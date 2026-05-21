---
name: doca-gpi-ib-write-lat
description: NVIDIA DOCA GPI ib_write_lat — the GPI-flavored analog of the classic `perftest` `ib_write_lat`, shipped under `doca/tools/gpi_ib_write_lat/` as a client + server pair that measures the latency of an RDMA WRITE work request when the WR is posted **from a CUDA kernel on the GPU via doca-gpi**, not from a host CPU thread. The skill teaches the class question of *"what does kernel-initiated RDMA-WR latency look like on this GPU-NIC pair?"* — the GPU-NIC pairing precondition (the GPU and the IB device must be reachable through the same PCIe / NVLink fabric for the GPI path to be efficient), the configure / build / run shape against the shipped tool tree, how to read the reported half-iteration and full-iteration usec values, the version + capability overlay against the installed DOCA + CUDA Toolkit, and how the result reads against the sister tool `doca-gpunetio-ib-write-lat` (same physical operation; different runtime framework — pick the right surface, do not mix them).
kind: tool
---

# DOCA GPI ib_write_lat

**Where to start:** This is a tool skill for the GPI-flavored
`ib_write_lat` benchmark shipped under
`doca/tools/gpi_ib_write_lat/` (built into a single binary that
runs as either client or server). It measures the latency of an
RDMA WRITE work request posted **from a CUDA kernel on the GPU**
through the `doca-gpi` channel + queue surface. Open
[`TASKS.md`](TASKS.md) and start at
[`## configure`](TASKS.md#configure) for the
GPU-NIC pairing precondition and the build pattern against the
installed DOCA; jump to [`## run`](TASKS.md#run) for the
single-frame smoke flow. Open
[`CAPABILITIES.md`](CAPABILITIES.md) when the question is *what
this tool actually measures*, *how it differs from
`doca-gpunetio-ib-write-lat`*, or *how to interpret the
reported half-iter / full-iter / CUDA usec output without
fooling yourself*. If DOCA is not installed yet, route to
[`doca-setup`](../../doca-setup/SKILL.md) first; if the user is
still picking between `doca-gpi` and `doca-gpunetio` as a
programming surface, the picture in
[`../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes`](../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes)
is the first stop.

## Example questions this skill answers well

The CLASSES of `doca-gpi-ib-write-lat` questions this skill is
built to answer, each with one worked example. The class is the
load-bearing piece; the worked example is one instance.

- **"What does GPU-kernel-initiated RDMA-WRITE latency actually
  look like on this GPU-NIC pair?"** — worked example:
  *"measure single-iteration WRITE latency between two hosts
  with an H100 + ConnectX-7 on each side"*. Answered by the
  GPU-NIC pairing precondition in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the bring-up flow in
  [`TASKS.md ## configure`](TASKS.md#configure) +
  [`TASKS.md ## run`](TASKS.md#run). The same shape answers
  *"measure GPI-driven WRITE latency between a host GPU and a
  BlueField DPU"* — the tool is a class-shaped benchmark, not
  a single-platform benchmark.
- **"Is the GPI path the right surface for this class of
  workload, or should I be on GPUNetIO / on a host-initiated
  path?"** — worked example: *"my CUDA kernel needs to push
  control-plane updates to a remote peer at the lowest latency
  achievable from GPU memory"*. Answered by the
  surface-selection table in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the *"why GPI vs GPUNetIO vs CPU-initiated"* rule in
  [`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
  + the cross-tool comparison in
  [`../doca-gpunetio-ib-write-lat/CAPABILITIES.md`](../doca-gpunetio-ib-write-lat/CAPABILITIES.md).
- **"How do I read the half-iteration vs full-iteration usec
  output the tool reports?"** — worked example: *"the binary
  printed a half-iter and a full-iter column — what is the
  difference and which one is the apples-to-apples latency
  number for a ping-pong workload?"*. Answered by the output-
  interpretation rules in
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability)
  + the eval-loop overlay in
  [`TASKS.md ## test`](TASKS.md#test).
- **"This is the GPI tool — how does the result differ from
  `doca-gpunetio-ib-write-lat`?"** — worked example: *"my
  team has a working build of the GPUNetIO variant; should I
  expect the same number from the GPI variant or different?"*.
  Answered by the *"same physical operation, different
  runtime"* rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  + the cross-link to
  [`../doca-gpunetio-ib-write-lat/`](../doca-gpunetio-ib-write-lat/SKILL.md).
- **"The number I am getting looks too good (or too bad). What
  do I check before I quote it?"** — worked example: *"my
  single-iter latency is 1.2 usec; that is inside the NIC's
  documented one-way latency — is the measurement sound?"*.
  Answered by the measurement-soundness rules in
  [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
  layer 5 + the *"smoke before bulk"* flow in
  [`TASKS.md ## run`](TASKS.md#run).
- **"What version of DOCA + CUDA Toolkit do I need for this
  binary to build and run?"** — worked example: *"my install
  has DOCA at one semver and CUDA at another; will the
  ToT-shipped `gpi_ib_write_lat` even link?"*. Answered by
  the version overlay in
  [`CAPABILITIES.md ## Version compatibility`](CAPABILITIES.md#version-compatibility)
  which cross-links the canonical detection chain in
  [`doca-version`](../../doca-version/SKILL.md) and adds the
  *"DOCA `.pc` + CUDA toolkit must both be visible to
  `meson`"* overlay specific to this tool's `meson.build`.

## Audience

This skill serves **external developers and performance
engineers who need a reproducible measurement of the latency
of an RDMA WRITE work request when the WR is posted from a
CUDA kernel through doca-gpi**, on the user's actual install
and GPU-NIC pair. Concretely:

- A developer comparing the GPI path against the GPUNetIO path
  or the host-initiated `perftest`-style path before committing
  an application design to one of them.
- A platform operator validating a tuning change (NUMA pinning,
  GPU PCIe placement, IB device choice, GID index, firmware
  burn) by re-running this benchmark against the new state.
- An SRE / performance engineer producing a *"this is what
  GPU-initiated WRITE latency looks like on this GPU-NIC pair
  today"* artifact that downstream consumers (capacity planning,
  regression bisection, GPU-NIC pairing decisions) can cite.
- An AI agent answering *"is the doca-gpi path a win for my
  workload class"* honestly — with a measured number, the
  build + invocation that produced it, and the GPU + NIC +
  DOCA version that scopes it — rather than guessing.

It is **not** for users debugging the `doca-gpi` library
itself (route there to
[`../../libs/doca-gpi/SKILL.md`](../../libs/doca-gpi/SKILL.md)),
and **not** a substitute for the `perftest` upstream
`ib_write_lat` (which measures CPU-initiated WRITE latency
through `libibverbs`).

## Language scope

The `doca-gpi-ib-write-lat` tool is shipped as **C plus a CUDA
`.cu` translation unit** under `doca/tools/gpi_ib_write_lat/`
(`main.c`, `common.h`, `perftest.c`, `oob_socket.c`,
`kernel.cu`, `meson.build`). The host-side build is `meson`
against the installed DOCA `pkg-config` modules (`doca-gpi`,
`doca-rdma`, `doca-common`, the verbs / CUDA dependencies);
the device-side build is `nvcc` against the DOCA GPU NetIO
device-side header set documented in
[`../../libs/doca-gpunetio/`](../../libs/doca-gpunetio/SKILL.md).
There is no Python / Rust / Go binding for this tool — it is
a CLI binary. The skill's job is to keep the configure / build
/ run / interpret-the-output workflow language-neutral *for
the operator*, not to re-bind the tool.

## When to load this skill

Load this skill when the user is — or the agent needs to —
build and run the `gpi_ib_write_lat` binary on a real host
with DOCA installed plus a CUDA Toolkit matched to the DOCA
install, and a GPU + IB device pair reachable on the host's
PCIe topology. Concretely:

- Measuring kernel-initiated RDMA WRITE latency between two
  hosts (or a host and a BlueField DPU) with the GPI surface.
- Deciding whether the GPI path is the right *runtime*
  surface for a class of workload vs the GPUNetIO path
  ([`../doca-gpunetio-ib-write-lat/SKILL.md`](../doca-gpunetio-ib-write-lat/SKILL.md))
  or the classic CPU-initiated `perftest` path.
- Capturing a documented baseline (build + invocation +
  DOCA version + GPU + NIC + as-deployed environment +
  numbers) for later regression hunts.
- Diagnosing a build / link / run failure that surfaces the
  GPI bring-up sequence under this tool's shipped scaffolding.

Do **not** load this skill for general DOCA orientation,
library API work, or installation. For those, use
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md),
[`../../libs/doca-gpi/SKILL.md`](../../libs/doca-gpi/SKILL.md),
or [`doca-setup`](../../doca-setup/SKILL.md). Do not load it
for *application-level* end-to-end RDMA latency either — this
benchmark measures one RDMA WRITE on the GPI surface, not the
user's full pipeline.

## What this skill provides

This is a **thin loader**. Substantive material lives in two
companion files:

- `CAPABILITIES.md` — what the tool measures (the WRITE-from-
  GPU latency primitive, the half-iter / full-iter / CUDA-usec
  reporting shape), the runtime-surface selection rule (GPI
  vs GPUNetIO vs CPU-initiated), the GPU-NIC pairing
  precondition (the GPU and the IB device must be on the
  same PCIe complex or reachable over NVLink for the GPI
  path to be efficient — this is a hardware-topology
  precondition, not a workaround), the version overlay
  (DOCA-side `.pc` PLUS CUDA Toolkit PLUS the verified
  `doca-gpi` symbol set on the install), the layered error
  taxonomy (config-syntax / build-time / GPU-NIC-pairing /
  GPI-lifecycle / RDMA-connection / measurement-soundness /
  version / cross-cutting), the observability surface
  (stdout report, DOCA log levels, the OOB socket exchange),
  and the safety overlay (the *"GPU handle is a credential"*
  rule inherited from doca-gpi; the cross-cutting hardware-
  safety meta-policy).
- `TASKS.md` — step-by-step workflows for the in-scope task
  verbs: `install` (preconditions — DOCA install, CUDA
  Toolkit, GPU + NIC pair, OOB connectivity), `configure`
  (build-tree under `doca/tools/gpi_ib_write_lat/` and the
  `meson` build wrapping the shipped DOCA), `build` (the
  `meson setup` + `meson compile` pattern from the public
  DOCA build documentation), `modify` (do not patch the
  shipped tool source; modify the *invocation* and the
  surrounding config instead), `run` (smoke-before-bulk
  with single-iteration verification), `test` (the eval
  loop — half-iter / full-iter / CUDA usec sanity), `debug`
  (walk the error taxonomy layer by layer), `use` (how a
  result from this tool feeds into a class-of-workload
  decision), plus a `Deferred task verbs` block routing
  out-of-scope questions.

The skill assumes a host where DOCA is already installed at
the standard location, a CUDA Toolkit compatible with the
installed DOCA is present, and the user has whatever
privileges their public install profile expects for binding
a `doca_dev` plus a `doca_gpu`.

## What this skill deliberately does not ship

This skill is **agent guidance**, not a samples or scripts
bundle. To keep the boundary clean, it deliberately does not
contain — and pull requests should not add:

- **Specific flag strings or expected latency numbers** beyond
  what the tool's shipped `--help` and `meson.build`
  documentation establish. The flag surface is small (per the
  tool's `main.c` it accepts a device name, a GPU PCIe
  address, an optional GID index, and a client / server mode
  with an IP address); the agent re-reads the binary's
  `--help` on the installed version before quoting flag
  strings. Latency numbers are device-, firmware-, version-,
  and topology-specific; pinning one would mislead operators
  on a different platform.
- **Pre-written DOCA GPI or CUDA kernel source code** that
  would compete with the shipped tool tree. The shipped
  `doca/tools/gpi_ib_write_lat/{main.c,perftest.c,kernel.cu,
  common.h}` files are the verified worked example for this
  benchmark class; the agent's job is to route the user there
  and prescribe minimum-diff modification per the universal
  modify-a-sample workflow in
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md).
- **Wrappers, parsers, or scripts** in any language that
  consume the tool's stdout. The output format is small and
  documented in
  [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability);
  if the user wants to script against it, the right answer
  is *"read the live source, write the parser against your
  installed binary"*.
- **A `samples/`, `bindings/`, or `reference/` subtree.**
  This is a thin loader for a shipped tool; substantive
  material lives in the source tree and in the GPI library
  docs.

## Loading order

1. Read this `SKILL.md` first to confirm the user's question
   is in scope (the user actually wants to measure kernel-
   initiated WRITE latency through GPI, not learn GPI as a
   library or do a CPU-initiated measurement).
2. **For what the tool measures, the surface-selection rule
   against `doca-gpunetio-ib-write-lat`, the GPU-NIC pairing
   precondition, the version overlay, the error taxonomy, the
   observability surface, and the safety overlay, see
   [CAPABILITIES.md](CAPABILITIES.md).**
3. **For step-by-step workflows — `install`, `configure`,
   `build`, `modify`, `run`, `test`, `debug`, `use` — see
   [TASKS.md](TASKS.md).**

## Related skills

- [`../../libs/doca-gpi/SKILL.md`](../../libs/doca-gpi/SKILL.md) —
  the library this tool wraps. The channel + queue object
  model, the GPU-side handle handoff, the capability-query
  surface (`doca_gpi_cap_get_*`), and the
  `DOCA_EXPERIMENTAL`-vs-`DOCA_STABLE` stability mix all live
  there. This skill assumes the agent has the GPI library
  picture before reading the tool.
- [`../../libs/doca-gpunetio/SKILL.md`](../../libs/doca-gpunetio/SKILL.md) —
  the higher-level GPU NetIO surface. The shipped tool's
  `kernel.cu` is compiled against the DOCA GPU NetIO device-
  side header set; the broader CUDA-side programming surface
  for GPU-initiated networking lives there.
- [`../../libs/doca-rdma/SKILL.md`](../../libs/doca-rdma/SKILL.md) —
  the underlying RDMA library. The RDMA queue GPI binds is
  created and connected via `doca-rdma`; the queue
  lifecycle, the transport type (RC vs UC vs UD), the
  permission matrix, and the connection method (CM, OOB
  socket per this tool, gRPC) are owned there.
- [`../../libs/doca-verbs/SKILL.md`](../../libs/doca-verbs/SKILL.md) —
  the raw-verbs escape hatch beneath `doca-rdma` /
  `doca-gpunetio`. This tool stays on the higher-level
  surfaces; `doca-verbs` is the right place only if the user
  needs a specific WR flag / QP attribute the GPI + RDMA
  surfaces do not expose.
- [`../doca-gpunetio-ib-write-bw/SKILL.md`](../doca-gpunetio-ib-write-bw/SKILL.md)
  and
  [`../doca-gpunetio-ib-write-lat/SKILL.md`](../doca-gpunetio-ib-write-lat/SKILL.md) —
  sister tools. Same physical operation (RDMA WRITE from
  GPU memory); different runtime framework. The selection
  rule in
  [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
  is the decision aid.
- [`doca-version`](../../doca-version/SKILL.md) — the canonical
  version-detection chain, four-way match rule, NGC container
  semantics, and headers-win-over-docs rule. The
  `## Version compatibility` section in this skill is a thin
  overlay on top of `doca-version`; the body lives there.
- [`doca-setup`](../../doca-setup/SKILL.md) — env preparation,
  install verification, GPU + CUDA Toolkit pairing, and the
  *I have no install yet* path with the public NGC DOCA
  container.
- [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md) —
  routing to the public DOCA documentation set (DOCA GPI,
  DOCA GPU NetIO, DOCA RDMA pages on `docs.nvidia.com`) and
  the `docs.nvidia.com/cuda/` pointer for the CUDA Toolkit
  side.
- [`doca-debug`](../../doca-debug/SKILL.md) — the cross-cutting
  debug ladder. This tool surfaces *its own* error taxonomy
  in [`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy);
  when the cause turns out to be below DOCA (driver,
  firmware, NUMA, CUDA driver), the tool taxonomy hands off
  to `doca-debug`.
- [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md) —
  the bundle-wide hardware-safety meta-policy. The
  `## Safety policy` overlay in `CAPABILITIES.md`
  cross-links it for any change that touches BlueField BFB,
  firmware, IOMMU mode, or kernel boot parameters
  load-bearing for GPUDirect-style memory mapping.
