---
name: doca-dpacc-compiler
description: NVIDIA DOCA DPACC Compiler (DPA Cross-Compiler) — the compile-time DPA toolchain shipped alongside DOCA that compiles DPA-side source (the kernels that run on the BlueField Data-Path Accelerator processor) into the DPA application image the host-side `doca-dpa` library loads at runtime. Pairs as a DPA toolchain triad — `doca-dpacc-compiler` (this skill) is COMPILE-TIME, `doca-dpa` is RUNTIME-LOAD-AND-LAUNCH, `doca-dpa-tools` is RUNTIME-INSPECT. DPACC must match the host DOCA install per the DOCA Compatibility Policy — a skewed DPACC produces an image that links cleanly but fails at runtime in confusing ways. Three-axis configure — target DPA architecture × source-language flavor (DPA kernel + host-side wrapper) × output artifact. Class-shape only — flag strings, arch names, and include-path strings live on the public DOCA DPACC Compiler guide and the installed binary's `--help`, not in this skill.
kind: library
---

# DOCA DPACC Compiler (`doca-dpacc-compiler`)

**Where to start:** This is a tool skill for invoking the public
**DOCA DPACC Compiler** (the *DPA Cross-Compiler*, `dpacc`) on a
host where DOCA is already installed, to compile DPA-side source
into the DPA application image that the host-side `doca-dpa`
library will later load and launch on a real BlueField DPA. Open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) for the three-axis decision
(target DPA architecture × source-language flavor × output
artifact), or at [`## build`](TASKS.md#build) when the three axes
are committed and the user is ready to actually compile + link.
Open [`CAPABILITIES.md`](CAPABILITIES.md) when the question is
*what is DPACC for, where does it sit between the host-side
`doca-dpa` library and the runtime `doca-dpa-tools` CLIs, and
which axes does the agent have to commit to before any flag is
chosen*. If DOCA is not installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user
actually wants to LOAD or LAUNCH a kernel (rather than compile
one), route to [`doca-dpa`](../../libs/doca-dpa/SKILL.md); if
the user wants to INSPECT a running DPA workload, route to
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md). For the
canonical URL of the public DOCA DPACC Compiler guide, route
through
[`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools).

## Example questions this skill answers well

The CLASSES of DPACC questions this skill is built to answer,
each with one worked example. The class is the load-bearing
piece; the worked example is one instance.

- **"How do I compile a DPA kernel so my host-side `doca-dpa`
  app can load it on the BlueField DPA?"** — worked example:
  *"I have a DPA-side C source file with one kernel entry
  point that touches a small buffer; how do I produce the
  artifact my host link line embeds and `doca-dpa` later
  loads?"*. Answered by the two-stage role in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the configure / build walk in
  [`TASKS.md ## configure`](TASKS.md#configure) and
  [`TASKS.md ## build`](TASKS.md#build).
- **"My DPACC version and my DOCA install version disagree —
  what breaks?"** — worked example: *"DPACC was installed by
  one DOCA package; the host runtime is a different DOCA
  install; the host link succeeds but the kernel fails at
  load with `DOCA_ERROR_DRIVER`"*. Answered by the
  hard-pairing version overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  + the version-check step in
  [`TASKS.md ## configure`](TASKS.md#configure) that redirects
  to [`doca-version`](../../doca-version/SKILL.md).
- **"Which BlueField generation am I targeting, and what's
  the smallest kernel I can compile to validate the
  toolchain?"** — worked example: *"a no-op kernel + a
  one-call host wrapper that uses `doca-dpa` to load and
  launch it"*. Answered by the smoke-before-bulk loop in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the smoke iteration in
  [`TASKS.md ## test`](TASKS.md#test) step 1.
- **"Is this a DPACC (compile-time) question or a `doca-dpa`
  (runtime) question or a `doca-dpa-tools` (runtime
  inspect) question?"** — worked example: *"I get
  `symbol not in image` when `doca-dpa` loads the artifact
  — DPACC, host link, or the DPA-tool inspector?"*.
  Answered by the compile-vs-runtime split in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the routing stub in
  [`TASKS.md ## Deferred task verbs`](TASKS.md#deferred-task-verbs).
- **"My DPA kernel calls into `doca-dpa-comms` from inside
  the kernel — does anything in the DPACC build change?"**
  — worked example: *"a DPA-side translation unit that
  uses inter-thread messaging primitives; does my DPACC
  invocation grow new include / link inputs?"*. Answered by
  the DPA-side library cross-link rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the per-DPA-side-library overlay in
  [`TASKS.md ## build`](TASKS.md#build).
- **"DPACC ran but the resulting image fails at runtime —
  which layer is it?"** — worked example: *"compile
  succeeds, host link succeeds, `doca-dpa` rejects the
  load on a known-good BlueField"*. Answered by the
  layered DPACC error taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  + the diagnosis ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).

## Audience

This skill serves **external DPA developers and AI agents who
have a DPA-side translation unit (or want to write one) and
need DPACC to turn it into a DPA application image their
host-side `doca-dpa` flow can load and launch**. Concretely:

- A developer adopting DPA who has the host-side `doca-dpa`
  flow already sketched and now needs to actually compile the
  DPA kernel into the binary the host executable embeds.
- A platform operator producing a build pipeline for DPA-using
  applications that needs a documented, reproducible DPACC
  invocation against the user's installed DOCA + DPACC pair.
- An AI agent splitting a *"build a DPA app"* request into its
  three skill surfaces — compile (this skill), load + launch
  ([`doca-dpa`](../../libs/doca-dpa/SKILL.md)), inspect
  ([`doca-dpa-tools`](../doca-dpa-tools/SKILL.md)) — and
  reaching for DPACC for the compile half.

It is **not** for users debugging DPACC itself, **not** a
substitute for the live public DOCA DPACC Compiler guide on
`docs.nvidia.com`, **not** the place to learn the DPA-side
kernel programming surface (route to the public *DOCA DPA*
guide via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
and to the matching DPA-side library skills
[`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) and
[`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) for
intra-DPA messaging and DPA-side RDMA respectively), and
**not** for runtime / inspect questions (those belong in
[`doca-dpa`](../../libs/doca-dpa/SKILL.md) and
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md)).

DPACC is shipped as a **tool** (a build-time compiler binary
plus supporting headers / libraries used at compile time), not
a runtime library the user links against from a long-running
program. The skill uses the same `kind: library` three-file
shape as the rest of the bundle so the agent's task-verb
contract (`configure / build / modify / run / test / debug`) is
uniform across libraries, services, and tools — even when
individual verbs collapse to a routing stub for a shipped
build-time toolchain.

## When to load this skill

Load this skill when the user is — or the agent needs to —
invoke DPACC on a host where DOCA is already installed (or
inside the public NGC DOCA container) to compile a DPA-side
translation unit. Concretely:

- Picking the **target DPA architecture** for the BlueField
  generation the user is going to run on, the
  **source-language flavor** (DPA-side C kernel plus the
  host-side wrapper that will use `doca-dpa` to load it), and
  the **output artifact** shape DPACC produces.
- Compiling a DPA-side translation unit and linking the
  resulting object into the host executable that will load it
  via `doca-dpa` at runtime.
- Compiling a DPA-side translation unit that itself calls
  into the DPA-side libraries
  [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) (intra
  -DPA messaging) or
  [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md)
  (DPA-side RDMA) — the kernel-side library set is part of
  the source-language flavor axis the agent has to commit to.
- Confirming the installed DPACC version matches the host
  DOCA install version per the DOCA Compatibility Policy —
  this is a HARD pairing requirement enforced by
  [`doca-version`](../../doca-version/SKILL.md), not optional
  hygiene.
- Smoking the toolchain end-to-end with a minimal DPA kernel
  + a minimal host-side wrapper before scaling to the user's
  real kernel — the canonical *compile → host-link → runtime
  load → smoke-launch* loop.
- Debugging a DPACC build that fails before producing an
  artifact, produces an artifact the host link rejects, or
  produces an artifact that the host link accepts but
  `doca-dpa` then refuses at runtime.

Do **not** load this skill for general DOCA orientation, the
host-side DPA control surface itself (load, launch, drain
completions — that is
[`doca-dpa`](../../libs/doca-dpa/SKILL.md)), DPA-side library
API surfaces (those are
[`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) and
[`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md)),
runtime / inspect of a DPA workload (that is
[`doca-dpa-tools`](../doca-dpa-tools/SKILL.md)), DOCA install
itself (that is [`doca-setup`](../../doca-setup/SKILL.md)), or
the cross-cutting debug ladder (that is
[`doca-debug`](../../doca-debug/SKILL.md)).

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what DPACC is and is not, the two-stage
  role (DPACC produces the image; `doca-dpa` loads and
  launches it; `doca-dpa-tools` introspects it once running),
  the three-axis configuration model (target DPA architecture
  × source-language flavor × output artifact), the
  hard-pairing version overlay that redirects to
  [`doca-version`](../../doca-version/SKILL.md) for the body
  and adds the *DPACC must match host DOCA* rule, the layered
  error surface (compiler-not-installed / wrong-DPACC-version
  / source-error / DPA-arch-mismatch / link-time-symbol-missing
  / version-skew-with-host-DOCA / cross-cutting), the tool's
  observability role inside the DPA toolchain triad, and the
  safety policy around partial rebuilds and silent
  arch-mismatch failure modes.
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `configure` (the three-axis decision plus
  version-state check), `build` (compile DPA-side + link
  into host executable), `modify` (refuse — DPACC is shipped
  read-only), `run` (route to `doca-dpa` for actual launch),
  `test` (compile-link-load-smoke loop with a minimal
  kernel), `debug` (the layered diagnosis ladder), plus a
  `Deferred task verbs` block routing out-of-scope questions
  and a `Command appendix` honoring the bundle's
  [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md)
  preamble.

The skill assumes a host where DOCA is already installed (or
the public NGC DOCA container is running), the DPACC compiler
shipped alongside DOCA is on `$PATH` (or at the install-tree
location the public guide names on the user's installed DOCA
version), and the user has — or is about to write — a
DPA-side translation unit they want to compile.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or
build-recipes bundle. To keep the boundary clean, it
deliberately does not contain — and pull requests should not
add:

- **Verbatim DPACC flag inventories, supported-arch names, or
  include-path strings.** The public DOCA DPACC Compiler
  guide on `docs.nvidia.com` (reached through
  [`doca-public-knowledge-map ## DOCA tools`](../../doca-public-knowledge-map/SKILL.md#doca-tools))
  and the installed binary's `--help` on the user's DOCA
  version are the joint source of truth; copying them here
  pins the skill to one DOCA release and silently rots when
  DPACC evolves. The skill routes the agent at those sources
  instead.
- **Pre-baked DPA-side kernel source or host-side wrapper
  source, in any language.** The verified DPA source is the
  shipped sample tree under
  `/opt/mellanox/doca/samples/doca_dpa/` (and the DPA-side
  library sample trees the parent
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md) skill names).
  The agent's job is to route the user to those files and
  prescribe a minimum-diff modification per
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, …) parked inside the skill. The agent
  constructs the build manifest *in the user's project
  directory* against the user's installed DOCA + DPACC pair,
  where `pkg-config --modversion doca-dpa` and the installed
  DPACC version are the joint sources of truth.
- **A `samples/`, `recipes/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree,
  even one labeled *"reference"*, is misleading: operators
  will read it as buildable.
- **Runtime / inspect content for the DPA toolchain triad.**
  The runtime side — load + launch via
  [`doca-dpa`](../../libs/doca-dpa/SKILL.md) and inspect via
  [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) — lives in
  those skills. This skill names them and routes; it does
  not redefine their surfaces.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (compile-time DPA toolchain work, not
   runtime / load / launch and not runtime / inspect).
2. **For DPACC's two-stage role inside the DPA toolchain
   triad, the three-axis configuration model, the
   hard-pairing version overlay, the layered error surface,
   the observability role, and the safety posture, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For the documented compile + link + smoke workflow —
   `configure`, `build`, `modify`, `run`, `test`, `debug`,
   plus the `Command appendix` — see [TASKS.md](TASKS.md).**

## Related skills

- [`doca-dpa`](../../libs/doca-dpa/SKILL.md) — **runtime
  load + launch counterpart** to this compile-time skill.
  The host-side library that creates the per-DPA-instance
  `doca_dpa` Core context, loads the DPA application image
  DPACC produced into the context, creates DPA execution
  contexts (`doca_dpa_thread`), launches DPA kernels with
  arguments via `doca_dpa_kernel_launch_update_*`, and
  drains `doca_dpa_completion`. The compile-vs-runtime split
  is load-bearing: BUILD with DPACC (this skill), LOAD and
  LAUNCH with `doca-dpa`. Treat them as a paired pair on
  every question.
- [`doca-dpa-tools`](../doca-dpa-tools/SKILL.md) — **runtime
  inspect counterpart** to this compile-time skill. The
  public DPA Tools umbrella CLIs that introspect, profile,
  and runtime-debug a DPA workload after it is loaded and
  running. The compile-vs-runtime distinction must be
  explicit: DPACC = build time, `doca-dpa-tools` = runtime
  inspect, `doca-dpa` = SDK library that bridges the two.
  Misrouting between these three surfaces is the most common
  DPA toolchain first-touch error.
- [`doca-dpa-comms`](../../libs/doca-dpa-comms/SKILL.md) —
  **DPA-side library** the user's DPA kernel may call from
  inside the kernel for intra-DPA messaging. DPACC compiles
  the translation unit that calls into it; this skill names
  the library as part of the source-language flavor axis but
  does not redefine its API surface.
- [`doca-dpa-verbs`](../../libs/doca-dpa-verbs/SKILL.md) —
  **DPA-side library** the user's DPA kernel may call from
  inside the kernel for DPA-side RDMA to a remote peer.
  Same routing rule as `doca-dpa-comms` — DPACC compiles the
  translation unit that uses it; this skill names it but
  does not redefine its API surface.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  routing to the public DOCA DPACC Compiler guide
  (<https://docs.nvidia.com/doca/sdk/DOCA-DPACC-Compiler/index.html>),
  the public DPA Tools umbrella, and the rest of the public
  DOCA documentation set. This skill names the public guide;
  the per-flag inventory lives there.
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and adds
  the **HARD pairing rule** — DPACC version must match the
  host DOCA install version per the DOCA Compatibility
  Policy. A skewed DPACC is the canonical *image links but
  fails at runtime* failure mode the bundle exists to
  prevent.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's detect → prefer → fall back → report contract
  for structured helper tools. The `Command appendix` in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification (DPACC is shipped as part of the DOCA
  install train; missing DPACC = install or partial-install
  problem, route through here), and the *I have no install
  yet* path with the public NGC DOCA container.
- [`doca-debug`](../../doca-debug/SKILL.md) — the
  cross-cutting debug ladder (install / version / build /
  link / runtime / program / driver). DPACC failures
  overlay layers 3 (build) and 4 (link) on top of the
  ladder; runtime failures of a DPACC-produced image escalate
  to layer 5 (runtime) on the host-side `doca-dpa` flow.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns. The cross-library
  build-from-sample workflow this skill rides on top of for
  the DPACC overlay lives there; this skill cross-links
  rather than duplicates.
