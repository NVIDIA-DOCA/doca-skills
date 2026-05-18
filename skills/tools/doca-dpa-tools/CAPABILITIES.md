# DOCA DPA tool suite — Capabilities

**Where to start:** The DPA tool suite is a small set of public
CLIs grouped under the **DPA Tools** umbrella. The pattern
overview below names the recurring tool-suite-class questions.
Pick the pattern first, then drill into the H2 that owns the
substance. For the *how* of executing each pattern, jump to
[TASKS.md](TASKS.md).

This file is loaded by [`SKILL.md`](SKILL.md). It documents *what
the DPA tool suite is*, *which class of finding each documented
family surfaces*, *which versions and environments it ships in*,
*its layered error surface*, *its observability role inside
`doca-dpa`'s host-side debug ladder*, and *the read-mostly
safety posture* that controls how aggressively each family may
be applied to a running workload. For step-by-step invocations
and the smoke-before-bulk workflow, see [`TASKS.md`](TASKS.md).

## Pattern overview

Every DPA-tool-suite question this skill teaches resolves into
one of SIX patterns. The patterns are CLASSES — they apply
across every DOCA install, every BlueField generation, and every
DPA workload that `doca-dpa` brought up.

| DPA tool pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Inspect what is loaded / bound on the DPA right now | Read-only enumeration — what DPA application image is loaded, which DPA execution contexts are bound, what is executing on the DPA processor — before guessing why a `doca-dpa` flow is misbehaving | [`## Capabilities and modes`](#capabilities-and-modes) inspection-family row + [TASKS.md ## run](TASKS.md#run) step 1 |
| 2. Profile a running DPA workload | Per-kernel timing and DPA-side communication patterns for a workload the host is actively driving; the right answer for *"which DPA kernel is the bottleneck"* | [`## Capabilities and modes`](#capabilities-and-modes) profiling-family row + [TASKS.md ## test](TASKS.md#test) smoke-before-bulk loop |
| 3. Runtime-debug a stuck DPA kernel from outside the DPA | Attach / examine DPA-side execution state / observe queue state / halt and resume — the answer for *"submitted launch, host completion never arrived, host log is silent"* | [`## Capabilities and modes`](#capabilities-and-modes) runtime-debug-family row + [TASKS.md ## debug](TASKS.md#debug) layer 5 |
| 4. Pair the tool with the host-side `doca-dpa` flow | Every DPA-tool finding is about a workload the host-side `doca-dpa` is driving; install and bring up `doca-dpa` FIRST, then introspect | [`## Capabilities and modes`](#capabilities-and-modes) parent-skill rule + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Smoke-before-bulk: inspect ONE running kernel before any sweep | Confirm the tool can see the user's workload at all (single inspection on one launched kernel) BEFORE any profiling sweep / multi-kernel run | [TASKS.md ## test](TASKS.md#test) iteration 1 + [`## Safety policy`](#safety-policy) smoke rule |
| 6. Distinguish runtime / inspect from compile-time (DPACC) | A symbol-not-found error at host-side image load is a compile-time question (`doca-dpacc-compiler`), not a runtime inspect question; the agent must NOT reach for `doca-dpa-tools` for that | [`## Capabilities and modes`](#capabilities-and-modes) compile-vs-runtime split + [TASKS.md ## build](TASKS.md#build) routing stub |

Two cross-cutting rules that apply to *every* pattern above:

- **Pair with `doca-dpa` before reaching for any DPA tool.**
  These tools introspect a workload that the host-side
  `doca-dpa` library is driving. If the host has not loaded a
  DPA application image yet (no `doca_dpa_app` registered, no
  `doca_dpa_thread` created, no kernel launched), the tools
  will report "nothing to see" and that finding is correct —
  route the user back to
  [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure).
- **Class-shape only. Do not invent flag strings.** The
  authoritative surface for each per-tool flag is the installed
  `--help` and the per-tool public guide reachable via
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).
  Naming the family is the agent's job here; quoting flag
  strings is not.

## Capabilities and modes

The DPA tool suite is documented on `docs.nvidia.com` as the
**DPA Tools** umbrella; per the routing table in
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools),
the umbrella URL is `https://docs.nvidia.com/doca/sdk/DPA+Tools/index.html`
and the per-tool guides live under that umbrella. The tools are
shipped as separate developer / admin binaries that each have
their own `--help` on the installed version — there is no
single `doca_dpa_tool` binary.

**Compile-time vs runtime / inspect — the load-bearing split.**

| Side | What runs there | Toolchain | Skill that owns it |
| --- | --- | --- | --- |
| Compile-time | Producing the DPA application image embedded in the host executable as a `doca_dpa_app` from the user's DPA-side source | DPACC compiler | `doca-dpacc-compiler` (separate tool skill) |
| Runtime / load | Loading the produced image into a `doca_dpa` Core context, creating `doca_dpa_thread` execution contexts, launching kernels, draining completions | `doca-dpa` (host-side library) | [`doca-dpa`](../../libs/doca-dpa/SKILL.md) |
| Runtime / inspect | Introspecting the loaded / bound / executing state of the DPA processor while a workload is running; profiling timing and DPA-side communication; runtime-debugging from outside the DPA processor | The DPA tool suite (this skill) | `doca-dpa-tools` (this skill) |

The agent's rule: a *"DPA symbol not in the loaded image"* error
is the compile-time row — route to `doca-dpacc-compiler`. A
*"DPA kernel launched but no host completion"* error is the
runtime / inspect row — that is exactly what these tools are
for. Misrouting between these two surfaces is the most common
DPA-tools first-touch error.

**Three documented DPA tool families — class shapes.**

| Family | What kind of finding the family surfaces (class) | When the agent should reach for it |
| --- | --- | --- |
| Inspection | Which DPA application image is loaded, which DPA execution contexts are currently bound, which kernel entry points the image exposes, where the workload is right now on the DPA processor. Side-effect-free; pure enumeration. | FIRST. Always. Inspect before profiling, inspect before any runtime-debug attach. Inspection is the equivalent of `doca_caps` for the DPA: a free, read-only snapshot of *what does this DPA actually look like right now*. |
| Profiling | Per-kernel timing of a running DPA workload and the patterns of DPA-side communication (e.g. between DPA threads, or DPA-to-host / DPA-to-remote when the kernel calls into `doca-dpa-comms` / `doca-dpa-verbs`). Read-mostly. | AFTER the inspection smoke passes and a single-kernel smoke launch is observed clean from the host side. Profiling a workload the tool cannot inspect at all is the wrong order. |
| Runtime-debug | DPA-side execution state from outside the DPA processor, queue state for the affected `doca_dpa_thread`, attach / halt / resume primitives. May change DPA-side execution state — halting a running kernel will stop the host-observed completion stream until resume. | When (and only when) the host-side `doca-dpa` flow reports a submitted launch that never completes and a clean inspection snapshot has been taken to confirm the kernel is genuinely stuck on the DPA, not just slow. |

The per-family entry points (which CLI implements which family,
flag inventories, output column names) are documented in the
per-tool public guides under
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
and in each tool's installed `--help`. This skill does NOT
duplicate that inventory; the agent reads the installed `--help`
on the user's actual DOCA version.

**Pairing with `doca-dpa` — the load-bearing precondition.**

| Step on the `doca-dpa` side | Why the DPA tool suite needs it before it can return anything useful |
| --- | --- |
| Host has loaded a DPA application image (`doca_dpa_app`) | Without a loaded image, the inspection family will (correctly) report no kernels available — that is a `doca-dpa` configure-time finding, not a DPA-tool failure |
| Host has at least one DPA execution context (`doca_dpa_thread`) | Without a bound thread, there is nothing the runtime-debug family can attach to and nothing the profiling family can time |
| Host has actually launched the kernel under inspection | A submitted but never-launched kernel is a host-side progress-engine bug per [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug); it is not what the DPA tools are for |
| BlueField mode actually exposes the DPA processor to the host | If the BlueField is in a mode that does not expose the DPA, the host-side `doca-dpa` create call fails with `DOCA_ERROR_NOT_SUPPORTED` and these tools simply will not see a DPA at all — route to [`doca-setup`](../../doca-setup/SKILL.md) |

The agent's rule: when in doubt, run inspection first and quote
what it returns; do not infer DPA-side state from host-side
behavior alone.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it.

**The DPA tool suite-specific overlay** is:

- **Tool availability follows the DOCA install pairing rule.** The DPA tools are shipped with the DOCA install. Per the DPA overlay in [`doca-dpa CAPABILITIES.md ## Version compatibility`](../../libs/doca-dpa/CAPABILITIES.md#version-compatibility), DOCA and the DPACC compiler must agree per the DOCA Compatibility Policy at <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html>; the DPA tools are aligned with the same DOCA train. The agent must surface the installed DOCA version via `pkg-config --modversion doca-dpa`, cross-check `doca_caps --version`, and confirm DPACC is at a matching version before claiming a missing tool is a bug rather than a stale install. Per-tool availability — i.e. whether a given DPA tool (inspection, profiling, runtime-debug) ships on this install — is documented in the per-tool public guide reachable via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools); do not assume a tool is available across all DOCA versions without checking the public guide for the user's installed version.
- **Tool present is necessary, DPA active is also necessary.** Even when the DPA tool binary is installed, it returns nothing meaningful unless the host's BlueField actually exposes a DPA processor and the host-side `doca-dpa` flow has loaded an application image onto it. The agent must verify BOTH axes before reaching for runtime-debug; verifying only the install axis (`which <tool>`) and then assuming a silent run means the workload is broken is the most common DPA-tools misdiagnosis. The DPA presence axis is queried per the dual-axis rule in [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../../libs/doca-dpa/CAPABILITIES.md#capabilities-and-modes) (the `doca_dpa_cap_*` query against the active `doca_devinfo`) and confirmed by `doca_caps --list-devs` showing a BlueField whose DPA is reachable.
- **Output column / flag stability.** The class-shape (the three families and what each surfaces) is stable across the recent DOCA train. The exact textual / column layout of each tool's output and the flag inventory are **not** contractually frozen — the installed `--help` and the per-tool public guide on the user's installed DOCA version are the authoritative surface. Agents that need to consume tool output programmatically should prefer a structured helper if one is present per [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) and re-verify the textual layout against the user's installed version when absent.

## Error taxonomy

The DPA tool suite's error surface is layered. The agent must
disambiguate WHICH layer the failure is in before recommending
a fix — running runtime-debug against a workload that was never
loaded is the wrong move in every version.

| Layer | What the agent sees | DPA-tool-specific cause | Routing |
| --- | --- | --- | --- |
| 1. Tool-not-installed | The DPA tool binary the user wants to run is not present on `$PATH` or in the installed DOCA `tools/` layout | DOCA is not installed, the install is older than the version that ships the tool, or the install was a partial install (DOCA upgraded, DPACC + DPA tools did not) | [`doca-setup ## install`](../../doca-setup/TASKS.md#install) for install; [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) for the partial-install detection per the four-way match rule |
| 2. DPA-runtime-not-active | The tool runs and exits 0 but reports no DPA application loaded, no DPA execution contexts bound, no kernels running — even when the host program is "doing things" | The host's `doca-dpa` flow has not actually reached the started lifecycle stage for a `doca_dpa` against this BlueField (no image loaded, no thread created, no kernel launched), OR the BlueField is in a mode that does not expose the DPA, OR the user is running the tool on a host whose BlueField has no DPA at all | [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure) for the `doca-dpa` bring-up, [`doca-setup`](../../doca-setup/SKILL.md) for the BlueField-mode side |
| 3. Kernel-not-loaded | Inspection reports the loaded image but the user's expected kernel function entry point is NOT in the listed entry-point set | The DPA-side translation unit `dpacc` compiled does NOT contain the function the user is asking about — a compile-time problem in disguise | The `doca-dpacc-compiler` tool skill (compile-time DPA toolchain), reachable through [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools) — wrong compile, not a runtime / inspect bug |
| 4. HART-binding | Inspection runs but a specific DPA execution context the user expected is not bound, or runtime-debug cannot attach to the context the user named | The host's `doca-dpa` flow created fewer DPA threads than the user expected, or the named context belongs to a different `doca_dpa` instance (multi-BlueField host), or the context has been torn down already | [`doca-dpa TASKS.md ## configure`](../../libs/doca-dpa/TASKS.md#configure) step 5 (thread create) and [`doca-dpa CAPABILITIES.md ## Safety policy`](../../libs/doca-dpa/CAPABILITIES.md#safety-policy) lifecycle ordering rule |
| 5. Permission | The tool fails or refuses to attach / read with a permission-class error from the OS or the underlying driver | The user lacks the privileges the public per-tool guide requires on this platform, or the BlueField mode requires elevated privilege for the runtime-debug family | The per-tool public guide reachable via [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools); [`doca-setup`](../../doca-setup/SKILL.md) for the OS-side privilege step |
| 6. Version | The tool runs but the output is missing a column / field the user is reading about in a doc, or the agent quoted a flag the installed `--help` does not list | DOCA + DPACC are skewed per the Compatibility Policy, or the user is reading a doc from a different DOCA version than the one installed | [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) for the four-way match; the per-tool public guide on the user's actual installed version, not "latest" |
| 7. Cross-cutting | The tool runs against a real loaded workload, but the user's question is really about the host-side `doca-dpa` API behavior, the cross-library `DOCA_ERROR_*` taxonomy, or generic driver / link / runtime failures unrelated to DPA introspection | The DPA tool suite is the wrong surface for this question | The cross-library debug ladder in [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug); the host-side surface in [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug) |

The agent's rule: **never recommend runtime-debug attach without
first confirming layers 1 and 2**. Attaching runtime-debug to a
workload that is not actually running is exactly the failure
mode the layered taxonomy is here to prevent.

## Observability

The DPA tool suite is itself the **DPA-side observability
primitive** for the rest of the bundle — it is *what other
skills load to observe* the DPA side of a workload after the
host-side flow has been brought up. Specifically:

- [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
  layer 5 (runtime) prescribes reaching for the DPA tool suite
  when a host-side submitted launch never produces a
  `doca_dpa_completion` and the host-side log is silent. The
  three host-side hypotheses (host not progressing the PE; DPA
  kernel in an infinite loop with no termination condition;
  completion queue full and silently dropped) are all
  distinguishable from the DPA side via inspection +
  runtime-debug. Without these tools, the agent is reduced to
  guessing.
- [`doca-dpa-comms TASKS.md ## debug`](../../libs/doca-dpa-comms/TASKS.md#debug)
  routes here for *"DPA kernel hung on a receive with no
  matching sender"* findings — the DPA-side queue / wait state
  is what runtime-debug surfaces directly.
- [`doca-dpa-verbs TASKS.md ## debug`](../../libs/doca-dpa-verbs/TASKS.md#debug)
  routes here for *"DPA-side RDMA call never completed and the
  host completion stream went silent"* findings.

The tool suite does not emit metrics, traces, or logs of its
own beyond each tool's documented output and any structured
output the per-tool guide names. For cross-cutting observability
primitives (`--sdk-log-level`, the `DOCA_LOG_LEVEL` env var, the
trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree layout and the per-tool guide URLs, defer
to
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## Safety policy

The DPA tool suite's safety surface is **per-family**, not
uniform — the three families differ in how aggressively they
can be applied to a running workload.

- **Inspection — read-only, always safe.** The inspection family
  is the DPA-side equivalent of `doca_caps` for the rest of the
  bundle: it prints; it does not change DPA-side execution
  state, lifecycle state, queue state, or any host-side
  `doca-dpa` state. Re-running it is free; it is the canonical
  first step before any other DPA tool reach. An agent
  uncertain whether to inspect should inspect.
- **Profiling — read-mostly, but check the per-tool guide.** The
  profiling family is intended to observe a running workload
  without changing it, but each profiling tool may have its
  own conditions documented in its public guide (e.g.
  attach-time overhead, ring-buffer reservation). The agent
  must read the per-tool guide on the user's installed DOCA
  version before applying profiling to a production workload,
  not infer safety from "it's profiling, it must be free".
- **Runtime-debug — may change DPA-side execution state.** The
  runtime-debug family includes attach / halt / resume
  primitives. Halting a running DPA kernel stops the host-
  observed completion stream until resume, and an unrecovered
  halt can leave the DPA processor in a state the next `doca-dpa`
  process inherits. Use deliberately — confirm via the layered
  diagnosis in [`## Error taxonomy`](#error-taxonomy) that
  runtime-debug is actually the right family for the question
  before reaching for it. If the user just wants to know
  *"what is loaded"*, that is inspection, not runtime-debug.
- **Smoke-before-bulk on EVERY new workload.** Inspect ONE
  running kernel and confirm the tool can see it before any
  profiling sweep across many kernels or many launches.
  Skipping this step is how operators discover, ten minutes
  into a profiling sweep, that the tool was not actually
  attached to the workload they thought they were profiling.
- **Quote what the tool said. Do not paraphrase DPA-side
  findings.** The captured DPA-side snapshot is the artifact
  downstream `doca-dpa ## debug` consumes; reformatting it
  loses fidelity that the rest of the bundle's procedures
  depend on.
- **Do not invent flags.** Per the cross-cutting rule in
  [`## Pattern overview`](#pattern-overview), the per-tool
  `--help` and the per-tool public guide are the authoritative
  surface for each flag and column.

## Public-source pointer

The single canonical public entry point for the DPA tool suite
is the **DPA Tools** umbrella page on `docs.nvidia.com`,
reachable through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools)
(direct URL <https://docs.nvidia.com/doca/sdk/DPA+Tools/index.html>).
The umbrella lists each per-tool public guide; the agent
follows the umbrella to the per-tool guide for the user's
installed DOCA version rather than quoting flags from memory.
Do not invent flags, output formats, or tool family surfaces
beyond what the umbrella + per-tool guides document.
