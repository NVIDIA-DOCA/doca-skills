# DOCA UROM capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(paired-contract model / per-`doca_urom`-instance context /
enqueue-side operation surface / capability discovery / env
preconditions / errors) and read that section end-to-end. The
tables in each section are the load-bearing content; the prose
around them is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern
(the verbs `configure / build / modify / run / test / debug`),
jump to [TASKS.md](TASKS.md). For the canonical DOCA
version-handling rules that this skill layers a UROM overlay on
top of, see [`doca-version`](../../doca-version/SKILL.md). For
the RDMA transport substrate UROM rides on top of, see
[`doca-rdma`](../doca-rdma/SKILL.md).

## Pattern overview

Every UROM question this skill teaches resolves into one of SIX
patterns. The patterns are CLASSES — they apply across every
DOCA UROM release and every host + BlueField + UROM Service
combination.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Walk the paired-contract model first | Every UROM deployment has TWO components (host-side `doca-urom` library + DPU-side DOCA UROM Service); the host enqueues, the DPU executes; both must be present at compatible versions before the first enqueue | [`## Capabilities and modes`](#capabilities-and-modes) paired-contract table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Create the per-`doca_urom`-instance Core context | One `doca_urom` Core context per BlueField the host is offloading remote memory operations to; standard DOCA Core lifecycle on the host side | [`## Capabilities and modes`](#capabilities-and-modes) per-instance-context rule + [TASKS.md ## configure](TASKS.md#configure) step 4 |
| 3. Enqueue the right operation kind | Pick by *direction* and *semantics*: put / get (one-sided data movement) vs atomic (compare-swap, fetch-add) vs active message vs collective primitive (the family above one-sided data movement, used by MPI / UCX stacks for all-to-all, all-reduce, …) — exact operation symbol names are install-bound and must be read from the headers, not quoted from memory | [`## Capabilities and modes`](#capabilities-and-modes) operation-shape table + [TASKS.md ## modify](TASKS.md#modify) |
| 4. Honor env preconditions: DPU-side UROM Service running, RDMA substrate healthy, versions matched | The library cannot offload to a service that is not running; the BlueField cannot move bytes without the RDMA transport substrate; host library + DPU service versions must agree per the DOCA Compatibility Policy | [`## Safety policy`](#safety-policy) env-precondition matrix + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 5. Choose `doca-urom` only when host-CPU offload is actually the goal | Simple point-to-point RDMA stays on `doca-rdma`; non-MPI / non-UCX stacks may not benefit; UROM adds the DPU-offload contract that is only worth its overhead when host CPU is the bottleneck | [`## Capabilities and modes`](#capabilities-and-modes) path-selection rule + [`## Deferred topic boundaries`](#deferred-topic-boundaries) |
| 6. Diagnose a UROM error | Map `DOCA_ERROR_NOT_SUPPORTED` / `_NOT_PERMITTED` / `_INVALID_VALUE` / `_BAD_STATE` / `_IO_FAILED` / `_AGAIN` to root cause without leaving the UROM layer prematurely | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **The paired-contract model is non-negotiable.** Every UROM
  deployment is two components: the host-side library (this
  skill, `doca-urom`) that ENQUEUES offloaded operations AND
  the DPU-side DOCA UROM Service that EXECUTES them. An agent
  that treats the host side as self-sufficient — for example by
  walking the user from `doca_urom_*` calls directly into
  on-wire behavior without checking the DPU-side service is
  even running — has the model wrong for every version of
  UROM. A library call that succeeds at the host-side API
  surface but has no service to offload to fails at the first
  enqueue, often with a `DOCA_ERROR_NOT_PERMITTED` that masks
  the real cause.
- **Discover the version-installed + service-installed
  surface, do not assume.** Every pattern above gates on
  `pkg-config --modversion doca-urom` (host-side build-time),
  `doca_urom_cap_*` queries against the active `doca_devinfo`
  (host-side runtime), AND the DPU-side UROM Service's version
  reachable from the host. Quoting an operation type, an
  atomic op, or a collective primitive without checking those
  three is the most common hallucination failure mode for
  UROM. Exact symbol names for the operation surface are
  install-bound and must be read from the headers under
  $(pkg-config --variable=includedir doca-common) and from the
  shipped samples under
  `/opt/mellanox/doca/samples/doca_urom/`, not quoted from
  memory.

## Capabilities and modes

The two orthogonal selection axes for any UROM design from the
host side are *which BlueField the host is offloading to*
(`doca_urom` per `doca_dev` mapping to a BlueField running the
DOCA UROM Service) and *which operation kind* the HPC / UCX /
MPI stack on top wants offloaded (one-sided data movement,
atomic, active message, collective primitive). Choose both
before writing any host-side enqueue code, then drill into the
relevant capability-query.

**Paired-contract model — the host library and the DPU
service.**

| Side | What runs there | Artifact | What this skill covers |
| --- | --- | --- | --- |
| Host side | C / C++ (or any language that can FFI a C library) using `doca-urom` to enqueue remote memory operations, integrated into the user's HPC / UCX / MPI stack on the host | `doca-urom` library (this skill); `pkg-config doca-urom` is the canonical build-time anchor | All of `## Capabilities and modes` / `## Error taxonomy` / `## Observability` / `## Safety policy` below |
| DPU side | The DOCA UROM Service — a long-running daemon / container on the BlueField Arm side that receives the host's enqueued operations and EXECUTES them against the remote-side memory and RDMA fabric, freeing the host CPU | DOCA UROM Service — a SEPARATE artifact with its own public guide reachable through [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services) | This skill NAMES the service and routes to its guide; it does NOT redefine the service surface or its deployment / operation. A `doca-urom` host program with no UROM Service running on the DPU side fails at the first enqueue |

The agent's rule: when the user asks *"how do I deploy / start /
stop / scale the DOCA UROM Service on my BlueField"*, that is
the DPU-side service question and the right artifact is the
public *DOCA UROM Service* guide via
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
When the user asks *"how do I enqueue an operation from my host
code and observe its completion"*, that is this skill's scope.
Two distinct artifacts; two distinct surfaces.

**Path selection — `doca-urom` vs raw `doca-rdma` vs neither.**
Before any `doca-urom` setup, the agent must confirm UROM is
even the right path:

| User intent | Right artifact | Why this skill is / isn't it |
| --- | --- | --- |
| Simple point-to-point RDMA between two endpoints; host CPU is not the bottleneck | `doca-rdma` directly (this skill is the WRONG path) — UROM adds a DPU-side service contract whose overhead isn't worth it for a single-pair / small / simple data movement case | `doca-urom` makes sense only when the host CPU's cost of posting RDMA work is itself the bottleneck (HPC collectives, repeated all-to-all / all-reduce, dense MPI patterns) — not for one-shot send / recv |
| HPC / MPI / UCX workload where host CPU spends a lot of cycles on communication and you want the BlueField to take over | `doca-urom` (this skill), with the DPU-side UROM Service deployed and running | This is the canonical UROM use case: the host frees its CPUs for compute and the BlueField DPU does the communication work via its on-DPU RDMA + offload pipeline |
| Non-MPI, non-UCX networking stack; host CPU is not heavily loaded on communication | None of this skill — UROM offers no benefit and adds operational complexity. Stay on whatever transport the user's stack already uses; route to [`doca-rdma`](../doca-rdma/SKILL.md) if RDMA is in play | UROM's HPC / collective shape is its load-bearing benefit; stacks that don't issue those patterns get the overhead without the upside |

**The per-`doca_urom`-instance Core context — one per BlueField
the host is offloading to.**

| Object | Lifetime | What it owns | Key calls |
| --- | --- | --- | --- |
| `doca_urom` | Per BlueField the host is offloading remote memory operations to; created against a `doca_dev` that maps to a UROM-capable BlueField actually running the DOCA UROM Service | The DOCA-side bookkeeping for that UROM instance, the registration of memory descriptors, and the host-side completion / progress surface for operations enqueued through this instance | `doca_urom` create / configure / start / stop / destroy (DOCA Core lifecycle); `doca_urom_cap_*` for what this device + this DOCA install + this UROM Service version actually supports |

A host driving UROM toward more than one BlueField needs one
`doca_urom` per target BlueField — there is no *"global UROM
context"*. The agent must ask which BlueField (which
`doca_dev`, mapping to which physical BlueField actually
running the UROM Service) the user intends to offload to before
recommending any `doca_urom_*` call.

**Enqueue-side operation surface — generic shape; exact symbols
are install-bound.** The host-side library exposes primitives
for enqueueing remote memory operations and active messages onto
the DPU; the loaded UROM Service on the DPU side actually
executes them. The agent must NAME the operation families and
route to the headers + samples for exact symbol names — quoting
specific operation function names from memory is the most common
hallucination failure mode for UROM.

| Operation family | Direction / semantics | Right shape for | Notes for the agent |
| --- | --- | --- | --- |
| Put / Get (one-sided data movement) | One-sided remote memory write / read; same family of operation that `doca-rdma` Write / Read implements but enqueued through the UROM contract so the BlueField DPU posts the underlying RDMA work, not the host CPU | MPI / UCX windows; bulk data movement where the host CPU otherwise spends cycles posting verbs | Per-operation memory descriptor + remote handle + payload size are the agent-visible inputs; exact `doca_urom_*` symbol must be read from the headers |
| Atomic (compare-and-swap, fetch-and-add) | One-sided atomic; same family of operation that `doca-rdma` Atomic ops implement but DPU-offloaded | MPI atomic windows; lock-free distributed data structures | Device-conditional per row; not every BlueField + DOCA + UROM Service combo supports every atomic — the `doca_urom_cap_*` query is the only authoritative answer |
| Active message | The host-side enqueue carries a payload and a remote-side handler identifier; the DPU executes the matching handler on the remote side | UCX active messages; control-plane messages alongside the data plane within the same UROM context | Service-side handler registration is part of the DPU service surface and is reachable via the public *DOCA UROM Service* guide; the agent must not invent handler-registration symbols on the host side |
| Collective primitive (all-to-all, all-reduce, broadcast, …) | Many-to-many remote memory operations expressed as a single host-side enqueue that the DPU expands into the underlying per-pair RDMA traffic | MPI collectives; UCX-based collective offload | Service-side capability — not every UROM Service version supports every collective. The agent must NAME the family and route to the cap query, not quote which collective is on this install from memory |

The agent's rule: when the user asks *"what is the exact
function name for a UROM put / atomic / collective"*, the
authoritative answer is the header under
$(pkg-config --variable=includedir doca-common) and the shipped
sample under `/opt/mellanox/doca/samples/doca_urom/` on the
user's install, NOT this skill or agent memory.

**Capability discovery — the only rule.** Before enqueueing any
operation, call the matching `doca_urom_cap_*` query against
the active `doca_devinfo`:

| Capability axis | Query family | Why the agent must ask |
| --- | --- | --- |
| Operation family supported | `doca_urom_cap_*` against the active `doca_devinfo`; the per-family `_is_supported` shape | Operation-family support is per-device + per-DOCA + per-UROM-Service-version; do not assume put / get / atomic / collective family is universally available |
| Atomic operation variants | `doca_urom_cap_*` for the specific atomic op (compare-swap, fetch-add, …) | Atomic op support is device-conditional; an atomic that the docs claim exists may not be supported on this BlueField + firmware |
| Collective primitive variants | `doca_urom_cap_*` for the specific collective (all-to-all, all-reduce, broadcast, …) | Service-side variant — newer UROM Service versions add collectives that older ones do not have; quoting which is on this install from memory is the failure mode |
| Maximum payload / queue sizing | `doca_urom_cap_get_*` against the active `doca_devinfo` | Used to size enqueue queue depth and per-operation payload limits; the `AGAIN` (queue-full) error rate at runtime is proportional to undersized queues |

**Configuration shape.** *Mandatory* preconditions before any
`doca_ctx_start()` on the `doca_urom`: the DPU-side UROM
Service is deployed and running on the BlueField the host
intends to offload to; the `doca_urom` Core context is created
against a `doca_dev` that maps to that BlueField; the user /
process can open that `doca_dev`; the `doca_urom_cap_*` queries
agree the operation family the user intends to enqueue is
supported on this combo. *Optional* configurations (per-context
queue sizing, transport-type knobs inherited from the RDMA
substrate) ride on top of the same cap-query rule.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The
body lives there; this skill does not duplicate it.

**The UROM-specific overlay** is:

- **The host-side library version and the DPU-side UROM Service version must agree per the DOCA Compatibility Policy.** This is the paired-contract version axis the agent must ALWAYS surface: a host-side `doca-urom` upgraded without the DPU-side UROM Service being upgraded (or vice versa) fails at the first enqueue, often with `DOCA_ERROR_NOT_SUPPORTED` for an operation family that DOES exist on one side but not the other. Surface BOTH `pkg-config --modversion doca-urom` on the host AND the DPU-side service version (per the public *DOCA UROM Service* guide via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services)); cross-check them against the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html). Per the cross-cutting cap-query rule in [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability), the `doca_urom_cap_*` query against the active `doca_devinfo` is the runtime authority for *"is this operation family supported on this hardware + this DOCA install + this UROM Service"*, and the four-way-match check (`doca-urom.pc` + `doca-common.pc` + `doca_caps --version`) per [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility) catches the *host upgraded but service didn't* partial-install pattern before it surfaces as a runtime failure.

## Error taxonomy

UROM-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *UROM surface* meaning that the agent
must disambiguate before falling back to the cross-library
response.

| Error | UROM context where it shows up | UROM-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Any `doca_urom_*` call before `doca_ctx_start()` or after `doca_ctx_stop()`; enqueue called before the context is healthy | Lifecycle violation. Walk the call sequence against the universal Core lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the most common case is enqueueing before the context has finished starting or progressing the PE. |
| `DOCA_ERROR_NOT_SUPPORTED` | `doca_urom_cap_*` family; first enqueue of a specific operation family / atomic / collective | The operation kind is not supported on this device + this DOCA install + this UROM Service version. Run the matching `doca_urom_cap_*` against the active `doca_devinfo`; surface BOTH the host-side library version AND the DPU-side service version, because mismatch on either side can produce this error. If the cap query agrees the op is not supported, that is the answer — do not paper over with a retry. |
| `DOCA_ERROR_INVALID_VALUE` | Enqueue with a bad memory descriptor, mismatched remote handle, or oversized payload | The user's memory descriptor (local buffer, remote handle, length, offset) does not validate. Re-check that the local buffer was registered correctly, the remote handle came from the matching peer's export step, and the payload size fits within the `doca_urom_cap_get_*` maximum for this operation family. Do not retry; fix the descriptor. |
| `DOCA_ERROR_NOT_PERMITTED` | `doca_urom` create / start; first enqueue | Either the standard `doca_dev` access is missing (the user / process cannot open the target `doca_dev` — same baseline as every other DOCA library), OR — and this is the UROM-specific case the agent MUST surface — the DPU-side UROM Service is not deployed and running on the target BlueField (or it is running but at a version the host library cannot pair with). The two look identical at the `doca-urom` API surface; the fix is different. `doca_dev` access is a host-OS / group-membership fix per [`doca-setup ## Safety policy`](../../doca-setup/CAPABILITIES.md#safety-policy); the DPU-side service-not-running case is a service-side fix via the public *DOCA UROM Service* guide reachable through [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services). The agent must check the DPU-side service state BEFORE concluding "this is a host-OS permission problem". |
| `DOCA_ERROR_IO_FAILED` | Any enqueue / completion call | The underlying RDMA transport substrate UROM rides on top of has reported failure. UROM does NOT replace RDMA — it offloads the *posting* of RDMA work onto the BlueField DPU. A failing RDMA fabric (link down, RoCE / IB config skew, routing issue between nodes) surfaces as `DOCA_ERROR_IO_FAILED` at the UROM API. Route to [`doca-rdma ## debug`](../doca-rdma/TASKS.md#debug) for the substrate-layer diagnosis BEFORE assuming the UROM library or service is at fault. |
| `DOCA_ERROR_AGAIN` | Enqueue when the per-context enqueue queue is full | This is *not* a hardware error; the program must drain completions via `doca_pe_progress()` before re-submitting. Same as the cross-library *"would-block, retry after progress"* pattern; the fix is to size the queue larger via the matching `doca_urom_set_*` at configure time OR to drain more aggressively on the host loop. |

The agent's rule: **never recommend a retry loop on
`DOCA_ERROR_*` without first identifying which of the rows
above is the cause**. `_AGAIN` is the only one that wants a
retry (after `doca_pe_progress()`); the others want
investigation — service-side, lifecycle, version-axis, RDMA
substrate, or memory descriptor — not retry.

## Observability

UROM observability surface is **two-sided**: there is a
host-side observability surface (operation completions on the
DOCA progress engine, the DOCA logger, capability snapshots
from `doca_urom_cap_*`) AND an infrastructure-side
observability surface (the DPU-side UROM Service's own
observability documented in the public *DOCA UROM Service*
guide via
[`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services),
plus the underlying RDMA substrate counters documented in
[`doca-rdma CAPABILITIES.md ## Observability`](../doca-rdma/CAPABILITIES.md#observability)).
The agent must reach for both, not just one — a UROM enqueue
that returns `DOCA_SUCCESS` on the host side but produces no
visible remote-side effect is almost always visible on one of
the infrastructure-side surfaces.

Three primary signals the agent should reach for:

1. **Per-operation completion events on the DOCA progress
   engine.** Every enqueued operation produces a completion
   event when it finishes (or errors) — the completion carries
   the `doca_error_t` if it failed. The host must inspect the
   per-operation completion, not just the return value of the
   enqueue call. *Submitted but no completion* is almost
   always either a missing `doca_pe_progress()` call in the
   host loop OR a DPU-side service that has stopped processing
   enqueues (route to the public service guide).
2. **Capability snapshot at configure time.** The output of
   every `doca_urom_cap_*` query against the active
   `doca_devinfo`, together with `pkg-config --modversion
   doca-urom` on the host and the DPU-side UROM Service
   version, is the baseline of *"what the library + the
   hardware + the DPU service said was possible"* before any
   enqueue. Save it; if an enqueue later returns
   `DOCA_ERROR_NOT_SUPPORTED` the diff against this baseline is
   the bug.
3. **Infrastructure-side: DPU service observability + RDMA
   substrate counters.** When the host-side surface shows
   operations completing cleanly but the user reports the
   remote-side memory does not have the expected bytes, the
   right diagnostic is the DPU-side UROM Service's own
   observability (reach via the public service guide through
   [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services))
   PLUS the underlying RDMA counters (per
   [`doca-rdma CAPABILITIES.md ## Observability`](../doca-rdma/CAPABILITIES.md#observability)).
   The agent must NAME the existence of both surfaces and route
   the user there; the per-surface details belong in their
   owning skills / guides.

For cross-cutting observability primitives (`--sdk-log-level`,
the `DOCA_LOG_LEVEL` env var, the trace build flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package
layout, sample tree) defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

UROM's safety surface is **env-precondition-driven AND
paired-contract-driven AND RDMA-substrate-driven**. The three
most common UROM first-app failures are (1) the DPU-side UROM
Service is not deployed and running on the BlueField the host
is enqueueing to; (2) the host-side library and the DPU-side
service are at versions the DOCA Compatibility Policy does not
support pairing; (3) the underlying RDMA fabric between host
and BlueField (or between BlueFields, for multi-node HPC) is
not healthy. The agent's job is to verify all three before any
host-side `doca_urom_*` enqueue, not after the first
`DOCA_ERROR_*`.

The **env-precondition matrix** the agent must walk for any new
host-side UROM setup:

| Precondition | What must be true | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| DOCA UROM Service deployed and running on the target BlueField | The DPU-side service is present on the BlueField, started, and reachable from the host through the DOCA contract — the host library cannot offload to a service that is not there | Per the public *DOCA UROM Service* guide via [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services); the agent must NAME this precondition explicitly even though the exact service health check sits in the service guide. A `doca_urom` create succeeding while the first enqueue returns `DOCA_ERROR_NOT_PERMITTED` strongly suggests the service is missing | The public *DOCA UROM Service* guide; this is **not** a host-side code fix |
| Host library and DPU service versions agree | `pkg-config --modversion doca-urom` on the host AND the DPU-side service version are at versions the DOCA Compatibility Policy lists as compatible | `pkg-config --modversion doca-urom`; the DPU-side service version per the public service guide; cross-check against the [DOCA Compatibility Policy](https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html). Same overlay [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility) documents at the four-way-match check | [`doca-setup`](../../doca-setup/SKILL.md) for the install-side; route to [`doca-version`](../../doca-version/SKILL.md) for the four-way-match check |
| Underlying RDMA transport is healthy | UROM rides on top of `doca-rdma` (or the matching RDMA / RoCE / IB substrate the BlueField is configured for); the underlying fabric must be up before UROM can offload anything | Per [`doca-rdma TASKS.md ## configure`](../doca-rdma/TASKS.md#configure); the agent must NAME RDMA as the substrate explicitly, because a failing RDMA fabric will surface as `DOCA_ERROR_IO_FAILED` at the UROM API and the user will incorrectly attribute it to UROM | [`doca-rdma ## debug`](../doca-rdma/TASKS.md#debug) for the substrate-layer fix; do **not** attempt to mask RDMA-layer failures inside the host UROM program |
| Standard DOCA `doca_dev` access | The user / process can open the target `doca_dev` for the BlueField — same baseline DOCA access rule as every other DOCA library; typically requires sudo or membership in the host's standard mlnx-style group | The DOCA `doca_dev` enumeration succeeds for the target device; if it does not, that is an env-side problem | [`doca-setup`](../../doca-setup/SKILL.md) for the env-side; do **not** modify the program |
| Capability for the operation family agreed at configure time | The `doca_urom_cap_*` query against the active `doca_devinfo` agrees the operation family / atomic / collective the user intends to enqueue is supported on this BlueField + DOCA install + UROM Service version | Walk the cap query in [`## Capabilities and modes`](#capabilities-and-modes); save the result as the baseline | Diagnose the gap (device too old / DOCA too old / UROM Service too old / op family genuinely unsupported), not paper over with a retry |
| Single small smoke succeeded before scaling to collectives | One put + one get round-trip between two nodes succeeds and the completion event fires on the host-side PE, BEFORE the user attempts a full collective pattern (all-to-all, all-reduce) | Walk the smoke step in [TASKS.md ## test](TASKS.md#test) step 1; a smoke that fails identifies *service-side*, *RDMA-substrate*, *version-axis*, or *memory-descriptor* gaps cheaply, before any HPC stack integration effort is wasted | Diagnose the smoke failure first; do NOT scale a broken smoke into a full collective pattern |

**Do not invent a "host-CPU fallback" for UROM.** UROM's entire
reason to exist is to remove host-CPU work from the
communication path. If the DPU-side UROM Service is not running
or is at the wrong version, the right answer is to fix that —
NOT to silently fall back to raw `doca-rdma` posted from the
host CPU. A fallback that masks the missing service produces an
HPC stack whose offload claims are silently wrong; the agent
must surface the service-side gap, not paper over it.

**Lifecycle ordering is UROM-aware.** The `doca_urom` Core
context follows the universal DOCA Core teardown order on top
of the `doca_dev`. Out-of-order teardown surfaces as
`DOCA_ERROR_BAD_STATE` on subsequent calls and may leave
DPU-side resources (memory registrations, completion queues)
half-released that the next `doca_urom` create on the same
device then has to recover from. The agent must surface this
ordering explicitly.

**This skill does not define an HPC algorithm.** `doca-urom`
*offloads* remote memory operations; it does not implement an
MPI collective, a UCX active message handler, or any
particular HPC stack algorithm. When the user asks *"what
all-reduce algorithm should I use"* or *"how do I implement my
collective"*, the agent must refuse to invent an algorithm and
must route the user to the upstream MPI / UCX documentation
and to the user's own HPC domain expertise.

## Deferred topic boundaries

This skill scopes itself to the **host-side** `doca-urom`
library for HPC / UCX / MPI workloads offloading remote memory
operations to the BlueField DPU. Adjacent topics the agent will
get asked but should route elsewhere:

- **DOCA UROM Service deployment and operation on the DPU
  side** — a SEPARATE artifact with its own public guide; route
  via
  [`doca-public-knowledge-map ## DOCA services`](../../doca-public-knowledge-map/SKILL.md#doca-services).
  Conflating the library and the service is the single most
  common UROM first-app design error: the agent must NAME the
  split explicitly whenever the question straddles the two.
- **MPI / UCX / HPC collective algorithm design itself** — out
  of scope. Route to the upstream MPI / UCX documentation; this
  skill assumes the user has the algorithmic shape they want
  and is asking *how to express the underlying remote memory
  operations through UROM*.
- **Setting up the RDMA / RoCE / IB transport substrate UROM
  rides on top of** — owned by
  [`doca-rdma`](../doca-rdma/SKILL.md). UROM *uses* the RDMA
  substrate; it does not stand it up. A UROM deployment over a
  broken RDMA fabric is a substrate problem, not a UROM bug.
- **DOCA Core context and progress engine internals** — owned
  by
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
  This skill *uses* the Core lifecycle; it does not redefine
  it.
- **Cross-library `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the UROM overlay, not the taxonomy itself.
- **Cross-cutting debug ladder** (install / version / build /
  link / runtime / program / driver) — owned by
  [`doca-debug ## debug`](../../doca-debug/TASKS.md#debug).
  This skill's `## debug` redirects there for layer 1-4 and
  layer 7; layers 5-6 carry the UROM-specific overlay
  (including the DPU-side-service-not-running route and the
  RDMA-substrate route).
- **Cross-library `doca_caps` invocation patterns** — owned by
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
  This skill references the *UROM capability query family*
  (`doca_urom_cap_*`), which is per-library; the cross-library
  capability snapshot tool (`doca_caps --list-devs`) is a
  separate surface routed via the public knowledge map.
