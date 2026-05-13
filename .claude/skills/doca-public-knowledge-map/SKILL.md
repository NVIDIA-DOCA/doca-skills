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
4. **No private references.** Do not link to internal NVIDIA hostnames,
   Gerrit, NVBugs, Confluence, Jenkins, or any company-internal tool. They are
   not available to a customer agent.
5. **No source-tree paths.** Do not reference `devtools/...`, `docs/ai/...`,
   or any path that only exists inside the DOCA repository. Customers do not
   have those.

## Public documentation entry points

Start here for any conceptual question. These are the canonical NVIDIA-hosted
documents.

| Topic | URL | When to use |
| --- | --- | --- |
| DOCA SDK documentation index | <https://docs.nvidia.com/doca/sdk/index.html> | The top of the documentation tree. Always start here when the user asks an open-ended "how does DOCA do X?" question. |
| DOCA Overview | <https://docs.nvidia.com/doca/sdk/doca-overview/index.html> | High-level architecture: what DOCA is, what runs on the BlueField DPU vs. the host, libraries vs. applications vs. services vs. tools. |
| DOCA Installation Guide for Linux | <https://docs.nvidia.com/doca/sdk/installation-guide-for-linux/index.html> | Install steps, supported OSes, package layout, post-install verification. Read this whenever the user is setting DOCA up for the first time. |
| DOCA Programming Guide (index) | <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> | SDK architecture, common patterns, how libraries connect, how to wire up a sample. Read this before drilling into a specific library guide. |
| DOCA Release Notes | <https://docs.nvidia.com/doca/sdk/doca-release-notes/index.html> | What changed in a release, supported hardware, supported OSes, known issues. Read whenever the user's symptom could be a known issue. |
| Developer Zone — DOCA landing | <https://developer.nvidia.com/networking/doca> | Marketing-and-onboarding view (videos, tutorials, blog posts). Use only as a fallback when the official SDK docs do not have the topic yet. |
| DOCA Downloads | <https://developer.nvidia.com/networking/doca-downloads> | Where customers actually download DOCA packages, BFB images, host packages. Use this to answer "which package do I need?". |
| NGC Catalog (containers and resources) | <https://catalog.ngc.nvidia.com> | Find DOCA containers, model artifacts, and DPU images. Search for `doca` to enumerate. |
| DOCA Developer Forum | <https://forums.developer.nvidia.com/c/infrastructure/doca/362> | Last-resort discovery for undocumented behavior, real customer questions, NVIDIA staff answers. Always include the disclaimer that forum threads can age and may not match the user's installed version. |

## Library- and module-specific guides

Each major DOCA library has its own subtree under `/doca/sdk/`. Use the matching
guide once the user's question is narrow enough to be about a single library.

| Library | Guide | Typical questions it answers |
| --- | --- | --- |
| DOCA Flow | <https://docs.nvidia.com/doca/sdk/doca-flow/index.html> | Port setup, device or representor selection, pipes, actions, actions memory, entry lifecycle. |
| DOCA DPA | <https://docs.nvidia.com/doca/sdk/doca-dpa/index.html> | DPA host/device split-build flow, DPACC context, DPA annotation conventions. |
| DOCA GPUNetIO | <https://docs.nvidia.com/doca/sdk/doca-gpunetio/index.html> | GPU-initiated networking, CUDA + DOCA integration patterns. |
| DOCA Comm Channel | <https://docs.nvidia.com/doca/sdk/doca-comm-channel/index.html> | Host ↔ DPU control-plane messaging. |
| DOCA Telemetry | <https://docs.nvidia.com/doca/sdk/doca-telemetry/index.html> | Telemetry exporter, schemas, integration with Grafana/Prometheus. |
| DOCA Apps and Tools | <https://docs.nvidia.com/doca/sdk/doca-applications-overview/index.html> | The shipped reference applications (PCC, DPI, etc.) and the `doca_tools` CLIs. |
| DOCA Samples Overview | <https://docs.nvidia.com/doca/sdk/doca-samples-overview/index.html> | Catalog of the sample programs the SDK ships per library. |

If the user asks about a DOCA library that is not in this table, do **not**
guess the URL. Fall back to the SDK index and the user's installed sample
directory (see "Layout of an installed DOCA package" below).

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

## Topic to "where to look first" routing table

When the user asks something, route as follows:

| User intent | First place to look |
| --- | --- |
| "How do I install DOCA?" | Installation Guide + Downloads page (Public documentation entry points). |
| "Which package gives me library X?" | Installation Guide section on package matrix; then verify on the user's system with `pkg-config --list-all`. |
| "Show me a sample that uses library X." | `/opt/mellanox/doca/samples/doca_<X>/` if installed; otherwise the DOCA Samples Overview page. |
| "How do I build a DOCA sample?" | Library guide + the sample's own `meson.build` inside `/opt/mellanox/doca/samples/...`. |
| "What is the API for X?" | Library guide; confirm by inspecting headers under `/opt/mellanox/doca/infrastructure/include`. |
| "Why does my build fail with `pkg-config` not finding `doca-...`?" | "Layout of an installed DOCA package" section above (`PKG_CONFIG_PATH`), then Installation Guide. |
| "What is the latest version / what changed?" | Release Notes. |
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
should appear in [SKILLS.md](../../../SKILLS.md) and link back here for the
"where to look" lookups.

## Related skills

For the bridge between *"DOCA is installed"* and *"I have a running first
program"* — install verification, build environment (`pkg-config`,
headers, hugepages), building and running shipped samples, and deriving a
custom first application from a sample — load
[`doca-setup`](../doca-setup/SKILL.md). That skill is library-agnostic;
each library skill extends its `## modify` (first-app derivation) with
library-specific overrides.

For DOCA Flow internals — port and representor setup, pipe creation,
match/action specifications, pipe validation before hardware programming,
Flow counters and traces, Flow version compatibility, and debugging
`DOCA_ERROR_*` failures from the Flow API — load
[`doca-flow`](../doca-flow/SKILL.md). That skill assumes this one is
available for shared documentation routing and install-layout lookups,
and `doca-setup` for environment preparation.
