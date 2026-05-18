# DOCA GPI capabilities, version compatibility, errors, observability, safety

**Where to start:** The pattern overview below names the recurring
GPI-class patterns. Pick the pattern first, then drill into the H2
that owns the substance. For the *how* of executing each pattern,
jump to [TASKS.md](TASKS.md).

Read this file when the loader sent you here from
[SKILL.md](SKILL.md). For step-by-step workflows that *use* these
capabilities (install, configure, build, modify, run, test, debug,
use) see [TASKS.md](TASKS.md). For where the underlying public
documentation and installed package paths live, defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) — do
not duplicate URLs or install paths in this file.

## Pattern overview

Every GPI-class question this skill teaches resolves into one of
SIX patterns. The patterns are CLASSES — they apply across every
GPU-initiated RDMA use case, not just the worked example shown.

| GPI pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick `doca-gpi` vs `doca-gpunetio` | Decide *before* writing any code whether the CUDA kernel drives an RDMA queue directly (channel/queue level — GPI) or sends / receives at the Ethernet-shaped Send/Receive layer (GPU NetIO) | [`## Capabilities and modes`](#capabilities-and-modes) surface-selection table |
| 2. Stand up the GPI context | DOCA Core lifecycle: create on a `doca_dev` → configure sizing via `doca_gpi_set_*` and bind memory regions → start on the GPU datapath → retrieve channel + GPU handles → use → stop → destroy | [TASKS.md ## configure](TASKS.md#configure) |
| 3. Bind an RDMA queue from `doca-rdma` | The GPI channel owns the *GPU-side wiring*; the underlying RDMA queue is created and connected via `doca-rdma`. The bridge is `doca_gpi_channel_get_rdma_queue_descriptor` / `doca_gpi_channel_connect_rdma_queue` | [`## Capabilities and modes`](#capabilities-and-modes) RDMA-queue-binding bullet + [TASKS.md ## configure](TASKS.md#configure) |
| 4. Hand off to the CUDA kernel | `doca_gpi_channel_get_gpu_handle` returns a `doca_gpu_gpi_channel*` the CUDA kernel uses directly; the host releases ownership and the device-side path is then GPU-driven | [`## Capabilities and modes`](#capabilities-and-modes) GPU-handoff bullet + [TASKS.md ## run](TASKS.md#run) |
| 5. Discover sizing limits before committing | `doca_gpi_cap_get_max_channel_num`, `doca_gpi_cap_get_max_rdma_queue_per_channel_num`, `doca_gpi_cap_get_max_rdma_queue_size` are the runtime authority for what the device allows | [`## Capabilities and modes`](#capabilities-and-modes) capability-query rule + [TASKS.md ## configure](TASKS.md#configure) |
| 6. Interpret a `DOCA_ERROR_*` from a GPI call | Map the error to a layer (configuration / lifecycle / GPU datapath assignment / CUDA-version / verbs below / driver) and route | [`## Error taxonomy`](#error-taxonomy) GPI overlay + [TASKS.md ## debug](TASKS.md#debug) |

Two cross-cutting rules that apply to *every* pattern above:

- **Sizing flows through the cap query, not from agent memory.**
  Every `doca_gpi_set_*` (channel count, RDMA queue count, RDMA
  queue size, GPU queue size) is gated by the matching
  `doca_gpi_cap_get_*` against the active device. Quoting a
  number without checking is the most common hallucination
  failure mode.
- **The GPU datapath must be assigned before `doca_ctx_start()`.**
  The public headers' `DOCA_ERROR_BAD_STATE` documentation on
  the channel / set / get-handle calls names the failure mode
  explicitly: *"if called before calling ctx_start(), or if not
  assigned to gpu datapath"*. The agent walks the user through
  the GPU datapath assignment (owned by
  [`doca-gpunetio`](../doca-gpunetio/SKILL.md)) *before* start,
  not after.

## Capabilities and modes

DOCA GPI is the **GPU-Packet-Initiator** surface: a CUDA kernel
running on an NVIDIA GPU drives RDMA work directly against the
BlueField / ConnectX device's queues, with no host CPU on the
data path. The host-side library configures a GPI context, a set
of channels, and per-channel RDMA queues; the GPU-side handle
then lets the CUDA kernel issue work.

### `doca-gpi` vs `doca-gpunetio`

Two GPU-side surfaces ship in DOCA. They are NOT interchangeable;
pick one before writing any code:

| Library | Surface shape | When to pick |
| --- | --- | --- |
| [`doca-gpunetio`](../doca-gpunetio/SKILL.md) | Higher-level Send/Receive-shaped Ethernet I/O for CUDA kernels; richer per-packet API; the canonical surface for GPU-side packet processing | The CUDA kernel sends or receives Ethernet packets through a queue and the application is happy with the Send/Receive abstraction |
| `doca-gpi` (this skill) | Lower-level channel + queue surface; the CUDA kernel drives RDMA queues *directly* via the GPU-side channel handle; binds an underlying `doca-rdma` queue via `doca_gpi_channel_connect_rdma_queue` | The CUDA kernel needs to initiate RDMA operations and the application wants direct control over the per-queue work request submission rather than the Send/Receive abstraction |

**Decision rule for the agent.** If the user's intent is *"my
CUDA kernel needs to drive an RDMA queue directly from GPU
memory, without the Send/Receive abstraction in between"*, GPI
is the right surface. If the user's intent is *"my CUDA kernel
sends or receives Ethernet packets"*, GPU NetIO is the right
surface. Both can coexist in one application; the agent does not
force one when the other fits better.

### The GPI context

`doca_gpi` is the top-level GPI object. Verified surface
(`doca_gpi.h`):

| Lifecycle phase | Calls | Note |
| --- | --- | --- |
| Create | `doca_gpi_create(dev, &gpi)` (DOCA_STABLE) | Created on a `doca_dev`; the GPI binds to that device for its lifetime |
| Configure (sizing) | `doca_gpi_set_channel_num(gpi, N)`, `doca_gpi_set_rdma_queue_num(gpi, N)`, `doca_gpi_set_rdma_queue_size(gpi, N)`, `doca_gpi_set_gpu_queue_size(gpi, N)` (all DOCA_EXPERIMENTAL) | Each must respect the matching `doca_gpi_cap_get_max_*` on this device; out-of-bounds returns `DOCA_ERROR_INVALID_VALUE` |
| Configure (transport) | `doca_gpi_set_gid_index(gpi, gid)` (DOCA_EXPERIMENTAL) | Selects the GID for the RDMA queues GPI will manage |
| Configure (memory) | `doca_gpi_bind_memory(gpi, addr, size)` + `doca_gpi_bind_memory_get_descriptor(gpi, &desc)` (both DOCA_EXPERIMENTAL) | Binds GPU-reachable memory regions to the GPI context; the descriptor is what the application exports to the remote peer |
| Convert to Core context | `doca_gpi_as_ctx(gpi)` (DOCA_STABLE) | Returns the generalized `doca_ctx*`; the application sets the GPU datapath on this context per [`doca-gpunetio`](../doca-gpunetio/SKILL.md) before `doca_ctx_start()` |
| Start | `doca_ctx_start(doca_gpi_as_ctx(gpi))` | All `set_*` calls and `bind_memory` calls must precede start; the headers' `DOCA_ERROR_BAD_STATE` doc strings name this |
| Destroy | `doca_gpi_destroy(gpi)` (DOCA_STABLE) | After `doca_ctx_stop()`; returns `DOCA_ERROR_IN_USE` if work queues are still attached — those must be detached first |

### The channel and RDMA-queue surface

A GPI context exposes `N` channels (sized via
`doca_gpi_set_channel_num`); each channel exposes `M` RDMA
queues (sized via `doca_gpi_set_rdma_queue_num`). Verified
channel surface:

| Call | Purpose | Note |
| --- | --- | --- |
| `doca_gpi_channel_get_handle(gpi, channel_num, &channel)` (DOCA_STABLE) | Retrieve the per-channel host-side handle on a started context | Returns `DOCA_ERROR_BAD_STATE` if called before `doca_ctx_start()` or if the context is not assigned to the GPU datapath |
| `doca_gpi_channel_get_gpu_handle(channel, &gpu_channel)` (DOCA_EXPERIMENTAL) | Retrieve the GPU-side handle the CUDA kernel uses; type is `struct doca_gpu_gpi_channel*` | Returns `DOCA_ERROR_BAD_STATE` under the same conditions as the host-side handle call |
| `doca_gpi_channel_get_rdma_queue_descriptor(channel, queue_num, &qdescr, &qdescr_size)` (DOCA_EXPERIMENTAL) | Read the local RDMA queue descriptor for exchange with the remote peer | The descriptor is the wire-format payload the application transports out-of-band to the peer |
| `doca_gpi_channel_connect_rdma_queue(channel, queue_num, qdescr_remote)` (DOCA_EXPERIMENTAL) | Connect the local RDMA queue to the remote peer's descriptor | After this call the GPU side can issue work on this queue |

### The CUDA-side surface

The GPU-side handle returned by
`doca_gpi_channel_get_gpu_handle` — type
`struct doca_gpu_gpi_channel*` — is consumed by a CUDA kernel
compiled with `nvcc` against the DOCA GPU NetIO device-side
header set. The CUDA-side programming model (kernel launch, GPU
memory mapping, the device-side API surface that *uses* the
GPI channel) is owned by
[`doca-gpunetio`](../doca-gpunetio/SKILL.md); this skill does
not duplicate it. Two rules that DO belong here because they are
GPI-specific:

- The GPU handle returned by
  `doca_gpi_channel_get_gpu_handle` is **the only legal bridge**
  between host-side configuration and CUDA-side execution. The
  agent does not invent a different handoff (e.g. casting a host
  pointer to a CUDA-managed pointer) — the doc string names this
  entry point.
- The GPU handle is valid only after the context is started
  *and* assigned to the GPU datapath. Retrieving it before
  start returns `DOCA_ERROR_BAD_STATE` per the shipped header
  doc strings.

### Capability discovery

Three capability-query calls gate the configure-time sizing:

- `doca_gpi_cap_get_max_channel_num(gpi, &max)` — maximum
  channels per GPI context.
- `doca_gpi_cap_get_max_rdma_queue_per_channel_num(gpi, &max)` —
  maximum RDMA queues per channel.
- `doca_gpi_cap_get_max_rdma_queue_size(gpi, &max)` — maximum
  RDMA queue size.

Run the cap query for each sizing knob before calling the
matching `doca_gpi_set_*`. Quoting a literal from the public
docs is not a substitute; the cap query is the runtime authority.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the headers-win-over-docs
rule, see [`doca-version`](../../doca-version/SKILL.md). The body
lives there; this skill does not duplicate it.

**The GPI-specific overlay** is:

- **The GPI surface is a stability mix.** The public version
  map exposes `doca_gpi_create`, `doca_gpi_destroy`,
  `doca_gpi_as_ctx`, and `doca_gpi_channel_get_handle` as
  `DOCA_STABLE`; the rest of the surface (sizing, GPU-handle
  retrieval, RDMA-queue descriptor exchange, memory binding) is
  `DOCA_EXPERIMENTAL`. The agent must surface this whenever the
  user wants to "ship to production" — the stable core is
  small, the experimental periphery is wide, and a future DOCA
  release may rename or change shape of any experimental call.
- **CUDA Toolkit is a second compatibility axis.** GPI's GPU-
  side handle is consumed by `nvcc`-compiled code, against the
  DOCA GPU-NetIO device-side header set. The DOCA-side `.pc`
  version (`pkg-config --modversion doca-gpi`) is one axis; the
  installed CUDA Toolkit version is a second axis. The
  authoritative DOCA ↔ CUDA pairing for a given DOCA release
  lives in the release notes; route through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the release-notes URL pattern rather than quoting a CUDA
  version pin from agent memory.
- **`doca-gpi.pc` plus `doca-common.pc` plus `doca-rdma.pc`
  must all match `doca_caps --version`** at the four-way-match
  check (per
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)).
  GPI sits on top of the doca-rdma queue surface; a partial
  install where one of these `.pc` files reports a different
  version is the most common partial-install pattern for GPI
  users.
- **The closest public docs surface for the GPU-side handoff is
  the DOCA GPU NetIO programming guide.** Until a dedicated
  *DOCA GPI* page is published, the agent uses the sister DOCA
  GPU NetIO guide at
  [docs.nvidia.com/doca/sdk/doca-gpunetio/index.html](https://docs.nvidia.com/doca/sdk/doca-gpunetio/index.html)
  for the underlying GPU-NetIO concepts and explicitly frames
  GPI as the lower-level channel/queue surface rather than a
  re-export of GPU NetIO. The
  [DOCA SDK index](https://docs.nvidia.com/doca/sdk/) is the
  authoritative starting point for whether a *GPI*-specific
  page now exists; route through
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  for the up-to-date URL pattern rather than quoting a URL
  literal from agent memory.

## Error taxonomy

The cross-library `DOCA_ERROR_*` taxonomy (what each family
means and which debug layer it routes to) lives in
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
The GPI-specific overlay names the families the agent will see
most often from `doca_gpi_*` calls and what they specifically
indicate:

| Family | Most common GPI cause | First action |
| --- | --- | --- |
| `DOCA_ERROR_BAD_STATE` | A configuration call (`set_channel_num`, `set_rdma_queue_*`, `set_gpu_queue_size`, `bind_memory`, `channel_get_handle`, `channel_get_gpu_handle`) ran *after* `doca_ctx_start()`; OR the context was not assigned to the GPU datapath before start | Walk the lifecycle in [`## Capabilities and modes`](#capabilities-and-modes); confirm every `set_*` and `bind_memory` call landed before `doca_ctx_start()` and that the GPU datapath was assigned before start |
| `DOCA_ERROR_INVALID_VALUE` | A `set_*` value exceeded the matching `doca_gpi_cap_get_max_*` for this device, or a pointer argument is NULL | Re-run capability discovery; clamp every `set_*` value to the device-reported maximum |
| `DOCA_ERROR_NO_MEMORY` | `doca_gpi_create` failed to allocate internal state | Inspect the system's available memory; this is rarely an application bug, usually a host-side resource issue |
| `DOCA_ERROR_INITIALIZATION` | `doca_gpi_create` failed to initialize an internal mutex | Same as above — inspect host resources |
| `DOCA_ERROR_IN_USE` | `doca_gpi_destroy` ran while work queues are still attached | Detach every attached queue before destroying the GPI context; the destroy lifecycle does not auto-detach |
| `DOCA_ERROR_NOT_SUPPORTED` | The installed DOCA version does not export the requested `doca_gpi_*` symbol, or the device does not support the GPU datapath this code requires | Confirm the symbol exists in the installed headers per [`## Version compatibility`](#version-compatibility); confirm GPU-datapath support on the device via `doca_caps` ([`doca-caps`](../../tools/doca-caps/SKILL.md)) |
| `DOCA_ERROR_DRIVER` | The layer below DOCA (mlx5 driver, firmware, the verbs / RDMA stack GPI depends on) reported a failure | Stop. This is not a GPI-spec problem. Capture `dmesg | tail` and `mlxconfig -d <pcie> q`; route to [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug) layer 7 |

Quote `doca_error_get_descr()` verbatim — do not paraphrase. The
cross-cutting debug ladder
([`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug))
is the canonical layered diagnosis path that the agent escalates
to once the GPI-specific cause has been narrowed.

## Observability

GPI's observability surface is **split between host and CUDA
kernel**, and the agent must keep both visible when walking a
problem.

1. **Host-side: the DOCA Core progress engine (PE).** The host
   side of GPI uses the universal Core-context PE for lifecycle
   events on the GPI context. The host side does NOT observe
   per-work-request completions — those happen on the GPU side.
   The host side only sees lifecycle transitions, context-start
   completion, and any host-initiated calls that fail.
2. **GPU-side: the CUDA kernel reads the channel directly.**
   The CUDA kernel that holds the `doca_gpu_gpi_channel*`
   handle reads completions, posts work, and observes per-queue
   state through the device-side API surface owned by
   [`doca-gpunetio`](../doca-gpunetio/SKILL.md). The host side
   is blind to those completions; the only signal the host gets
   that work happened is application-level (counters the CUDA
   kernel updates in shared memory, host-side timing, observable
   network traffic on the wire).
3. **Capability snapshot at configure time.** The output of
   every `doca_gpi_cap_get_*` query is a snapshot of *what the
   library said was possible* before any queue was sized. Save
   it as the baseline; if a later sizing returns
   `DOCA_ERROR_INVALID_VALUE` the diff against this snapshot is
   the bug.
4. **Memory-bind descriptor exchange.** The descriptor returned
   by `doca_gpi_bind_memory_get_descriptor` is the
   wire-format payload the application transports to the
   remote peer; the descriptor returned by
   `doca_gpi_channel_get_rdma_queue_descriptor` is the queue-
   side payload. Both are observable artifacts that the agent
   inspects when *"the peer says it can't reach my memory"* —
   diff the descriptor the local side built against what the
   peer received over its out-of-band channel.

For cross-cutting observability primitives (`--sdk-log-level`,
the `doca-<lib>-trace` build flavor, the `DOCA_LOG_LEVEL` env
var) see
[`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
For the install-tree observability (logger names, package
layout) defer to
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

GPI's safety surface is **GPU-side initiator**: a CUDA kernel
that has been handed a `doca_gpu_gpi_channel*` can issue RDMA
work directly against a remote peer's memory with no host CPU on
the data path. A wrong configuration or a stale handle silently
issues remote operations the user did not intend. Three policies
follow from that:

1. **The GPU handle is a credential, not a pointer.** Treat
   `doca_gpu_gpi_channel*` like any other capability handle: it
   is valid only for the lifetime of the GPI context that
   produced it, and only after that context is started on the
   GPU datapath. Reusing a handle across context restarts,
   sharing a handle between unrelated CUDA kernels, or
   persisting it across GPU driver reloads is undefined
   behavior. The agent enforces the *"one handle, one context,
   one consuming kernel"* discipline.
2. **Cap-gate every sizing knob.** Posting against a queue that
   was sized above the device's reported maximum is a silent
   failure mode in production — the configure call returned an
   error the application may have logged-and-ignored. The agent
   walks the cap query in front of every `doca_gpi_set_*` and
   refuses to recommend a number the device's cap query did not
   produce.
3. **Memory-bind descriptors are wire-format secrets.** The
   descriptor returned by
   `doca_gpi_bind_memory_get_descriptor` lets a remote peer
   address into bound GPU memory. Treat its out-of-band
   transport like any other RDMA descriptor: over a secure
   channel, only to authenticated peers, and with the
   *"production environments need a secure channel"* discipline
   the public DOCA RDMA guide names (see
   [`doca-rdma CAPABILITIES.md ## Safety policy`](../doca-rdma/CAPABILITIES.md#safety-policy)).
   The GPI overlay does not relax that rule.

For changes that touch hardware state below the GPI library
itself — `mlxconfig`-class writes, firmware burns, BlueField BFB
reflash, host kernel boot parameters (IOMMU mode is particularly
load-bearing for GPUDirect-style memory mapping) — the
cross-cutting meta-policy in
[`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md)
applies without modification. GPI does not redefine those rules;
the agent walks the hardware-safety ladder first whenever the
symptom involves device state, then the GPI overlay above for
the API-surface specifics.

## Deferred topic boundaries

This skill scopes itself to the DOCA GPI library. Adjacent
topics the agent will get asked but should route elsewhere:

- **The CUDA programming model** (kernel launch, stream
  ordering, GPU memory allocation) — outside this skill. The
  upstream CUDA documentation is the right answer; this skill
  assumes the user already builds and launches CUDA kernels.
- **The DOCA GPU NetIO Send/Receive surface** — owned by
  [`doca-gpunetio`](../doca-gpunetio/SKILL.md). GPI is the
  lower-level channel/queue surface; GPU NetIO is the higher-
  level Send/Receive surface. The selection table at the top
  of [`## Capabilities and modes`](#capabilities-and-modes)
  routes the agent there.
- **The doca-rdma queue lifecycle and permission matrix** —
  owned by [`doca-rdma`](../doca-rdma/SKILL.md). GPI binds an
  RDMA queue; the RDMA queue itself, its transport type, and
  its permission matrix are not GPI's concern.
- **DPA-resident accelerator initiation** — owned by
  [`doca-rdmi`](../doca-rdmi/SKILL.md). GPI is the GPU case;
  RDMI is the DPA case. The CLASS of "accelerator-initiated
  one-sided RDMA" applies to both.
- **Cross-library `DOCA_ERROR_*` taxonomy** — owned by
  [`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).
  This skill adds the GPI overlay, not the taxonomy itself.
- **Cross-library capability-snapshot tooling** — owned by
  [`doca-caps`](../../tools/doca-caps/SKILL.md). This skill
  references the tool; it does not redefine its invocation
  patterns.
