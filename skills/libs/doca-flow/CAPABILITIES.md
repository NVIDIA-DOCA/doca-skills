# DOCA Flow capabilities, version compatibility, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
Flow-class patterns. Pick the pattern first, then drill into the H2
that owns the substance. For the *how* of executing each pattern, jump
to [TASKS.md](TASKS.md).

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For step-by-step workflows that *use* these
capabilities (configure, build, modify, run, test, debug) see
[TASKS.md](TASKS.md). For where the underlying public documentation and
installed package paths live, defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) — do
not duplicate URLs or install paths in this file.

## Pattern overview

Every Flow-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
pipe spec, not just the worked example shown.

| Flow pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick the steering mode | HWS vs SWS, decide before quoting any feature | [`## Capabilities and modes`](#capabilities-and-modes) steering-mode bullet |
| 2. Bring up port + representor | Port-init, representor binding, lifecycle order | [TASKS.md ## configure](TASKS.md#configure) |
| 3. Express *<match X, do Y>* as a pipe | Match-criteria + action set + pipe-type pick (basic / hairpin / control / ordered) | [`## Capabilities and modes`](#capabilities-and-modes) pipe-type table + [TASKS.md ## modify](TASKS.md#modify) |
| 4. Validate the spec before commit | DOCA Flow does not ship a separate `doca_flow_pipe_validate` C API at this release — validation is done at constructor time inside `doca_flow_pipe_create_v1` (and the staged-entry / dry-run pattern in the shipped samples). Treat constructor failure as the validate step; do not invent a separate validate call. | [`## Safety policy`](#safety-policy) validate-before-commit rule + [TASKS.md ## test](TASKS.md#test) |
| 5. Observe what the HW actually did | Per-pipe / per-entry counters + Flow inspector trace | [`## Observability`](#observability) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret a `DOCA_ERROR_*` from a Flow call | Map the error to a layer (env / build / link / runtime / program), then route | [`## Error taxonomy`](#error-taxonomy) Flow overlay + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Discover the version-installed surface, do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-flow` and on
  the `doca_caps` capability snapshot of the active device. Quoting
  a feature without checking is the most common hallucination
  failure mode.
- **Validate before commit, every time.** `validate` is a separate
  read-only call; skipping it produces runtime symptoms that look
  like hardware bugs and waste debug time. See
  [`## Safety policy`](#safety-policy).

## Capabilities and modes

DOCA Flow programs the BlueField NIC's accelerated steering hardware.
Before writing any pipe spec, the agent should know which mode and feature
set the device is in:

- **Steering mode.** Flow runs over either hardware steering (HWS, the
  default on supported hardware/firmware combinations) or software steering
  (SWS, fallback). Supported match kinds, action kinds, and pipe types
  depend on the active mode. Confirm the active mode before quoting feature
  support — never assume HWS just because the device supports it.
- **Pipe types.** Basic match-action pipes, hairpin pipes (RX-to-TX
  forwarding without the host CPU touching the packet), control pipes,
  ordered/unordered list pipes. Hairpin and ordered-list pipes have
  additional steering-mode constraints documented per release.
- **Match kinds.** L2 (destination MAC, VLAN), L3 (IPv4/IPv6 source and
  destination, protocol), L4 (TCP/UDP ports, flags), tunnel headers
  (VXLAN, GENEVE, GRE — availability varies by firmware), and metadata
  fields. Always verify the requested match kind is in the device's
  capability set before building the spec.
- **Action kinds.** Forward to representor, drop, modify (header rewrite,
  decap, encap), counter, jump-to-pipe, mirror. Encap/decap availability
  depends on the firmware feature set.
- **Capability discovery at runtime.** Before relying on a capability,
  agents should encourage the user to query it through the installed
  `doca_caps` tool and the Flow capability-query API rather than guessing
  from documentation. The exact tool path lives in the knowledge-map.

When the user has not yet checked steering mode and feature support, the
correct first move is to walk them through capability discovery in
[TASKS.md ## configure](TASKS.md#configure) — not to guess a working pipe
spec.

## flow-ct

DOCA Flow Connection Tracking (pkg-config `doca-flow-ct`) is the
**COMPANION** library that EXTENDS the stateless steering surface
in [`## Capabilities and modes`](#capabilities-and-modes) above
with hardware-accelerated 5-tuple connection tracking, aging
timers, and NAT-aware actions (SNAT / DNAT) on tracked
connections. It is NOT a replacement for doca-flow; it attaches
a per-port `doca_flow_ct` context on top of an already-up
doca-flow port and wraps existing pipes with CT semantics.

**Layering rule — doca-flow first, CT on top — non-negotiable.**
A `doca_flow_ct` context cannot be created against a port that
has not been brought up via doca-flow, and a CT entry cannot be
added before BOTH the wrapped doca-flow pipe AND the CT context
have started. When the user has not yet brought doca-flow up on
the target port, route to
[`TASKS.md ## configure`](TASKS.md#configure) FIRST. Do NOT
propose that CT replaces or rewires the doca-flow setup — CT
extends it. An agent that treats `doca-flow-ct` as a standalone
library — or recommends rebuilding the doca-flow setup from
scratch to add CT — has the layering wrong for every version of
CT.

**Path selection — stateless vs CT vs Linux kernel conntrack.**

| User intent | Right artifact |
| --- | --- |
| Stateless steering only (match-and-forward, no per-connection state) | This skill's stateless surface in [`## Capabilities and modes`](#capabilities-and-modes) alone |
| Hardware-accelerated stateful firewall offload, hardware NAT gateway, per-connection telemetry tied to flow rules, conntrack-aware dataplane actions | `doca-flow-ct` (this section) on top of doca-flow |
| Software / kernel-side conntrack is acceptable (low connection rate, host CPU has headroom) | Linux netfilter (`nf_conntrack`, `iptables -m state`, `nft ct`) — different code path, out of scope here. Do NOT use `doca-flow-ct` as a wrapper around kernel conntrack |
| Traffic dominated by one-packet flows (CT entries would churn faster than aging can keep up) | This skill's stateless surface alone — CT entries have a non-zero per-flow cost |

**The per-port `doca_flow_ct` context — one per tracked port.**

| Object | Lifetime | What it owns |
| --- | --- | --- |
| `doca_flow_ct` | Per doca-flow port the user wants stateful tracking on; created against an already-up port; lifetime is a subset of the port's (start after port start, stop before port stop) | The CT bookkeeping for that port: the CT entry table, the aging-timer configuration, the registration of CT-aware pipe builders that wrap the port's pipes; `doca_flow_ct_cap_*` for what this device supports on the CT axis |

A host driving CT on more than one doca-flow port needs ONE
`doca_flow_ct` per port — there is no *"global CT context"*. Ask
which port (which doca-flow port handle) the user intends to
track BEFORE recommending any `doca_flow_ct_*` call.

**The 5-tuple CT match — the only match the agent should quote
as default.**

| Match field | What it carries |
| --- | --- |
| Source IP (v4 / v6) | The connection's source address — half of the connection identity |
| Destination IP (v4 / v6) | The connection's destination address — the other half |
| Source port | TCP / UDP source port — separates concurrent flows from the same source host |
| Destination port | TCP / UDP destination port — separates concurrent flows to the same destination host |
| Protocol | IP protocol number (TCP=6, UDP=17, …) — the same (IP, port, IP, port) tuple may legitimately exist for different protocols |
| VRF / VNI (overlay only) | Routing-domain identifier (VRF) or overlay network identifier (VNI) for VXLAN / GENEVE / … — required when the same 5-tuple may exist in multiple overlay tenants |

If the user asks for a CT match that is *less* than 5-tuple
(e.g. *"track by source IP only"*), that is almost always a
stateless steering question dressed up as CT — route back to
[`## Capabilities and modes`](#capabilities-and-modes). If they
ask for *more*, confirm via the cap-query before promising it.

**CT-aware actions — state-tracking, NAT, overlay-aware.**

| Action class | Capability axis to check |
| --- | --- |
| State-tracking only (new → established → related → closed) | Base CT capability — what every CT-supporting device has |
| SNAT (rewrite source address / port; reverse is symmetric) | `doca_flow_ct_cap_*` SNAT axis |
| DNAT (rewrite destination address / port; reverse is symmetric) | `doca_flow_ct_cap_*` DNAT axis (separate from SNAT — check independently) |
| SNAT + DNAT combined (full-cone, hairpin, double NAT) | `doca_flow_ct_cap_*` combined axis — may be supported even when each individually is, but confirm; do not assume |
| Overlay-aware CT (inner 5-tuple over VXLAN / GENEVE / …) | Per-overlay axis — VXLAN support does NOT imply GENEVE support |

**Capability discovery — multi-axis, every time.** Before sizing
any CT table, choosing an aging timer, attempting a NAT
translation, or attaching CT over an overlay, call the matching
`doca_flow_ct_cap_*` query against the active `doca_devinfo`.
The agent must NEVER quote only one axis (typically the flow
ceiling) and silently assume the rest:

| Axis | Why ask separately |
| --- | --- |
| Max concurrent CT flows | Sizing for more flows than the device supports returns `DOCA_ERROR_FULL` at the worst possible time — under load |
| Aging-timer range (min / max / granularity) | A timer outside the advertised range returns `DOCA_ERROR_INVALID_VALUE` at configure; under-provisioning causes spurious disconnects, over-provisioning wastes table space |
| NAT variants (SNAT / DNAT / combined) | Requesting an unsupported variant returns `_NOT_SUPPORTED` at entry add; NAT support is NOT a single axis |
| Overlay encapsulations for CT | Overlay support in stateless doca-flow does NOT imply CT support over that overlay — the CT layer has its own per-overlay axis |

**Version pairing — doca-flow-ct rides the doca-flow version.**
`pkg-config --modversion doca-flow-ct` MUST equal
`pkg-config --modversion doca-flow`, AND both MUST equal
`doca_caps --version`. A partial install (one `.pc` upgraded
without the other) is the canonical *"my CT entry returns
`_DRIVER` on a device the cap-query says supports it"* root
cause. Route disagreement to
[`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
layer 2 BEFORE any CT-layer diagnosis.

**CT-specific error overlay.** Add to the cross-library taxonomy
in [`## Error taxonomy`](#error-taxonomy):

| Error | CT-specific cause |
| --- | --- |
| `DOCA_ERROR_BAD_STATE` | Layering / lifecycle violation: a CT-layer call before the underlying doca-flow port reports started, OR a CT entry add before `doca_ctx_start()` on the `doca_flow_ct`, OR tearing down the doca-flow port while a CT context is still attached and running |
| `DOCA_ERROR_NOT_SUPPORTED` | NAT variant / overlay / aging range / CT feature is unsupported on this device + firmware combo. Re-run the matching `doca_flow_ct_cap_*`; surface BOTH which DOCA version is installed AND which CT axis the device does not advertise. Do not retry the same spec on the same device |
| `DOCA_ERROR_FULL` (or `_NO_MEMORY`) | CT entry table at capacity. Read the per-CT-entry counters to identify idle / stale entries; either wait for aging to evict them, evict explicitly, or — if the workload genuinely needs more concurrent flows than the device supports — re-run the cap query for the max-concurrent-flows axis and consider whether the workload fits this device at all |
| `DOCA_ERROR_INVALID_VALUE` | Malformed 5-tuple (zero protocol, mismatched IP versions on src / dst), NAT translation that conflicts with an existing entry (two entries cannot map the same translated 5-tuple to two different connections), unsupported overlay configuration, or aging timer outside the cap-advertised range |
| `DOCA_ERROR_IN_USE` | CT entry remove while the entry is still being referenced by in-flight traffic. Quiesce the affected 5-tuple (or wait for the aging timer to evict the entry naturally), then retry. Do NOT force-remove — doing so can corrupt the per-connection state on the wire |

**Safety overlay.** Inherits this skill's existing
[`## Safety policy`](#safety-policy) plus three CT-specific rules:

1. **Aging-table sizing.** The cap-advertised max concurrent
   flows is the ceiling; the user's expected peak (not average)
   concurrent-flow count is the input. If the estimate exceeds
   the ceiling, surface the device-fit gap — do NOT over-commit
   the table. The aging timer must fit BOTH the cap-advertised
   range AND the granularity.
2. **Do not invent NAT translations to resolve a conflict.**
   `DOCA_ERROR_INVALID_VALUE` on an entry add with a NAT action
   is almost always a policy bug (two NAT rules that should not
   coexist). Surface the conflict to the user; the policy layer
   is the right place to fix it.
3. **This skill does not define a firewall policy.**
   doca-flow-ct *tracks* connections and *applies* the actions
   the user asks for; it does NOT implement policy. When the
   user asks *"what rules should I write"*, refuse to invent a
   policy and route to their networking / security expertise.

For the configure / build / modify / run / test / debug shape
specific to CT, see
[`TASKS.md ## flow-ct`](TASKS.md#flow-ct).

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match rule, NGC container semantics, and the headers-win-over-docs rule, see [`doca-version`](../../doca-version/SKILL.md). The body lives there; this skill does not duplicate it.

**The Flow-specific overlay** is:

- The set of `doca_flow_*` symbols available on a given install is observable from the Flow header set under the installed DOCA infrastructure tree (look up the path in [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package)). When the user reports an `undefined reference` or "function not found" for a `doca_flow_*` symbol, the first hypothesis is **wrong-version documentation** — confirm the installed version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure), then verify the symbol exists in the installed headers, then read the Flow programming guide for *that* release.
- Per-Flow-capability availability uses the version-matrix lookup procedure in [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) step 2, with `pkg-config --modversion doca-flow` as the build-time anchor.
- The release notes for the installed version are the canonical source for
  Flow features added, deprecated, or behavior-changed in that release.
  Route through the knowledge-map for the release-notes URL pattern.

Version-specific tables of symbol availability are deliberately not
maintained in this file — they would drift out of date silently. The
discipline is "read the headers and the matching release notes", not
"trust this file's table".

## Error taxonomy

Flow API calls return either `DOCA_SUCCESS` or a `DOCA_ERROR_*` code.
The agent should treat these as a layered taxonomy when deciding what
to ask the user next:

| Class | Examples | Typical cause | Right next move |
| --- | --- | --- | --- |
| Configuration error | `DOCA_ERROR_INVALID_VALUE` on pipe creation | Spec contradicts itself or violates schema | Re-validate the spec against the pipe-spec rules (`pipe validation` workflow in TASKS.md). |
| Capability error | `DOCA_ERROR_NOT_SUPPORTED` on pipe creation or entry add | Match kind, action kind, or steering mode is unsupported on this device/firmware | Re-run capability discovery (TASKS.md `## configure`); compare requested capability to the device's actual capability set. Do not retry the same spec on the same device. |
| Resource error | `DOCA_ERROR_NO_MEMORY`, `DOCA_ERROR_FULL` on entry add | Pipe entry budget exhausted or actions-memory pool depleted | Inspect counters and pipe statistics (`## Observability` below); enlarge the pool or evict entries before retrying. |
| Lifecycle error | `DOCA_ERROR_BAD_STATE` on start/stop | Object operated on outside its allowed lifecycle window | Re-read the object's lifecycle in TASKS.md; ensure operations happen in the documented order (port started before pipe created, pipe created before entries added, etc.). |
| Hardware/firmware error | `DOCA_ERROR_DRIVER` and similar | The kernel driver, firmware, or PCIe path is in a state Flow cannot recover from | Stop. This is not a Flow-spec problem. Capture device state via the platform's diagnostic CLIs and escalate. |

Flow does not invent error codes outside the `DOCA_ERROR_*` family;
**any error in a Flow API trace that is not a `DOCA_ERROR_*` constant is
either a wrapper layer the user added or a bug worth filing** — do not
silently translate it to a guess.

## Observability

Flow exposes three observable surfaces:

- **Pipe counters.** Each pipe entry can be created with a counter
  attached. Reading the counter back is the canonical way to confirm
  *traffic is matching* the entry. If the counter is zero while the user
  reports traffic should match, the pipe spec is wrong; do not blame the
  packet generator first.
- **Pipe statistics.** Per-pipe statistics (entry count, hit count where
  exposed, errors) describe whether the pipe itself is healthy. Use these
  before blaming individual entries.
- **Tracing / per-pipe diagnostic dump.** Flow's diagnostic dump describes
  the actual programmed entries the hardware sees. Use this when the
  user's understanding of "what I asked the hardware to do" diverges from
  observed behavior — it is the ground truth.

Workflow: when investigating "traffic is going to the wrong place", the
canonical order is *counters first → statistics second → trace dump
third*. Walking the order saves redundant questions.

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

Programming the BlueField steering hardware is **not** a free-form
operation. Wrong specs can take traffic offline; wrong actions can drop
or mirror unintended traffic. Two policies follow from that:

1. **Validate before committing to hardware.** Every pipe specification
   that an agent helps construct should be validated by Flow's
   pipe-validation API (or, where the API is unavailable on the installed
   version, by a dry-run sample) **before** the entry-add call hits the
   hardware. The lifecycle is *build → validate → start → add entries →
   read counters*. Skipping validation is the most common cause of "my
   pipe takes the link down" reports.
2. **Hairpin pipes must be staged.** A hairpin pipe (RX-to-TX without the
   host CPU) effectively rewires the steering plane. The validate-before-
   commit ordering for hairpin pipes is stricter than for plain
   match-action pipes:
   1. **Build** the pipe spec with explicit ingress and egress port
      identifiers and an explicit match key. Implicit-match hairpin specs
      are forbidden by this policy because they are silently
      catch-everything.
   2. **Validate** the spec against the active steering mode's hairpin
      rules; reject any spec that would shadow an existing higher-priority
      pipe on either port.
   3. **Stage** entries on a single representor first and read the
      counters under controlled traffic before widening the entry set to
      production representors.
   4. **Commit** the production entries only after the staged entries
      report the expected counters under expected traffic.

   The build-validate-stage-commit ordering is what this policy means by
   "validate before commit" for hairpin pipes specifically.

3. **Capability check before action change.** Any change to a pipe's
   action set must re-run the capability check from
   `## Capabilities and modes` against the *new* action set on the
   currently active steering mode. An action that was supported when the
   pipe was first built can become unsupported if the device or firmware
   was reconfigured between sessions.

The agent's job is to **enforce these orderings in the workflow**, not
just describe them. If the user says "skip the dry-run, just program it",
the right answer is to refuse and explain the cost, not to comply.
