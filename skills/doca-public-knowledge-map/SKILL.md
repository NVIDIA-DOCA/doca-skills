---
name: doca-public-knowledge-map
description: Comprehensive map of every public DOCA knowledge source — docs.nvidia.com pages, programming guides, downloads, public GitHub repos, NGC catalog, developer forum — plus the on-disk layout of an installed DOCA package, so any agent can locate authoritative information without access to the DOCA source repository.
kind: knowledge
---

# DOCA Public Knowledge Map

**Where to start:** Reach for this skill whenever the question is "where does
the authoritative answer live?" — a docs page, the on-disk install layout, a
sample, or an NGC catalog entry. Read [`## Public documentation entry points`](#public-documentation-entry-points)
first; then jump to the routing-table section that matches the user's intent.

## Example questions this skill answers well

These are the question SHAPES this skill is designed to route, with one worked
example each. A productive A/B test against this skill probes the *shape*, not
the literal wording.

- **"Where can I read about DOCA &lt;library/service/tool/concept&gt;?"** —
  worked example: *"Where can I read about DOCA Flow Connection Tracking?"*
  Answered by walking the `## Library- and module-specific guides`,
  `## DOCA services`, or `## DOCA tools` routing tables to the matching
  `docs.nvidia.com/doca/sdk/...` entry.
- **"Which DOCA libraries do I have installed and at what version?"** —
  worked example: *"How do I confirm the box has DOCA Flow 3.3 installed?"*
  Answered by combining `## Layout of an installed DOCA package` and
  `## Where to find the version`, with cross-link to the layered
  version-detection rules in
  [doca-setup ## Capabilities and modes](../doca-setup/CAPABILITIES.md).
- **"Where is sample &lt;X&gt; on disk and where is its source on GitHub?"** —
  worked example: *"Where is the doca_flow sample that exercises ACL pipes?"*
  Answered by combining `## Layout of an installed DOCA package` (local)
  with `## Public source code: GitHub` (remote) — both sections name the
  canonical paths.
- **"What does this on-disk path mean, what should I cite from it?"** —
  worked example: *"What's in `/opt/mellanox/doca/applications/` that the
  customer can actually run?"* Answered by `## Layout of an installed DOCA package`,
  plus the "no source-tree paths" ground rule above.
- **"This URL I have 404s — what's the new one?"** — worked example: *"The
  Comm Channel page is gone in DOCA 2.5+."* Answered by the URL-rename rule
  at the top of `## Public documentation entry points`, plus the
  `## URL audit` footer at the bottom of this file.
- **"Where is the customer-facing place to ask for help on this?"** —
  worked example: *"What's the developer forum's DOCA category?"* Answered
  from the developer-forum entry in `## Public documentation entry points`,
  never internal NVIDIA channels (see ground rule above).

If the question fits a different shape (how to write code, how to set up an
env, how to debug a crash), route to the matching skill instead — see
[`AGENTS.md`](../../AGENTS.md) for the routing table.

## When to load this skill

Load this skill whenever the user asks anything about NVIDIA DOCA where the
agent needs to **locate authoritative information** without access to the
DOCA source tree. That includes: installing DOCA, building a sample, learning
a DOCA library (Flow, DPA, Comm Channel, GPUNetIO, …), debugging an error,
finding an API reference, finding a sample, finding release notes, or
pointing the user at the developer forum.

This skill is intentionally a **routing table**, not a tutorial. Pick the
entry that matches the user's intent, fetch the URL or inspect the local
install path, and only then answer.

## Ground rules for any agent using this skill

1. **Prefer the local install over the web.** If DOCA is installed on the
   machine, the files in `/opt/mellanox/doca` (Linux) are the exact bits the
   user is running. Web docs describe a release; local files *are* the release.
2. **Always check the version.** Before quoting API names, options, or sample
   filenames, find the installed DOCA version (see "Where to find the
   version" below) and use the matching documentation release.
3. **Never invent URLs, file paths, package names, `pkg-config` modules,
   library names, or sample names.** If you do not see it in this map, in the
   user's local install, or in the official docs you fetched, say so and ask.
4. **Public sources only.** Reference NVIDIA documentation only on the
   public hosts listed in [`AGENTS.md` ground rule #1](../../AGENTS.md).
   Anything else is not available to a customer agent and is rejected
   by an internal CI pipeline before the bundle ships.
5. **No source-tree paths.** Do not reference `devtools/...`, `docs/ai/...`,
   or any path that only exists inside the DOCA repository. Customers do not
   have those.

> **Hardware-safety meta-policy.** Every per-artifact `## Safety policy`
> in this bundle overlays the cross-cutting hardware-safety
> meta-policy. When the user's question touches a change to live DPU /
> NIC hardware state (`mlxconfig` writes, firmware burn, BlueField
> mode flip, BAR window change, IOMMU / hugepages kernel boot
> parameter, BFB reflash), load
> [`doca-hardware-safety`](../doca-hardware-safety/SKILL.md) alongside
> the per-artifact skill. Cross-cutting meta-policy lives there
> (pre-flight inventory, out-of-band access requirement, maintenance
> window, replica-first validation, rollback discipline,
> observability-before-workload, refuse-and-escalate when no rollback
> exists). Per-artifact overlays MUST NOT redefine it.

## Public documentation entry points

Start here for any conceptual question. These are the canonical NVIDIA-hosted
documents.

> **Rule when a URL in this skill returns 404.** NVIDIA periodically renames
> doc pages and library slugs (the most recent example: *Comm Channel* →
> *Comch* in DOCA 2.5). If a URL listed here 404s during a real session:
> (1) tell the user explicitly that the skill's URL is stale; (2) try
> `https://docs.nvidia.com/doca/sdk/` (the index always works) and look for a
> renamed link; (3) **do not invent a replacement URL** and do not silently
> point at an `archive/` URL — those are version-pinned to old releases.
> File a fix against this skill (see "URL audit" footer for the last
> verification date and DOCA version).

| Topic | URL | When to use |
| --- | --- | --- |
| DOCA SDK documentation index | <https://docs.nvidia.com/doca/sdk/index.html> | The top of the documentation tree. Always start here when the user asks an open-ended "how does DOCA do X?" question. |
| DOCA Overview | <https://docs.nvidia.com/doca/sdk/doca-overview/index.html> | High-level architecture: what DOCA is, what runs on the BlueField DPU vs. the host, libraries vs. applications vs. services vs. tools. |
| DOCA Installation Guide for Linux | <https://docs.nvidia.com/doca/sdk/installation-guide-for-linux/index.html> | Install steps, supported OSes, package layout, post-install verification. Read this whenever the user is setting DOCA up for the first time. |
| DOCA Programming Guide (index) | <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> | SDK architecture, common patterns, how libraries connect, how to wire up a sample. Read this before drilling into a specific library guide. |
| DOCA Developer Quick Start Guide | <https://docs.nvidia.com/doca/sdk/doca-developer-quick-start-guide/index.html> | NVIDIA's official "how do I bring DOCA up and run my first reference application" walkthrough. Cite this for any beginner asking "how do I start?" *once they have BlueField + host hardware*. For users **without** hardware (macOS / Windows / Linux without a NIC), route via [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install) (NGC container) instead — the Quick Start assumes hardware is already present. |
| DOCA Release Notes | <https://docs.nvidia.com/doca/sdk/doca-release-notes/index.html> | What changed in a release, supported hardware, supported OSes, known issues. Read whenever the user's symptom could be a known issue. |
| DOCA Compatibility Policy | <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html> | NVIDIA's authoritative statement of DOCA version semantics — quarterly GA cadence, October LTS designation (3-year support, 7-update LTS train), the semantic-versioning scheme (X.Y.Z), the three compatibility types (source / binary / behavioral), and the two compatibility directions (backward / forward). Cite this whenever the user asks "what does the version string mean?", "is this LTS release still supported?", or any host ↔ DPU compatibility question. |
| Developer Zone — DOCA landing | <https://developer.nvidia.com/networking/doca> | Marketing-and-onboarding view (videos, tutorials, blog posts). Use only as a fallback when the official SDK docs do not have the topic yet. |
| DOCA Downloads | <https://developer.nvidia.com/doca-downloads> | Where customers actually download DOCA packages, BFB images, host packages. Use this to answer "which package do I need?". |
| NGC Catalog (containers and resources) | <https://catalog.ngc.nvidia.com> | Find DOCA containers, model artifacts, and DPU images. Search for `doca` to enumerate. |
| DOCA Developer Forum | <https://forums.developer.nvidia.com/c/infrastructure/doca/370> | Last-resort discovery for undocumented behavior, real customer questions, NVIDIA staff answers. Always include the disclaimer that forum threads can age and may not match the user's installed version. |

## Library- and module-specific guides

Each DOCA library has its own subtree under `/doca/sdk/`. Use the matching
guide once the user's question is narrow enough to be about a single library.

> **First — the umbrella.** The DOCA SDK ships **dozens** of libraries; the
> table below names the ones agents most often need to route directly. If the
> user's library is not listed, the canonical first stop is the
> [**DOCA Libraries** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html),
> which lists every public library with its quality level (GA / Beta / Alpha)
> and links to its programming guide. Always consult the umbrella before
> telling a user a library does not exist or before guessing a URL. The
> umbrella is also the right answer for *"what DOCA libraries are available
> for X?"*-style discovery questions.

| Library | Guide | Typical questions it answers |
| --- | --- | --- |
| **DOCA Libraries** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Canonical list of every public DOCA library with its quality level. Always check here first when the user's library is not in the table below. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA Core (umbrella) | <https://docs.nvidia.com/doca/sdk/DOCA-Core/index.html> | The shared object-model every DOCA library is built on: `doca_dev`, `doca_devinfo`, `doca_pe` (progress engine), `doca_buf` / `doca_mmap`, `doca_ctx` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy. Read this whenever the user is touching more than one library or asking *"how does DOCA in general work?"*. |
| DOCA Common | <https://docs.nvidia.com/doca/sdk/DOCA-Common/index.html> | The base utility library every DOCA program links against (`doca-common` `pkg-config` module). Pulled in transitively when you depend on any other DOCA library. |
| DOCA Flow | <https://docs.nvidia.com/doca/sdk/DOCA-Flow/index.html> | Port setup, device or representor selection, pipes, actions, actions memory, entry lifecycle. |
| DOCA Flow (incl. Connection Tracking) | <https://docs.nvidia.com/doca/sdk/DOCA-Flow/index.html> | Port setup, pipes, actions, action memory, entry lifecycle, validation, counters, traces. Folds Flow Connection Tracking (`doca_flow_ct.h`) as `## flow-ct` (connection-aware pipes, aging, NAT/SNAT/DNAT). Covered by the [`doca-flow`](../libs/doca-flow/SKILL.md) skill. |
| DOCA Ethernet | <https://docs.nvidia.com/doca/sdk/DOCA-Ethernet/index.html> | RX/TX queues, packet I/O, `eth_rxq` / `eth_txq` lifecycle. Underpins the GPU Packet Processing app and most line-rate examples. Covered by the [`doca-eth`](../libs/doca-eth/SKILL.md) skill. |
| DOCA RDMA | <https://docs.nvidia.com/doca/sdk/DOCA-RDMA/index.html> | DOCA's RDMA surface (send / recv / write / read patterns) on BlueField / ConnectX. Covered by the [`doca-rdma`](../libs/doca-rdma/SKILL.md) skill. |
| DOCA Verbs | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Lower-level ibverbs-style API beneath DOCA RDMA / DOCA Eth, exposing raw QP / CQ / PD / MR / SRQ / AH primitives inside DOCA Core. Primary role is to route back to the higher-level library; takes the conversation only when the higher-level library does not expose the specific verb / opcode / WR flag the user needs. Covered by the [`doca-verbs`](../libs/doca-verbs/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA DPA (incl. Comms + Verbs) | <https://docs.nvidia.com/doca/sdk/DOCA-DPA/index.html> | DPA host / device split-build, DPACC context, DPA annotation conventions. Folds DPA Comms (DPA-side communication primitives) as `## comms` and DPA Verbs (DPA-side verbs surface) as `## verbs`. Covered by the [`doca-dpa`](../libs/doca-dpa/SKILL.md) skill. |
| DOCA Flow DPA Provider | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Bridges a `doca-flow` pipe into a DPA execution target so flow execution can run on the DPA processor instead of the host or DPU-CPU path. Covered by the [`doca-flow-dpa-provider`](../libs/doca-flow-dpa-provider/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA GPUNetIO | <https://docs.nvidia.com/doca/sdk/DOCA-GPUNetIO/index.html> | GPU-initiated networking, CUDA + DOCA integration patterns. Covered by the [`doca-gpunetio`](../libs/doca-gpunetio/SKILL.md) skill. |
| DOCA GPI | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | GPU Programming Interface for kernel-launched RDMA operations directly from a CUDA thread. Distinct runtime surface from GPUNetIO; pairs with `doca-rdma` and `doca-gpunetio`. Covered by the [`doca-gpi`](../libs/doca-gpi/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA Comch (formerly Comm Channel) | <https://docs.nvidia.com/doca/sdk/DOCA-Comch/index.html> | Host ↔ DPU control-plane messaging. **Library was renamed in DOCA 2.5**: the URL slug is `DOCA-Comch`, not `doca-comm-channel`. The `pkg-config` module on installed systems is `doca-comch`. Covered by the [`doca-comch`](../libs/doca-comch/SKILL.md) skill. |
| DOCA Telemetry | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry/index.html> | DOCA's telemetry collection surface — schemas, sampling, integration with the DOCA Telemetry Service (DTS). Covered by the [`doca-telemetry`](../libs/doca-telemetry/SKILL.md) skill. |
| DOCA Telemetry Exporter | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Exporter/index.html> | Application-side library used to *publish* telemetry from a DOCA program (distinct from `DOCA Telemetry`, which is the collection / consumption surface). Covered by the [`doca-telemetry-exporter`](../libs/doca-telemetry-exporter/SKILL.md) skill. |
| DOCA DMA | <https://docs.nvidia.com/doca/sdk/DOCA-DMA/index.html> | Host ↔ DPU memory copy via the BlueField DMA engine. The DMA Copy reference application is the canonical example. Covered by the [`doca-dma`](../libs/doca-dma/SKILL.md) skill. |
| DOCA Compress | <https://docs.nvidia.com/doca/sdk/DOCA-Compress/index.html> | Hardware-accelerated compression / decompression. Pairs with the File Compression reference application. Covered by the [`doca-compress`](../libs/doca-compress/SKILL.md) skill. |
| DOCA AES-GCM | <https://docs.nvidia.com/doca/sdk/DOCA-AES-GCM/index.html> | Hardware-accelerated AES-GCM encryption / decryption. Member of the DOCA Crypto Acceleration family. Covered by the [`doca-aes-gcm`](../libs/doca-aes-gcm/SKILL.md) skill. |
| DOCA SHA | <https://docs.nvidia.com/doca/sdk/DOCA-SHA/index.html> | Hardware-accelerated SHA hashing. Pairs with the File Integrity reference application. Covered by the [`doca-sha`](../libs/doca-sha/SKILL.md) skill. |
| DOCA Erasure Coding | <https://docs.nvidia.com/doca/sdk/DOCA-Erasure-Coding/index.html> | Hardware-accelerated erasure coding (RS / similar). Used in storage workloads. Covered by the [`doca-erasure-coding`](../libs/doca-erasure-coding/SKILL.md) skill. |
| DOCA App Shield (library) | <https://docs.nvidia.com/doca/sdk/DOCA-App-Shield/index.html> | Process-introspection primitives the App Shield Agent application is built on. Distinct from the App Shield Agent reference application page. Covered by the [`doca-apsh`](../libs/doca-apsh/SKILL.md) skill. |
| DOCA PCC (library) | <https://docs.nvidia.com/doca/sdk/DOCA-PCC/index.html> | Programmable congestion control library (DPA-hosted). Distinct from the PCC reference application and the `doca_pcc_counter` tool. Covered by the [`doca-pcc`](../libs/doca-pcc/SKILL.md) skill. |
| DOCA PCC ZTR-RTTCC Algorithm | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | The shipped reference Zero-Touch-RTT Congestion-Control algorithm that runs under `doca-pcc`. Pairs with `doca-pcc` (host) and `doca-pcc-counters` (observability). Covered by the [`doca-pcc-ztr-rttcc-algo`](../libs/doca-pcc-ztr-rttcc-algo/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA UROM (library) | <https://docs.nvidia.com/doca/sdk/DOCA-UROM/index.html> | Unified Communication Remote Memory Operations library. Distinct from the DOCA UROM Service. Covered by the [`doca-urom`](../libs/doca-urom/SKILL.md) skill. |
| DOCA Arg Parser | <https://docs.nvidia.com/doca/sdk/DOCA-Arg-Parser/index.html> | Argument parser used by every shipped DOCA sample and reference application. Worth knowing when the user adapts a sample's CLI surface. Covered by the [`doca-argp`](../libs/doca-argp/SKILL.md) skill. |
| DOCA Device Emulation (umbrella) | <https://docs.nvidia.com/doca/sdk/DOCA-Device-Emulation/index.html> | Umbrella for the device-emulation libraries (PCI Generic, virtio, virtio-fs). Start here if the user is building emulated PCIe devices on BlueField. Covered by the [`doca-devemu`](../libs/doca-devemu/SKILL.md) skill. |
| DOCA MGMT | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Programmatic management of DOCA device state (library-side). Pairs with `doca-dms` (service-side). Covered by the [`doca-mgmt`](../libs/doca-mgmt/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA RDMI | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Redfish Device Management Interface — Redfish-compliant device-management surface. Pairs with `doca-mgmt`. Covered by the [`doca-rdmi`](../libs/doca-rdmi/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA Storage Applications | <https://docs.nvidia.com/doca/sdk/DOCA-Storage-Applications/index.html> | Index of DOCA's storage-focused reference applications (Comch-to-RDMA zero-copy, GGA offload, SBC generator, initiator, target). Use this entry when the user's question is *"how do I move storage I/O across the BlueField?"* before drilling into a specific app guide. Covered by the [`doca-sta`](../libs/doca-sta/SKILL.md) skill. |
| DOCA Rivermax | <https://docs.nvidia.com/doca/sdk/DOCA-Rivermax/index.html> | DOCA's Rivermax integration (media / streaming workloads). Covered by the [`doca-rmax`](../libs/doca-rmax/SKILL.md) skill. |
| DOCA STA | <https://docs.nvidia.com/doca/sdk/DOCA-STA/index.html> | Storage Transport Acceleration library. Covered by the [`doca-sta`](../libs/doca-sta/SKILL.md) skill. |
| DOCA DPDK Bridge (API-only) | <https://docs.nvidia.com/doca/api/3.1.0/doca-libraries-api/modules.html#group__DOCA__DPDK__BRIDGE> | The interop layer that lets an existing DPDK application reach DOCA libraries (most commonly DOCA Flow) without rewriting its data-plane. **No standalone SDK doc page today** — documented as an API-reference module under DOCA Libraries API. Covered by the [`doca-dpdk-bridge`](../libs/doca-dpdk-bridge/SKILL.md) skill. |
| DOCA Reference Applications | <https://docs.nvidia.com/doca/sdk/DOCA-Reference-Applications/index.html> | The shipped reference applications (PCC, DPI, IPsec gateway, file-compression, etc.) — what each one does, where its source lives under `/opt/mellanox/doca/applications/`, and how to recompile with `meson` + `ninja`. |

There is **no current single "DOCA Samples Overview" page** in the v3.x docs.
Samples are documented per-library inside each library's programming guide
(see "Sample" sections inside the URLs above) and ship on disk under
`/opt/mellanox/doca/samples/doca_<library>/`. Earlier (v1.x / v2.x) docs did
have a single overview page — those URLs are now archived and will return 404
on `docs.nvidia.com/doca/sdk/`. Do not link the archived page; route the user
to the per-library "Sample" sections plus the on-disk samples directory.

If the user asks about a DOCA library that is **not** in the table above, do
**not** guess the URL. Open the
[**DOCA Libraries** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html)
first to confirm the library exists and to find its canonical guide URL.
Only after that, fall back to the user's installed sample directory (see
"Layout of an installed DOCA package" below).

## DOCA services

DOCA ships a set of *services* — long-running daemons / containers
documented separately from the libraries. Per-service skills (where
they exist) live under `skills/services/<svc>`; the URLs below are
the public guides in `docs.nvidia.com/doca/sdk/`.

> **First — the umbrella.** When the user's service is not listed below, the
> canonical first stop is the
> [**DOCA Services** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Services/index.html),
> which lists every public DOCA service with its purpose and links to its
> service guide.

| Service | Guide | What it does |
| --- | --- | --- |
| **DOCA Services** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Services/index.html> | Canonical list of every public DOCA service with its purpose and guide link. Always check here first when a service is not in the table below. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DOCA Management Service (DMS) | <https://docs.nvidia.com/doca/sdk/DOCA-Management-Service-Guide/index.html> | Centralized configuration / operation of BlueField and ConnectX devices via gRPC (gNMI for config, gNOI for system ops). Covered by the [`doca-dms`](../services/doca-dms/SKILL.md) skill. |
| DOCA Firefly Service | <https://docs.nvidia.com/doca/sdk/DOCA-Firefly-Service-Guide/index.html> | PTP / time synchronization service. Covered by the [`doca-firefly`](../services/doca-firefly/SKILL.md) skill. |
| DOCA Flow Inspector Service | <https://docs.nvidia.com/doca/sdk/DOCA-Flow-Inspector-Service-Guide/index.html> | Mirrored-flow inspection service. Covered by the [`doca-flow-inspector`](../services/doca-flow-inspector/SKILL.md) skill. |
| DOCA UROM Service | <https://docs.nvidia.com/doca/sdk/DOCA-UROM-Service-Guide/index.html> | Unified Communication Remote Memory Operations service. Covered by the [`doca-urom-svc`](../services/doca-urom-svc/SKILL.md) skill. |
| DOCA Argus Service | <https://docs.nvidia.com/doca/sdk/DOCA-Argus-Service-Guide/index.html> | DOCA's runtime-security / monitoring service for BlueField. Covered by the [`doca-argus`](../services/doca-argus/SKILL.md) skill. |
| DOCA OS Inspector Service | <https://docs.nvidia.com/doca/sdk/DOCA-Services/index.html> | DPU-side out-of-band host-OS introspection container. Service wrapper for apsh-class capabilities; pairs with `doca-apsh` (library) and `doca-apsh-config` (profile generation). Covered by the [`doca-os-inspector`](../services/doca-os-inspector/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |

> **Non-goals.** Externally-productized NVIDIA services that are NOT in
> `doca/services/` at the bundle's currently-aligned DOCA release —
> DOCA Telemetry Service (DTS), BlueMan, HBN, SNAP, Virtio-net — are
> intentionally out of scope for this bundle, which is strictly 1:1
> with `doca/services/`. See
> [AGENTS.md `## Non-goals`](../../AGENTS.md#non-goals) for the policy
> rationale. If a user asks about one of these external services,
> route them to the public NVIDIA documentation on
> `docs.nvidia.com/doca/sdk/` (the URL stems above remain valid for
> reference) and explain that this bundle covers only the in-tree
> services.

The bundle covers DOCA deployment via **two sibling top-level
cross-cutting skills**, one per deployment path, plus a front-door
routing decision in `doca-setup ## recognize` that lands the user
on the right one:

- The **Container Deployment Guide**
  (<https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html>)
  is the cross-service reference for how DOCA service containers are
  deployed on BlueField. Covered cross-cuttingly by the
  [`doca-container-deployment`](../doca-container-deployment/SKILL.md)
  skill — every in-bundle per-service skill above hands off to it
  for the kubelet-standalone static-pod manifests directory, image
  pull, and pod-spec drop pattern.
- The **bare-metal hardware deployment** path (a DOCA-linked
  application binary launched directly on host x86 or BlueField
  Arm bare-metal — no container) is covered by the
  [`doca-bare-metal-deployment`](../doca-bare-metal-deployment/SKILL.md)
  skill. It owns the launch contract (direct / tmux / systemd),
  hardware-resource binding (PF/VF/representor + NUMA + CPU pinning
  + IRQ affinity), per-tenant isolation primitives, the bare-metal
  error taxonomy, and the restart-loop-is-HIGH-STAKES rule. The
  authoritative public references are the **DOCA Programming
  Guide** (build, link, runtime preconditions:
  <https://docs.nvidia.com/doca/sdk/DOCA-Programming-Guide/index.html>),
  the **DPU / BlueField User Manual** (PCIe topology, devlink,
  representor naming, `mlxconfig` device introspection:
  <https://docs.nvidia.com/doca/sdk/BlueField+and+DOCA+User+Types.md>), and
  the per-library guides listed below in this map.
- The **front-door routing decision** between the two — *"which
  path applies to my workload?"* — is owned by
  [`doca-setup ## recognize`](../doca-setup/TASKS.md#recognize),
  which detects the system shape (host x86 / BlueField Arm
  bare-metal / DPU-only / fresh laptop) and asks the developer the
  minimum residual question before routing. Any deployment-shaped
  question (*"how do I deploy"*, *"my code is built, how do I run
  it"*, *"I just got a BlueField, what now"*) loads `## recognize`
  first.

If the user asks about a DOCA service that is not in this table, open the
[**DOCA Services** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Services/index.html)
to discover it. Do not guess service URLs.

## DOCA tools

DOCA ships a set of *tools* — small CLIs installed under
`/opt/mellanox/doca/tools/` on a real install, each documented on its
own public page. Per-tool skills (where they exist) live under
`skills/tools/<tool>`.

> **First — the umbrella.** When the user's tool is not listed below, the
> canonical first stop is the
> [**DOCA Tools** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html),
> which lists every public DOCA tool and links to its tool guide.

| Tool | Guide | What it does |
| --- | --- | --- |
| **DOCA Tools** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Canonical list of every public DOCA tool with its purpose and guide link. Always check here first when a tool is not in the table below. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Capabilities Print Tool (`doca_caps`) | <https://docs.nvidia.com/doca/sdk/DOCA-Capabilities-Print-Tool/index.html> | Prints DOCA devices and the per-library capabilities they support. Side-effect-free; safe to call early. Covered by the [`doca-caps`](../tools/doca-caps/SKILL.md) skill. |
| DOCA Bench | <https://docs.nvidia.com/doca/sdk/DOCA-Bench/index.html> | Performance evaluation harness for the built-in workload modes. Covered by the [`doca-bench`](../tools/doca-bench/SKILL.md) skill. |
| DOCA Bench Extension | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | In-tree extension / plug-in framework that lets `doca-bench` measure workload classes its built-in modes do not cover. Reference exemplar `doca_bench_cuda` drives GPUNetIO RX / TX kernels. Covered by the [`doca-bench-extension`](../tools/doca-bench-extension/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Comm Channel Admin Tool | <https://docs.nvidia.com/doca/sdk/DOCA-Comm-Channel-Admin-Tool/index.html> | Admin CLI for Comch channels. Covered by the [`doca-comm-channel-admin`](../tools/doca-comm-channel-admin/SKILL.md) skill. |
| Flow Tune | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Unified visibility / analysis / recommendation tool for live `doca-flow` pipelines. The artifact is ONE binary with TWO internal roles (server role: snapshots and exposes pipe / counter / KPI state through local IPC; client / consumer role: dumps, analyzes, visualizes, recommends parameter changes). The historical "Flow Tune Tool" and "Flow Tune Server" split lives INSIDE this artifact — there is one skill: [`doca-flow-tune`](../tools/doca-flow-tune/SKILL.md). **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Flow Perf | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Host / DPU-CPU control-plane rule-rate measurement (install / delete / query rate). Distinct from `Flow DPA Perf` (DPA-offloaded path) and `Flow Tune` (optimizes a deployed pipeline). Covered by the [`doca-flow-perf`](../tools/doca-flow-perf/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Flow DPA Perf | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Flow performance measurement for the DPA-offloaded execution path. Covered by the [`doca-flow-dpa-perf`](../tools/doca-flow-dpa-perf/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Flow gRPC Server | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | gRPC remote-control server for `doca-flow` rule programming. Covered by the [`doca-flow-grpc-server`](../tools/doca-flow-grpc-server/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| PCC Counter | <https://docs.nvidia.com/doca/sdk/DOCA-PCC-Counter-Tool/index.html> | PCC counter inspection. Covered by the [`doca-pcc-counters`](../tools/doca-pcc-counters/SKILL.md) skill. |
| Socket Relay | <https://docs.nvidia.com/doca/sdk/DOCA-Socket-Relay/index.html> | Socket relay between host and DPU. Covered by the [`doca-socket-relay`](../tools/doca-socket-relay/SKILL.md) skill. |
| App Shield Config | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Generates the host-OS profile / symbol files that `doca-apsh` and `doca-os-inspector` need to interpret host kernel state. Without a current profile, apsh-class introspection returns garbage. Covered by the [`doca-apsh-config`](../tools/doca-apsh-config/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| DPA High-Level Tracer | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Captures DPA-side execution traces with higher-level events than raw cycle counts. Covered by the [`doca-dpa-hl-tracer`](../tools/doca-dpa-hl-tracer/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| GPI ib_write_lat | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | RDMA-write latency benchmark from the GPI (CUDA-kernel-initiated RDMA) path. Covered by the [`doca-gpi-ib-write-lat`](../tools/doca-gpi-ib-write-lat/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| GPUNetIO ib_write_bw | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | RDMA-write bandwidth benchmark from the GPUNetIO framework. Covered by the [`doca-gpunetio-ib-write-bw`](../tools/doca-gpunetio-ib-write-bw/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| GPUNetIO ib_write_lat | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | RDMA-write latency benchmark from the GPUNetIO framework. Covered by the [`doca-gpunetio-ib-write-lat`](../tools/doca-gpunetio-ib-write-lat/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| SHA Offload Engine | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | OpenSSL ENGINE wrapping the DOCA SHA library; lets unmodified OpenSSL-based applications offload SHA without code changes. Covered by the [`doca-sha-offload-engine`](../tools/doca-sha-offload-engine/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| SPCX-CC | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Programmable Congestion-Control extension (next-gen). Pairs with `doca-pcc`, `doca-pcc-ztr-rttcc-algo`. Live-fabric safety implications: heavy use of `doca-hardware-safety`. Covered by the [`doca-spcx-cc`](../tools/doca-spcx-cc/SKILL.md) skill. **No standalone SDK doc page in the public index today — use the umbrella above to discover.** |
| Telemetry Utils | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Utils/index.html> | Operator-side support CLI for a DOCA Telemetry exporter pipeline. Translates name ↔ Data ID, enumerates the diagnostic-counter schema, and probes per-device counter support before an exporter config commits to it. Covered by the [`doca-telemetry-utils`](../tools/doca-telemetry-utils/SKILL.md) skill. |

> **Non-goals.** Externally-productized NVIDIA tools that are NOT in
> `doca/tools/` at the bundle's currently-aligned DOCA release —
> DOCA-DPACC-Compiler, DPA-Tools (DPA GDB Server / PS / Statistics),
> DOCA-DPU-CLI, DOCA-Ngauge, `doca-hugepages` helper — are
> intentionally out of scope for this bundle, which is strictly 1:1
> with `doca/tools/`. See
> [AGENTS.md `## Non-goals`](../../AGENTS.md#non-goals).

If the user asks about a DOCA tool that is not in this table, open the
[**DOCA Tools** umbrella page](https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html)
to discover it. Do not guess tool URLs.

## Public source code: GitHub

NVIDIA publishes a small, deliberately scoped set of DOCA-adjacent code on
GitHub. These are the public, customer-visible repositories.

| Repository | URL | What you find there |
| --- | --- | --- |
| DOCA Platform Framework | <https://github.com/NVIDIA/doca-platform> | DPU provisioning, Kubernetes operator pieces, deployment manifests. Read this when the user is operating DPUs at scale or running them under Kubernetes. |

**Important:** the bulk of DOCA — libraries, samples, applications, build
system — is **not on GitHub**. It ships as packages and, for licensed users,
as source archives downloaded from the Developer Zone. If the user asks for
"the DOCA library X source on GitHub", correct them: the published sample for
library X lives under `/opt/mellanox/doca/samples/doca_<library>/` on an
installed system, or in the downloadable source archive referenced from the
Downloads page.

## Layout of an installed DOCA package

When DOCA is installed from the official packages on a Linux host or on
BlueField, an agent can rely on this on-disk layout. Use it instead of asking
the user to share source code.

| Path | What is there | How to use it |
| --- | --- | --- |
| `/opt/mellanox/doca` | Install root. | Use as `${DOCA_DIR}` in any command you suggest. |
| `/opt/mellanox/doca/samples` | One subdirectory per library, each containing a self-contained sample (typical files: `<library>_main.c`, `meson.build`). | The authoritative example for that library on the installed version. Read these before answering "show me a sample of X". |
| `/opt/mellanox/doca/applications` | Full reference applications (e.g. `doca_pcc`, `doca_dpi`). | Larger, integrated examples. Inspect their `meson.build` to see how they declare DOCA dependencies. |
| `/opt/mellanox/doca/tools` | Shipped CLIs (e.g. `doca_caps`, `doca_telemetry_exporter`). | Use them for runtime introspection before answering capability questions. |
| `/opt/mellanox/doca/infrastructure` | Headers, libraries, and `pkg-config` files used to build against DOCA. | Inspect `*.pc` here to verify the exact Meson dependency name for a library (`doca-flow`, `doca-common`, etc.). |
| `/opt/mellanox/doca/services` | Bundled services (DTS, telemetry agents, etc.). | Read service-specific README files inside each subdirectory before suggesting service-level changes. |

Useful enumeration commands to suggest to the user (read-only, safe):

```bash
ls /opt/mellanox/doca
ls /opt/mellanox/doca/samples
ls /opt/mellanox/doca/applications
pkg-config --list-all | grep -i doca
```

To build against DOCA from a user-owned directory, the canonical environment
hint is to expose the DOCA `pkg-config` directory before running `meson setup`:

```bash
export PKG_CONFIG_PATH="/opt/mellanox/doca/infrastructure/lib/pkgconfig:${PKG_CONFIG_PATH}"
```

If `pkg-config --modversion doca-common` fails after that, treat it as a real
environment problem (wrong package, wrong arch, missing dev package) and stop;
do not silently change the user's environment.

## Where to find the version

Pick whichever of these is available, in this order:

1. `cat /opt/mellanox/doca/applications/VERSION` (or the `VERSION` file at the
   install root, depending on package layout).
2. `pkg-config --modversion doca-common`
3. The DOCA Release Notes page header for the version the user says they
   installed.
4. The `--version` flag on any installed DOCA tool, for example
   `doca_caps --version`.

Always quote the version you actually observed; never assume "latest".

## First-contact discovery — the four questions to ask before any drill-down

When a user opens with an open-ended orientation question (*"I'm new with
DOCA, how do I start?"*, *"can you guide me?"*, *"what's the easiest way to
try DOCA?"*), the agent does **not** have enough information yet to pick a
path. Asking these four questions before drilling avoids wasted recommendations
that the user cannot actually execute on their setup. Ask them as a single
short message; do not interrogate one-at-a-time.

| Question | Why it matters | What it routes |
| --- | --- | --- |
| 1. **What OS are you on?** macOS, Windows, Linux laptop, cloud VM, lab Linux box, BlueField OS itself? | DOCA installs natively only on supported Linux distributions; macOS / Windows users cannot install it at all. | Picks between the four DOCA acquisition paths in [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install). macOS / Windows / no-Linux → Path 0 (NGC container). Supported Linux → Path A or B per the Installation Guide. |
| 2. **What hardware do you have?** No NVIDIA hardware, ConnectX SmartNIC, BlueField as a SmartNIC in a host, BlueField as a standalone DPU, not sure? | Real-traffic runtime needs a real NIC; build / read / learn does not. The user's hardware decides which DOCA libraries are even relevant. | Picks the runtime story (container is build-only without hardware). Filters which libraries make sense to learn (Flow needs a real port to do anything visible; Comch needs a host ↔ DPU pair). |
| 3. **What's your goal?** Just exploring, building a small first app on a specific library (Flow / RDMA / Comch / Telemetry / GPUNetIO / DPA / …), running an existing reference application, operating a service (DMS / DTS / BlueMan / Firefly), or something else? | The bundle's first-app workflow (`doca-programming-guide ## modify`) starts from a **shipped C sample** and edits down. The right sample depends on the library the user is targeting. | Picks which library skill (if any) to load next. If the user does not yet know which library — that itself is a routing answer (see the *Library- and module-specific guides* table above and let the user pick). |
| 4. **Which language do you plan to write the program in?** C / C++, Rust, Go, Python, other? | DOCA's public surface is a C ABI. Non-C consumers go through FFI / language bindings (`doca-programming-guide CAPABILITIES.md ## Capabilities and modes` and the per-library skill). The C samples are the reference even when the user's language is not C. | Picks whether the agent's first-app guidance is *direct C build* or *FFI / bindings against the C ABI*. Does **not** change which sample the agent points at first. |

The agent's rule: **never recommend a specific install path, container tag,
or sample without first having the answers to questions 1–3** (question 4 is
needed for the first-app workflow but not for orientation itself).
Volunteering specific commands before this is the single most common failure
mode for DOCA orientation.

If the user has already volunteered some of the information in their first
message, mark those questions answered and only ask the rest. Do not re-ask
what the user has already told you.

## Topic to "where to look first" routing table

When the user asks something, route as follows:

| User intent | First place to look |
| --- | --- |
| "How do I install DOCA?" | Installation Guide + Downloads page (Public documentation entry points). |
| "How do I start with DOCA — what's the very first thing?" | Developer Quick Start Guide *if* the user has BlueField + host hardware; otherwise [`doca-setup ## no-install`](../doca-setup/TASKS.md#no-install) Path 0 (NGC container). Use the four questions in [*First-contact discovery*](#first-contact-discovery--the-four-questions-to-ask-before-any-drill-down) to pick. |
| "Do I need a BlueField? A SmartNIC? Or just DOCA-Host?" | Overview page (`doca-overview/index.html`) plus the Installation Guide's *DOCA installation profiles* section. The bundle does not pick the hardware for the user — these two pages do. |
| "Which package gives me library X?" | Installation Guide section on package matrix; then verify on the user's system with `pkg-config --list-all`. |
| "Show me a sample that uses library X." | `/opt/mellanox/doca/samples/doca_<X>/` if installed; otherwise the per-library guide on `docs.nvidia.com/doca/sdk/` (each library guide documents the samples shipped with it). |
| "How do I build a DOCA sample?" | Library guide + the sample's own `meson.build` inside `/opt/mellanox/doca/samples/...`. |
| "What is the API for X?" | Library guide; confirm by inspecting headers under `/opt/mellanox/doca/infrastructure/include`. |
| "Why does my build fail with `pkg-config` not finding `doca-...`?" | "Layout of an installed DOCA package" section above (`PKG_CONFIG_PATH`), then Installation Guide. |
| "What is the latest version / what changed?" | Release Notes. |
| "What does the DOCA version number mean? Is LTS still supported?" | Compatibility Policy (Public documentation entry points table). |
| "How do I run DOCA on Kubernetes / provision a DPU?" | DOCA Platform Framework on GitHub. |
| "I have a behavior I cannot explain." | Release Notes (known issues) first; then the DOCA Developer Forum. Never go to the forum first. |

## What this skill deliberately does not cover

This file is intentionally a **map**, not a tutorial. It does not contain:

- DOCA library tutorials (those live in the per-library guides).
- API reference (lives in headers and the per-library guides).
- Build-system deep-dives (lives in the Installation Guide and the sample
  `meson.build` files).
- Performance tuning, driver-level setup, OFED interaction (lives in the
  Installation Guide and library-specific guides).

When the agent needs those, it should fetch the matching public document or
read the matching installed file. As more focused skills are added, they
should appear in [SKILLS.md](../../SKILLS.md) and link back here for the
"where to look" lookups.

## Related skills

For env preparation — install verification, build environment
(`pkg-config`, headers, hugepages, devlink), env-class debugging, and
the *I have no install yet* path with the public NGC DOCA container
(`nvcr.io/nvidia/doca/doca`) as the universal Stage-1 fallback for any
user on macOS, Windows, or Linux without DOCA — load
[`doca-setup`](../doca-setup/SKILL.md). That skill stops at *"the
install is healthy and the env is ready"*.

For general DOCA programming patterns shared across every library —
the canonical `pkg-config doca-<library>` build pattern (C/C++ direct
or non-C via FFI), the universal *derive a custom first app from a
shipped sample* workflow, the universal lifecycle (`cfg-create →
init → start → use → stop → destroy`), the cross-library
`DOCA_ERROR_*` taxonomy, and the program-side debug order — load
[`doca-programming-guide`](../doca-programming-guide/SKILL.md). Each
library skill extends its `## modify` (first-app derivation) with
library-specific overrides.

For DOCA Flow internals — port and representor setup, pipe creation,
match/action specifications, pipe validation before hardware programming,
Flow counters and traces, Flow version compatibility, and debugging
`DOCA_ERROR_*` failures from the Flow API — load
[`doca-flow`](../libs/doca-flow/SKILL.md). That skill assumes this one is
available for shared documentation routing and install-layout lookups,
`doca-setup` for environment preparation, and `doca-programming-guide`
for the cross-library programming patterns it layers on top of.

## URL audit

Every URL referenced by this routing map is HEAD-checked against the
public NVIDIA documentation surface on every commit, so bundle
releases always ship a routing map whose every URL was reachable at
release time. If a URL on this page no longer resolves, that is the
release's bug, not yours — fall back to the umbrella entry points
listed in *Public documentation entry points* (DOCA SDK index, DOCA
Libraries / Services / Tools umbrella pages) and search from there.
