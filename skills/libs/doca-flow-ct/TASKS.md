# DOCA Flow CT workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. Skip ahead only when the user is already
past a verb. The `## test` verb is an iterative loop (single-flow
smoke → multi-flow → aging → NAT-aware → loop back if a
precondition changes), not a one-shot pass — see the eval-loop
overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the CT capability surface, layering
rule, 5-tuple match schema, NAT action surface, capability-query
rule, error taxonomy, observability, and safety policy, see
[CAPABILITIES.md](CAPABILITIES.md). For everything that lives in
the underlying stateless layer (port bring-up, basic pipe spec,
validate-before-commit, Flow counters, Flow inspector) see
[`doca-flow`](../doca-flow/SKILL.md) — this skill assumes the
doca-flow surface is already in scope and does not redefine it.
For the cross-library DOCA patterns layered under everything
below (the universal Core lifecycle, the cross-library
`DOCA_ERROR_*` taxonomy, the modify-a-shipped-sample workflow),
see [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: attach a `doca_flow_ct` CT context to an already-up
`doca-flow` port, size the CT entry table and aging timer
against the device's advertised capabilities, and confirm both
the doca-flow layer and the CT layer are in a state where adding
CT entries will be meaningful.

Steps the agent should walk the user through:

1. **Confirm the doca-flow base layer is up FIRST.** Per the
   layering rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   layering table, the doca-flow port must already be created
   AND started before any `doca_flow_ct_*` call. If the user
   has not completed
   [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)
   on the target port, STOP and route there first. Do NOT
   propose rebuilding the doca-flow setup from scratch to add
   CT — CT extends doca-flow, it does not replace it. The user
   should arrive at this skill with a working port handle, at
   least one validated stateless pipe, and a sanity-checked
   match/action sketch for the CT-aware version of that pipe.
2. **Run CT capability discovery on every axis against the
   active `doca_devinfo`.** Per the cap-query table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   call the matching `doca_flow_ct_cap_*` queries for: max
   concurrent CT flows; supported aging-timer range (min, max,
   granularity); supported NAT variants (SNAT, DNAT, both); and
   supported overlay encapsulations (VXLAN, GENEVE, … — only
   the ones the user actually intends to use). Quote each
   queried value back to the user; do not assume from prior
   installs. If any axis says *not supported*, that axis is
   the answer — either change the CT design to fit the
   advertised set or pick a different device.
3. **Size the aging table to the workload's expected
   concurrent-flow count.** Per the aging-table sizing rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   the cap-advertised max concurrent flows is the ceiling and
   the user's traffic profile is the input. The agent must
   ASK the user for the expected peak concurrent connections
   (not invent a number) and the expected idle-connection
   profile (which sets the aging timer). If the user's
   estimate exceeds the ceiling, surface the device-fit
   problem before any `doca_flow_ct_*` setup call.
4. **Create the `doca_flow_ct` Core context against the
   already-up doca-flow port.** This is a standard DOCA Core
   context create — the universal lifecycle from
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure)
   applies. The `doca_flow_ct` is per-port: a host driving CT
   on more than one port needs one `doca_flow_ct` per port,
   not a *"global"* one, per the per-port-context rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
5. **Configure aging-timer + NAT-variant settings within the
   cap-advertised ranges, then start the CT context.** Start
   the `doca_flow_ct` via `doca_ctx_start()` — this is the
   moment CT entries become possible to add on the wrapped
   pipes. Per the layering rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   record the order so teardown happens in reverse: stop the
   `doca_flow_ct` → destroy the `doca_flow_ct` → only then
   touch the doca-flow port teardown (which lives in
   [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)).
6. **Sanity check before any CT entry add.** Confirm with the
   user: which doca-flow port the CT context is attached to;
   which doca-flow pipe(s) the CT-aware builder will wrap;
   which 5-tuple shape the CT entries will use (and VRF / VNI
   if overlay); which NAT variant (if any) the entries apply;
   how the agent will know the CT plane is working (which
   per-CT-entry counter, which state transition). If any of
   those are unclear, stop and ask — do not invent.

If any step fails with a `DOCA_ERROR_*`, route through the CT
error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: compile a CT-using consumer against the user's installed
DOCA, with `pkg-config` as the source of truth for include + link
flags, and with `doca-flow` linked alongside `doca-flow-ct`
because CT cannot run without its base layer.

The build pattern for any DOCA C/C++ consumer is fully documented
in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the CT-specific overlay:

| Slot | Value | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-flow-ct` (the CT companion library) — AND `doca-flow` (the base layer) — both are required | Linking only `doca-flow-ct` without `doca-flow` produces `undefined reference` errors for the base-layer symbols CT depends on; the agent must surface that both modules are required |
| Include flags | `pkg-config --cflags doca-flow-ct doca-flow` | Resolves DOCA headers under the installed infrastructure include path for both layers in one pass |
| Link flags | `pkg-config --libs doca-flow-ct doca-flow` | Pulls in the CT companion library plus the base doca-flow library plus the common DOCA library; the ordering is handled by `pkg-config`, do not hand-craft the `-l` list |
| Version anchors | `pkg-config --modversion doca-flow-ct` AND `pkg-config --modversion doca-flow` MUST agree, AND both MUST agree with `doca_caps --version` | doca-flow-ct rides the doca-flow version per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility); disagreement is a partial-install hazard. Route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Companion DOCA libs | `doca-argp` for arg parsing (if the consumer uses the standard DOCA arg style); the cross-library `doca-common` is pulled in transitively | Adding unnecessary companion libs bloats the link line and obscures real partial-install issues |
| Build flavor | Start with the trace flavor for the first run (`doca-flow-trace` + the CT-trace `.pc` if shipped) so the inspector dump is verbose, then switch to release | Same rule as base doca-flow: validate the steering plane before optimizing the link line for production |

For non-C consumers (Rust, Go, Python), the wrapper consumes
`libdoca_flow_ct.so` (and `libdoca_flow.so`) through FFI; the
build-time version visibility goes through the language's own
FFI generator (e.g. `bindgen` against the doca-flow-ct headers,
which depend on the doca-flow headers). The layering rule and
capability-discovery rules still apply — the wrapper consumes
two `*.so` files that each have their own runtime version per
[`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility),
and the wrapper must surface the version-pair to the user.

## modify

Goal: take the closest-fitting shipped DOCA Flow CT sample as
the verified starting point and apply a **minimum diff** to make
it match the user's intent, without rewriting from scratch and
without rewriting the underlying doca-flow setup the sample
already wires up.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
this skill provides the CT-specific slot fill.

| Slot | What the agent asks the user | CT-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_flow_ct/`? | Pick a sample whose **shape** matches the user's intent: same 5-tuple match shape, same NAT variant (or none), same overlay variant (or none). The CT samples assume a working doca-flow setup in their own code; do not strip that out — it is part of the verified base |
| 2. doca-flow base layer in the sample | Is the user replacing the sample's doca-flow port / pipe with their own, or layering CT on top of the sample's existing doca-flow setup? | If the user already has a doca-flow setup they want to keep, the minimum-diff move is to PORT the sample's CT logic onto their setup, not to replace their setup with the sample's. Per the layering rule in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), CT extends doca-flow — the agent must not propose rebuilding the user's doca-flow setup from scratch unless the user explicitly asks for it |
| 3. 5-tuple match shape | What 5-tuple is the user matching on, and is there a VRF / VNI? | Per the 5-tuple table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), CT match is 5-tuple plus VRF / VNI for overlay scenarios. A modify pass that drops a field (e.g. *"just match by source IP"*) is not a CT pass at all — surface that and route back to [`doca-flow`](../doca-flow/SKILL.md) if the user does not need state |
| 4. NAT variant | Is the user applying SNAT, DNAT, both, or none? Was the variant confirmed via the cap query? | Per the NAT action table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), each NAT variant has its own capability axis. Adding a NAT variant the device does not advertise returns `DOCA_ERROR_NOT_SUPPORTED` at entry add — re-run the cap query before the modify lands |
| 5. Aging-timer setting | Is the aging timer the sample uses appropriate for the user's workload's idle profile? | Per the aging-table sizing rule in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy), the cap-advertised range is the constraint and the user's workload is the input. Changing the sample's default aging timer is fine; setting one outside the cap range is `DOCA_ERROR_INVALID_VALUE` at configure |
| 6. Re-validate against capabilities | Re-run the `doca_flow_ct_cap_*` queries from [`## configure`](#configure) step 2 against the modified configuration — flow-count growth, aging-range growth, NAT variant change, overlay change all flip a capability boundary | Per the cross-cutting rule in [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability), the cap query is the runtime authority |
| 7. Re-validate the wrapped pipe | The wrapped doca-flow pipe must still pass `doca_flow_pipe_validate` after the CT-aware modification | Per the validate-before-commit rule owned by [`doca-flow CAPABILITIES.md ## Safety policy`](../doca-flow/CAPABILITIES.md#safety-policy), validation is mandatory on every spec change — including the CT-wrapping change. Do not skip |

The agent emits an *intent description + the seven filled slots*;
the *actual* unified diff against the sample source is produced
the way every other library skill in this bundle handles modify
— the agent walks the user through the diff line-by-line against
the sample source they read on disk, and has the user paste back
the result for validation. The agent's anti-pattern alert: a
*"clean rewrite"* from scratch is almost always slower to first
green than a minimum-diff modify on a shipped CT sample, and
removes the user's ability to bisect against a known-good
baseline.

## run

Goal: actually start the CT context on top of the already-running
doca-flow setup, add CT entries in a staged fashion, and confirm
the per-CT-entry counters and state transitions report the
expected behaviour.

Steps the agent should walk the user through:

1. **Confirm the underlying doca-flow layer is running** before
   any CT entry add. The doca-flow port must be started and
   the wrapped pipe must have been validated and started per
   [`doca-flow TASKS.md ## run`](../doca-flow/TASKS.md#run). A
   CT entry add against a doca-flow pipe that is not started
   returns `DOCA_ERROR_BAD_STATE` and the fix is not in this
   skill — it is in [`doca-flow`](../doca-flow/SKILL.md).
2. **Start the `doca_flow_ct` via `doca_ctx_start()`.** Per the
   layering rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   `doca_ctx_start()` on the `doca_flow_ct` is the moment the
   CT plane becomes live on the port; before this point the
   context exists but the dataplane is still purely stateless.
   A successful start does NOT yet imply any connection is
   being tracked — that needs CT entries added and traffic
   matching them.
3. **Add CT entries in a staged fashion.** Per the safety
   policy in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   layering-rule table row 3, stage ONE CT entry first on a
   controlled 5-tuple, send ONE matching packet, read the
   per-CT-entry counter, and confirm the state transitions
   reported on the entry are what the user expects. Only
   widen to bulk add after the single-entry smoke is green.
   Bulk-adding to a CT table on first run is the canonical
   way to discover an aging-timer / NAT-conflict / 5-tuple
   bug on N entries instead of on one.
4. **Drive the host-side `doca_pe_progress` loop** in parallel
   so any CT-side completions / events flow through the
   progress engine. A host that starts the CT context and
   then blocks without progressing the PE will see no events
   and conclude the CT plane is broken incorrectly. This is
   the cross-library *"PE not progressed"* failure mode
   applied to CT.
5. **Capture the structured log on first failure.** Set
   `DOCA_LOG_LEVEL=trace` for the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability));
   the CT-layer trace lines plus the underlying doca-flow
   trace lines together describe the lifecycle ordering and
   the entry-add results. If the log is silent and the
   counters do not move, route to [`## debug`](#debug).

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove a CT consumer is correct end-to-end on top of the
user's already-working doca-flow setup, on the user's installed
DOCA + device + permissions, before claiming the *"add CT to my
doca-flow pipeline"* journey is done.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the layering precondition, the 5-tuple match shape, the
aging-timer setting, the NAT translation correctness, or the
device-fit envelope. The loop terminates when either (a) the
user observes the CT plane tracking the intended connections
and the intended NAT translations on the wire with the expected
per-CT-entry counters and state transitions, or (b) the agent
has narrowed the failure cause to a layer outside CT itself
(underlying doca-flow misconfiguration, device-fit problem,
DOCA install, kernel / driver) and escalated to the matching
skill.

Iteration shape:

1. **Single-flow smoke.** Add ONE CT entry for a controlled
   5-tuple, send ONE matching packet end-to-end, confirm: the
   `doca_flow_ct_*` add call succeeds; the per-CT-entry
   counter increments for the forward direction; the state
   transitions reported on the entry match the user's
   expectation (new → established for a TCP handshake, or
   directly established for a UDP first-packet). If yes,
   advance. If no, route to [`## debug`](#debug). Per the
   safety-policy rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   DO NOT scale a broken single-flow smoke into a bulk add.
2. **Multi-flow smoke.** Add 10-100 CT entries for distinct
   5-tuples (still well below the device's cap-advertised
   ceiling), send matching traffic on each, confirm every
   per-entry counter moves and every entry reaches the
   expected state. Catches per-entry bugs that the single-flow
   smoke cannot (e.g. table-key hashing collisions, off-by-one
   in the 5-tuple shape).
3. **Aging smoke.** Add a small set of CT entries, idle them
   past the configured aging timer, confirm they are evicted
   (per [`## Observability`](../doca-flow/CAPABILITIES.md#observability)
   for the base-layer counter visibility, and per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
   for the CT-entry visibility). Then re-add and confirm new
   entries can be created. Catches aging-timer
   misconfiguration BEFORE the user discovers it in production
   as *"connections drop after N seconds of idle"*.
4. **NAT-aware smoke (if NAT is in scope).** Add a CT entry
   with the NAT variant the user picked, send traffic in
   both directions, confirm the forward direction is
   translated as configured AND the reverse direction is
   translated symmetrically. Catches NAT-translation
   conflicts and asymmetry bugs that a state-only CT smoke
   cannot.
5. **Negative test — capability mismatch.** Intentionally
   request a NAT variant the agent expects to be *not
   supported* on this device (per the cap query in
   [`## configure`](#configure) step 2) and confirm the
   reported `DOCA_ERROR_NOT_SUPPORTED` matches the cap-query
   answer. Validates the agent's capability discovery is
   correct.
6. **Sustained-run loop.** Let the validated CT setup run for
   a sustained period (minutes, not seconds) under
   representative traffic and confirm: no spurious connection
   drops (aging-timer is appropriately sized); no
   `DOCA_ERROR_FULL` on new entry add (table is appropriately
   sized for steady-state concurrency); per-CT-entry counters
   continue to track real on-wire activity. Catches
   sizing-envelope bugs that a short smoke cannot.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Single-flow smoke counter does not increment | CT entry was added but the 5-tuple does not match the on-wire packet (wrong byte order, wrong IP version, wrong VRF / VNI in overlay) | Re-read the on-wire 5-tuple via the underlying doca-flow inspector trace per [`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug); fix the 5-tuple shape; loop back to single-flow smoke |
| Multi-flow smoke partially passes | Some entries fire counters, some do not, OR `DOCA_ERROR_FULL` is hit well below the cap-advertised ceiling | Re-check whether the user's flow-count estimate matched the per-port or per-CT-context cap axis (these can differ on some devices); re-run the cap query; re-size if needed |
| Aging smoke evicts entries before idle threshold | Aging timer is shorter than the user thinks it is, OR the timer's granularity rounds down on this device | Re-read the cap-advertised aging-timer range AND granularity; pick a timer that survives the rounding; loop back to aging smoke |
| NAT-aware smoke fails reverse direction | The reverse translation is not being applied — typically because the wrapped pipe does not see the reverse direction, OR the NAT variant chosen does not include reverse translation on this device | Check the wrapped pipe in the underlying doca-flow layer for symmetric match (route to [`doca-flow TASKS.md ## test`](../doca-flow/TASKS.md#test)); re-check the NAT variant cap query for combined / reverse support |
| Sustained-run loop drops connections at steady state | Aging timer under-provisioned for the workload's true idle profile, OR table at capacity and aging cannot keep up | Re-walk the aging-table sizing rule in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy); either lengthen the aging timer (if device-fit allows), or pick a device with a higher concurrent-flows ceiling |
| Same CT setup passes on host A, fails on host B | Different DOCA version (doca-flow-ct + doca-flow version-pair must match) OR different device capability set | Re-run the version chain per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) four-way match on host B; re-run the CT cap queries on host B against the active `doca_devinfo` |

Loop termination: stop iterating once two consecutive iterations
of the same kind do not change the picture — that means the
cause is below CT (underlying doca-flow misconfiguration,
device-fit gap, DOCA install, kernel / driver). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured CT-layer trace, the cap-query baseline, and
the per-CT-entry counter snapshots as evidence.

## debug

Goal: when a `doca_flow_ct_*` call (or the CT plane in motion)
returns a `DOCA_ERROR_*` or does not behave as expected, narrow
the cause to a specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending CT-specific
fixes. This skill's overlay names the CT-specific manifestation
at layers 5 (runtime), 6 (program), and 7 (driver):

**Layer 5 (runtime) — CT overlay.**

- `DOCA_ERROR_BAD_STATE` on the first CT call is *almost
  always* a layering violation: the underlying doca-flow port
  is not yet started, OR `doca_ctx_start()` on the
  `doca_flow_ct` was skipped, OR a CT entry is being added
  before the wrapped doca-flow pipe is started. Walk the
  layering rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy);
  verify the doca-flow lifecycle in
  [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)
  is complete; verify the CT lifecycle in
  [`## configure`](#configure) is in order.
- `DOCA_ERROR_FULL` (or `DOCA_ERROR_NO_MEMORY`) on CT entry
  add is *always* a sizing / aging issue, never a CT API bug.
  Re-read the cap-advertised max concurrent flows; read the
  per-CT-entry counters to identify idle entries that aging
  has not yet evicted; either wait for aging or shorten the
  aging timer (within the cap-advertised range) so steady-
  state churn frees table space. If the workload genuinely
  needs more concurrent flows than the device supports,
  surface the device-fit gap — do not paper over with a
  retry loop.
- *"CT entries exist but the counter does not increment"* is
  *almost always* a 5-tuple mismatch (wrong byte order, wrong
  IP version, wrong protocol, wrong VRF / VNI on overlay).
  Reach for the underlying doca-flow inspector trace per
  [`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug)
  to see what the device thinks the on-wire 5-tuple is; the
  diff between the user's mental model and the trace is the
  bug.

**Layer 6 (program) — CT overlay.**

- Lifecycle ordering: the `doca_flow_ct` must be stopped and
  destroyed BEFORE the underlying doca-flow port is stopped.
  Out-of-order returns `DOCA_ERROR_BAD_STATE` per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
  The most common case is tearing down the doca-flow port
  while a CT context is still attached and running.
- Translation conflict: `DOCA_ERROR_INVALID_VALUE` on CT entry
  add with a NAT action is *almost always* a translation that
  collides with an existing CT entry (two entries cannot map
  the same translated 5-tuple to two different connections).
  Per the safety policy in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
  do NOT invent a different translation to resolve the
  conflict — surface it to the user as a policy bug.
- Aging-timer out of range: `DOCA_ERROR_INVALID_VALUE` at
  configure time on the aging-timer set means the requested
  timer is outside the cap-advertised range OR violates the
  cap-advertised granularity. Re-read the cap query for the
  aging-timer axis; pick a timer that fits both the range and
  the granularity.
- `DOCA_ERROR_IN_USE` on CT entry remove means traffic in
  flight is still referencing the entry; quiesce the affected
  5-tuple (or wait for the aging timer to evict the entry
  naturally), then retry. Do not force-remove.

**Layer 7 (driver) — CT overlay.**

- `DOCA_ERROR_NOT_SUPPORTED` on `doca_flow_ct` create with
  `doca_dev` access otherwise fine, and with a doca-flow port
  already up successfully on the same device, means the
  device + firmware combo does not advertise the CT axis (or
  the specific NAT variant / overlay encapsulation the user
  asked for). Re-run the matching `doca_flow_ct_cap_*` query;
  surface BOTH the DOCA version installed AND the device's
  advertised CT capability set. If the device truly does not
  support CT, the answer is the hardware, not a DOCA upgrade.
- A `DOCA_ERROR_DRIVER` from a `doca_flow_ct_*` call is the
  driver layer reporting failure to DOCA. Capture
  `pkg-config --modversion doca-flow-ct`, `pkg-config
  --modversion doca-flow`, and `doca_caps --version`;
  cross-check the version pair per
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility);
  route to
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5 (driver).

Once the layer is identified, route to the matching debug verb
on the matching skill: install / build / link / driver to
[`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
version to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug);
base-layer Flow surface to
[`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug).

## Command appendix

Every command below is **cross-cutting on DOCA Flow CT** — it
answers a recurring class of question that comes up in the verbs
above. The agent should treat the *class* as load-bearing; the
worked example is a single instance. Run-as user is the
unprivileged user unless noted; sudo is called out per row.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the
   row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-flow-ct` | [`## configure`](#configure) step 1; [`## build`](#build) version-anchor slot | What is the build-time DOCA Flow CT version? | A semver string matching `pkg-config --modversion doca-flow` and `doca_caps --version`. Any disagreement is a partial-install hazard; route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| `pkg-config --cflags --libs doca-flow-ct doca-flow` | [`## build`](#build) | What include + link flags does the linker need for the CT + base-layer pair? | Includes resolve under the installed DOCA infrastructure include path; libs include the CT companion plus the base doca-flow library plus the common DOCA library. Hand-typed `-l` lines or linking only one of the pair are the failure modes |
| `ls /opt/mellanox/doca/samples/doca_flow_ct/` | [`## modify`](#modify) slot 1 | Which CT samples ship in this install, and which is the closest starting point? | A list of sample directories that each contain a CT-aware companion to a doca-flow sample shape (5-tuple match, NAT variant, overlay variant). Each sample assumes a working doca-flow setup in its own code |
| `doca_caps --list-devs` (cross-check against the CT cap-query family) | [`## configure`](#configure) step 2 | Which DOCA devices does the host see, and which advertise CT capability? | One entry per `doca_dev` with the device identity and the per-library capability flags; the CT-axis flags answer max concurrent flows, aging-timer range, NAT variants, overlay encapsulations. No CT-capable entry on a device the user expected to work = route to [`doca-setup`](../../doca-setup/SKILL.md) |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run) step 5 | What did the structured DOCA logger emit for the first failing CT call? | Trace-level lines on every CT-layer lifecycle transition and every entry add / remove. Silence after `doca_ctx_start()` on the `doca_flow_ct` = either PE not progressed OR the CT plane is not yet seeing traffic — reach for the base-layer inspector next |
| `dmesg \| tail -n 40` (sudo) | [`## debug`](#debug) layer 7 | What did the kernel / driver log around the last CT call? | Empty or recent benign messages. Repeated mlx5 / Flow-driver errors → driver-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug). Repeated *"CT table full"* or *"NAT translation conflict"* in the structured DOCA log → application-side fix per [`## debug`](#debug) layer 5-6 |
| Per-CT-entry counter read (via the CT API surface, owning step [`## debug`](#debug) step 1) | [`## test`](#test) step 1; [`## debug`](#debug) layer 5 | Is the suspected CT entry actually matching on-wire traffic? | A non-zero counter under expected traffic. Zero = 5-tuple mismatch; reach for the underlying doca-flow inspector trace via [`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug) |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the CT-specific rows on top. The base-layer
doca-flow commands (port enumeration, pipe validation, Flow
inspector dump) live in
[`doca-flow TASKS.md ## Command appendix`](../doca-flow/TASKS.md#command-appendix)
and are referenced from there, not duplicated here.

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as follows
so the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the install-tree
  layout in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed and that the
  base doca-flow is already brought up on the target port.
- **deploy.** Deploying CT-using firewall / NAT applications at
  scale (many BlueField nodes, coordinated CT-state failover,
  Kubernetes operator workflows) — out of scope for Phase 1 and
  reserved for a future platform skill. For single-host first-run
  testing, the right verb in this skill is [`## run`](#run); do
  not invent a "deploy" workflow.
- **rollback.** Coordinated CT-plane rollback across multiple
  DPUs and host nodes — out of scope for Phase 1 and reserved
  for a future platform skill. For single-DPU CT-entry rollback
  within a session, the right verb in this skill is
  [`## modify`](#modify) with a delta that removes the offending
  entries; do not invent a "rollback" workflow.
- **firewall / NAT policy design.** Designing the security
  policy itself (which connections to allow, which subnets to
  NAT to which public IPs, how long is the right aging timer
  for the user's workload) — out of scope. Route to the user's
  own networking / security expertise; this skill prescribes
  how to *track and apply* policy, not how to *write* policy.
- **stateless steering.** Owned by
  [`doca-flow`](../doca-flow/SKILL.md). When the user's intent
  does not need per-connection state, the right answer is to
  stay in doca-flow alone; do not pull CT in for a stateless
  workload.
