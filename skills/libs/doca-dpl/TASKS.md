# DOCA DPL workflows

**Where to start:** The verbs run `configure → build → modify → run
→ test → debug`. Skip ahead only when the user is already past a
verb. The `## test` verb is an iterative loop (smoke → expand →
loop back if the DPL source changed), not a one-shot pass — see
the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the DPL capability surface, the
declarative-vs-imperative layering rule, the compile-step shape,
the path-selection rule, the cap-query surface, the error
taxonomy, the observability surface, and the safety policy, see
[CAPABILITIES.md](CAPABILITIES.md). For the cross-library DOCA
patterns layered under everything below (the universal lifecycle,
the cross-library `DOCA_ERROR_*` taxonomy, the
modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: stand up a DPL authoring + runtime environment on a host
where DOCA is installed, with the user clear on the
declarative-vs-imperative layering and the compile / load / run
split — *before* any DPL source is written.

Steps the agent should walk the user through:

1. **Restate the layering rule out loud.** DPL is the
   *declarative* authoring surface; doca-flow is the *imperative*
   C API DPL compiles down to; the BlueField runs the generated
   doca-flow programming. Per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   the agent must teach this BEFORE any source is written; an
   agent that skips this step will misanswer every later
   capability and debug question. If the user's actual need is
   raw imperative pipe programming, **stop and route to**
   [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)
   — DPL is the wrong tool for that.
2. **Confirm the installed DOCA version.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   (do not duplicate it here). Quote `pkg-config --modversion
   doca-dpl` back to the user; do not assume "latest". Per the
   DPL overlay in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility),
   surface BOTH the DPL toolchain version (compile-time) and the
   `doca-dpl` runtime library version — they must come from the
   same install.
3. **Confirm the env preconditions.** Same shape as
   [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure)
   step 3: enumerate ports, confirm representors are visible
   (`ls /sys/class/net/` on the DPU, `lspci | grep Mellanox`
   on the host), confirm the BlueField mode is what the
   pipeline assumes (per
   [`doca-switching CAPABILITIES.md ## Capabilities and modes`](../doca-switching/CAPABILITIES.md#capabilities-and-modes)
   runtime-mode table). DPL inherits all of doca-flow's env
   preconditions — it does not bypass them.
4. **Discover runtime DPL capabilities AND underlying doca-flow
   capabilities.** Run the `doca_dpl_cap_*` family AND the
   `doca_flow_cap_*` family against the active `doca_devinfo`,
   per the capability-query rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   Both sides matter: a DPL feature the *language* allows can
   still fail at load if the *device* cannot accelerate the
   doca-flow primitive the compiler will emit. When a
   structured helper is present, prefer it per the contract in
   [`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract).
5. **Sketch the pipeline declaratively before writing source.**
   Restate the user's intent in parser / match / action terms.
   ("Parse Ethernet + IPv4 + UDP; match UDP destination port;
   forward to representor X.") If any of those are unclear,
   **stop and ask** — do not invent. The declarative sketch is
   the cheapest place to surface a path-selection mistake
   (DPL vs raw doca-flow per the path-selection bullets in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)).

If any step fails with a `DOCA_ERROR_*`, route through the
DPL error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying. Locate the *stage* (compile-time vs runtime)
before suggesting a fix.

## build

Goal: produce a compiled DPL program from a DPL source file —
plus a runtime application linked against the `doca-dpl`
library — that the BlueField can load at runtime.

The build pattern for any DOCA C/C++ consumer is fully
documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
DPL has *two* build paths the agent must keep distinct: the
DPL source compile path (run by the DOCA toolchain on a DPL
source file, emitting a compiled program), and the runtime
application build path (the user's C / C++ application that
links `doca-dpl` and loads the compiled program). This
skill carries only the DPL-specific overlay for both:

| Slot | Value | Why it matters |
| --- | --- | --- |
| `pkg-config` module name (runtime app) | `doca-dpl` on installs that ship the library | Wrong module name = `pkg-config: Package 'doca-dpl' was not found`. If the install does not surface the `.pc`, the library is not on this DOCA release — route to [`doca-version`](../../doca-version/SKILL.md) before assuming a wrong build env. |
| Include flags (runtime app) | `pkg-config --cflags doca-dpl` | Resolves to headers under `/opt/mellanox/doca/infrastructure/include/` for the DPL subset. |
| Link flags (runtime app) | `pkg-config --libs doca-dpl` | Pulls in the DPL runtime `.so` and transitively `doca-common`. |
| Companion libraries (runtime app) | `doca-argp` for argument parsing (when the consumer uses the standard DOCA arg style); `doca-flow` only if the consumer also constructs imperative pipes in the same binary alongside the DPL pipeline (the more common pattern is *the DPL compiler emits all the doca-flow programming; the runtime app links only `doca-dpl`*) | Adding `doca-flow` to a DPL-only application bloats the link line and obscures real partial-install issues. |
| DPL source compile step | The DPL toolchain shipped with the install (the exact compiler invocation is install-bound; read it out of `/opt/mellanox/doca/samples/doca_dpl/<name>/` when present, or the [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html) for the release) | The compile step is what turns DPL source into the compiled program the runtime loads; it is a separate artifact in the build, NOT a flag on the application build. |

For non-C consumers (Rust, Go, Python), the wrapper consumes
`libdoca_dpl.so` through FFI; the build-time version visibility
goes through the language's own FFI generator (e.g. `bindgen`
against the DPL headers). The DPL source compile step is
language-neutral (it produces a compiled program the runtime
loads regardless of what language opens the `doca-dpl`
context). The layering rule, capability-discovery, and
compile-vs-runtime split still apply.

## modify

Goal: take the closest-fitting shipped DPL sample and apply a
**minimum diff** to make it match the user's intended pipeline,
without rewriting the DPL source from scratch.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
this skill provides the DPL-specific slot fill.

| Slot | Value | Source |
| --- | --- | --- |
| Sample tree | `/opt/mellanox/doca/samples/doca_dpl/<name>/` when present on the install | Confirmed by `ls /opt/mellanox/doca/samples/doca_dpl/`. If the directory is absent on this DOCA release, route the user to the [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html) for the version-matching reference code; do not author DPL source from documentation prose. |
| Pick the closest sample | Match the user's intent (parser shape; match keys; action set; whether the pipeline targets representors, hairpin, or counter-only) to a sample whose pipeline shape already matches | Per the authoring-surface bullets in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Identify the modify surface (DPL source side) | The parser declarations; the match field selection; the action bindings; the pipeline composition — the explicit edit points in the DPL source. Do not introduce a new DPL source file unless the sample is being split for clarity. | These are the in-place edit points in the DPL source. |
| Identify the modify surface (runtime app side) | The compiled-program path passed to the `doca_dpl` Core context at runtime, the target `doca_devinfo`, and any runtime configuration the sample's app exposes (representor selection, log level). Keep the universal Core lifecycle and the `doca_pe_progress()` loop untouched. | These are the in-place edit points in the runtime C application. |
| Re-validate against capabilities | After the DPL source edit, re-run BOTH `doca_dpl_cap_*` AND `doca_flow_cap_*` against the active `doca_devinfo` — adding a new parser stage, a new match kind, or a new action each flips a capability boundary, and the underlying doca-flow primitive must support it too | Per the two-axis cap-query rule in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Keep both build manifests unchanged | The sample's `meson.build` (or equivalent) and the DPL toolchain invocation already wire the release together; do not switch to a hand-rolled Makefile for *"simplicity"* — it removes the version-check rail | Per the build slot table in [`## build`](#build) |

The agent's anti-pattern alert: a *"clean rewrite"* of the DPL
source from scratch is almost always slower to first green than
a minimum-diff modify on a shipped sample, and removes the
user's ability to bisect against a known-good baseline —
*especially* dangerous on DPL, where the indirection between
source and generated doca-flow programming makes a
from-scratch source harder to debug than the same change
expressed as a delta on a sample.

## run

Goal: actually load the compiled DPL program at runtime and
observe that traffic does what the pipeline says it should —
on a controlled smoke first, NOT on production traffic.

Steps the agent should walk the user through:

1. Confirm [`## test`](#test) (smoke + capability cross-check)
   has passed for the current DPL source and compiled program;
   do not enter `run` from an un-smoked program. The BlueField
   hardware pipeline carries production traffic — un-smoked
   pipelines are the cause of the most expensive outages.
2. Create and start the `doca_dpl` runtime context via the
   universal DOCA Core lifecycle in
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
   The runtime context follows the same `doca_ctx_create →
   configure → doca_ctx_start → use → doca_ctx_stop → destroy`
   shape as every other DOCA Core context; this skill adds the
   DPL overlay (compiled-program path is part of `configure`;
   the program becomes live on the device at `_start`), it
   does not re-explain the lifecycle.
3. Load the compiled DPL program by passing its on-disk path
   to the runtime configuration. `IO_FAILED` here means the
   file path or permissions or version are wrong per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy);
   `NOT_SUPPORTED` here means the underlying doca-flow
   primitives the compiler emitted are not on this device.
4. **Run the single-packet smoke before any production
   traffic.** Push one controlled packet through the pipeline
   (e.g. a generator on the host PF crafted to match the
   single rule the smoke pipeline declares), then confirm with
   `tcpdump` on the target representor that the packet arrived
   where the DPL source said it should — per the smoke rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy).
5. Stop and destroy in REVERSE order at session end:
   `doca_ctx_stop` → `doca_ctx_destroy` on the `doca_dpl`
   runtime context, then close the device handle. Out-of-order
   teardown returns `BAD_STATE` from the next session's start
   on the same device.

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove a DPL pipeline is correct end-to-end, on the user's
installed DOCA + device + permissions, before scaling to a
complex pipeline OR layering the DPL pipeline into a production
deployment.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the DPL source under test, the capability axis being
exercised, or the runtime call surface. The loop terminates
when the user reports a single-packet smoke AND a multi-packet
run both work AND the generated doca-flow programming has been
read against the DPL source (the bug surface DPL's compile step
introduces).

Iteration shape:

1. **Two-axis capability cross-check.** Re-confirm both
   `doca_dpl_cap_*` (runtime DPL side) and `doca_flow_cap_*`
   (underlying primitives the compiled program will need)
   against the active `doca_devinfo` per
   [`## configure`](#configure) step 4. The user's first
   instinct when DPL fails is to blame the source; the
   two-axis cap query is the cheapest way to disprove that.
2. **Smallest viable DPL smoke.** One parser stage, one match,
   one action, one representor. Compile this minimal DPL
   source, load it via the runtime context, push ONE
   controlled packet through, confirm it lands at the expected
   representor via `tcpdump`. If it does not, the DPL source
   or the generated doca-flow programming is wrong — do not
   blame the packet generator first.
3. **Inspect the generated doca-flow programming.** Open the
   compiler's emitted doca-flow programming and diff it
   against your mental model of what the DPL source asked for.
   Per [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability),
   this is the load-bearing DPL observable; the DPL source is
   what the user authored, but the generated programming is
   what the BlueField actually runs.
4. **Expand to the intended pipeline.** Add the additional
   parser stages / matches / actions the user's real pipeline
   requires. Re-run the smoke at each expansion step. Catches
   latent capability errors (`NOT_SUPPORTED` / `INVALID_VALUE`)
   that the minimal smoke never tripped because the underlying
   doca-flow primitive count was small.
5. **Cross-version run** (if the user has multiple installs):
   re-run steps 1-4 on each install; quote the version per
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure)
   in the report. Quote BOTH the DPL toolchain version AND
   the `doca-dpl` runtime version on each install.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Cap query passed; minimal smoke fails on packet path | DPL source compiled to a generated programming that does not do what the user thought it did | Re-run step 3 — inspect the generated doca-flow programming and diff it against the DPL source. The diff IS the bug. |
| Minimal smoke passed; expansion fails with `NOT_SUPPORTED` at load | The added match / action requires a doca-flow primitive the device does not accelerate | Re-run step 1 cap query on BOTH axes against the active `doca_devinfo`; do not retry the same expansion on the same device. |
| Compile passed; load fails with `IO_FAILED` | The compiled program file path is wrong OR the runtime version disagrees with the toolchain version that produced the file | Verify the file exists and is readable; then re-run [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) to confirm the DPL toolchain version matches the runtime version. |
| Compile passed; load fails with `INVALID_VALUE` (runtime) | A parameter to the `doca_dpl` runtime call (devinfo, configuration, program path) is wrong shape | Locate the stage per [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy); fix the call site, not the DPL source. |
| Same DPL source compiles on host A, fails on host B | Different DOCA version, different BlueField generation, or different firmware on host B's device | Re-run [`## configure`](#configure) step 2 (DOCA version) + step 4 (two-axis cap discovery) on host B; do not assume the pipeline transfers. |

Loop termination: stop iterating once two consecutive
iterations do not change the picture — the cause is below the
DPL API surface (firmware, hardware, env). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured trace + version state + generated doca-flow
programming as evidence.

## debug

Goal: when a DPL pipeline fails or behaves unexpectedly,
isolate the cause to a single layer (DPL source / compile /
runtime / underlying doca-flow / firmware) before recommending
any code change.

> **Routing summary.** This anchor is the **DPL-specific debug
> overlay**: the DPL `DOCA_ERROR_*` stage disambiguation
> (compile-time vs runtime), the source-vs-generated-programming
> diff, the two-axis cap-query check, and the boundary call
> back to [`doca-flow`](../doca-flow/SKILL.md) when the bug is
> below the DPL surface. For the **cross-cutting debug ladder**
> (install / version / build / link / runtime / program /
> driver) plus the cross-cutting tooling surface (`gdb`,
> `valgrind`, `--sdk-log-level`, container-vs-native debug,
> core dumps, the Developer Forum escalation), see
> [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
> The agent should walk the cross-cutting ladder first whenever
> the symptom layer is not yet known; this DPL overlay layers
> on top once the symptom is confirmed to be inside the DPL
> API surface.

Walk in this order — do not skip steps:

1. **Locate the stage first.** Every DPL failure is *either*
   compile-time *or* runtime per
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
   Step 1 is *always* to ask: did the failure happen when the
   DPL toolchain compiled the source, or when the runtime
   loaded / started the compiled program, or when traffic
   actually hit the pipeline? The fix is different for each.
2. **Inspect the generated doca-flow programming whenever
   behavior is unexpected.** This is the load-bearing DPL
   debug rule per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   rule 2. The BlueField runs the generated programming, not
   the DPL source. If the user reports "DPL is doing
   something I didn't expect", the diff between the DPL
   source and the generated programming is the first thing
   to read. An agent that loops on "let me re-read your DPL
   source" without ever opening the generated programming
   will miss the indirection DPL's compile step introduces.
3. **`NOT_SUPPORTED` at load is a two-axis cap-query
   failure waiting to happen.** Re-run BOTH `doca_dpl_cap_*`
   AND `doca_flow_cap_*` against the active `doca_devinfo`.
   The DPL feature can be in the language; the underlying
   doca-flow primitive must also be on the device. Do not
   retry the same compiled program on the same device.
4. **`IO_FAILED` is a file or version problem.** Verify the
   compiled program file exists, is readable, and was
   produced by the same DOCA install whose runtime is loading
   it. The two-version rule (toolchain + runtime) in
   [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
   is the most-common silent cause.
5. **`BAD_STATE` is a lifecycle violation on the runtime
   context.** Walk the universal Core lifecycle per
   [`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug)
   against the user's call sequence. DPL does not invent a
   new lifecycle — it uses the universal one.
6. **When the bug is in the generated programming, escalate
   to [`doca-flow ## debug`](../doca-flow/TASKS.md#debug).**
   Once you have confirmed via step 2 that the diff between
   the DPL source and the generated programming is wrong,
   the fix is one of (a) change the DPL source so the
   compiler emits different programming, or (b) accept that
   the imperative doca-flow surface gives more control and
   bypass DPL for the offending pipe. The diagnosis (which
   doca-flow construct is wrong) lives in the
   [`doca-flow`](../doca-flow/SKILL.md) skill; this skill's
   contribution is making sure the agent does not blame the
   DPL source when the real bug is in what the source
   compiled to.
7. **Version sanity.** If a previously working DPL pipeline
   now fails or behaves differently, confirm the installed
   DOCA version (BOTH toolchain and runtime) and the
   BlueField firmware did not change. The four-source
   version-coherence check is owned by
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
   the firmware-version check is owned by the env side
   ([`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)).
   DPL is unusually sensitive to toolchain-vs-runtime drift
   because a compiled program from toolchain *X* loaded by
   runtime *Y* is the same partial-install trap as mixing
   build-time and runtime `*.so`.
8. **Escalation criteria.** If both cap queries pass AND the
   generated programming matches the DPL source AND the
   versions are coherent AND the env-side observables agree
   AND the pipeline still misbehaves, the bug is below the
   DPL API surface (driver or firmware). Stop attempting
   DPL source changes; capture state per
   [`doca-debug TASKS.md ## test`](../../doca-debug/TASKS.md#test)
   (the read-only triple) and escalate via
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   to the public DOCA Developer Forum.

## Command appendix

DPL-specific commands the verbs above reach for, grouped by
purpose so the agent picks the right family without searching
prose. Every row is a class — the agent must not invent flags
beyond what the row names; the *flag-discovery* rule is
`--help` against the installed binary or `pkg-config` against
the installed `.pc`, not prose recall.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST
   (`doca-env --json` for version + devices + libraries in one
   shot; `doca-capability-snapshot` for per-device capability
   flags including the DPL runtime side and the underlying
   doca-flow primitive side).
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
| `pkg-config --modversion doca-dpl` | [`## configure`](#configure) step 2; [`## build`](#build) | What is the build-time DOCA DPL runtime version? | A semver string matching `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)). |
| `pkg-config --cflags --libs doca-dpl` | [`## build`](#build) | What include + link flags does the runtime app linker need? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include the DPL runtime `.so` plus `-ldoca-common`. |
| `ls /opt/mellanox/doca/samples/doca_dpl/` | [`## modify`](#modify) | Which DPL samples ship in this install (DPL source + runtime app together)? | A list of sample directories. Empty / missing directory = the DPL toolchain may not be shipped on this DOCA release; route to [`doca-version`](../../doca-version/SKILL.md) before assuming a wrong build env. |
| `ls /sys/class/net/` (DPU side) | [`## configure`](#configure) step 3; [`## test`](#test) step 2 | Which representors are visible to the DPU? | One entry per representor (PF / VF / SF) the host has surfaced. A missing representor the user expects = env-side problem; route to [`doca-setup`](../../doca-setup/SKILL.md). |
| `lspci | grep Mellanox` (host side) | [`## configure`](#configure) step 3 | Which BlueField PCIe addresses are reachable from the host? | One row per BlueField PF, plus VFs and SFs depending on configuration. |
| `tcpdump -i <rep>` (DPU side, sudo) | [`## run`](#run) step 4; [`## test`](#test) step 2 | Did the smoke packet land where the DPL source said it should? | Frame arrives on the expected representor under controlled traffic. Silence = the DPL source or the generated doca-flow programming is wrong; do not blame the generator first. |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run); [`## debug`](#debug) step 5 | What did the structured DOCA logger emit for the DPL runtime lifecycle? | A trace-level line on every Core context transition and every `doca_dpl_*` call. Silence after a load call = PE not progressed; partial output = call returned before reaching the device. |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the DPL-specific rows on top.

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them so the
agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring, BlueField BFB imaging —
  defer to [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **imperative pipe programming.** When the user's question is
  really about writing pipes / actions imperatively in C —
  validate-before-commit, per-pipe counters, the hairpin
  staging rule — route to
  [`doca-flow`](../doca-flow/SKILL.md). DPL is one authoring
  surface for the same target; doca-flow is the lower-level
  surface and the surface the BlueField actually executes.
- **switch topology configuration.** Configuring the BlueField
  embedded switch dataplane TOPOLOGY (port enumeration,
  bridges, NIC vs switch mode) lives in
  [`doca-switching`](../doca-switching/SKILL.md). A DPL pipeline
  that targets a representor the switching topology never
  exposed will fail at load regardless of how clean the DPL
  source is.
- **stateful connection tracking.** Adding stateful CT on top
  of the dataplane lives in
  [`doca-flow-ct`](../doca-flow-ct/SKILL.md). DPL does not
  generate CT programming today (or, if it does, the surface
  is install-bound — read the
  [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html)
  for *that* release before claiming it).
- **deploy / rollback.** Coordinated DPL-pipeline rollout
  across multiple DPUs and host nodes — out of scope for
  this skill and reserved for a future platform skill. For
  single-DPU pipeline rollback within a session, the right
  verb in this skill is [`## modify`](#modify) with a delta
  on the DPL source.
