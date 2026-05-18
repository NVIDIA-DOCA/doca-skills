# DOCA DPL capabilities, version overlay, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
DPL-class patterns. Pick the pattern first, then drill into the H2
that owns the substance. For the *how* of executing each pattern,
jump to [TASKS.md](TASKS.md).

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the canonical DOCA version-handling
rules this skill layers a DPL overlay on top of, see
[`doca-version`](../../doca-version/SKILL.md). For the
**imperative C API DPL ultimately compiles down to**, see
[`doca-flow`](../doca-flow/SKILL.md) — DPL is the declarative
authoring surface; the BlueField hardware pipeline executes the
generated doca-flow programming at runtime.

## Pattern overview

Every DPL-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
DPL release and every BlueField, not just the worked example
shown.

| DPL pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Declarative vs imperative layering | DPL describes WHAT the pipeline does; doca-flow programs HOW; DPL is COMPILED DOWN TO doca-flow programming for the BlueField hardware pipeline | [`## Capabilities and modes`](#capabilities-and-modes) layering rule + [SKILL.md](SKILL.md) loader |
| 2. The compile step is explicit | DPL source → compiled program → runtime load via the `doca_dpl` Core context — three artifacts, three lifecycles | [`## Capabilities and modes`](#capabilities-and-modes) compile-step section + [TASKS.md ## build](TASKS.md#build) |
| 3. Pick the authoring surface | DPL when declarative authoring + pipeline portability matter; raw doca-flow when fine-grained control or debug fidelity matter | [`## Capabilities and modes`](#capabilities-and-modes) path-selection bullets + [TASKS.md ## configure](TASKS.md#configure) |
| 4. Discover the runtime cap surface | Query `doca_dpl_cap_*` against the active `doca_devinfo` for the runtime side; remember the compiled program *also* gates on the doca-flow primitives the device actually accelerates | [`## Capabilities and modes`](#capabilities-and-modes) capability-query rule + [TASKS.md ## test](TASKS.md#test) |
| 5. Smoke a single packet before scaling | One DPL source compiles + loads + one matching packet observed at the expected representor — BEFORE adding complexity | [`## Safety policy`](#safety-policy) smoke-before-scale rule + [TASKS.md ## test](TASKS.md#test) |
| 6. Interpret a `DOCA_ERROR_*` and locate the layer | Map the error (`BAD_STATE` / `INVALID_VALUE` / `NOT_SUPPORTED` / `IO_FAILED`) to compile-time vs runtime vs underlying-doca-flow cause before retrying or escalating | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **DPL does not replace doca-flow at runtime.** The BlueField
  hardware pipeline executes the doca-flow programming the DPL
  compiler emits. An agent that treats DPL as an independent
  runtime — as if the BlueField speaks DPL natively — will
  mis-diagnose every capability and debug question. Quote the
  layering before any other diagnosis.
- **Discover the device-installed surface, do not assume.**
  Every pattern above gates on `pkg-config --modversion
  doca-dpl` (build-time) and on the runtime `doca_dpl_cap_*`
  capability snapshot of the active device. A DPL feature
  that *the language* expresses but *the device's doca-flow
  primitives* do not accelerate will fail at load or behave
  unexpectedly at runtime — neither side alone is sufficient.

## Capabilities and modes

DOCA DPL is a declarative authoring surface for BlueField
dataplane pipelines. Before writing any DPL source, the agent
should know how DPL relates to the imperative
[`doca-flow`](../doca-flow/SKILL.md) C API and what the
compile / load / run shape actually is.

**The layering rule (load-bearing).** This is the single most
important distinction the agent must teach:

| Layer | Library / language | What it expresses | Authoritative public guide |
| --- | --- | --- | --- |
| Declarative authoring | DPL (the language) + `doca-dpl` (the runtime) | The pipeline as a description: parser shape, match keys, action set — WHAT should happen | [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html) |
| Imperative programming | `doca-flow` (C API) | The pipeline as C calls: pipe create, entry add, validate, commit — HOW the BlueField is programmed | [DOCA Flow](https://docs.nvidia.com/doca/sdk/doca-flow/index.html) |
| Hardware execution | BlueField steering hardware | The actual packet path the device runs at line rate — the same hardware whether the source was DPL or hand-written doca-flow | [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../doca-flow/CAPABILITIES.md#capabilities-and-modes) |

The agent's rule: **DPL is COMPILED DOWN TO doca-flow
programming. It does NOT replace doca-flow; it generates
doca-flow programming from a higher-level declarative spec.**
Under the hood, the BlueField still runs the same hardware
pipeline; DPL just makes the source easier to author and reason
about. An agent that conflates the two layers — for example by
treating DPL as an independent runtime that bypasses doca-flow —
will give wrong answers on every capability, every error, and
every debug question.

**The compile-step shape (three artifacts, three lifecycles).**
DPL splits the authoring path explicitly:

| Stage | Artifact | When it happens | What gates it |
| --- | --- | --- | --- |
| Source | A DPL source file (declarative description of the pipeline) | Authoring time, on the developer host | The DPL language surface in the [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html) for the install's release |
| Compile | The DOCA toolchain reads the DPL source and emits a compiled program plus the equivalent doca-flow programming the BlueField will run | Build time, on the developer host | The DPL compiler's feature set for the install's release; compile-time errors surface here as `INVALID_VALUE` |
| Runtime load | The application creates a `doca_dpl` Core context, loads the compiled program, starts the context, and runs traffic | Run time, on the DPU | The runtime `doca_dpl_cap_*` family + the underlying doca-flow primitives the device actually accelerates |

The agent's rule: **name the stage explicitly before diagnosing
any failure.** A "DPL doesn't work" report is meaningless until
the agent has located which of source / compile / load / run the
failure happened in. The error taxonomy below maps each
`DOCA_ERROR_*` to a stage.

**Path selection — DPL vs raw doca-flow.** Both surfaces target
the same BlueField hardware. The choice is about the *authoring
experience*, not about what the hardware can do.

- **Use DPL when:** declarative description of the dataplane
  pipeline is preferred (P4-like authoring); pipeline
  portability across configurations matters; the team is
  comfortable with declarative dataplane languages; the
  pipeline is large enough that maintaining it as
  imperative C calls is the bottleneck.
- **Do NOT use DPL when:** an existing imperative doca-flow C
  codebase already does the job; fine-grained control over
  every pipe state is needed (raw doca-flow gives more);
  simple stateless rules that doca-flow handles trivially are
  the workload (the DPL toolchain overhead is not worth it);
  debugging is a priority (DPL's compile step adds an
  indirection that complicates per-instruction debugging — the
  generated doca-flow programming is one extra surface to
  inspect).

The agent's rule: when the user asks *"DPL or doca-flow?"*,
walk these bullets before quoting either surface. Don't treat
DPL as automatically better because it is higher-level — the
indirection has real cost at debug time.

**The authoring surface — what a DPL source typically declares.**
The exact syntax is install-bound; read the installed sample
under `/opt/mellanox/doca/samples/doca_dpl/<name>/` and the
[DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html)
for the release-pinned authoring shape. The recurring shape
across releases is:

- **Parser declarations.** Which protocol headers the pipeline
  parses (Ethernet, IPv4 / IPv6, UDP, TCP, tunnel headers).
  The compile step maps these to the parser primitives the
  underlying doca-flow programming can express.
- **Match declarations.** Which fields the pipeline matches on
  (L2 / L3 / L4 / tunnel / metadata). The compile step maps
  these to doca-flow match kinds; a DPL match the device's
  doca-flow programming does not accelerate will be caught at
  compile or at load.
- **Action declarations.** Forward, drop, modify, encap / decap,
  counter, jump-to-pipe — same action vocabulary as doca-flow,
  expressed declaratively.
- **Pipeline composition.** How the parsed / matched / acted
  pieces compose into a complete pipeline.

**Capability discovery — the only rule.** Before relying on a
runtime capability, the agent should encourage the user to
query both:

| Capability axis | Query | Why the agent must ask |
| --- | --- | --- |
| Runtime DPL features on this install | `doca_dpl_cap_*` against the active `doca_devinfo` | The runtime side of DPL is install-bound; assuming a feature is present is the leading hallucination mode. |
| Underlying doca-flow primitives the device accelerates | `doca_flow_cap_*` against the active `doca_devinfo` (per [`doca-flow CAPABILITIES.md ## Capabilities and modes`](../doca-flow/CAPABILITIES.md#capabilities-and-modes)) | Since DPL compiles DOWN TO doca-flow, the device must support the doca-flow primitive the DPL source ends up emitting. A DPL source that compiles cleanly can still fail at load if the underlying primitive is not on this device. |

The exact symbol names of each `doca_dpl_cap_*` entry point are
install-bound; the agent should read them out of the installed
headers and the
[DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html)
rather than inventing them.

**Configuration shape.** *Mandatory* configurations before
`doca_ctx_start()` on the `doca_dpl` runtime context: the
compiled DPL program path (the artifact emitted by the compile
step), the target device's `doca_devinfo`, and a successful
runtime cap-query against that `doca_devinfo`. *Optional*
configurations (per-pipeline parameters, runtime tuning) gate
on the capability queries above; query the active value before
assuming a default.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it.

**The DPL-specific overlay** is:

- The DPL toolchain has TWO version axes the agent must surface:
  (a) the **compile-time** version (the DPL compiler that lives
  with the installed DOCA toolchain) and (b) the **runtime**
  version (the `doca-dpl` library the application links).
  Both must come from the same DOCA install per the four-way
  match in [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
  A DPL program compiled with toolchain version *X* loaded by
  runtime version *Y* (*X ≠ Y*) is the same partial-install
  trap that mixing build-time and runtime `*.so` for any DOCA
  library produces.
- The DPL runtime also pairs with the underlying doca-flow
  version. A DPL source that compiles cleanly against
  doca-flow primitives version *X* will still fail at load if
  the device's installed doca-flow runtime is *Y* < *X*. The
  agent must surface both axes (DPL version *and* underlying
  doca-flow version) when answering *"is feature *F* available
  in DPL?"*.
- When the user reports an `undefined reference` or "function
  not found" for a `doca_dpl_*` symbol, the first hypothesis
  is **wrong-version documentation** — confirm the installed
  version per [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure),
  then verify the symbol exists in the installed headers, then
  read the DPL programming guide for *that* release.
- The release notes for the installed DOCA version are the
  canonical source for DPL features added, deprecated, or
  behavior-changed in that release. Route through the
  knowledge-map for the release-notes URL pattern.

Version-specific tables of symbol availability are deliberately
not maintained in this file — they would drift out of date
silently. The discipline is "read the headers, the matching
release notes, AND the underlying doca-flow surface for *that*
release", not "trust this file's table".

## Error taxonomy

DPL-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *DPL surface* meaning that the agent
must disambiguate before falling back to the cross-library
response. The defining shape of the DPL taxonomy is that every
error has a *stage* (compile-time vs runtime) — and the fix
depends on the stage, not just the code.

| Error | DPL stage where it shows up | DPL-specific cause | First action |
| --- | --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Runtime, on the `doca_dpl` Core context | Lifecycle violation — the runtime context was operated on outside its allowed window (e.g. load before `doca_ctx_start()`, or run after `_stop()`). Same shape as every other DOCA Core context's `BAD_STATE`. | Walk the universal Core lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); confirm the call sequence respects create → configure → start → use → stop → destroy. |
| `DOCA_ERROR_INVALID_VALUE` | Compile-time OR runtime | Compile-time: the DPL source is malformed or expresses something the DPL language surface does not allow. Runtime: a parameter passed to a `doca_dpl_*` call (compiled-program path, devinfo, configuration value) is wrong shape. The agent must disambiguate which stage. | Locate the stage first. Compile-time `INVALID_VALUE` is a DPL source problem — re-read the source against the language guide. Runtime `INVALID_VALUE` is a wrong-parameter problem — read the call site against the installed headers. |
| `DOCA_ERROR_NOT_SUPPORTED` | Runtime, typically at load or at `_start()` | The DPL program uses a doca-flow primitive that the device's installed doca-flow runtime does NOT accelerate on this BlueField / firmware. This is the most common surprise: the DPL source compiled cleanly because the *language* allows the construct, but the *device* cannot run it. | Re-run the `doca_dpl_cap_*` query *and* the underlying `doca_flow_cap_*` query against the active `doca_devinfo`. Confirm which side rejects the feature. Do not retry the same compiled program on the same device hoping for a different answer. |
| `DOCA_ERROR_IO_FAILED` | Runtime, at compiled-program load | The compiled DPL program file is unreachable (wrong path, missing file), unreadable (permission), or the file's on-disk format does not match the runtime version. | Verify the file exists and is readable. Then verify the runtime version matches the version of the toolchain that produced the file (the two-version rule in `## Version compatibility`). |
| `DOCA_ERROR_DRIVER` and similar | Runtime, deep | The layer below DOCA reported failure. The DPL surface is not the suspect; capture state per [`doca-debug TASKS.md ## test`](../../doca-debug/TASKS.md#test) and route to env-class debug. | Stop attempting DPL or doca-flow changes; the bug is below the API surface. |

The agent's rules:

1. **Locate the stage before suggesting a fix.** Every DPL
   error is *either* compile-time *or* runtime; the fix is
   different in each case. A "fix" for a compile-time
   `INVALID_VALUE` that edits the runtime call site is wasted
   work — and vice versa.
2. **Never recommend a blind retry loop on a DPL
   `DOCA_ERROR_*`.** Each row above wants investigation, not
   retry. `NOT_SUPPORTED` in particular is *never* fixed by
   retrying — the device cannot accelerate the doca-flow
   primitive the DPL source compiled to, full stop.

## Observability

The DPL observability surface is unusual because DPL is a
*compiled* language — the program the BlueField actually runs
is the doca-flow programming the DPL compiler emitted, not the
DPL source. That makes the **generated doca-flow programming
the ground-truth observable** for any "what did DPL actually
do?" question.

Four primary signals the agent should reach for:

1. **The generated doca-flow programming (the most important
   one).** What the DPL compiler emitted from the user's DPL
   source. This is what the BlueField hardware pipeline
   actually runs. When the user reports *"DPL is doing
   something I didn't expect"*, the diff between the user's
   mental model of the DPL source and the generated doca-flow
   programming is the bug. The exact path to the generated
   programming is install-bound; read the
   [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html)
   for *that* release to find it.
2. **Runtime cap-query state.** Read the `doca_dpl_cap_*`
   queries against the active `doca_devinfo` to confirm the
   runtime side advertises the features the DPL source uses.
3. **Underlying doca-flow observability.** Counters, pipe
   statistics, and the doca-flow trace / inspector — all
   described in [`doca-flow CAPABILITIES.md ## Observability`](../doca-flow/CAPABILITIES.md#observability)
   — are the per-packet observables of what the BlueField
   actually does. They apply unchanged to a DPL-authored
   pipeline because the pipeline IS doca-flow programming
   under the hood.
4. **Env-side cross-checks.** Representor presence (`ls
   /sys/class/net/`), PCIe enumeration (`lspci | grep
   Mellanox`), and the BlueField mode (`mlxconfig -d <pcie>
   q INTERNAL_CPU_MODEL`) are the env-side primitives that
   gate whether the DPL pipeline can land on any device at all.
   The cross-cutting mechanics live in
   [`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).

For the cross-library debug-time observability (`DOCA_LOG_LEVEL=trace`,
`--sdk-log-level`, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).

## Safety policy

Authoring a DPL pipeline is **not** a free-form operation —
because what runs on the device is the doca-flow programming
the compiler emitted, the same hardware-safety considerations
the imperative [`doca-flow`](../doca-flow/SKILL.md) skill names
apply to DPL too, with one extra DPL-specific consideration
(the compile step adds an indirection that complicates
debugging).

1. **Smoke a single packet before scaling the pipeline.**
   A DPL pipeline that has been compiled, loaded, and
   demonstrated to handle ONE controlled packet end-to-end
   on a minimum-viable shape (one parser stage, one match,
   one action, one representor) is the cheapest place to
   detect a stage error before scaling to a complex
   pipeline. Skipping the smoke produces failure modes
   (compile points at runtime, runtime points at the DPL
   source, source points at the underlying doca-flow) that
   are expensive to bisect.
2. **When DPL behavior is unexpected, inspect the generated
   doca-flow programming — do not re-read the DPL source in
   isolation.** This is the load-bearing DPL debug rule: the
   BlueField runs the generated doca-flow programming, not
   the DPL source. The diff between the user's mental model
   of the DPL source and what the compiler emitted is the
   bug surface. An agent that loops on "let me re-read your
   DPL source" without ever inspecting the generated
   programming will miss the indirection that DPL's compile
   step introduces.
3. **The validate-before-commit discipline doca-flow
   enforces applies to DPL too.** A DPL pipeline that loads
   successfully has the *equivalent* of a doca-flow validate
   pass (because the device accepted the compiled
   programming) — but the agent should still run a
   single-packet smoke before declaring it production-ready,
   per rule 1 above. The
   [`doca-flow CAPABILITIES.md ## Safety policy`](../doca-flow/CAPABILITIES.md#safety-policy)
   build-validate-stage-commit ordering is what *the device*
   sees; DPL's compile step is an upstream addition to that
   ordering, not a replacement for it.

The agent's job is to **enforce these orderings in the workflow**,
not just describe them. If the user says "skip the single-packet
smoke, just load the production pipeline" or "I don't need to
look at the generated doca-flow programming, the DPL source is
fine", the right answer is to refuse and explain the cost, not
to comply.
