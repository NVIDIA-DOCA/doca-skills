# DOCA DPA Verbs capabilities, version overlay, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
DPA-Verbs CLASS patterns. Pick the pattern first, then drill into
the H2 that owns the substance. Every section in this file rests on
TWO invariants: **`doca-dpa-verbs` is a targeted latency-tuning
escape hatch, not a default** (if the user's case fits host-side
[`doca-rdma`](../doca-rdma/SKILL.md), that is the answer), AND
**the QPs the DPA kernel posts on are configured by the host
through the parent [`doca-dpa`](../doca-dpa/SKILL.md), not by the
DPA-side code itself.** The rest of this file applies only after the
4-way-matrix decision in [SKILL.md](SKILL.md) has been made.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For step-by-step workflows that *use* these
capabilities (configure / build / modify / run / test / debug) see
[TASKS.md](TASKS.md). For where the underlying public documentation
and installed package paths live, defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
do not duplicate URLs or install paths in this file. For the host
side of every DPA setup this skill assumes (per-DPA-instance
context, loaded DPA application image, kernel launch, host-side
completion), defer to the parent [`doca-dpa`](../doca-dpa/SKILL.md);
this skill does not redefine that surface.

## Pattern overview

Every DPA-Verbs question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
DPA-Verbs use case, not just the worked example shown.

| Pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Navigate the 4-way matrix first | The agent re-walks the host-vs-DPA × high-level-vs-verbs decision and confirms the user belongs in this corner before continuing | [`## Capabilities and modes`](#capabilities-and-modes) matrix table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Confirm host round-trip is the actual bottleneck | The agent treats "do I need DPA-side RDMA" as a *measured-latency* question, not an intuition question; without a measured host bottleneck the right answer is host-side RDMA | [`## Safety policy`](#safety-policy) latency-bottleneck rule + [TASKS.md ## configure](TASKS.md#configure) step 2 |
| 3. Apply host-configures-QP / DPA-uses-QP | The agent teaches that QP setup lives on the host side via the parent `doca-dpa`; the DPA-side translation unit then posts WRs on those QPs via `doca_dpa_verbs_*` | [`## Capabilities and modes`](#capabilities-and-modes) coupling rule + [TASKS.md ## configure](TASKS.md#configure) steps 4-6 |
| 4. Cap-query the SPECIFIC DPA-side verb / opcode on the HOST before launch | The user wanted DPA-side verbs because some specific RDMA op is needed inside the kernel — the agent must confirm the *specific* op is supported here via the `doca_dpa_verbs_cap_*` family **on the host side before the kernel is launched**, not from inside the kernel | [`## Capabilities and modes`](#capabilities-and-modes) cap-query rule + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 5. Inspect a CQE that came from a DPA-side post | Completions for DPA-side WR posts are observed from the host (or surfaced into the DPA kernel via the parent's completion mechanism); the diagnostic flow crosses the host / DPA boundary | [`## Observability`](#observability) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret a `DOCA_ERROR_*` from a DPA-side verbs call | Map the error to a layer (lifecycle / cap / two-side-program signature / completion status); the IO_FAILED case has its own overlay because the answer lives on the host-side CQE, not on a DPA-side return value | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Smoke-before-scale.** Always start with one DPA kernel
  launch + one WR post + one completion observed end-to-end before
  adding a second QP, a second WR opcode, or a streaming-launch
  loop. The DPA-side verbs surface compounds the cost of a hidden
  configuration bug across two libraries (the parent `doca-dpa`
  setup AND this skill's DPA-side post), so the single-WR smoke is
  even more valuable than at the host-side `doca-rdma-verbs` level.
  The full eval-loop overlay is in [TASKS.md ## test](TASKS.md#test).
- **Discover the version-installed surface; do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-dpa-verbs`
  agreeing with `pkg-config --modversion doca-dpa` and on the
  `doca_dpa_verbs_cap_*` capability queries against the active
  `doca_devinfo` **executed from the host before kernel launch**.
  Quoting a DPA-side verb / opcode / WR flag without checking — or
  trying to cap-query from inside the kernel itself — is the most
  common hallucination failure mode for this surface.

## Capabilities and modes

DOCA DPA Verbs is the **DPA-side counterpart** of the host-side
DOCA Core context that the parent [`doca-dpa`](../doca-dpa/SKILL.md)
manages. Every DPA-Verbs use case follows the parent's universal
two-side-program model: the host side stands up the `doca_dpa`
context, loads the DPACC-compiled DPA application image, creates
DPA execution contexts, and configures the underlying RDMA QPs that
the DPA kernel will post against; the DPA side calls the
`doca_dpa_verbs_*` primitives from inside the kernel function body
to post WRs and (optionally) poll completions. On top of that two-
side model, the DPA-Verbs surface layers an ibverbs-like primitive
set that the *DPA processor* — not the host CPU — actually issues.

**The 4-way RDMA matrix — the load-bearing selection table.** This
is the table the agent walks BEFORE any code-level discussion.
Reproduced from [SKILL.md](SKILL.md#the-4-way-matrix-this-skill-exists-to-navigate)
because every downstream decision in this file resolves to a row of
it.

| Library | Execution side | Abstraction level | When it's the right answer |
| --- | --- | --- | --- |
| [`doca-rdma`](../doca-rdma/SKILL.md) | Host CPU | High-level tasks | Default for the vast majority of RDMA work; the host is the right execution side and the task abstractions cover the case |
| [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md) | Host CPU | Raw verbs | `doca-rdma` confirmed not to expose the specific verb / opcode / WR flag, but execution still belongs on the host |
| [`doca-dpa-comms`](../doca-dpa/SKILL.md) (DPA-side) | DPA processor | Local DPA-side messaging | The DPA kernel needs to coordinate locally (between DPA threads or with host-resident state); **not** RDMA |
| **`doca-dpa-verbs`** (this skill) | DPA processor | Raw verbs | Host round-trip is the measured latency bottleneck AND the DPA kernel needs RDMA semantics from inside the kernel body |

**Host-configures-QP / DPA-uses-QP — the coupling rule.** This is
the single non-negotiable invariant for everything below.

| Side | What it does | Owning library | Where the substance lives |
| --- | --- | --- | --- |
| Host side | Stands up `doca_dpa`; loads the DPA application image via DPACC; creates `doca_dpa_thread` execution contexts; **creates and configures the RDMA QP(s) the DPA kernel will post against**; attaches whatever per-launch `doca_dpa_completion` the kernel-launch model needs; runs the cap-query for every DPA-Verbs verb / opcode the kernel will use; launches the DPA kernel | [`doca-dpa`](../doca-dpa/SKILL.md) (parent) | All of `## Capabilities and modes` / `## Error taxonomy` / `## Observability` / `## Safety policy` in [`doca-dpa CAPABILITIES.md`](../doca-dpa/CAPABILITIES.md) |
| DPA side | The kernel function body (DPACC-compiled) calls `doca_dpa_verbs_*` primitives to post WRs (sends, RDMA reads, RDMA writes, atomics) on QP handles the host already configured; optionally polls completions inside the kernel via the matching DPA-side primitive | `doca-dpa-verbs` (this skill) | The rest of this file |

The agent's rule: when the user asks *"how do I create the QP from
my DPA kernel"*, that question has the model wrong. QPs are created
on the host side through the parent [`doca-dpa`](../doca-dpa/SKILL.md);
the DPA-side `doca_dpa_verbs_*` post primitives consume the QP
*handles* the host setup made available to the kernel. The
DPA-side translation unit does not own QP creation. Conflating the
two sides is the single most common DPA-Verbs first-app design
error.

**DPA-side primitive surface inside the kernel.** The DPA kernel
calls DPA-side primitives to *post* work requests on host-configured
QPs and (optionally) to *poll* completions. The exact symbol names
are install-bound; the agent must read them from the DPA-side
headers shipped on the user's install rather than quote them from
memory. The right symbol-lookup procedure is in
[TASKS.md ## configure](TASKS.md#configure) step 5.

| DPA-side primitive class | What it does | Coupling to host side |
| --- | --- | --- |
| WR-post (send, RDMA read, RDMA write, atomic) | The DPA kernel constructs a work request and posts it on a host-configured QP handle | The QP must already be configured (and transitioned through whatever state the underlying RDMA transport requires) by the host-side `doca-dpa` setup before the kernel is launched |
| Completion-poll | The DPA kernel reads completion entries inline if the user's pattern needs the kernel to react to its own completions; OR the host observes completions through the parent's host-side completion mechanism | Per-WR completion-status interpretation lives on whichever side reads the completion; CQE error fields surface through the same path |

**Capability discovery — the only rule.** Before assuming any DPA-side
verb, opcode, or WR flag is available on the user's hardware, **call
the matching `doca_dpa_verbs_cap_*` query from the host side, against
the active `doca_devinfo`, BEFORE the DPA kernel is launched.** The
cap-query family lives on the host because the BlueField generation
and the DOCA + DPACC install pair determine what the DPA hardware can
do; the DPA-side translation unit is in no position to refuse a verb
the hardware does not support. An agent that recommends a "cap-check
inside the DPA kernel" has the model wrong. Per the cross-cutting
rule in [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
the cap-query is the runtime authority — the public docs are the
*promise*, the cap-query is the *reality*.

**Configuration shape.** *Mandatory* preconditions before any
DPA-side `doca_dpa_verbs_*` WR post call inside the kernel: the
parent [`doca-dpa`](../doca-dpa/SKILL.md) setup is complete (the
`doca_dpa` is started, the DPA application image is loaded, the
`doca_dpa_thread` exists, the kernel was launched via
`doca_dpa_kernel_launch_update_*`); the underlying RDMA QP(s) the
kernel posts against were configured by the host side and are in a
state that accepts WRs; the host-side cap-query confirmed the
specific verb / opcode / WR flag the kernel uses; the DPA-side
kernel function signature matches the host launch arguments (per
the parent's two-side-program rule in
[`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes)).
*Optional but commonly needed*: per-WR completion attachment, batch
sizing for the DPA-side post loop, application-layer flags that
ride on top of the host-configured QP feature set.

**Climb back up to host-side RDMA.** DPA-side verbs is a *targeted
latency-tuning* surface, not a long-term home for RDMA in general.
Once the specific need that drove the drop into the DPA-side
verbs surface is covered (the RDMA op that needed the kernel-side
post is wired; the host-roundtrip latency win is measured), the
agent should *explicitly* ask whether the user can move the rest of
the RDMA work back up to host-side [`doca-rdma`](../doca-rdma/SKILL.md)
or [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md). The maintenance
cost of a DPA-side RDMA setup (two-side-program build, DPACC + DOCA
version pinning, cap-query density, host / DPA boundary debugging)
is real; staying on this surface for RDMA work that the host could
handle is not free.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way match
rule, NGC container semantics, and the headers-win-over-docs rule,
see [`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it. For the parent's DPA
overlay — that DOCA and the DPACC compiler must match per the DOCA
Compatibility Policy — see
[`doca-dpa CAPABILITIES.md ## Version compatibility`](../doca-dpa/CAPABILITIES.md#version-compatibility);
this skill inherits that overlay rather than re-deriving it.

**The DPA-Verbs-specific overlay** is:

- **`doca-dpa-verbs.pc` joins the match set alongside `doca-dpa.pc`.**
  On any host where the DPA-side verbs surface is in use, the agent
  must verify that `pkg-config --modversion doca-dpa-verbs`,
  `pkg-config --modversion doca-dpa`, and `pkg-config --modversion
  doca-common` all match `doca_caps --version`, AND that the
  installed `dpacc` is at a version the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html)
  lists as compatible. A common partial-install pattern is that
  the user upgraded `doca-dpa-verbs` (or DPACC) independently of
  the rest of DOCA; the kernel then fails at launch in ways that
  look like hardware bugs but are version-skew bugs. Route to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before any DPA-Verbs-layer diagnosis.
- **The DPA-side translation unit must be rebuilt by `dpacc`
  whenever the DPA-Verbs version moves.** Inherits the parent's *do
  not partial-rebuild one side* rule from
  [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy):
  rebuilding only the host side (or only the DPA side) when
  `doca-dpa-verbs` upgrades is the canonical way to introduce
  `DOCA_ERROR_DRIVER` at kernel launch. The agent must surface
  both versions explicitly and demand a paired rebuild.
- **Use `doca_dpa_verbs_cap_*` at runtime from the host side, not
  at configure time alone, and never from inside the kernel.** Per
  the cross-cutting rule in
  [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
  the cap-query is the runtime authority. The DPA-Verbs surface is
  install-bound enough that reading a verb / opcode off a doc page
  and skipping the host-side cap-query before kernel launch is
  almost guaranteed to produce a runtime surprise at the first
  `doca_dpa_kernel_launch_update_*` against a kernel that uses the
  unsupported verb.
- **Headers win over docs.** When the user reports *"the doc says
  this DPA-side verb / opcode / flag is supported but the symbol
  isn't in my DPA-side headers"*, the headers on the user's install
  (under `/opt/mellanox/doca/infrastructure/include/` for the
  host-visible header set; the DPA-side include path is what DPACC
  expects per the DPACC compiler guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md))
  are the authoritative truth for what the *built* surface exposes.
  The agent must not assert a symbol exists without confirming it
  there.

## Error taxonomy

DPA-Verbs-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the parent's host-side DPA overlay lives in
[`doca-dpa CAPABILITIES.md ## Error taxonomy`](../doca-dpa/CAPABILITIES.md#error-taxonomy);
the rows below are the *DPA-side verbs surface* meaning that the
agent must disambiguate before falling back to either of those
ladders.

| Error | DPA-Verbs context where it shows up | DPA-Verbs-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | A DPA-side `doca_dpa_verbs_*` post call that ran before the host-side QP was in a state that accepts WRs; OR the parent `doca_dpa` was not started before the kernel that calls the post was launched | Lifecycle violation that spans both sides. Walk the host-side preconditions per [`doca-dpa CAPABILITIES.md ## Capabilities and modes`](../doca-dpa/CAPABILITIES.md#capabilities-and-modes); confirm the QP the kernel posts against is in the WR-accepting state before retrying. The DPA side cannot manufacture readiness the host has not yet established |
| `DOCA_ERROR_NOT_SUPPORTED` | The host-side `doca_dpa_verbs_cap_*` query for the verb / opcode the kernel uses returned false; OR the host launched a kernel using a DPA-Verbs surface this BlueField generation does not expose | Run the matching `doca_dpa_verbs_cap_*` on the host against the active `doca_devinfo` BEFORE the kernel is launched; if false, that is the answer. The DPA hardware on this BlueField generation does not expose the verb. Climb back to host-side [`doca-rdma`](../doca-rdma/SKILL.md) if the higher-level surface covers a viable alternative on the host CPU |
| `DOCA_ERROR_INVALID_VALUE` | A DPA-side WR post with a bad QP handle (handle the kernel was not given), an oversized payload (past the host-configured QP's max message size), or a WR flag the host-configured QP does not support | The DPA kernel constructed a WR whose shape the host-configured QP cannot honor. Re-check the host-side QP configuration AND the DPA-side WR construction together — this is one of the highest-frequency two-side-program bugs. Rebuild the DPA-side image via `dpacc` if the WR construction changed in the kernel source, and re-link the host executable that embeds it per the parent's [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy) *do not partial-rebuild one side* rule |
| `DOCA_ERROR_IO_FAILED` | A DPA-side WR completed with error status. **The DPA-side post return is not the answer; the host-side (or kernel-side, depending on the user's completion topology) CQE is.** The agent MUST direct the user to inspect the CQE error field for the specific cause | Drain the relevant CQ; read the CQE error field verbatim; then map THAT to the next action. For host-observed completions this is the same shape as the host-side `doca-rdma-verbs` IO_FAILED case — see [`doca-rdma-verbs CAPABILITIES.md ## Error taxonomy`](../doca-rdma-verbs/CAPABILITIES.md#error-taxonomy) for the parallel guidance |
| `DOCA_ERROR_DRIVER` | Reported at host-side kernel launch or at host-side CQE drain after a DPA-side WR post; most often DOCA + DPACC version skew or a `doca-dpa-verbs` install that drifted from the rest of DOCA | Same as the parent's DPA overlay: capture `pkg-config --modversion doca-dpa-verbs`, `pkg-config --modversion doca-dpa`, the installed `dpacc` version, and `doca_caps --version`; cross-check against the DOCA Compatibility Policy. Route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug) AND to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug) layer 5 (driver) |

The agent's rule: **never recommend a retry loop on `DOCA_ERROR_*`
from a DPA-side post without first identifying which of the rows
above is the cause**. DPA-Verbs amplifies the cost of "retry until
it works" — the retry can mask a two-side-program signature bug
that gets dramatically worse under load.

Quote `doca_error_get_descr()` output verbatim — do not paraphrase
— and remember the descriptor for a DPA-side post error is read on
whichever side surfaced the error (host on launch / CQE drain; DPA
inside the kernel if the user's pattern reads completions there).
The cross-cutting debug ladder
([`doca-debug ## debug`](../../doca-debug/TASKS.md#debug)) is the
canonical layered diagnosis path the agent escalates to once the
DPA-Verbs-specific cause has been narrowed.

## Observability

DPA-Verbs observability is **two-sided like the parent, but
specifically split around the CQE**:

1. **Host-side completion / CQE inspection.** The CQE for a DPA-side
   WR post is most commonly read on the *host* side, through whatever
   completion surface the parent's `doca_dpa_completion` and the
   underlying RDMA QP expose to the host. This is the right
   default — the host already has the full DOCA debug surface, and
   a DPA kernel hung mid-post produces no CQE at all (which is
   itself a signal). When `DOCA_ERROR_IO_FAILED` surfaces on the
   host after a DPA-side post, the CQE error field is the answer;
   the DPA-side return value is not.
2. **In-kernel completion polling on the DPA side.** When the user's
   pattern requires the kernel to react to its own completions
   (e.g. the kernel posts an RDMA read, polls until the read
   completes, then operates on the fetched buffer all inside one
   kernel invocation), the DPA-side completion-poll primitive is the
   surface. The agent must pick one of the two completion surfaces
   explicitly per use case; mixing them on the same CQ — some
   completions surfaced to the host, others polled inside the
   kernel — is the same anti-pattern as the host-side mixed-CQ
   pattern in
   [`doca-rdma-verbs CAPABILITIES.md ## Observability`](../doca-rdma-verbs/CAPABILITIES.md#observability)
   and produces dropped completions.

Three primary signals the agent should reach for:

1. **The CQE that came from the DPA-side post.** Whether surfaced
   to the host or read in the kernel, the CQE carries the
   work-request status. `DOCA_ERROR_IO_FAILED` is the indicator
   that *the WR submitted but the completion reports an error* —
   the answer lives in the CQE error field, not in the DPA-side
   post return.
2. **The host-side capability snapshot at configure time.** The
   output of every `doca_dpa_verbs_cap_*` query run from the host
   before kernel launch is a snapshot of *what the library + the
   hardware + the DPACC compiler said was possible* before the
   kernel posted any WR. Save it; if a runtime CQE later reports
   `NOT_SUPPORTED`-like status the diff against this snapshot is
   the bug.
3. **DPA-side developer tools (the DPA debugger, the DPA
   process-state inspector, the DPA statistics tool).** When the
   host-side completion never arrives and the host side is healthy,
   the DPA-side kernel is running but stuck — possibly mid-WR-post.
   The public *DPA Tools* umbrella (routed via the parent's
   [`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability)
   and via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md))
   names the tools. The agent's job is to NAME the existence of
   these tools and route the user there; the per-tool surface is
   out of scope for this skill.

For cross-cutting observability primitives (`--sdk-log-level`, the
`DOCA_LOG_LEVEL` env var, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the host-side DPA completion mechanism this skill rides on, see
[`doca-dpa CAPABILITIES.md ## Observability`](../doca-dpa/CAPABILITIES.md#observability).

## Safety policy

DPA-Verbs' safety surface is **bottleneck-evidence-driven AND
two-side-program-driven**. The two most common DPA-Verbs first-app
failures are (1) the user is on this skill because they assumed the
host round-trip was the bottleneck without measuring (so the
latency win never materializes and they paid the two-side-program
maintenance cost for nothing) and (2) the host-side QP configuration
and the DPA-side WR construction disagree because one side was
rebuilt while the other was not. The agent's job is to verify both
before any DPA-side WR post, not after the first
`DOCA_ERROR_INVALID_VALUE` or `DOCA_ERROR_DRIVER`.

The **safety matrix** the agent must walk for any new DPA-Verbs
setup:

| Precondition | What must be true | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| Host round-trip is the measured bottleneck | The user has data (a profile, a latency histogram, or at minimum a back-of-envelope per-op cost) showing the host CPU round-trip dominates the per-RDMA-op latency for this workload | Ask the user for the measurement; if absent, ask them to take it before continuing. A guess does not count | If host roundtrip is NOT the bottleneck, the right answer is host-side [`doca-rdma`](../doca-rdma/SKILL.md) / [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md); do **not** continue here |
| Parent [`doca-dpa`](../doca-dpa/SKILL.md) is in scope and adopted | The user is already running a host-side `doca-dpa` setup with a loaded DPA application image (or is committed to standing one up); the DPA-side translation unit is the one DPACC will compile | The parent's env-precondition matrix in [`doca-dpa CAPABILITIES.md ## Safety policy`](../doca-dpa/CAPABILITIES.md#safety-policy); the agent demands `pkg-config --modversion doca-dpa` BEFORE `pkg-config --modversion doca-dpa-verbs` | The parent skill; not a code change in the DPA-side translation unit |
| `doca-dpa-verbs` and `doca-dpa` versions match `doca-common` and `doca_caps --version` | `pkg-config --modversion` agrees across all of `doca-dpa-verbs`, `doca-dpa`, and `doca-common`, AND with `doca_caps --version`, AND with the installed `dpacc` per the DOCA Compatibility Policy | The four-way match check from [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility) extended with the DPA-Verbs row | [`doca-setup`](../../doca-setup/SKILL.md) for the install-side; route to [`doca-version`](../../doca-version/SKILL.md) for the version-side |
| Host-configures-QP / DPA-uses-QP coupling is consistent | The host-side QP configuration (transport, max message size, feature flags, transitioned state) actually supports the WR shape the DPA-side kernel posts | Walk both sides together: the host-side `doca-dpa` QP setup AND the DPA-side WR construction in the kernel source. Re-run the host-side `doca_dpa_verbs_cap_*` for the specific verb the kernel uses | Coordinated edit across both sides; per the *do not partial-rebuild one side* rule, rebuild the DPA-side image via `dpacc` AND the host executable that embeds it |
| Single-WR-post smoke succeeded before scaling | One DPA kernel launch, one DPA-side WR post (e.g. an RDMA read of a small buffer), one completion observed (host-side or kernel-side per the picked surface) before any streaming or multi-thread design | Walk the smoke step in [TASKS.md ## test](TASKS.md#test) step 1; a smoke that fails identifies *two-side-program* or *cap-query* gaps cheaply, before any scaled design pays the cost | Diagnose the smoke failure first; do NOT scale a broken smoke into a high-throughput DPA-side RDMA design |

**Do not invent a "DPA-side QP create."** The DPA-side translation
unit cannot create or configure the RDMA QPs it posts against — the
host side does that via the parent [`doca-dpa`](../doca-dpa/SKILL.md)
setup. An agent that proposes a DPA-side QP-create call has the
model wrong. If the user's *natural* mental model is "DPA owns the
QP", that itself is a routing signal: confirm the user's compute
shape and route them through the parent skill's configure workflow
before any DPA-side code is written.

**Do not partial-rebuild one side.** Inherits the parent's rule.
Rebuilding only the host (DOCA upgrade, host re-link) while the
DPA-side image was built by an old DPACC, or rebuilding only the
DPA side without re-linking the host executable that embeds it,
produces non-obvious DPA-Verbs failures: the host launch may
succeed at submit and the DPA-side post may then fail with
`DOCA_ERROR_DRIVER` or silently corrupt the WR construction. The
fix is to rebuild both sides against matched DOCA + DPACC versions,
not to silence the error.

## Deferred topic boundaries

This skill scopes itself to the **DPA-side verbs surface** beneath
the parent `doca-dpa`. Adjacent topics the agent will get asked but
should route elsewhere:

- **Host-side DPA lifecycle, kernel launch, host-side completion,
  per-DPA-instance context, loaded DPA application image, DPA
  execution context.** Owned by [`doca-dpa`](../doca-dpa/SKILL.md).
  This skill *uses* the host-side setup; it does not redefine it.
- **DPA-side `doca-dpa-comms`** (local DPA-side messaging primitives
  the DPA kernel itself calls; not RDMA). Different DPA-side
  library, with its own pkg-config module and its own public
  guide. Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public [DOCA DPA Comms guide](https://docs.nvidia.com/doca/sdk/DOCA-DPA-Comms/index.html).
  Conflating it with `doca-dpa-verbs` is a common DPA-side library-
  selection error.
- **Host-side RDMA in general (Send / Receive / Read / Write /
  Atomic task patterns).** Owned by [`doca-rdma`](../doca-rdma/SKILL.md).
  This skill is the DPA-side counterpart and exists *only* when
  the host execution side is genuinely the wrong place; if it isn't,
  climb back to host-side RDMA.
- **Host-side raw verbs.** Owned by
  [`doca-rdma-verbs`](../doca-rdma-verbs/SKILL.md). Same raw-verbs
  shape, different execution side; pick on the host-vs-DPA axis,
  not on the "I want verbs" trigger word alone.
- **DPA-side kernel programming itself** (how to write the function
  body the DPA processor runs; DPA-side memory model; DPA-side
  allocation; intrinsics) — owned by the public *DOCA DPA*
  programming guide and the *DPACC* compiler guide, both routed via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  and named for context in the parent
  [`doca-dpa`](../doca-dpa/SKILL.md).
- **DPACC compiler internals.** Out of scope. Route to the public
  *DOCA DPACC Compiler* guide via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **DPA developer tools** (the DPA debugger, the DPA process-state
  inspector, the DPA statistics tool) — named in
  [`## Observability`](#observability) for routing, but the
  per-tool surface lives in the public *DPA Tools* umbrella via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
- **DOCA Core context and progress engine internals** — owned by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the host-side Core lifecycle (through the
  parent); it does not redefine it.
- **Cross-cutting `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the DPA-Verbs overlay, not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build / link /
  runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug). This
  skill's `## debug` redirects there for layers 1-4; layers 5-7
  carry the DPA-Verbs-specific overlay.
- **GPU-initiated RDMA from a CUDA kernel** — a separate
  *DOCA-into-a-non-CPU-target* path (CUDA on an NVIDIA GPU, not
  the DPA on a BlueField). The sibling
  [`doca-gpunetio`](../doca-gpunetio/SKILL.md) covers the GPU side;
  the two skills share the *DOCA-into-target-processor* shape
  (paired-library setup, cap-query before launch, smoke-before-scale,
  two-side-program rebuild) but differ in target processor, kernel
  toolchain, and the network surface available inside the in-target
  code. The agent should treat them as siblings, not synonyms.
