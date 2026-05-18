---
name: doca-dpa-verbs
description: NVIDIA DOCA DPA Verbs (pkg-config doca-dpa-verbs) — the DPA-SIDE verbs surface, an ibverbs-like RDMA primitive set the DPA kernel itself calls (work-request post for send / RDMA read / RDMA write / atomic, plus completion polling) so a DPA kernel running on the BlueField DPA processor can issue RDMA directly without a host round-trip. Companion to the host-side doca-dpa library, which configures the underlying QPs and loads the DPA application image via DPACC. This skill's primary job is to navigate the 4-way matrix (host-side doca-rdma vs host-side doca-rdma-verbs vs DPA-side doca-dpa-comms vs DPA-side doca-dpa-verbs) and to confirm the host round-trip is actually the latency bottleneck before recommending this drop-down.
kind: library
---

# DOCA DPA Verbs

**Where to start:** This skill is the **DPA-side raw-verbs surface
beneath the parent [`doca-dpa`](../doca-dpa/SKILL.md) host-side
control library**, and the **DPA-side counterpart to the host-side
[`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md)**. The agent's
first job, before anything else, is to navigate the **4-way matrix**
in [`## The 4-way matrix this skill exists to navigate`](#the-4-way-matrix-this-skill-exists-to-navigate)
below and confirm the user really belongs in this corner — most
RDMA users belong on host-side [`doca-rdma`](../doca-rdma/SKILL.md),
not here. Open [`CAPABILITIES.md`](CAPABILITIES.md) when the
question is *what does the DPA-side verbs surface express and how
does host-configures-QP / DPA-uses-QP work*; open
[`TASKS.md`](TASKS.md) when the user has *already confirmed* they
need DPA-side RDMA and wants the configure / build / modify / run /
test / debug workflow for it. If the user has not installed DOCA
yet, route to [`doca-setup`](../../doca-setup/SKILL.md) first; if
the user is asking how to *use the host-side DPA control library at
all*, route to [`doca-dpa`](../doca-dpa/SKILL.md) — that is the
parent and this skill assumes it.

## The 4-way matrix this skill exists to navigate

The single load-bearing decision every conversation that loads this
skill must make, FIRST, before any code-level discussion. DOCA
splits RDMA across TWO axes — *execution side* (host CPU vs DPA
processor on the BlueField) and *abstraction level* (high-level
task abstractions vs raw verbs primitives). The 2×2 yields four
distinct libraries, each with a different right-use case:

| Library | Execution side | Abstraction level | Default for | Drop-down indicator |
| --- | --- | --- | --- | --- |
| [`doca-rdma`](../doca-rdma/SKILL.md) | Host CPU | High-level tasks (Send / Receive / Read / Write / Atomic / Sync-Event) | **The vast majority of RDMA work.** The right answer for any user whose RDMA can live on the host. | None — this is the default home |
| [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) | Host CPU | Raw verbs (QP / CQ / PD / MR; raw WRs) | The narrow case where `doca-rdma`'s task abstractions don't expose the verb / opcode / WR flag the user needs, but RDMA still lives on the host | `doca-rdma` confirmed not to expose the specific primitive |
| [`doca-dpa-comms`](../doca-dpa/SKILL.md) (DPA-side, routed via parent) | DPA processor | Local DPA-side messaging primitives | DPA kernels coordinating among themselves or with host-resident state | Different purpose — not RDMA at all |
| **`doca-dpa-verbs`** (this skill) | DPA processor | Raw verbs (DPA-side QP handles, WR post, CQ poll) | The narrow case where a DPA kernel needs to issue RDMA directly without round-tripping to the host — **latency-bound, tightly-coupled compute + communication** | host round-trip confirmed to be the actual bottleneck AND `doca-dpa` already adopted for DPA-resident compute |

The agent's rule, before touching any code:

1. **Has the user adopted [`doca-dpa`](../doca-dpa/SKILL.md) for
   DPA-resident compute?** If no — this skill is not in scope. The
   DPA-side verbs surface presupposes the DPA-side compute the
   parent library lifecycle owns. Route to
   [`doca-dpa`](../doca-dpa/SKILL.md) first.
2. **Is the host round-trip actually the latency bottleneck?** If
   no — stay on host-side ([`doca-rdma`](../doca-rdma/SKILL.md) or
   [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md)). Latency-tuning
   is the *entire* reason to drop to DPA-side verbs; if the host
   round-trip is not on the critical path, the maintenance cost of
   a two-side-program RDMA setup is not paid for. Recommending this
   skill for a host-bottleneck workload is a misroute.
3. **Does the user need RDMA semantics (sends, RDMA reads / writes,
   atomics) from inside the DPA kernel?** If no but the user needs
   DPA-side local messaging — route to the DPA-side
   [`doca-dpa-comms`](../doca-dpa/SKILL.md) via the parent skill's
   public-knowledge-map route; that is a different DPA-side library
   with a different purpose.
4. **Is it (1) yes AND (2) yes AND (3) yes?** Then this skill is in
   scope. Continue.

A correctly-loaded DPA-Verbs skill that talks the user *out* of
DPA-side RDMA when the host round-trip isn't the bottleneck is doing
its job — same shape as
[`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) talking users out
of raw verbs.

## Example questions this skill answers well

The CLASSES of DPA-Verbs questions this skill is built to answer,
each with one worked example. The agent should treat the *class* as
the load-bearing piece — the worked example is a single instance.

- **"Should I do RDMA from inside my DPA kernel?"** — worked
  example: *"my DPA kernel does a small compute and then needs to
  fetch the next input from a remote node; would moving the RDMA
  read into the kernel cut latency?"*. Answered by the 4-way matrix
  in
  [`## The 4-way matrix this skill exists to navigate`](#the-4-way-matrix-this-skill-exists-to-navigate)
  + the latency-bottleneck check in
  [`TASKS.md ## configure`](TASKS.md#configure) step 1.
- **"How does the host configure a QP that the DPA kernel will
  use?"** — worked example: *"my host program already creates an
  RDMA connection through `doca-dpa`; how do I make the QP
  callable from a `doca-dpa-verbs` post inside the DPA kernel?"*.
  Answered by the host-configures-QP / DPA-uses-QP rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the configure workflow in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"Is this DPA-side verb / opcode supported on my hardware + DOCA
  + DPACC?"** — worked example: *"can my BlueField generation
  expose RDMA atomics to the DPA kernel via `doca-dpa-verbs`?"*.
  Answered by the host-side cap-query rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (cap-query lives on the host before kernel launch, not inside the
  kernel) + the discovery step in
  [`TASKS.md ## configure`](TASKS.md#configure).
- **"How does the host know the DPA-side RDMA op finished?"** —
  worked example: *"my DPA kernel posts an RDMA read; when does
  the host see the completion?"*. Answered by the DPA-side post +
  CQE inspection split in
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
  + the completion-handling step in
  [`TASKS.md ## run`](TASKS.md#run).
- **"What does this `DOCA_ERROR_*` from my DPA-side RDMA mean?"** —
  worked example: *"`DOCA_ERROR_IO_FAILED` after a DPA-side RDMA
  read — what do I look at and from which side?"*. Answered by the
  DPA-Verbs overlay on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (CQE inspection happens on the host, not from inside the DPA
  kernel) + the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug).
- **"When should I move RDMA back out of the DPA kernel?"** —
  worked example: *"the latency win didn't materialize — should I
  stay on `doca-dpa-verbs` or refactor back to host-side
  `doca-rdma`?"*. Answered by the climb-back rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  (DPA-side verbs is a *targeted* latency-tuning surface, not a
  default; once the host round-trip is no longer the bottleneck,
  host-side RDMA is the long-term home).

## Audience

This skill serves **external developers who have already adopted
[`doca-dpa`](../doca-dpa/SKILL.md) for DPA-resident compute and now
need their DPA kernel to issue RDMA work requests directly** — i.e.,
users whose DPA-side translation unit (the source DPACC compiles
into the DPA application image the host loads via `doca-dpa`) calls
DPA-side `doca_dpa_verbs_*` primitives to post sends, RDMA reads,
RDMA writes, or atomics on QPs that the *host* configured. It is
*not* for NVIDIA developers contributing to DOCA DPA Verbs itself,
not for general DOCA RDMA work (that belongs in
[`doca-rdma`](../doca-rdma/SKILL.md)), and not for users who have
not yet adopted the DPA itself (route via
[`doca-dpa`](../doca-dpa/SKILL.md) first).

**Language scope.** DOCA DPA Verbs ships as a DPA-side library with
`pkg-config` module name `doca-dpa-verbs`. The DPA-side symbols are
called from inside the DPA kernel — the same translation unit the
DPACC compiler turns into the DPA application image — and are NOT
linked into the host executable's link line. The host side is
covered by the parent [`doca-dpa`](../doca-dpa/SKILL.md) skill. The
shipped DPA Verbs samples are written in the language DPACC accepts
on the DPA side (NVIDIA's choice) plus a host-side C translation
unit; they live under `/opt/mellanox/doca/samples/doca_dpa_verbs/`.
Other-language host-side wrappers around the parent `doca-dpa`
runtime are still useful, but the DPA-side translation unit must be
a unit DPACC accepts (there is no FFI escape hatch on the DPA side);
this skill keeps the lifecycle, host-configures-DPA-uses pattern,
cap-query, and error-taxonomy guidance language-neutral.

## When to load this skill

Load this skill ONLY after the user (or the agent on the user's
behalf) has walked the 4-way matrix above and confirmed:

- The DPA-side compute is *already* on [`doca-dpa`](../doca-dpa/SKILL.md)
  (parent loaded; this skill is an add-on, not a stand-alone entry).
- The host round-trip is *actually* the latency bottleneck for the
  user's workload — confirmed by measurement, not by intuition. If
  the host round-trip is not on the critical path, the right answer
  is host-side RDMA via [`doca-rdma`](../doca-rdma/SKILL.md).
- The user needs RDMA semantics (send / RDMA read / RDMA write /
  atomic) from inside the DPA kernel; for local DPA-side messaging
  the right library is [`doca-dpa-comms`](../doca-dpa/SKILL.md)
  (routed via the parent), not this one.

Concretely:

- The user explicitly asks *"how do I post an RDMA read / write /
  send from inside my DPA kernel?"* — load this skill to answer,
  AFTER the 4-way-matrix check confirms the corner is right.
- The user has a tightly-coupled compute + communication pattern on
  the DPA (next-input fetch, remote completion signal, atomic-based
  coordination) and the host round-trip dominates their measured
  latency.
- The user is debugging a `DOCA_ERROR_*` that surfaces at host-side
  CQE drain after a DPA-side WR post — the diagnosis crosses the
  host / DPA boundary and benefits from the overlay below.
- The user is sizing the host-side QP configuration that the DPA
  kernel will then post against — the host-configures-QP rule
  determines what the DPA-side post can express.

Do **not** load this skill for: general DOCA RDMA work (use
[`doca-rdma`](../doca-rdma/SKILL.md)); raw verbs on the host CPU
(use [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md)); local
DPA-side messaging (use [`doca-dpa-comms`](../doca-dpa/SKILL.md)
via the parent's routing); host-side DPA lifecycle / kernel launch
(use the parent [`doca-dpa`](../doca-dpa/SKILL.md) itself);
install of DOCA or the DPACC compiler (use
[`doca-setup`](../../doca-setup/SKILL.md)); or general DOCA
orientation (use [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).

## What this skill provides

This is a **thin loader**. The body keeps only the orientation
needed to pick the right next file. The substantive DPA-Verbs
material lives in two companion files:

- `CAPABILITIES.md` — what `doca-dpa-verbs` can express on this
  version: the 4-way-matrix selection table, the
  host-configures-QP / DPA-uses-QP coupling rule, the DPA-side
  verbs primitive surface (WR post + CQ poll, opcodes implied by
  the underlying QP configuration), the host-side capability-query
  surface (`doca_dpa_verbs_cap_*` lives on the host BEFORE kernel
  launch, not inside the kernel), the DPA-Verbs error taxonomy
  (mapped onto the cross-library `DOCA_ERROR_*` set, with the
  IO_FAILED → host-side CQE-inspection overlay), the observability
  surface (host-side CQE / completion, DPA-side developer tools via
  the parent), and the safety policy that gates env preconditions
  plus the *do not partial-rebuild one side* rule inherited from
  the parent.
- `TASKS.md` — step-by-step workflows for the six in-scope verbs:
  `configure`, `build`, `modify`, `run`, `test`, `debug`. Plus a
  `Deferred task verbs` block that points out-of-scope questions
  at the right next skill. Every workflow assumes the 4-way-matrix
  decision in this `SKILL.md` has already been made and the parent
  [`doca-dpa`](../doca-dpa/SKILL.md) is loaded; the `## configure`
  step always begins by re-confirming both.

The skill assumes a host or BlueField where DOCA is already
installed at the standard location, a BlueField with a DPA
processor visible to the host, the DPACC compiler installed at a
version matched to the DOCA install per the DOCA Compatibility
Policy, the user already runs a `doca-dpa` host-side setup that
loads a DPA application image, and the user has measured that the
host round-trip is the latency bottleneck. It does not cover
installing DOCA or DPACC — that path goes through
[`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DOCA DPA Verbs application source code or DPA-side
  kernel source, in any language.** The verified DPA-Verbs source
  is the shipped samples under
  `/opt/mellanox/doca/samples/doca_dpa_verbs/`. The agent's job is
  to route the user to those files and prescribe a minimum-diff
  modification on them via the universal modify-a-sample workflow
  in [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the DPA-Verbs-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify) and with the
  two-side-program rule from the parent
  [`doca-dpa`](../doca-dpa/SKILL.md).
- **Standalone build manifests** (`meson.build`, `CMakeLists.txt`,
  …) parked inside the skill. The agent constructs the build
  manifest *in the user's project directory* against the user's
  installed DOCA + DPACC compiler, where `pkg-config --modversion
  doca-dpa-verbs` and the installed `dpacc` are the joint sources
  of truth.
- **A `samples/`, `bindings/`, or `reference/` subtree** of any
  kind. A mock or incomplete artifact in this skill's tree, even
  one labeled "reference", is misleading: users will read it as
  buildable.
- **Host-side DPA lifecycle content.** The host side — `doca_dpa`
  per-instance context, `doca_dpa_app` image load, `doca_dpa_thread`
  execution contexts, the kernel-launch surface, the
  `doca_dpa_completion` host-side observation — lives in the parent
  [`doca-dpa`](../doca-dpa/SKILL.md) skill. This skill names that
  surface where the coupling matters and cross-links; it does not
  redefine it.
- **DPA-side `doca-dpa-comms` content.** That is a *different
  DPA-side library* for local DPA-side messaging, not RDMA. Route
  via the parent's public-knowledge-map link to the
  [DOCA DPA Comms guide](https://docs.nvidia.com/doca/sdk/DOCA-DPA-Comms/index.html);
  this skill does not redefine its surface.

## Loading order

1. Read this `SKILL.md` first to walk the 4-way-matrix decision
   above and confirm the user is in this skill's corner — DPA-side,
   raw RDMA, latency-bound — not in one of the other three corners.
2. **For the host-configures-QP / DPA-uses-QP coupling rule, the
   DPA-side verbs primitive surface, the cap-query rule (host-side,
   before launch), the error taxonomy, the observability split
   (host-side CQE vs DPA-side tools), and the safety policy, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify, run,
   test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other, to the parent
[`doca-dpa`](../doca-dpa/SKILL.md) for the host-side lifecycle and
kernel-launch surface, to the host-side sibling
[`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) for raw-verbs
shape on the host CPU, to the host-side default
[`doca-rdma`](../doca-rdma/SKILL.md) as the canonical climb-back
target when the latency-tuning premise fails to hold, to
[`doca-version`](../../doca-version/SKILL.md) for the canonical
DOCA version-handling rules (with the DPA overlay that DOCA must
match DPACC), and to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public DOCA DPA
Verbs guide, the DPACC guide, the DPA Tools umbrella, or the
on-disk install layout" rather than "DPA-Verbs-specific guidance".

## Related skills

- [`doca-dpa`](../doca-dpa/SKILL.md) — **parent skill**, the
  host-side DPA control library. This skill is an add-on, never a
  stand-alone entry: a user who has not adopted `doca-dpa` cannot
  meaningfully use `doca-dpa-verbs` because the QPs the DPA kernel
  posts on are configured through the host-side DPA setup and the
  DPA-side translation unit that calls `doca_dpa_verbs_*` is the
  same translation unit DPACC compiles into the host-loaded DPA
  application image. Every conversation that loads this skill
  should also have `doca-dpa` loaded.
- [`doca-rdma`](../doca-rdma/SKILL.md) — the canonical higher-level
  host-side home for RDMA, and the climb-back target when the
  latency-tuning premise that justified dropping into the DPA-side
  verbs surface does not hold. Load alongside this skill so the
  climb-back answer is immediate.
- [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) — host-side
  sibling on the same *raw-verbs* axis. The two skills differ in
  execution side (host CPU vs DPA processor) but share the raw-verbs
  shape (per-WR opcode / flag granularity, no task abstraction,
  cap-query density). When the user wants raw verbs but the host is
  fine as the execution side, that is the right sibling.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation source and
  the on-disk layout of an installed DOCA package. The DOCA DPA
  Verbs public guide is at
  <https://docs.nvidia.com/doca/sdk/DOCA-DPA-Verbs/index.html>;
  the DPACC compiler guide and the DPA Tools umbrella (the DPA
  developer / admin CLIs the agent needs when the host-side CQE
  does not arrive) live in the same routing table.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, DPACC compiler install / verification, and
  the *I have no install yet* path with the public NGC DOCA
  container. This skill assumes its preconditions are satisfied
  AND that DPACC is installed at a version matching DOCA.
- [`doca-version`](../../doca-version/SKILL.md) — canonical DOCA
  version-handling rules. This skill's `## Version compatibility`
  cross-links the four-way match rule (with `doca-dpa-verbs.pc`
  joining the match set) and inherits the parent's *DOCA must match
  DPACC* overlay.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect / prefer /
  fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library: the
  canonical `pkg-config` + meson build pattern, the universal
  modify-a-shipped-sample first-app workflow, the universal Core
  lifecycle (used on the host side here), the cross-library
  `DOCA_ERROR_*` taxonomy, and the program-side debug order. This
  skill layers DPA-Verbs specifics on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder (install / version / build / link / runtime /
  program / driver). DPA-Verbs-specific debug (host-side CQE
  inspection from a DPA-side post, two-side-program signature
  mismatch where the QP set the kernel posts on doesn't match the
  host's configuration, DPA-side kernel stuck mid-WR-post visible
  only via the DPA Tools) overlays on top of that ladder.
