---
name: doca-public-knowledge-map
description: Comprehensive map of every public DOCA knowledge source — docs.nvidia.com pages, programming guides, downloads, public GitHub repos, NGC catalog, developer forum — plus the on-disk layout of an installed DOCA package, so any agent can locate authoritative information without access to the DOCA source repository.
kind: knowledge
---

# DOCA Public Knowledge Map

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
   by `ci/check-skill.sh`.
5. **No source-tree paths.** Do not reference `devtools/...`, `docs/ai/...`,
   or any path that only exists inside the DOCA repository. Customers do not
   have those.

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
| **DOCA Libraries** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Libraries/index.html> | Canonical list of every public DOCA library with its quality level. Always check here first when the user's library is not in the table below. |
| DOCA Core (umbrella) | <https://docs.nvidia.com/doca/sdk/DOCA-Core/index.html> | The shared object-model every DOCA library is built on: `doca_dev`, `doca_devinfo`, `doca_pe` (progress engine), `doca_buf` / `doca_mmap`, `doca_ctx` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy. Read this whenever the user is touching more than one library or asking *"how does DOCA in general work?"*. |
| DOCA Common | <https://docs.nvidia.com/doca/sdk/DOCA-Common/index.html> | The base utility library every DOCA program links against (`doca-common` `pkg-config` module). Pulled in transitively when you depend on any other DOCA library. |
| DOCA Flow | <https://docs.nvidia.com/doca/sdk/DOCA-Flow/index.html> | Port setup, device or representor selection, pipes, actions, actions memory, entry lifecycle. |
| DOCA Flow Connection Tracking | <https://docs.nvidia.com/doca/sdk/DOCA-Flow-Connection-Tracking/index.html> | Stateful CT layer on top of DOCA Flow — connection-aware pipes, aging, NAT/SNAT/DNAT patterns. Load alongside `DOCA Flow` when the user asks about CT, conntrack, or stateful firewall offload. |
| DOCA Ethernet | <https://docs.nvidia.com/doca/sdk/DOCA-Ethernet/index.html> | RX/TX queues, packet I/O, `eth_rxq` / `eth_txq` lifecycle. Underpins the GPU Packet Processing app and most line-rate examples. |
| DOCA RDMA | <https://docs.nvidia.com/doca/sdk/DOCA-RDMA/index.html> | RDMA verbs over BlueField / ConnectX, queue-pair lifecycle, DOCA-RDMA send / recv / write / read patterns. |
| DOCA RDMA Verbs | <https://docs.nvidia.com/doca/sdk/DOCA-RDMA-Verbs/index.html> | The lower-level Verbs surface beneath DOCA RDMA. Load this only when the user explicitly needs raw verbs semantics (rare; DOCA RDMA is the canonical entry). |
| DOCA DPA | <https://docs.nvidia.com/doca/sdk/DOCA-DPA/index.html> | DPA host / device split-build flow, DPACC context, DPA annotation conventions. |
| DOCA DPA Comms | <https://docs.nvidia.com/doca/sdk/DOCA-DPA-Comms/index.html> | DPA-side communication primitives. Load alongside `DOCA DPA` when the user is wiring DPA kernels into the network. |
| DOCA DPA Verbs | <https://docs.nvidia.com/doca/sdk/DOCA-DPA-Verbs/index.html> | DPA-side verbs surface. Load alongside `DOCA DPA` when the user needs verbs from inside a DPA kernel. |
| DOCA GPUNetIO | <https://docs.nvidia.com/doca/sdk/DOCA-GPUNetIO/index.html> | GPU-initiated networking, CUDA + DOCA integration patterns. |
| DOCA Comch (formerly Comm Channel) | <https://docs.nvidia.com/doca/sdk/DOCA-Comch/index.html> | Host ↔ DPU control-plane messaging. **Library was renamed in DOCA 2.5**: the URL slug is `DOCA-Comch`, not `doca-comm-channel`. The `pkg-config` module on installed systems is `doca-comch`. |
| DOCA Telemetry | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry/index.html> | DOCA's telemetry collection surface — schemas, sampling, integration with the DOCA Telemetry Service (DTS). |
| DOCA Telemetry Exporter | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Exporter/index.html> | Application-side library used to *publish* telemetry from a DOCA program (distinct from `DOCA Telemetry`, which is the collection / consumption surface). |
| DOCA DMA | <https://docs.nvidia.com/doca/sdk/DOCA-DMA/index.html> | Host ↔ DPU memory copy via the BlueField DMA engine. The DMA Copy reference application is the canonical example. |
| DOCA Compress | <https://docs.nvidia.com/doca/sdk/DOCA-Compress/index.html> | Hardware-accelerated compression / decompression. Pairs with the File Compression reference application. |
| DOCA AES-GCM | <https://docs.nvidia.com/doca/sdk/DOCA-AES-GCM/index.html> | Hardware-accelerated AES-GCM encryption / decryption. Member of the DOCA Crypto Acceleration family. |
| DOCA SHA | <https://docs.nvidia.com/doca/sdk/DOCA-SHA/index.html> | Hardware-accelerated SHA hashing. Pairs with the File Integrity reference application. |
| DOCA Erasure Coding | <https://docs.nvidia.com/doca/sdk/DOCA-Erasure-Coding/index.html> | Hardware-accelerated erasure coding (RS / similar). Used in storage workloads. |
| DOCA App Shield (library) | <https://docs.nvidia.com/doca/sdk/DOCA-App-Shield/index.html> | Process-introspection primitives the App Shield Agent application is built on. Distinct from the App Shield Agent reference application page. |
| DOCA PCC (library) | <https://docs.nvidia.com/doca/sdk/DOCA-PCC/index.html> | Programmable congestion control library (DPA-hosted). Distinct from the PCC reference application and the `doca_pcc_counter` tool. |
| DOCA UROM (library) | <https://docs.nvidia.com/doca/sdk/DOCA-UROM/index.html> | Unified Communication Remote Memory Operations library. Distinct from the DOCA UROM Service. |
| DOCA Arg Parser | <https://docs.nvidia.com/doca/sdk/DOCA-Arg-Parser/index.html> | Argument parser used by every shipped DOCA sample and reference application. Worth knowing when the user adapts a sample's CLI surface. |
| DOCA Log | <https://docs.nvidia.com/doca/sdk/DOCA-Log/index.html> | DOCA's logging primitive — log registries, log levels, integration with `DOCA_LOG_LEVEL` and `--sdk-log-level`. Cross-references [`doca-debug`](../doca-debug/SKILL.md) for the runtime-debug story. |
| DOCA Device Emulation (umbrella) | <https://docs.nvidia.com/doca/sdk/DOCA-Device-Emulation/index.html> | Umbrella for the device-emulation libraries (PCI Generic, virtio, virtio-fs). Start here if the user is building emulated PCIe devices on BlueField. |
| DOCA Switching | <https://docs.nvidia.com/doca/sdk/DOCA-Switching/index.html> | DOCA's switching abstraction (BlueField switch dataplane). |
| DOCA Pipeline Language | <https://docs.nvidia.com/doca/sdk/DOCA-Pipeline-Language-Services-Guide/index.html> | DPL (Pipeline Language) — declarative pipeline definition. Load this when the user mentions "DPL" or asks about declarative dataplane programming. |
| DOCA Storage Applications | <https://docs.nvidia.com/doca/sdk/DOCA-Storage-Applications/index.html> | Index of DOCA's storage-focused reference applications (Comch-to-RDMA zero-copy, GGA offload, SBC generator, initiator, target). Use this entry when the user's question is *"how do I move storage I/O across the BlueField?"* before drilling into a specific app guide. |
| DOCA Rivermax | <https://docs.nvidia.com/doca/sdk/DOCA-Rivermax/index.html> | DOCA's Rivermax integration (media / streaming workloads). |
| DOCA STA | <https://docs.nvidia.com/doca/sdk/DOCA-STA/index.html> | Storage Transport Acceleration library. |
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
| **DOCA Services** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Services/index.html> | Canonical list of every public DOCA service with its purpose and guide link. Always check here first when a service is not in the table below. |
| DOCA Management Service (DMS) | <https://docs.nvidia.com/doca/sdk/DOCA-Management-Service-Guide/index.html> | Centralized configuration / operation of BlueField and ConnectX devices via gRPC (gNMI for config, gNOI for system ops). Covered by the `doca-dms` skill. |
| DOCA Telemetry Service (DTS) | <https://docs.nvidia.com/doca/sdk/DOCA-Telemetry-Service-Guide/index.html> | Telemetry collection container on BlueField. Use this for streaming telemetry (DMS does *not* support gNMI Subscribe). |
| DOCA BlueMan Service | <https://docs.nvidia.com/doca/sdk/DOCA-BlueMan-Service-Guide/index.html> | BlueField management dashboard service. |
| DOCA Firefly Service | <https://docs.nvidia.com/doca/sdk/DOCA-Firefly-Service-Guide/index.html> | PTP / time synchronization service. |
| DOCA Flow Inspector Service | <https://docs.nvidia.com/doca/sdk/DOCA-Flow-Inspector-Service-Guide/index.html> | Mirrored-flow inspection service. |
| DOCA HBN Service | <https://docs.nvidia.com/doca/sdk/DOCA-HBN-Service-Guide/index.html> | Host-Based Networking (BGP/EVPN/VXLAN) service. |
| DOCA SNAP Service | <https://docs.nvidia.com/doca/sdk/DOCA-SNAP-Services/index.html> | NVMe / virtio-blk SNAP storage service (BlueField-3). The umbrella; specific generations live at *DOCA-SNAP-3-User-Guide* and *DOCA-SNAP-4-Service-Guide*. |
| DOCA UROM Service | <https://docs.nvidia.com/doca/sdk/DOCA-UROM-Service-Guide/index.html> | Unified Communication Remote Memory Operations service. |
| DOCA Argus Service | <https://docs.nvidia.com/doca/sdk/DOCA-Argus-Service-Guide/index.html> | DOCA's runtime-security / monitoring service for BlueField. |
| DOCA Virtio-net Service | <https://docs.nvidia.com/doca/sdk/DOCA-Virtio-net-Service-Guide/index.html> | Virtio-net device emulation service. |

The **Container Deployment Guide**
(<https://docs.nvidia.com/doca/sdk/DOCA-Container-Deployment-Guide/index.html>)
is the cross-service reference for how DOCA service containers are
deployed on BlueField.

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
| **DOCA Tools** (umbrella index) | <https://docs.nvidia.com/doca/sdk/DOCA-Tools/index.html> | Canonical list of every public DOCA tool with its purpose and guide link. Always check here first when a tool is not in the table below. |
| Capabilities Print Tool (`doca_caps`) | <https://docs.nvidia.com/doca/sdk/DOCA-Capabilities-Print-Tool/index.html> | Prints DOCA devices and the per-library capabilities they support. Side-effect-free; safe to call early. Covered by the `doca-caps` skill. |
| DOCA Bench | <https://docs.nvidia.com/doca/sdk/DOCA-Bench/index.html> | Performance evaluation harness for DOCA applications. |
| Comm Channel Admin Tool | <https://docs.nvidia.com/doca/sdk/DOCA-Comm-Channel-Admin-Tool/index.html> | Admin CLI for Comch channels. |
| DPA Tools (umbrella) | <https://docs.nvidia.com/doca/sdk/DPA+Tools> | DPA developer / admin CLIs. The umbrella; per-tool guides live at *DOCA-DPA-GDB-Server-Tool*, *DOCA-DPA-PS-Tool*, and *DOCA-DPA-Statistics-Tool*. |
| DPACC Compiler | <https://docs.nvidia.com/doca/sdk/DOCA-DPACC-Compiler/index.html> | The DPA host/device split-build compiler. Not strictly a runtime tool — but every DPA developer needs its options reference, so it lives in the tools surface. |
| DOCA DPU CLI | <https://docs.nvidia.com/doca/sdk/DOCA-DPU-CLI/index.html> | Administrative CLI for the BlueField DPU itself. |
| Flow Tune Tool | <https://docs.nvidia.com/doca/sdk/DOCA-Flow-Tune-Tool/index.html> | Visibility / analysis CLI for DOCA Flow programs. |
| Flow Tune Server | <https://docs.nvidia.com/doca/sdk/DOCA-Flow-Tune-Server/index.html> | The long-running server side of Flow Tune. Distinct from the *Tool* row above; load both when the user asks about end-to-end Flow Tune. |
| PCC Counter | <https://docs.nvidia.com/doca/sdk/DOCA-PCC-Counter-Tool/index.html> | PCC counter inspection. |
| Socket Relay | <https://docs.nvidia.com/doca/sdk/DOCA-Socket-Relay/index.html> | Socket relay between host and DPU. |
| DOCA Ngauge | <https://docs.nvidia.com/doca/sdk/DOCA-Ngauge/index.html> | Diagnostic / measurement tool. |
| `doca-hugepages` Tool | <https://docs.nvidia.com/doca/sdk/DOCA-doca-hugepages-Tool/index.html> | Helper to set up huge-page reservations expected by some DOCA workloads. Cite this whenever the user hits hugepage-allocation failures during init. |

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

| Last full audit | Against DOCA docs version | Outcome |
| --- | --- | --- |
| 2026-05-13 | v3.3.0 (current `docs.nvidia.com/doca/sdk/` redirect target) | All URLs in this file fetched successfully. Five URLs fixed in this audit: *DOCA Downloads* dropped `/networking/`; *Forum* moved from category 362 → 370; *Comm Channel* renamed to *Comch* (`DOCA-Comch/index.html`); *DOCA Apps and Tools* renamed to *DOCA Reference Applications* (`DOCA-Reference-Applications/index.html`); *DOCA Samples Overview* row removed (page no longer exists in current sdk; samples are documented per-library inside each library guide). Added: *DOCA RDMA* row (was missing from libraries table). |
| 2026-05-14 | v3.3.0 | Three content-correctness fixes surfaced by Prompt-A subagent smoke test (the lint did not catch these — the URLs were 200, just pointing at the wrong page or with cosmetic noise): *Flow Tune* row corrected to `DOCA+Flow+Tune+Tool` (was wrongly pointing at `DOCA+PCC+Counter+Tool`); *Container Deployment Guide* URL stripped of stray `.md` extension to match the rest of the table; "Topic to where to look first" routing for samples updated to point at the per-library guide on docs.nvidia.com (it had still mentioned the deprecated *DOCA Samples Overview* page, contradicting the prose two sections above). |
| 2026-05-14 (round 2 sharpening, batch 1) | v3.3.0 (claimed; see batch 2) | Added one missing top-level reference: *DOCA Compatibility Policy* (`docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html`) — NVIDIA's authoritative release/versioning/upgrade policy. Surfaced as a gap during round 1 demo (the agent could explain version *detection* but had no canonical NVIDIA page to cite for version *policy*). Added to the "Public documentation entry points" table (between *Release Notes* and *Developer Zone*) and cross-linked from `doca-programming-guide CAPABILITIES.md ## Version compatibility` as the upstream source for the program-side rules in that section. |
| 2026-05-14 (round 2 sharpening, batch 2) | **v3.1.0** observed on the live `docs.nvidia.com/doca/sdk/index.html` (the prior audit row's "v3.3.0 redirect target" claim had drifted within ~24h — NVIDIA appears to have rolled the SDK index default redirect back to v3.1.0). | Five fixes surfaced by a fresh-agent orientation smoke test (the lint did not catch any of these — the URLs were 200, the failures were content-correctness, content-coverage, or routing-completeness): (1) **Added** *DOCA Developer Quick Start Guide* (`docs.nvidia.com/doca/sdk/doca-developer-quick-start-guide/index.html`) to the "Public documentation entry points" table — the literal "how do I start?" page on the live SDK index, previously missing; (2) **Tightened** the *Compatibility Policy* row description to match the page's actual content (source / binary / behavioral compatibility, quarterly GA + October LTS, semver) instead of the looser "upgrade and downgrade paths" phrasing; (3) **Added** a new top-level *First-contact discovery* section with the four canonical questions an agent must ask (OS / hardware / goal / language) before recommending any path — surfaced because a fresh agent had to re-derive this question set from scratch; (4) **Added** a *Quick Start vs no-install* routing row and a *hardware selection* routing row to the "Topic to where to look first" table — both predictable beginner intents previously absorbed implicitly; (5) **Recorded** the v3.1.0 vs v3.3.0 redirect-target drift here so the next audit re-checks the live page rather than relying on the prior row's claim. |
| 2026-05-14 (round 2 merge gate \u2014 baseline-vs-skills A/B + upstream validator) | v3.3.0 (per `/doca/sdk/DOCA-Libraries/index.html`) | **Merge-gate addendum to the sign-off row below.** Two further validations the user asked for explicitly before merge: (a) Replicated the round-1 demo's baseline-vs-skills A/B model on the round-2 state. Two fresh baseline subagents with no access to the bundle (and no access to `devops/` or any demo file) answered prompt 1 (orientation) and prompt 4 (link-error debug). Strict-grade against the prompt-YAML criteria: prompt 1 baseline 5/6 vs skills 6/6 (decisive criterion: umbrella URLs surfaced); prompt 4 baseline 4/6 vs skills 6/6 (decisive criteria: canonical 7-layer ladder + Flow multi-`*.so` split as confirmed fact). Aggregate: baseline 9/12 vs skills 12/12 (+3, +25 pp). **Honest narrative shift:** 2026 baseline is meaningfully stronger than 2025 baseline \u2014 it no longer fabricates `doca_version()` / `-ldoca_common` etc. The bundle's value proposition has moved from *prevent hallucination* to *deliver the canonical answer shape consistently*. The second is more durable because it does not depend on baseline staying weak. (b) Ran the upstream Anthropic-ecosystem validator (`claude-skill-check` 0.1.0; the package the user described as "skills-ref" doesn't exist as an installable name, but `claude-skill-check` is the actual community-validator equivalent) on every `SKILL.md`. Result: **0 errors per file, 1 warning per file** (`W900 unknown field 'kind'`) \u2014 expected and by design (`kind:` is the bundle's own routing contract). Updated the Jenkinsfile *Validate frontmatter* stage to invoke `claude-skill-check` (was a placeholder `agentskills validate` before). |
| 2026-05-14 (round 2 quality gate sign-off) | v3.3.0 (`/doca/sdk/DOCA-Libraries/index.html`); v3.1.0 (SDK index landing) | **Round-2 quality gate validations 1–6 PASSED.** Validation 1 (coverage rebalance): batch 3 below. Validation 4 (per-skill data audit): one missing cross-link found and fixed (`doca-setup CAPABILITIES.md ## Version compatibility` now anchors to the Compatibility Policy as the upstream rulebook). Validation 5 (separation audit): confirmed clean ownership — `doca-setup` owns env layers (1–4); `doca-programming-guide` owns program layers (lifecycle / error / library); `doca-debug` owns the cross-cutting ladder + tooling + forum escalation; bidirectional cross-links across all three; `libs/doca-flow ## debug` extended with cross-link to `doca-debug` for cross-cutting parts. Validation 2 (debug-prompt addition): new `devops/runner/prompts/04_link_error_debug.yaml` with explicit `co_loads_three_skills` criterion. Validation 3 (CI coverage check): new `devops/ci/check-coverage.sh` wired into `Jenkinsfile.skills.ci` and `ab_runner.py`. Bundle currently at 100% catalog coverage (57/57). Validation 6 (two-agent self-consistency test): two fresh subagents (`24c100ff-…` on prompt 4, `4020eb09-…` on prompt 1) both passed all 6 of their respective criteria; Agent B explicitly cited all three new umbrella URLs (Libraries / Services / Tools). The bundle is sign-off-ready for Wave-3 expansion. |
| 2026-05-14 (round 2 sharpening, batch 3 — coverage) | v3.3.0 (`/doca/sdk/DOCA-Libraries/index.html` shows v3.3.0; the SDK index `index.html` is still v3.1.0 — the per-page version differs from the index landing) | **Coverage rebalance.** Surfaced because a fresh-agent test flagged that the bundle's library table had only 7 of the 25+ public DOCA libraries, which biases the agent toward the listed subset (the "agent focuses on what it knows" failure mode). Diff against the live `DOCA-Libraries/index.html` listing yielded 19 missing library rows; against `DOCA-Services/index.html` yielded 2 missing service rows (Argus, Virtio-net); against `DOCA-Tools/index.html` yielded 5 missing tool rows (DPACC Compiler, DPU CLI, Flow Tune Server, Ngauge, doca-hugepages). All 36 candidate URLs HEAD-checked 200 before being added. **Also added** an "umbrella index" row at the top of each of the three tables pointing at `DOCA-Libraries`, `DOCA-Services`, `DOCA-Tools` respectively — these are the canonical "I don't know — show me everything" escape hatches the agent should hit *before* declining to answer or guessing a URL. The umbrella rows close the structural gap that allowed the original 7-row table to feel complete. **URL hygiene fix included:** moved DMS / DTS / BlueMan / Firefly / Flow Inspector / HBN / SNAP / UROM rows from the legacy `DOCA+Foo+Service+Guide` URL form to the canonical `DOCA-Foo-Service-Guide/index.html` slug to match the new rows; same for tools (`DOCA+Capabilities+Print+Tool` → `DOCA-Capabilities-Print-Tool/index.html`, etc.). The legacy URLs still 302-redirect, so this is hygiene, not a functional fix. |

How to re-audit: run [`ci/check-skill.sh --all --check-urls`](../../ci/check-skill.sh)
from the repo root. It HEADs every URL in every skill file (including
this one), and fails on any non-`2xx`/`3xx` response. CI should run it
in URL mode whenever outbound network is available; locally, run it
before opening a PR that touches a URL or before bumping the row above
on a DOCA release. The script also enforces the *public-sources only*
contract from [`AGENTS.md`](../../AGENTS.md) ground rule #1 by
allowlisting NVIDIA hosts and rejecting URLs / paths that mention
internal tooling vocabulary; that part runs without network.
