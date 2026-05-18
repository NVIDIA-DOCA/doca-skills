# DOCA GPI ib_write_lat — Capabilities

**Where to start:** This file is loaded by [`SKILL.md`](SKILL.md).
It documents *what `gpi_ib_write_lat` actually measures*, *how
it differs from the GPUNetIO sister tool and the CPU-initiated
`perftest` `ib_write_lat`*, *which DOCA / CUDA versions it
needs*, *the layered error and observability surfaces*, and
*the safety overlay* the agent applies whenever this benchmark
is run against real hardware. The pattern overview below names
the recurring `gpi_ib_write_lat`-class questions; pick the
pattern first, then drill into the H2 that owns the substance.
For the *how* of executing each pattern, jump to
[TASKS.md](TASKS.md).

## Pattern overview

Every `gpi_ib_write_lat`-class question this skill teaches
resolves into one of six patterns. The patterns are CLASSES —
they apply to every GPU-NIC pair the benchmark can target, not
just one platform.

| `gpi_ib_write_lat` pattern | Class shape | Where the substance lives |
| --- | --- | --- |
| 1. Pick the runtime surface | Decide *before* building whether the workload's WR-init path should be GPI (this tool), GPUNetIO (sister tool `doca-gpunetio-ib-write-lat`), or classic CPU-initiated `perftest` `ib_write_lat`. The three surfaces measure the same physical operation but answer different runtime questions. | [`## Capabilities and modes`](#capabilities-and-modes) surface-selection table + [`../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes`](../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes) |
| 2. Confirm the GPU-NIC pairing | The GPI path requires the GPU and the IB device to be reachable through the same PCIe complex or NVLink fabric for the WR-submission path to be efficient. A wrong pairing produces a number, but the number is not the question the operator was asking. | [`## Capabilities and modes`](#capabilities-and-modes) GPU-NIC pairing rule + [TASKS.md ## configure](TASKS.md#configure) |
| 3. Build against the install | The tool ships under `doca/tools/gpi_ib_write_lat/` with a `meson.build` that wraps the DOCA `pkg-config` modules (`doca-gpi`, `doca-rdma`, `doca-common`) and the CUDA Toolkit. Mismatched DOCA + CUDA versions surface at build / link time. | [`## Version compatibility`](#version-compatibility) + [TASKS.md ## build](TASKS.md#build) |
| 4. Smoke-before-bulk | Run the smallest defensible single-iteration handshake (server up, client connects, one WR flows, one report line lands) before any swept run. The class shape applies to every GPU-NIC pair. | [TASKS.md ## run](TASKS.md#run) smoke flow + [TASKS.md ## test](TASKS.md#test) eval-loop overlay |
| 5. Diagnose a tool failure | Walk the layered error taxonomy in [`## Error taxonomy`](#error-taxonomy) — config-syntax / build-time / GPU-NIC-pairing / GPI-lifecycle / RDMA-connection / measurement-soundness / version / cross-cutting — instead of guessing at causes from a stack trace. | [`## Error taxonomy`](#error-taxonomy) + [TASKS.md ## debug](TASKS.md#debug) |
| 6. Interpret the reported number | The tool's printed line carries half-iter, full-iter, and CUDA-side usec values; the user must know which one is the apples-to-apples ping-pong latency. Quoting one without naming the column is the cross-tool comparison failure mode. | [`## Observability`](#observability) + [TASKS.md ## test](TASKS.md#test) |

Two cross-cutting rules that apply to *every* pattern above:

- **The result is GPU-NIC-pair-specific, version-specific, and
  topology-specific.** A number captured on one host is not
  transferable to another without re-capturing the (GPU model,
  NIC model, PCIe topology, DOCA version, CUDA Toolkit
  version, firmware level, IB transport) tuple alongside the
  number. Quoting a number without the tuple is the canonical
  cross-platform regression-hunt failure mode.
- **GPI is the lower-level GPU-init RDMA surface.** Most
  CUDA developers should *not* drop to GPI just because they
  want GPU-initiated RDMA; the higher-level GPUNetIO surface
  ([`../../libs/doca-gpunetio/`](../../libs/doca-gpunetio/SKILL.md))
  is the default and answers the same workload class via a
  Send/Receive abstraction. This tool only makes sense when
  the operator has *already decided* GPI is the right
  programming surface for the class of workload.

## Capabilities and modes

`gpi_ib_write_lat` is a **single-binary, client + server**
benchmark shipped as the source tree under
`doca/tools/gpi_ib_write_lat/`. The same binary acts as server
by default and switches to client when invoked with `-c
<server-ip>`. Both halves run on hosts that have:

- A DOCA install that exposes the `doca-gpi` library (the
  capability surface lives in
  [`../../libs/doca-gpi/CAPABILITIES.md`](../../libs/doca-gpi/CAPABILITIES.md)).
- A CUDA Toolkit matched to the DOCA install (the pairing
  lives in the DOCA release notes per
  [`../../libs/doca-gpunetio/CAPABILITIES.md#version-compatibility`](../../libs/doca-gpunetio/CAPABILITIES.md#version-compatibility)).
- An IB device named on the command line (`-d <ibdev>`) and a
  GPU named by PCIe address (`--gpu <bdf>`).

### What the benchmark actually measures

The binary brings up a `doca_gpi` context on the named IB
device, configures one RDMA queue per channel, exchanges
queue + memory descriptors with the remote peer over an OOB
TCP/IP socket (`oob_socket.c`), connects the queue, and then
launches a CUDA kernel (`kernel.cu`) that posts an RDMA WRITE
work request **from the GPU** and waits for completion. The
ping-pong is GPU-driven; the host CPU is not on the WR-
submission path.

The measured quantity is the latency of one round trip of
this GPU-driven WRITE handshake. The skill teaches three
classes of result the operator must keep distinct:

| Result column class | What it is | Read it as |
| --- | --- | --- |
| Half-iteration | The one-direction WRITE + completion observation | The lower-bound apples-to-apples ping-pong latency when both halves are GPI-driven. The right column to quote for *"one-way latency of a GPU-initiated WRITE"*. |
| Full-iteration | The full round trip (client posts WRITE; server observes and responds; client observes) | The right column to quote for *"round-trip latency for a request-response pattern"*. |
| CUDA-side usec | The CUDA kernel's own measured time (driven from the device-side clock) | Use as a cross-check against the host-side number. A large divergence between the host and the CUDA number is a measurement-soundness signal that belongs in [`## Error taxonomy`](#error-taxonomy) layer 5, not in a quoted result. |

### Surface selection: GPI vs GPUNetIO vs CPU-initiated

The same RDMA WRITE operation can be measured from three
different runtime surfaces. The agent must surface this
choice to the operator before quoting any number:

| Surface | Tool | When this surface is the right answer |
| --- | --- | --- |
| GPI (this skill) | `doca-gpi-ib-write-lat` | The CUDA kernel drives the RDMA queue **directly** through the `doca-gpi` channel + queue handle. Right when the application is committed to GPI as its programming surface and wants a latency baseline that reflects that runtime. |
| GPUNetIO | [`../doca-gpunetio-ib-write-lat/`](../doca-gpunetio-ib-write-lat/SKILL.md) | The CUDA kernel drives RDMA WRITE through the higher-level `doca-gpunetio` framework. Right when the application sits on GPUNetIO and wants the latency it will see in practice. |
| CPU-initiated `perftest` | Upstream `perftest` `ib_write_lat` (out of scope here; not in `doca/tools/`) | The host CPU posts the WR via `libibverbs`; the GPU is not on the path. Right when the comparison the operator needs is *"how much overhead does the GPU-initiated path add (or remove) versus the classic CPU-initiated path?"*. |

**Decision rule for the agent.** Surface the three options to
the user and ask which programming surface their application
will actually run on. *"Pick GPI because the user said GPU"*
is the canonical bait — the GPI vs GPUNetIO question is about
the runtime API the application is using, not whether a GPU
is in the machine.

### The GPU-NIC pairing precondition

The GPI WR-submission path is efficient only when the GPU
and the IB device are reachable through a *common* PCIe
complex or an NVLink fabric the platform exposes for that
purpose. A misplaced pair (GPU on one NUMA node, NIC on the
other, no NVLink bridge) still completes the benchmark but
the reported latency reflects PCIe-crossover overhead, not
the property the operator was trying to measure.

The agent's rule for this precondition:

- Identify the GPU's PCIe address (`nvidia-smi --query-gpu=pci.bus_id`).
- Identify the IB device's PCIe address (`ibdev2netdev -v`
  or `lspci`).
- Confirm both are siblings under the same PCIe root
  complex, OR confirm the platform documents an NVLink path
  between the GPU and the NIC's host bridge.
- Quote the pairing alongside any reported number. *"WRITE
  latency from H100 (PCIe X) to ConnectX-7 (PCIe Y) on the
  same root complex"* is a defensible quote; *"WRITE latency
  on this host"* is not.

If the pairing is wrong, the answer is **not** to tune the
benchmark — the answer is to fix the platform's GPU + NIC
placement. The benchmark surfaces the precondition; it
does not synthesize a result around it.

## Version compatibility

For the canonical DOCA version-detection chain, the four-way
match rule, NGC container semantics, and the
headers-win-over-docs rule, see
[`doca-version`](../../doca-version/SKILL.md). The body lives
there; this skill does not duplicate it.

**The `doca-gpi-ib-write-lat`-specific overlay** is:

- **The tool builds against `doca-gpi`** per
  `doca/tools/gpi_ib_write_lat/meson.build`. The version of
  the installed `doca-gpi` (`pkg-config --modversion
  doca-gpi`) is the authoritative pin for this tool's API
  surface. The four-way match in
  [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
  must hold across `doca-common`, `doca-rdma`, and
  `doca-gpi` on the install before the build is attempted.
- **The CUDA Toolkit is a second axis.** The tool's
  `kernel.cu` is compiled with `nvcc`; the CUDA Toolkit
  version must be the one paired with the installed DOCA per
  the DOCA release notes (looked up via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).
  The agent does NOT quote a specific CUDA version from
  memory; the user reads the pairing from the release notes
  for the DOCA version `doca_caps --version` reports.
- **`doca-gpi` is a stability mix (per the library skill).**
  Most of the GPI symbols this tool uses are tagged
  `DOCA_EXPERIMENTAL` in the public version map. A DOCA
  upgrade that moves the GPI surface can break this build
  without any user-visible warning; the agent re-runs the
  build and the smoke after any DOCA upgrade rather than
  assuming the binary survived.
- **The remote peer must run a binary built against a
  compatible DOCA + CUDA pair.** Mixing a client built on
  one DOCA version with a server built on a different one is
  unsupported; the OOB-socket descriptor exchange uses the
  ABI the binary was built with on each side.
- **No version literal from memory.** *"GPI tools landed in
  DOCA X.Y"* is not stated in this skill; the agent quotes
  the version observed from the user's host
  (`pkg-config --modversion doca-gpi`, `doca_caps --version`)
  and from the DOCA release notes published on
  `docs.nvidia.com/doca/`.

## Error taxonomy

The error surface for `gpi_ib_write_lat` is broader than for
a pure library call because the tool builds against the
installed DOCA, talks to a remote peer over a TCP socket, and
drives a CUDA kernel against an RDMA queue. The error layers
the agent should distinguish, in escalating order:

1. **Config-syntax.** The invocation itself is wrong:
   missing `-d <ibdev>`, missing `--gpu <bdf>`, an `-c`
   server-IP that is not a valid IP, a GID index that is
   non-numeric. The tool's `main.c` carries the ARGP
   schema; re-read the binary's `--help` on the installed
   build, do not infer flags from blog posts.
2. **Build-time.** `meson setup` or `meson compile` failed
   under `doca/tools/gpi_ib_write_lat/`. Most common
   causes: `doca-gpi.pc` not found (DOCA install does not
   ship GPI on this profile), `nvcc` not found (CUDA
   Toolkit not on `PATH`), GLIBC / GCC mismatch with the
   shipped DOCA install. Re-route through
   [`doca-setup`](../../doca-setup/SKILL.md) and the GPI
   library's
   [`../../libs/doca-gpi/TASKS.md#install`](../../libs/doca-gpi/TASKS.md#install)
   verification before re-running the build.
3. **GPU-NIC pairing.** Binary built; the runtime cannot
   bind the GPU to the IB device because the platform
   does not expose a path between them, or because the
   user named a `-d`/`--gpu` pair that does not share a
   PCIe complex / NVLink fabric. Re-walk the pairing
   precondition in
   [`## Capabilities and modes`](#capabilities-and-modes)
   GPU-NIC pairing rule before re-running.
4. **GPI-lifecycle.** The GPI context fails to start (most
   often `DOCA_ERROR_BAD_STATE` per
   [`../../libs/doca-gpi/CAPABILITIES.md#error-taxonomy`](../../libs/doca-gpi/CAPABILITIES.md#error-taxonomy)),
   the channel-handle retrieval returns `DOCA_ERROR_BAD_STATE`
   because the GPU datapath was not assigned, or
   `doca_gpi_destroy` returns `DOCA_ERROR_IN_USE` because
   the CUDA kernel is still holding the GPU handle. Route
   to the library skill's debug ladder.
5. **RDMA-connection.** The OOB socket comes up but the
   queue connection fails: GID index mismatch between client
   and server, RDMA permission flags do not include WRITE,
   the remote peer's memory descriptor is rejected by
   `doca_gpi_channel_connect_rdma_queue`. Route to
   [`../../libs/doca-rdma/CAPABILITIES.md`](../../libs/doca-rdma/CAPABILITIES.md)
   for the underlying RDMA connection rules.
6. **Measurement-soundness.** The benchmark completes and
   prints a number, but the number is unsound. Common sub-
   layers: (a) the GPU-NIC pairing is wrong (PCIe-crossover
   overhead dominates), (b) the system was not at idle
   (background traffic on the IB link, GPU kernels competing
   for the SM), (c) the warm-up was too short and the first
   measured iteration sits in the transient region, (d) the
   number quoted was the wrong column of the result line
   (half-iter vs full-iter vs CUDA-side). Re-walk
   [`## Observability`](#observability) before quoting.
7. **Version.** Cross-cutting partial-install / mixed-version
   layer per
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility).
   Symptoms: client and server were built against different
   DOCA versions, CUDA Toolkit version on the build host
   disagrees with the runtime CUDA driver, `pkg-config
   --modversion` for `doca-gpi` disagrees with
   `doca_caps --version`. Route through
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug).
8. **Cross-cutting.** The cause is below DOCA — mlx5
   driver, CUDA driver, firmware, NUMA, hugepages, kernel
   boot parameters (IOMMU mode is load-bearing for
   GPUDirect-style memory mapping per
   [`doca-hardware-safety CAPABILITIES.md ## Capabilities and modes`](../../doca-hardware-safety/CAPABILITIES.md#capabilities-and-modes)).
   Route to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   and
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug).

This tool does not *itself* participate in the cross-library
`DOCA_ERROR_*` taxonomy at the program level — the
`DOCA_ERROR_*` returns it produces come from the underlying
GPI / RDMA libraries. For the cross-library taxonomy itself,
see
[`doca-programming-guide CAPABILITIES.md ## Error taxonomy`](../../doca-programming-guide/CAPABILITIES.md#error-taxonomy).

## Observability

The tool's observability surface is the printed report on
stdout (the result line carrying `#bytes`, `#iterations`,
half-iter / full-iter / CUDA-side usec columns, per
`perftest.c`), plus the DOCA log surface owned by
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability),
plus the OOB-socket exchange. Specifically:

- **Stdout result line.** The benchmark prints one summary
  row per (message size × iteration count) combination the
  user asked for. The columns the agent must keep distinct
  are: bytes, iteration count, half-iter usec, full-iter
  usec, CUDA-side usec. *"What is the latency"* without
  naming the column is ambiguous; the agent does not paper
  over that.
- **DOCA log levels.** `DOCA_LOG_LEVEL` and
  `--sdk-log-level` apply per the cross-cutting rule in
  [`doca-debug CAPABILITIES.md ## Observability`](../../doca-debug/CAPABILITIES.md#observability).
  The tool's `main.c` sets the SDK logger to `WARNING`; an
  operator hunting bring-up issues should raise it.
- **OOB-socket exchange.** Client and server negotiate the
  RDMA queue + memory descriptors over a TCP socket
  (`oob_socket.c`, default port `5000`). The pre-handshake
  hangs surface here, not in the CUDA path; checking the
  TCP socket is up and the firewall is not blocking is the
  first observable signal that the bring-up reached the
  exchange step.
- **Pre-run echo.** The tool logs the device name, GPU
  PCIe address, GID index, and client/server choice at
  startup via `DOCA_LOG_INFO`. A captured log self-documents
  the invocation the result line belongs to; the agent
  preserves the echo when capturing a baseline.
- **CUDA-side timing as a cross-check.** The CUDA kernel
  reports its own measured time (per `kernel.cu`). A large
  divergence between the host-side and the CUDA-side number
  is itself the diagnostic signal — see
  [`## Error taxonomy`](#error-taxonomy) layer 6.

For env-side observability (PCIe scans, link introspection,
`mlxconfig`, `nvidia-smi`) see
[`doca-setup CAPABILITIES.md ## Observability`](../../doca-setup/CAPABILITIES.md#observability).
For program-side observability (DOCA log levels,
`DOCA_LOG_LEVEL`) see
[`doca-programming-guide CAPABILITIES.md ## Observability`](../../doca-programming-guide/CAPABILITIES.md#observability).

## Safety policy

> **Overlay on the bundle-wide hardware-safety meta-policy.** The rules below are this skill's per-artifact overlay on the cross-cutting rules in [`doca-hardware-safety` CAPABILITIES.md ## Safety policy](../../doca-hardware-safety/CAPABILITIES.md#safety-policy) (specifically [### Per-artifact overlay pattern](../../doca-hardware-safety/CAPABILITIES.md#per-artifact-overlay-pattern)). When the two layers disagree, the stricter wins; when either layer says STOP, the agent stops.

`gpi_ib_write_lat` is a measurement tool. It allocates GPU
memory, binds it to the GPI context, exchanges descriptors
with a remote peer over a TCP socket, and drives an RDMA
WRITE from a CUDA kernel. The artifact-specific safety
overlay:

- **The GPU handle and the memory-bind descriptor are
  credentials.** The same rule the GPI library carries in
  [`../../libs/doca-gpi/CAPABILITIES.md#safety-policy`](../../libs/doca-gpi/CAPABILITIES.md#safety-policy)
  applies here: the GPU-side channel handle is valid only
  for the lifetime of the started GPI context, and the
  memory-bind descriptor is wire-format that lets the
  remote peer address into the bound GPU memory. The OOB
  socket this tool uses runs in cleartext by default; run
  the benchmark only against trusted peers on trusted
  segments, and do not re-use the descriptor across runs.
- **Smoke-before-bulk; never trust the first sweep.** A
  swept run on the wrong GPU-NIC pair, wrong GID index, or
  wrong RDMA permissions burns the operator's time on
  unusable data. The agent's rule is the
  [`TASKS.md ## run`](TASKS.md#run) smoke step (single-
  iteration, single message size, single client + server
  pair) before any sweep.
- **Quote the (DOCA version + CUDA Toolkit + GPU + NIC +
  topology + firmware) tuple, not just the number.** A
  latency number quoted without the tuple is unreplicable
  and unfalsifiable. This rule applies to every output of
  this skill — the most common downstream misuse of this
  tool is quoting a screenshot from one platform as if it
  described another.
- **Do not invent flags.** The flag surface is small (per
  `main.c`: `-c`, `-d`, `--gpu`, `--gid-index`) and the
  installed binary's `--help` is the authoritative source.
  Prose-derived flags are the most common hallucination
  failure for this skill.
- **Hardware-safety meta-policy applies to host-side
  changes.** Any host-side change the benchmark surfaces a
  need for (kernel command-line `iommu=` change for
  GPUDirect, hugepage reservation change, BlueField BFB
  reflash, firmware burn on the NIC) is a hardware-touching
  change that runs through the cross-cutting meta-policy in
  [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md),
  not through this tool's invocation.

## Public-source pointer

The two canonical public sources for this tool's surface are
the **DOCA GPI** programming guide page and the **DOCA GPU
NetIO** page on `docs.nvidia.com/doca/sdk/`, plus the
shipped source tree at `doca/tools/gpi_ib_write_lat/` on the
user's install (or in the public DOCA source mirror on
`github.com/NVIDIA/doca-platform` / the public DOCA SDK
download). Routing to those lives in
[`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md).
Do not invent flags, GPI symbols, RDMA queue attributes, or
expected latency literals beyond what those sources document.
