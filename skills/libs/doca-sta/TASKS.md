# DOCA STA workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. Skip ahead only when the user is already
past a verb. The `## test` verb is an iterative loop (cap-query
re-check → substrate / steering precondition re-check →
single-IO admin-then-read smoke → multi-queue smoke → loop back
if a precondition or sizing changed), not a one-shot pass — see
the eval-loop overlay in `## test` below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the STA capability surface, the
integration boundary with SPDK / kernel-nvme, the NVMe queue-pair
shape, the transport-type taxonomy, the capability-query rules,
the error taxonomy, the observability surface, and the safety
policy, see [CAPABILITIES.md](CAPABILITIES.md). For the
cross-library DOCA patterns layered under everything below (the
universal Core lifecycle, the cross-library `DOCA_ERROR_*`
taxonomy, the modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
For the RDMA substrate that NVMe-over-RDMA transport lands on,
see [`doca-rdma`](../doca-rdma/SKILL.md). For the steering
side that decides which NVMe-oF packets reach STA-managed
queues, see [`doca-flow`](../doca-flow/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: stand up a `doca_sta` Core context on a BlueField, pick
the transport type the device actually supports, size the NVMe
queue pair against the device cap, and confirm both the
substrate-library and the steering preconditions are met before
the NVMe-oF Connect handshake is attempted.

Steps the agent should walk the user through:

1. **Confirm the env preconditions and substrate library FIRST.**
   Per the precondition matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   walk three checks BEFORE any `doca_sta_*` call: (a) DOCA is
   installed and consistent — `pkg-config --modversion doca-sta`
   resolves and matches `doca_caps --version` per the four-way
   match rule owned by
   [`doca-version`](../../doca-version/SKILL.md); (b) for the
   NVMe-over-RDMA path, `pkg-config --modversion doca-rdma`
   resolves AND `doca_rdma_cap_*` on the chosen device reports a
   non-empty surface per
   [`doca-rdma CAPABILITIES.md ## Capabilities and modes`](../doca-rdma/CAPABILITIES.md#capabilities-and-modes);
   (c) the user has a plan for how NVMe-oF traffic will reach
   the STA-managed queue — either a DOCA Flow rule programmed
   per [`doca-flow TASKS.md ## configure`](../doca-flow/TASKS.md#configure),
   or the env-side equivalent on the user's setup. If any of
   the three is missing, route to the owning skill (the env
   side to [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure))
   first and do NOT propose a `doca_sta_*` workaround.
2. **Confirm which SIDE the user is building.** Per the
   side-symmetry note in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   doca-sta supports both initiator and target. The lifecycle
   and queue-pair shape are identical on both sides, but the
   application logic on top (SPDK `bdev_nvme` initiator vs
   SPDK `nvmf_tgt` target; kernel `nvme` host vs kernel
   `nvmet` target) is different and so are the configure-time
   choices. If the user has not named the side, ASK — getting
   it wrong silently inverts the handshake direction.
3. **Run capability discovery for the transport types the user
   is considering, against the active `doca_devinfo`.** Per
   the cap-query rule in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   call the matching `doca_sta_cap_*` query for each candidate
   transport (NVMe-over-RDMA vs NVMe-over-TCP) and quote the
   queried result back to the user. Do NOT assume from prior
   installs and do NOT quote a transport from memory — the
   exact cap-query spelling is install-bound and varies across
   DOCA versions per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   If neither transport is advertised, that is the answer — the
   device or DOCA version does not support NVMe-oF here.
4. **Size the NVMe queue pair against the device cap.** Per
   the queue-pair sizing table in
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   ASK the user for the intended per-connection I/O queue count
   and queue depth, then gate each input on the matching
   `doca_sta_cap_*` query (max number of I/O queues, max I/O
   queue depth, max in-flight IOs per queue). Surface the
   queried ceilings before the user commits — oversizing fails
   at `doca_ctx_start()` with `DOCA_ERROR_NOT_SUPPORTED` or
   `DOCA_ERROR_INVALID_VALUE`, and undersizing leaves throughput
   on the floor. Each NVMe-oF connection always carries exactly
   one admin queue plus the configured number of I/O queues —
   that ratio is not negotiable.
5. **Create and configure the `doca_sta` context.** This is a
   standard DOCA Core context create — the universal lifecycle
   from
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure)
   applies. Mandatory before `doca_ctx_start()`: the underlying
   `doca_dev` opened against a device that advertises STA
   capability; the chosen transport type set via the matching
   `doca_sta_set_*` setter; the I/O queue count and depth at or
   below the device cap. Optional opt-ins (NVMe-oF features
   the user explicitly needs) gate on the matching
   `doca_sta_cap_*` query first. Register the per-queue and
   per-IO completion callbacks BEFORE start — callbacks
   registered after `doca_ctx_start()` are not observed on the
   first lifecycle transitions and the agent must surface this.
6. **Sanity check before any Connect handshake.** Confirm with
   the user: the SPDK or kernel-nvme integration point on top
   (doca-sta does NOT implement the NVMe protocol semantics per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   integration-boundary table); which NVMe-oF subsystem / peer
   the connection is targeting; how the user will read per-queue
   state transitions and per-IO completions on the DOCA Core
   progress engine per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).
   If any of those are unclear, stop and ask — do NOT invent
   the SPDK / kernel-nvme glue inside this skill.

If any step fails with a `DOCA_ERROR_*`, route through the STA
error taxonomy in
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: produce a binary that links DOCA STA against the user's
installed DOCA, using the canonical cross-library build pattern,
with the substrate library (`doca-rdma`) linked alongside when
the chosen transport is NVMe-over-RDMA.

The build pattern for any DOCA C/C++ consumer is fully
documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the STA-specific overlay:

| Slot | Value for STA | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-sta` for the STA surface itself; AND `doca-rdma` for the NVMe-over-RDMA substrate when that transport is picked | Linking only `doca-sta` without `doca-rdma` produces `undefined reference` errors for the substrate symbols when the transport is RDMA — surface the substrate-link requirement up front per [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) |
| Include flags | `pkg-config --cflags doca-sta` (add `doca-rdma` for the RDMA transport) | Resolves DOCA headers under `/opt/mellanox/doca/infrastructure/include/` for the STA surface — and for the substrate surface in the RDMA case — in one pass |
| Link flags | `pkg-config --libs doca-sta` (add `doca-rdma` for the RDMA transport) | Pulls in `-ldoca-sta -ldoca-common`, plus `-ldoca-rdma` when the transport is RDMA; ordering is handled by `pkg-config`, do not hand-craft the `-l` list |
| Version anchors | `pkg-config --modversion doca-sta` MUST agree with `doca_caps --version`; for NVMe-over-RDMA, `pkg-config --modversion doca-rdma` MUST also agree with the same line | Per the substrate-library version-match rule in [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility), a STA install that compiles against one DOCA RDMA major and runs against another is a partial-install hazard; route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2 |
| Companion DOCA libs | `doca-argp` for argument parsing (if the consumer uses the standard DOCA arg style); the cross-library `doca-common` is pulled in transitively | Adding unnecessary companion libs bloats the link line and obscures real partial-install issues |
| SPDK / kernel-nvme glue | NOT shipped by this skill | Per [`SKILL.md`](SKILL.md), the SPDK and kernel `nvme` stacks are upstream projects with their own integration patterns; this skill names the boundary, the user's project owns the glue |

For non-C consumers (Rust, Go, Python), the wrapper consumes
`libdoca_sta.so` (and `libdoca_rdma.so` for the RDMA transport)
through FFI; the build-time version visibility goes through the
language's own FFI generator (e.g. `bindgen` against the
doca-sta headers, which assume the substrate headers when the
RDMA transport is in scope). The substrate rule, lifecycle
rule, and capability-discovery rules still apply per
[`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility),
and the wrapper must surface the version-pair to the user.

## modify

Goal: take the closest-fitting shipped DOCA STA sample as the
verified starting point and apply a **minimum diff** to make it
match the user's intent, without rewriting from scratch and
without inventing SPDK / kernel-nvme glue that does not belong
in this skill.

The universal modify-a-shipped-sample workflow is in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify);
this skill provides the STA-specific slot fill.

| Slot | What the agent asks the user | STA-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_sta/`? | Pick a sample whose **shape** matches the user's intent: same side (initiator vs target), same transport (NVMe-over-RDMA vs NVMe-over-TCP), comparable queue-pair sizing. The shipped samples assume a fixed integration shape — do NOT bridge across both side and transport in one diff. A re-architecture diff is always larger and riskier than starting from the closer sample. |
| 2. Side switch (initiator ↔ target) | Is the user changing the side relative to the sample? | Per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), the lifecycle and queue-pair shape are symmetric across sides but the application logic on top differs. If the user is switching side, recommend starting from the side-matching sample instead of inverting one over. |
| 3. Transport-type change | Is the user moving from NVMe-over-RDMA → NVMe-over-TCP or vice versa? | Per the cap-query rule in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), re-run `doca_sta_cap_*` for the new transport on the active `doca_devinfo` BEFORE the diff lands. A transport the device does not advertise will fail at configure time with `DOCA_ERROR_NOT_SUPPORTED`. |
| 4. Queue-pair re-sizing | Is the user changing I/O queue count, queue depth, or in-flight budget? | Per the queue-pair sizing table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), every sizing input gates on its own cap query; the device cap is the ceiling, the user's peer's advertised limits are also a ceiling. Re-run the matching `doca_sta_cap_*` queries and quote both. |
| 5. NVMe-oF feature opt-ins | Is the user enabling any NVMe-oF feature the sample does not enable (Discovery, In-Capsule Data, …)? | Per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), each NVMe-oF feature opt-in is its own capability axis. Opting in to a feature the device does not advertise fails at configure, not at runtime — re-run the matching `doca_sta_cap_*` query first. |
| 6. SPDK / kernel-nvme integration point | Is the user changing the NVMe stack on top (e.g. SPDK `bdev_nvme` → kernel `nvme` host)? | Per [`SKILL.md`](SKILL.md) and the integration-boundary table in [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes), the NVMe stack on top is the user's project — do NOT propose to write the glue inside this skill. Name the boundary; route to the upstream stack's own integration docs for the glue itself. |
| 7. Keep the build manifest unchanged | The sample's existing `meson.build` already wires `pkg-config doca-sta` and, for RDMA samples, `doca-rdma` | Do NOT switch to a hand-rolled Makefile for *"simplicity"* — it removes the version-check rail and the substrate-link rail in one stroke. |

The agent emits an *intent description + the seven filled
slots*; the *actual* unified diff against the sample source is
produced the way every other library skill in this bundle
handles modify — the agent walks the user through the diff
line-by-line against the sample source they read on disk, and
has the user paste back the result for validation. The agent's
anti-pattern alert: a *"clean rewrite"* from scratch is almost
always slower to first green than a minimum-diff modify on a
shipped STA sample, and removes the user's ability to bisect
against a known-good baseline.

## run

Goal: actually execute the built binary against the user's
installed DOCA on a BlueField, with the NVMe-oF peer reachable
and the SPDK or kernel-nvme stack on top driving the NVMe
protocol semantics.

Steps the agent should walk the user through:

1. **Confirm the NVMe-oF peer is reachable.** Doca-sta is the
   transport layer; without a peer (target if the user built
   an initiator; initiator if the user built a target) the
   Connect handshake never completes and the program hangs.
   For NVMe-over-RDMA both sides must route IB / RoCE to each
   other per [`doca-rdma TASKS.md ## run`](../doca-rdma/TASKS.md#run);
   for NVMe-over-TCP both sides must be on a routable IP path.
   This is a fabric / env precondition, NOT a code problem.
2. **Confirm the steering side is in place.** Per the
   precondition matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   NVMe-oF traffic only reaches the STA-managed queue when a
   DOCA Flow rule (or the env-side equivalent) steers it
   there. The most common symptom of a missing Flow rule is
   that the Connect handshake never completes and the program
   blocks indefinitely — do NOT recommend retrying the
   `doca_ctx_start()` until the Flow rule is confirmed per
   [`doca-flow TASKS.md ## run`](../doca-flow/TASKS.md#run).
3. **Start the side that LISTENS first.** When the user built
   a target, start it before the initiator side starts
   connecting. When the user built an initiator that talks to
   an existing target, confirm the target is already up. Do
   NOT recommend starting the initiator first and waiting —
   the symptom is identical to a steering bug and the
   bisection wastes time.
4. **Start the SPDK or kernel-nvme stack on top.** Per
   [`SKILL.md`](SKILL.md), doca-sta is the transport layer
   only — the NVMe-oF Connect handshake itself, the Discovery
   exchange, and every admin / I/O command on top is owned by
   SPDK or the kernel `nvme` stack. Confirm the upstream
   stack is configured to use doca-sta as its transport
   provider for this connection.
5. **Capture the structured log on the first run.** Set
   `DOCA_LOG_LEVEL=trace` for the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)).
   This is the cheapest way to make the per-queue lifecycle
   transitions, the Connect handshake outcome, and the
   per-IO completion events visible on first failure — and
   to confirm the DOCA Core progress engine is being
   progressed per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).

For the runtime version + `LD_LIBRARY_PATH` cross-checks that
underlie *"the program built but does nothing"*, see
[`doca-version TASKS.md ## run`](../../doca-version/TASKS.md#run).

## test

Goal: prove the configured STA context can actually establish
an NVMe-oF connection and move one admin command and one I/O
end-to-end on the user's hardware, before the user attempts
production traffic on top of SPDK or kernel-nvme.

This is **a loop, not a one-shot pass.** Each iteration
narrows either the capability set, the substrate / steering
preconditions, the queue-pair sizing, the transport-type pick,
or the SPDK / kernel-nvme integration point. The loop
terminates when either (a) a single admin command (e.g.
Identify Controller) on the admin queue plus a single Read or
Write I/O on one I/O queue both complete successfully, or
(b) the agent has narrowed the failure cause to a layer
outside STA itself (substrate library, steering, fabric, NVMe
stack on top, driver / firmware) and escalated to the matching
skill.

Iteration shape:

1. **Capability re-check.** Re-run `doca_sta_cap_*` for the
   transport the user picked and for each NVMe-oF feature
   the user opted in to, against the active `doca_devinfo`.
   If any answer comes back false (or returns a smaller cap
   than the user's request) that is the answer — the user's
   device or DOCA version does not support the request. Per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes),
   do NOT escalate further until the cap-query baseline is
   re-established.
2. **Substrate and steering re-check.** Walk the precondition
   matrix in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
   once more: substrate library (RDMA for NVMe-over-RDMA),
   device access (group / sudo), DOCA Flow rule in place for
   the NVMe-oF 5-tuple. The vast majority of *"my Connect
   handshake never completes"* failures are here, not in the
   STA code.
3. **Single-IO smoke — admin command FIRST, then one I/O.**
   Per the smoke-before-scale-up rule in
   [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
   drive ONE NVMe admin command (typically Identify Controller)
   on the admin queue and confirm the completion event arrives
   on the DOCA Core PE with success; THEN drive ONE NVMe Read
   or Write on a single I/O queue and confirm its completion
   arrives. Failure on admin narrows to handshake / fabric
   / steering; failure on I/O after admin succeeded narrows to
   I/O-queue sizing / mmap / SPDK or kernel-nvme glue. Both
   together give a much cleaner bisection than starting at
   production scale.
4. **Multi-queue smoke.** Once the single-IO smoke is green,
   add a second I/O queue on the same connection, repeat one
   Read or Write on each, and confirm both completions
   arrive. Catches per-queue bugs that a single-queue smoke
   cannot (queue-count cap miscount, per-queue progress not
   wired, queue-pair state machine confused about which
   queue is which).
5. **Negative test — capability mismatch.** Intentionally
   request a transport, queue depth, or NVMe-oF feature the
   cap query in step 1 says is NOT supported, and confirm the
   reported `DOCA_ERROR_NOT_SUPPORTED` (or
   `DOCA_ERROR_INVALID_VALUE` for an over-cap value) matches
   the cap-query answer. Validates the agent's capability
   discovery is itself correct.
6. **Sustained-run loop (optional, only after the smoke is
   green).** Drive a small steady-state workload through the
   established connection for minutes — not seconds — and
   confirm: no spurious `DOCA_ERROR_IO_FAILED` (transport is
   stable); no `DOCA_ERROR_AGAIN` storm (in-flight budget is
   appropriately sized for the steady rate); per-queue
   completions continue to arrive. Catches sizing-envelope
   bugs that a short smoke cannot.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Connect handshake never completes | `doca_ctx_start()` returns success but the per-queue state never transitions past CREATED, OR the SPDK / kernel-nvme stack on top reports the NVMe-oF Connect timed out | Re-walk the substrate + steering precondition matrix in [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy) BEFORE re-checking STA code — this is almost never a STA bug |
| `DOCA_ERROR_NOT_SUPPORTED` on transport set | The agent picked NVMe-over-RDMA (or NVMe-over-TCP) on a device whose cap query says the transport is unavailable | Re-run the `doca_sta_cap_*` query against the active `doca_devinfo`; switch to the supported transport OR pick a device that advertises the desired one |
| Single I/O fails with `DOCA_ERROR_IO_FAILED` after admin command succeeded | The admin queue worked but the I/O queue path is broken — transport-layer error, peer-side controller reset, or the substrate (e.g. RDMA queue-pair) hit a fault | Capture `dmesg | tail` per [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug) and the matching substrate-skill error taxonomy in [`doca-rdma CAPABILITIES.md ## Error taxonomy`](../doca-rdma/CAPABILITIES.md#error-taxonomy); do NOT retry blindly |
| `DOCA_ERROR_AGAIN` on submit during the sustained-run loop | The per-queue in-flight budget is full | This is the cross-library *"would-block, retry after progress"* pattern — drain completions via `doca_pe_progress()` before re-submitting, or raise the queue depth / in-flight budget within the device cap per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| Same code passes on host A, fails on host B | Different DOCA version, different substrate version, or different device cap surface | Re-run the version chain per [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) four-way match on host B; re-run the STA cap queries on host B against the active `doca_devinfo`; re-walk the substrate-library version-match rule in [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) |

Loop termination: stop iterating once two consecutive
iterations of the same kind do not change the picture — that
means the cause is below STA (substrate, steering, fabric,
NVMe stack on top, driver / firmware). Escalate to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
with the captured STA-layer trace, the cap-query baseline,
and the substrate-side trace as evidence.

## debug

Goal: when a `doca_sta_*` call (or the per-queue / per-IO
event stream on the progress engine) returns a `DOCA_ERROR_*`
or does not behave as expected, narrow the cause to a single
layer before recommending any code change.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending STA-specific
fixes. This skill's overlay names the STA-specific
manifestation at layers 5 (runtime), 6 (program), and 7
(driver / substrate):

**Layer 5 (runtime) — STA overlay.**

- `DOCA_ERROR_BAD_STATE` on the first STA call after start is
  *almost always* a lifecycle violation on the per-connection
  queue-pair state machine: an I/O was submitted before the
  queue-pair transitioned to CONNECTED, or the context was
  reconfigured after start. Walk the universal lifecycle in
  [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)
  AND the per-queue state-transition note in
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
  before recommending any code change.
- `DOCA_ERROR_AGAIN` on I/O submit is the in-flight budget
  full. This is *not* a hardware error — drive
  `doca_pe_progress()` to drain completions, or raise the
  per-queue in-flight budget within the device cap per
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
  Do not recommend a retry loop without the progress call.
- *"The Connect handshake never completes"* is *rarely* an
  STA bug. Per the safety policy in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy),
  walk the precondition matrix (substrate library present,
  device access, steering rule in place) BEFORE any code
  change. The most common cause is a missing or wrong DOCA
  Flow rule for the NVMe-oF 5-tuple, owned by
  [`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug).

**Layer 6 (program) — STA overlay.**

- Lifecycle order: configure → start → per-queue CONNECTED
  callback → use → stop → destroy. Out-of-order returns
  `DOCA_ERROR_BAD_STATE` per
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
  The most common case is submitting an I/O before the
  queue-pair reports CONNECTED — surface the transition-event
  hookup before any other diagnosis.
- Cap-query miss: `DOCA_ERROR_NOT_SUPPORTED` or
  `DOCA_ERROR_INVALID_VALUE` at configure / start is almost
  always a value (transport type, queue depth, queue count,
  NVMe-oF feature opt-in) that the cap query would have
  rejected. Re-read the cap, lower the requested value, and
  re-run configure per
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy).
- Integration-boundary confusion: the agent must NOT propose
  an NVMe-protocol-level fix inside this skill. Per
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  integration-boundary table, NVMe admin commands, namespace
  management, and block-device semantics are owned by SPDK or
  the kernel `nvme` stack — if the failure is at that layer,
  route the user to the upstream project's own debug guide
  and do not invent a `doca_sta_*` call to substitute.

**Layer 7 (driver / substrate) — STA overlay.**

- `DOCA_ERROR_IO_FAILED` on a per-IO completion is a
  transport-layer error: link drop, RDMA peer disconnect,
  TCP reset, firmware fault, or peer-side controller reset.
  Capture `dmesg | tail` and `mlxconfig -d <pcie> q` per
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5 (driver); for the NVMe-over-RDMA path overlay the
  substrate-side error taxonomy in
  [`doca-rdma CAPABILITIES.md ## Error taxonomy`](../doca-rdma/CAPABILITIES.md#error-taxonomy).
  Do NOT retry blindly in the STA code.
- `DOCA_ERROR_DRIVER` from any STA call is the layer below
  DOCA reporting failure. Capture
  `pkg-config --modversion doca-sta`,
  `pkg-config --modversion doca-rdma` (if applicable), and
  `doca_caps --version`; cross-check the version triple per
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility);
  route to
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5 (driver). A version-skew between STA and the
  substrate is the canonical partial-install hazard here.
- `DOCA_ERROR_NOT_PERMITTED` on the `doca_dev` open or the
  `doca_sta` context create is access-side, not code-side.
  Confirm sudo or the appropriate group membership per
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy);
  the fix lives in
  [`doca-setup TASKS.md ## configure`](../../doca-setup/TASKS.md#configure),
  not in a `doca_sta_*` call.

Once the layer is identified, route to the matching debug
verb on the matching skill: install / build / link / driver
to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug);
version to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug);
substrate (RDMA) to
[`doca-rdma TASKS.md ## debug`](../doca-rdma/TASKS.md#debug);
steering to
[`doca-flow TASKS.md ## debug`](../doca-flow/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as follows
so the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the install-tree
  layout in
  [`doca-public-knowledge-map ## Layout of an installed DOCA package`](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **deploy.** Deploying NVMe-oF-using applications at scale
  across many hosts / DPUs, multi-tenant subsystem fan-out,
  Kubernetes operator workflows for NVMe-oF workloads — out
  of scope for Phase 1 and reserved for a future platform
  skill. For single-host first-run testing, the right verb in
  this skill is [`## run`](#run); do not invent a "deploy"
  workflow.
- **SPDK / kernel-nvme integration glue.** SPDK is an upstream
  project with its own integration patterns for plugging in
  a transport provider; the kernel `nvme` stack likewise has
  its own host / target hook points. Per [`SKILL.md`](SKILL.md),
  this skill names the boundary (where doca-sta plugs in as
  the transport provider) but does not ship the glue itself.
  Route the user to the upstream project's own integration
  documentation reachable via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **NVMe protocol-stack work above the transport layer.**
  Designing namespaces, controller configuration, block-layer
  semantics, multi-path policy — owned by SPDK or the kernel
  `nvme` stack, not by doca-sta. Surface the integration
  boundary per
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  and route the user to the upstream project.
- **firmware burn / BFB re-image.** STA depends on the
  underlying ConnectX firmware and BlueField BFB; if the
  debug ladder lands on a driver-layer issue, the fix is via
  `mlxconfig` / `mlxfwreset` / re-imaging the BFB, all of
  which belong to the env-side skill rather than this one.
  Route to
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  layer 5.

## Command appendix

Every command below is **cross-cutting on DOCA STA** — it
answers a recurring class of question that comes up in the
verbs above. The agent should treat the *class* as
load-bearing; the worked example is a single instance.
Run-as user is the unprivileged user unless noted; sudo is
called out per row.

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
3. If the probe fails, fall back to the manual command in the
   row. Report *"falling back to manual chain"*.
4. The schemas the structured tools emit are defined in
   [`doca-structured-tools-contract ## Schemas`](../../doca-structured-tools-contract/SKILL.md#schemas);
   the version-handling semantics (four-way match, NGC,
   headers-win) are owned by
   [`doca-version`](../../doca-version/SKILL.md).

| Command (worked example) | Owning step | Class of question it answers | What healthy output looks like |
| --- | --- | --- | --- |
| `pkg-config --modversion doca-sta` | [`## configure`](#configure) step 1; [`## build`](#build) version-anchor slot | What is the build-time DOCA STA version? | A semver string matching `doca_caps --version`. Disagreement = partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2) |
| `pkg-config --modversion doca-rdma` | [`## configure`](#configure) step 1 (NVMe-over-RDMA path); [`## build`](#build) version-anchor slot | What is the build-time DOCA RDMA substrate version, and does it agree with `doca-sta`? | A semver string matching `pkg-config --modversion doca-sta` and `doca_caps --version`. Disagreement = substrate-vs-STA partial-install hazard per [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility) |
| `pkg-config --cflags --libs doca-sta doca-rdma` | [`## build`](#build) | What include + link flags does the linker need for the STA surface plus the RDMA substrate? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include `-ldoca-sta -ldoca-common -ldoca-rdma`. Hand-typed `-l` lines or linking only STA without the substrate when the transport is RDMA are the failure modes |
| `ls /opt/mellanox/doca/samples/doca_sta/` | [`## modify`](#modify) slot 1 | Which STA samples ship in this install, and which is the closest starting point? | A list of sample directories that each demonstrate a side (initiator / target), a transport (RDMA / TCP), and a queue-pair shape; pick the closest in side AND transport in one diff |
| `doca_caps --list-devs` | [`## configure`](#configure) step 3 | Which devices on this host can be used as a `doca_dev` for STA, and what do they advertise? | One row per visible device with PCIe address and capability flags; cross-check against the `doca_sta_cap_*` family for the per-device STA surface |
| `ls /opt/mellanox/doca/infrastructure/include/doca_sta*.h` | [`## configure`](#configure) step 3; [`## modify`](#modify) slot 5 | Which `doca_sta_*` cap-query and setter symbols does this install actually expose? | One or more header files; grep inside for the `doca_sta_cap_*` and `doca_sta_set_*` declarations rather than quoting symbols from memory per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes) |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run) step 5 | What did the structured DOCA logger emit for the first failing STA call? | Trace-level lines on every STA-layer lifecycle transition, the Connect handshake outcome, every per-IO completion. Silence after `doca_ctx_start()` on the `doca_sta` = either PE not progressed OR the steering rule is missing — reach for the substrate / steering trace next |
| `dmesg \| tail -n 40` (sudo) | [`## debug`](#debug) layer 7 | What did the kernel / driver log around the last STA / substrate call? | Empty or recent benign messages. Repeated mlx5 / IB errors → driver-layer bug; route to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug). Repeated NVMe-oF reset / disconnect lines → peer-side fault, NOT a doca-sta bug |
| `ibv_devinfo` (sudo, NVMe-over-RDMA path only) | [`## configure`](#configure) step 1; [`## debug`](#debug) layer 7 | What does the underlying `libibverbs` see for this device on the RDMA substrate side? | One device row with `state: PORT_ACTIVE` and a sane MTU; absence indicates the RDMA substrate is not actually up regardless of what doca-sta reports |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the STA-specific rows on top. The substrate-
library commands (RDMA-side cap queries, `ibv_devinfo`,
RDMA-side trace) live in
[`doca-rdma TASKS.md ## Command appendix`](../doca-rdma/TASKS.md#command-appendix)
and are referenced from there, not duplicated here.
