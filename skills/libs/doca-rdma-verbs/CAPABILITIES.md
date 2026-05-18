# DOCA RDMA Verbs capabilities, version compatibility, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
raw-verbs CLASS patterns. Pick the pattern first, then drill into
the H2 that owns the substance. Every section in this file rests on
ONE invariant: **`doca-rdma-verbs` is a targeted escape hatch, not
a default.** If the user's case fits the higher-level
[`doca-rdma`](../doca-rdma/SKILL.md), that is the answer; the rest
of this file applies only after the drop-down decision in
[SKILL.md](SKILL.md) has been made.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For step-by-step workflows that *use* these
capabilities (configure, build, modify, run, test, debug) see
[TASKS.md](TASKS.md). For where the underlying public
documentation and installed package paths live, defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
do not duplicate URLs or install paths in this file.

## Pattern overview

Every raw-verbs question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
raw-verbs use case, not just the worked example shown.

| Raw-verbs pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Decide drop-down vs stay-up | The agent first re-checks whether [`doca-rdma`](../doca-rdma/SKILL.md) covers the case; only if it explicitly does not does the conversation continue here | [`## Capabilities and modes`](#capabilities-and-modes) doca-rdma-vs-doca-rdma-verbs table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Place the surface against libibverbs | The agent teaches that `doca-rdma-verbs` is *not* a synonym for libibverbs even though the object names rhyme; mixing handles across the boundary is unsupported | [`## Safety policy`](#safety-policy) no-mixing rule + [TASKS.md ## modify](TASKS.md#modify) porting block |
| 3. Bring the verbs context up inside DOCA Core | The agent walks `doca_dev` + `doca_pe` + PD / QP / CQ / MR creation in DOCA Core terms (not in libibverbs poll-CQ terms) | [`## Capabilities and modes`](#capabilities-and-modes) object-model section + [TASKS.md ## configure](TASKS.md#configure) |
| 4. Capability-query the specific verb / opcode / option | The user wanted raw verbs because some specific thing was missing upstairs — the agent must confirm that *specific* thing is supported here on the device, via `doca_rdma_verbs_cap_*` against the active `doca_devinfo` | [`## Capabilities and modes`](#capabilities-and-modes) cap-query rule + [TASKS.md ## configure](TASKS.md#configure) |
| 5. Observe what the HW actually did | Two valid surfaces: the DOCA progress engine (preferred, integrates with the rest of DOCA Core) OR manual completion-queue handling (when the raw-verbs case explicitly needed it); the agent picks one explicitly | [`## Observability`](#observability) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret a `DOCA_ERROR_*` from a raw-verbs call | Map the error to a layer (lifecycle / cap / permission / completion-status); the IO_FAILED case has its own overlay because the answer lives on the CQE, not on the submit return | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Smoke-before-scale.** Always start with one QP + one WR + one
  completion before adding any second QP, second connection, or
  second WR opcode. Raw verbs amplifies the cost of a hidden
  configuration bug; a single-shot smoke isolates the cause
  cleanly. The full eval-loop overlay is in
  [TASKS.md ## test](TASKS.md#test).
- **Discover the version-installed surface, do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-rdma-verbs`
  and on the `doca_rdma_verbs_cap_*` capability queries against
  the active `doca_devinfo`. Quoting a verb / opcode / QP option
  without checking is the most common hallucination failure mode
  for raw verbs.

## Capabilities and modes

DOCA RDMA Verbs is a **DOCA Core Context.** Every verbs context
follows the universal `cfg-create → cfg-set-* → init → start →
use → stop → destroy` lifecycle (see
[`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)).
On top of that lifecycle, the verbs surface layers an ibverbs-like
object model.

**doca-rdma vs doca-rdma-verbs — the load-bearing selection
table.** This is the table the agent walks BEFORE any code-level
discussion.

| Axis | doca-rdma (higher level) | doca-rdma-verbs (this skill) |
| --- | --- | --- |
| Default for | The vast majority of RDMA work — Send / Receive / Read / Write / Write-Imm / Atomic / Sync-Event tasks | The narrow case where `doca-rdma`'s task abstractions do not expose the specific verb / opcode / WR flag / QP option the user needs |
| Surface shape | Task-level (`doca_rdma_task_*`) — submit a task, get a completion event | Raw verbs primitives (QP / CQ / PD / MR) inside DOCA Core — closer to what libibverbs exposes, but inside the DOCA Core lifecycle |
| Completion handling | DOCA progress engine (`doca_pe_progress`), event per task | DOCA progress engine OR manual completion-queue handling, picked explicitly by the user |
| When the cap-query exists | `doca_rdma_cap_*` (per-task supported, per-transport supported, per-property max) | `doca_rdma_verbs_cap_*` (per-verb / per-opcode / per-WR-flag / per-QP-feature supported on this `doca_devinfo`) |
| Right answer for *"I want raw QP control"* | Often: doca-rdma's task abstractions cover the case once the user names the actual semantic | Sometimes: when the user has confirmed the higher level genuinely does not surface the option |
| Right answer for *"I want a higher-level task abstraction"* | Yes — this is the home | No — climb back up |

**Verbs object model inside DOCA Core.** The verbs primitives
(QP / CQ / PD / MR) have the same *conceptual* role as in
libibverbs, but they are created and torn down through the DOCA
Core lifecycle, not through libibverbs `ibv_*` calls. The exact
symbol names are install-bound; the agent must read them from the
verbs headers shipped on the user's install rather than quote them
from memory. The right symbol-lookup procedure is in
[TASKS.md ## configure](TASKS.md#configure) step 2.

**Capability discovery — the only rule.** Before assuming any verb,
opcode, WR flag, or QP feature is available, call the matching
`doca_rdma_verbs_cap_*` query against the active `doca_devinfo`.
This is even more important than at the `doca-rdma` level: the
raw-verbs surface exposes *more* knobs, of which *fewer* are
universally supported across devices and firmware. The agent must
not quote raw verbs feature support without naming the cap query
that established it. Per the cross-cutting rule in
[`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
the cap-query is the runtime authority — the public docs are the
*promise*, the cap-query is the *reality*.

**Configuration shape.** *Mandatory* before
`doca_ctx_start()` on a verbs context: at least one PD attached,
at least one QP created, the matching CQ(s), and the MR(s)
covering any memory the QP will read or write — all configured
through the `doca_rdma_verbs_*` setters appropriate for each
object. *Optional but commonly needed*: explicit transport-type
selection (IB / RoCE — same option set as `doca-rdma` per
[`doca-rdma CAPABILITIES.md ## Capabilities and modes`](../doca-rdma/CAPABILITIES.md#capabilities-and-modes));
queue depths; per-WR flag selection. Query the active value of
any setter with the matching `doca_rdma_verbs_cap_get_*` call.

**Climb back up to `doca-rdma`.** Raw verbs is a *targeted*
surface, not a long-term home. Once the specific need that drove
the drop-down is covered (the WR flag is set; the custom QP
attribute is honored; the legacy libibverbs port is integrated),
the agent should *explicitly* ask whether the user can move the
rest of the application back up to
[`doca-rdma`](../doca-rdma/SKILL.md). The maintenance cost of raw
verbs (capability-query density, manual completion handling,
no-mixing rule with libibverbs) is real; staying down at the verbs
level for work the higher-level library already covers is not free.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The raw-verbs-specific overlay** is:

- **`doca-rdma-verbs.pc` joins the four-way match.** On any host
  where both libraries are installed, the agent must verify
  `pkg-config --modversion doca-rdma-verbs`,
  `pkg-config --modversion doca-rdma`, and
  `pkg-config --modversion doca-common` all match
  `doca_caps --version`. A common partial-install pattern is that
  the user upgraded `doca-rdma-verbs` independently of the rest
  of DOCA; the cap-query at runtime can then return values the
  higher-level library does not honor. Route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before any verbs-layer diagnosis.
- **Use `doca_rdma_verbs_cap_*` at runtime, not at configure
  time alone.** Per the cross-cutting rule in
  [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
  the cap-query is the runtime authority for *"is this verb /
  opcode / WR flag / QP feature supported on this device + this
  DOCA version"*. For raw verbs the surface is wide enough that
  reading a feature off a doc page and skipping the cap-query is
  almost guaranteed to produce a runtime surprise.
- **Headers win over docs.** When the user reports *"the doc says
  this verb / opcode / flag is supported but the symbol isn't in
  my headers"*, the headers on the user's install
  (`/opt/mellanox/doca/infrastructure/include/`) are the
  authoritative truth for what the *built* library exposes. The
  agent must not assert a symbol exists without confirming it
  there — per the headers-win-over-docs rule in
  [`doca-version`](../../doca-version/SKILL.md).

## Error taxonomy

The cross-library `DOCA_ERROR_*` taxonomy (what each family means
and which debug layer it routes to) lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
The raw-verbs-specific overlay names the families the agent will
see most often from `doca_rdma_verbs_*` calls and what they
specifically indicate:

| Family | Most common verbs cause | First action |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Lifecycle violation in verbs terms — e.g., QP create called before PD attach; WR submit called before the QP transition the verbs surface requires; mmap / MR destroyed before context destroy | Walk the lifecycle in [`## Capabilities and modes`](#capabilities-and-modes) object-model section; confirm each step's preconditions BEFORE retrying |
| `DOCA_ERROR_NOT_SUPPORTED` | The verb / opcode / WR flag / QP feature the user requested is not on this device + firmware + DOCA version | Run the matching `doca_rdma_verbs_cap_*` against the active `doca_devinfo`; if false, that is the answer — climb back up to [`doca-rdma`](../doca-rdma/SKILL.md) if the higher-level surface covers a viable alternative |
| `DOCA_ERROR_INVALID_VALUE` | Bad WR flags / opcode / address-handle parameter / WR field that the runtime rejects at submit time | Re-check the user's WR construction against the headers; do not assume the libibverbs field layout transfers — this is one of the highest-frequency raw-verbs program bugs |
| `DOCA_ERROR_NOT_PERMITTED` | Missing privileges to open the device, register the MR, or transition the QP — usually a host-side env issue (RDMA stack module loads, user group, ulimits) | Route to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug) — the layer below the verbs API is the suspect |
| `DOCA_ERROR_IO_FAILED` | Work-request completed with error status. **The submit return is not the answer; the completion-queue entry is.** The agent MUST direct the user to inspect the CQE's error field for the specific cause | Drain the CQ (via `doca_pe_progress` if using the DOCA progress engine, or via the verbs surface's manual CQ poll); read the CQE error field verbatim; then map THAT to the next action |

The agent's rule: **never recommend a retry loop on
`DOCA_ERROR_*` from a verbs call without first identifying which
of the rows above is the cause**. Raw verbs amplifies the cost of
"retry until it works" — the retry can mask a configuration bug
that gets worse at scale.

Quote `doca_error_get_descr()` verbatim — do not paraphrase. The
cross-cutting debug ladder
([`doca-debug ## debug`](../../doca-debug/TASKS.md#debug)) is the
canonical layered diagnosis path that the agent escalates to once
the raw-verbs-specific cause has been narrowed.

## Observability

Raw verbs has **two valid completion-handling surfaces**, and the
agent's job is to make the choice explicit rather than let it
drift:

1. **DOCA progress engine (`doca_pe_progress`).** The same engine
   `doca-rdma` and every other DOCA Core context uses. Completions
   surface as events on the PE; the rest of the user's DOCA
   application keeps its single-PE loop. This is the recommended
   default for raw verbs unless the user has named a specific
   reason it does not fit.
2. **Manual completion-queue handling.** The raw-verbs surface
   exposes the CQ object directly; the user can poll it themselves
   in whatever loop they want. This is the right answer ONLY when
   the user's reason for dropping to raw verbs was *"I need custom
   CQ handling"* — otherwise the PE path is simpler and integrates
   with the rest of the user's DOCA application.

The agent must not silently mix the two on the same CQ in the same
program. *"Some completions go through the PE, others I poll
manually"* is unsupported and a source of dropped completions.

Three primary signals the agent should reach for:

1. **Per-WR completion entries.** Whether surfaced through the PE
   or polled manually, the CQE carries the work-request status.
   `DOCA_ERROR_IO_FAILED` is the indicator that *the submit
   succeeded but the completion reports an error* — the answer
   then lives in the CQE error field, not in the submit return.
2. **QP state transitions.** Raw verbs exposes the QP state
   machine directly; misordered transitions return
   `DOCA_ERROR_BAD_STATE`. A debugging session without
   confirmation of the QP's current state is blind to half the
   lifecycle.
3. **Capability snapshot at configure time.** The output of every
   `doca_rdma_verbs_cap_*` query is a snapshot of *what the
   library said was possible* before any WR was submitted. Save
   it as the baseline; if a WR later returns
   `DOCA_ERROR_NOT_SUPPORTED` the diff against this snapshot is
   the bug.

For cross-cutting observability primitives (`--sdk-log-level`, the
`doca-<lib>-trace` build flavor, the `DOCA_LOG_LEVEL` env var) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package layout)
defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

Raw verbs' safety surface centers on **one rule that has no
equivalent at the `doca-rdma` level**: **do not mix libibverbs
handles with `doca-rdma-verbs` handles on the same hardware
resources.** The two libraries look similar by intent — both
expose QP / CQ / PD / MR — but they are *different libraries*
operating against the same kernel uverbs interface from different
sides:

- `libibverbs` (`/usr/include/infiniband/verbs.h`) is the kernel
  uverbs userspace interface. It is NOT integrated with the DOCA
  Core lifecycle, the DOCA progress engine, the DOCA error model,
  or the DOCA device model (`doca_dev` / `doca_devinfo`).
- `doca-rdma-verbs` is the same conceptual surface BUT lives
  inside the DOCA Core model. The verbs objects it returns are
  managed through `doca_ctx_*` / `doca_pe_*`; the errors it
  returns are `DOCA_ERROR_*`; the device handle it consumes is
  `doca_dev`, not `ibv_context`.

Mixing the two — e.g., calling `ibv_modify_qp()` on a QP created
through `doca-rdma-verbs`, or passing a `doca_dev`-derived MR into
a libibverbs `ibv_post_send` — is unsupported. The visible
symptom can be silent (the call appears to succeed) and the
program then fails far from the line that mixed the boundary.
The agent's first response to *"can I keep my existing ibv_* code
next to new doca_rdma_verbs_* code on the same QP / CQ / PD /
MR?"* must be **no**. The right pattern is in
[TASKS.md ## modify](TASKS.md#modify) porting block: port the
libibverbs code over to `doca-rdma-verbs` handles, then run
purely through one library at a time.

Per the parent library: permissions and mmap-export rules are the
same as `doca-rdma`. The agent should not re-invent them here —
defer to
[`doca-rdma CAPABILITIES.md ## Safety policy`](../doca-rdma/CAPABILITIES.md#safety-policy)
for the matrix.

## Deferred topic boundaries

This skill scopes itself to the raw-verbs surface inside DOCA
Core. Adjacent topics the agent will get asked but should route
elsewhere:

- **General DOCA RDMA work (Send / Receive / Read / Write / Atomic
  task patterns).** Owned by
  [`doca-rdma`](../doca-rdma/SKILL.md). This skill exists *only*
  for cases the higher-level library does not cover.
- **General libibverbs programming** (raw ibverbs lifecycle, queue
  pair theory, memory-region semantics outside DOCA Core) —
  outside this skill. Route to the upstream RDMA / IB
  documentation; this skill assumes the user already understands
  the abstractions and is asking *how to express them inside the
  DOCA Core model*.
- **DOCA Core context and progress engine internals** — owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the Core context lifecycle; it does not
  redefine it.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the raw-verbs overlay, not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build / link
  / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug). This
  skill's `## debug` redirects there for layers 1-4 and layer 7;
  layers 5-6 carry the raw-verbs-specific overlay.
- **Cross-library `doca_caps` invocation patterns** — owned by
  [`doca-caps`](../../tools/doca-caps/SKILL.md). This skill
  references the *raw-verbs capability query family*
  (`doca_rdma_verbs_cap_*`), which is per-library; the
  *cross-library capability snapshot tool* is a separate surface
  routed there.
