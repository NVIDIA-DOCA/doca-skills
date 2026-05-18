---
name: doca-rdma-verbs
description: NVIDIA DOCA RDMA Verbs (pkg-config doca-rdma-verbs) — the LOWER-LEVEL Verbs surface beneath DOCA RDMA, exposing ibverbs-like QP / CQ / PD / MR primitives inside the DOCA Core context model. This skill's primary job is to route most users BACK to doca-rdma; it only takes the conversation when the user has confirmed doca-rdma does not expose the specific verb / opcode / WR flag they need. Covers when to drop down vs stay up, the libibverbs-vs-doca-rdma-verbs boundary (do not mix handles), capability discovery via doca_rdma_verbs_cap_*, the DOCA Core lifecycle in verbs terms, the porting path from existing libibverbs code, and debugging DOCA_ERROR_* returns from raw-verbs calls.
kind: library
---

# DOCA RDMA Verbs

**Where to start:** This skill is the **raw-verbs escape hatch
beneath [`doca-rdma`](../doca-rdma/SKILL.md)**. The agent's first
job, before anything else, is to confirm the user actually needs to
drop down — most users do not, and the right answer is almost
always *"stay in `doca-rdma`"*. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
does the verbs surface actually expose and where is the boundary
with vanilla libibverbs*; open [`TASKS.md`](TASKS.md) when the user
has *already confirmed* they need raw verbs and wants the
configure / build / modify / run / test / debug workflow for them.
If the user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first.

## The decision this skill exists to gate

The single load-bearing decision every conversation that loads this
skill must make, FIRST, before any code-level discussion:

1. **Has the user confirmed that the higher-level
   [`doca-rdma`](../doca-rdma/SKILL.md) does not expose the
   semantic they need?** If no — stop here, route back to
   `doca-rdma`. The most common baseline-agent failure for raw
   verbs is recommending them *unnecessarily* because the user
   said the word "verbs" or "QP" without checking whether the
   higher-level surface already covers their case.
2. **Is the semantic the user needs a specific verb / opcode /
   work-request flag / QP option that `doca-rdma` genuinely does
   not expose?** Examples: a specific raw WR flag the
   `doca_rdma_task_*` abstractions do not surface; custom
   completion-queue handling beyond what the DOCA progress engine
   exposes; an esoteric QP attribute. If yes — this skill is in
   scope.
3. **Is the user porting existing libibverbs code into the DOCA
   Core model?** This skill is in scope, AND the agent must teach
   the porting path (replace libibverbs handles with
   `doca-rdma-verbs` handles, integrate with the DOCA Core
   lifecycle, drive completions via the DOCA progress engine
   instead of polling CQ directly) rather than recommend a
   mechanical 1:1 textual replacement.

If none of (1)-(3) apply, the answer to *"should I use
`doca-rdma-verbs`?"* is **no**. Route the user back to
[`doca-rdma`](../doca-rdma/SKILL.md). This is by design: a
correctly-loaded raw-verbs skill that talks the user *out* of raw
verbs is doing its job.

## Example questions this skill answers well

The CLASSES of raw-verbs questions this skill is built to answer,
each with one worked example. The agent should treat the *class*
as the load-bearing piece — the worked example is a single
instance.

- **"Should I drop to `doca-rdma-verbs` for this?"** — worked
  example: *"I want to set a specific raw work-request flag and
  the `doca_rdma_task_*` abstraction does not expose it"*.
  Answered by the path-selection rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  doca-rdma-vs-doca-rdma-verbs table + the *climb back up* step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How is `doca-rdma-verbs` different from `libibverbs`?"** —
  worked example: *"I have existing `ibv_*` code; can I just keep
  using it and call `doca_*` next to it?"*. Answered by the
  libibverbs-vs-doca-rdma-verbs boundary rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the porting workflow in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **"Is this raw verb / opcode / QP option supported on my device
  + DOCA version?"** — worked example: *"does this device
  advertise the QP feature my raw WR needs"*. Answered by the
  capability-query rule (`doca_rdma_verbs_cap_*` against a
  `doca_devinfo`) in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the discovery step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"I'm porting libibverbs code into the DOCA Core model — what
  does the agent walk me through?"** — worked example: *"I have a
  small libibverbs sender/receiver and want it to live inside a
  DOCA Core context"*. Answered by the porting overlay in
  [`TASKS.md ## modify`](TASKS.md#modify) +
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  no-mixing rule.
- **"What does this `DOCA_ERROR_*` from a raw-verbs call mean?"** —
  worked example: *"`DOCA_ERROR_IO_FAILED` from a WR submission —
  what do I look at?"*. Answered by the verbs overlay on the
  cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (which sends the agent to inspect the completion-queue entry,
  not the submit return value) + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"When do I climb back up from `doca-rdma-verbs` to
  `doca-rdma`?"** — worked example: *"my raw-verbs prototype works;
  do I keep it or refactor onto `doca-rdma`?"*. Answered by the
  climb-back rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (raw verbs is a *targeted* surface, not a default; once the
  specific need is covered, the higher-level surface is the
  long-term home).

## Audience

This skill serves **external developers building applications that
consume the DOCA RDMA Verbs library** — i.e., users whose code
calls `doca_rdma_verbs_*` (directly in C/C++, or through
FFI/bindings from another language) for raw QP / CQ / PD / MR
control inside a DOCA Core context. It is *not* for NVIDIA
developers contributing to DOCA RDMA Verbs itself, and it is *not*
the right entry point for general DOCA RDMA work — that belongs in
[`doca-rdma`](../doca-rdma/SKILL.md).

**Language scope.** DOCA RDMA Verbs ships as a C library with
`pkg-config` module name `doca-rdma-verbs`. The shipped samples
are written in C (NVIDIA's choice) and live under
`/opt/mellanox/doca/samples/doca_rdma_verbs/`. C and C++ consumers
are the canonical case; the worked examples in `TASKS.md` assume
that path. Other-language consumers (Rust, Go, Python, …) consume
the same `*.so` through FFI or language-specific bindings; the
skill's contribution in that case is to keep the *drop-down
decision*, *libibverbs boundary*, *cap-query rule*, *lifecycle in
verbs terms*, and *error-handling rule* language-neutral, and to
route the agent to the public C ABI as the authoritative surface
that any wrapper will eventually call.

## When to load this skill

Load this skill ONLY after the user (or the agent on the user's
behalf) has confirmed `doca-rdma` does not expose the semantic
they need. Concretely:

- The user explicitly asks *"do I need to drop to `doca-rdma-verbs`
  for this?"* — load this skill to answer, but expect the answer
  to be *"no, stay in `doca-rdma`"* unless the user can name the
  specific verb / opcode / option the higher-level library does
  not surface.
- The user wants a specific raw WR flag, raw QP option, or custom
  CQ-handling pattern that `doca_rdma_task_*` does not expose.
- The user is porting existing libibverbs code into the DOCA Core
  model and needs the integration path (lifecycle, progress
  engine, no-mixing rule).
- A `DOCA_ERROR_*` returned from a `doca_rdma_verbs_*` call needs
  diagnosis — including the IO_FAILED case where the answer lives
  on the completion-queue entry, not the submit return.
- Designing or extending non-C bindings (Rust, Go, Python, …) that
  wrap the verbs C ABI — for the boundary, lifecycle, and
  cap-query rules the wrapper must honor.

Do **not** load this skill for: general DOCA RDMA work (use
[`doca-rdma`](../doca-rdma/SKILL.md)); a use case `doca-rdma`
already covers (use [`doca-rdma`](../doca-rdma/SKILL.md)); use
cases a different higher-level DOCA library covers ([`doca-flow`](../doca-flow/SKILL.md)
for steering, [`doca-rivermax`](../doca-rivermax/SKILL.md) for
media, and the `doca-sta` library for NVMe-oF — routed via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md));
install of DOCA itself (use
[`doca-setup`](../../doca-setup/SKILL.md)); or general DOCA
orientation (use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive raw-verbs
material lives in two companion files:

- `CAPABILITIES.md` — what `doca-rdma-verbs` can express on this
  version: the doca-rdma-vs-doca-rdma-verbs selection table,
  the libibverbs-vs-doca-rdma-verbs boundary, the verbs object
  model (QP / CQ / PD / MR) inside DOCA Core, the capability-query
  surface (`doca_rdma_verbs_cap_*`), the raw-verbs error taxonomy
  (mapped onto the cross-library `DOCA_ERROR_*` set, with the
  IO_FAILED → completion-queue-entry overlay), the observability
  surface (DOCA progress engine vs manual CQ polling), and the
  safety policy that gates the no-mixing-with-libibverbs rule.
- `TASKS.md` — step-by-step workflows for the six in-scope verbs:
  `configure`, `build`, `modify`, `run`, `test`, `debug`. Plus a
  `Deferred task verbs` block that points out-of-scope questions
  at the right next skill. Every workflow assumes the drop-down
  decision in this `SKILL.md` has already been made; the
  `## configure` step always begins by re-confirming it.

The skill assumes a host or BlueField where DOCA is already
installed at the standard location and the user has the privileges
their public install profile expects (the RDMA stack on host with
proper module loads, same as
[`doca-rdma`](../doca-rdma/SKILL.md)). It does not cover
installing DOCA — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA RDMA Verbs application source code, in any
  language.** The verified verbs source code is the shipped C
  samples at `/opt/mellanox/doca/samples/doca_rdma_verbs/<name>/`.
  The agent's job is to route the user to those files and
  prescribe a minimum-diff modification on them via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the verbs-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  `Cargo.toml`, …) parked inside the skill. The agent constructs
  the build manifest *in the user's project directory* against the
  user's installed DOCA, where `pkg-config --modversion
  doca-rdma-verbs` is the source of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.
- **A migration script from libibverbs to `doca-rdma-verbs`.**
  The porting path is *judgment*, not a mechanical textual
  replacement — see
  [`TASKS.md ## modify`](TASKS.md#modify) for why.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question is in
   scope — i.e., to walk the drop-down decision above.
2. **For the doca-rdma-vs-doca-rdma-verbs split, the
   libibverbs-vs-doca-rdma-verbs boundary, the verbs object model,
   capability discovery, error taxonomy, observability, and
   safety policy, see [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other,
[`doca-rdma`](../doca-rdma/SKILL.md) as the canonical higher-level
home, [`doca-version`](../../doca-version/SKILL.md) for the
canonical version-handling rules, and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public docs or
the installed package layout" rather than "verbs-specific
guidance".

## Related skills

- [`doca-rdma`](../doca-rdma/SKILL.md) — the canonical higher-level
  DOCA RDMA library and the home this skill routes most users
  *back* to. Every conversation that loads `doca-rdma-verbs`
  should also have `doca-rdma` loaded so the climb-back-up answer
  is immediate when the raw-verbs need turns out to be coverable
  there.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source
  and the on-disk layout of an installed DOCA package. The
  RDMA Verbs page is listed there; this skill does not duplicate
  the URL.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, and the *I have no install yet* path
  with the public NGC DOCA container. This skill assumes its
  preconditions are satisfied.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule (with `doca-rdma-verbs.pc`
  joining the match set) and the cap-query-is-runtime-authority
  rule.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer
  / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal
  lifecycle, the cross-library `DOCA_ERROR_*` taxonomy, and the
  program-side debug order. This skill layers raw-verbs specifics
  on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). Raw-verbs-specific debug (completion-entry
  inspection, no-mixing-with-libibverbs, lifecycle in verbs terms)
  overlays on top of that ladder.
