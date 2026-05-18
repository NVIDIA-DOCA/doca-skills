# DOCA DPA Verbs workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. EVERY workflow below begins by re-confirming
two things from [SKILL.md](SKILL.md): (a) the 4-way-matrix decision
puts the user in this corner (DPA-side, raw verbs, latency-bound)
and (b) the parent [`doca-dpa`](../doca-dpa/SKILL.md) is in scope.
If either fails, the right answer is to stop and route back, not
to walk these verbs. The `## test` verb is an iterative loop (one
DPA-side WR-post smoke → streaming → loop back if a cap-query, host-
configured QP shape, or completion topology changed), not a one-shot
pass — see the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the 4-way matrix, the host-configures-QP /
DPA-uses-QP coupling rule, the DPA-side primitive surface, the
host-side cap-query rule, the error taxonomy, the observability
split, and the safety policy that these workflows assume, see
[CAPABILITIES.md](CAPABILITIES.md). For the host-side DPA lifecycle
this skill rides on, see the parent [`doca-dpa`](../doca-dpa/SKILL.md).
For the cross-library DOCA patterns layered under everything below
(the universal Core lifecycle on the host side, the cross-library
`DOCA_ERROR_*` taxonomy, the modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through the
steps in order, verifying preconditions before recommending the
next call.

## configure

Goal: stand up a DPA-side RDMA setup — host-side `doca-dpa` context
that creates and configures the RDMA QP(s) the DPA kernel will post
against, a DPA application image (DPACC-compiled) whose kernel
function body calls `doca_dpa_verbs_*` primitives on those QPs, and
a confirmed cap-query for the specific verb / opcode the kernel uses
— *after* confirming the 4-way-matrix decision and the latency-
bottleneck precondition.

Steps the agent should walk the user through:

1. **Re-confirm the 4-way-matrix decision.** Ask: *"have you walked
   the host-vs-DPA × high-level-vs-verbs matrix in
   [SKILL.md](SKILL.md#the-4-way-matrix-this-skill-exists-to-navigate)
   and confirmed you belong in this corner?"* If no — stop, route
   back. If yes, ask the user to name the specific RDMA op the DPA
   kernel will issue (RDMA read of a remote buffer, send to a peer,
   atomic CmpSwap, etc.); that name is the load-bearing input for
   steps 3 and 5. This step is the cheapest place to catch the
   *"recommended DPA-side verbs unnecessarily"* failure mode.
2. **Confirm the host round-trip is the measured bottleneck.** Per
   the safety matrix in
   [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy):
   ask the user for the latency data (profile, histogram, or
   back-of-envelope per-op cost) that shows the host round-trip
   dominates. If the user cannot point at a measurement, ask them
   to take one BEFORE writing any DPA-side code. A guess does not
   count, and the two-side-program maintenance cost of this skill
   is not paid for unless the bottleneck is real. If the bottleneck
   turns out NOT to be the host round-trip, climb back up to
   [`doca-rdma`](../doca-rdma/SKILL.md) (or
   [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) if raw verbs is
   genuinely needed on the host).
3. **Run the host-side cap-query for the specific verb the kernel
   uses.** Per the cap-query rule in
   [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes):
   from the host side, BEFORE launching any DPA kernel, run the
   matching `doca_dpa_verbs_cap_*` against the active `doca_devinfo`
   for the BlueField the host is driving. The cap-query lives on
   the *host*; the DPA-side translation unit cannot cap-query from
   inside the kernel. If the cap-query returns false — that is the
   answer. The DPA hardware on this BlueField generation does not
   expose the verb the kernel wanted, and dropping into DPA-side
   code cannot manufacture support the cap-query denies. Climb back
   up if a host-side alternative covers the case.
4. **Bring up the parent [`doca-dpa`](../doca-dpa/SKILL.md) setup
   AND configure the RDMA QP(s) on the host side.** Per the
   host-configures-QP / DPA-uses-QP rule in
   [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes):
   the QP(s) the DPA kernel will post against are created and
   configured by the host code through the parent skill's
   workflow. Walk
   [`doca-dpa TASKS.md ## configure`](../doca-dpa/TASKS.md#configure)
   for the host-side `doca_dpa` context, the loaded
   `doca_dpa_app`, the `doca_dpa_thread`, and the
   `doca_dpa_completion`; layer on the QP create + configure
   appropriate to whatever RDMA transport the user picked (IB /
   RoCE). The DPA kernel will receive the QP handle(s) as launch
   arguments or via host-shared DPA-visible memory; the agent must
   name the mechanism explicitly per the parent's two-side-program
   rule.
5. **Read the DPA-side verbs symbols from the user's install.** The
   `doca_dpa_verbs_*` symbol surface is install-bound on the
   DPA side; the agent must not quote symbols from memory. Direct
   the user to the DPA-side header path the DPACC compiler uses
   (per the DPACC guide via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md))
   and to `/opt/mellanox/doca/samples/doca_dpa_verbs/` for the
   shipped samples that demonstrate the live DPA-side API. Per
   [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility),
   the headers win over the docs when they disagree.
6. **Pick the completion-handling surface.** Per the
   observability split in
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability):
   host-side CQE inspection (default; the host's
   `doca_dpa_completion` from the parent surfaces the completion)
   OR in-kernel completion polling on the DPA side (when the
   kernel must react to its own completions before exiting). Pick
   one per use case explicitly; do not mix them on the same CQ.
7. **Sketch the DPA-side WR construction BEFORE writing kernel
   code.** Which QP handle? Which opcode (send, RDMA read, RDMA
   write, atomic)? Which flags (constrained by the host-configured
   QP feature set)? Which memory region(s)? How does the host
   pass the QP handle and the buffer addresses into the kernel
   (launch argument shape vs DPA-visible memory)? If any of those
   are unclear, stop and ask — DPA-side raw verbs amplifies the
   cost of guessed parameters because the WR construction lives in
   a translation unit DPACC compiles and a misshape surfaces as a
   `DOCA_ERROR_INVALID_VALUE` on the host launch return that does
   not point at the line in the kernel that built the WR.
8. **Sanity check before the first launch.** Confirm with the user:
   the cap-query result from step 3; the QP handle(s) and their
   configured feature set; the launch-argument shape; how the
   DPA kernel will terminate (a DPA kernel that never exits pins
   the DPA processor per the parent's
   [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes)
   rule — the kernel still needs the host-set termination signal
   even when it is also posting WRs).

If any step fails with a `DOCA_ERROR_*`, route through the error
taxonomy in
[CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: compile a DPA-side translation unit that links
`doca-dpa-verbs` through DPACC, paired with the host-side `doca-dpa`
build the parent skill prescribes, against the user's installed
DOCA + DPACC compiler.

The host-side build pattern lives in
[`doca-dpa TASKS.md ## build`](../doca-dpa/TASKS.md#build); the
universal DOCA build pattern lives in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the DPA-Verbs-specific overlay:

| Slot | Value for DPA-Verbs | Why it matters |
| --- | --- | --- |
| `pkg-config` module name (DPA side) | `doca-dpa-verbs` — exposed through DPACC for the DPA-side translation unit, NOT added to the host-side link line | DPA Verbs is a DPA-side library: its symbols are linked into the DPA application image by `dpacc`, not into the host executable by the host C/C++ linker. A common first-build error is adding `-ldoca-dpa-verbs` to the host link line; the host link line uses `-ldoca-dpa -ldoca-common` per the parent skill |
| Required host-side libs | The parent's set: `-ldoca-dpa -ldoca-common` plus whatever the host-side QP setup requires from the underlying RDMA stack (kept consistent with the parent build slot) | Adding `doca-dpa-verbs` to the host side bloats the link line, hides the drop-into-DPA-Verbs decision the agent and user already made, and can also mask a real DPA-side build failure if DPACC silently picks up a different surface |
| DPACC step | The DPA-side translation unit that calls `doca_dpa_verbs_*` is compiled by `dpacc` into the binary embedded into the host executable as the `doca_dpa_app` per the parent build slot | The host's system C/C++ compiler is NOT a substitute for `dpacc` on the DPA side; without the DPACC embed step the host has no DPA application image to load at runtime |
| Header check (DPA side) | The DPA-side headers exposing `doca_dpa_verbs_*` resolvable on the DPACC include path; the host-visible headers under `/opt/mellanox/doca/infrastructure/include/` resolve the host-side cap-query surface | If the DPACC include path does not resolve the DPA-side verbs headers, the install is partial — route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) AND to [`doca-setup`](../../doca-setup/SKILL.md) for the DPACC installation check |
| Minimum required DOCA / DPACC versions | Query at build time: `pkg-config --modversion doca-dpa-verbs` AND `pkg-config --modversion doca-dpa` AND the installed `dpacc` version; cross-check against the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html) | Cross-version build/runtime mixing breaks per [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility); DPA-Verbs-only upgrades (without the matching `doca-dpa` and DPACC bump) are a documented partial-install hazard |
| Companion DOCA libs | `doca-argp` for arg parsing if the shipped samples use it; the shipped samples include BOTH the host-side translation unit and the DPA-side translation unit | The shipped samples under `/opt/mellanox/doca/samples/doca_dpa_verbs/` are the verified two-side-program build template; do not invent a one-side-only manifest |
| DPA-side library NOT to add here | `doca-dpa-comms` | That is a *different* DPA-side library for local DPA-side messaging, not RDMA. Adding it because the user's DPA kernel also messages locally is a separate decision routed via the parent skill and the public *DOCA DPA Comms* guide — it does not belong on the same DPACC line by default |

For non-C host-side wrappers (Rust, Go, Python) that drive the
parent `doca-dpa` setup and embed a DPA application image built
separately by DPACC, the host-side link line and version rules from
the parent still apply; the DPA-side translation unit is still a
unit DPACC compiles, and the DPA-Verbs cap-query the wrapper must
call (from the host) is still the load-bearing input.

## modify

Goal: take the closest-fitting shipped DOCA DPA Verbs sample as the
verified starting point and apply a **minimum diff** to make it
match the user's intent, without rewriting from scratch. The DPA
Verbs samples are two-side programs (host-side translation unit AND
DPA-side translation unit) — the agent must modify both sides
together.

The universal modify-a-shipped-sample workflow lives in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
the parent's DPA-side overlay (two-side-program reminder, do-not-
partial-rebuild rule, sample-tree pointer) lives in
[`doca-dpa TASKS.md ## modify`](../doca-dpa/TASKS.md#modify);
this skill provides the DPA-Verbs-specific slot fill.

| Slot | What the agent asks the user | DPA-Verbs-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_dpa_verbs/`? | Pick a sample whose **shape** matches the user's intent: same DPA-side WR opcode pattern (RDMA read vs RDMA write vs atomic vs send), same completion topology (host-observed vs in-kernel-polled per [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)), same host-configured QP transport (IB vs RoCE). DPA-Verbs samples are two-side programs; the sample's DPA-side translation unit is the second half of the verified base |
| 2. Host-side QP configuration changes | What changes in the QP the host configures for the DPA kernel to post against? | Per the host-configures-QP / DPA-uses-QP rule in [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes), QP changes live in the host-side translation unit. Each added opcode / WR flag also needs its own `doca_dpa_verbs_cap_*` query from [`## configure`](#configure) step 3 BEFORE the kernel is rebuilt |
| 3. DPA-side WR construction changes | What changes in the kernel's WR-post body (opcode, target QP handle, memory region, flags, payload size)? | The DPA-side translation unit is the in-place edit point for WR construction. The agent's anti-pattern alert: do NOT propose moving the WR construction to the host *"to simplify"* — that defeats the entire reason to use DPA-side verbs. Keep the post in the kernel |
| 4. Launch-argument shape (host → DPA) | What does the host pass into the kernel — QP handle(s), buffer addresses, peer info? | Per the parent's two-side-program signature rule in [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes), the host launch call and the DPA-side kernel signature MUST agree on count, size, and type. Any change to one side requires updating the other; track this as a single edit, not two |
| 5. Completion topology | Does the host observe the completion via `doca_dpa_completion`, or does the kernel poll its own completions? | If the sample used one and the user wants the other, this is a re-architecture, not a tweak. Recommend starting from a sample that already uses the target completion topology instead of patching one over |
| 6. Termination signal for the DPA kernel | How does the kernel know when to exit, especially if it polls its own completions in a loop? | A DPA kernel that runs forever pins the DPA processor and the host sees no completion regardless of whether the DPA-side WR posts succeed. The agent must surface the kernel-exit condition on every modify pass — same shape as the parent's modify slot 6 in [`doca-dpa TASKS.md ## modify`](../doca-dpa/TASKS.md#modify) |
| 7. Rebuild BOTH sides | After any modify, rebuild the DPA-side image via `dpacc` AND rebuild the host executable that embeds it | Per the *do not partial-rebuild one side* rule inherited from [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy) and reinforced for DPA-Verbs in [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy), rebuilding only one side is the canonical way to introduce `DOCA_ERROR_DRIVER` at launch or `DOCA_ERROR_INVALID_VALUE` at the first DPA-side WR post |

The agent emits an *intent description + the seven filled slots*;
the *actual* unified diff against the sample source is produced the
way every other library skill in this bundle handles modify — the
agent walks the user through the diff line-by-line against the
sample source they read on disk, and has the user paste back the
result for validation. The agent's anti-pattern alert: a *"clean
rewrite"* from scratch on a two-side-program is almost always
slower to first green than a minimum-diff modify on a shipped
DPA-Verbs sample, and removes the user's ability to bisect against
a known-good baseline across BOTH translation units.

## run

Goal: actually launch the DPA kernel from the host so it posts the
DPA-side WR against the host-configured QP, and confirm the
completion is observed end-to-end on the chosen completion surface.

Steps the agent should walk the user through:

1. **Confirm the loaded DPA image exposes the kernel function the
   host will launch, and that the kernel body posts the expected
   `doca_dpa_verbs_*` call.** Both come from the DPACC compile of
   the DPA-side translation unit. If the host launches a function
   DPACC did not compile in, that is a build-side bug — route back
   to [`## build`](#build). If the kernel body does not actually
   post the WR the agent expects, that is a sample-modification bug
   — route back to [`## modify`](#modify).
2. **Confirm the peer is reachable.** A DPA-side RDMA read / write
   needs a remote peer; the peer's RDMA stack and transport must
   match what the host-configured QP asked for (IB / RoCE; QP
   feature set per [`## configure`](#configure) step 3). A solo run
   without a peer produces a misleading hang at the first WR post.
   Same rule as host-side RDMA — the DPA-side execution does not
   eliminate the peer.
3. **Submit the kernel launch from the host** via the parent's
   `doca_dpa_kernel_launch_update_*` flow per
   [`doca-dpa TASKS.md ## run`](../doca-dpa/TASKS.md#run). The launch
   is asynchronous from the host's point of view; the DPA kernel
   then posts its WR(s) inside its body.
4. **Drive the host-side `doca_pe_progress` loop AND drain the
   `doca_dpa_completion`.** Without progressing the PE, the host
   sees no completion regardless of whether the DPA-side post and
   the underlying RDMA WR succeeded. Same anti-pattern as the
   parent skill warns about; this skill inherits it.
5. **Capture the structured log on first failure.** Set
   `DOCA_LOG_LEVEL=trace` for the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability));
   if the host-side log is silent but the completion never arrives,
   the DPA kernel is running but stuck — most likely stuck inside
   its own `doca_dpa_verbs_*` post or completion-poll body. Reach
   for the DPA-side developer tools (the DPA debugger and the DPA
   process-state inspector) named in
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)
   and routed via the parent's
   [`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability)
   to the public *DPA Tools* umbrella.

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove the DPA-side RDMA path actually moves data correctly
end-to-end between the DPA kernel and the remote peer on the user's
hardware, and that the specific verb / opcode that justified
dropping to DPA-side verbs actually fires the way the user expected.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the host-side cap-query, the host-configured QP shape, the
DPA-side WR construction, the completion topology, or the
two-side-program signature. The loop terminates when either (a) the
DPA-side post-and-complete cycle flows end-to-end with the expected
RDMA semantics, or (b) the agent has narrowed the failure cause to
a layer outside `doca-dpa-verbs` itself (driver / firmware /
network / *host-side RDMA was the right answer all along* / DPACC
or DOCA version skew) and escalated to the matching skill.

Iteration shape — the smoke-before-scale principle is non-negotiable
for the DPA-side verbs surface:

1. **One DPA kernel launch, one DPA-side WR post, one completion.**
   The cheapest possible smoke. Host configures ONE QP, launches
   the kernel ONCE, the kernel posts exactly ONE WR (e.g. an RDMA
   read of a small buffer; matched on the peer where two-sided),
   the host drains exactly ONE completion through the chosen path
   ([CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)).
   If this fails, do not scale — narrow.
2. **Re-confirm the host-side cap-query passed for THIS device.**
   Re-run the `doca_dpa_verbs_cap_*` for the specific verb /
   opcode the kernel posts, from the host, against the active
   `doca_devinfo`. If false → that is the answer; the user's
   device or DOCA + DPACC version does not support the verb on
   the DPA side. Update the user's intent, climb back to
   [`doca-rdma`](../doca-rdma/SKILL.md), or update the install.
3. **Verify the host-configures-QP / DPA-uses-QP coupling.** Walk
   the host-side QP setup AND the DPA-side WR construction
   together. If the kernel constructs a WR whose opcode / flag /
   payload size the host-configured QP cannot honor,
   `DOCA_ERROR_INVALID_VALUE` is the result; fix the side that
   does not match and rebuild BOTH per
   [`## modify`](#modify) slot 7.
4. **Inspect the CQE on `DOCA_ERROR_IO_FAILED`.** Per the
   DPA-Verbs error overlay in
   [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy),
   IO_FAILED means *the WR submitted but the completion reports an
   error*. The answer is in the CQE error field on whichever side
   reads the completion; the agent must direct the user there
   before recommending any code-level change. Do NOT inspect the
   DPA-side post return value and assume that is the error.
5. **Streaming-launch loop (only after smoke is green).** Once the
   single-WR-post smoke completes, walk the parent's
   streaming-launch test pattern from
   [`doca-dpa TASKS.md ## test`](../doca-dpa/TASKS.md#test) step 2,
   layered with the DPA-side WR repetition. Catches completion-
   queue-sizing bugs that compound across the host completion
   surface AND the DPA-side post pattern.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `DOCA_ERROR_NOT_SUPPORTED` at kernel launch (when the kernel uses a DPA-side verb the agent expected to work) | The host-side `doca_dpa_verbs_cap_*` returned true at configure time, but the runtime rejects the launch | Re-narrow to the device-level cap-query (BlueField generation may not actually expose the verb to the DPA on this hardware); confirm BOTH version axes match per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test); consider climbing back to [`doca-rdma`](../doca-rdma/SKILL.md) |
| `DOCA_ERROR_DRIVER` at launch or CQE drain | DOCA + DPACC + `doca-dpa-verbs` versions are skewed OR the DPA-side image was built against a different `doca-dpa-verbs` install than the host runtime | Re-run the version chain per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test); rebuild BOTH sides via DPACC + host build against matched versions; cross-check against the DOCA Compatibility Policy |
| `DOCA_ERROR_INVALID_VALUE` at first DPA-side WR | Two-side-program signature mismatch — the kernel constructs a WR whose shape the host-configured QP does not support | Walk both sides together per [`## modify`](#modify) slots 2-4; rebuild BOTH sides; this is the highest-frequency DPA-Verbs program bug |
| `DOCA_ERROR_IO_FAILED` reported through the completion | The DPA-side post succeeded but the completion carries an error status | Stop reading the DPA-side post return; read the CQE error field on the chosen completion surface. The cross-cutting taxonomy ladder in [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug) takes over from the CQE error |
| Host launched the kernel; no completion observed; host log is silent | DPA kernel is stuck mid-execution — possibly inside the `doca_dpa_verbs_*` post body or the in-kernel completion poll | Walk the kernel-exit condition per [`## modify`](#modify) slot 6; reach for the DPA-side developer tools named in [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability) |
| Smoke is green but the latency win didn't materialize | The user dropped to DPA-side verbs assuming the host round-trip was the bottleneck; with the new measurement the assumption no longer holds | Successful outcome of the loop. Climb back to [`doca-rdma`](../doca-rdma/SKILL.md) (or [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md)) for the RDMA work the host can handle; retire the DPA-side path for that subset |

Loop termination: stop iterating once two consecutive iterations
of the same kind don't change anything — that means the cause is
below `doca-dpa-verbs`. Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured layer-1-through-5 evidence including BOTH the
host-side DOCA log and the DPA-side tooling output.

## debug

Goal: when a `doca_dpa_verbs_*` post (or its observed completion)
returns a `DOCA_ERROR_*` or does not make forward progress, narrow
the cause to a specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending DPA-Verbs-
specific fixes. This skill's overlay names the DPA-Verbs-specific
manifestation at layers 5 (runtime), 6 (program), and 7 (driver),
on top of the parent's host-side DPA overlay in
[`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug):

**Layer 5 (runtime) — DPA-Verbs overlay.**

- A DPA kernel launched, the kernel posts a `doca_dpa_verbs_*` WR,
  and no completion ever surfaces. The three usual causes: (a) the
  host is not progressing the PE / draining the
  `doca_dpa_completion` per the parent's
  [`doca-dpa TASKS.md ## run`](../doca-dpa/TASKS.md#run); (b) the
  DPA kernel is stuck mid-post or mid-in-kernel-poll with no
  termination condition; (c) the host-configured QP is in a state
  that silently dropped the WR. Confirm the env-side preconditions
  per [`## configure`](#configure) step 1 and the host-side progress
  per [`## run`](#run) step 4 before assuming the DPA-side verbs
  surface itself is broken.
- On `DOCA_ERROR_IO_FAILED` surfaced through the completion, the
  DPA-side post return is not the answer. Direct the user to the
  CQE error field per
  [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).

**Layer 6 (program) — DPA-Verbs overlay.**

- **Two-side-program signature mismatch.** The single highest-
  frequency DPA-Verbs program bug. The host configured a QP that
  cannot honor the WR shape the DPA-side kernel posts (opcode not
  in the QP feature set, payload size past the QP's max message
  size, flag not supported by the underlying transport). Walk both
  sides together per [`## modify`](#modify) slots 2-4; rebuild BOTH
  sides per [`## modify`](#modify) slot 7.
- **DPA-side post against an unready QP.** The host-side
  `doca-dpa` setup created the QP but it has not transitioned
  through the state machine required to accept WRs; the DPA-side
  post returns `DOCA_ERROR_BAD_STATE`. Walk the host-side QP
  bring-up per [`## configure`](#configure) step 4; the DPA side
  cannot manufacture readiness.
- **Host-configures-QP / DPA-uses-QP rule violation.** The user's
  DPA-side code tries to create or modify the QP from inside the
  kernel. Per the rule in
  [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes),
  this is the model bug. Refactor the QP create / configure into
  the host-side translation unit (via the parent skill); leave the
  WR post in the kernel.
- **Climb-back-up check.** Before exhausting a layer-6 debug
  session, ask: *did the latency-bottleneck premise actually hold?
  Does the higher-level host-side
  [`doca-rdma`](../doca-rdma/SKILL.md) cover this case?* Sometimes
  the cheapest layer-6 fix is to retire the DPA-side RDMA path
  entirely.

**Layer 7 (driver) — DPA-Verbs overlay.**

- `DOCA_ERROR_DRIVER` from a DPA-side WR is most often DOCA + DPACC
  + `doca-dpa-verbs` version skew (per the parent's
  [`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug) layer 7
  + this skill's [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility)
  overlay). Capture `pkg-config --modversion doca-dpa-verbs`,
  `pkg-config --modversion doca-dpa`, the installed `dpacc`
  version, and `doca_caps --version`; cross-check against the DOCA
  Compatibility Policy at
  <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html>.
- A BlueField that does not expose the requested DPA-side verb to
  the kernel surfaces as `DOCA_ERROR_NOT_SUPPORTED` at kernel
  launch. Route to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5 (driver) for the env-side BlueField mode check; this is
  NOT a code change in the kernel.

Once the layer is identified, route to the matching debug verb on
the matching skill: install / build / link / driver to
[`doca-setup ## debug`](../../doca-setup/TASKS.md#debug); version
to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug);
host-side DPA lifecycle / kernel-launch patterns to
[`doca-dpa TASKS.md ## debug`](../doca-dpa/TASKS.md#debug); the
host-side raw-verbs IO_FAILED → CQE-inspection pattern (which the
DPA-side post inherits the *shape* of) to
[`doca-rdma-verbs TASKS.md ## debug`](../doca-rdma-verbs/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are commonly
asked in the same conversations. Route them as follows so the agent
does not invent guidance:

- **install.** Installing DOCA, installing the DPACC compiler,
  choosing matched versions, post-install verification, `pkg-config`
  wiring — defer to [`doca-setup`](../../doca-setup/SKILL.md) and to
  the install-tree layout in
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA + DPACC are already installed and matched.
- **deploy.** Deploying DPA-Verbs-using applications at scale
  (multi-BlueField clusters, Kubernetes operator workflows for DPU
  workloads, multi-tenant DPA-side RDMA sharing) — out of scope
  for Phase 1 and reserved for a future platform skill. For
  single-host first-run testing, the right verb is [`## run`](#run).
- **Host-side DPA lifecycle, kernel launch, host-side completion.**
  Owned by [`doca-dpa`](../doca-dpa/SKILL.md). This skill rides on
  that surface and assumes it is already understood.
- **DPA-side `doca-dpa-comms` (local DPA-side messaging primitives).**
  Different DPA-side library, with its own pkg-config module and
  its own public guide. Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public *DOCA DPA Comms* guide. Conflating it with
  `doca-dpa-verbs` is a common DPA-side library-selection error.
- **DPACC compiler internals and DPA-side kernel programming
  itself** (how to write the function body the DPA processor runs;
  DPA-side memory layout; DPACC compile flags; DPA-side debugging
  from inside the kernel) — out of scope. Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public *DOCA DPA*, *DOCA DPACC Compiler*, and *DPA Tools*
  guides plus the parent [`doca-dpa`](../doca-dpa/SKILL.md).

## Command appendix

Every command below is **cross-cutting on DOCA DPA Verbs** — it
answers a recurring class of question that comes up in the verbs
above. The agent should treat the *class* as load-bearing; the
worked example is a single instance. Run-as user is the
unprivileged user unless noted; sudo is called out per row.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers + hugepages in one
   shot; `doca-capability-snapshot` for per-device capability flags;
   `version-matrix.json` for *"available since"* lookups).
2. If the probe succeeds, the structured tool's output is the
   authoritative answer and the agent SHOULD NOT also run the
   manual command in the row below. Report *"using structured
   `<tool>`"*.
3. If the probe fails, fall back to the manual command in the row.
   Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-dpa-verbs` | [`## configure`](#configure) step 3; [`## build`](#build) minimum-version slot | What is the build-time DOCA DPA Verbs version? | A semver string matching `pkg-config --modversion doca-dpa` AND `pkg-config --modversion doca-common` AND `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2) |
| `pkg-config --modversion doca-dpa` | [`## configure`](#configure) step 4; [`## build`](#build) | What is the parent host-side DPA library version? | Matches the `doca-dpa-verbs` version above; disagreement = partial install per the four-way-match rule in [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility) |
| `which dpacc && dpacc --version` (or the install-tree path) | [`## configure`](#configure) step 2; [`## build`](#build) DPACC step | Is the DPACC compiler installed and at what version? | A version string the agent compares against the DOCA Compatibility Policy linked from [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility). Missing `dpacc` = the DPA-side translation unit cannot be built; route to [`doca-setup`](../../doca-setup/SKILL.md) |
| `doca_caps --list-devs` | [`## configure`](#configure) step 3 | Which DOCA devices does the host see, and which expose a DPA processor with the verbs surface? | One entry per `doca_dev` with the BlueField identity and the per-library capability flags including the DPA-Verbs support axis. No DPA-Verbs-capable entry = the BlueField is not present, not in the right mode, or not on a generation that exposes DPA-side verbs; route to [`doca-setup`](../../doca-setup/SKILL.md) |
| `ls /opt/mellanox/doca/samples/doca_dpa_verbs/` | [`## modify`](#modify) slot 1 | Which DPA-Verbs samples ship in this install (both host-side AND DPA-side translation units), and which is the closest starting point? | A list of sample directories that each contain BOTH host-side and DPA-side source plus a `meson.build` that wires `dpacc` and `pkg-config doca-dpa` together |
| `dmesg \| tail -n 40` (sudo) | [`## debug`](#debug) layer 7 | What did the kernel / driver log around the last DPA-side RDMA call? | Empty or recent benign messages. Repeated mlx5 / DPA-driver errors → driver-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run) step 5 | What did the structured DOCA logger emit for the first failing host-side call around a DPA-side RDMA op? | A trace-level line on every host-side lifecycle transition, every kernel launch submit, and every completion drained. Silence after a launch = host PE not progressed OR DPA kernel running but stuck inside the `doca_dpa_verbs_*` body |
| (route via [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)) DPA-side developer tools — DPA debugger, DPA process-state inspector, DPA statistics tool | [`## debug`](#debug) layer 5; [`## debug`](#debug) layer 6 | What is the DPA processor itself doing right now, from the DPA side, when the host sees no completion for a DPA-side WR post? | The public *DPA Tools* umbrella documents the per-tool output; the agent's job is to NAME the existence of these tools and route the user there, not to redefine their surface |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the DPA-Verbs-specific rows on top.
