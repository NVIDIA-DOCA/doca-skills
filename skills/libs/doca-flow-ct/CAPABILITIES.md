# DOCA Flow CT capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(layering / 5-tuple match / aging / NAT / overlay / cap-query /
errors / safety) and read that section end-to-end. The tables in
each section are the load-bearing content; the prose around them
is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern
(the verbs `configure / build / modify / run / test / debug`),
jump to [TASKS.md](TASKS.md). For everything that lives in the
underlying stateless layer (port bring-up, basic pipe spec,
validate-before-commit, Flow counters, Flow inspector) see
[`doca-flow`](../doca-flow/SKILL.md) — this skill assumes the
doca-flow surface is already in scope and does not redefine it.
For the canonical DOCA version-handling rules this skill layers a
CT overlay on top of, see [`doca-version`](../../doca-version/SKILL.md).

## Pattern overview

Every CT question this skill teaches resolves into one of SIX
patterns. The patterns are CLASSES — they apply across every
DOCA Flow CT release and every BlueField + ConnectX combination.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Walk the layering rule first | Every CT deployment requires a working doca-flow setup FIRST; CT attaches a context to an already-up doca-flow port and wraps existing pipes with CT semantics; CT does NOT replace doca-flow | [`## Capabilities and modes`](#capabilities-and-modes) layering table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Pick the path: stateless vs CT vs kernel conntrack | Decide whether the user even needs CT at all before quoting any CT API: stateless steering = doca-flow alone; hardware-accelerated stateful = doca-flow-ct; software / kernel-side state = Linux netfilter | [`## Capabilities and modes`](#capabilities-and-modes) path-selection rule + [`## Deferred topic boundaries`](#deferred-topic-boundaries) |
| 3. Express the 5-tuple match + CT-aware action set | CT match is 5-tuple (src IP, dst IP, src port, dst port, protocol) plus VRF / VNI for overlay scenarios; CT-aware actions include NAT (SNAT / DNAT / both) tied to the tracked connection | [`## Capabilities and modes`](#capabilities-and-modes) 5-tuple + NAT tables + [TASKS.md ## modify](TASKS.md#modify) |
| 4. Honor capability discovery on every axis | `doca_flow_ct_cap_*` against the active `doca_devinfo` answers max concurrent CT flows, supported aging-timer range, supported NAT variants, and supported overlay encapsulations; each is device-conditional and must be asked, not assumed | [`## Capabilities and modes`](#capabilities-and-modes) cap-query table + [TASKS.md ## configure](TASKS.md#configure) step 2 |
| 5. Size the aging table to expected concurrent flows | Under-provisioned aging tables cause spurious connection drops; over-provisioned tables waste device memory; the cap-query answer is the ceiling, the user's traffic profile is the input | [`## Safety policy`](#safety-policy) aging-table sizing rule + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 6. Diagnose a CT error | Map `DOCA_ERROR_BAD_STATE` / `_NOT_SUPPORTED` / `_FULL` (or `_NO_MEMORY`) / `_INVALID_VALUE` / `_IN_USE` to a root cause without leaving the CT layer prematurely | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **doca-flow first, CT on top — non-negotiable.** A CT context
  cannot be created against a port that has not been brought up
  via doca-flow, and a CT entry cannot be added before both the
  doca-flow pipe and the CT context have started. An agent that
  treats CT as a standalone library — or recommends rebuilding
  the doca-flow setup from scratch to add CT — has the layering
  wrong for every version of CT. The right move when the user
  asks "can I add CT" is always "yes, on top of what you
  already have", not "yes, throw away what you have and start
  over".
- **Capability discovery is multi-axis.** *"Will this CT
  deployment fit on this device"* requires asking on each axis
  separately: max concurrent flows, aging-timer range, NAT
  variants, overlay encapsulations. An agent that quotes only
  one axis (typically the flow ceiling) and silently assumes the
  rest will miss *"the device supports CT but not over VXLAN"*
  and *"the device supports SNAT but not DNAT"* cases.

## Capabilities and modes

The two orthogonal selection axes for any CT design are *which
doca-flow port the CT context attaches to* (one `doca_flow_ct`
per port that the user wants tracked) and *which CT-aware actions
the user needs* (plain conntrack-style state tracking, NAT-aware
actions on tracked connections, overlay-aware CT for tunneled
traffic). Choose both before writing any CT code, then drill into
the relevant capability-query.

**Layering rule — doca-flow first, CT on top.**

| Layer | What runs there | What this skill covers vs defers |
| --- | --- | --- |
| Base (doca-flow) | The stateless steering plane: port bring-up, basic match/action pipes, the validate-before-commit rule, per-pipe / per-entry counters, the Flow inspector trace | Out of scope here; owned by [`doca-flow`](../doca-flow/SKILL.md). CT assumes this layer is already up and stays out of its way |
| Companion (doca-flow-ct) | The stateful CT plane: a per-port `doca_flow_ct` context attached on top of a started doca-flow port; CT-aware pipe builders that wrap doca-flow pipes with 5-tuple match + state-aware actions; the CT entry table that tracks per-connection state; aging timers; NAT-aware actions on tracked connections | All of `## Capabilities and modes` / `## Error taxonomy` / `## Observability` / `## Safety policy` below |

The agent's rule: when the user has *not* yet brought doca-flow
up on the target port, the right next move is to route to
[`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)
FIRST, complete that bring-up, and only THEN come back to add
CT. Do **not** propose that CT replaces or rewires the doca-flow
setup — CT extends it.

**Path selection — stateless steering vs CT vs Linux kernel conntrack.**

| User intent | Right artifact | Why this skill is / isn't it |
| --- | --- | --- |
| Stateless steering only (match-and-forward, no per-connection state) | [`doca-flow`](../doca-flow/SKILL.md) alone | CT adds per-connection state tracking and aging on top of the stateless layer; pulling CT in for a stateless workload wastes device CT capacity and complicates the lifecycle |
| Hardware-accelerated stateful firewall offload, hardware NAT gateway, per-connection telemetry tied to flow rules, conntrack-aware actions in the dataplane | `doca-flow-ct` (this skill) on top of `doca-flow` | This is the only path doca-flow-ct is designed for; if stateless is enough, stay in `doca-flow`. If kernel conntrack is acceptable for the workload, that is a different artifact (next row) |
| Software / kernel-side connection tracking is acceptable (low connection rate, host CPU has headroom, no need to offload state to the device) | Linux netfilter conntrack (`nf_conntrack`, `iptables -m state`, `nft ct`) | Different code path, different semantics, and out of scope for this skill. Route to upstream Linux documentation; do NOT use doca-flow-ct as a wrapper around kernel conntrack |
| Very short-lived connections with no CT benefit (every packet is a new flow; aging would dominate the table churn) | [`doca-flow`](../doca-flow/SKILL.md) alone | CT entries have a non-zero per-flow cost; for traffic profiles dominated by one-packet flows the stateless pipe is faster and uses less device memory |

**The per-port `doca_flow_ct` context — one per tracked doca-flow port.**

| Object | Lifetime | What it owns | Key calls (host-side surface) |
| --- | --- | --- | --- |
| `doca_flow_ct` | Per doca-flow port the user wants stateful tracking on; created against an already-up doca-flow port; lifetime is a subset of the port's lifetime (start after port start, stop before port stop) | The CT bookkeeping for that port: the CT entry table, the aging timer configuration, the registration of CT-aware pipe builders that wrap the port's pipes | `doca_flow_ct` create / configure / start / stop / destroy (DOCA Core lifecycle); `doca_flow_ct_cap_*` for what this device supports on the CT axis |

A host driving CT on more than one doca-flow port needs one
`doca_flow_ct` per port — there is no *"global CT context"*. The
agent must ask which port (which doca-flow port handle) the user
intends to track before recommending any `doca_flow_ct_*` call.

**The 5-tuple CT match shape — the only match the agent should
quote as default.**

| Match field | What it carries | Why the agent must surface it |
| --- | --- | --- |
| Source IP (v4 / v6) | The connection's source address | Half of the connection identity; CT must see both endpoints to identify the connection |
| Destination IP (v4 / v6) | The connection's destination address | Other half of the connection identity |
| Source port | TCP / UDP source port | Required to separate concurrent flows from the same source host |
| Destination port | TCP / UDP destination port | Required to separate concurrent flows to the same destination host (especially common with load balancers) |
| Protocol | IP protocol number (TCP=6, UDP=17, …) | Required because the same (IP, port, IP, port) tuple may legitimately exist for different protocols |
| VRF / VNI (overlay scenarios only) | Routing-domain identifier (VRF) or overlay network identifier (VNI) for VXLAN / GENEVE / … | Required when the same 5-tuple may exist in multiple overlay tenants; omit only for non-overlay flat networks |

The agent's rule: if the user asks for a CT match that is *less*
than 5-tuple (e.g. *"track by source IP only"*), that is almost
always a stateless steering question dressed up as CT — route
back to [`doca-flow`](../doca-flow/SKILL.md). If the user asks
for *more* than 5-tuple plus VRF / VNI (e.g. *"include the
DSCP bits"*), surface that this is outside the conntrack-style
5-tuple identity and may not have hardware support — confirm via
the cap query before promising it.

**The CT-aware action set — what a tracked connection can do.**

| Action class | What it does | Capability axis to check |
| --- | --- | --- |
| State-tracking only | The CT entry tracks the connection state (new, established, related, closed) and the action is decided by the wrapped doca-flow pipe based on state | None beyond the base CT capability; this is what every device supporting CT supports |
| SNAT (source NAT) | The CT entry rewrites the source address (and optionally source port) of packets matching the tracked connection in the forward direction; the reverse direction is rewritten symmetrically | `doca_flow_ct_cap_*` axis for SNAT — not every device that supports CT also supports SNAT |
| DNAT (destination NAT) | The CT entry rewrites the destination address (and optionally destination port) of packets matching the tracked connection in the forward direction; the reverse direction is rewritten symmetrically | `doca_flow_ct_cap_*` axis for DNAT — separate from the SNAT axis; check independently |
| SNAT + DNAT combined | Both source and destination rewritten for the same tracked connection (full-cone NAT, hairpin NAT, double NAT scenarios) | `doca_flow_ct_cap_*` axis for combined NAT — may be supported even when each individually is, but the agent must confirm rather than assume |
| Overlay-aware CT | The CT entry tracks the inner 5-tuple over an overlay encapsulation (VXLAN, GENEVE, …) and applies actions on the inner packet | `doca_flow_ct_cap_*` axis for the specific overlay encapsulation — VXLAN support does NOT imply GENEVE support; ask per overlay |

**Capability discovery — the only rule.** Before sizing any CT
table, choosing an aging timer, attempting a NAT translation, or
attaching CT over an overlay, call the matching
`doca_flow_ct_cap_*` query against the active `doca_devinfo`:

| Capability | What the cap query answers | Why the agent must ask |
| --- | --- | --- |
| Maximum concurrent CT flows | The device's per-port (or per-CT-context, per the documented surface) ceiling on simultaneous tracked entries | Sizing CT for more flows than the device supports returns `DOCA_ERROR_FULL` (or `_NO_MEMORY`) on entry add at the worst possible time — under load. Ask before commit |
| Supported aging-timer range | The min / max aging timer values the device accepts (granularity may also be device-specific) | Setting an aging timer outside the range returns `DOCA_ERROR_INVALID_VALUE` at configure. Under-provisioning (timer too short) causes spurious disconnects; over-provisioning (timer too long) holds dead entries and wastes table space |
| Supported NAT variants (SNAT / DNAT / both) | Which of {none, SNAT only, DNAT only, both} the device supports as CT-tied actions | Requesting a NAT variant the device does not support returns `DOCA_ERROR_NOT_SUPPORTED` at pipe / entry add. The agent must surface that NAT support is not a single axis |
| Supported overlay encapsulations for CT | Which overlay encapsulations (VXLAN, GENEVE, GRE, …) can carry CT-tracked inner flows on this device | Overlay support in plain doca-flow does NOT imply overlay support in doca-flow-ct; the CT layer has its own per-overlay capability axis |

**Configuration shape.** *Mandatory* preconditions before any
`doca_ctx_start()` on the `doca_flow_ct`: the doca-flow port must
be started; the `doca_flow_ct` Core context must be created
against that started port; the aging-timer setting must be inside
the device's advertised range; any NAT variant the user intends
to use must have been confirmed via the matching cap query.
*Optional* configurations (CT-entry retunes after creation,
observability hook-up) are program-side tunables that ride on
top of the same cap-query rule.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it.

**The CT-specific overlay** is:

- **doca-flow-ct rides the doca-flow version.** doca-flow-ct is
  a companion library: it ships in the same DOCA install as
  doca-flow and is expected to be at the same DOCA version. The
  agent must check BOTH `pkg-config --modversion doca-flow-ct`
  AND `pkg-config --modversion doca-flow`, AND confirm they agree
  with each other AND with `doca_caps --version` (the four-way
  match check that [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
  owns). Disagreement is a partial-install hazard, typically
  from a DOCA upgrade that pulled in the new doca-flow `.pc`
  while leaving an older doca-flow-ct `.pc` (or vice versa) in
  place. Route any disagreement to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before any CT-layer diagnosis.
- **Per-CT-capability availability uses the cap-query rule.**
  Per the cross-cutting cap-query rule in
  [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
  `doca_flow_ct_cap_*` against the active `doca_devinfo` is the
  runtime authority for *"is this CT axis (max flows, aging
  range, NAT variant, overlay encapsulation) supported on this
  hardware + this DOCA install"*. The version-matrix lookup
  procedure in
  [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test)
  step 2 uses `pkg-config --modversion doca-flow-ct` as the
  build-time anchor.
- **The release notes for the installed version are the
  canonical source for CT features added, deprecated, or
  behavior-changed in that release.** Route through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the release-notes URL pattern. Do not maintain a per-release
  feature table here — it would drift out of date silently.

## Error taxonomy

CT-specific overlays on the cross-library `DOCA_ERROR_*` taxonomy.
The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *CT surface* meaning that the agent must
disambiguate before falling back to the cross-library response.

| Error | CT context where it shows up | CT-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | `doca_flow_ct` create / start; CT entry add before the CT context is started; CT entry add before the underlying doca-flow port is started | Layering / lifecycle violation. The most common case is calling a CT-layer API before the underlying doca-flow port reports started, or adding a CT entry before `doca_ctx_start()` has been called on the `doca_flow_ct`. Walk the layering rule in [`## Capabilities and modes`](#capabilities-and-modes) layering table; verify the doca-flow lifecycle in [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure) is complete; verify the CT lifecycle in [`TASKS.md ## configure`](TASKS.md#configure) is in order |
| `DOCA_ERROR_NOT_SUPPORTED` | `doca_flow_ct_cap_*`; CT context create; CT entry add with a NAT action; CT entry add over an overlay | NAT variant / overlay / aging range / CT feature is unsupported on this device + firmware combo. Re-run the matching `doca_flow_ct_cap_*` against the active `doca_devinfo`; surface BOTH which DOCA version is installed AND which CT axis the device does not advertise. Do not retry the same spec on the same device |
| `DOCA_ERROR_FULL` (or `DOCA_ERROR_NO_MEMORY`) | CT entry add when the table is at capacity | CT entry table is full. Read the per-CT-entry counters (per [`## Observability`](#observability) below) to identify idle / stale entries; either wait for aging to evict them, or evict explicitly; or — if the workload genuinely needs more concurrent flows than the device supports — re-run the cap query for the max-concurrent-flows axis and consider whether the workload fits this device at all |
| `DOCA_ERROR_INVALID_VALUE` | CT entry add with a malformed 5-tuple; NAT translation that conflicts with an existing entry; unsupported overlay configuration; aging-timer outside the device's advertised range | Either the 5-tuple is malformed (e.g. zero protocol, mismatched IP version between src and dst), or the requested NAT translation conflicts with an entry already in the table (two CT entries cannot map the same translated 5-tuple to two different connections), or the overlay configuration is not one the device supports for CT, or the aging timer is outside the cap-advertised range. Re-validate the 5-tuple shape; re-check the NAT translation against existing entries; re-read the matching cap query |
| `DOCA_ERROR_IN_USE` | CT entry remove while the entry is still being referenced by traffic in flight | The CT entry the user is trying to remove is still being referenced by packets in the device's processing pipeline. The fix is to quiesce traffic to the affected 5-tuple (or wait for the aging timer to evict the entry naturally), then retry the remove. Do NOT force-remove; doing so can corrupt the per-connection state on the wire |

The agent's rule: **never recommend a retry loop on a
`DOCA_ERROR_*` from a `doca_flow_ct_*` call without first
identifying which of the rows above is the cause**. `_BAD_STATE`
needs a lifecycle fix, `_NOT_SUPPORTED` needs a capability /
device fix, `_FULL` needs aging / eviction / device-fit
reconsideration, `_INVALID_VALUE` needs a spec fix, and `_IN_USE`
needs a quiescence step — none of them want a blind retry.

## Observability

CT's observability surface is the **per-CT-entry counter set**
plus the per-connection state transitions plus everything the
underlying doca-flow layer already exposes (per-pipe counters,
per-entry counters on the wrapped pipes, the Flow inspector
trace). The CT layer adds visibility on top; it does not replace
the base-layer visibility.

Three primary signals the agent should reach for:

1. **Per-CT-entry counters.** Each CT entry the user creates can
   carry counters that report how many packets / bytes have
   matched it in each direction. Reading the counter back is the
   canonical way to confirm *the connection is actually flowing
   through this CT entry*. A zero counter on an entry the user
   expected to match is almost always a 5-tuple mismatch (wrong
   address, wrong port, wrong VRF / VNI) — re-read the 5-tuple
   against the actual on-wire traffic before blaming the device.
2. **Per-connection state transitions.** CT tracks the standard
   conntrack state machine (new → established → related → closed)
   on each entry. The current state of an entry is the *what is
   the device's understanding of this connection right now*
   signal. Inconsistency between the user's mental model (e.g.
   *"this connection should be established"*) and the entry's
   reported state is the bug — typically a missing-direction
   match (CT did not see the reply direction) or an overly
   aggressive aging timer that closed the entry prematurely.
3. **Aging-timer expirations.** Entries evicted by aging are
   silently removed from the CT table; the user observes this as
   *"connections drop after N seconds of idle"*. If the user
   reports this, the next move is to read the aging timer the
   user configured, compare it to the cap-advertised range, and
   ask whether the timer is appropriate for the workload's idle
   profile — under-provisioned aging is the load-bearing CT-side
   cause of *"my long-lived connections keep being dropped"*.

Underlying-layer observability (per-pipe counters, per-entry
counters on wrapped pipes, Flow inspector trace) lives in
[`doca-flow CAPABILITIES.md ## Observability`](../doca-flow/CAPABILITIES.md#observability)
and is not duplicated here. The agent should reach for
*CT-entry counters first, then state transitions, then aging
expirations, then the underlying doca-flow observability* — in
that order — when investigating *"connections behave oddly"*.

For cross-cutting observability primitives (`--sdk-log-level`,
the `DOCA_LOG_LEVEL` env var, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package
layout, sample tree) defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

CT's safety surface is **layering-driven AND sizing-driven AND
translation-conflict-driven**. The three most common CT first-app
failures are (1) attempting a CT operation before the underlying
doca-flow lifecycle is complete; (2) sizing the aging table
without consulting the device's cap-advertised range, which
causes either spurious connection drops or device-memory waste;
and (3) committing a NAT translation that conflicts with an
existing CT entry, which the runtime catches as
`DOCA_ERROR_INVALID_VALUE` but the agent should catch in design.

The **layering rule** the agent must enforce on every CT setup:

| Stage | What must already be true | How the agent verifies | Where to fix if it isn't |
| --- | --- | --- | --- |
| Before any `doca_flow_ct_*` call | doca-flow port is created AND started against the target device | The user can show the port handle from a successful `doca_flow_port_start` per [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure) step 4 | [`doca-flow`](../doca-flow/SKILL.md) — complete the doca-flow bring-up first; do NOT propose rebuilding it from scratch to add CT |
| Before `doca_ctx_start()` on the `doca_flow_ct` | The `doca_flow_ct` is created against the started doca-flow port AND the aging-timer setting is inside the cap-advertised range AND any NAT / overlay variants the user intends to use are confirmed supported | The user has run `doca_flow_ct_cap_*` against the active `doca_devinfo` and recorded the max-concurrent-flows / aging range / NAT variant / overlay set | [`TASKS.md ## configure`](TASKS.md#configure) step 2 capability discovery |
| Before any CT entry add | Both the doca-flow pipe being wrapped AND the `doca_flow_ct` are started, AND the CT entry's 5-tuple is internally consistent (matched IP versions on src / dst, non-zero protocol, valid ports for the protocol), AND any NAT translation does not collide with an existing CT entry | The user has staged the entry through [`TASKS.md ## test`](TASKS.md#test) step 1 single-flow smoke | [`TASKS.md ## test`](TASKS.md#test) — stage one entry, send one matching packet, observe the counter and state transitions before bulk add |

The **aging-table sizing rule** the agent must enforce:

1. Read the device's max concurrent CT flows via the matching
   `doca_flow_ct_cap_*` query. This is the ceiling.
2. Estimate the user's expected concurrent-flow count (peak,
   not average). The user supplies this from workload knowledge
   — the agent must NOT invent a number.
3. If the user's estimate exceeds the ceiling, surface that
   the device does not fit the workload; either reduce the
   workload's concurrent-flow target (aggressive aging timer,
   per-tenant CT partitioning) or pick a device with a higher
   ceiling. Do NOT recommend over-committing the table.
4. If the user's estimate fits the ceiling, recommend an aging
   timer that matches the user's idle-connection profile: long
   enough to avoid evicting still-active connections, short
   enough to free table space for new connections at the
   expected churn rate. The cap-advertised aging-timer range
   is the constraint; the user's workload is the input.
5. Validate by running the [`TASKS.md ## test`](TASKS.md#test)
   sustained-run loop with a representative traffic profile;
   spurious connection drops at steady state mean the aging
   timer is too short and the table is under-provisioned for
   the actual concurrency.

**Do not invent NAT translations to resolve a conflict.** If
two CT entries would map the same translated 5-tuple, the
runtime catches it as `DOCA_ERROR_INVALID_VALUE` and the agent's
job is to surface the conflict to the user, not to silently
pick a different port or address. Translation conflicts are
almost always a policy bug (two NAT rules that should not
coexist) and the user's policy layer is the right place to
resolve them.

**Do not propose stateless steering as a CT substitute.** When
the user's intent genuinely requires stateful behavior
(*"allow established, drop new"*, *"per-connection NAT"*,
*"per-connection telemetry"*), stateless steering cannot
express it — the right answer is to add CT on top of doca-flow,
not to talk the user out of stateful semantics. The path-
selection rule in [`## Capabilities and modes`](#capabilities-and-modes)
documents the criteria; honor them.

**This skill does not define a firewall policy.** doca-flow-ct
*tracks* connections and *applies* the actions the user asks
for; it does not implement a security policy. When the user
asks *"what rules should I write"*, the agent must refuse to
invent a policy and must route the user to their own networking
/ security expertise — that is a domain question, not an API
question.

## Deferred topic boundaries

This skill scopes itself to the **CT companion** that extends
doca-flow with stateful connection tracking. Adjacent topics
the agent will get asked but should route elsewhere:

- **Stateless steering, port bring-up, basic pipe spec.** Owned
  by [`doca-flow`](../doca-flow/SKILL.md). This skill assumes
  the doca-flow setup is already in place; if it is not, route
  there first.
- **Linux kernel conntrack (`nf_conntrack`, `iptables -m state`,
  `nft ct`).** Different code path with different semantics. Out
  of scope for this skill. Route to upstream Linux documentation;
  do NOT use doca-flow-ct as a wrapper around kernel conntrack.
- **Firewall / NAT policy design itself** (which connections to
  allow, which subnets to NAT to which public IPs, how long is
  the right aging timer for the user's workload) — outside this
  skill. Route to the user's own networking / security expertise;
  this skill prescribes how to *track and apply* policy, not how
  to *write* policy.
- **DOCA Core context and progress engine internals** — owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the Core lifecycle; it does not redefine it.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the CT overlay, not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build /
  link / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug). This
  skill's `## debug` redirects there for layer 1-4; layers 5-7
  carry the CT-specific overlay (including the layering-rule
  violation route and the aging-table sizing route).
