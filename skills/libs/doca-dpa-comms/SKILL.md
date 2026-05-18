---
name: doca-dpa-comms
description: NVIDIA DOCA DPA Comms on BlueField hosts — the DPA-SIDE communication primitives library the user's DPA-side kernel calls from INSIDE the DPA processor to send / receive small messages between DPA threads or signal another DPA thread, including its position as the DPA-side companion to host-side `doca-dpa` (which loads the DPA application image produced by `dpacc` and drives the per-DPA-instance lifecycle), the host-side capability-budget commit via `doca_dpa_comms_cap_*` that fixes what the DPA kernel may use at app-load time, the dependency on `dpacc` for compiling the DPA-side translation unit, the DPA-side error surface flowing back to the host via the `doca_dpa_completion` mechanism owned by `doca-dpa`, and the routing rule that disambiguates DPA-side comms (`doca-dpa-comms`, this skill) from host-side messaging libraries (`doca-comch`, `doca-rdma`) and from the sibling DPA-side RDMA library (`doca-dpa-verbs`).
kind: library
---

# DOCA DPA Comms

**Where to start:** This skill assumes DOCA is already installed,
the user's BlueField has a DPA processor and the host can see
it, the user has already adopted the host-side `doca-dpa`
library to load and launch a DPA application, and the user is
now writing **DPA-side kernel code** that needs to communicate
between DPA threads (or between DPA threads and host / DPU
code). Open [`TASKS.md`](TASKS.md) if the user wants to *do*
something (configure / build / modify / run / test / debug);
open [`CAPABILITIES.md`](CAPABILITIES.md) when the question is
*what DPA-side communication primitives can this library
express* on the loaded app's committed capability budget. If
the user has not installed DOCA yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user
has not yet adopted the host-side DPA library, route to the
parent [`doca-dpa`](../doca-dpa/SKILL.md) skill first — this
skill is the **DPA-side companion**, not a standalone library.
If the user actually wants host-side messaging between a host
program and a DPU agent, that is **a different scope**: route
to [`doca-comch`](../doca-comch/SKILL.md) for control-plane
PCIe messaging or to [`doca-rdma`](../doca-rdma/SKILL.md) for
host-to-remote-peer RDMA; conflating either with this skill is
the most common DPA-side first-app design error.

## Example questions this skill answers well

The CLASSES of DPA Comms questions this skill is built to
answer, each with one worked example. The agent should treat
the *class* as the load-bearing piece — the worked example is
a single instance.

- **"How does a DPA kernel send a small message to another DPA
  thread on the same DPA processor?"** — worked example: *"two
  DPA threads in the same loaded `doca_dpa_app`; thread A
  produces a counter value, sends it to thread B over a
  DPA-side comms endpoint, and thread B signals the host
  through the `doca-dpa` completion path that the round trip
  finished"*. Answered by the DPA-side endpoint + send /
  receive primitive table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  plus the configure / smoke workflow in
  [`TASKS.md ## configure`](TASKS.md#configure) and
  [`TASKS.md ## test`](TASKS.md#test) step 1.
- **"Am I supposed to call `doca-dpa-comms` from my host
  program or from inside my DPA kernel?"** — worked example:
  *"the user's `pkg-config --libs` on the host returns
  `-ldoca-dpa-comms` and a host-side link fails"*. Answered
  by the host-vs-DPA-side routing rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  audience-and-side table plus the build-slot table in
  [`TASKS.md ## build`](TASKS.md#build) that names where this
  library belongs on the link line and where it does NOT.
- **"How do I check whether the comms primitive I want to use
  is available on my BlueField + this DOCA install, given the
  DPA kernel itself can't really cap-query at runtime?"** —
  worked example: *"I want to use a specific DPA-side comms
  primitive; do I have to commit to it at app-load time on
  the host?"*. Answered by the host-side capability-budget
  rule (`doca_dpa_comms_cap_*` called from host code before
  the DPA app is loaded into the `doca_dpa` context) in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  capability-discovery section plus the cap-query step in
  [`TASKS.md ## configure`](TASKS.md#configure) step 3.
- **"My DPA kernel returns `DOCA_ERROR_AGAIN` from a
  DPA-side comms send. What do I do?"** — worked example:
  *"a DPA thread submitting to a comms endpoint sees `_AGAIN`
  back through the host-side `doca_dpa_completion`; the host
  log shows the kernel is alive"*. Answered by the
  DPA-Comms-specific error overlay in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  (`_AGAIN` means the DPA-side comms queue is full and the
  DPA kernel must yield), plus the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) layer 5 that walks
  the host-side drain-then-yield pattern with the kernel-side
  cooperative back-off.
- **"Is the DPA-side comms primitive I see in the docs in my
  installed DOCA + my DPACC compiler?"** — worked example:
  *"the public DPA Comms guide names a primitive; is it
  available on this install given the DPACC version I have
  alongside DOCA?"*. Answered by the version-compatibility
  overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md), adds the
  DPA-Comms-specific *DOCA must match DPACC* overlay
  inherited from `doca-dpa`, and routes the user to query
  the host-side cap budget before the agent quotes from a
  doc page.
- **"What does this DPA-Comms `DOCA_ERROR_*` (delivered to me
  on the host through `doca_dpa_completion`) mean and which
  layer caused it?"** — worked example: *"the host
  completion for a DPA-side comms call reports
  `DOCA_ERROR_BAD_STATE` even though the kernel itself
  appears to be running"*. Answered by the DPA-Comms overlay
  on the cross-library taxonomy in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  plus the layered ladder in
  [`TASKS.md ## debug`](TASKS.md#debug) that escalates to
  [`doca-debug`](../../doca-debug/SKILL.md) and to the
  parent host-side
  [`doca-dpa`](../doca-dpa/SKILL.md) skill for any host-side
  lifecycle root cause.

## Audience

This skill serves **external developers writing DPA-side
kernel code that uses the DOCA DPA Comms library** — i.e.,
users whose code is compiled by the DPACC compiler into the
binary the host executable embeds as a `doca_dpa_app`, and
whose DPA kernel function bodies call DOCA DPA Comms
primitives from *inside the DPA processor* to send / receive
messages between DPA threads or signal another thread. It is
*not* for NVIDIA developers contributing to DOCA DPA Comms
itself, and it is *not* the right place to learn how the
host-side program drives the DPA app lifecycle (loading the
image, creating DPA execution contexts, launching kernels,
draining completions) — that surface lives in the parent
[`doca-dpa`](../doca-dpa/SKILL.md) skill.

**Language scope.** DOCA DPA Comms ships as a DPA-side C
library with `pkg-config` module name `doca-dpa-comms`. The
DPA-side translation unit that calls into this library is
compiled by the DPACC compiler (`dpacc`) into the binary the
host executable embeds; the host's system C / C++ compiler is
not a substitute, and the host-side link line should NOT
include `-ldoca-dpa-comms`. The shipped samples at
`/opt/mellanox/doca/samples/doca_dpa_comms/` are the verified
DPA-side source of truth and pair with the host-side
`doca-dpa` translation units that load and launch them. There
is no language-binding escape hatch for the DPA-side code —
the DPA kernel must be a translation unit `dpacc` accepts —
so the skill keeps its cap-discovery, error-taxonomy, and
kernel-side cooperative-back-off guidance language-neutral
for the host-side wrapper case only.

## When to load this skill

Load this skill when the user is writing **DPA-side kernel
code that needs to communicate** — between DPA threads inside
the same DPA app, or to signal completion of DPA-side work
back to host or DPU code through the host-side `doca-dpa`
completion mechanism. Concretely:

- Calling DPA-side communication primitives from inside a DPA
  kernel function body — endpoint handles, small-message
  send / receive primitives, signal / event primitives — that
  the DPACC compiler will link against the `doca-dpa-comms`
  library when it produces the DPA application binary.
- Wiring two or more `doca_dpa_thread` execution contexts
  (created on the host side via `doca-dpa`) to exchange
  values, coordinate ordering, or wake each other up via
  DOCA DPA Comms signal primitives.
- Reasoning about which DPA-side comms primitives are
  available on the user's BlueField + DOCA install, *given
  that the host-side program commits to that capability
  budget at app-load time* via the `doca_dpa_comms_cap_*`
  family called from host code (DPA-side runtime cap-query
  is not the place this decision lives).
- Debugging a `DOCA_ERROR_*` that surfaces back through the
  host-side `doca_dpa_completion` mechanism owned by
  `doca-dpa` but that originated in a DPA-side comms call —
  in particular disambiguating *DPA-side comms queue full*
  (`_AGAIN`, kernel must yield) from *primitive not
  supported on this DPA generation* (`_NOT_SUPPORTED`, the
  capability budget at app-load time was inconsistent with
  the kernel's usage) from *DPA-side lifecycle violation*
  (`_BAD_STATE`, the kernel used a comms primitive before it
  was usable inside the kernel).
- Choosing between this DPA-side communication library and
  the sibling DPA-side **`doca-dpa-verbs`** library when the
  DPA kernel needs to do something more than message-passing
  between local DPA threads — `doca-dpa-comms` is for local
  inter-thread / coordination messaging on the DPA;
  `doca-dpa-verbs` is for ibverbs-style RDMA from inside the
  DPA kernel to remote peers (route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the public DPA Verbs guide).

Do **not** load this skill for general DOCA orientation,
install of DOCA or the DPACC compiler, the host-side DPA
control surface itself (loading the DPA app, creating DPA
threads, launching kernels, draining completions — that is
[`doca-dpa`](../doca-dpa/SKILL.md)), host-side messaging
between a host process and a DPU agent over PCIe (that is
[`doca-comch`](../doca-comch/SKILL.md)), host-side
host-to-remote-peer RDMA (that is
[`doca-rdma`](../doca-rdma/SKILL.md)), or DPA-side RDMA from
inside the DPA kernel (that is the sibling DPA-side library
`doca-dpa-verbs`, no skill in this bundle yet — route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).

## What this skill provides

This is a **thin loader**. The body keeps only the
orientation needed to pick the right next file. The
substantive DPA-Comms-specific material lives in two
companion files:

- `CAPABILITIES.md` — what the DPA-side comms surface can
  express on this version + this BlueField generation, given
  the capability budget the host-side program commits at
  app-load time: the DPA-side endpoint handle shape, the
  send / receive small-message primitive family, the signal /
  event primitive family for inter-thread coordination, the
  host-side cap-query surface (`doca_dpa_comms_cap_*`) that
  bounds what the DPA kernel may call, the DPA-Comms error
  taxonomy mapped onto the cross-library `DOCA_ERROR_*` set
  *as observed on the host through the parent skill's
  completion mechanism*, the observability surface (host-side
  completions are the primary observation point; DPA-side
  developer tools named in `doca-dpa` apply unchanged), and
  the safety policy that gates the parent-skill prerequisites
  this library inherits from `doca-dpa`.
- `TASKS.md` — step-by-step workflows for the six in-scope
  DPA-Comms verbs: `configure`, `build`, `modify`, `run`,
  `test`, `debug`. Plus a `Deferred task verbs` block that
  points out-of-scope questions at the right next skill — in
  particular at the parent host-side
  [`doca-dpa`](../doca-dpa/SKILL.md) skill for anything the
  host program owns.

The skill assumes a host where DOCA is already installed at
the standard location, a BlueField with a DPA processor is
physically present and visible to the host, the DPACC
compiler is installed at a version matched to the DOCA
install per the DOCA Compatibility Policy, and the user has
already brought up a working host-side `doca-dpa` flow
(per the parent [`doca-dpa`](../doca-dpa/SKILL.md) skill) —
this skill is the *DPA-side layer that runs inside that
flow's loaded `doca_dpa_app`*, not a standalone path. It does
not cover installing DOCA or the DPACC compiler — that path
goes through [`doca-setup`](../../doca-setup/SKILL.md).

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or templates
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Pre-written DPA-side kernel source that calls DOCA DPA
  Comms primitives, in any language.** The verified DPA-side
  comms source is the shipped C + DPA-side samples at
  `/opt/mellanox/doca/samples/doca_dpa_comms/`. The agent's
  job is to route the user to those files and prescribe a
  minimum-diff modification on them via the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md),
  layered with the DPA-Comms-specific overrides in
  [`TASKS.md ## modify`](TASKS.md#modify).
- **Pre-written host-side `doca-dpa` driver code** that the
  DPA-side kernel would pair with. That is the parent
  [`doca-dpa`](../doca-dpa/SKILL.md) skill's territory, not
  this one — and even there, the parent skill refuses to
  ship pre-written source, for the same reason.
- **Standalone build manifests** (`meson.build`,
  `CMakeLists.txt`, …) parked inside the skill. The agent
  constructs the build manifest *in the user's project
  directory* against the user's installed DOCA + DPACC
  compiler, where `pkg-config --modversion doca-dpa-comms`
  and the installed `dpacc` are the joint sources of truth
  for the DPA-side library's version + the DPA-side
  toolchain.
- **A `samples/`, `bindings/`, or `reference/` subtree** of
  any kind. A mock or incomplete artifact in this skill's
  tree, even one labeled "reference", is misleading: users
  will read it as buildable DPA-side code.
- **The DPA-side kernel function-body API symbol set
  enumerated from memory.** The exact symbol names on the
  DPA side are install-bound and live in the headers DPACC
  uses against this DOCA install; the agent's job is to
  route the user to the shipped samples at
  `/opt/mellanox/doca/samples/doca_dpa_comms/` and to the
  public *DOCA DPA Comms* guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the per-symbol surface, not to quote symbols from
  memory.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (DPA-side kernel-resident comms work, not
   host-side messaging and not DPA-side RDMA).
2. **For the DPA-Comms capability matrix, the DPA-side
   endpoint / send / receive / signal primitive families,
   the host-side capability-budget rule that fixes what the
   DPA kernel may use at app-load time, the version overlay,
   the error taxonomy (observed on the host through the
   parent skill's completion mechanism), the observability
   surface, and the safety policy that inherits the parent
   `doca-dpa` env-precondition matrix, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — configure, build, modify,
   run, test, debug — see [TASKS.md](TASKS.md).**

Both companion files cross-link to each other, to the parent
host-side [`doca-dpa`](../doca-dpa/SKILL.md) skill for every
host-side decision this skill inherits,
[`doca-version`](../../doca-version/SKILL.md) for the
canonical DOCA version-handling rules (with the DPA overlay
that DOCA must match the DPACC compiler), and
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
whenever the right answer is "look it up in the public DOCA
DPA Comms guide, the shipped sample tree, or the on-disk
install layout" rather than "DPA-Comms-specific guidance".

## Related skills

- [`doca-dpa`](../doca-dpa/SKILL.md) — **parent skill**.
  Host-side library that creates the per-DPA-instance
  `doca_dpa` Core context, loads the DPA application image
  (the binary `dpacc` produced from the user's DPA-side
  source that calls into this `doca-dpa-comms` library),
  creates DPA execution contexts, launches DPA kernels with
  arguments, and drains the `doca_dpa_completion` through
  which DPA-side errors (including DPA-Comms errors) surface
  on the host. This skill is the **DPA-side companion** to
  that host-side surface. Treat them as a paired pair on
  every question; conflating them is the canonical first-app
  failure mode.
- [`doca-comch`](../doca-comch/SKILL.md) — **different
  scope**. Host ↔ DPU control-plane messaging over PCIe; the
  user's code calls `doca_comch_*` **from the host (or from
  the DPU Arm), NOT from inside a DPA kernel**. If the user's
  goal is to exchange messages between a host process and a
  DPU process, that is `doca-comch`, not this library. The
  agent's job is to ask which side the user is writing for
  *before* recommending either.
- [`doca-rdma`](../doca-rdma/SKILL.md) — **different scope**.
  Host-side RDMA between the host and a remote peer; the
  user's code calls `doca_rdma_*` from the host. If the user
  wants RDMA from inside a DPA kernel, that is the sibling
  DPA-side library `doca-dpa-verbs`, NOT this library and
  NOT `doca-rdma`. Both routes go through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  the routing table for every public DOCA documentation
  source and the on-disk layout of an installed DOCA
  package. The DPA Comms public guide is at
  <https://docs.nvidia.com/doca/sdk/DOCA-DPA-Comms/index.html>;
  the sibling DPA Verbs guide and the parent DPA host-side
  guide live in the same routing table.
- [`doca-setup`](../../doca-setup/SKILL.md) — env
  preparation, install verification, DPACC compiler install /
  verification, BlueField-with-DPA mode checks. This skill
  assumes its preconditions are satisfied AND that the
  parent [`doca-dpa`](../doca-dpa/SKILL.md) skill's env
  preconditions are also satisfied (matched DOCA + DPACC,
  BlueField exposing the DPA to the host).
- [`doca-version`](../../doca-version/SKILL.md) — canonical
  DOCA version-handling rules. This skill's `## Version
  compatibility` cross-links the four-way match rule and
  inherits the DPA-specific *DOCA-and-DPACC must match*
  overlay from the parent skill per the DOCA Compatibility
  Policy.
- [`doca-structured-tools-contract`](../../doca-structured-tools-contract/SKILL.md) —
  the bundle's structured-tools precedence rule (detect /
  prefer / fall back / report). The Command appendix in
  [TASKS.md](TASKS.md) honors this contract.
- [`doca-programming-guide`](../../doca-programming-guide/SKILL.md) —
  general DOCA programming patterns shared by every library:
  the canonical `pkg-config` + meson build pattern, the
  universal modify-a-shipped-sample first-app workflow, the
  universal Core-context lifecycle (which the parent
  `doca-dpa` skill, not this one, drives directly), the
  cross-library `DOCA_ERROR_*` taxonomy, and the program-side
  debug order. This skill layers the DPA-side-comms
  specifics on top.
- [`doca-debug`](../../doca-debug/SKILL.md) — the
  cross-cutting debug ladder (install / version / build /
  link / runtime / program / driver). DPA-Comms-specific
  debug (DPA-side comms queue full versus DPA-side
  lifecycle violation versus capability-budget mismatch at
  app-load time) overlays on top of that ladder and on top
  of the parent `doca-dpa` DPA overlay.

DOCA DPA Comms's sibling — `doca-dpa-verbs` (DPA-side
ibverbs-like RDMA verbs the DPA kernel itself calls to talk
to remote peers) — is a **different DPA-side library** with
its own pkg-config module and its own public guide. No skill
ships for it in this bundle yet; for any DPA-side RDMA
question, route via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
to the public *DOCA DPA Verbs* guide and to the shipped
samples on disk. Conflating *DPA-side comms* with *DPA-side
verbs* (both are DPA-resident, but only one is RDMA-shaped)
is the most common DPA-side library-selection error after the
host-vs-DPA-side question itself.
