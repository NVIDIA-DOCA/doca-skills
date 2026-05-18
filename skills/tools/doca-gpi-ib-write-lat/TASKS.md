# DOCA GPI ib_write_lat — Tasks

**Where to start:** The verbs that carry real workflow content
are `## configure`, `## build`, `## run`, `## test`, and
`## debug`. The other verbs (`install`, `modify`, `use`) carry
routing stubs or short integration shapes; `install` is owned
by [`doca-setup`](../../doca-setup/SKILL.md) and the GPI
library skill's preconditions, `modify` refuses to patch the
shipped tool source, and `use` describes how a result from
this benchmark feeds a class-of-workload decision rather than
a direct integration step.

This file is loaded by [`SKILL.md`](SKILL.md) after
[`CAPABILITIES.md`](CAPABILITIES.md). It walks the agent
through the task verbs every artifact in this bundle exposes
(`install / configure / build / modify / run / test / debug /
use`), then explicitly defers task verbs that do not belong
here.

## install

Goal: confirm the user's host has every precondition the
build + run sequence needs **before** any GPI-specific work
begins.

This skill does **not** own DOCA installation; that path
lives in [`doca-setup`](../../doca-setup/SKILL.md). The
`gpi_ib_write_lat`-specific preconditions the agent verifies
after a DOCA install:

1. **`doca-gpi.pc` is present and resolves.** Run `pkg-config
   --modversion doca-gpi` on the build host. If the `.pc`
   does not resolve, the installed DOCA package set does not
   include GPI; route to
   [`../../libs/doca-gpi/TASKS.md#install`](../../libs/doca-gpi/TASKS.md#install)
   for the package-name lookup and re-install path.
2. **Supporting `.pc` files agree on the same DOCA semver.**
   The tool's `meson.build` also pulls in `doca-rdma` and
   `doca-common`; the four-way match in
   [`doca-version CAPABILITIES.md ## Version compatibility`](../../doca-version/CAPABILITIES.md#version-compatibility)
   must hold across `doca-common`, `doca-rdma`, and
   `doca-gpi` before the build is attempted.
3. **CUDA Toolkit + `nvcc` are on the build host.** The
   tool's `kernel.cu` is compiled by `nvcc`; confirm
   `nvcc --version` resolves and the toolkit version is the
   one paired with the installed DOCA per the DOCA release
   notes (looked up via
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)).
4. **GPU is visible to the host.** `nvidia-smi` lists the
   GPU and reports its PCIe bus ID. A host without a GPU
   cannot run this benchmark regardless of how cleanly DOCA
   installs.
5. **IB device is visible to DOCA.** `doca_caps --list-devs`
   (per
   [`../doca-caps/TASKS.md#run`](../doca-caps/TASKS.md#run))
   reports the IB device the user plans to pass via
   `-d <ibdev>`. If the device is missing, the bring-up
   path is environmental; route through
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug).
6. **OOB connectivity exists between client and server.**
   The two halves negotiate the queue + memory descriptor
   over a TCP socket; the IP address the client uses for
   `-c <ip>` must be reachable on the host network with
   the server's default listen port (the source declares it
   as `5000`).

If any precondition fails, **stop and route**; a tool-level
diagnosis against a half-installed DOCA, a missing CUDA
toolkit, or an absent GPU wastes the user's time.

## configure

Goal: pick the right GPU + IB device pair, confirm the
runtime-surface choice (GPI vs GPUNetIO vs CPU-initiated
`perftest`), and prepare the build tree under
`doca/tools/gpi_ib_write_lat/`.

Steps the agent should walk the user through, in order:

1. **Confirm the runtime-surface choice.** Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   surface-selection table with the user. *"Pick GPI because
   the user said GPU"* is the canonical bait; the GPI vs
   GPUNetIO vs CPU-initiated decision is about which
   programming surface the application will actually run on.
   If the user has not committed, this is the moment to
   surface that choice; do not silently default to GPI.
2. **Identify the GPU + IB device pair and check the
   pairing.** Run `nvidia-smi --query-gpu=pci.bus_id` on the
   GPU side and `ibdev2netdev -v` (or
   `doca_caps --list-devs`) on the IB side. Confirm both
   PCIe addresses sit under the same root complex or are
   bridged by an NVLink path the platform documents per
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes).
   If the pairing is wrong, fix the platform — do not tune
   the benchmark around it.
3. **Pick the GID index.** The `--gid-index` flag is
   optional but the right value is GID-routing-rule-specific
   per
   [`../../libs/doca-rdma/CAPABILITIES.md`](../../libs/doca-rdma/CAPABILITIES.md).
   Defaulting silently is a common cause of layer-5 errors
   (connection comes up but the queue-side rejects the
   write); the agent surfaces the rule and asks the user.
4. **Pick the client / server roles and OOB IP.** The server
   runs the binary without `-c`; the client runs the same
   binary with `-c <server-ip>`. The IP is the server's
   reachable address on the OOB network, not on the IB
   fabric.
5. **Confirm the build inputs.** The tool builds under
   `doca/tools/gpi_ib_write_lat/` against the installed
   DOCA's `pkg-config` modules. The build environment must
   carry the right `PKG_CONFIG_PATH` for the install layout
   per
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
   the agent does not invent the path, the user reads it
   from the install.

For the canonical DOCA universal lifecycle that underlies
program-side configuration (which the binary itself runs
internally per the GPI library), see
[`doca-programming-guide TASKS.md ## configure`](../../doca-programming-guide/TASKS.md#configure).
This skill is concerned with the *operator*-side
configuration of the build and the invocation, not the
program-side lifecycle of the libraries the tool uses.

## build

The tool is **not pre-built** under `/opt/mellanox/doca/`;
the user builds it from source under
`doca/tools/gpi_ib_write_lat/` against the installed DOCA.
The build pattern is the canonical `meson` flow:

1. **Set the right `PKG_CONFIG_PATH`** so `pkg-config` can
   find `doca-gpi.pc`, `doca-rdma.pc`, and `doca-common.pc`.
   On a stock install the path lives under the DOCA
   `pkgconfig` directory documented in
   [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md);
   the agent points the user there rather than inventing
   the literal path.
2. **Set up the build directory.** `meson setup <build-dir>
   doca/tools/gpi_ib_write_lat/` from the workspace root.
   `meson` resolves the `dependency('doca-gpi', ...)` and
   `dependency('doca-rdma', ...)` lines in the tool's
   `meson.build` plus the CUDA dependency.
3. **Compile.** `meson compile -C <build-dir>` produces the
   `gpi_ib_write_lat` binary (the exact target name is
   declared in the tool's `meson.build`; the agent re-reads
   it on the user's install rather than quoting from
   memory).
4. **Smoke the build artifact.** Run `<binary> --help` on
   the build host before deploying. If `--help` does not
   resolve, the build did not produce the expected
   artifact — re-route to
   [`## debug`](#debug) layer 2.

Routing for nearby "build" questions:

- *"Can I build the tool against a different DOCA than the
  one I have installed?"* → no, not through this skill. The
  install is the version anchor per
  [`doca-version`](../../doca-version/SKILL.md); if the user
  wants a different DOCA, they install a different DOCA
  first (or use the NGC DOCA container per
  [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)).
- *"I want to build my own GPI-based latency benchmark from
  scratch."* → not a `gpi_ib_write_lat` question. Route to
  [`../../libs/doca-gpi/TASKS.md#build`](../../libs/doca-gpi/TASKS.md#build)
  and
  [`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build);
  the shipped tool is the worked example, not the only
  legitimate build.

The `## What this skill deliberately does not ship` block
in [`SKILL.md`](SKILL.md) explicitly forbids adding a
verbatim build recipe; revisit that policy before changing
this section.

## modify

**Do not patch the shipped `gpi_ib_write_lat` source tree
inside this skill's recommended workflow.** The shipped
`main.c`, `perftest.c`, `kernel.cu`, `oob_socket.c`, and
`common.h` are the verified worked example for this
benchmark class; modifying them puts the user in
*contributor-to-DOCA* territory, not external-consumer
territory, and the safety + version overlays in this skill
assume the shipped scaffolding.

What the agent *does* modify, every time, is the **build +
invocation environment** — the `PKG_CONFIG_PATH`, the
chosen GPU + IB device pair, the GID index, the client /
server roles, the OOB IP, the run-time environment variables
(`DOCA_LOG_LEVEL`, `CUDA_VISIBLE_DEVICES`). Treat *"modify
the environment, not the source"* as the operating mode.

Routing for nearby "modify" questions:

- *"The reported columns are inconvenient — can I change
  them?"* → no, that is a source-level change to the
  shipped tool. If the user wants different columns, the
  right answer is *"author a bespoke GPI-based benchmark
  per
  [`../../libs/doca-gpi/TASKS.md#use`](../../libs/doca-gpi/TASKS.md#use)*"
  — not a patch to the shipped source.
- *"I want to add a new message-size column."* → out of
  scope for this skill; it would be a contribution to the
  shipped DOCA tool, not an external consumer task.
- *"I need a different measurement than this tool
  reports."* → re-examine the runtime-surface choice in
  [`## configure`](#configure) step 1 (maybe the user
  actually wants `doca-gpunetio-ib-write-bw` instead),
  then route to
  [`doca-programming-guide`](../../doca-programming-guide/SKILL.md)
  if the user genuinely needs a bespoke benchmark.

## run

The smoke-before-bulk flow — every session goes through it,
no exceptions. The detailed flag surface lives in the
binary's `--help` on the installed build; this section names
the *shape* of the flow, not the verbatim command lines.

1. **Confirm the build artifact and the environment.** Per
   [`## install`](#install) and [`## configure`](#configure).
   Without this, the next steps will burn the operator's
   time on a misconfigured pair.
2. **Bring up the server first.** Pick the host and the IB
   device + GPU pair that will be the server; run the
   binary without `-c`. The server listens on the OOB
   socket (default `5000`) and waits for a client.
3. **Confirm the server's pre-run echo.** The tool logs the
   IB device name, the GPU PCIe address, the GID index, and
   the role at startup. If the echo does not match intent,
   stop now — the client's connect will pin the wrong
   pairing into the result.
4. **Bring up the client.** On the second host, run the
   same binary with `-c <server-ip>`, the same `-d
   <ibdev>` choice on the client side, the same `--gpu
   <bdf>`, and the same `--gid-index` if a non-default was
   used on the server.
5. **Read the single-iteration smoke output.** The result
   line carries `#bytes`, `#iterations`, half-iter,
   full-iter, and CUDA-side usec per
   [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability).
   Verify the numbers are in a defensible order of magnitude
   for the GPU-NIC pair on the topology; if anything looks
   off, loop back to [`## debug`](#debug).
6. **Plan the bulk / swept run** only after the smoke is
   green. The tool's iteration count and message-size
   surface lives in the binary's `--help`; the agent does
   not invent sweep flags from generic CLI patterns.

When recording the run for downstream consumers, write
down: the DOCA `pkg-config --modversion doca-gpi`, the
CUDA Toolkit version (`nvcc --version`), the host platform
(host OS, kernel, NUMA topology, firmware), the GPU model
and its PCIe bus ID, the IB device model and its PCIe bus
ID, the GID index, the exact command lines used on client
and server, and the full unredacted stdout for both halves.
The downstream [`## test`](#test) and [`## debug`](#debug)
workflows depend on those fields.

## test

`gpi_ib_write_lat` is a **measurement tool**, so its
`## test` verb is about *testing the measurement* — i.e.
confirming the numbers are sound and reproducible — not
unit-testing the tool itself.

**`## test` is an iterative loop, not a one-shot pass.** A
run that completes is not the same as a run that produced a
defensible number; each iteration tightens one axis of
measurement soundness (GPU-NIC pairing, IB link health,
warm-up, NUMA placement, cross-run reproducibility,
cross-version delta) and loops back to [`## run`](#run).

The eval-loop overlay (rows apply to every benchmark run,
not just one platform):

| Iteration trigger | What it looks like | What changes next iteration |
| --- | --- | --- |
| Smoke completes; number is far above the NIC's documented one-way latency | Could be PCIe-crossover overhead from a wrong GPU-NIC pair, NUMA thrash, or a real platform property | Re-walk the GPU-NIC pairing per [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes); confirm the pair sits under the same root complex; only then question the NIC. |
| Number swings between runs by > X% | Steady-state not reached; system not at idle; warm-up too short | Lengthen the run (more iterations); confirm no background traffic on the IB link; confirm no concurrent CUDA workload on the GPU. |
| Half-iter and full-iter columns disagree by more than ~2x | A reporting error or a one-sided handshake failure | Re-confirm both halves are at the same DOCA version per [`## debug`](#debug) layer 7; re-confirm the `--gid-index` matches on both sides. |
| Host-side and CUDA-side numbers diverge sharply | The CUDA kernel is not actually on the critical path the operator thinks it is (the host is doing something the kernel was supposed to do, or vice versa) | Re-read [`CAPABILITIES.md ## Observability`](CAPABILITIES.md#observability) CUDA-side timing rule; route to [`../../libs/doca-gpi/TASKS.md#debug`](../../libs/doca-gpi/TASKS.md#debug) for the host-vs-device split. |
| Same invocation produces different numbers on two hosts at the same DOCA version | GPU-NIC pairing, firmware, or kernel parameter delta below DOCA | Capture the (GPU + NIC + topology + firmware) tuple on both hosts; route through [`doca-version TASKS.md ## test`](../../doca-version/TASKS.md#test) before blaming the tool. |
| Same invocation produces different numbers on the same host across DOCA versions | This is a regression signal — provided both tuples are captured | Cross-link both baselines, name the changed fields, route to [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug). |

The agent's rule: every change to the environment re-opens
the loop. Re-running with a different GID index, a different
GPU, or a different DOCA install without re-checking the
warm-up / steady-state / pairing axes is exactly the failure
mode this loop replaces.

**Baseline-capture rule.** When the goal is a baseline (vs
an ad-hoc question), the captured artifact must include the
(DOCA version + CUDA Toolkit + GPU + NIC + topology +
firmware) tuple per
[`CAPABILITIES.md ## Safety policy`](CAPABILITIES.md#safety-policy)
alongside the stdout from both halves. Without all of them,
the baseline cannot be regression-tested later.

This skill does **not** ship a "test fixture" or
pre-recorded expected output. The expected output is
GPU-NIC-pair-specific; pinning one would mislead operators
on a different platform.

## debug

When `gpi_ib_write_lat` fails to build, fails to bring up
the connection, or produces numbers that do not look
defensible, walk the
[`CAPABILITIES.md ## Error taxonomy`](CAPABILITIES.md#error-taxonomy)
layers in order. The shape of the diagnosis:

1. **Config-syntax.** Invocation does not parse. Confirm
   the flag exists in `--help` on the installed binary
   (not a blog or older release). Confirm the `-d`/`--gpu`/`-c`/`--gid-index`
   values are well-formed; do not infer from generic CLI
   knowledge.
2. **Build-time.** Re-route through
   [`## build`](#build) and the GPI library's
   [`../../libs/doca-gpi/TASKS.md#install`](../../libs/doca-gpi/TASKS.md#install)
   verification. Common cause: `doca-gpi.pc` not on
   `PKG_CONFIG_PATH`, `nvcc` not on `PATH`, GLIBC mismatch.
3. **GPU-NIC pairing.** Walk
   [`CAPABILITIES.md ## Capabilities and modes`](CAPABILITIES.md#capabilities-and-modes)
   GPU-NIC pairing rule; re-confirm both PCIe addresses on
   the platform; if the pairing is wrong, the fix is
   platform-side, not benchmark-side.
4. **GPI-lifecycle.** A `DOCA_ERROR_BAD_STATE` from the
   bring-up sequence almost always means the GPU datapath
   was not assigned before `doca_ctx_start()`. Route to
   [`../../libs/doca-gpi/CAPABILITIES.md#error-taxonomy`](../../libs/doca-gpi/CAPABILITIES.md#error-taxonomy)
   and
   [`../../libs/doca-gpi/TASKS.md#debug`](../../libs/doca-gpi/TASKS.md#debug).
5. **RDMA-connection.** The OOB socket connected but the
   queue did not. Confirm the GID index matches between
   client and server; confirm the IB link is up
   (`ibstat`); confirm the RDMA permission flags include
   WRITE per
   [`../../libs/doca-rdma/CAPABILITIES.md`](../../libs/doca-rdma/CAPABILITIES.md).
6. **Measurement-soundness.** The run completes; the
   number is unsound. Walk the
   [`## test`](#test) eval loop; confirm warm-up applied;
   confirm the right column was quoted.
7. **Version.** Cross-cutting partial-install / mixed-
   version. Walk
   [`doca-version TASKS.md ## debug`](../../doca-version/TASKS.md#debug)
   end-to-end; confirm the same DOCA + CUDA Toolkit pair
   was used to build both client and server.
8. **Cross-cutting.** Cause is below DOCA. Hand off to
   [`doca-debug TASKS.md ## debug`](../../doca-debug/TASKS.md#debug)
   and
   [`doca-setup TASKS.md ## debug`](../../doca-setup/TASKS.md#debug).

In every case: **quote what the binary reported.** Do not
paraphrase the stdout, do not reorder columns, do not
*"summarize"* a sweep into a single number. The tool is in
the loop precisely to break the agent out of the
inference-from-datasheet trap.

## use

Goal: turn a captured result from this benchmark into a
class-of-workload decision — *"is the GPI path the right
runtime surface for my workload?"*.

The decision shape this skill teaches:

1. **Quote the right column.** Use the half-iter usec for
   one-way latency comparisons; use the full-iter usec for
   request-response patterns. Quoting the wrong column is
   the cross-tool comparison failure mode that breaks any
   downstream decision.
2. **Compare against the right alternative.** If the
   workload class is *"GPU-initiated WRITE for a
   request-response pattern"*, the alternative this
   benchmark answers is *"the same pattern on the GPUNetIO
   surface"* per
   [`../doca-gpunetio-ib-write-lat/SKILL.md`](../doca-gpunetio-ib-write-lat/SKILL.md);
   if the alternative is *"the same pattern on the host
   CPU"*, the comparison data has to come from the upstream
   `perftest` `ib_write_lat` separately (the agent does
   not synthesize the CPU number).
3. **Apply the GPU-NIC pairing precondition to the
   downstream design.** A latency that wins on this
   benchmark only carries over to the production workload
   if the production GPU-NIC pair sits on the same PCIe /
   NVLink topology as the test bed. The agent surfaces
   that constraint to the user before recommending the
   GPI path for production.
4. **Per-release re-verification.** Because the GPI surface
   is a stability mix (per
   [`../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes`](../../libs/doca-gpi/CAPABILITIES.md#capabilities-and-modes)),
   every DOCA upgrade — and every CUDA Toolkit upgrade —
   requires re-running this benchmark before re-quoting the
   number. The agent does not assume a known-good number
   survives a DOCA-version bump or a CUDA-Toolkit bump
   without re-testing.
5. **Hand off to the application's own benchmark for the
   final answer.** This tool measures the latency of one
   RDMA WRITE on the GPI surface; the user's application
   sits *above* one RDMA WRITE and has its own latency
   contributors. The right *final* answer for *"will my
   application be fast enough"* is an application-level
   benchmark that uses GPI in the same shape the
   application will; this tool is the *floor*, not the
   forecast.

## Deferred task verbs

The verbs below are not `gpi_ib_write_lat` work and should
be routed out before the agent does any of them under this
skill's name.

- **install DOCA** ⇒ [`doca-setup TASKS.md`](../../doca-setup/TASKS.md)
  (and
  [`doca-setup TASKS.md ## no-install`](../../doca-setup/TASKS.md#no-install)
  for the public NGC DOCA container path). This skill does
  not own the DOCA install workflow.
- **author a bespoke GPI-based benchmark** ⇒
  [`../../libs/doca-gpi/TASKS.md#use`](../../libs/doca-gpi/TASKS.md#use)
  for the per-application integration shape and
  [`doca-programming-guide TASKS.md ## build`](../../doca-programming-guide/TASKS.md#build)
  for the cross-library build pattern.
- **CPU-initiated WRITE latency** ⇒ the upstream `perftest`
  `ib_write_lat` (not in this bundle, not in
  `doca/tools/`). Route via
  [`doca-public-knowledge-map`](../../doca-public-knowledge-map/SKILL.md)
  to the public RDMA / `perftest` docs.
- **GPU-initiated WRITE bandwidth** ⇒
  [`../doca-gpunetio-ib-write-bw/SKILL.md`](../doca-gpunetio-ib-write-bw/SKILL.md).
  This tool measures latency; bandwidth is a different
  metric class.
- **GPUNetIO WRITE latency (same physical operation,
  different runtime framework)** ⇒
  [`../doca-gpunetio-ib-write-lat/SKILL.md`](../doca-gpunetio-ib-write-lat/SKILL.md).
- **hardware-touching changes the benchmark surfaced a
  need for** (BlueField BFB reflash, firmware burn on the
  NIC, kernel command-line changes for IOMMU mode) ⇒
  [`doca-hardware-safety`](../../doca-hardware-safety/SKILL.md).
  This skill names the need; the meta-policy owns the
  change discipline.
