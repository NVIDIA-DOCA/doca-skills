# DOCA Switching workflows

**Where to start:** The verbs run `configure → build → modify → run
→ test → debug`. Skip ahead only when the user is already past a
verb. The `## test` verb is an iterative loop (smoke → bridge-pair
→ expand → loop back if the topology spec changed), not a one-shot
pass — see the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the switching capability surface, the
topology-vs-rules layering rule, port-type taxonomy, mode axis,
capability-query rule, error taxonomy, observability, and safety
policy (especially the high-stakes mode-transition rule), see
[CAPABILITIES.md](CAPABILITIES.md). For the cross-library DOCA
patterns layered under everything below (the universal lifecycle,
the cross-library `DOCA_ERROR_*` taxonomy, the
modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through the
steps in order, verifying preconditions before recommending the
next call.

## configure

Goal: stand up a switching context against a BlueField that is
already in the right mode for the intended topology, with the port
set enumerated and the capability surface understood — *before* any
bridge or table primitive is committed.

Steps the agent should walk the user through:

1. **Confirm the env preconditions.** The BlueField must be
   reachable (the host sees its PCIe address) and must be in the
   mode the topology assumes. Per the runtime-mode table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   run `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` (sudo) and
   confirm the BlueField is in the mode the user intends *before*
   any switching API call. If the mode is wrong, **stop and route
   to** [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
   for the env-side reconfiguration steps — and warn the user
   explicitly that a mode change typically requires firmware
   reconfiguration and a reboot per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
2. **Confirm the installed DOCA version.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   (do not duplicate it here). Quote `pkg-config --modversion
   doca-switching` back to the user; do not assume "latest".
3. **Discover switching capabilities.** Run the
   `doca_switching_cap_*` family against the active `doca_devinfo`
   per the capability-query rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   Record: max ports, supported port types (PF / VF / SF /
   representor), supported switching modes, supported overlay
   encapsulations. **The agent must quote the queried values back
   to the user, not assume them from prior installs.** When a
   structured helper is present, prefer it per the contract in
   [`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract).
4. **Enumerate the port set.** Confirm with the user which
   port objects (PFs / VFs / SFs / representors) are expected on
   this BlueField generation in the active mode, then walk the
   switching-context's port enumeration to confirm they are
   visible. A representor that the user expects but is missing
   from the enumeration is almost always an env-side problem
   (host-side SR-IOV or SF setup) — route to
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
   before any switching-program change.
5. **Sketch the topology before committing any primitive.** Which
   ports belong to which switching domain / bridge? Which
   representors will `doca-flow` rules later target? Restate the
   intent back to the user in plain language; if any port
   association is unclear, **stop and ask** — do not invent.
6. **Start the switching context** via the universal DOCA Core
   lifecycle (`doca_ctx_create → ... → doca_ctx_start`) per
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
   The switching context follows the same lifecycle as every
   other DOCA Core context; this skill adds the switching
   overlay (mode preconditions, port enumeration, cap discovery),
   it does not re-explain the lifecycle.

If any step fails with a `DOCA_ERROR_*`, route through the
switching error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying. `BAD_STATE` here is especially load-bearing — it
can mean a lifecycle violation OR a switching-mode mismatch, and
the two have very different fixes.

## build

Goal: compile a switching-using consumer against the user's
installed DOCA, with `pkg-config` as the source of truth for
include + link flags.

The build pattern for any DOCA C/C++ consumer is fully documented
in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the switching-specific overlay:

| Slot | Value | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-switching` on installs that ship the library | Wrong module name = `pkg-config: Package 'doca-switching' was not found`. If the install does not surface the `.pc`, the library is not on this DOCA release — route to [`doca-version`](../../doca-version/SKILL.md) before assuming a wrong build env. |
| Include flags | `pkg-config --cflags doca-switching` | Resolves to headers under `/opt/mellanox/doca/infrastructure/include/` for the switching subset. |
| Link flags | `pkg-config --libs doca-switching` | Pulls in the switching `.so` and transitively `doca-common`. |
| Companion libraries | `doca-argp` for argument parsing (when the consumer uses the standard DOCA arg style); `doca-flow` only if the consumer programs steering rules on top of the configured topology in the same binary (the more common pattern is two separate programs — topology configuration first, flow rule programming second) | Adding `doca-flow` to a topology-only program bloats the link line and obscures real partial-install issues |

For non-C consumers (Rust, Go, Python), the wrapper consumes
`libdoca_switching.so` through FFI; the build-time version
visibility goes through the language's own FFI generator (e.g.
`bindgen` against the switching headers). The topology-vs-rules
layering, mode-transition safety, and capability-discovery rules
still apply — the wrapper consumes a `*.so` that has its own
runtime version per
[`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).

## modify

Goal: take the closest-fitting shipped switching sample and apply a
**minimum diff** to make it match the user's intended topology,
without rewriting from scratch.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
this skill provides the switching-specific slot fill.

| Slot | Value | Source |
| --- | --- | --- |
| Sample tree | `/opt/mellanox/doca/samples/doca_switching/<name>/` when present on the install | Confirmed by `ls /opt/mellanox/doca/samples/doca_switching/`. If the directory is absent on this DOCA release, route the user to the [DOCA Switching public guide](https://docs.nvidia.com/doca/sdk/DOCA-Switching/index.html) for the version-matching reference code; do not author switching code from documentation prose. |
| Pick the closest sample | Match the user's intent (basic port enumeration; bridge-pair setup; representor-mapping configuration; overlay-aware switching) to a sample whose code shape already matches | Per the port-type and primitives tables in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Identify the modify surface | The port-enumeration body; the bridge / switching-table allocation calls; the representor-association calls; the per-port property setters | These are the in-place edit points; do not introduce a new translation unit unless the sample is being split for clarity |
| Re-validate against capabilities | Re-run the `doca_switching_cap_*` queries from [`## configure`](#configure) step 3 against the modified topology — adding a new port type, changing the switching mode, or enabling a new overlay encap each flips a capability boundary | Per the cross-cutting rule in [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility), the cap query is the runtime authority |
| Plan the layered work | After the switching topology compiles and passes the smoke in [`## test`](#test), the *next* programming task is typically writing `doca-flow` rules that target the configured representors — route the user to [`doca-flow TASKS.md ## configure`](../../doca-flow/TASKS.md#configure) at that point, not before | Per the layering rule in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes): substrate first, steering on top |

The agent's anti-pattern alert: a *"clean rewrite"* of the switching
topology from scratch is almost always slower to first green than a
minimum-diff modify on a shipped sample, and removes the user's
ability to bisect against a known-good baseline — *especially*
dangerous on the switching surface, where a wrong topology takes
traffic offline rather than just producing a runtime error.

## run

Goal: actually commit the validated switching topology to the
BlueField and observe that the configured ports behave as the
topology expected.

Steps the agent should walk the user through:

1. Confirm [`## test`](#test) (smoke + capability cross-check) has
   passed for the current topology spec; do not enter `run` from
   an un-smoked spec. The switching plane carries production
   traffic — un-smoked topologies are the cause of the most
   expensive outages.
2. Commit the switching topology via the switching context's
   start / commit primitives per the universal lifecycle in
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
   The switching context follows the same lifecycle as every
   other DOCA Core context.
3. **Verify port and bridge state on the device** before declaring
   the topology live. Use the env-side and switching-context
   observables from
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability):
   port enumeration matches the spec; switching-table inspection
   reports the bridge entries the program intended; representors
   are visible on `/sys/class/net/` on the DPU.
4. **Run the smoke before any steering work.** Push controlled
   traffic through the configured bridge / representor pair (e.g.
   `tcpdump` on a representor + a small generator on the host
   PF) and confirm the packet path is what the topology says it
   should be — *before* any `doca-flow` rules are programmed on
   top. Once the smoke passes, route the user to
   [`doca-flow TASKS.md ## configure`](../../doca-flow/TASKS.md#configure)
   for the steering layer.
5. **If a port refuses to start with `DOCA_ERROR_IN_USE`**, that
   port is carrying traffic from a prior configuration. The fix
   is *not* to retry — see the live-port reconfiguration rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   and the matching row in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove a switching topology is correct end-to-end, on the
user's installed DOCA + BlueField generation + permissions, before
either declaring the topology done OR layering `doca-flow` rules
on top.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the port set being exercised, the mode assumption, or the
bridge-association assumption. The loop terminates when the user
reports a single-packet smoke AND a multi-packet bridged-pair run
both work AND the env-side and API-side observables agree on what
ports exist and what bridges them.

Iteration shape:

1. **Capability cross-check.** Re-confirm every port type and
   switching mode in the committed topology is supported by the
   active BlueField + firmware via the `doca_switching_cap_*`
   queries from [`## configure`](#configure) step 3. The user's
   first instinct when a topology call fails is to blame the
   code; the cap query is the cheapest way to disprove that.
2. **Smallest viable topology smoke.** One bridge, one
   representor pair (one host PF → one DPU representor), no
   `doca-flow` rules on top. Push a single packet through;
   confirm it reaches the representor via `tcpdump`. If it does
   not, the topology is wrong — do not blame the packet generator
   first.
3. **Expand to the intended port set.** Add the additional
   representors / VFs / SFs the topology requires. Re-run the
   smoke at each expansion step. Catches latent capacity errors
   (`NOT_SUPPORTED` / `INVALID_VALUE`) that the minimal smoke
   never tripped.
4. **Env-side and API-side observability diff.** Confirm the
   switching-context's port enumeration matches the env-side
   readout (`ls /sys/class/net/`, `lspci`, `mlxconfig`). A
   divergence between the two is a real topology hazard, not a
   reporting glitch.
5. **Cross-version run** (if the user has multiple installs):
   re-run steps 1-4 on each install; quote the version per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   in the report.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Cap query passed; minimal smoke fails on packet path | Topology spec wrong (the bridge association is not what the user thought it was) | Re-run step 2 with switching-table inspection from [`## Observability`](CAPABILITIES.md#observability); diff the actual bridge entries against the user's mental model |
| Minimal smoke passed; expansion fails with `NOT_SUPPORTED` | The added port type is not supported on this BlueField generation | Re-run step 1 cap query against the active `doca_devinfo`; do not retry the same expansion on the same device |
| Expansion passed; observability diff shows a missing representor | Env-side and switching-context disagree — host-side SR-IOV / SF setup may be incomplete | Route to [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure) for the env-side fix; the switching program is not the bug |
| Cap query says feature supported; runtime call returns `NOT_SUPPORTED` | DOCA version mismatch — `pkg-config` and `doca_caps` disagree, or BlueField firmware predates the feature | Run the four-way version match per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test); fix the partial install before any program change |
| Same topology spec passes on host A, fails on host B | Different DOCA version, different BlueField generation, or different mode | Re-run [`## configure`](#configure) step 1 (mode check) + step 3 (cap discovery) on host B; do not assume the topology transfers |

Loop termination: stop iterating once two consecutive iterations
do not change the picture — the cause is below the switching API
(firmware, hardware, env). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured trace + version state + mode state as evidence.

## debug

Goal: when a switching topology call fails, isolate the cause to a
single layer (env / mode / version / lifecycle / live-port /
firmware) before recommending any code change.

> **Routing summary.** This anchor is the **switching-specific
> debug overlay**: the `DOCA_ERROR_*` switching disambiguation,
> the mode-vs-flow boundary call, the topology-vs-steering
> diagnosis. For the **cross-cutting debug ladder** (install /
> version / build / link / runtime / program / driver) plus the
> cross-cutting tooling surface (`gdb`, `valgrind`,
> `--sdk-log-level`, container-vs-native debug, core dumps, the
> Developer Forum escalation), see
> [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
> The agent should walk the cross-cutting ladder first whenever
> the symptom layer is not yet known; this switching overlay
> layers on top once the symptom is confirmed to be inside the
> Switching API surface.

Walk in this order — do not skip steps:

1. **Disambiguate `BAD_STATE` first.** `DOCA_ERROR_BAD_STATE` on
   a switching call has two distinct causes per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy):
   (a) lifecycle violation, and (b) **switching-mode mismatch**
   (the call requires switch mode but the BlueField is in NIC
   mode, or vice versa). Step 1 is *always* to re-run the
   `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` check from
   [`## configure`](#configure) step 1 — most "lifecycle"
   reports are actually mode mismatches in disguise.
2. **Is this a topology question or a steering question?** When
   the symptom is "the packet didn't end up where I expected",
   the cause is in one of two layers: the switching topology
   (this skill) or the `doca-flow` steering rules (route to
   [`doca-flow TASKS.md ## debug`](../../doca-flow/TASKS.md#debug)).
   The disambiguation: run the smoke from
   [`## test`](#test) step 2 *without any flow rules*. If the
   packet still doesn't reach the representor, the topology is
   wrong. If it does, the topology is fine and the bug is in the
   flow layer.
3. **`NOT_PERMITTED` is always env-side.** Switching calls require
   privilege; the program is not the bug. Route to
   [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
   for the env-side fix.
4. **`NOT_SUPPORTED` is a cap-query failure waiting to happen.**
   The user assumed a feature the device does not advertise.
   Re-run the matching `doca_switching_cap_*` query against the
   active `doca_devinfo`; do not retry the same call hoping for
   a different answer.
5. **`IN_USE` is a traffic-disruption warning.** A port the user
   wants to reconfigure is carrying live traffic. Surface the
   implication *before* recommending a quiesce-and-retry; do not
   paper over `IN_USE` with a blind retry loop. The safety policy
   in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   names this case explicitly.
6. **Version sanity.** If a previously working topology now fails
   or behaves differently, confirm the installed DOCA version
   and the BlueField firmware did not change. The four-source
   version-coherence check is owned by
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
   the firmware-version check is owned by the env side
   ([`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)).
   Switching is unusually sensitive to firmware changes — a BFB
   reflash between sessions can shift the supported port-type
   and mode set silently.
7. **Escalation criteria.** If the cap query says the feature is
   supported AND the mode is correct AND the version is unchanged
   AND the env-side observables agree AND the topology still
   fails, the bug is below the Switching API surface (driver or
   firmware). Stop attempting topology spec changes; capture
   state per [`doca-debug TASKS.md ## test`](../../doca-debug/TASKS.md#test)
   (the read-only triple) and escalate via
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   to the public DOCA Developer Forum.

## Command appendix

Switching-specific commands the verbs above reach for, grouped by
purpose so the agent picks the right family without searching
prose. Every row is a class — the agent must not invent flags
beyond what the row names; the *flag-discovery* rule is `--help`
against the installed binary or `pkg-config` against the installed
`.pc`, not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env
   --json` for version + devices + mode + libraries in one shot;
   `doca-capability-snapshot` for per-device capability flags
   including switching ones; `collect-dpu-state` for the
   firmware-version + mode + representor cross-check that
   switching-mode debug needs).
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
| `pkg-config --modversion doca-switching` | [`## configure`](#configure) step 2; [`## build`](#build) slot 1 | What is the build-time DOCA Switching version? | A semver string matching `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)). |
| `pkg-config --cflags --libs doca-switching` | [`## build`](#build) | What include + link flags does the linker need? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include the switching `.so` plus `-ldoca-common`. |
| `ls /opt/mellanox/doca/samples/doca_switching/` | [`## modify`](#modify) | Which switching samples ship in this install? | A list of sample directories. Empty / missing directory = the library may not be shipped on this DOCA release; route to [`doca-version`](../../doca-version/SKILL.md). |
| `mlxconfig -d <pcie> q INTERNAL_CPU_MODEL` (sudo) | [`## configure`](#configure) step 1; [`## debug`](#debug) step 1 | What mode is this BlueField in (SmartNIC / DPU / switch)? | A single matching mode line. Mismatch with the topology assumption = the switching call will return `BAD_STATE`; the fix is env-side, not code-side. |
| `ls /sys/class/net/` (DPU side) | [`## configure`](#configure) step 4; [`## test`](#test) step 4 | Which representors are visible to the DPU? | One entry per representor (PF / VF / SF) the host has surfaced. A missing representor the user expects = env-side problem; route to [`doca-setup`](../../doca-setup/SKILL.md). |
| `lspci | grep Mellanox` (host side) | [`## configure`](#configure) step 1; [`## debug`](#debug) step 2 | Which BlueField PCIe addresses are reachable from the host? | One row per BlueField PF, plus VFs and SFs depending on configuration. |
| `tcpdump -i <rep>` (DPU side, sudo) | [`## run`](#run) step 4; [`## test`](#test) step 2 | Does traffic actually reach the configured representor under the topology? | Frames arrive on the representor under controlled traffic. Silence = topology wrong; do not blame the generator first. |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run); [`## debug`](#debug) step 1 | What did the structured DOCA logger emit for the first failing switching call? | A trace-level line on every switching-context lifecycle transition and every port-config call. Silence after a config call = PE not progressed; partial output = call returned before reaching the device. |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the switching-specific rows on top.

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them so the agent
does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring, BlueField BFB imaging — defer
  to [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **mode transition (NIC ↔ switch).** Changing the BlueField mode is
  an env-side, firmware-affecting operation (see the
  high-stakes rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy));
  the env-side `mlxconfig` + reboot workflow is owned by
  [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure)
  and the BlueField BFB workflow. This skill explains *why* the
  operation is high-stakes; it does not own the env-side steps.
- **packet steering / flow rule programming.** Once the switching
  topology is up, programming the rules that decide which packets
  go where lives in [`doca-flow`](../doca-flow/SKILL.md). This
  skill stops at the topology boundary and routes the user to
  [`doca-flow TASKS.md ## configure`](../../doca-flow/TASKS.md#configure)
  for the next layer up.
- **deploy / rollback.** Coordinated switching-topology rollout
  across multiple DPUs and host nodes — out of scope for this
  skill and reserved for a future platform skill. For single-DPU
  spec rollback within a session, the right verb in this skill is
  [`## modify`](#modify) with a delta that removes the offending
  primitives.
