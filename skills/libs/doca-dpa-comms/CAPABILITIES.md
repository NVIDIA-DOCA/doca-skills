# DOCA DPA Comms capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your
question (DPA-side endpoint / send-receive / signal / host-side
capability budget / DPA-side error surface / host-side
observability / env preconditions inherited from the parent
host-side skill) and read that section end-to-end. The tables
in each section are the load-bearing content; the prose around
them is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern
(the verbs `configure / build / modify / run / test / debug`),
jump to [TASKS.md](TASKS.md). For every host-side decision
this skill inherits — the per-DPA-instance `doca_dpa` Core
context, the loaded `doca_dpa_app`, the `doca_dpa_thread`
execution context, the host-initiated launch +
`doca_dpa_completion` model, the dual capability discovery on
the DPA itself, the host-side env-precondition matrix — go to
the parent [`doca-dpa`](../doca-dpa/SKILL.md) skill. This
skill layers the DPA-side comms surface *on top of* that
parent flow; it does not redefine the parent.

## Pattern overview

Every DPA-Comms question this skill teaches resolves into one
of FIVE patterns. The patterns are CLASSES — they apply across
every DOCA DPA Comms release and every host + BlueField +
DPACC combination.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Confirm the user is writing DPA-side code, not host-side | DOCA DPA Comms is a DPA-SIDE library — its symbols are called from inside the DPA kernel function body, NOT from host code; if the user's code is on the host they want a different library (`doca-comch` / `doca-rdma`) | [`## Capabilities and modes`](#capabilities-and-modes) audience-and-side table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Walk the parent-skill prerequisites first | This library only makes sense inside a working host-side `doca-dpa` flow that loads the DPA app image, creates DPA threads, launches kernels, and drains completions; if any of that is not yet stood up, route to the parent skill | [`## Safety policy`](#safety-policy) parent-skill prerequisite matrix + [TASKS.md ## configure](TASKS.md#configure) step 2 |
| 3. Commit the DPA-side comms capability budget on the host before app load | Use `doca_dpa_comms_cap_*` from host code against the active `doca_devinfo` to confirm which DPA-side comms primitives the kernel may call; the budget is fixed at the point the host loads the DPA app into the `doca_dpa` context | [`## Capabilities and modes`](#capabilities-and-modes) capability-discovery section + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 4. Pick the DPA-side primitive family the kernel will call | Endpoint handle + small-message send / receive primitives for messaging between DPA threads; signal / event primitives for lightweight inter-thread coordination; the exact symbol set is install-bound and lives in the headers DPACC compiles against | [`## Capabilities and modes`](#capabilities-and-modes) DPA-side primitive families table + [TASKS.md ## modify](TASKS.md#modify) slot 2 |
| 5. Diagnose a DPA-Comms error observed on the host through `doca_dpa_completion` | Map `_BAD_STATE` / `_NOT_SUPPORTED` / `_INVALID_VALUE` / `_AGAIN` (delivered to the host through the parent skill's completion path) to a DPA-side root cause without leaving the DPA-Comms layer prematurely | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **DPA Comms is a DPA-SIDE library. Host code does not call
  it directly.** The user's host program calls `doca-dpa`;
  the user's DPA-side translation unit calls
  `doca-dpa-comms`. An agent that recommends adding
  `-ldoca-dpa-comms` to the host link line — or that
  recommends `doca-dpa-comms` when the user is writing host
  code that needs to message a DPU agent (that is
  `doca-comch`) — has the side wrong for every version of
  this library. The agent's first move on any DPA-Comms
  question is to confirm the user is writing DPA-side code.
- **The host commits the capability budget; the DPA kernel
  does not cap-query at the DPA processor at runtime.** The
  `doca_dpa_comms_cap_*` family is called from host code
  against the active `doca_devinfo` BEFORE the host loads the
  DPA app into the `doca_dpa` context. From inside the DPA
  kernel there is no general runtime cap-query — the kernel
  must only call comms primitives the host-side budget
  already covers. An agent that proposes *"the DPA kernel
  could just check at runtime whether primitive X is
  supported"* has the model wrong: that check is the host's
  responsibility, run once, before the kernel executes.

## Capabilities and modes

The two orthogonal selection axes for any DPA Comms usage are
*which side of the program the user is writing* (host-side
control program using `doca-dpa`, or DPA-side translation unit
using `doca-dpa-comms`; this skill is only the latter) and
*which DPA-side primitive family* (small-message send /
receive between DPA threads, or signal / event coordination
between DPA threads). Resolve both before writing any DPA-side
code, then drill into the host-side capability budget.

**Audience and side — host-side vs DPA-side.** This is the
load-bearing first question.

| Side | What runs there | Toolchain | Library the user calls | What this skill covers |
| --- | --- | --- | --- | --- |
| Host side | C / C++ (or any language that can FFI a C library) that drives the DPA — creates the `doca_dpa` context, loads the DPA app, launches kernels, drains the `doca_dpa_completion` | Host system compiler + `pkg-config doca-dpa` | `doca-dpa` (parent skill) — and the host-side `doca_dpa_comms_cap_*` family in the `doca-dpa-comms` headers used from host code purely for cap-query | The host-side cap-query step ONLY (see capability-discovery section below); everything else on the host side lives in the parent [`doca-dpa`](../doca-dpa/SKILL.md) skill |
| DPA side | The kernel function bodies that run on the DPA processor; the user's DPA-side translation unit `dpacc` compiles into the binary the host embeds as `doca_dpa_app` | `dpacc` (DPACC compiler) | `doca-dpa-comms` (this skill) for inter-DPA-thread messaging and coordination; sibling `doca-dpa-verbs` for DPA-side RDMA to remote peers | All of the DPA-side primitive families below; the cap-budget rule that fixes what the kernel may use; the error taxonomy as observed back on the host |

The agent's rule: when the user asks *"can I call
`doca-dpa-comms` from my host program?"*, the answer is
**no, this library's primitives live in the DPA-side
translation unit**. Host code may include the
`doca-dpa-comms` header for the `doca_dpa_comms_cap_*` family
to confirm what the DPA kernel may use, but the substantive
send / receive / signal calls happen from inside the DPA
kernel. When the user asks *"can I use `doca-dpa-comms`
between my host and my DPU agent?"*, the answer is **no,
that is `doca-comch`** — route through
[`doca-comch`](../doca-comch/SKILL.md).

**DPA-side primitive families — pick at least one per
kernel.** The exact symbol surface is install-bound; the
agent must NOT quote symbol names from memory and must route
the user to the on-disk headers and to the public *DOCA DPA
Comms* guide via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
for the per-symbol detail. The *family-level* shape, however,
is stable enough to teach:

| Family | What it is | Right shape for | Wrong shape for |
| --- | --- | --- | --- |
| DPA-side comms endpoint handle | An addressable handle a DPA kernel uses to identify a peer it will send to or receive from on the DPA side; created on the host through the parent `doca-dpa` flow and made visible to the DPA kernel via the launch-argument mechanism documented in [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes) | Every DPA-Comms usage pattern — endpoints are the addressable unit | Treating the endpoint as a host-side object (host code uses it to set things up, but the actual send / receive happens DPA-side) |
| DPA-side small-message send / receive primitives | The DPA kernel issues a send with a small payload to a peer DPA thread (or accepts a receive); latency-optimized; not a bulk-data path | Coordination, hand-off, small control messages between DPA threads on the same DPA processor | Bulk data movement — the family is small-message-shaped; large payloads need a different primitive (and very often the kernel should be using `doca-dpa-verbs` for true RDMA to a remote peer instead) |
| DPA-side signal / event primitives | Lightweight inter-thread wake-up / wait primitives between DPA threads in the same loaded `doca_dpa_app` | Ordering, fence-style coordination, one-shot wake-ups | A substitute for the host-side `doca_dpa_completion` — the host's view of *"the kernel finished"* still lives in the parent skill's completion mechanism, not in a DPA-side signal |

The agent's anti-pattern alert: *"use a DPA-side signal as
the host's notification that the kernel finished"* skips the
parent skill's `doca_dpa_completion` mechanism, which is the
host's only portable way to know any DPA work finished.
DPA-side signals are for *inter-DPA-thread* coordination,
not host notification.

**Host-side capability budget — fixed at app-load time.**
This is the DPA-Comms-specific rule the agent must surface
explicitly.

| Axis | What to call | Where it lives | Why the agent must ask |
| --- | --- | --- | --- |
| DOCA side, per-device | The `doca_dpa_comms_cap_*` family against the active `doca_devinfo` for the BlueField the host is driving | Host-side call, made from the host program BEFORE it loads the DPA app into the `doca_dpa` context per the parent skill's configure flow | DPA-Comms primitive availability is per BlueField generation + DOCA install + (potentially) DPACC version. Querying it from host code at app-load time is the only place to commit the budget; the DPA kernel cannot generally re-check at runtime |
| Parent DPA axis | The parent skill's `doca_dpa_cap_*` family per [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes) | Same host-side flow, also at app-load time | If the parent's DPA cap-query fails the DPA processor is not even available; the DPA-Comms budget is meaningless until the parent passes |
| Install axis | `pkg-config --modversion doca-dpa-comms` agrees with `pkg-config --modversion doca-dpa` and with `doca_caps --version` and with the installed `dpacc` per the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html) | Build / install side | Mismatched `doca-dpa-comms` vs `doca-dpa` versions, or mismatched DOCA vs DPACC versions, produce the same launch-time failure modes the parent skill documents — and there is no DPA-side runtime workaround |

**Configuration shape.** *Mandatory* preconditions before
the user writes any DPA-side comms code: the parent skill's
host-side flow is brought up end-to-end with a smoke kernel
that launches and completes (per [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test)
step 1); the `doca_dpa_comms_cap_*` queries against the
active `doca_devinfo` confirm the primitive family the DPA
kernel intends to use is supported on this BlueField + this
DOCA install; the DPA kernel function signature and the
host-side launch arguments per the parent skill are aligned
on which DPA-side comms endpoint handles will be passed in.
*Optional* configurations (how many endpoints, how many
in-flight messages per endpoint) are program-side tunables
that ride on top of the same host-side cap-query rule.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it. For the DPA
DOCA-must-match-DPACC overlay that this skill inherits from
the parent, see
[`doca-dpa CAPABILITIES.md ## Version compatibility`](../doca-dpa/CAPABILITIES.md#version-compatibility).

**The DPA-Comms-specific overlay** is:

- **`doca-dpa-comms` and `doca-dpa` must come from the same
  DOCA install, and must match the installed DPACC compiler
  per the DOCA Compatibility Policy.** `doca-dpa-comms` is
  the DPA-side library that pairs with the host-side
  `doca-dpa`; both `.pc` files MUST report the same version
  in the four-way-match check per
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility),
  and both must match the installed `dpacc` version per the
  DOCA Compatibility Policy at
  <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html>.
  A partial-install pattern where the host install ships a
  newer `doca-dpa.pc` than `doca-dpa-comms.pc` (or vice
  versa) is the canonical *"my DPA-side comms call returns
  `DOCA_ERROR_DRIVER` on the host completion but the host
  cap-query said it was supported"* root cause — surface
  BOTH versions in the agent's report. The cap-budget rule
  in [`## Capabilities and modes`](#capabilities-and-modes)
  is the runtime authority for *"is this DPA-Comms
  primitive on this hardware + this DOCA install"*, but it
  only protects you when the two `.pc` files agree.
- **The DPA-side symbol surface is install-bound. The agent
  must NOT quote symbol names from memory.** When the user
  asks *"does this DPA-Comms primitive exist on my DOCA?"*,
  the answer is the headers DPACC sees on disk plus the
  host-side cap-query, not a remembered API. Route the user
  to the on-disk samples at
  `/opt/mellanox/doca/samples/doca_dpa_comms/` and to the
  public guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Error taxonomy

DPA-Comms-specific overlays on the cross-library
`DOCA_ERROR_*` taxonomy. The cross-library taxonomy itself
lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the parent host-side DPA overlay lives in
[`doca-dpa CAPABILITIES.md ## Error taxonomy`](../doca-dpa/CAPABILITIES.md#error-taxonomy);
the rows below are the *DPA-Comms surface* meaning the agent
must disambiguate before falling back to either upstream
taxonomy. **Every error here is reported back to the host
through the `doca_dpa_completion` owned by the parent
`doca-dpa` skill** — the DPA kernel itself does not surface
errors to anyone but its host program.

| Error (as observed on the host completion) | DPA-Comms context where it shows up | DPA-Comms-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_NOT_SUPPORTED` | A DPA-side comms primitive the kernel called fails; surfaced on the host through `doca_dpa_completion` | The DPA-Comms primitive the kernel used is not in this DPA hardware generation OR was not in the capability budget the host committed at app-load time per the [`## Capabilities and modes`](#capabilities-and-modes) capability-discovery section. Re-run the `doca_dpa_comms_cap_*` query from host code against the active `doca_devinfo`; cross-check against the parent skill's BlueField-generation rule per [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes). Do not paper over with a kernel-side retry. |
| `DOCA_ERROR_INVALID_VALUE` | A DPA-side comms send / receive call; reported back via the host completion | Bad endpoint handle (commonly: the kernel was passed a handle the host did not actually create through the parent `doca-dpa` flow, or an out-of-scope handle from a different `doca_dpa` instance), or the message payload exceeded the per-primitive size limit. Re-read the DPA-side call site and the host-side launch-argument shape per [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes); if the DPA-side source's signature changed, rebuild via `dpacc` AND rebuild the host executable per the parent skill's *do not partial-rebuild one side* rule. |
| `DOCA_ERROR_BAD_STATE` | Any DPA-side comms call made before the comms surface is usable inside the kernel | Lifecycle violation INSIDE the DPA kernel — the kernel called a comms primitive before whatever initialization the DPA-Comms surface requires inside the kernel had completed, OR the kernel is using a comms endpoint after teardown. The agent must NOT treat this as the same `_BAD_STATE` the parent skill documents for host-side `doca_dpa` lifecycle violations — both exist; both surface on the host completion; they need to be told apart. Walk the DPA-side initialization order in the shipped sample at `/opt/mellanox/doca/samples/doca_dpa_comms/` before adjusting kernel code. |
| `DOCA_ERROR_AGAIN` | A DPA-side comms send when the DPA-side comms queue is full; the host sees `_AGAIN` on the matching `doca_dpa_completion` | The DPA-side comms queue on the DPA processor is full. **The DPA kernel must yield** — i.e. return from this launch and let the host drain the completion queue per the parent skill's flow before re-submitting the same comms call on the next launch — OR, if the kernel is persistent, cooperatively back off and re-try inside the kernel. This is the DPA-Comms equivalent of the cross-library *"would-block, drain-then-retry after progress"* pattern; the difference is that the *drain* happens host-side via `doca_pe_progress` on the parent skill's progress engine, not inside the DPA kernel itself. |

The agent's rule: **never recommend a tight retry loop on
DPA-Comms `DOCA_ERROR_*` without first identifying which of
the rows above is the cause**. `_AGAIN` wants a
yield-then-host-drains-then-retry; the others want
investigation (budget / signature / kernel-side
initialization order), not retry.

## Observability

DPA-Comms observability is **host-side-observed**: the DPA
kernel's view of its own comms calls flows back to the host
through the `doca_dpa_completion` attached on the host per
the parent skill's [`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability),
and the DPA-side developer tools named in the parent skill
(routed via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
to the public *DPA Tools* umbrella) apply unchanged when the
kernel-side comms path is the suspect.

Three primary signals the agent should reach for:

1. **Host-side per-launch completions through the parent
   `doca_dpa_completion`.** Every DPA kernel launch the host
   submits produces a completion (success or failure) the
   host reads through the `doca_dpa_completion` attached to
   that launch's `doca_dpa_thread`. A DPA-Comms call that
   fails inside the kernel surfaces here as one of the
   `DOCA_ERROR_*` rows in [`## Error taxonomy`](#error-taxonomy).
   Absence of a completion for a submitted launch is the
   parent skill's missing-progress / kernel-stuck case per
   [`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability),
   not a DPA-Comms-specific signal.
2. **Host-side capability-budget snapshot at app-load time.**
   The output of `doca_dpa_comms_cap_*` against the active
   `doca_devinfo` together with the installed
   `pkg-config --modversion doca-dpa-comms`,
   `pkg-config --modversion doca-dpa`, and the installed
   `dpacc` version is the baseline of *"what DPA-Comms
   primitives the kernel may use"*. Save it; if a host
   completion later reports `DOCA_ERROR_NOT_SUPPORTED` from
   a DPA-side comms call, the diff against this baseline
   either names the bug (the DPA-side kernel called outside
   the budget) or escalates to the parent skill (the
   BlueField generation simply doesn't support the
   primitive).
3. **DPA-side developer tools (route via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).**
   When the host-side completion never arrives and the
   parent skill's progress check is clean, the DPA-side
   kernel is alive but stuck — possibly in a DPA-Comms
   primitive that never makes forward progress (e.g. a
   receive that has no matching send, or a signal wait with
   no signaler). The public *DPA Tools* umbrella names the
   DPA debugger and DPA process-state inspector; the agent's
   job is to NAME the existence of these tools and route the
   user there, not to redefine their surface here.

For cross-cutting observability primitives
(`--sdk-log-level`, the `DOCA_LOG_LEVEL` env var, the trace
build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the host-side launch + completion model itself, defer to
the parent skill — this skill does not redefine it.

## Safety policy

DOCA DPA Comms's safety surface is **parent-skill-inherited
AND DPA-side-kernel-shape-driven**. The library does not add
new privilege checks of its own — the underlying access to
the DPA processor is governed by the host-side `doca-dpa`
loading per [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy)
— so the agent's job is (1) verify the parent skill's
env-precondition matrix is already satisfied, and (2)
verify the DPA-side kernel's use of comms primitives is
shaped consistently with what the host-side capability
budget committed.

The **parent-skill prerequisite matrix** the agent must walk
for any new DPA-Comms usage:

| Prerequisite | What must be true | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| Parent host-side flow is green | A trivial DPA kernel (no DPA-Comms calls) launches via the parent skill's `doca_dpa_kernel_launch_update_*` family on this exact host + BlueField + DPA app and the host observes one completion through `doca_dpa_completion` | Walk [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test) step 1 first | The parent [`doca-dpa`](../doca-dpa/SKILL.md) skill — fix env / version / lifecycle there; do NOT start writing DPA-side comms code on a broken parent flow |
| `doca-dpa-comms.pc` and `doca-dpa.pc` agree | `pkg-config --modversion doca-dpa-comms` equals `pkg-config --modversion doca-dpa`, and both match `doca_caps --version`, and both match the installed DPACC compiler per the DOCA Compatibility Policy | Quote both `pkg-config --modversion` outputs back to the user; cross-check the DPACC version | [`doca-setup`](../../doca-setup/SKILL.md) for the install side; route to [`doca-version`](../../doca-version/SKILL.md) for the four-way-match check |
| Host-side capability budget covers what the kernel will call | The DPA-side primitives the kernel intends to use are present in the `doca_dpa_comms_cap_*` query result against the active `doca_devinfo`, committed BEFORE the host loads the DPA app | Run the cap-query from host code per [`## Capabilities and modes`](#capabilities-and-modes) capability-discovery section; quote the result | The DPA-side kernel source — restrict the primitives it uses to the budget — OR the BlueField hardware generation (if the primitive truly isn't there, that's hardware, not code) |
| Two-side-program signature matches | The DPA-side kernel function signature and the host-side launch-argument shape per the parent skill's [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes) agree on which DPA-Comms endpoint handles (or other comms-related arguments) the host passes in | Re-read the DPA-side source against the host launch call; if either changed, rebuild BOTH sides | Program-layer fix on both sides together per the parent skill's *do not partial-rebuild one side* rule |
| One-send-one-receive DPA-Comms smoke passed before scaling | Two DPA threads in the same loaded `doca_dpa_app` exchange ONE small message and one of them signals the host through `doca_dpa_completion` that the round trip finished | Walk [TASKS.md ## test](TASKS.md#test) step 1 | Diagnose the smoke failure first per [TASKS.md ## debug](TASKS.md#debug); do NOT scale a broken DPA-Comms smoke into a high-throughput design |

**The DPA kernel does not own its own teardown of the
DPA-Comms surface.** The teardown order is governed by the
host-side `doca-dpa` lifecycle (destroy DPA threads →
release the loaded DPA app → destroy the `doca_dpa`); the
DPA-Comms surface inside the kernel goes away with that
teardown. An agent that proposes a kernel-side
*"shutdown the DPA-Comms surface"* call before the host
side has stopped is shaping the wrong responsibility — the
DPA kernel exits, the host tears down.

**Yield on `DOCA_ERROR_AGAIN` from a DPA-Comms send.** The
DPA-side comms queue is finite; when it fills, the kernel
must let the host drain. A tight in-kernel retry loop on
`_AGAIN` will pin the DPA processor and the host's
completion drain will starve. The cooperative shape — yield
back, let the host progress the parent skill's progress
engine, re-submit on the next launch (or after a kernel-side
back-off if the kernel is persistent) — is the only correct
pattern.

## Deferred topic boundaries

This skill scopes itself to the **DPA-side** DOCA DPA Comms
library. Adjacent topics the agent will get asked but should
route elsewhere:

- **The host-side DPA control surface** (creating
  `doca_dpa`, loading the DPA app, creating DPA threads,
  launching kernels, draining `doca_dpa_completion`) —
  parent skill. Route to
  [`doca-dpa`](../doca-dpa/SKILL.md); this skill assumes
  that flow is already working.
- **Host ↔ DPU control-plane messaging over PCIe** — that
  is `doca-comch`, not DPA-Comms. Route to
  [`doca-comch`](../doca-comch/SKILL.md). DPA-Comms is
  *inside* the DPA processor; `doca-comch` is *between* a
  host process and a DPU process.
- **Host-side host-to-remote-peer RDMA** — that is
  `doca-rdma`, not DPA-Comms. Route to
  [`doca-rdma`](../doca-rdma/SKILL.md). DPA-Comms is not an
  RDMA path.
- **DPA-side ibverbs-like RDMA from inside the DPA kernel
  to remote peers** — that is the sibling DPA-side library
  `doca-dpa-verbs`. No skill in this bundle yet; route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public *DOCA DPA Verbs* guide and to the shipped
  samples on disk. DPA-Comms is small-message-and-signal-shaped
  for *local* DPA threads; DPA-Verbs is RDMA-shaped for
  *remote* peers from inside the DPA.
- **The DPA-side kernel programming model itself** (how to
  structure the DPA kernel function body around comms calls,
  DPA-side memory layout, DPA intrinsics) — out of scope.
  Route to the public *DOCA DPA* and *DOCA DPACC Compiler*
  guides via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
  this skill assumes the user knows how to write a DPA
  kernel and is asking specifically about its comms calls.
- **DPACC compiler internals** (flags, target options, how
  the host + DPA split-build is wired) — out of scope, owned
  by the parent skill's deferral and by the public *DOCA
  DPACC Compiler* guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **DOCA Core context and progress engine internals** —
  owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  The parent skill *uses* the Core lifecycle; this skill
  inherits it through the parent and does not redefine it.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the DPA-Comms overlay on top of the
  parent skill's DPA overlay, not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build
  / link / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).
  This skill's `## debug` redirects there for layer 1-4 and
  redirects to the parent skill for the host-side overlays;
  the DPA-Comms-specific overlay carries only the
  kernel-side cooperative-back-off pattern and the
  cap-budget-mismatch root cause.
