---
name: doca-dpl
description: NVIDIA DOCA Pipeline Language (DPL) on BlueField — the declarative dataplane-programming surface (pkg-config `doca-dpl`) that lets the user describe WHAT a pipeline should do (parse this header, match this field, set this action) in a DPL source file that the DOCA toolchain compiles down to doca-flow programming for the BlueField hardware pipeline; the compile-step shape (DPL source → compiled program → runtime load), the per-runtime DOCA Core context lifecycle for loading and running compiled DPL programs, the `doca_dpl_cap_*` capability-discovery family on the runtime side, permission rules (root / sudo, same as doca-flow underneath), the `BAD_STATE` / `INVALID_VALUE` / `NOT_SUPPORTED` / `IO_FAILED` error overlay, and debugging unexpected behavior by inspecting the generated doca-flow programming that the BlueField actually runs.
kind: library
---

# DOCA Pipeline Language (DPL)

**Where to start:** This skill assumes DOCA is already installed and
the user is doing **hands-on declarative dataplane-pipeline work** on
a BlueField / ConnectX host. Open [`TASKS.md`](TASKS.md) if the user
wants to *do* something (configure / build / modify / run / test /
debug); open [`CAPABILITIES.md`](CAPABILITIES.md) when the question
is *what can DPL express* on this version. If the user has not
installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first. **If the user is
asking how to write low-level pipe / action programming directly in
C**, route to [`doca-flow`](../doca-flow/SKILL.md) — that is the
imperative API the DPL compiler ultimately emits programming for.

## Example questions this skill answers well

The CLASSES of DPL questions this skill is built to answer, each
with one worked example. The agent should treat the *class* as the
load-bearing piece — the worked example is a single instance.

- **"What is DPL and how does it relate to doca-flow?"** — worked
  example: *"should I write my dataplane in DPL or in doca-flow C
  calls?"*. Answered by the declarative-vs-imperative layering rule
  in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (DPL is declarative; doca-flow is imperative; DPL is COMPILED
  DOWN TO doca-flow) + the path-selection section in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"How do I write a small DPL pipeline that parses
  Ethernet + IPv4 + UDP and forwards to a representor on a port
  match?"** — worked example: *"declare the parser, declare the
  match-action, compile, load, run"*. Answered by the source →
  compiled-program → runtime-load workflow in
  [`TASKS.md ## build`](TASKS.md#build) +
  [`TASKS.md ## run`](TASKS.md#run) + the parser / match /
  action surface in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
- **"How do I check whether a DPL feature will actually program
  the hardware?"** — worked example: *"my DPL source uses a header
  the device's doca-flow programming doesn't accelerate"*.
  Answered by the runtime `doca_dpl_cap_*` rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the compile-then-cap-check sequence in
  [`TASKS.md ## test`](TASKS.md#test).
- **"My DPL program compiled but the BlueField is doing something
  I didn't expect — how do I debug it?"** — worked example: *"the
  pipeline parses, matches, but forwards the wrong way"*.
  Answered by the *inspect-the-generated-doca-flow-programming*
  rule in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the layered debug ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-flow ## debug`](../doca-flow/TASKS.md#debug).
- **"What does this `DOCA_ERROR_*` from a DPL runtime call
  mean?"** — worked example: *"`DOCA_ERROR_IO_FAILED` loading my
  compiled DPL program"*. Answered by the DPL overlay on the
  cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md).
- **"Is this DPL feature available on my installed DOCA
  version?"** — worked example: *"is the DPL compiler that ships
  with my install able to target the doca-flow primitive I need?"*.
  Answered by the version-compatibility section in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the version-discovery rule (`pkg-config --modversion
  doca-dpl`) pinned in
  [`TASKS.md ## configure`](TASKS.md#configure).

## Audience

This skill serves **external developers authoring BlueField
dataplane pipelines declaratively** — i.e., users who would
otherwise write `doca_flow_*` C calls imperatively but prefer to
describe the pipeline in a DPL source file and let the DOCA
toolchain compile it down to that doca-flow programming. It is
*not* for NVIDIA developers contributing to DPL itself, nor for
users asking about Linux software dataplanes (XDP, eBPF, OVS),
which are different stacks entirely.

**Language scope.** DOCA DPL is a *language* (the declarative
pipeline source) plus a *runtime library* (the C library that
loads and runs the compiled program). The pipeline source is
written in DPL; the runtime that loads it is consumed as a C
library with `pkg-config` module name `doca-dpl`. The shipped
samples that this skill points the agent at (when present at the
install path below) include both DPL source files and the C
runtime that loads them. The user's *application* is C / C++; the
*pipeline description* is DPL. Other-language consumers
(Rust, Go, Python, …) consume the C runtime through FFI; the
DPL source itself is language-neutral.

## When to load this skill

Load this skill when the user is doing **hands-on declarative
dataplane-pipeline work on a BlueField host with DOCA already
installed**. Concretely:

- Authoring a DPL source file that describes a parser + match +
  action pipeline — and asking how the DOCA toolchain will
  compile it.
- Loading a compiled DPL program at runtime via the `doca_dpl`
  Core context on the DPU and running it against live traffic.
- Querying the DPL runtime's capability surface
  (`doca_dpl_cap_*`) against the active `doca_devinfo` — i.e.,
  asking *"does the doca-flow programming this DPL compiles down
  to actually run on this device / firmware?"*.
- Debugging *"my DPL compiles but the hardware behaves
  unexpectedly"* — which is, almost always, a question about the
  generated doca-flow programming, not about the DPL source.
- Deciding whether DPL is the right authoring surface vs going
  directly to [`doca-flow`](../doca-flow/SKILL.md) (the imperative
  C API DPL compiles down to).
- Debugging a `DOCA_ERROR_*` returned from the DPL runtime
  (`BAD_STATE` / `INVALID_VALUE` / `NOT_SUPPORTED` / `IO_FAILED`)
  and deciding whether the cause is a compile-time issue
  (bad DPL source), a runtime lifecycle violation, a missing
  doca-flow primitive on this hardware, or a file / load
  failure.

Do **not** load this skill for general DOCA orientation, install
of DOCA itself, low-level imperative pipe programming (use
[`doca-flow`](../doca-flow/SKILL.md) — that is the layer DPL
compiles down to), stateful connection tracking on top of a flow
pipeline (use [`doca-flow-ct`](../doca-flow-ct/SKILL.md)),
switch-topology configuration (use
[`doca-switching`](../doca-switching/SKILL.md)), or non-DPL
library questions. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive DPL-specific
material lives in two companion files:

- `CAPABILITIES.md` — what DPL can express on this version: the
  declarative-vs-imperative layering rule (DPL describes WHAT;
  doca-flow programs HOW; DPL is compiled DOWN TO doca-flow
  programming for the BlueField hardware pipeline), the
  source / compiler / runtime split (compile-time vs runtime
  surfaces), the parser / match / action authoring surface, the
  `doca_dpl_cap_*` runtime capability-query family, the DPL
  error taxonomy (mapped onto the cross-library `DOCA_ERROR_*`
  set, with the compile-time vs runtime overlay), the
  observability surface (the generated doca-flow programming is
  the ground-truth observable), and the safety policy that gates
  scaling a DPL pipeline beyond a single-packet smoke.
- `TASKS.md` — step-by-step workflows for the six in-scope DPL
  verbs: `configure`, `build`, `modify`, `run`, `test`, `debug`.
  Plus a `Deferred task verbs` block that points install / deploy
  / rollback questions at the right next skill.

The skill assumes a BlueField host where DOCA is already
installed at the standard location and the user has root / sudo
on the DPU (DPL runtime calls typically require it, same as the
underlying doca-flow programming). It does not cover installing
DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DPL pipeline source files**, in any
  *.dpl-shaped extension or other format. The DPL language
  surface evolves between releases and a source file written
  from documentation prose cannot be verified without compiling
  it against the live DPL toolchain on a real install. The
  verified DPL source is the shipped sample at
  `/opt/mellanox/doca/samples/doca_dpl/<name>/` when present on
  the install; the agent's job is to route the user to that
  file and prescribe a minimum-diff modification via the
  universal modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the DPL-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Pre-written DOCA DPL runtime application source code, in any
  language.** Same reasoning as the imperative
  [`doca-flow`](../doca-flow/SKILL.md) skill — the API surface
  evolves between releases and code written from documentation
  prose cannot be verified without compiling it against the live
  library on a real install.
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, `Cargo.toml`, …) parked inside the skill.
  The agent constructs the build manifest *in the user's project
  directory* against the user's installed DOCA, where
  `pkg-config --modversion doca-dpl` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.
- **Pipeline recipes for specific dataplane patterns** (e.g. an
  "L4 load balancer in DPL" reference). Those are
  instance-shaped per the classes-over-instances rule in
  [`AUTHORING.md` § 1a](../../../../devops/AUTHORING.md) and
  rejected by the class-shape filename gate; route any such
  request to the DPL authoring *primitives* taught here plus the
  imperative counterpart in
  [`doca-flow`](../doca-flow/SKILL.md).

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is
   in scope (and *not* a low-level imperative pipe-programming
   question, which routes to
   [`doca-flow`](../doca-flow/SKILL.md)).
2. **For the declarative-vs-imperative layering rule, the
   compile-step shape (DPL source → compiled program → runtime
   load), the parser / match / action authoring surface, the
   runtime capability-query rule, the DPL error taxonomy, the
   observability surface (inspect the generated doca-flow
   programming), and the safety policy gating scale-up, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-version`](../../doca-version/SKILL.md) for the canonical
version-handling rules,
[`doca-flow`](../doca-flow/SKILL.md) for the imperative
counterpart (the C API DPL compiles down to and the
authoritative source of truth on what the BlueField hardware
actually runs), and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "DPL-specific
guidance".

## Related skills

- [`doca-flow`](../doca-flow/SKILL.md) — the **imperative C API
  DPL compiles down to**. Same shape (DOCA Core lifecycle,
  capability-query rule, validate / smoke-before-scale, env
  preconditions, BlueField hardware pipeline underneath);
  different concern (DPL is a declarative authoring surface;
  doca-flow is the imperative programming surface DPL emits).
  The agent must teach the layering: a DPL program is COMPILED
  DOWN TO doca-flow programming; the BlueField hardware
  pipeline does not know DPL at runtime — it executes the
  generated doca-flow programming. When DPL behaves
  unexpectedly, the debug path is to inspect the generated
  doca-flow programming, not to re-read the DPL source in
  isolation. The
  [DOCA Pipeline Language Services Guide](https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html)
  is the authoritative public source on DPL itself; the
  [DOCA Flow programming guide](https://docs.nvidia.com/doca/sdk/doca-flow/index.html)
  is the authoritative source on the surface DPL compiles to.
- [`doca-switching`](../doca-switching/SKILL.md) — the BlueField
  embedded switch dataplane TOPOLOGY (which ports exist, NIC vs
  switch mode, bridging at the switch level). A DPL pipeline
  that targets a representor the switching topology never
  exposed will produce a doca-flow-side capability or validate
  failure when the compiled program loads; the fix is at the
  switching layer (this is the same precondition doca-flow
  itself has).
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. Always
  available alongside this skill; this skill expects to be able
  to defer documentation-finding and install-layout questions
  there instead of duplicating them.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, representor visibility checks, the
  BlueField runtime-mode (SmartNIC / DPU / switch) check, and
  the *I have no install yet* path with the public NGC DOCA
  container. This skill assumes its preconditions are
  satisfied.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  the DPL per-library overlay (compiler version paired with
  runtime version paired with the underlying doca-flow
  version).
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, and the
  program-side debug order. This skill layers DPL specifics on
  top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). DPL-specific debug (compile-time vs
  runtime split, generated-doca-flow inspection, capability
  mismatch between DPL feature and doca-flow primitive) overlays
  on top of that ladder.
