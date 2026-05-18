# DOCA RDMA Verbs workflows

**Where to start:** The verbs run `configure → build → modify →
run → test → debug`. EVERY workflow below begins by re-confirming
the drop-down decision in [SKILL.md](SKILL.md) — if
[`doca-rdma`](../doca-rdma/SKILL.md) covers the user's case, the
right answer is to stop and climb back up, not to walk these
verbs. The `## test` verb is an iterative loop (smoke → narrow →
loop back if the WR-flag set, QP feature set, or completion path
changed), not a one-shot pass — see the eval-loop overlay in
[`doca-rdma-verbs ## test`](#test) below.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the doca-rdma-vs-doca-rdma-verbs split,
the libibverbs-vs-doca-rdma-verbs boundary, the verbs object
model, capability discovery, error taxonomy, observability, and
safety policy that these workflows assume, see
[CAPABILITIES.md](CAPABILITIES.md). For the cross-library DOCA
patterns layered under everything below (the universal lifecycle,
the cross-library `DOCA_ERROR_*` taxonomy, the
modify-a-shipped-sample workflow), see
[`doca-programming-guide`](../../doca-programming-guide/SKILL.md).

Each verb below describes the **shape of the workflow**, not a
copy-paste recipe. The agent's job is to walk the user through
the steps in order, verifying preconditions before recommending
the next call.

## configure

Goal: bring up a `doca-rdma-verbs` context on a host or
BlueField, with a QP / CQ / PD / MR set the user has explicitly
chosen, *after* confirming the drop-down decision is correct.

Steps the agent should walk the user through:

1. **Re-confirm drop-down.** Ask: *"have you confirmed
   [`doca-rdma`](../doca-rdma/SKILL.md) does not expose the verb /
   opcode / WR flag / QP option you need?"* If no — stop, route
   back to `doca-rdma`. If yes — ask the user to name the
   specific thing the higher-level surface does not cover; that
   name is the load-bearing input for steps 4 and 5. This step
   is the cheapest place to catch the *"recommended raw verbs
   unnecessarily"* failure mode.
2. **Read the verbs symbols from the user's install.** The
   `doca_rdma_verbs_*` symbol surface is install-bound; the agent
   must not quote symbols from memory. Direct the user to
   `/opt/mellanox/doca/infrastructure/include/` for the verbs
   headers and to `/opt/mellanox/doca/samples/doca_rdma_verbs/`
   for the shipped samples that demonstrate the live API. Per
   [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility),
   the headers win over the docs when they disagree.
3. **Confirm the installed DOCA version.** Use the procedure in
   [`doca-version TASKS.md ## configure`](../../doca-version/TASKS.md#configure).
   Quote the version observed (`pkg-config --modversion
   doca-rdma-verbs` AND `pkg-config --modversion doca-rdma`, both
   matching `doca_caps --version`); do not assume "latest". A
   verbs-only upgrade against an older `doca-rdma` install is a
   partial-install hazard per
   [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility).
4. **Capability-query the SPECIFIC verb / opcode / option the user
   named in step 1.** Run the matching `doca_rdma_verbs_cap_*`
   against the active `doca_devinfo`. If it returns false —
   that is the answer. The user's device / firmware / DOCA
   version does not support what they wanted, and dropping to
   raw verbs cannot manufacture support that the cap-query
   denies. Climb back up to
   [`doca-rdma`](../doca-rdma/SKILL.md) if the higher-level
   surface covers a viable alternative.
5. **Sketch the verbs object set BEFORE any code.** Which PD?
   Which QP(s), with which feature set? Which CQ(s), with which
   completion-handling path (DOCA progress engine vs manual CQ
   polling — pick one explicitly per
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability))?
   Which MR(s) covering which memory? If any of those are
   unclear, stop and ask — do not invent.
6. **Configure the verbs context.** Walk the universal Core
   lifecycle (`cfg-create → cfg-set-* → init → start → use →
   stop → destroy`, per
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure));
   apply the verbs-specific setters in the order the headers
   require. Per the no-mixing rule in
   [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy),
   do not pull any `ibv_*` handle into this context.
7. **Sanity check before any WR submission.** Confirm with the
   user: which QP, which CQ it reports to, which MR(s) the WR
   will reference, which WR opcode + flags. If any of those
   are unclear, stop and ask — raw verbs amplifies the cost of
   guessed parameters.

If any step fails with a `DOCA_ERROR_*`, route through the error
taxonomy in
[CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy)
before retrying.

## build

Goal: produce a binary that links `doca-rdma-verbs` against the
user's installed DOCA, using the canonical cross-library build
pattern.

The build pattern for any DOCA C/C++ consumer is **identical**
across libraries — `pkg-config` for include + link flags, meson
or CMake as the build system — and is fully documented in
[`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build).
This skill carries only the raw-verbs-specific overlay:

| Slot | Value for raw verbs | Why it matters |
| --- | --- | --- |
| `pkg-config` module name | `doca-rdma-verbs` (NOT `doca-rdma`; NOT `libibverbs`) | The library's `.pc` file installed by the DOCA host packages. A typo to `doca-rdma` silently links the wrong library; a fallback to `libibverbs` puts the user on the wrong side of the boundary in [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) |
| Required runtime libs | `libdoca-common` plus the verbs runtime referenced by `pkg-config --libs doca-rdma-verbs` | The raw-verbs library depends on Core; it does NOT auto-pull `doca-rdma`, and adding `doca-rdma` on the link line as a *"just in case"* hides the drop-down decision the agent and user already made |
| Header check | The verbs headers resolvable under `/opt/mellanox/doca/infrastructure/include/` | If `pkg-config --cflags doca-rdma-verbs` resolves but the include is missing, the install is partial — route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) |
| Minimum required DOCA version | Query with `pkg-config --modversion doca-rdma-verbs`; never hardcode in build files | Cross-version build/runtime mixing breaks per [CAPABILITIES.md ## Version compatibility](CAPABILITIES.md#version-compatibility), and verbs-only upgrades are a documented partial-install pattern |
| Coexistence with `doca-rdma` on the same link line | Allowed only if BOTH libraries are independently used in the same binary; never *just in case* | Adding `doca-rdma` to a binary that only uses `doca-rdma-verbs` is a code-smell that suggests the drop-down was not actually needed |

For non-C consumers (Rust, Go, Python), the link surface is the
same `*.so` files; the FFI wrapper layer is the language-specific
binding and is out of scope for this skill — but the five slots
above are still the load-bearing inputs the wrapper needs.

## modify

Goal: take a shipped DOCA RDMA Verbs sample as the verified
starting point and apply a minimum-diff modification to express
the user's intent — OR, for the libibverbs-porting case, walk the
integration path step by step (this is the load-bearing case for
the verbs skill in particular).

The universal modify-a-shipped-sample workflow lives in
[`doca-programming-guide TASKS.md ## modify`](../../doca-programming-guide/TASKS.md#modify).
Use it as-is for the *modify-a-sample* path. The verbs-specific
overlays are the *modify-from-sample schema fill* AND the
*libibverbs-porting block* below.

**Modify-from-sample schema fill — the five slots the agent must
elicit from the user before recommending any code-level edit:**

| Slot | What the agent asks the user | Verbs-specific consideration |
| --- | --- | --- |
| 1. Starting sample | Which sample under `/opt/mellanox/doca/samples/doca_rdma_verbs/`? | Pick the closest in *QP shape* (reliable vs unreliable, connected vs unconnected — whatever the user named in `## configure` step 1) and *completion-handling path* (DOCA PE vs manual CQ poll, per [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)). Do NOT bridge across both axes in a single modify pass — a smaller diff is always safer than a re-architecture |
| 2. Verbs / opcodes added or removed | Which WR opcodes? Which QP features? | Each added opcode / WR flag needs its own `doca_rdma_verbs_cap_*` query from `## configure` step 4 against the active `doca_devinfo` before any code-level change |
| 3. MR / PD changes | Which MR(s) / PD(s) change? | Refer to the no-mixing rule in [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy) — if the user is tempted to reuse an `ibv_pd` / `ibv_mr` from existing code, the porting block below is the right path |
| 4. Completion-handling change | Switch PE → manual CQ poll or vice versa? | This is a re-architecture, not a tweak. If yes, recommend the user start from the sample that already uses the target path instead of patching one over |
| 5. Transport / queue sizing | Change transport type or queue depths? | Same option set as `doca-rdma` per [`doca-rdma CAPABILITIES.md ## Capabilities and modes`](../doca-rdma/CAPABILITIES.md#capabilities-and-modes); re-run `## configure` step 4 — transport-type support is device-conditional even at the verbs level |

**Libibverbs porting block — what the agent walks the user
through when they arrive with existing `ibv_*` code.** This is
NOT a textual replacement; it is an integration into the DOCA
Core model:

1. **Confirm the case really wants `doca-rdma-verbs`, not
   `doca-rdma`.** Most libibverbs ports land cleaner on the
   higher-level [`doca-rdma`](../doca-rdma/SKILL.md) because the
   task abstractions cover the case once the user names what
   they actually do. Re-walk the drop-down decision in
   [SKILL.md](SKILL.md) before any porting work.
2. **Replace `ibv_context` ownership with `doca_dev` ownership.**
   The device handle the verbs context consumes is `doca_dev`,
   discovered through the standard DOCA Core path
   (`doca_dev_open` on a `doca_devinfo`), not through
   `ibv_open_device`. Mixing the two handles on the same hardware
   resource is the no-mixing rule in
   [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy).
3. **Integrate with the DOCA Core lifecycle.** Wrap the verbs
   object set in a `doca_ctx_*` lifecycle per
   [`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
   Calls that lived in `ibv_*` setup move into `cfg-set-*` /
   `start`; calls that lived in cleanup move into `stop` /
   `destroy`.
4. **Drive completions through the DOCA progress engine.** Replace
   the libibverbs CQ-polling loop with `doca_pe_progress` against
   a CQ surfaced through the verbs context, per
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability).
   If the user has a documented reason to keep manual CQ polling,
   that is the *other* valid path — but the agent must make the
   choice explicit, not let it drift.
5. **Map every `ibv_*` error path onto `DOCA_ERROR_*`.** Per the
   raw-verbs error overlay in
   [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy),
   including the `IO_FAILED → inspect the CQE` rule.

The agent emits an *intent description + the five filled slots*
(modify-from-sample case) or *the five-step porting walk*
(libibverbs case); the *actual* unified diff against the sample
source is produced by the modify-from-sample renderer (deferred
to a future round). Until the renderer ships, the agent walks
the user through the diff line-by-line against the sample source
they read on disk, and has the user paste back the result for
validation.

## run

Goal: actually execute the built binary against the user's
installed DOCA on a host or BlueField, including a peer to
connect to.

Steps the agent should walk the user through:

1. **Confirm the peer is reachable.** Raw verbs needs a peer; the
   peer's RDMA stack and transport must match what this side
   asked for (IB / RoCE; QP feature set per `## configure` step
   4). A solo run produces a misleading hang.
2. **Run the listening side first.** Same shape as
   [`doca-rdma TASKS.md ## run`](../doca-rdma/TASKS.md#run) step
   2 — the listening side must be in its accept-ready state
   before the connecting side starts. Raw verbs does not change
   that ordering.
3. **Capture the structured log.** Set `DOCA_LOG_LEVEL=trace` for
   the first run (see
   [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability)).
   This is the cheapest way to make verbs-layer lifecycle
   transitions visible on first failure.
4. **Confirm completions are arriving on the chosen path.** A run
   that submits WRs but produces no CQEs is almost always either
   a missing `doca_pe_progress` call (DOCA PE path) or a missing
   manual CQ poll (manual path). Confirm the chosen path from
   [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)
   is actually being driven on both sides.

## test

Goal: prove the configured raw-verbs context can actually move
data correctly between the two sides on the user's hardware, and
that the specific verb / opcode / WR flag that justified the
drop-down actually fires the way the user expected.

This is **a loop, not a one-shot pass.** Each iteration narrows
either the cap-query, the QP / WR setup, the completion-handling
path, or the user's no-mixing-with-libibverbs hygiene. The loop
terminates when either (a) the user's intended raw-verbs pattern
flows end-to-end with the expected completions, or (b) the agent
has narrowed the failure cause to a layer outside `doca-rdma-verbs`
itself (driver / firmware / network / *the higher-level
`doca-rdma` was the right answer all along*) and escalated to
the matching skill.

Iteration shape — the smoke-before-scale principle is
non-negotiable for raw verbs:

1. **One QP, one WR, one completion.** The cheapest possible
   smoke. Bring up exactly ONE QP, post exactly ONE WR (matched
   on the peer where two-sided), drain exactly ONE completion
   through the chosen path
   ([CAPABILITIES.md ## Observability](CAPABILITIES.md#observability)).
   If this fails, do not scale up — narrow.
2. **Re-confirm the cap-query passed for THIS device.** Re-run
   the `doca_rdma_verbs_cap_*` for the specific verb / opcode /
   WR flag against the active `doca_devinfo`. If false → that's
   the answer; the user's device or DOCA version does not
   support the verb. Update the user's intent, climb back to
   [`doca-rdma`](../doca-rdma/SKILL.md), or update the install.
3. **Verify completion-handling path is wired.** If the agent
   picked the DOCA PE path: confirm `doca_pe_progress` is in
   the user's main loop on both sides. If the agent picked the
   manual CQ poll: confirm the poll loop runs and reads CQEs.
   The most common failure mode here is *picked PE in
   `## configure` but the user wrote a manual poll loop anyway*
   (or vice versa).
4. **Inspect the CQE on `DOCA_ERROR_IO_FAILED`.** Per the
   raw-verbs error overlay in
   [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy),
   IO_FAILED means *the submit succeeded but the completion
   reports an error*. The answer is in the CQE error field; the
   agent must direct the user there before recommending any
   code-level change.
5. **Confirm the no-mixing-with-libibverbs hygiene.** If the
   user was porting libibverbs code, walk the porting block from
   [`## modify`](#modify) and confirm no leftover `ibv_*` call
   touches an object owned by `doca-rdma-verbs`. Mixed handles
   are the highest-cost-to-find raw-verbs bug.

Eval-loop overlay — why this is a loop, not a one-shot pass:

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| `DOCA_ERROR_NOT_SUPPORTED` on the verb we expected to work | A `doca_rdma_verbs_cap_*` returned true, but the runtime rejects the WR | The cap-query was at the *library* level; the *device* capability per `doca_devinfo` is the real gate. Re-narrow to the device-level query, and consider whether the higher-level [`doca-rdma`](../doca-rdma/SKILL.md) exposes a viable alternative |
| `DOCA_ERROR_IO_FAILED` on the WR | Submit returned `DOCA_SUCCESS`; completion arrives with error status | Stop reading the submit return; read the CQE error field. The cross-cutting taxonomy ladder in [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug) takes over from the CQE error |
| Submit succeeded but no completion at all | Either the PE is not progressed, the manual CQ poll loop is missing, or the peer disconnected silently | Map to the path picked in [CAPABILITIES.md ## Observability](CAPABILITIES.md#observability); only ONE of PE or manual poll should be active on this CQ |
| Intermittent `DOCA_ERROR_BAD_STATE` on QP modify / WR submit | QP state transitions misordered | Re-walk the verbs object lifecycle from [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes); raw verbs exposes the QP state machine directly, and the agent must confirm each transition's precondition |
| Same code that worked yesterday now fails with `NOT_PERMITTED` | RDMA stack module loads / user group / ulimits regressed | Route to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug); this is an env regression, not a verbs code change |
| The user's case turned out to be covered by `doca-rdma` after all | The drop-down was unnecessary; the smoke surfaced a higher-level alternative | This is a successful outcome of the loop. Climb back up to [`doca-rdma`](../doca-rdma/SKILL.md) and retire the raw-verbs path |

Loop termination: stop iterating once two consecutive iterations
of the same kind don't change anything — that means the cause is
below `doca-rdma-verbs`. Escalate to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug) with the
captured layer-1-through-5 evidence.

## debug

Goal: when a `doca_rdma_verbs_*` call returns a `DOCA_ERROR_*`
(or the program doesn't make forward progress), narrow the cause
to a specific layer and act on it.

The cross-library debug ladder lives in
[`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug).
Walk through it in order — install → version → build → link →
runtime → program → driver — *before* recommending raw-verbs-specific
fixes. This skill's overlay names the raw-verbs-specific
manifestation at layers 5 (runtime) and 6 (program):

**Layer 5 (runtime) — raw-verbs overlay.**

- Walk the QP state machine: was the QP transitioned through
  every state the verbs surface requires before the first WR was
  posted? Out-of-order transitions return `DOCA_ERROR_BAD_STATE`,
  not a self-describing symptom.
- Confirm exactly ONE completion-handling path is active on the
  CQ — the DOCA progress engine OR the manual poll, never both.
  Mixed paths drop completions silently.
- On `DOCA_ERROR_IO_FAILED`, the submit return is not the answer.
  Direct the user to the CQE error field per
  [CAPABILITIES.md ## Error taxonomy](CAPABILITIES.md#error-taxonomy).

**Layer 6 (program) — raw-verbs overlay.**

- **No mixing with libibverbs.** This is the single
  highest-frequency raw-verbs program bug. Search the user's
  code for any `ibv_*` call that touches an object owned by
  `doca-rdma-verbs`; route to the porting block in
  [`## modify`](#modify) when found.
- Lifecycle order: configure → start → use → stop → destroy.
  Out-of-order returns `DOCA_ERROR_BAD_STATE`. The most common
  case in verbs context is destroying an MR or PD before the QP
  that referenced it.
- Cap-query mismatches: the program assumed a verb / opcode / WR
  flag is supported because the *library* cap-query returned
  true, but the per-`doca_devinfo` cap-query for the live
  device returns false. Re-run per
  [CAPABILITIES.md ## Capabilities and modes](CAPABILITIES.md#capabilities-and-modes)
  cap-query rule.
- **Climb-back-up check.** Before exhausting a layer-6 debug
  session, ask: *does the higher-level
  [`doca-rdma`](../doca-rdma/SKILL.md) cover this case? If yes,
  is the raw-verbs path still required?* Sometimes the cheapest
  fix at layer 6 is to drop the raw-verbs path entirely.

Once the layer is identified, route to the matching debug verb on
the matching skill: install / build / link / driver to
[`doca-setup ## debug`](../../doca-setup/TASKS.md#debug);
cross-cutting runtime to
[`doca-debug ## debug`](../../doca-debug/TASKS.md#debug);
program-layer Core-context patterns to
[`doca-programming-guide TASKS.md ## debug`](../../doca-programming-guide/TASKS.md#debug);
higher-level RDMA-layer patterns the user might climb back to,
to [`doca-rdma TASKS.md ## debug`](../doca-rdma/TASKS.md#debug).

## Deferred task verbs

The following verbs are out of scope for this skill but are
commonly asked in the same conversations. Route them as follows
so the agent does not invent guidance:

- **install.** Installing DOCA, choosing packages, post-install
  verification, `pkg-config` wiring — defer to
  [`doca-setup`](../../doca-setup/SKILL.md) and to the
  install-tree layout in
  [doca-public-knowledge-map ## Layout of an installed DOCA package](../../doca-public-knowledge-map/SKILL.md#layout-of-an-installed-doca-package).
  This skill assumes DOCA is already installed.
- **deploy.** Deploying raw-verbs-using applications at scale,
  Kubernetes operator workflows, multi-tenant RDMA isolation —
  out of scope for Phase 1 and reserved for a future platform
  skill. For single-host first-run testing, the right verb in
  this skill is [`## run`](#run).
- **rollback.** Coordinated rollback across multiple hosts /
  DPUs — out of scope. For a single in-session raw-verbs
  configuration rollback, the right verb in this skill is
  destroying the context (`doca_ctx_stop` → `doca_ctx_destroy`)
  and re-running [`## configure`](#configure) with corrected
  parameters.
- **kernel-level driver install / firmware burn.** Out of scope
  for this skill. Route to
  [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)
  driver layer.
- **Climb back to `doca-rdma` for a use case `doca-rdma`
  actually covers.** Not a verb in this skill at all — that
  conversation belongs in
  [`doca-rdma TASKS.md ## configure`](../doca-rdma/TASKS.md#configure).
  This skill's job is to *recognize* when the climb-back is the
  right answer, then hand the conversation off.

## Command appendix

Every command below is **cross-cutting on DOCA RDMA Verbs** — it
answers a recurring class of question that comes up in the verbs
above. The agent should treat the *class* as load-bearing; the
worked example is a single instance. Run-as user is the
unprivileged user unless noted; sudo is called out per row.

**Infra-aware preamble (every row below).** Per the bundle's
detect → prefer → fall back → report contract documented in
[`doca-structured-tools-contract ## The agent behavior contract`](../../doca-structured-tools-contract/SKILL.md#the-agent-behavior-contract),
the agent should:

1. Probe for the matching structured helper FIRST (`doca-env --json`
   for version + devices + libraries + drivers in one shot;
   `doca-capability-snapshot` for per-device capability flags;
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
| `pkg-config --modversion doca-rdma-verbs` | [`## configure`](#configure) step 3; [`## build`](#build) slot 4 | What is the build-time raw-verbs version? | A semver string matching `pkg-config --modversion doca-rdma` AND `doca_caps --version`. Disagreement = verbs-only partial install (route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) layer 2) |
| `pkg-config --cflags --libs doca-rdma-verbs` | [`## build`](#build) | What include + link flags does the linker need? | Includes resolve under `/opt/mellanox/doca/infrastructure/include/`; libs include the verbs runtime plus `-ldoca-common`; should NOT auto-pull `-ldoca-rdma` |
| `ls /opt/mellanox/doca/samples/doca_rdma_verbs/` | [`## modify`](#modify) slot 1 | Which raw-verbs samples ship in this install, and which is the closest starting point? | A list of sample directories named after the QP / WR pattern they demonstrate |
| `doca_caps --list-devs` | [`## configure`](#configure) step 4 | Which devices on this host can be used as a `doca_dev`? | One row per visible device with PCIe address and capability flags; raw verbs needs at least one row, same as `doca-rdma` |
| `doca_caps --version` | [`## configure`](#configure) step 3; [`## test`](#test) step 2 | What is the *runtime* DOCA version on this host? | A semver string matching `pkg-config --modversion doca-rdma-verbs` |
| `cat /opt/mellanox/doca/applications/VERSION` | [`## configure`](#configure) step 3; [`## debug`](#debug) layer 1 | What does the install tree itself claim its version is? | A semver string matching the other two version sources |
| `dmesg | tail -n 40` (sudo) | [`## debug`](#debug) layer 7 | What did the kernel / driver log around the last raw-verbs call? | Empty or recent benign messages. Repeated mlx5 / IB errors → driver-layer bug; route to [`doca-setup ## debug`](../../doca-setup/TASKS.md#debug) |
| `ibv_devinfo` (sudo) | [`## configure`](#configure) step 4; [`## debug`](#debug) layer 7 | What does the underlying `libibverbs` see for this device? | One device row with `state: PORT_ACTIVE` and a sane MTU. **NOTE:** running `ibv_devinfo` is a diagnostic; it does NOT license the program to also call `ibv_*` against a `doca-rdma-verbs`-owned object (per the no-mixing rule in [CAPABILITIES.md ## Safety policy](CAPABILITIES.md#safety-policy)) |
| `DOCA_LOG_LEVEL=trace ./<binary>` | [`## run`](#run) step 3 | What did the structured DOCA logger emit for the first failing call? | A trace-level line on every lifecycle transition and every WR submission. Silence after submit = chosen completion-handling path not driven |

For commands shared across libraries (`pkg-config --modversion`,
`doca_caps`, `cat /opt/mellanox/doca/applications/VERSION`,
`DOCA_LOG_LEVEL`) the cross-library overlay is in
[`doca-debug TASKS.md ## Command appendix`](../../doca-debug/TASKS.md#command-appendix);
this table adds the raw-verbs-specific rows on top.
