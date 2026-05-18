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
├── libs/<library>/               # one skill per DOCA library
├── services/<service>/           # one skill per DOCA service
└── tools/<tool>/                 # one skill per DOCA tool
```

The three cross-cutting skills (knowledge map, setup, programming guide)
sit at the top level because they apply *across* libraries / services /
tools. Per-artifact skills live under the matching subdirectory.

This is a *physical* convention only — agents discover skills by their
`name:` (declared in each `SKILL.md`'s YAML frontmatter), and cross-link
labels of the form `[<skill-name> ## <anchor>]` resolve by name regardless
of where the skill lives in the tree. Reorganizing the tree later does not
break agent discovery.

## Index

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-public-knowledge-map` | [skills/doca-public-knowledge-map/SKILL.md](skills/doca-public-knowledge-map/SKILL.md) | The user asks anything about DOCA where you need to locate authoritative documentation, installed package paths, downloads, samples, the developer forum, the public DOCA services / tools index, or how to find the installed DOCA version — without access to the DOCA source repository. |
| `doca-setup` | [skills/doca-setup/SKILL.md](skills/doca-setup/SKILL.md) | Env-class only. The user is installing DOCA, verifying the install, preparing the build env (`pkg-config`, headers, hugepages, devlink), debugging an env-class failure, or asking *I'm on macOS / Windows / Linux without DOCA — how do I reach an install?* (the canonical Stage-1 answer is the public NGC DOCA container `nvcr.io/nvidia/doca/doca`, alongside lab-host, cloud-Linux, and hardware paths). Hands off to `doca-programming-guide` once the env is healthy. **Headline contract: never scaffold DOCA code (`main.c` / `Makefile` / `Dockerfile`) for the user before they have an install — this skill's `## no-install` is the canonical pre-install routing.** |
| `doca-programming-guide` | [skills/doca-programming-guide/SKILL.md](skills/doca-programming-guide/SKILL.md) | The user has a healthy DOCA env and is asking a general DOCA programming question — the canonical `pkg-config doca-<library>` build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, or the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. |
| `doca-debug` | [skills/doca-debug/SKILL.md](skills/doca-debug/SKILL.md) | The user is debugging anything DOCA-related across layers — a build that won't compile, a link step that can't resolve a `doca_*` symbol, a runtime call that returns `DOCA_ERROR_*`, a packet not appearing on the wire, a service that won't start, or "how do I get more logs?". Provides the canonical layered debug ladder (install → version → build → link → runtime → program → driver), the cross-cutting tooling reference (`gdb`, `valgrind`, `ldd`, `strace`, `dmesg`, `--sdk-log-level`, the `doca-<lib>-trace` build flavor, container introspection, core dumps), and the *Where to ask for help* escalation to the public Developer Forum. `doca-setup ## debug` (env-class half) and `doca-programming-guide ## debug` (program-class half) both escalate here for cross-cutting tooling and ladder shape; library skills overlay their library-specific debug on top. |
| `doca-flow` | [skills/libs/doca-flow/SKILL.md](skills/libs/doca-flow/SKILL.md) | The user is working with DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, Flow counters and traces, Flow version compatibility, or debugging `DOCA_ERROR_*` failures from the Flow API. Builds on `doca-setup` (env) and `doca-programming-guide` (cross-library patterns) and layers Flow specifics on top. |
| `doca-dms` | [skills/services/doca-dms/SKILL.md](skills/services/doca-dms/SKILL.md) | The user is deploying or operating the DOCA Management Service — choosing a deployment shape (host non-DPU / BlueField Arm / Kubernetes pod), launching `dmsd` (SystemD or manual), choosing an authentication mode (localhost / PAM / credentials / mTLS), wiring `dmsgroup` authorization, issuing gNMI Get/Set against modeled YANG paths, issuing gNOI system operations (reboot, OS install, file transfer, `mlxconfig`, `containerz`), or debugging a DMS request layered through transport / auth / path / backend / library failures. Currently beta per the public guide. |
| `doca-caps` | [skills/tools/doca-caps/SKILL.md](skills/tools/doca-caps/SKILL.md) | The user — or the agent itself — needs a side-effect-free, documented snapshot of *what DOCA sees on this host*: enumerating DOCA devices and representors (`--list-devs`, `--list-rep-devs`, `--pci-addr`), listing the DOCA libraries supported on the running OS, listing per-device per-library capabilities, listing DOCA logger names. Available since DOCA 2.6.0; runs on host or BlueField Arm. The canonical first-step capability snapshot called out from `doca-setup ## test` and `doca-programming-guide ## debug`. |

### Cross-cutting top-level skills (added in PR1)

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-version` | [skills/doca-version/SKILL.md](skills/doca-version/SKILL.md) | Any question that depends on a DOCA version, BFB version, container tag, or host↔DPU↔container pairing. Every per-artifact skill's `## Version compatibility` anchor redirects here so the rule is stated once and reused. Cross-link from `doca-setup`, `doca-debug`, every `libs/`/`services/`/`tools/` skill. |
| `doca-structured-tools-contract` | [skills/doca-structured-tools-contract/SKILL.md](skills/doca-structured-tools-contract/SKILL.md) | The agent is about to emit JSON for any infra step (env probe, hardware probe, version detect, NGC promote, build flags). This skill ships the JSON schemas the future infra tools will validate against; today the agent uses them to shape its own structured output. |
| `doca-hardware-safety` | [skills/doca-hardware-safety/SKILL.md](skills/doca-hardware-safety/SKILL.md) | The agent is about to recommend a change that touches DPU / NIC hardware state (`mlxconfig`, firmware burn, BlueField mode flip, BAR change, IOMMU mode, hugepages, BFB reflash). This skill is the meta-policy — pre-flight inventory, OOB requirement, maintenance window, rollback discipline, replica-first validation. Every per-artifact `## Safety policy` anchor cross-links here. |

### Per-artifact skills (51 — one per public DOCA library / service / tool)

This bundle ships one skill per artifact on the public NVIDIA DOCA
SDK index (`https://docs.nvidia.com/doca/sdk/`). The agent loads the
matching skill when the user's question is narrow enough to be about
that one artifact. Every row also appears in the
[`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md)
routing tables so the agent can reach the skill from either entry point.

The complete mapping (skill dir → public SDK page → naming rationale)
is audited in `devops/SKILL-PROVENANCE.md`. The compact triple table
below is the discovery surface every fresh agent walks.

**Libraries (28) — `skills/libs/<name>/`**

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-flow` | [skills/libs/doca-flow/SKILL.md](skills/libs/doca-flow/SKILL.md) | DOCA Flow — port + representor setup, pipes, actions, action memory, entry lifecycle, validation, counters, traces. |
| `doca-flow-ct` | [skills/libs/doca-flow-ct/SKILL.md](skills/libs/doca-flow-ct/SKILL.md) | DOCA Flow Connection Tracking — stateful CT layer on DOCA Flow. |
| `doca-eth` | [skills/libs/doca-eth/SKILL.md](skills/libs/doca-eth/SKILL.md) | DOCA Ethernet — RX/TX queues, packet I/O. |
| `doca-rdma` | [skills/libs/doca-rdma/SKILL.md](skills/libs/doca-rdma/SKILL.md) | DOCA RDMA — DOCA's RDMA surface (send/recv/write/read patterns). |
| `doca-rdma-verbs` | [skills/libs/doca-rdma-verbs/SKILL.md](skills/libs/doca-rdma-verbs/SKILL.md) | DOCA RDMA Verbs — lower-level verbs surface beneath DOCA RDMA. |
| `doca-dpa` | [skills/libs/doca-dpa/SKILL.md](skills/libs/doca-dpa/SKILL.md) | DOCA DPA — host/device split-build, DPACC context, DPA annotation. |
| `doca-dpa-comms` | [skills/libs/doca-dpa-comms/SKILL.md](skills/libs/doca-dpa-comms/SKILL.md) | DOCA DPA Comms — DPA-side communication primitives. |
| `doca-dpa-verbs` | [skills/libs/doca-dpa-verbs/SKILL.md](skills/libs/doca-dpa-verbs/SKILL.md) | DOCA DPA Verbs — DPA-side verbs surface. |
| `doca-gpunetio` | [skills/libs/doca-gpunetio/SKILL.md](skills/libs/doca-gpunetio/SKILL.md) | DOCA GPUNetIO — GPU-initiated networking + CUDA integration. |
| `doca-comch` | [skills/libs/doca-comch/SKILL.md](skills/libs/doca-comch/SKILL.md) | DOCA Comch (formerly Comm Channel) — host↔DPU control-plane messaging. |
| `doca-telemetry` | [skills/libs/doca-telemetry/SKILL.md](skills/libs/doca-telemetry/SKILL.md) | DOCA Telemetry — schemas, sampling, DTS integration. |
| `doca-telemetry-exporter` | [skills/libs/doca-telemetry-exporter/SKILL.md](skills/libs/doca-telemetry-exporter/SKILL.md) | DOCA Telemetry Exporter — application-side publish library. |
| `doca-dma` | [skills/libs/doca-dma/SKILL.md](skills/libs/doca-dma/SKILL.md) | DOCA DMA — host↔DPU memory copy via the BlueField DMA engine. |
| `doca-compress` | [skills/libs/doca-compress/SKILL.md](skills/libs/doca-compress/SKILL.md) | DOCA Compress — hardware-accelerated compression / decompression. |
| `doca-aes-gcm` | [skills/libs/doca-aes-gcm/SKILL.md](skills/libs/doca-aes-gcm/SKILL.md) | DOCA AES-GCM — hardware-accelerated AES-GCM. |
| `doca-sha` | [skills/libs/doca-sha/SKILL.md](skills/libs/doca-sha/SKILL.md) | DOCA SHA — hardware-accelerated SHA hashing. |
| `doca-erasure-coding` | [skills/libs/doca-erasure-coding/SKILL.md](skills/libs/doca-erasure-coding/SKILL.md) | DOCA Erasure Coding — hardware-accelerated EC (RS / similar). |
| `doca-apsh` | [skills/libs/doca-apsh/SKILL.md](skills/libs/doca-apsh/SKILL.md) | DOCA App Shield (library) — process-introspection primitives. |
| `doca-pcc` | [skills/libs/doca-pcc/SKILL.md](skills/libs/doca-pcc/SKILL.md) | DOCA PCC (library) — programmable congestion control (DPA-hosted). |
| `doca-urom` | [skills/libs/doca-urom/SKILL.md](skills/libs/doca-urom/SKILL.md) | DOCA UROM (library) — Unified Communication Remote Memory Operations. |
| `doca-argp` | [skills/libs/doca-argp/SKILL.md](skills/libs/doca-argp/SKILL.md) | DOCA Arg Parser — argument parser used by every shipped sample. |
| `doca-log` | [skills/libs/doca-log/SKILL.md](skills/libs/doca-log/SKILL.md) | DOCA Log — logging primitive (log registries, levels). |
| `doca-device-emulation` | [skills/libs/doca-device-emulation/SKILL.md](skills/libs/doca-device-emulation/SKILL.md) | DOCA Device Emulation — umbrella for PCI Generic, virtio, virtio-fs. |
| `doca-switching` | [skills/libs/doca-switching/SKILL.md](skills/libs/doca-switching/SKILL.md) | DOCA Switching — BlueField switch-dataplane abstraction. |
| `doca-dpl` | [skills/libs/doca-dpl/SKILL.md](skills/libs/doca-dpl/SKILL.md) | DOCA Pipeline Language — declarative pipeline definition. |
| `doca-sta` | [skills/libs/doca-sta/SKILL.md](skills/libs/doca-sta/SKILL.md) | DOCA Storage Applications / STA — storage-focused reference apps + storage transport acceleration. |
| `doca-rivermax` | [skills/libs/doca-rivermax/SKILL.md](skills/libs/doca-rivermax/SKILL.md) | DOCA Rivermax — media / streaming integration. |
| `doca-dpdk-bridge` | [skills/libs/doca-dpdk-bridge/SKILL.md](skills/libs/doca-dpdk-bridge/SKILL.md) | DOCA DPDK Bridge (API-only) — interop layer for an existing DPDK application to reach DOCA libraries. |

**Services (11) — `skills/services/<name>/`**

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-dms` | [skills/services/doca-dms/SKILL.md](skills/services/doca-dms/SKILL.md) | DOCA Management Service — gNMI/gNOI config + ops over gRPC. |
| `doca-dts` | [skills/services/doca-dts/SKILL.md](skills/services/doca-dts/SKILL.md) | DOCA Telemetry Service — telemetry collection container on BlueField. |
| `doca-blueman` | [skills/services/doca-blueman/SKILL.md](skills/services/doca-blueman/SKILL.md) | DOCA BlueMan Service — BlueField management dashboard. |
| `doca-firefly` | [skills/services/doca-firefly/SKILL.md](skills/services/doca-firefly/SKILL.md) | DOCA Firefly Service — PTP / time-sync. |
| `doca-flow-inspector` | [skills/services/doca-flow-inspector/SKILL.md](skills/services/doca-flow-inspector/SKILL.md) | DOCA Flow Inspector Service — mirrored-flow inspection. |
| `doca-hbn` | [skills/services/doca-hbn/SKILL.md](skills/services/doca-hbn/SKILL.md) | DOCA HBN Service — Host-Based Networking (BGP/EVPN/VXLAN). |
| `doca-snap` | [skills/services/doca-snap/SKILL.md](skills/services/doca-snap/SKILL.md) | DOCA SNAP Service — NVMe / virtio-blk storage emulation on BlueField-3. |
| `doca-urom-svc` | [skills/services/doca-urom-svc/SKILL.md](skills/services/doca-urom-svc/SKILL.md) | DOCA UROM Service — paired with `libs/doca-urom`. `-svc` suffix per the AUTHORING § 17 collision rule. |
| `doca-argus` | [skills/services/doca-argus/SKILL.md](skills/services/doca-argus/SKILL.md) | DOCA Argus Service — runtime-security / monitoring on BlueField. |
| `doca-virtio-net` | [skills/services/doca-virtio-net/SKILL.md](skills/services/doca-virtio-net/SKILL.md) | DOCA Virtio-net Service — virtio-net device-emulation service. |
| `doca-container-deployment` | [skills/services/doca-container-deployment/SKILL.md](skills/services/doca-container-deployment/SKILL.md) | Cross-cutting: how every DOCA service container is deployed on BlueField (kubelet-standalone + pod-spec drop). Every per-service skill cross-links here. |

**Tools (12) — `skills/tools/<name>/`**

| Skill | Source | What it covers |
| --- | --- | --- |
| `doca-caps` | [skills/tools/doca-caps/SKILL.md](skills/tools/doca-caps/SKILL.md) | (see top-section row above) |
| `doca-bench` | [skills/tools/doca-bench/SKILL.md](skills/tools/doca-bench/SKILL.md) | DOCA Bench — performance evaluation harness. |
| `doca-comm-channel-admin` | [skills/tools/doca-comm-channel-admin/SKILL.md](skills/tools/doca-comm-channel-admin/SKILL.md) | Comm Channel Admin Tool — admin CLI for Comch channels. |
| `doca-dpa-tools` | [skills/tools/doca-dpa-tools/SKILL.md](skills/tools/doca-dpa-tools/SKILL.md) | DPA Tools (umbrella) — DPA developer / admin CLIs. |
| `doca-dpacc-compiler` | [skills/tools/doca-dpacc-compiler/SKILL.md](skills/tools/doca-dpacc-compiler/SKILL.md) | DPACC — DPA host/device split-build compiler. |
| `doca-dpu-cli` | [skills/tools/doca-dpu-cli/SKILL.md](skills/tools/doca-dpu-cli/SKILL.md) | DOCA DPU CLI — administrative CLI for the BlueField DPU. |
| `doca-flow-tune-tool` | [skills/tools/doca-flow-tune-tool/SKILL.md](skills/tools/doca-flow-tune-tool/SKILL.md) | Flow Tune Tool — visibility / analysis CLI for DOCA Flow programs. |
| `doca-flow-tune-server` | [skills/tools/doca-flow-tune-server/SKILL.md](skills/tools/doca-flow-tune-server/SKILL.md) | Flow Tune Server — long-running server side of Flow Tune. |
| `doca-pcc-counter` | [skills/tools/doca-pcc-counter/SKILL.md](skills/tools/doca-pcc-counter/SKILL.md) | PCC Counter — PCC counter inspection (paired with `libs/doca-pcc`). |
| `doca-socket-relay` | [skills/tools/doca-socket-relay/SKILL.md](skills/tools/doca-socket-relay/SKILL.md) | Socket Relay — socket relay between host and DPU. |
| `doca-ngauge` | [skills/tools/doca-ngauge/SKILL.md](skills/tools/doca-ngauge/SKILL.md) | DOCA Ngauge — diagnostic / measurement tool. |
| `doca-hugepages` | [skills/tools/doca-hugepages/SKILL.md](skills/tools/doca-hugepages/SKILL.md) | `doca-hugepages` Tool — helper for huge-page reservations. |

## Adding a new skill

1. Pick the right slot in the layered tree
   (`libs/<library>` / `services/<service>` / `tools/<tool>`, or
   top-level only if the skill is genuinely cross-cutting).
2. Create `<slot>/<kebab-case-id>/SKILL.md`.
3. Use the frontmatter contract enforced by `ci/check-skill.sh`
   (`name`, `description ≤ 1024 chars`, `kind: knowledge | library`).
4. For `kind: library`, add `CAPABILITIES.md` and `TASKS.md` with the
   required H2 anchors (`ci/check-skill.sh` enforces them).
5. Add a row to the index table above with a single-line "when to
   load" trigger.
6. Run `ci/check-skill.sh --all` locally (and `--check-urls` if any
   URLs were added or changed) and confirm both pass.
