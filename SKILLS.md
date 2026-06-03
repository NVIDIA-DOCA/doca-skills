# Skill index

**Where to start:** Match the user's request against the *trigger*
column below, load the matching `SKILL.md`, then follow the *Where
to start* header at the top of each skill to pick the right next
file (`CAPABILITIES.md` for "what can it do", `TASKS.md` for "how do
I do it"). If the user has not installed DOCA yet, start with
[`doca-setup`](skills/doca-setup/SKILL.md). If the request is *"what
does DOCA cover"* or *"where is the doc for X"*, start with
[`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md).

Skills installed in this repository. Each row gives the skill ID, where to
find its source file, and a one-line trigger for when an agent should load it.

For the discovery convention and ground rules every agent must follow, see
[AGENTS.md](AGENTS.md).

## Layout

Skills live under `skills/` (top-level, vendor-neutral path — not
under any agent-runtime-specific directory), layered by *kind of
artifact* the skill is about:

```
skills/
├── doca-public-knowledge-map/   # cross-cutting routing skill (knowledge)
├── doca-setup/                   # cross-cutting env skill        (library-shape)
├── doca-programming-guide/       # cross-cutting programming skill (library-shape)
├── doca-debug/                   # cross-cutting debug skill      (library-shape)
├── doca-version/                 # cross-cutting version skill    (library-shape)
├── doca-structured-tools-contract/ # cross-cutting JSON-contract skill
├── doca-hardware-safety/         # cross-cutting hardware-safety meta-policy
├── doca-upgrade/                 # cross-cutting upgrade/downgrade discipline (detect → report → ASK → guided)
├── doca-container-deployment/    # cross-cutting service-container deployment path
├── doca-bare-metal-deployment/   # cross-cutting bare-metal-binary deployment path (sibling of container-deployment)
├── libs/<library>/               # one skill per doca/libs/<library>
├── services/<service>/           # one skill per doca/services/<service>
└── tools/<tool>/                 # one skill per doca/tools/<tool>
```

The cross-cutting skills sit at the top level because they apply *across*
libraries / services / tools. Per-artifact skills live under the matching
subdirectory, **strictly 1:1 with `doca/{libs,services,tools}`** at the
DOCA release the bundle is aligned to. Every bundle release is verified
to preserve this 1:1 alignment before it ships, so the bundle is always
in lock-step with the named DOCA release.

This is a *physical* convention only — agents discover skills by their
`name:` (declared in each `SKILL.md`'s YAML frontmatter), and cross-link
labels of the form `[<skill-name> ## <anchor>]` resolve by name regardless
of where the skill lives in the tree. Reorganizing the tree later does not
break agent discovery.

## Index

### Top-level cross-cutting skills (10)

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-public-knowledge-map` | [skills/doca-public-knowledge-map/SKILL.md](skills/doca-public-knowledge-map/SKILL.md) | The user asks anything about DOCA where you need to locate authoritative documentation, installed package paths, downloads, samples, the developer forum, the public DOCA services / tools index, or how to find the installed DOCA version — without access to the DOCA source repository. |
| `doca-setup` | [skills/doca-setup/SKILL.md](skills/doca-setup/SKILL.md) | Env-class + deployment-routing front door. The user is installing DOCA, verifying the install, preparing the build env (`pkg-config`, headers, hugepages, devlink), debugging an env-class failure, OR asking a deployment-shaped question (*"how do I deploy"*, *"my code is built, how do I run it"*, *"I just got a BlueField, what now"*) — the `## recognize` anchor here is the bundle's **front-door routing decision** that detects the system shape, asks the minimum residual dev-Q, and routes to either `doca-container-deployment` or `doca-bare-metal-deployment`. Also owns the *I'm on macOS / Windows / Linux without DOCA* path (canonical Stage-1: the public NGC DOCA container `nvcr.io/nvidia/doca/doca`). Hands off to `doca-programming-guide` once env is healthy. **Headline contract: never scaffold DOCA code (`main.c` / `Makefile` / `Dockerfile`) for the user before they have an install — this skill's `## no-install` is the canonical pre-install routing.** |
| `doca-programming-guide` | [skills/doca-programming-guide/SKILL.md](skills/doca-programming-guide/SKILL.md) | The user has a healthy DOCA env and is asking a general DOCA programming question — the canonical `pkg-config doca-<library>` build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, or the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. |
| `doca-debug` | [skills/doca-debug/SKILL.md](skills/doca-debug/SKILL.md) | The user is debugging anything DOCA-related across layers — build → link → runtime → program → driver. Provides the canonical layered debug ladder, the cross-cutting tooling reference (`gdb`, `valgrind`, `ldd`, `strace`, `dmesg`, `--sdk-log-level`, the `doca-<lib>-trace` build flavor, container introspection, core dumps), and the escalation to the public Developer Forum. Library skills overlay their library-specific debug on top. |
| `doca-version` | [skills/doca-version/SKILL.md](skills/doca-version/SKILL.md) | Any question that depends on a DOCA version, BFB version, container tag, or host↔DPU↔container pairing. Every per-artifact skill's `## Version compatibility` anchor redirects here so the rule is stated once and reused. |
| `doca-structured-tools-contract` | [skills/doca-structured-tools-contract/SKILL.md](skills/doca-structured-tools-contract/SKILL.md) | The agent is about to emit JSON for any infra step (env probe, hardware probe, version detect, NGC promote, build flags). This skill ships the JSON schemas the future infra tools will validate against. |
| `doca-hardware-safety` | [skills/doca-hardware-safety/SKILL.md](skills/doca-hardware-safety/SKILL.md) | The agent is about to recommend a change that touches DPU / NIC hardware state (`mlxconfig`, firmware burn, BlueField mode flip, BAR change, IOMMU mode, hugepages, BFB reflash). Meta-policy: pre-flight inventory, OOB requirement, maintenance window, rollback discipline, replica-first validation. Every per-artifact `## Safety policy` cross-links here. |
| `doca-upgrade` | [skills/doca-upgrade/SKILL.md](skills/doca-upgrade/SKILL.md) | The user is contemplating or recovering a DOCA upgrade / downgrade — moving a host to the next release, refreshing the BFB, bumping an NGC container tag, rolling back, or reacting to an accidental `apt upgrade` drift. Headline discipline: **detect → report → ASK → only-then guided upgrade; never auto-upgrade.** Routes version detection to `doca-version`, every hardware/firmware/reboot step to `doca-hardware-safety`, and sunset/deprecation lookups to `doca-public-knowledge-map`. |
| `doca-container-deployment` | [skills/doca-container-deployment/SKILL.md](skills/doca-container-deployment/SKILL.md) | The user is deploying any DOCA service container on BlueField (kubelet-standalone + pod-spec drop). The CONTAINER half of the two-path deployment landscape; the bare-metal half lives in `doca-bare-metal-deployment`. Every in-bundle per-service skill cross-links here. If the developer has NOT yet decided container vs. bare-metal, route them back to `doca-setup ## recognize` first. |
| `doca-bare-metal-deployment` | [skills/doca-bare-metal-deployment/SKILL.md](skills/doca-bare-metal-deployment/SKILL.md) | The user is deploying a DOCA-linked **application binary** directly on hardware — no container — on host x86 (DOCA host install talking to a remote BlueField NIC over PCIe) OR on BlueField Arm bare-metal (DOCA app on the DPU cores). Owns the launch contract (direct / tmux / systemd), hardware-resource binding (PF/VF/representor + NUMA + CPU pinning + IRQ affinity), per-tenant isolation (cgroup-v2 + namespaces + numactl), the bare-metal error taxonomy, observability (stdout / journald / devlink / sysfs), and the restart-loop-is-HIGH-STAKES rule. The BARE-METAL half of the two-path deployment landscape; the container half lives in `doca-container-deployment`. Routed to from `doca-setup ## recognize`. |

### Per-artifact skills (52 — strict 1:1 with `doca/{libs,services,tools}` at the **publicly-released DOCA the bundle is documented for, currently `3.3.0109`** — see README.md "Standards & Compatibility")

This bundle ships one skill per artifact in the DOCA monorepo at the
DOCA release the bundle is aligned to. The agent loads the matching
skill when the user's question is narrow enough to be about that one
artifact. Every row also appears in the
[`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md)
routing tables so the agent can reach the skill from either entry point.

The compact triple table below is the discovery surface every fresh
agent walks. Strict 1:1 alignment with the named DOCA release is
verified on every commit.

**Libraries (28) — `skills/libs/<name>/`, 1:1 with `doca/libs/`** (excluding the internal-only `doca_gpunetio_internal`)

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-common` | [skills/libs/doca-common/SKILL.md](skills/libs/doca-common/SKILL.md) | DOCA Common — the foundation library every other DOCA library depends on: `doca_buf` / `doca_mmap` (zero-copy data plane), `doca_ctx` (universal context lifecycle), `doca_dev` / `doca_dev_rep` (device + representor discovery), `doca_pe` (universal progress engine), `doca_log` (logging primitive). Teaches the primitives ONCE so per-library skills cross-link here. |
| `doca-flow` | [skills/libs/doca-flow/SKILL.md](skills/libs/doca-flow/SKILL.md) | DOCA Flow — port + representor setup, pipes, actions, action memory, entry lifecycle, validation, counters, traces. Folds Flow Connection Tracking as `## flow-ct`. |
| `doca-eth` | [skills/libs/doca-eth/SKILL.md](skills/libs/doca-eth/SKILL.md) | DOCA Ethernet — RX/TX queues, packet I/O. |
| `doca-rdma` | [skills/libs/doca-rdma/SKILL.md](skills/libs/doca-rdma/SKILL.md) | DOCA RDMA — DOCA's RDMA surface (send/recv/write/read patterns). |
| `doca-verbs` | [skills/libs/doca-verbs/SKILL.md](skills/libs/doca-verbs/SKILL.md) | DOCA Verbs — lower-level ibverbs-style API beneath DOCA RDMA / DOCA Eth, exposing raw QP / CQ / PD / MR / SRQ / Address-Handle primitives. Primary job is to ROUTE back to the matching higher-level library; only takes the conversation when the higher-level library does not expose the specific verb / opcode the user needs. |
| `doca-dpa` | [skills/libs/doca-dpa/SKILL.md](skills/libs/doca-dpa/SKILL.md) | DOCA DPA — host/device split-build, DPACC context, DPA annotation. Folds DPA Comms as `## comms` and DPA Verbs as `## verbs`. |
| `doca-flow-dpa-provider` | [skills/libs/doca-flow-dpa-provider/SKILL.md](skills/libs/doca-flow-dpa-provider/SKILL.md) | DOCA Flow DPA Provider — bridges a `doca-flow` pipe into a DPA execution target so flow execution can run on the DPA processor instead of the host or DPU-CPU path. |
| `doca-gpunetio` | [skills/libs/doca-gpunetio/SKILL.md](skills/libs/doca-gpunetio/SKILL.md) | DOCA GPUNetIO — GPU-initiated networking + CUDA integration. |
| `doca-gpi` | [skills/libs/doca-gpi/SKILL.md](skills/libs/doca-gpi/SKILL.md) | DOCA GPI — GPU Programming Interface for kernel-launched RDMA operations directly from a CUDA thread. Pairs with `doca-rdma` and `doca-gpunetio` (different runtime surface for GPU-initiated networking). |
| `doca-comch` | [skills/libs/doca-comch/SKILL.md](skills/libs/doca-comch/SKILL.md) | DOCA Comch (formerly Comm Channel) — host↔DPU control-plane messaging. |
| `doca-telemetry` | [skills/libs/doca-telemetry/SKILL.md](skills/libs/doca-telemetry/SKILL.md) | DOCA Telemetry — per-domain hardware-counter READER (six sub-libs: `_pcc`, `_dpa`, `_diag`, `_adp_retx`, `_phy`, `_pci`). Not a NetFlow / IPFIX / DTS-shaped collector framework — for OpenTelemetry / OTLP application-side publishing route to `doca-telemetry-exporter`; for DTS (the productized service) route to the external DTS docs (out of scope). |
| `doca-telemetry-exporter` | [skills/libs/doca-telemetry-exporter/SKILL.md](skills/libs/doca-telemetry-exporter/SKILL.md) | DOCA Telemetry Exporter — application-side publish library. |
| `doca-dma` | [skills/libs/doca-dma/SKILL.md](skills/libs/doca-dma/SKILL.md) | DOCA DMA — host↔DPU memory copy via the BlueField DMA engine. |
| `doca-compress` | [skills/libs/doca-compress/SKILL.md](skills/libs/doca-compress/SKILL.md) | DOCA Compress — hardware-accelerated compression / decompression. |
| `doca-aes-gcm` | [skills/libs/doca-aes-gcm/SKILL.md](skills/libs/doca-aes-gcm/SKILL.md) | DOCA AES-GCM — hardware-accelerated AES-GCM. |
| `doca-sha` | [skills/libs/doca-sha/SKILL.md](skills/libs/doca-sha/SKILL.md) | DOCA SHA — hardware-accelerated SHA hashing. |
| `doca-erasure-coding` | [skills/libs/doca-erasure-coding/SKILL.md](skills/libs/doca-erasure-coding/SKILL.md) | DOCA Erasure Coding — hardware-accelerated EC (RS / similar). |
| `doca-apsh` | [skills/libs/doca-apsh/SKILL.md](skills/libs/doca-apsh/SKILL.md) | DOCA App Shield (library) — process-introspection primitives. |
| `doca-pcc` | [skills/libs/doca-pcc/SKILL.md](skills/libs/doca-pcc/SKILL.md) | DOCA PCC (library) — programmable congestion control (DPA-hosted). |
| `doca-pcc-ztr-rttcc-algo` | [skills/libs/doca-pcc-ztr-rttcc-algo/SKILL.md](skills/libs/doca-pcc-ztr-rttcc-algo/SKILL.md) | DOCA PCC ZTR-RTTCC Algorithm — the shipped reference congestion-control algorithm (Zero-Touch-RTT-CC) that runs under doca-pcc. Pairs with `doca-pcc` (host) and `doca-pcc-counters` (observability). |
| `doca-urom` | [skills/libs/doca-urom/SKILL.md](skills/libs/doca-urom/SKILL.md) | DOCA UROM (library) — Unified Communication Remote Memory Operations. |
| `doca-argp` | [skills/libs/doca-argp/SKILL.md](skills/libs/doca-argp/SKILL.md) | DOCA Arg Parser — argument parser used by every shipped sample. |
| `doca-devemu` | [skills/libs/doca-devemu/SKILL.md](skills/libs/doca-devemu/SKILL.md) | DOCA Device Emulation — umbrella for PCI Generic, virtio, virtio-fs. |
| `doca-mgmt` | [skills/libs/doca-mgmt/SKILL.md](skills/libs/doca-mgmt/SKILL.md) | DOCA MGMT (Management library) — programmatic management of DOCA device state. Pairs with `doca-dms` (service-side) and `doca-version`. |
| `doca-rdmi` | [skills/libs/doca-rdmi/SKILL.md](skills/libs/doca-rdmi/SKILL.md) | DOCA RDMI (DOCA RDMA Initiator) — accelerator-initiated (host or DPA-kernel) one-sided RDMA flow surface; pairs with `doca-rdma` (general RDMA) and `doca-dpa` / `doca-verbs` for the DPA-kernel-initiated path. |
| `doca-sta` | [skills/libs/doca-sta/SKILL.md](skills/libs/doca-sta/SKILL.md) | DOCA STA — storage-focused reference apps + storage transport acceleration. |
| `doca-rmax` | [skills/libs/doca-rmax/SKILL.md](skills/libs/doca-rmax/SKILL.md) | DOCA Rivermax — media / streaming integration. |
| `doca-dpdk-bridge` | [skills/libs/doca-dpdk-bridge/SKILL.md](skills/libs/doca-dpdk-bridge/SKILL.md) | DOCA DPDK Bridge — interop layer for an existing DPDK application to reach DOCA libraries. |

**Services (6) — `skills/services/<name>/`, 1:1 with `doca/services/`**

The doca-skills bundle is strict 1:1 with `doca/services/` (excluding
the shared infra dirs `base_image` and `framework`, which are not
user-facing services). External NVIDIA productized services that are
**not** in `doca/services/` (e.g. HBN, BlueMan, SNAP, Virtio-net,
Telemetry-Service-as-deployed) are intentionally out of scope — see
[AGENTS.md `## Non-goals`](AGENTS.md#non-goals-questions-the-agent-should-recognize-and-refuse-politely).

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-dms` | [skills/services/doca-dms/SKILL.md](skills/services/doca-dms/SKILL.md) | DOCA Management Service — gNMI / gNOI config + ops over gRPC. |
| `doca-firefly` | [skills/services/doca-firefly/SKILL.md](skills/services/doca-firefly/SKILL.md) | DOCA Firefly Service — PTP / time-sync. |
| `doca-flow-inspector` | [skills/services/doca-flow-inspector/SKILL.md](skills/services/doca-flow-inspector/SKILL.md) | DOCA Flow Inspector Service — mirrored-flow inspection. |
| `doca-urom-svc` | [skills/services/doca-urom-svc/SKILL.md](skills/services/doca-urom-svc/SKILL.md) | DOCA UROM Service — paired with `libs/doca-urom`. `-svc` suffix per AUTHORING § 17 collision rule. |
| `doca-argus` | [skills/services/doca-argus/SKILL.md](skills/services/doca-argus/SKILL.md) | DOCA Argus Service — runtime-security / monitoring on BlueField. |
| `doca-os-inspector` | [skills/services/doca-os-inspector/SKILL.md](skills/services/doca-os-inspector/SKILL.md) | DOCA OS Inspector Service — DPU-side out-of-band host-OS introspection container. Service wrapper for apsh-class capabilities; pairs with `doca-apsh` (library), `doca-apsh-config` (profile generation), and `doca-container-deployment`. |

**Tools (17) — `skills/tools/<name>/`, 1:1 with `doca/tools/`**

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-caps` | [skills/tools/doca-caps/SKILL.md](skills/tools/doca-caps/SKILL.md) | DOCA Capabilities Print Tool — side-effect-free snapshot of what DOCA sees on this host (devices, representors, supported libraries, per-device capabilities, log registries). |
| `doca-bench` | [skills/tools/doca-bench/SKILL.md](skills/tools/doca-bench/SKILL.md) | DOCA Bench — performance evaluation harness for the built-in workload modes. |
| `doca-bench-extension` | [skills/tools/doca-bench-extension/SKILL.md](skills/tools/doca-bench-extension/SKILL.md) | DOCA Bench Extension — the in-tree extension / plug-in framework that lets `doca-bench` measure workload classes its built-in modes do not cover. Reference exemplar `doca_bench_cuda` drives GPUNetIO RX / TX kernels. |
| `doca-comm-channel-admin` | [skills/tools/doca-comm-channel-admin/SKILL.md](skills/tools/doca-comm-channel-admin/SKILL.md) | Comm Channel Admin Tool — admin CLI for Comch channels. |
| `doca-flow-tune` | [skills/tools/doca-flow-tune/SKILL.md](skills/tools/doca-flow-tune/SKILL.md) | DOCA Flow Tune — unified tool for offline / online tuning of a live `doca-flow` pipeline. ONE binary with TWO internal roles (server role: snapshots and exposes pipe / counter / KPI state; client / consumer role: dumps / analyzes / visualizes / recommends). |
| `doca-flow-perf` | [skills/tools/doca-flow-perf/SKILL.md](skills/tools/doca-flow-perf/SKILL.md) | DOCA Flow Perf — host / DPU-CPU control-plane rule-rate measurement (install / delete / query rate). Distinct from `doca-flow-dpa-perf` (DPA-offloaded path) and `doca-flow-tune` (optimizes a deployed pipeline). |
| `doca-flow-dpa-perf` | [skills/tools/doca-flow-dpa-perf/SKILL.md](skills/tools/doca-flow-dpa-perf/SKILL.md) | DOCA Flow DPA Perf — flow performance for the DPA-offloaded execution path. |
| `doca-flow-grpc-server` | [skills/tools/doca-flow-grpc-server/SKILL.md](skills/tools/doca-flow-grpc-server/SKILL.md) | DOCA Flow gRPC Server — gRPC remote-control server for `doca-flow` rule programming. |
| `doca-pcc-counters` | [skills/tools/doca-pcc-counters/SKILL.md](skills/tools/doca-pcc-counters/SKILL.md) | DOCA PCC Counters — the `pcc_counters.sh` script arms (`set`) and reads (`query`) the device's firmware/HW PCC diagnostic counters via mst + the mlx5 debugfs `diag_cnt` interface. |
| `doca-socket-relay` | [skills/tools/doca-socket-relay/SKILL.md](skills/tools/doca-socket-relay/SKILL.md) | DOCA Socket Relay — socket relay between host and DPU. |
| `doca-apsh-config` | [skills/tools/doca-apsh-config/SKILL.md](skills/tools/doca-apsh-config/SKILL.md) | DOCA App Shield Config — generates the host-OS profile / symbol files that `doca-apsh` and `doca-os-inspector` need to interpret host kernel state. Without a current profile, apsh-class introspection returns garbage. |
| `doca-dpa-hl-tracer` | [skills/tools/doca-dpa-hl-tracer/SKILL.md](skills/tools/doca-dpa-hl-tracer/SKILL.md) | DOCA DPA High-Level Tracer — captures DPA-side execution traces with higher-level events than raw cycle counts. |
| `doca-gpunetio-ib-write-bw` | [skills/tools/doca-gpunetio-ib-write-bw/SKILL.md](skills/tools/doca-gpunetio-ib-write-bw/SKILL.md) | DOCA GPUNetIO ib_write_bw — RDMA-write bandwidth benchmark from the GPUNetIO framework. |
| `doca-gpunetio-ib-write-lat` | [skills/tools/doca-gpunetio-ib-write-lat/SKILL.md](skills/tools/doca-gpunetio-ib-write-lat/SKILL.md) | DOCA GPUNetIO ib_write_lat — RDMA-write latency benchmark from the GPUNetIO framework. |
| `doca-sha-offload-engine` | [skills/tools/doca-sha-offload-engine/SKILL.md](skills/tools/doca-sha-offload-engine/SKILL.md) | DOCA SHA Offload Engine — OpenSSL ENGINE wrapping the DOCA SHA library; lets unmodified OpenSSL-based applications offload SHA without code changes. |
| `doca-spcx-cc` | [skills/tools/doca-spcx-cc/SKILL.md](skills/tools/doca-spcx-cc/SKILL.md) | DOCA SPCX-CC — Programmable Congestion-Control extension (next-gen). Pairs with `doca-pcc`, `doca-pcc-ztr-rttcc-algo`. Live-fabric safety implications: heavy use of `doca-hardware-safety`. |
| `doca-telemetry-utils` | [skills/tools/doca-telemetry-utils/SKILL.md](skills/tools/doca-telemetry-utils/SKILL.md) | DOCA Telemetry Utils — operator-side support CLI for a DOCA Telemetry exporter pipeline. Translates name ↔ Data ID, enumerates the diagnostic-counter schema, and probes per-device counter support before an exporter config commits to it. |

## Adding a new skill

Adding or modifying a skill is governed by NVIDIA's internal author
contract. External consumers of this bundle do not need to author
skills themselves — the bundle already carries the 1:1-aligned skill
for every public DOCA library, service, and tool at the currently-
aligned DOCA release, and every new release brings the matching
skills along with it as part of the bundle alignment.
