# DOCA STA capabilities, version overlay, errors, observability, safety

**Where to start:** Pick the H2 anchor that matches your question
(integration boundary / queue-pair shape / transport types /
capabilities / errors / safety) and read that section end-to-end.
The tables in each section are the load-bearing content; the prose
around them is interpretation.

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For the *how* of executing each pattern (the
verbs `configure / build / modify / run / test / debug`), jump to
[TASKS.md](TASKS.md). For the canonical DOCA version-handling
rules that this skill layers a STA overlay on top of, see
[`doca-version`](../../doca-version/SKILL.md). For the RDMA
substrate that NVMe-over-RDMA transport lands on, see
[`doca-rdma`](../../doca-rdma/SKILL.md). For the steering side
that decides which NVMe-oF packets land on which STA-managed
queue, defer to [`doca-flow`](../../doca-flow/SKILL.md).

## Pattern overview

Every DOCA STA question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
NVMe-over-Fabrics deployment shape (initiator vs target,
NVMe-over-RDMA vs NVMe-over-TCP, single-connection smoke vs
multi-tenant fan-out), not just the worked example shown.

| Pattern | When it applies (class shape) | Where the substance lives |
| --- | --- | --- |
| 1. Identify the integration boundary | Decide which layer the user owns (NVMe semantics in SPDK or kernel-nvme) and which layer doca-sta owns (transport handshake + per-IO encapsulation/decapsulation); doca-sta is *not* a complete NVMe stack | [`## Capabilities and modes`](#capabilities-and-modes) integration-boundary table + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 2. Stand up the `doca_sta` context | DOCA Core lifecycle: create → configure (transport type, queue-pair sizing, NVMe-oF feature opt-ins) → start → use → stop → destroy, on the underlying `doca_dev` | [TASKS.md ## configure](TASKS.md#configure) + [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes) for the universal lifecycle |
| 3. Pick the transport type | NVMe-over-RDMA (substrate: `doca-rdma`) vs NVMe-over-TCP; cap-query against the active `doca_devinfo` is the only authority on what this device supports | [`## Capabilities and modes`](#capabilities-and-modes) transport-type table + [TASKS.md ## configure](TASKS.md#configure) step 3 |
| 4. Shape the NVMe queue pair | One admin queue plus N I/O queues per NVMe-oF connection; size N (number of I/O queues), the depth per queue, and the in-flight IO budget against what the device cap reports | [`## Capabilities and modes`](#capabilities-and-modes) queue-pair table + [TASKS.md ## configure](TASKS.md#configure) step 4 |
| 5. Honor substrate and steering preconditions | NVMe-over-RDMA needs `doca-rdma` discoverable and the RDMA cap surface non-empty on the chosen device; NVMe-oF traffic only reaches the STA-managed queues when DOCA Flow rules (or the env-side equivalent) steer it there | [`## Safety policy`](#safety-policy) precondition matrix + [TASKS.md ## configure](TASKS.md#configure) step 1 |
| 6. Diagnose a STA error | Map symptom (`DOCA_ERROR_BAD_STATE`, `_NOT_SUPPORTED`, `_INVALID_VALUE`, `_AGAIN`, `_IO_FAILED`, `_NOT_PERMITTED`) to root cause without leaving the STA layer prematurely | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **doca-sta is the transport layer, not a full NVMe stack.** The
  user's NVMe initiator or target logic still runs above doca-sta —
  typically in SPDK, sometimes in the kernel `nvme` stack. Doca-sta
  accelerates the transport handshake, queue-pair establishment,
  and per-IO transport overhead; it does not implement NVMe admin
  commands, namespace management, or block-device semantics. An
  agent that recommends doca-sta as a *replacement* for SPDK or
  kernel-nvme is misleading the user.
- **Discover the version-installed surface, do not assume.** Every
  pattern above gates on `pkg-config --modversion doca-sta` and on
  the `doca_sta_cap_*` capability queries against the active
  `doca_devinfo`. Quoting a transport type, an I/O queue depth, or
  an NVMe-oF feature-set value without checking is the most common
  hallucination failure mode.

## Capabilities and modes

DOCA STA is a **DOCA Core context**. Every STA instance follows
the universal `cfg-create → cfg-set-* → init → start → use → stop
→ destroy` lifecycle (see
[`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes)).
On top of that lifecycle, STA layers an NVMe-oF integration
boundary, a transport-type selection, and a queue-pair shape.

**Integration boundary — what doca-sta owns vs what the consumer
owns.** The single most important framing the agent should
surface before any code:

| Layer | Owner | What lives here |
| --- | --- | --- |
| NVMe protocol semantics (admin commands, namespaces, block I/O semantics, controller state machine) | The user's NVMe stack — typically SPDK on the BlueField Arm or host, sometimes the kernel `nvme` stack | All NVMe spec behavior; `doca-sta` does NOT re-implement this |
| NVMe-oF transport (per-connection queue establishment, per-IO encapsulation/decapsulation onto RDMA or TCP, transport-layer flow control) | `doca-sta` on the BlueField hardware path | The `doca_sta` context, the per-connection NVMe queue pair, the transport-type selection |
| Underlying RDMA / TCP substrate | `doca-rdma` (for NVMe-over-RDMA) or the device's TCP path (for NVMe-over-TCP), driven by doca-sta on the consumer's behalf | The verbs / TCP socket primitives the consumer should NOT call directly through STA |
| Steering of NVMe-oF packets to the right STA-managed queue | `doca-flow` (or the env-side equivalent) | The Flow rules that match NVMe-oF 5-tuples and steer them; doca-sta does NOT program steering itself |

**Sides — initiator vs target.** STA is symmetric in the sense
that it can be configured on either side of an NVMe-oF
connection. The lifecycle and queue-pair shape are the same on
both sides; what differs is the application logic on top
(initiator: SPDK `bdev_nvme` consumer or kernel `nvme` host;
target: SPDK `nvmf_tgt` or kernel `nvmet`). The agent must
confirm which side the user is building before recommending
configure-time choices — getting it wrong silently inverts the
queue-pair handshake direction.

**Transport-type selection.** Two transports are the documented
options; cap-query against the active `doca_devinfo` is the only
authority on what this device supports.

| Transport | Substrate | Right shape for | Wrong shape for |
| --- | --- | --- | --- |
| NVMe-over-RDMA | `doca-rdma` (RoCE on Ethernet, or InfiniBand) | Line-rate NVMe-oF in a data center with an RDMA-capable fabric end-to-end; the lowest CPU overhead per IO | Fabrics where RDMA is not deployed end-to-end, or where the peer is a kernel `nvme` host without RDMA configured |
| NVMe-over-TCP | The device's TCP path | Mixed fabrics where RDMA is unavailable; broader peer compatibility (any NVMe-over-TCP host / target) | Workloads that need the absolute lowest CPU overhead and the fabric supports RDMA — pick NVMe-over-RDMA there |

The agent's rule: **never recommend a transport without naming
the cap query.** Run `doca_sta_cap_*` against the active
`doca_devinfo` for each transport the user is considering;
quote the queried result. Do not assume from the docs page.

**NVMe queue-pair shape.** Each NVMe-oF *connection* (initiator
↔ target pair) carries:

| Queue | Count per connection | What it carries |
| --- | --- | --- |
| Admin queue | exactly 1 | NVMe admin commands (Identify, Set/Get Features, Connect, Discovery, …) plus the NVMe-oF Connect handshake itself |
| I/O queue | configurable, up to the device cap | NVMe Read / Write / Flush / Dataset Management I/O commands |

Sizing inputs (each gates on the matching cap query):

| Sizing input | Cap-query class | Why the agent must ask |
| --- | --- | --- |
| Number of I/O queues per connection | `doca_sta_cap_*` for max number of I/O queues on this device | Oversize fails at start; under-size leaves throughput on the floor |
| I/O queue depth | `doca_sta_cap_*` for max I/O queue depth | Per-queue depth is device-bound; assuming 1024 works everywhere is wrong |
| Max in-flight IOs per queue | `doca_sta_cap_*` for max in-flight IOs per queue | Submitting past the in-flight budget returns `DOCA_ERROR_AGAIN` at runtime |
| NVMe-oF feature opt-ins (Discovery, In-Capsule Data, …) | `doca_sta_cap_*` for the supported NVMe-oF feature set | Opting in to a feature the device does not advertise fails at configure time, not at runtime |

The agent SHOULD NOT quote specific symbol names for the
`doca_sta_cap_*` family from memory — the exact spelling is
install-bound and varies across DOCA versions. Tell the user to
read the `doca_sta_cap_*` query family in the headers shipped on
their install (`/opt/mellanox/doca/infrastructure/include/doca_sta*.h`)
or in the public DOCA STA guide reachable via
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
do not invent spellings.

**Configuration shape.** *Mandatory* configurations before
`doca_ctx_start()`: the underlying `doca_dev` opened against a
device that advertises STA capability; the chosen transport
type set against the matching `doca_sta_set_*` setter; the I/O
queue count and depth at or below the device cap. *Optional*
configurations (NVMe-oF feature opt-ins, advanced flow-tag
fields) gate on the matching `doca_sta_cap_*` query and use the
matching `doca_sta_set_*` setter.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The STA-specific overlay** is:

- **Transport-type availability and `doca_sta_cap_*` are the
  runtime authority, not the public docs.** Per the cross-cutting
  cap-query rule in
  [`doca-version CAPABILITIES.md ## Observability`](../../doca-version/CAPABILITIES.md#observability),
  the agent must call the matching `doca_sta_cap_*` query against
  the active `doca_devinfo` before promising the user that
  NVMe-over-RDMA or NVMe-over-TCP is on this device + DOCA
  version; the NVMe-oF feature set likewise gates on the
  matching `doca_sta_cap_*` query. Quoting a transport or feature
  from memory is the canonical hallucination failure mode for
  this library.
- **`doca-sta.pc` and `doca-common.pc` must both match
  `doca_caps --version`** at the four-way-match check (per
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)).
  Use `pkg-config --modversion doca-sta` as the build-time
  anchor; disagreement with `doca_caps --version` is a
  partial-install hazard and must be routed to
  [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
  layer 2 before any STA-layer diagnosis.
- **Substrate-library version match.** When the user picks
  NVMe-over-RDMA, `doca-rdma.pc` must also match the same
  `doca_caps --version` line — a STA install that compiles
  against one DOCA RDMA major and runs against another is a
  partial-install hazard. Route to
  [`doca-rdma CAPABILITIES.md ## Version compatibility`](../../doca-rdma/CAPABILITIES.md#version-compatibility)
  for the RDMA-side overlay.

## Error taxonomy

STA-specific overlays on the cross-library `DOCA_ERROR_*`
taxonomy. The cross-library taxonomy itself lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy);
the rows below are the *STA surface* meaning that the agent
must disambiguate before falling back to the cross-library
response.

| Error | DOCA STA context where it shows up | STA-specific cause |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | Any call after `doca_ctx_stop()` or before `doca_ctx_start()`; submitting an I/O on a queue pair that has not completed the NVMe-oF Connect handshake; reconfiguring transport type after start | Lifecycle violation on either the `doca_sta` context itself or the per-connection queue-pair state machine. Walk the call sequence against the universal lifecycle in [`doca-programming-guide CAPABILITIES.md ## Capabilities and modes`](../../doca-programming-guide/CAPABILITIES.md#capabilities-and-modes); the most common case is submitting before the queue-pair reports CONNECTED. |
| `DOCA_ERROR_NOT_SUPPORTED` | Setting a transport type the device does not advertise; opting in to an NVMe-oF feature the device does not advertise; oversized I/O queue count or depth | Re-run the matching `doca_sta_cap_*` query against the active `doca_devinfo`; if the cap query says false (or returns a smaller cap), that is the answer — the user's device or DOCA version does not support the request. |
| `DOCA_ERROR_INVALID_VALUE` | `doca_sta_set_*` with a queue depth, queue count, or transport parameter outside the device cap; queue-pair config that mismatches the peer's advertised limits | The fix is to re-read the cap, lower the requested value, and re-run configure. Quote the queried cap value, not a value the user remembered. |
| `DOCA_ERROR_AGAIN` | I/O submission on a per-queue path when the in-flight budget is full | The I/O queue is full. This is *not* a hardware error; the program must drain completions via `doca_pe_progress()` before re-submitting, or raise the queue depth and in-flight budget within the device cap. Same as the cross-library *"would-block, retry after progress"* pattern. |
| `DOCA_ERROR_IO_FAILED` | Per-IO completion event reports failure; transport-layer error during the NVMe-oF Connect handshake | A transport-layer I/O error. Likely causes: link drop, RDMA peer disconnect, TCP reset, firmware fault, peer-side controller reset. Do not retry blindly — capture `dmesg | tail` and route to [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug) and to [`doca-rdma CAPABILITIES.md ## Error taxonomy`](../../doca-rdma/CAPABILITIES.md#error-taxonomy) (for NVMe-over-RDMA) before recommending a code change. |
| `DOCA_ERROR_NOT_PERMITTED` | `doca_dev_open` for a device the user has no access to; STA context create after a permission downgrade | The device was not opened with the required access. Confirm sudo or the appropriate group membership per [`## Safety policy`](#safety-policy); do not modify the program. |
| `DOCA_ERROR_DRIVER` | Any submit / completion call | The layer below DOCA reported failure. Capture state (`dmesg | tail`, `mlxconfig -d <pcie> q`) and route to env-class debug ([`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug)) — the layer below DOCA is the suspect, not the program. |

The agent's rule: **never recommend a retry loop on `DOCA_ERROR_*`
without first identifying which of the rows above is the cause**.
`_AGAIN` is the only one that wants a retry (after
`doca_pe_progress()`); the others want investigation, not retry.
And *"the connection won't establish"* is **rarely** a `_BAD_STATE`
on the STA side — it is more often a steering / fabric / peer
issue and the agent should walk the precondition matrix in
[`## Safety policy`](#safety-policy) before any code change.

## Observability

The DOCA Core progress engine (PE) is the single source of
observability for STA: every queue-pair state transition and
every I/O completion (success or failure) arrives as an event on
the PE that the `doca_sta` context is registered against. STA
does **not** maintain per-connection counters of its own; its
observability surface is event-driven, with one add-on signal
(capability snapshot at configure time).

Three primary signals the agent should reach for:

1. **Per-queue I/O completion events on the PE.** Each submitted
   I/O produces a completion event when it finishes (or errors)
   on the matching queue. The completion carries the
   `doca_error_t` if it failed; the agent must inspect the
   per-IO completion, not the submit-call return value alone.
   Absence of completions on a queue with submitted IOs is
   *always* either a missing `doca_pe_progress()` call or a
   transport-layer stall; route to [`## Error taxonomy`](#error-taxonomy)
   `_AGAIN` / `_IO_FAILED` rows.
2. **Queue-pair state transitions.** The NVMe-oF queue pair
   transitions from CREATED → CONNECTED (after the NVMe-oF
   Connect handshake) → DISCONNECTED. The agent must wire and
   inspect the transition events; submitting an I/O before
   CONNECTED returns `DOCA_ERROR_BAD_STATE`, and a session that
   *seems up* but never moves past CREATED is a fabric or
   peer-side problem, not a STA bug.
3. **Capability snapshot at configure time.** The output of
   every `doca_sta_cap_*` query is a snapshot of *what the
   library said was possible* before any I/O was submitted.
   Save it as the baseline; if an I/O later returns
   `DOCA_ERROR_NOT_SUPPORTED` or `_INVALID_VALUE` the diff
   against this snapshot is the bug.

For the cross-cutting debug-time observability primitives
(`DOCA_LOG_LEVEL=trace`, `--sdk-log-level`, the trace build
flavor) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the env-side observability primitives (link state, RDMA
device enumeration) defer to
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).

## Safety policy

DOCA STA's safety surface is **substrate-library presence,
device access, and steering**. The single most common first-app
failure for an NVMe-over-RDMA initiator is *"my Connect
handshake never completes"* — and the agent's job is to verify
the three preconditions before any code change, not after the
first `DOCA_ERROR_*`.

The **precondition matrix** the agent must walk for any new
DOCA STA setup:

| Precondition | What must be true before `doca_ctx_start()` | How the agent verifies | Where to fix |
| --- | --- | --- | --- |
| Substrate library present | For NVMe-over-RDMA: `doca-rdma.pc` resolves and `doca_rdma_cap_*` reports a non-empty surface on the chosen device. For NVMe-over-TCP: the device's TCP path is enabled in firmware | `pkg-config --modversion doca-rdma`; the matching cap-query call as documented in [`doca-rdma CAPABILITIES.md ## Capabilities and modes`](../../doca-rdma/CAPABILITIES.md#capabilities-and-modes); `mlxconfig -d <pcie> q` for the firmware view | [`doca-setup`](../../doca-setup/SKILL.md) for the env-side; do not modify the program |
| Device access | The `doca_dev` was opened against a BlueField PF / SF the user has permission to use (typically requires sudo or the appropriate group membership) | `id` for group membership; the open call failing with `DOCA_ERROR_NOT_PERMITTED` is the runtime symptom | [`doca-setup`](../../doca-setup/SKILL.md) for the env-side; do not modify the program |
| NVMe-oF traffic actually reaches the STA-managed queue | Either a DOCA Flow rule (or the env-side equivalent) steers matching NVMe-oF 5-tuples to this STA instance's queues | Inspect the Flow rule programmed for this NVMe-oF connection (or the absence of one); confirm via the steering-rule listing on the user's setup | [`doca-flow`](../../doca-flow/SKILL.md) for the steering side; do not invent a `doca_sta_*` steering call |

**The integration point with SPDK or kernel-nvme is named, not
implemented here.** The agent must surface — early in any
recommendation — that doca-sta is the transport layer underneath
the user's NVMe stack, not a replacement for it. SPDK is the
canonical companion (the `nvmf` target stack and the `bdev_nvme`
initiator both expose transport-provider plug-points where
doca-sta lands); kernel-nvme is the alternative for users who
want the host-OS NVMe stack to do its normal work and offload
only the transport. The skill does NOT prescribe which path to
pick — that's the user's deployment decision — but it must
ensure the user knows the boundary exists.

**Smoke before scale-up.** Before driving production workloads,
the agent must walk the user through a single-IO smoke (one NVMe
admin command — typically Identify Controller — over the admin
queue, then one NVMe Read / Write I/O over a single I/O queue).
A failure here narrows cleanly: admin-queue side, fabric, or
I/O-queue side. A failure at production scale *without* the
single-IO smoke pass is a much harder bisection.
