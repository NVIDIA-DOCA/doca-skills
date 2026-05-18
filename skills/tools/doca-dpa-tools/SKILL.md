---
name: doca-dpa-tools
description: NVIDIA DOCA DPA tool suite — the developer / admin CLIs documented in the public DPA Tools umbrella that the user invokes to inspect, profile, and runtime-debug a running DPA workload on the BlueField DPA processor from the host. Pairs with the host-side `doca-dpa` library (the library that loads the DPACC-compiled DPA application image and launches DPA kernels) — bring `doca-dpa` up FIRST against a real DPA-capable BlueField, then use these tools to introspect what the running workload is doing. Covers three documented DPA tool families as class-shapes — inspection (what DPA application is loaded, which DPA execution contexts are bound, what is running on the DPA processor right now), profiling (per-kernel timing and DPA-side communication patterns), and runtime-debug (DPA-side execution state, queue state, attach / halt / resume from outside the DPA processor). Distinct from `doca-dpacc-compiler`, the compile-time DPA-side toolchain — that is a separate skill.
kind: library
---

# DOCA DPA tool suite (`doca-dpa-tools`)

**Where to start:** This is a tool skill for invoking the public
**DPA Tools** umbrella CLIs against a real, running DPA workload
on a BlueField. Open [`TASKS.md`](TASKS.md) and start at
[`## run`](TASKS.md#run) for which tool family to reach for first,
or [`## debug`](TASKS.md#debug) when the host-side `doca-dpa`
flow reports a missing completion or a stuck kernel and you need
the DPA-side picture. Open [`CAPABILITIES.md`](CAPABILITIES.md)
when the question is *what kinds of DPA-side findings each tool
family surfaces*. If DOCA is not installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user has
not actually launched a DPA kernel yet, route to
[`doca-dpa`](../../libs/doca-dpa/SKILL.md) first — these tools
introspect a running DPA workload, they do not bring one up.

**This skill is the runtime / inspect side. It is NOT the
compile-time DPA toolchain.** The DPACC compiler — which
produces the DPA application image embedded in the host
executable as a `doca_dpa_app` — is a separate tool skill
(`doca-dpacc-compiler`) and a separate public guide. Compile
with DPACC; LOAD and LAUNCH with `doca-dpa`; INSPECT, PROFILE,
RUNTIME-DEBUG with `doca-dpa-tools`. Three separate surfaces.

## Example questions this skill answers well

The CLASSES of DPA-tool-suite questions this skill is built to
answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"What is the DPA processor actually doing on this BlueField
  right now?"** — worked example: *"my host program submitted a
  DPA kernel launch via `doca-dpa` and is waiting on a
  completion — what's loaded on the DPA processor and which
  execution contexts are bound?"*. Answered by the **inspection
  family** in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the `## run` step in
  [`TASKS.md ## run`](TASKS.md#run) that reaches for the
  inspection tool first.
- **"Which DPA kernel in my workload is the hot one and where
  is its time going?"** — worked example: *"I have a DPA
  application with three kernels and the host completion-rate
  graph went flat — which kernel is the bottleneck and what
  pattern of DPA-side communication is it doing?"*. Answered
  by the **profiling family** in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the smoke-before-bulk rule in [`TASKS.md ## test`](TASKS.md#test).
- **"My DPA kernel is stuck — how do I attach and see what
  state the DPA-side execution is in?"** — worked example: *"the
  host has been waiting on a `doca_dpa_completion` for far
  longer than the kernel should take; the host logs are
  silent"*. Answered by the **runtime-debug family** in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the *"submitted launch, no host-side completion"* ladder
  in [`TASKS.md ## debug`](TASKS.md#debug).
- **"Does the tool I want even exist on this DOCA install, on
  this BlueField generation?"** — worked example: *"is the DPA
  profiling tool available on the host I'm sitting at"*.
  Answered by the dual *tool-present AND DPA-runtime-active*
  rule in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the env-precondition step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"The tool ran but reports nothing useful — is my DPA
  workload broken, the tool, or my expectation?"** — worked
  example: *"the inspector reports zero loaded apps and my host
  program is running"*. Answered by the layered diagnosis in
  [`TASKS.md ## debug`](TASKS.md#debug) +
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
- **"Is this a `doca-dpacc-compiler` (compile-time) question or
  a `doca-dpa-tools` (runtime / inspect) question?"** — worked
  example: *"I get a symbol-not-found error when my host loads
  the DPA image — do I run a DPA tool or rebuild the image?"*.
  Answered by the compile-vs-runtime split in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing stubs in
  [`TASKS.md ## build`](TASKS.md#build) and
  [`TASKS.md ## Deferred task verbs`](TASKS.md#deferred-task-verbs)
  that send compile-time questions to `doca-dpacc-compiler` and
  load / lifecycle questions to `doca-dpa`.

## Audience

This skill serves **external operators, developers, and AI
agents who have already brought up a DPA workload using the
host-side `doca-dpa` library** and now need to inspect, profile,
or runtime-debug what the DPA processor is doing. Concretely:

- A developer whose host program launches a DPA kernel via
  `doca-dpa` and wants to see, from outside the kernel, which
  DPA application image is loaded and which DPA execution
  contexts are bound to it.
- A platform operator who needs a documented, read-mostly way
  to ask *"what is the DPA on this BlueField actually doing?"*
  without touching the host program.
- An AI agent producing a *DPA-side snapshot* as evidence for
  the debug ladder in
  [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug)
  when the host-side flow has a submitted launch that never
  completes.

It is **not** for users debugging the DPA tools themselves,
**not** for users who have not yet brought up the host-side
`doca-dpa` flow (route them through
[`doca-dpa`](../../libs/doca-dpa/SKILL.md) first), and **not**
for compile-time DPA questions (route to
`doca-dpacc-compiler`).

The DPA tools are shipped as **CLIs** (separate developer / admin
binaries under the public DPA Tools umbrella), not libraries the
user links against. The skill uses the same `kind: library`
three-file shape as the rest of the bundle so the agent's
task-verb contract (`configure / build / modify / run / test /
debug`) is uniform across libraries, services, and tools — even
when individual verbs collapse to a routing stub for shipped
binaries.

## When to load this skill

Load this skill when the user is — or the agent needs to — invoke
a public DPA developer / admin CLI against a real BlueField with
a DPA processor exposed to the host and a live DPA workload (or
one the user is bringing up). Concretely:

- Inspecting which DPA application image (`doca_dpa_app`) is
  currently loaded on the BlueField DPA and which DPA execution
  contexts (`doca_dpa_thread`) are bound to it.
- Profiling per-kernel timing or DPA-side communication patterns
  for a running DPA workload to localize a hot path or a
  bottleneck.
- Runtime-debugging a stuck DPA kernel from outside the DPA
  processor — attaching, examining DPA-side execution state,
  observing queue state, and halting / resuming as the public
  guide documents.
- Capturing a documented DPA-side *snapshot* as prerequisite
  evidence for the host-side debug ladder in
  [`doca-dpa TASKS.md ## debug`](../../libs/doca-dpa/TASKS.md#debug).

Do **not** load this skill for general DOCA orientation, host-side
DPA programming, install of DOCA or DPACC, or compile-time DPA
questions. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`doca-dpa`](../../libs/doca-dpa/SKILL.md),
[`doca-setup`](../../doca-setup/SKILL.md), or the
`doca-dpacc-compiler` tool skill.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what each DPA tool family surfaces (the
  three documented families — inspection, profiling, runtime-debug
  — and how each one pairs with `doca-dpa` on the host side),
  version availability and execution environment (the DPA must
  be active on a DPA-capable BlueField and the matching tool
  must be installed; per-tool availability follows the DOCA
  install + DPACC pairing rule), the tool suite's error surface
  layered onto the cross-library taxonomy, its observability role
  inside `doca-dpa`'s debug workflow, and the read-mostly safety
  posture (inspection / profiling are read-only; runtime-debug
  may halt / resume DPA-side execution and must be used
  deliberately).
- `TASKS.md` — step-by-step workflows for the in-scope task verbs:
  `configure` (env preconditions and tool discovery), `build`
  (route to install + a routing stub to `doca-dpacc-compiler` for
  compile-time questions), `modify` (refuse — these are shipped
  binaries), `run` (which family to pick, smoke first), `test`
  (single-kernel-inspect smoke before any profiling sweep),
  `debug` (the layered diagnosis when the tool reports nothing
  or the user is mis-routed), plus a `Deferred task verbs` block
  routing out-of-scope questions and a `Command appendix` with
  the infra-aware preamble shared by every library skill.

The skill assumes a host where DOCA is already installed (or the
public NGC DOCA container is running), a BlueField with a DPA
processor exposed to the host, and the host-side `doca-dpa` flow
already brought up at least once for the workload the user wants
to inspect.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts bundle.
To keep the boundary clean, it deliberately does not contain —
and pull requests should not add:

- **Pre-baked example output.** Output is install-, BlueField-,
  and workload-specific. A captured example pinned to one
  platform and one DOCA version misleads operators on a
  different platform / version.
- **Invented subcommand strings or flag inventories.** The
  authoritative surface for each per-tool flag is the installed
  `--help` and the public per-tool guide reachable via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  The class-shape "what each family does" is enough for routing;
  the per-flag inventory is not.
- **Wrappers, parsers, or scripts** in any language that consume
  DPA tool output. If a user wants to script against it, the
  right answer is "read the live guide, write the parser against
  your installed version".
- **A `samples/` or `reference/` subtree.** This is a thin loader
  for shipped CLIs; substantive material lives on the public
  page and in each tool's `--help`.
- **Compile-time DPA toolchain content.** The DPACC compiler has
  its own public guide and its own tool skill
  (`doca-dpacc-compiler`); this skill names it and routes to it.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (introspecting a *running* DPA workload, not bringing
   one up and not compiling DPA-side source).
2. **For what each DPA tool family surfaces, version availability,
   error surface, observability role inside `doca-dpa`'s debug
   ladder, and safety posture, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — `configure / build / modify /
   run / test / debug`, plus the Command appendix and Deferred
   task verbs — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-dpa`](../../libs/doca-dpa/SKILL.md) — the host-side
  library that loads the DPA application image, creates DPA
  execution contexts, launches DPA kernels, and owns the
  `doca_dpa_completion` mechanism the host uses to observe the
  DPA. The DPA tools introspect what `doca-dpa` is driving;
  bring `doca-dpa` up FIRST.
- [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) — the
  DPA-side library the DPA kernel itself uses for intra-DPA
  messaging. Profiling and runtime-debug findings about
  DPA-side comms patterns route through here for the *what
  does this finding mean* question.
- [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) — the
  DPA-side library the DPA kernel itself uses for RDMA from
  inside the DPA processor to a remote peer. Same routing
  rule as `doca-dpa-comms` for verbs-level findings.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table to the public DPA Tools umbrella at
  `https://docs.nvidia.com/doca/sdk/DPA+Tools/index.html` and to
  each per-tool public guide listed under that umbrella. This
  skill names the families; the per-tool surface lives there.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, BlueField mode (the BlueField must
  expose its DPA processor to the host before any of these
  tools can see it), and the *I have no install yet* path with
  the public NGC DOCA container.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule and adds the DPA-tools-
  specific overlay (tool present + DPA runtime active + DOCA
  matched to DPACC per the Compatibility Policy).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's detect / prefer / fall back / report contract.
  Honored by the Command appendix in
  [TASKS.md](TASKS.md#command-appendix).
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). DPA-side findings from these tools
  overlay layers 5 (runtime) and 6 (program) on top of the
  ladder when a host-side `doca-dpa` symptom escalates here.
- The `doca-dpacc-compiler` tool skill — the **compile-time**
  DPA toolchain that produces the DPA application image these
  tools later observe. The distinction is load-bearing: build
  with DPACC, run with `doca-dpa`, introspect with
  `doca-dpa-tools`.
