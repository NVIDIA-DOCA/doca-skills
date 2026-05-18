# DOCA DPA Comms workflows

**Where to start:** The verbs run `configure → build → modify
→ run → test → debug`. Skip ahead only when the user is
already past a verb. The `## test` verb is an iterative loop
(one DPA-side send → one DPA-side receive smoke between two
DPA threads → multi-message → multi-thread → loop back if a
precondition or a capability assumption changes), not a
one-shot pass — see the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the DPA-Comms capability surface,
the host-vs-DPA-side rule, the DPA-side primitive families,
the host-side capability-budget rule, the error taxonomy as
observed on the host through `doca_dpa_completion`, the
observability surface, and the parent-skill prerequisite
matrix, see [CAPABILITIES.md](CAPABILITIES.md). For every
host-side decision this skill inherits — the
per-DPA-instance `doca_dpa` Core context, the loaded DPA
application image, the DPA execution context, the host launch
+ completion model, the dual host-side capability discovery,
the env-precondition matrix — go to the parent
[`doca-dpa`](../doca-dpa/SKILL.md) skill. For the
cross-library DOCA patterns layered under everything below
(the universal Core lifecycle, the cross-library
`DOCA_ERROR_*` taxonomy, the modify-a-shipped-sample
workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not
a copy-paste recipe. The agent's job is to walk the user
through the steps in order, verifying preconditions before
recommending the next call.

## configure

Goal: confirm the user is writing DPA-side code, confirm the
parent host-side `doca-dpa` flow is already standing, commit
the DPA-Comms capability budget from host code against the
active `doca_devinfo`, and confirm both the host side and the
DPA side are in a state where the DPA-side kernel may call
DPA-Comms primitives without surprise.

Steps the agent should walk the user through:

1. **Confirm the user is writing DPA-side code, not
   host-side.** Per the audience-and-side table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   DOCA DPA Comms's substantive calls live in the DPA-side
   translation unit `dpacc` compiles into the binary the
   host executable embeds as `doca_dpa_app`. The host program
   does NOT call DPA-Comms send / receive / signal primitives
   directly — it includes the DPA-Comms header only to
   call the `doca_dpa_comms_cap_*` family for the
   capability-budget commit (step 3 below). If the user's
   problem statement is *"I want to send messages between
   my host process and a DPU process"*, that is
   [`doca-comch`](../doca-comch/SKILL.md), not DPA-Comms —
   route there before doing anything else. If the user
   wants host-to-remote RDMA, that is
   [`doca-rdma`](../doca-rdma/SKILL.md).
2. **Confirm the parent host-side `doca-dpa` flow is green
   end-to-end first.** Per the parent-skill prerequisite
   matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   a trivial DPA kernel (no DPA-Comms calls) must already
   launch on this exact host + BlueField + DPA app and the
   host must already observe its completion through
   `doca_dpa_completion`. Walk the user through
   [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test)
   step 1 BEFORE introducing any DPA-Comms call. A broken
   parent flow surfaces as a broken DPA-Comms launch later
   — far harder to diagnose. If the parent flow does not
   stand, this is a parent-skill problem to fix via
   [`doca-dpa TASKS.md ## configure`](../doca-dpa/TASKS.md#configure)
   first, NOT a code change in the DPA-side kernel.
3. **Commit the DPA-Comms capability budget from host
   code.** Per the host-side capability-budget rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes):
   from the host side, call the matching
   `doca_dpa_comms_cap_*` family against the active
   `doca_devinfo` for the BlueField the host is driving,
   BEFORE the host loads the DPA app into the `doca_dpa`
   context per
   [`doca-dpa TASKS.md ## configure`](../doca-dpa/TASKS.md#configure)
   step 5. Cross-check `pkg-config --modversion doca-dpa-comms`
   agrees with `pkg-config --modversion doca-dpa` and with
   `doca_caps --version` and with the installed `dpacc`
   version per the DOCA Compatibility Policy. Quote BOTH
   results back to the user. The kernel may only call
   primitives this budget covers — the DPA kernel cannot
   generally cap-query at runtime.
4. **Sketch the two-side coupling explicitly.** The
   DPA-side kernel function signature (what comms endpoint
   handles or other comms arguments it expects) and the
   host-side launch call per the parent skill MUST agree on
   shape. Per the *do not partial-rebuild one side* rule in
   the parent skill's [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy),
   any change to one side requires updating the other; the
   agent treats this as a single edit, not two.
5. **Read the matching shipped DPA-Comms sample first.**
   Per the parent skill's universal modify-a-sample
   discipline (carried through from
   [`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify)),
   the closest sample under
   `/opt/mellanox/doca/samples/doca_dpa_comms/` is the
   verified two-side-program baseline — DPA-side translation
   unit calling DPA-Comms primitives, host-side translation
   unit driving it with the parent `doca-dpa` flow. Read it
   on disk before writing any DPA-side comms code; do not
   re-derive the kernel-side initialization order from
   memory.
6. **Sanity-check before the first DPA-Comms kernel
   launch.** Confirm with the user: which BlueField (which
   `doca_dev`) the launches will target (parent skill);
   which DPA application image is loaded and which kernel
   entry points it exposes (parent skill); which
   `doca_dpa_thread`(s) the kernel will run on (parent
   skill); which DPA-side comms primitive family the kernel
   uses (this skill); which DPA-Comms endpoint handles the
   host launch call passes in and how the DPA-side kernel
   maps them; how the kernel terminates if a DPA-Comms call
   returns `_AGAIN` (the kernel must yield, per
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)).
   If any of those are unclear, stop and ask — do not
   invent.

For the canonical DOCA universal lifecycle that underlies
the parent skill's host-side configure flow, see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
This skill adds the DPA-Comms-specific overlay on top of the
parent skill's DPA overlay; do not re-explain the lifecycle
here.

## build

Goal: compile a DPA-Comms-using consumer (DPA-side
translation unit calling DPA-Comms primitives + the
host-side `doca-dpa` translation unit that loads and
launches it) against the user's installed DOCA + DPACC
compiler, with `pkg-config` + `dpacc` as the joint sources
of truth.

The build pattern for any DOCA C / C++ consumer is fully
documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build);
the parent host-side DPA overlay is in
[`doca-dpa TASKS.md ## build`](../doca-dpa/TASKS.md#build).
DPA-Comms adds a DPA-side library to the DPA-side
translation unit's link line ONLY; the host-side link line
stays as the parent skill describes (no `-ldoca-dpa-comms`
on the host link). This skill carries only the
DPA-Comms-specific overlay:

| Slot | Value | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-dpa-comms` | The library's `.pc` file installed by the DOCA host packages; the DPACC compile of the DPA-side translation unit uses its include + link information. The host link line does NOT pull `doca-dpa-comms` |
| Host-side use of the DPA-Comms header | Limited to the `doca_dpa_comms_cap_*` family called from host code to commit the capability budget at app-load time per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) | The header is on the host install for both sides; including it from host code only for the cap-query is a legitimate use. Calling DPA-Comms send / receive / signal primitives from host code is NOT |
| DPA-side toolchain | `dpacc` (DPACC compiler), installed alongside DOCA, per the parent skill | Compiles the DPA-side translation unit that calls DOCA DPA Comms primitives into the binary the host executable embeds as the `doca_dpa_app`. The host system compiler is NOT a substitute |
| DPA-side include flags | The DPACC-prescribed include path resolves the DPA-side DPA-Comms headers | The agent's job is to route the user to the on-disk DPACC layout via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md), not to enumerate include paths from memory |
| DPA-side link of the DPA-Comms library | The DPACC-prescribed link step that pulls the DPA-Comms library into the DPA-side binary the host executable embeds | The agent's job is to route the user to the matching shipped sample under `/opt/mellanox/doca/samples/doca_dpa_comms/` as the verified DPACC build incantation, not to invent the DPACC command line |
| Host-side link line | Unchanged from the parent skill: `pkg-config --libs doca-dpa` plus the DPACC embed step from [`doca-dpa TASKS.md ## build`](../doca-dpa/TASKS.md#build). NO `-ldoca-dpa-comms` here | Putting `-ldoca-dpa-comms` on the host link line is the canonical *"the link line built, but my host program does not call any DPA-Comms function"* dead weight and is a strong signal the user misunderstands the host-vs-DPA-side split |
| Minimum DOCA version (DPA-Comms axis) | Query with `pkg-config --modversion doca-dpa-comms`; must equal `pkg-config --modversion doca-dpa`; never hardcode | A `doca-dpa-comms.pc` newer or older than `doca-dpa.pc` is a partial-install hazard per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) |
| Minimum DPACC version | Cross-check the installed `dpacc` version against the DOCA Compatibility Policy linked from [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) | Mismatched DOCA + DPACC combos fail per the parent skill's [`doca-dpa CAPABILITIES.md ## Error taxonomy`](../doca-dpa/CAPABILITIES.md#error-taxonomy) and surface here as host completions reporting `DOCA_ERROR_DRIVER` from DPA-Comms calls |

For non-C host-side consumers (Rust, Go, Python) that drive
the parent `doca-dpa` flow and embed a DPACC-built DPA-side
binary that calls DPA-Comms, the host-side link line and
version rules above still apply (no `-ldoca-dpa-comms` on
the host link); the DPA-side build is a separate
compilation unit and is out of scope for this skill, but the
`pkg-config --modversion doca-dpa-comms` cross-check is the
load-bearing input the wrapper still needs.

## modify

Goal: take the closest-fitting shipped DOCA DPA Comms sample
as the verified DPA-side + host-side baseline and apply a
**minimum diff** to make it match the user's intent,
without rewriting from scratch.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
the parent host-side DPA overlay is in
[`doca-dpa TASKS.md ## modify`](../doca-dpa/TASKS.md#modify);
this skill provides the DPA-Comms-specific slot fill on top
of both.

| Slot | What the agent asks the user | DPA-Comms-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_dpa_comms/`? | Pick a sample whose **shape** matches the user's intent: same DPA-side primitive family (send / receive vs signal / event), same number of DPA threads on each end, same way of getting the comms endpoint handles from host to kernel. DPA-Comms samples are two-side programs; the sample's host-side translation unit is the verified parent `doca-dpa` driver and the sample's DPA-side translation unit is the verified kernel that calls DPA-Comms primitives |
| 2. DPA-side comms call site | Which DPA-Comms primitive family is the kernel calling and on which endpoint handle? | Per the DPA-side primitive families table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), do not mix-and-match small-message send / receive primitives with signal / event primitives without re-reading the sample's setup — they are separate families with their own setup. The agent's anti-pattern alert: do NOT propose moving comms logic to the host side to *"simplify"* — that defeats the entire reason DPA-Comms exists |
| 3. Host-side launch-argument shape for DPA-Comms endpoints | How does the host pass the DPA-Comms endpoint handles into the kernel? | Per the two-side-program coupling rule in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy), the host launch call and the DPA-side kernel signature MUST agree on which endpoint handles flow into the kernel. Any change to one side requires updating the other; track this as a single edit, not two |
| 4. Host-side capability-budget commitment | What does the host's `doca_dpa_comms_cap_*` query against the active `doca_devinfo` return, and does it cover the primitives the modified kernel uses? | Per [`## configure`](#configure) step 3, the budget is committed at app-load time. A modify pass that introduces a new DPA-Comms primitive without re-running the host-side cap-query is the canonical way to surface `DOCA_ERROR_NOT_SUPPORTED` on the host completion at first launch |
| 5. Cooperative back-off shape on `DOCA_ERROR_AGAIN` | How does the kernel handle a comms send when the DPA-side comms queue is full? | Per the `_AGAIN` row in [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy), the kernel must yield (return from the launch, let the host drain through the parent skill's `doca_pe_progress`, re-submit on the next launch) OR cooperatively back off if the kernel is persistent. A tight in-kernel retry loop pins the DPA processor and starves the host drain — refactor the sample's pattern, do not introduce a new tight loop |
| 6. Kernel termination shape | How does the DPA kernel know when to exit, given it may be waiting on a DPA-Comms receive or signal? | Per the parent skill's kernel-exit-condition rule in [`doca-dpa TASKS.md ## modify`](../doca-dpa/TASKS.md#modify) slot 6, a DPA kernel that runs forever pins the DPA processor and the host sees no completion. A DPA-Comms receive or signal-wait with no matching sender is one common way to introduce this exact hang; surface the kernel-exit condition on every modify pass — a host-set flag in DPA-visible memory, a per-launch one-shot, or whatever the sample's exit pattern is |
| 7. Rebuild BOTH sides | After any modify, rebuild the DPA-side image via `dpacc` (now linking against the updated DPA-Comms surface) AND rebuild the host executable that embeds it | Per the *do not partial-rebuild one side* rule in [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy), rebuilding only one side is the canonical way to introduce `DOCA_ERROR_DRIVER` on the host completion. The DPA-Comms surface is no exception |

The agent emits an *intent description + the seven filled
slots*; the *actual* unified diff against the sample source
is produced the way every other library skill in this
bundle handles modify — the agent walks the user through
the diff line-by-line against the sample source they read
on disk, and has the user paste back the result for
validation. The agent's anti-pattern alert: a *"clean
rewrite"* from scratch is almost always slower to first
green than a minimum-diff modify on a shipped DPA-Comms
sample, and removes the user's ability to bisect against a
known-good baseline (which here includes the verified
DPACC + host two-side-program wiring).

## run

Goal: actually launch the DPA kernel that calls DPA-Comms
primitives and confirm the launch completes — and confirm
the DPA-Comms calls inside it did what the kernel intended.

Steps the agent should walk the user through:

1. **Confirm the loaded image exposes the DPA kernel
   function the host will launch AND that the kernel's
   DPA-Comms call site survived the DPACC compile.** Per
   the parent skill's [`doca-dpa TASKS.md ## run`](../doca-dpa/TASKS.md#run)
   step 1, the host's view of *"which kernels exist"* is
   exactly the entry-point set in the loaded
   `doca_dpa_app`. If the user changed the DPA-Comms call
   inside the kernel but the host's launch call still names
   the old entry point — or DPACC rejected the DPA-Comms
   call at compile and the entry point is stale — that is
   a build-side bug, not a launch-side bug; route back to
   [`## build`](#build).
2. **Submit the launch from the host** via the matching
   `doca_dpa_kernel_launch_update_*` call against the
   chosen `doca_dpa_thread`, with the DPA-Comms endpoint
   handles the kernel signature expects. The call is
   asynchronous from the host's point of view per the
   parent skill's launch + completion section in
   [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes);
   a successful submit return means the launch was
   submitted, not that the kernel finished.
3. **Drive the host-side `doca_pe_progress` loop in
   parallel with any outstanding launches.** This is the
   parent skill's [`doca-dpa TASKS.md ## run`](../doca-dpa/TASKS.md#run)
   step 3, inherited unchanged. The DPA-Comms-specific
   addition is that a kernel which yielded on
   `DOCA_ERROR_AGAIN` from a DPA-Comms send needs the host
   to *drain* the parent skill's completion queue *and*
   re-submit the kernel for the queue space to free up on
   the DPA side — without the host's progress loop, the
   DPA-Comms `_AGAIN` is permanent.
4. **Capture the structured log on first failure.** Set
   `DOCA_LOG_LEVEL=trace` for the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability));
   if the host-side log is silent and a `doca_dpa_completion`
   for a DPA-Comms-calling kernel reports a `DOCA_ERROR_*`,
   walk [`## debug`](#debug) layer 5 against the
   DPA-Comms-specific row in
   [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
   BEFORE reaching for the parent skill's DPA-side
   developer tools — the kernel-side comms-queue / budget /
   signature classification is cheaper to do first.

For the runtime version + `LD_LIBRARY_PATH` cross-checks
that underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).
For the host-side launch + completion model itself, defer
to the parent skill — this skill does not redefine it.

## test

Goal: prove the DPA-side DPA-Comms surface is correct
end-to-end on the user's installed DOCA + BlueField +
DPACC, and that the host-side capability-budget commit at
app-load time matches what the DPA kernel actually calls.

This is **a loop, not a one-shot pass.** Each iteration
narrows either the parent-skill prerequisites, the
host-side cap-budget, the DPA-side primitive choice, or the
cooperative-back-off shape on `DOCA_ERROR_AGAIN`. The loop
terminates when either (a) the user launches a DPA kernel
that exchanges DPA-Comms messages between two DPA threads
at the intended rate with the expected completions, or
(b) the agent has narrowed the failure cause to a layer
outside DPA-Comms itself (parent host-side DPA flow / DPACC
build / BlueField generation / DOCA install) and escalated
to the matching skill.

Iteration shape:

1. **One-send-one-receive DPA-Comms smoke between two DPA
   threads.** Launch a DPA kernel pattern (or a paired pair
   of kernels) where thread A issues ONE DPA-Comms send on
   one endpoint handle and thread B issues a matching
   DPA-Comms receive on the same handle; confirm the host
   observes the launch's completion through the parent
   skill's `doca_dpa_completion` with no error. Per the
   parent skill's smoke step in
   [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test)
   step 1, the **parent** smoke (a trivial kernel with NO
   DPA-Comms calls) MUST already pass first — if it does
   not, fixing the parent skill is the answer, not adding
   more DPA-Comms code. Per the safety-policy rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   DO NOT scale a broken DPA-Comms smoke into a
   high-throughput design.
2. **Multi-message DPA-Comms loop.** Once the smoke is
   green, have the DPA kernel issue 100 sends and confirm
   the host sees all the matching launches complete
   without losing any. Catches `DOCA_ERROR_AGAIN`-handling
   bugs: if the kernel does not yield correctly on the
   DPA-side comms queue filling up, the multi-message
   stage is where the throughput collapses or the host
   completion stream stalls. The fix is the
   cooperative-back-off shape per [`## modify`](#modify)
   slot 5.
3. **Multi-thread DPA-Comms scale-out (if used).** Add a
   third or fourth `doca_dpa_thread` per the parent
   skill's persistent-thread shape, and have them
   participate in the same DPA-Comms exchange. Re-run step
   1 and step 2 on each additional thread — each thread is
   its own DPA execution context and can hit the DPA-Comms
   surface differently (e.g. its own queue, its own
   pending-send budget).
4. **Capability-budget negative test.** Intentionally
   write a DPA-side kernel that calls a DPA-Comms primitive
   the host-side `doca_dpa_comms_cap_*` query against the
   active `doca_devinfo` reported as NOT supported, and
   confirm the host observes `DOCA_ERROR_NOT_SUPPORTED`
   cleanly on the launch's completion. Validates that the
   agent's capability-budget commit at app-load time per
   [`## configure`](#configure) step 3 is the runtime
   authority — not a coincidence.
5. **`_AGAIN` cooperative-back-off positive test.** Drive
   the DPA-side comms queue full deliberately (a tight
   pattern from the kernel against a slow-draining host),
   confirm the host completion sees `DOCA_ERROR_AGAIN`,
   then confirm the kernel's yield-and-resume pattern
   restores forward progress when the host drains. This is
   the load-bearing validation of [`## modify`](#modify)
   slot 5.

Eval-loop overlay — why this is a loop, not a one-shot
pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Parent `doca-dpa` smoke (no DPA-Comms calls) is broken | The parent-skill flow does not complete a trivial launch | This is NOT a DPA-Comms problem. Route to [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test) and fix there before adding any DPA-Comms code |
| `DOCA_ERROR_NOT_SUPPORTED` from the DPA-side comms call surfaced on host completion | The kernel called a primitive the host-side cap-budget did not cover OR the BlueField generation does not expose it | Re-run the `doca_dpa_comms_cap_*` query per [`## configure`](#configure) step 3; restrict the kernel to budgeted primitives; OR if the primitive truly isn't on this BlueField, the answer is the hardware, not a software upgrade |
| One-send-one-receive smoke passed; multi-message loop stalls or drops launches | Cooperative back-off on `_AGAIN` is wrong OR host is not draining the parent skill's completion queue fast enough | Re-walk [`## modify`](#modify) slot 5; restructure the host loop to drain completions per batch per the parent skill |
| Host observes the launch completion but the receiver kernel never sees the message | The DPA-Comms endpoint handles on the two threads do not refer to the same logical endpoint OR the kernel-side signature mismatched what the host launch passed in | Re-walk [`## modify`](#modify) slot 3; rebuild BOTH sides per [`## build`](#build) |
| Host observes no completion for a launch that calls DPA-Comms | This is the parent skill's missing-progress / kernel-stuck case, not a DPA-Comms-specific symptom | Route to [`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug) layer 5; the DPA-side developer tools named in the parent skill apply unchanged |
| `_BAD_STATE` on the host completion but the parent skill's host lifecycle is correct | The DPA-side kernel's DPA-Comms call site is in the wrong place inside the kernel — e.g. before the kernel's DPA-Comms surface is initialized, or after teardown | Walk the kernel-side initialization order in the shipped sample at `/opt/mellanox/doca/samples/doca_dpa_comms/`; this is a kernel-side fix, not a host-side fix |

Loop termination: stop iterating once two consecutive
iterations of the same kind don't change anything — that
means the cause is below DPA-Comms (parent host-side DPA
flow, BlueField generation, DPACC bug, NIC firmware).
Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured layer-1-through-5 evidence including the
host-side DOCA log, the host-side cap-budget snapshot from
[`## configure`](#configure) step 3, and the DPA-side
tooling output from the parent skill.

## debug

Goal: when a DPA kernel that calls DPA-Comms primitives
fails — usually as a `DOCA_ERROR_*` reported back on the
host through the parent skill's `doca_dpa_completion`, or
as silence where a completion was expected — narrow the
cause to a specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
The parent host-side DPA overlay lives in
[`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug).
Walk through the cross-library ladder in order — install →
version → build → link → runtime → program → driver —
*before* recommending DPA-Comms-specific fixes, AND consult
the parent skill's overlay for anything host-side. This
skill's overlay names the DPA-Comms-specific manifestation
at layers 5 (runtime), 6 (program), and 7 (driver):

**Layer 5 (runtime) — DPA-Comms overlay.**

- `DOCA_ERROR_AGAIN` on a `doca_dpa_completion` for a
  DPA-Comms-calling kernel is *always* the DPA-side comms
  queue full. Do not recommend a tight in-kernel retry
  loop; recommend the cooperative back-off per
  [`## modify`](#modify) slot 5 and confirm the host is
  draining the parent skill's progress engine. If both are
  in place and `_AGAIN` is still permanent, the
  cap-budget for the relevant primitive sized the queue
  too small for the workload — re-run the
  `doca_dpa_comms_cap_*` query and either commit a larger
  budget or restructure the workload.
- `DOCA_ERROR_NOT_SUPPORTED` on a `doca_dpa_completion` for
  a DPA-Comms-calling kernel is *always* a cap-budget /
  hardware-generation mismatch — the kernel called a
  primitive the budget at app-load time did not cover.
  Confirm via [`## configure`](#configure) step 3; if the
  query was never run, this is the bug. If the query was
  run and reported supported, then either the host loaded a
  DIFFERENT DPA app (a different binary that uses different
  primitives) or the binary the host loaded was built
  against a different DOCA install than the host runtime —
  route to [`## debug`](#debug) layer 7 and to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug).
- A *"DPA kernel that calls DPA-Comms hung; cannot stop the
  program"* pattern is almost always either (a) a
  DPA-Comms receive with no matching sender, (b) a
  DPA-Comms signal-wait with no signaler, or (c) a tight
  in-kernel `_AGAIN` retry that the host can never drain.
  All three are the parent skill's missing-kernel-exit
  pattern from [`doca-dpa TASKS.md ## modify`](../doca-dpa/TASKS.md#modify)
  slot 6, layered with DPA-Comms semantics.

**Layer 6 (program) — DPA-Comms overlay.**

- `DOCA_ERROR_BAD_STATE` on a `doca_dpa_completion` for a
  DPA-Comms-calling kernel must be disambiguated from the
  parent skill's `_BAD_STATE`. The parent meaning is *the
  host-side `doca_dpa` lifecycle was violated*; the
  DPA-Comms meaning is *the DPA kernel called a DPA-Comms
  primitive before its in-kernel comms surface was usable,
  or after kernel-side teardown*. Walk both: confirm the
  parent's host-side lifecycle per [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy)
  first; then walk the DPA-side kernel initialization
  order against the shipped DPA-Comms sample on disk.
- `DOCA_ERROR_INVALID_VALUE` from a DPA-Comms call is most
  often a bad DPA-Comms endpoint handle — the host launch
  passed a handle the DPA kernel does not recognize, or the
  message payload exceeds the per-primitive size limit. Per
  the parent skill's *do not partial-rebuild one side*
  rule, the fix is to re-align the host launch call and the
  DPA-side kernel signature AND rebuild both sides. Do not
  patch only one side.
- Two-side-program signature mismatch on the DPA-Comms
  call site itself: if the host launch passes N endpoint
  handles and the DPA-side signature expects M, the parent
  skill's `_INVALID_VALUE` overlay applies; the fix is at
  the parent skill's program layer, not in DPA-Comms.

**Layer 7 (driver) — DPA-Comms overlay.**

- `DOCA_ERROR_DRIVER` from a `doca_dpa_completion` for a
  DPA-Comms-calling kernel is most often the parent
  skill's DPA driver layer reporting failure (DOCA + DPACC
  version skew) *layered with* the DPA-Comms-side version
  skew between `doca-dpa-comms.pc` and `doca-dpa.pc`.
  Capture all of: `pkg-config --modversion doca-dpa-comms`,
  `pkg-config --modversion doca-dpa`, the installed `dpacc`
  version, and `doca_caps --version`; cross-check against
  the DOCA Compatibility Policy at
  <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html>.
  Any disagreement among the four is the bug.
- A BlueField generation that exposes the DPA but does
  NOT expose the specific DPA-Comms primitive the kernel
  uses surfaces as `_NOT_SUPPORTED` at layer 5; the layer 7
  driver path is for the *DOCA + DPACC + DPA-Comms version
  skew* case specifically.

Once the layer is identified, route to the matching debug
verb on the matching skill: install / build / link /
driver to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
version to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
host-side DPA lifecycle / kernel-stuck to [`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug);
cross-cutting runtime to [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as
follows so the agent does not invent guidance:

- **install.** Installing DOCA, installing the DPACC
  compiler, choosing matched versions, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA + DPACC are already installed and
  matched.
- **Host-side DPA control surface.** Creating
  `doca_dpa`, loading the DPA app, creating DPA threads,
  launching kernels, draining `doca_dpa_completion` — parent
  skill. Route to
  [`doca-dpa`](../doca-dpa/SKILL.md). This skill assumes
  that flow is already working.
- **Host ↔ DPU messaging over PCIe.** Different scope. Route
  to [`doca-comch`](../doca-comch/SKILL.md). DPA-Comms is
  *inside* the DPA processor; `doca-comch` is *between* a
  host process and a DPU process.
- **Host-side host-to-remote-peer RDMA.** Different scope.
  Route to [`doca-rdma`](../doca-rdma/SKILL.md). DPA-Comms
  is not an RDMA path.
- **DPA-side RDMA from inside the DPA kernel to remote
  peers.** Sibling DPA-side library `doca-dpa-verbs`. No
  skill in this bundle yet; route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public *DOCA DPA Verbs* guide. DPA-Comms is
  small-message-and-signal-shaped for local DPA threads;
  DPA-Verbs is RDMA-shaped for remote peers.
- **DPA-side kernel programming and DPACC usage.** Writing
  the kernel function body itself, DPA-side memory layout,
  DPACC compile flags, DPA-side debugging from inside the
  kernel — out of scope. Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public *DOCA DPA*, *DOCA DPACC Compiler*, *DOCA
  DPA Comms*, and *DOCA DPA Verbs* guides plus the *DPA
  Tools* umbrella. This skill prescribes how the DPA-side
  kernel calls DPA-Comms primitives; it does not redefine
  how to write the kernel body around them.
- **deploy.** Deploying DPA-Comms-using applications at
  scale (multi-BlueField clusters, multi-tenant DPA sharing,
  Kubernetes operator workflows for DPU workloads) — out
  of scope for Phase 1 and reserved for a future platform
  skill, the same as the parent `doca-dpa` skill's
  deferral.

## Command appendix

Every command below is **cross-cutting on DOCA DPA Comms** —
it answers a recurring class of question that comes up in
the verbs above. The agent should treat the *class* as
load-bearing; the worked example is a single instance.
Run-as user is the unprivileged user unless noted; sudo is
called out per row.

**Infra-aware preamble (every row below).** Per the
bundle's detect → prefer → fall back → report contract
documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST
   (`doca-env --json` for version + devices + libraries +
   drivers + hugepages in one shot;
   `doca-capability-snapshot` for per-device capability
   flags including the DPA-Comms axis; `version-matrix.json`
   for *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is
   the authoritative answer and the agent SHOULD NOT also
   run the manual command in the row below. Report *"using
   structured `<tool>`"*.
3. If the probe fails, fall back to the manual command in
   the row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-dpa-comms` | `## configure` step 3; `## build` minimum-version slot | What is the build-time DOCA DPA Comms library version, and does it agree with `doca-dpa`? | A semver string matching `pkg-config --modversion doca-dpa` AND `doca_caps --version`. Disagreement with `doca-dpa` = partial-install hazard per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility); disagreement with `doca_caps --version` = route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| `pkg-config --cflags doca-dpa-comms` | `## configure` step 3 (host-side cap-query include only); `## build` (DPA-side via DPACC) | What include flags does host code need to call the `doca_dpa_comms_cap_*` family for the budget commit? | Resolves to the host DOCA DPA Comms header under the DOCA install include layout. The flags here are used host-side ONLY for the cap-query; the DPA-side includes come from the DPACC compile per [`## build`](#build) |
| `pkg-config --libs doca-dpa-comms` | `## build` (host-side warning row) | Useful only to confirm that the agent did NOT put `-ldoca-dpa-comms` on the host link line | The pkg-config command will print library flags; per the build slot table in [`## build`](#build), those flags belong in the DPACC compile of the DPA-side translation unit, NOT on the host link line. If the host link line includes them, that is the bug |
| `which dpacc && dpacc --version` (or the install-tree path) | `## configure` step 3; `## build` minimum-DPACC slot | Is the DPACC compiler installed and at what version, given DPA-Comms requires it to build the DPA-side translation unit? | A version string the agent compares against the DOCA Compatibility Policy linked from [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility); missing `dpacc` means the DPA-side translation unit cannot be built and DPA-Comms cannot be used; route to [`doca-setup`](../../doca-setup/SKILL.md) |
| `doca_caps --list-devs` | `## configure` step 2; `## configure` step 3 | Which DOCA devices does the host see, which expose a DPA, and which expose DPA-Comms primitives? | One entry per `doca_dev` with the per-library capability flags including the DPA and DPA-Comms axes. No DPA-capable entry = parent skill issue; DPA capable but no DPA-Comms primitive supported = the BlueField generation does not expose the primitive, route to [`doca-setup`](../../doca-setup/SKILL.md) for any mode-side fix |
| `ls /opt/mellanox/doca/samples/doca_dpa_comms/` | `## modify` slot 1 | Which DPA-Comms samples ship in this install (both host-side AND DPA-side translation units), and which is the closest starting point? | A list of sample directories that each contain BOTH host-side and DPA-side source plus a build manifest that wires `dpacc` for the DPA-side translation unit and `pkg-config doca-dpa` for the host side |
| `dmesg \| tail -n 40` (sudo) | `## debug` layer 7 | What did the kernel / driver log around the last DPA-Comms-call-related failure? | Empty or recent benign messages. Repeated mlx5 / DPA-driver errors → driver-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) and to the parent skill's [`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug) layer 7 |
| `DOCA_LOG_LEVEL=trace ./<binary>` | `## run` step 4 | What did the structured DOCA logger emit for the first failing host-side launch of a DPA-Comms-calling kernel? | A trace-level line on every host-side lifecycle transition and every launch submit. Silence after a launch submit = either host PE not progressed (parent skill) OR DPA kernel running but stuck in a DPA-Comms primitive — reach for the parent skill's DPA-side tooling per [`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability) next |
| (route via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)) DPA-side developer tools — DPA debugger, DPA process-state inspector, DPA statistics tool | `## debug` layer 5; `## debug` layer 6 | What is the DPA processor itself doing right now, especially around a DPA-Comms-blocked kernel? | The public *DPA Tools* umbrella documents the per-tool output; the agent's job is to NAME the existence of these tools (inherited from the parent skill) and route the user there, not to redefine their surface here |

For commands shared across libraries (`pkg-config
--modversion`, `doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the DPA-Comms-specific rows on top of the
parent skill's DPA rows.
