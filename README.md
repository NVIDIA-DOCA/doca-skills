# NVIDIA DOCA Skills

**Production-grade agent skill bundle for NVIDIA DOCA — 60 skills covering every public DOCA library, service, and tool.**

[![NVIDIA](https://img.shields.io/badge/NVIDIA-DOCA-76B900?style=flat&logo=nvidia&logoColor=white)](https://docs.nvidia.com/doca/sdk/index.html)
[![Agent Skills Spec](https://img.shields.io/badge/Agent%20Skills-Specification-blue)](https://agentskills.io/specification)
[![License](https://img.shields.io/badge/License-NVIDIA%20Software-green.svg)](#license)

> 📖 **DOCA SDK docs:** [docs.nvidia.com/doca/sdk](https://docs.nvidia.com/doca/sdk/index.html) &nbsp;·&nbsp;
> 🧪 **DOCA samples + applications:** [github.com/NVIDIA-DOCA/doca-samples](https://github.com/NVIDIA-DOCA/doca-samples) &nbsp;·&nbsp;
> 🛠️ **DOCA Platform Framework:** [github.com/NVIDIA/doca-platform](https://github.com/NVIDIA/doca-platform) &nbsp;·&nbsp;
> 💬 **DOCA Developer Forum:** [forums.developer.nvidia.com/c/infrastructure/doca/370](https://forums.developer.nvidia.com/c/infrastructure/doca/370)

---

This repository ships **60 portable, [AgentSkills.io](https://agentskills.io/specification)-compliant skills** that teach AI agents — Cursor, Anthropic Claude Code, OpenAI Codex CLI, Gemini CLI, GitHub Copilot, custom in-house LLMs — how to use NVIDIA DOCA correctly on host x86, BlueField Arm bare-metal, or inside containerized environments.

> ### Scope at a glance — what this bundle covers, and what it does not
>
> **In scope.** This bundle is focused on the **NVIDIA DOCA SDK** as shipped in the public DOCA monorepo at the currently-aligned release (DOCA 3.3 / `doca-3.3.0109`): every public DOCA **library** under `doca/libs/`, every public DOCA **service** under `doca/services/`, every public DOCA **tool** under `doca/tools/`, plus the cross-cutting setup / version / debug / deployment / programming-guide overlays. If a developer building an application against the DOCA SDK headers can ask a question about it, that question is in scope for this bundle.
>
> **Out of scope (covered by sibling efforts, not by this bundle).** Externally-productized NVIDIA networking software that ships **outside** the DOCA monorepo is intentionally excluded so that this bundle stays focused and accurate. The major examples — each owned by a different team with its own skill / docs surface — are:
>
> - **DOCA Platform Framework (DPF)** — separately-productized; DPF-specific skills are being prepared as part of the DPF PoR.
> - **DOCA Microservices** — DOCA HBN Service, DOCA BlueMan Service, DOCA SNAP Services, DOCA Virtio-net Service, DOCA Telemetry Service (DTS as-deployed). These are productized externally to `doca/services/` and are not modelled here.
> - **NVIDIA Network Operator** — already has its own AI skills shipped at <https://mellanox.github.io/network-operator-docs/ai-skills.html>; use those for Network Operator questions.
> - **BlueField BSP / BFB / `bfb-install` / RShim / TMFIFO / `bf.cfg` / BMC** lifecycle — the agent will recognize the boundary, route to public BlueField BSP docs, and refuse to invent BSP procedure.
>
> When the agent receives a question about an out-of-scope product it does **not** synthesize an answer from training knowledge. The required response shape is: (a) name the product as externally-productized and out-of-bundle, (b) name the boundary (strict 1:1 with the DOCA monorepo), and (c) route the user to the right authoritative `docs.nvidia.com/doca/sdk/` page and the DOCA Developer Forum search hint — via the per-product row in [`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md). Full non-goal contract: [`AGENTS.md` § Non-goals item 7](AGENTS.md#non-goals-questions-the-agent-should-recognize-and-refuse-politely).

The bundle is **strictly 1:1 with the `doca/{libs,services,tools}/` monorepo** at the currently-aligned DOCA release (DOCA 3.3 / `doca-3.3.0109`): every public DOCA library, every public DOCA service, every public DOCA tool — plus 9 cross-cutting skills for setup, debug, hardware safety, version-pinning, bare-metal vs containerized deployment, programming patterns, public-docs routing, structured-tools contract, and non-goal routing for externally-productized NVIDIA networking software (27 products covered).

The whole bundle is **vendor-neutral by design**: the directory layout is `skills/<name>/SKILL.md` (the AgentSkills.io standard), not `.claude/skills/` or any other runtime-specific path, so the bundle reads naturally to any agent that follows the open standard.

---

## Quickstart

### Install (one-liner)

> **Repository host.** The `doca-skills` bundle is published from the public NVIDIA-owned GitHub repository [`NVIDIA-DOCA/doca-skills`](https://github.com/NVIDIA-DOCA/doca-skills). The clone URLs in the Quickstart below resolve over the public internet; no NVIDIA-internal credentials are required. The bundle is also mirrored into the [NVIDIA Skills catalog](https://github.com/NVIDIA/skills) — skill changes land in this repository first and are mirrored daily.

The same one-liner installs into **any AgentSkills.io-aware agent** — `cursor`, `claude-code`, `codex`, `gemini-cli`, `kiro-cli`, `agents` (the cross-platform standard), or `custom --dest /path/to/anywhere`. Replace `<agent>` with whichever you want:

```bash
git clone https://github.com/NVIDIA-DOCA/doca-skills.git \
  && cd doca-skills && ./install.sh --agent <agent>
```

Concrete examples (copy-paste any one of them — there is no agent-specific install path; the only difference is the target directory the installer writes to):

```bash
# Cursor                  → ~/.cursor/skills/
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent cursor

# Anthropic Claude Code   → ~/.claude/skills/
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent claude-code

# OpenAI Codex CLI        → ~/.agents/skills/   (Codex's PRIMARY path per the official Codex Skills spec)
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent codex

# Google Gemini CLI       → ~/.gemini/skills/   (Gemini also reads ~/.agents/skills/ as alias)
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent gemini-cli

# Kiro CLI                → ~/.kiro/skills/     (auto-discovered by Kiro's default agent since v1.26.0)
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent kiro-cli

# Cross-platform AgentSkills.io target → ~/.agents/skills/  (shared by Codex; aliased by Gemini)
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent agents

# Any AgentSkills.io target you control → /path/you/give/it
git clone https://github.com/NVIDIA-DOCA/doca-skills.git && cd doca-skills && ./install.sh --agent custom --dest /path/to/your/agent/skills
```

> **Per-agent skill-discovery paths (where each agent looks for `<name>/SKILL.md`).**
> The installer below maps `--agent <name>` to that agent's spec-correct location so you don't have to remember each one. The flat `<dest>/<skill-name>/SKILL.md` layout is honored by every AgentSkills.io-aware agent; the bundle's `libs/` / `services/` / `tools/` slot is collapsed at install time, so a skill named `doca-flow` lands at `<dest>/doca-flow/SKILL.md` regardless of which slot it lives in inside the bundle.
>
> | Agent | Spec-correct install path | Notes |
> |---|---|---|
> | Cursor | `~/.cursor/skills/<name>/SKILL.md` | Loads on the next agent reload. |
> | Anthropic Claude Code | `~/.claude/skills/<name>/SKILL.md` | Loads on the next session. |
> | OpenAI Codex CLI | `~/.agents/skills/<name>/SKILL.md` | The PRIMARY path per the [official Codex Skills spec](https://developers.openai.com/codex/skills/). The legacy `~/.codex/skills/` is also read for backward-compat; if you need to write there specifically, use `--agent custom --dest ~/.codex/skills`. Make sure skills are enabled — either pass `--enable skills` or set `skills = true` in `~/.codex/config.toml`. |
> | Google Gemini CLI | `~/.gemini/skills/<name>/SKILL.md` | Gemini also reads `~/.agents/skills/` as an alias (with precedence when both exist). |
> | Kiro CLI | `~/.kiro/skills/<name>/SKILL.md` | Auto-discovered by the `kiro_default` agent since Kiro v1.26.0; on older Kiro you have to add `"skill://~/.kiro/skills/*/SKILL.md"` to your custom agent's `resources` field. |
> | Cross-platform (`agents`) | `~/.agents/skills/<name>/SKILL.md` | This is the emerging cross-platform Agent Skills standard — Codex reads it natively, Gemini treats it as an aliased high-precedence source. Use this when you want one shared pool for multiple agents on the same host. |
>
> **"Reload your agent" — what does that mean?** Most agents discover skills only at session start. After running `install.sh`, open a new agent session / tab / CLI invocation (or, in Cursor's case, use the IDE command palette's *Reload Window*). Then ask a DOCA question that matches one of the skill descriptions and the bundle will activate.

Or, if you prefer a single pipe-to-bash form (no manual `cd` required) — works for every agent with one flag swap:

```bash
curl -fsSL https://raw.githubusercontent.com/NVIDIA-DOCA/doca-skills/main/install.sh \
  | bash -s -- --agent <agent> \
                --repo https://github.com/NVIDIA-DOCA/doca-skills.git
```

You can also fan out into multiple agents in a single run:

```bash
./install.sh --agent cursor --agent claude-code --agent codex --agent gemini-cli --agent kiro-cli --agent agents
```

> **Why two commands and not `npx`?** The bundle ships as a portable directory of [AgentSkills.io](https://agentskills.io/specification)-compliant skill folders, not as a published npm package, so the install path is `git clone` + `./install.sh` rather than `npx`. The installer is intentionally a small (~310-line) bash script with zero runtime dependencies beyond `bash` / `cp` / `ln` / `mkdir` / `readlink` — auditable, offline-friendly, and reproducible on every Linux / macOS host without any package manager surface. Once installed, the activation flow (`AGENTS.md` → `SKILLS.md` → per-skill `SKILL.md`) is identical to every other AgentSkills.io-aware bundle including [`NVIDIA/skills`](https://github.com/NVIDIA/skills).

The installer copies (or symlinks) the skill folders into your agent's skill discovery directory. The skills are available the next time your agent loads skills and encounters a relevant task — for example, ask your agent:

> *"Help me build a DOCA Flow application that steers SMPTE-2110 traffic on my BlueField-3 to specific RX queues for a Rivermax receiver."*

…and the bundle's `doca-setup` + `doca-version` + `doca-programming-guide` + `doca-flow` + `doca-rmax` + `doca-eth` skills activate in the right order, against the DOCA samples shipped in the public [`NVIDIA-DOCA/doca-samples`](https://github.com/NVIDIA-DOCA/doca-samples) repository and against your live `/opt/mellanox/doca` install.

### Install for a specific agent

The installer recognizes these common AgentSkills.io-aware clients (one-flag, idempotent, repeatable):

```bash
# Cursor (writes to ~/.cursor/skills/ or .cursor/skills/ at workspace root)
./install.sh --agent cursor

# Anthropic Claude Code (writes to ~/.claude/skills/)
./install.sh --agent claude-code

# OpenAI Codex CLI (writes to ~/.agents/skills/ — Codex's PRIMARY path per the official spec)
./install.sh --agent codex

# Gemini CLI (writes to ~/.gemini/skills/ — Gemini also reads ~/.agents/skills/ as alias)
./install.sh --agent gemini-cli

# Kiro CLI (writes to ~/.kiro/skills/ — auto-discovered by default agent since Kiro v1.26.0)
./install.sh --agent kiro-cli

# Cross-platform Agent Skills target (writes to ~/.agents/skills/)
./install.sh --agent agents

# Generic AgentSkills.io target (just writes to the path you give it)
./install.sh --agent custom --dest /path/to/your/agent/skills/
```

Use `--agent` more than once to install the same skill bundle into multiple agents:

```bash
./install.sh --agent claude-code --agent cursor --agent codex --agent gemini-cli --agent kiro-cli
```

### Install one skill without prompts

```bash
./install.sh --agent cursor --skill doca-flow --yes
```

Replace `doca-flow` with any skill name from the [Skill Catalog](#skill-catalog). Without `--skill`, the installer installs all 60 skills (this is the default and is what an external reviewer should use).

### Browse the catalog without installing

```bash
./install.sh --list
```

Prints the same catalog as in this README, with each skill's slot, name, one-line summary, and the path that would be installed.

### Workspace-local install (no global pollution)

```bash
./install.sh --agent cursor --dest ./.cursor/skills/
```

The skills install at your current workspace root, not in your `$HOME` agent directory — useful for per-project isolation.

### Manual install (just clone + load)

The agent's skill discovery is driven by `AGENTS.md` (industry convention) and the AgentSkills.io progressive-disclosure model. If you prefer not to run the installer, just clone the repo and open it in your agent. The agent reads the repo root `AGENTS.md`, walks to `SKILLS.md`, and loads the matching per-skill `SKILL.md` (plus `CAPABILITIES.md` / `TASKS.md`) when your question matches a `Use this skill when …` trigger:

```bash
git clone https://github.com/NVIDIA-DOCA/doca-skills.git
cd doca-skills
# Open in your agent — no further wiring required.
```

### Bring the skills into an existing workspace

If you already work in another repo and want the DOCA skills loaded alongside it, add this repo as a git submodule or sibling clone and either symlink `doca-skills/AGENTS.md` into your workspace root, or copy its contents into your existing `AGENTS.md`. Agents resolve `AGENTS.md` at workspace root by convention.

---

## Beginner roadmap — Stage 1 (container learning) → Stage 2 (hardware runtime)

If you are new to DOCA, the answer to *"how do I get to my first DOCA app?"* is a staged roadmap, not a single command. The bundle teaches a Stage-1-first path because almost every learning step can be done in a container on any OS without ordering hardware, and Stage 2 only matters once the user knows what to ask hardware *for*. The agent's response to any "I'm new to DOCA" prompt opens with this table before any command:

| Stage | What you are doing | Where you are | Bundle path |
| --- | --- | --- | --- |
| **Stage 1 — container learning** | Read the API surface, build / modify a shipped C sample, smoke the build, learn the `pkg-config doca-<library>` + meson pattern. **No real packets cross hardware.** This is the universal entry point for any user on macOS, Windows, or Linux without DOCA. | The public **NGC DOCA container** `nvcr.io/nvidia/doca/doca:<tag>`, pulled with Docker and run with `-it --rm`. `/opt/mellanox/doca` is populated inside the container by construction. | [`doca-setup ## no-install`](skills/doca-setup/TASKS.md#no-install) **Path 0**, then [`doca-programming-guide ## modify`](skills/doca-programming-guide/TASKS.md#modify) (the *modify-a-shipped-C-sample* workflow), then the matching library skill (e.g. [`doca-flow`](skills/libs/doca-flow/SKILL.md)). |
| **Stage 2 — hardware runtime** | Run the app you built in Stage 1 against real traffic on a real NIC / DPU. Programmed flows, real packets, counters move. | Either a **Linux host with a ConnectX / BlueField NIC** (Path C), or remote-into a **lab box that already has DOCA + hardware** (Path A). Cloud GPU/ARM SKUs do not generically include DOCA-eligible NICs and the agent does *not* pretend otherwise. | [`doca-setup ## no-install`](skills/doca-setup/TASKS.md#no-install) **Paths A / C**, then [`doca-bare-metal-deployment`](skills/doca-bare-metal-deployment/SKILL.md) or [`doca-container-deployment`](skills/doca-container-deployment/SKILL.md) depending on how the user wants to ship the app. |

**Resume point inside the container.** Once the user is inside Stage 1, the agent expects them to paste back the output of `pkg-config --modversion doca-<library>` and `pkg-config --cflags --libs doca-<library>`, plus `ls /opt/mellanox/doca/samples/<library>/<sample_name>/` for the C track. The skill resumes from [`doca-programming-guide ## modify`](skills/doca-programming-guide/TASKS.md#modify) step 1 with the real install in hand. This is the canonical hand-off between *no-install* answer-time and *real-install* doing-time.

**How to pick an NGC tag without guessing.** Image tags are version-dated and platform-shaped; never guess one. The deterministic rule:

1. Open the catalog **Tags** page directly: <https://catalog.ngc.nvidia.com/orgs/nvidia/teams/doca/containers/doca/tags>. This is the only authoritative list of tags that actually exist for `nvcr.io/nvidia/doca/doca`.
2. Detect the user's host axes — architecture (`uname -m`: `x86_64` → look for `linux-amd64`, `aarch64` / Apple Silicon → look for `linux-arm64`), OS family (Ubuntu / RHEL flavor in the tag string), and whether they need CUDA (default: no for first-app work; CUDA-enabled variants are larger and only relevant if the user is also using CUDA).
3. From the *visible* tags list, pick the **highest-numbered** tag matching those axes. The tag string is treated as opaque text from the catalog; the agent does NOT assemble a tag from version + arch fragments out of memory.
4. `docker pull nvcr.io/nvidia/doca/doca:<tag-copied-verbatim-from-the-catalog>`. If a particular tag asks for auth, the user signs up for a free NGC account at <https://ngc.nvidia.com>, generates an API key, and runs `docker login nvcr.io -u '$oauthtoken' -p <api-key>` once.
5. If the agent cannot reach the catalog page from this session, the agent says so explicitly and asks the user to paste the candidate tag from the catalog — it does NOT fabricate a tag string. This is the same *never invent symbols, URLs, paths, or package names* discipline as [AGENTS.md ground rule 3](AGENTS.md#ground-rules-every-agent-must-follow).

---

## Skill Catalog

60 skills, grouped by slot. Every skill conforms to AgentSkills.io and ships `SKILL.md` (frontmatter + body) + `CAPABILITIES.md` (what the skill can/cannot do) + `TASKS.md` (the worked tasks).

### Cross-cutting (9 skills)

These load on top-level questions that aren't tied to a single library/service/tool — install, version, build, debug, hardware safety, deployment shape, public-docs routing, structured-tools contract, non-goal routing.

| Skill | What it covers | When the agent loads it |
|---|---|---|
| [`doca-setup`](skills/doca-setup/SKILL.md) | Install verification, build env (pkg-config, headers, hugepages, devlink), env-class debug, no-install-yet path via the public NGC DOCA container. | Any "install / build env / I have no DOCA yet" question. |
| [`doca-version`](skills/doca-version/SKILL.md) | Four-source DOCA version audit chain: `pkg-config doca-common`, `/opt/mellanox/doca/applications/VERSION`, `doca_caps --version`, BF BFB. Catches mixed MLNX_OFED + DOCA-Host installs. | Any "what version am I on / why is X missing / are these versions compatible" question. |
| [`doca-programming-guide`](skills/doca-programming-guide/SKILL.md) | Cross-library programming patterns: the `pkg-config + meson` build pattern, the derive-from-sample workflow, the `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy. | Any cross-library programming question — "how do I structure a build", "how do I derive a first app", "how do I read `DOCA_ERROR_NOT_PERMITTED`". |
| [`doca-debug`](skills/doca-debug/SKILL.md) | Layered debug ladder (install → version → build → link → runtime → program → driver), verbosity controls (`--sdk-log-level`, `DOCA_LOG_LEVEL`, per-library trace), how to capture state for a Developer Forum post. | Any "DOCA symptom" — build won't compile, link can't resolve `doca_*`, runtime returns `DOCA_ERROR_*`, silent service. |
| [`doca-hardware-safety`](skills/doca-hardware-safety/SKILL.md) | The `## configure / ## modify / ## test` operator discipline for any change that touches live BlueField / NIC state — `mlxconfig`, firmware burn, BFB reflash, SFC flip. Preconditions: operator window, OOB console, rollback. | Any mutating change against live hardware. Loaded automatically alongside any tool/lib skill that prescribes such a change. |
| [`doca-bare-metal-deployment`](skills/doca-bare-metal-deployment/SKILL.md) | Launching, supervising, debugging DOCA-linked binaries directly on hardware (host x86 over PCIe or BF Arm bare-metal): launch mode, PCI/NUMA/CPU/IRQ binding, cgroup-v2/netns/numactl isolation, 7-layer error taxonomy. Handoff to BFB-install (out-of-scope, routes via non-goal #7). | The user is running or supervising a DOCA binary directly on hardware — no container, no kubelet. |
| [`doca-container-deployment`](skills/doca-container-deployment/SKILL.md) | Hands-on deploying an in-bundle DOCA service container on BlueField via kubelet-standalone + static-pod manifests. Smoke-before-bulk, layered error taxonomy (pod-spec, scheduling, pull, runtime, mount, network, version, host). | The user is deploying an Argus / DMS / Firefly / Flow-Inspector / OS-Inspector / UROM-Svc container. |
| [`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md) | Master routing index — every authoritative DOCA information source (public docs URLs, on-disk `/opt/mellanox/doca` layout, public GitHub repos, NGC catalog, Developer Forum) + the 27-product routing table for externally-productized NVIDIA networking software not in this bundle. | Any "where is / which doc / how do I find" question, AND any out-of-scope question that requires routing-with-substance (non-goal #7 contract). |
| [`doca-structured-tools-contract`](skills/doca-structured-tools-contract/SKILL.md) | JSON schemas the agent must produce for every infra step (env probe, version detect, hardware probe, capability snapshot, validate-before-commit, host-vs-DPU state diff). Plus the Detect / Prefer / Fall-back / Report behavior contract for the future structured-tools binaries. | The agent is about to emit JSON for any infra step, or is being wired into a structured-tool / function-calling dispatcher (MCP, OpenAI function calling) and needs the JSON-schema contract. |

### DOCA Libraries (28 skills)

Each library skill teaches the agent the library's API surface, build / link, lifecycle, the library-specific `DOCA_ERROR_*` shapes, and the derive-from-sample first-app pattern.

| Skill | DOCA library | One-line API surface |
|---|---|---|
| [`doca-aes-gcm`](skills/libs/doca-aes-gcm/SKILL.md) | DOCA AES-GCM | Hardware-accelerated AES-GCM encrypt/decrypt offload to BlueField / ConnectX. |
| [`doca-apsh`](skills/libs/doca-apsh/SKILL.md) | DOCA App Shield | Live-introspection of host processes from BlueField (zero host-agent footprint). |
| [`doca-argp`](skills/libs/doca-argp/SKILL.md) | DOCA Argument Parser | Sample-shaped CLI argument parsing used by every shipped DOCA sample. |
| [`doca-comch`](skills/libs/doca-comch/SKILL.md) | DOCA Comch | BlueField↔host control-channel message passing (consumer + producer patterns). |
| [`doca-common`](skills/libs/doca-common/SKILL.md) | DOCA Common | The foundation: contexts, devices, mmap, sync events, error / log / pe / mmap / mem APIs every other DOCA lib stands on. |
| [`doca-compress`](skills/libs/doca-compress/SKILL.md) | DOCA Compress | Hardware-offloaded DEFLATE compress / decompress and LZ4 *decompress* (LZ4 compress is not on the accelerator) on BlueField / ConnectX. |
| [`doca-devemu`](skills/libs/doca-devemu/SKILL.md) | DOCA Device Emulation | Device-emulation framework — umbrella for PCI Generic, virtio-net (`vnet`), virtio-fs (`vfs`), virtio-blk (`vblk`), and NVMe (`nvme`) sub-libraries that emulate PCIe devices toward the host from the BlueField side. Productized vblk / nvme paths route to the packaged DOCA SNAP Service (out of scope). |
| [`doca-dma`](skills/libs/doca-dma/SKILL.md) | DOCA DMA | Host↔BlueField (and DPU-local) DMA, including memory regions, mmap, copy / scatter-gather offload. |
| [`doca-dpa`](skills/libs/doca-dpa/SKILL.md) | DOCA DPA | Programming the BlueField-3 DPA (Data-Path Accelerator) processor: kernel launch, DPA-host coordination, RPC, mmap / sync events. |
| [`doca-dpdk-bridge`](skills/libs/doca-dpdk-bridge/SKILL.md) | DOCA DPDK Bridge | Interop layer for DOCA programs that also use DPDK port + queue / mempool abstractions. |
| [`doca-erasure-coding`](skills/libs/doca-erasure-coding/SKILL.md) | DOCA Erasure Coding | EC encode / decode offload — Reed-Solomon / matrix-based EC, on BlueField. |
| [`doca-eth`](skills/libs/doca-eth/SKILL.md) | DOCA Ethernet | Ethernet RX / TX queues (`doca_eth_rxq`, `doca_eth_txq`) — the queue layer underneath Flow steering. |
| [`doca-flow`](skills/libs/doca-flow/SKILL.md) | DOCA Flow | Programmable hardware steering on BlueField / ConnectX — pipes, match / action, counters, validation, HWS / SWS modes, Flow-CT for stateful. |
| [`doca-flow-dpa-provider`](skills/libs/doca-flow-dpa-provider/SKILL.md) | DOCA Flow DPA Provider | DPA-side helper for Flow actions / counters that run inside a DPA program. |
| [`doca-gpi`](skills/libs/doca-gpi/SKILL.md) | DOCA GPI | GPU Programming Interface — kernel-launched RDMA operations issued directly from a CUDA thread (pairs with `doca-rdma` and `doca-gpunetio`). |
| [`doca-gpunetio`](skills/libs/doca-gpunetio/SKILL.md) | DOCA GPUNetIO | GPU-side networking — RX / TX queues, semaphores, Flow steering controlled from CUDA kernels (no CPU on the data path). |
| [`doca-mgmt`](skills/libs/doca-mgmt/SKILL.md) | DOCA Management | Programmatic management APIs (devlink, firmware-version queries, NIC-state introspection) for tools that don't shell out. |
| [`doca-pcc`](skills/libs/doca-pcc/SKILL.md) | DOCA PCC | Programmable Congestion Control library — DPA-hosted algorithm slot + matching host-side glue; distinct from `doca_pcc_counter` (operator-side counter inspection) and the PCC reference application. |
| [`doca-pcc-ztr-rttcc-algo`](skills/libs/doca-pcc-ztr-rttcc-algo/SKILL.md) | DOCA PCC ZTR-RTTCC Algorithm | Shipped reference Zero-Touch-RTT Congestion-Control algorithm that runs under `doca-pcc`. |
| [`doca-rdma`](skills/libs/doca-rdma/SKILL.md) | DOCA RDMA | RDMA send / recv / write / read on RoCE + InfiniBand — verbs-equivalent surface with DOCA's lifecycle. |
| [`doca-rdmi`](skills/libs/doca-rdmi/SKILL.md) | DOCA RDMI | DOCA RDMA Initiator — accelerator-initiated (host or DPA-kernel) one-sided RDMA flow surface; pairs with `doca-rdma` for the general RDMA path. |
| [`doca-rmax`](skills/libs/doca-rmax/SKILL.md) | DOCA Rivermax | Sub-microsecond-jitter SMPTE 2110 / NMOS media streaming — wraps the external Rivermax SDK (license required, see non-goal #7 routing). |
| [`doca-sha`](skills/libs/doca-sha/SKILL.md) | DOCA SHA | Hardware-offloaded SHA-1 / SHA-256 / SHA-512 hashing. |
| [`doca-sta`](skills/libs/doca-sta/SKILL.md) | DOCA STA | DOCA Storage-Target-Acceleration library — NVMe-oF transport-acceleration substrate that sits under SPDK / kernel-nvme; the per-IO transport-layer offload, not the NVMe protocol stack itself. |
| [`doca-telemetry`](skills/libs/doca-telemetry/SKILL.md) | DOCA Telemetry | Per-domain DOCA hardware-counter / diagnostic *readers* (PCC / PCI / PHY / DPA / DIAG / ADP-RETX). For *publishing* application metrics, see `doca-telemetry-exporter` instead. Distinct from the deployed DTS service (non-goal #7 routing). |
| [`doca-telemetry-exporter`](skills/libs/doca-telemetry-exporter/SKILL.md) | DOCA Telemetry Exporter | Application-side publish library — schema + source + type lifecycle plus labeled-metrics (`metrics_*`) and OTLP-logs (`otlp_logs_*`) surfaces; publishes into the DOCA Telemetry Service over local IPC. |
| [`doca-urom`](skills/libs/doca-urom/SKILL.md) | DOCA UROM | Unified Communication Remote Memory Operations — offload control of long-lived RDMA flows. |
| [`doca-verbs`](skills/libs/doca-verbs/SKILL.md) | DOCA Verbs | Low-level verbs surface for libraries / wrappers that want direct QP / CQ / WR control under DOCA's safety model. |

### DOCA Services (6 skills)

| Skill | DOCA service | What it does |
|---|---|---|
| [`doca-argus`](skills/services/doca-argus/SKILL.md) | DOCA Argus | Cybersecurity-monitoring service on BlueField — process / network / file telemetry stream. |
| [`doca-dms`](skills/services/doca-dms/SKILL.md) | DOCA Management Service | gRPC-based device management (gNMI for config, gNOI for system ops, YANG-modeled paths, `dmsd` + `dmspe` two-process daemon, four auth modes). Beta as of DOCA 3.3. |
| [`doca-firefly`](skills/services/doca-firefly/SKILL.md) | DOCA Firefly | PTP synchronization service — sub-microsecond clock sync on BlueField. |
| [`doca-flow-inspector`](skills/services/doca-flow-inspector/SKILL.md) | DOCA Flow Inspector | Mirrored-flow inspection service — taps a copy of programmed Flow traffic and emits a stream for off-host analysis (containerized, kubelet-standalone). |
| [`doca-os-inspector`](skills/services/doca-os-inspector/SKILL.md) | DOCA OS Inspector | DPU-side out-of-band introspection of the **HOST** OS via DOCA App Shield (read-only via PCIe DMA). Pairs with `doca-apsh` (library) and `doca-apsh-config` (profile generation). |
| [`doca-urom-svc`](skills/services/doca-urom-svc/SKILL.md) | DOCA UROM Service | The deployed service half of UROM — manages offloaded RDMA flow state. |

### DOCA Tools (17 skills)

| Skill | DOCA tool | What it does |
|---|---|---|
| [`doca-apsh-config`](skills/tools/doca-apsh-config/SKILL.md) | `doca_apsh_config` | Configures App Shield (target-host symbol / kallsyms / process-map fixtures). |
| [`doca-bench`](skills/tools/doca-bench/SKILL.md) | `doca_bench` | Standardized benchmark harness for DOCA libraries (Flow, DMA, etc.). |
| [`doca-bench-extension`](skills/tools/doca-bench-extension/SKILL.md) | `doca_bench_extension` | Plugin surface for adding new bench scenarios. |
| [`doca-caps`](skills/tools/doca-caps/SKILL.md) | `doca_caps` | Read-only `/opt/mellanox/doca/tools/doca_caps` — devices, representors, per-library per-device capabilities, logger names. The canonical first-step state snapshot. |
| [`doca-comm-channel-admin`](skills/tools/doca-comm-channel-admin/SKILL.md) | `doca_comm_channel_admin` | Admin / diagnostics for the comm-channel transport under Comch. |
| [`doca-dpa-hl-tracer`](skills/tools/doca-dpa-hl-tracer/SKILL.md) | `doca_dpa_hl_tracer` | DPA high-level tracer — visibility into DPA execution. |
| [`doca-flow-dpa-perf`](skills/tools/doca-flow-dpa-perf/SKILL.md) | `doca_flow_dpa_perf` | Performance harness for Flow's DPA path. |
| [`doca-flow-grpc-server`](skills/tools/doca-flow-grpc-server/SKILL.md) | `doca_flow_grpc` | Remote programmable steering — pushes Flow pipes / entries via gRPC. |
| [`doca-flow-perf`](skills/tools/doca-flow-perf/SKILL.md) | `doca_flow_perf` | Throughput / steering-rate benchmark for Flow. |
| [`doca-flow-tune`](skills/tools/doca-flow-tune/SKILL.md) | `doca_flow_tune` | Unified visibility / analysis / recommendation tool for a live `doca-flow` pipeline — five subcommands (MONITOR / ANALYZE / VISUALIZE / DUMP / WEB). The binary is a CLIENT to the server-side library linked into the running doca-flow application. |
| [`doca-gpunetio-ib-write-bw`](skills/tools/doca-gpunetio-ib-write-bw/SKILL.md) | `doca_gpunetio_ib_write_bw` | Bandwidth micro-benchmark for GPUNetIO IB-write. |
| [`doca-gpunetio-ib-write-lat`](skills/tools/doca-gpunetio-ib-write-lat/SKILL.md) | `doca_gpunetio_ib_write_lat` | Latency micro-benchmark for GPUNetIO IB-write. |
| [`doca-pcc-counters`](skills/tools/doca-pcc-counters/SKILL.md) | `pcc_counters.sh` | Bash script that arms (`set`) and reads (`query`) the device's firmware/HW PCC diagnostic counters via mst + the mlx5 debugfs `diag_cnt` interface. |
| [`doca-sha-offload-engine`](skills/tools/doca-sha-offload-engine/SKILL.md) | `doca_sha_offload_engine` | OpenSSL ENGINE that routes SHA digests through the DOCA SHA hardware path. |
| [`doca-socket-relay`](skills/tools/doca-socket-relay/SKILL.md) | `doca_socket_relay` | Bridges a host AF_UNIX socket into a BlueField service over Comch. |
| [`doca-spcx-cc`](skills/tools/doca-spcx-cc/SKILL.md) | `doca_spcx_cc` | Programmable Congestion-Control extension (next-gen) reference sample. Pairs with `doca-pcc` and `doca-pcc-ztr-rttcc-algo`. Live-fabric safety implications — heavy use of `doca-hardware-safety`. |
| [`doca-telemetry-utils`](skills/tools/doca-telemetry-utils/SKILL.md) | `doca_telemetry_utils` | Operator-side support CLI for a DOCA Telemetry exporter pipeline — translates name ↔ Data ID, enumerates the diagnostic-counter schema, probes per-device counter support before an exporter config commits to it. |

---

## Standards & Compatibility

### AgentSkills.io open-standard compliance

Every `SKILL.md` in this bundle conforms to the [AgentSkills.io](https://agentskills.io/specification) open standard for agent skills. Any AgentSkills.io-aware client — Anthropic Claude Code, Cursor, OpenAI Codex CLI, Gemini CLI, GitHub Copilot, custom in-house LLMs — can discover, route to, and load these skills without any DOCA-specific glue:

- Each skill ships YAML frontmatter with the spec-mandated fields: `name` (matches the directory name), `description` (imperative *"Use this skill when..."* phrasing per [optimizing-descriptions](https://agentskills.io/skill-creation/optimizing-descriptions), ≤ 1024 chars), `metadata` (for our `kind` routing contract: `library` / `service` / `tool` / `cross-cutting`), and `compatibility` (environment requirements: DOCA install path, Linux distro, BlueField / ConnectX gens).
- Every release runs the official reference validator ([`skills-ref validate`](https://github.com/agentskills/agentskills/tree/main/skills-ref)) against all 60 skills as an internal CI gate before tagging. A green validator is a merge precondition.
- The directory layout (`skills/<name>/SKILL.md` + `CAPABILITIES.md` + `TASKS.md`) is exactly the AgentSkills.io recommended progressive-disclosure shape: agents read the frontmatter first to decide whether to load, then drill into the body and companions only when activated.

Re-validate locally:

```bash
git clone https://github.com/agentskills/agentskills.git /tmp/agentskills
cd /tmp/agentskills/skills-ref && uv sync
.venv/bin/skills-ref validate /path/to/doca-skills/skills/libs/doca-flow
```

### Ground rules every agent follows

Full list in [`AGENTS.md`](AGENTS.md). The non-negotiables:

- **Public sources only** (skill body content) — every skill's `SKILL.md` / `CAPABILITIES.md` / `TASKS.md` body, every prompt, and every URL the agent **cites to the user as a fact about DOCA** must resolve from the public internet; internal NVIDIA hostnames (`gerrit-master`, `nvbugs`, `gitlab-master`, internal wikis) are banned from skill body content and fail an automated gate. This rule governs *what the agent quotes back* to a user; the public install path (which is `git clone https://github.com/NVIDIA-DOCA/doca-skills.git` over the public internet) does not touch skill body content.
- **Prefer the local install at `/opt/mellanox/doca`** over the web — for symbol resolution, sample paths, and bin locations on a real DOCA host.
- **Never invent symbols, URLs, paths, or package names** — every claim must be traceable to either the installed tree, an authoritative `docs.nvidia.com/doca/sdk/` URL, or a sample under `samples/` / `applications/`.
- **Always check the installed DOCA version before quoting API names** — load `doca-version` first.
- **Hardware-safety overlay is mandatory** for any change that touches live BlueField / NIC state (`mlxconfig`, firmware burn, BFB reflash, SFC mode flip): operator window + OOB console + rollback plan.
- **Out-of-scope products route with substance** — 27 externally-productized NVIDIA networking products (BlueField BSP, DPF, Network Operator, MLNX_OFED, UFM, Cumulus, MFT, Rivermax SDK, BlueField BMC, DTS-deployed, HBN, SNAP, BlueMan, Virtio-net, DPL Service, OVS-DOCA, DPACC, DPA Tools, DPU CLI, Ngauge, doca-hugepages, DPE, NIC Config Operator, NetQ, NVOS, Spectrum-X stack, GPU Operator) have routing-table rows with authoritative URL + symptom-matching gotcha class + Developer Forum entry. Agents must produce the 3-part response (recognize + name boundary + route with substance) for these — bare-URL refusals fail the bundle's own contract.

---

## Repository Structure

```
doca-skills/
├── README.md                                 # This file
├── AGENTS.md                                 # Ground rules every AI agent follows
├── SKILLS.md                                 # Index of installed skills + "when to load" triggers
├── CLAUDE.md                                 # One-line stub redirecting Claude Code to AGENTS.md
├── install.sh                                # One-line install: --agent <cursor|claude-code|codex|gemini-cli|kiro-cli|custom>
└── skills/
    ├── doca-setup/                           # Cross-cutting: install / env / build / no-install-yet
    │   ├── SKILL.md                          # Frontmatter + body (AgentSkills.io)
    │   ├── CAPABILITIES.md                   # What this skill can / cannot do
    │   └── TASKS.md                          # Worked tasks the agent can drive
    ├── doca-version/                         # Cross-cutting: four-source version audit
    ├── doca-programming-guide/               # Cross-cutting: build patterns, lifecycle, errors
    ├── doca-debug/                           # Cross-cutting: 7-layer debug ladder
    ├── doca-hardware-safety/                 # Cross-cutting: operator discipline for live HW
    ├── doca-bare-metal-deployment/           # Cross-cutting: launch directly on hardware
    ├── doca-container-deployment/            # Cross-cutting: kubelet-standalone on BF
    ├── doca-public-knowledge-map/            # Cross-cutting: routing index + non-goal #7 table
    ├── doca-structured-tools-contract/       # Cross-cutting: tool-call contract for dispatchers
    ├── libs/                                 # 28 library skills
    │   ├── doca-flow/
    │   ├── doca-rdma/
    │   ├── doca-eth/
    │   └── …
    ├── services/                             # 6 service skills
    │   ├── doca-argus/
    │   ├── doca-dms/
    │   └── …
    └── tools/                                # 17 tool skills
        ├── doca-caps/
        ├── doca-bench/
        └── …
```

---

## DOCA: what's covered, what's not

**Who this bundle is for:** *external developers building applications that **consume** DOCA libraries* — i.e., users who want to call DOCA Flow, DOCA RDMA, DOCA Comch, etc. from their own networking application to offload work onto an NVIDIA BlueField DPU or ConnectX NIC. The bundle scopes itself to NVIDIA's public DOCA documentation surfaces; questions about NVIDIA-internal infrastructure or DOCA contributor workflows are out of scope and enforced by the ground rules in [`AGENTS.md`](AGENTS.md).

**Language scope:** The skills are language-agnostic about the consumer application. DOCA itself ships as C libraries with a stable C ABI and `pkg-config` modules; the application source code NVIDIA ships in `samples/` and `applications/` is C/C++. So:

- **C / C++ consumers** are the canonical case. The "first app" workflow is *modify a shipped C sample on your DOCA-installed Linux host*; the build manifest is meson + `pkg-config doca-<library>`.
- **Other-language consumers** (Rust, Go, Python, …) consume DOCA via FFI / language-specific bindings against the same `*.so` libraries the C samples link against. The skills route you to the public C API surface (which is what your bindings will call) and keep the install / runtime / safety guidance language-agnostic. Your build system (cargo, go build, setup.py, …) is your concern; DOCA appears to it as a system C library.

**What is in scope:** The strict-1:1 set with the `doca/{libs,services,tools}/` monorepo at DOCA 3.3 — 28 libraries + 6 services + 17 tools.

**What is intentionally out of scope (non-goal #7):** 27 externally-productized NVIDIA networking products that NVIDIA ships *outside* the DOCA monorepo — BlueField BSP / `bfb-install` / RShim, DOCA Platform Framework (DPF), NVIDIA Network Operator, MLNX_OFED-as-separate-install, NVIDIA UFM, NVIDIA Cumulus Linux, NVIDIA Firmware Tools (MFT), NVIDIA Rivermax SDK (the license layer), BlueField BMC, DOCA Telemetry Service (as-deployed), DOCA HBN, DOCA BlueMan, DOCA SNAP Services, DOCA Virtio-net Service, DOCA DPL Service (Pipeline Language), OVS-DOCA (ASAP² Open vSwitch offload), DOCA DPACC Compiler, DPA Tools, DOCA DPU CLI, DOCA Ngauge, `doca-hugepages` helper, DOCA Privileged Executor (DPE), NIC Configuration Operator, NVIDIA NetQ, NVIDIA NVOS, NVIDIA Spectrum-X Validated Solution Stack, NVIDIA GPU Operator. Each has a per-product row in [`doca-public-knowledge-map`](skills/doca-public-knowledge-map/SKILL.md) with authoritative docs URL + common-gotcha class + Developer Forum entry. The bundle's contract requires agents to give the **three-part response** (recognize + name boundary + route with substance) for these — not a bare-URL handoff.

---

## DOCA install reference (for humans reading this README directly)

For the *human* "how do I install DOCA, build a sample, run a sample" walk-through, the canonical source is the NVIDIA public documentation set, not this README. The skills in this bundle are designed so an AI agent answering an external user can route them directly to those pages instead of paraphrasing:

- [NVIDIA DOCA Developer Guide](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Developer+Guide)
- [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Installation+Guide+for+Linux) — install with the `doca-all` profile (superset of `doca-ofed` + `doca-networking`).
- [NVIDIA BlueField DPU OS / Platform Software docs](https://docs.nvidia.com/networking/display/BlueFieldDPUOSLatest) — RShim, host↔DPU connectivity, and install troubleshooting (the standalone *DOCA Troubleshooting Guide* was folded into the BlueField Platform Software documentation set).
- [Meson build configuration guide](https://mesonbuild.com/) — the build system every shipped sample uses.

If you have a DOCA install and want to build a sample by hand: follow the Installation Guide above with the `doca-all` profile, then `meson /tmp/build && ninja -C /tmp/build` from `applications/`. The generated binaries land under `/tmp/build/<application_name>/doca_<application_name>`.

If you want an AI agent to drive a richer "first app" walk-through end-to-end against either a real DOCA install or the public NGC container, install this bundle and ask your agent to walk you through it — the bundle handles the staged roadmap via [`doca-setup`](skills/doca-setup/SKILL.md) → [`doca-programming-guide ## modify`](skills/doca-programming-guide/TASKS.md#modify) → the matching library skill.

---

## Quality assurance behind each release

External consumers of this bundle do not need to run any CI gates themselves. Skill changes are vetted by an internal CI pipeline before each release — that pipeline verifies:

1. **Structural conformance** of every `SKILL.md` / `CAPABILITIES.md` / `TASKS.md` (gate-2).
2. **AgentSkills.io spec compliance** via the official `skills-ref` validator on every skill (gate-13).
3. **Public-sources-only references** — no internal NVIDIA hostnames or paths leak through (gate-4 reference-hygiene).
4. **Cross-link integrity** — every inter-skill anchor reference resolves (gate-3 check-crosslinks).
5. **Anchor density** — every skill exposes the H2 anchors the bundle's contract relies on (gate-3 check-anchor-density).
6. **Coverage** — every shipping `doca/{libs,services,tools}/` artifact has a corresponding skill (gate-3 check-coverage); strict 1:1 with the monorepo (gate-3 check-doca-inventory).
7. **JTBD coverage** — every "job to be done" has a matching skill / anchor (gate-3 check-jtbd-coverage).
8. **Public-surface invariants** — the public bundle never leaks internal-only files (gate-3 check-public-surface-invariants).
9. **Live-hardware harness** — the bundle is exercisable against a real BlueField (gate-3 check-live-hardware-harness).
10. **Non-goal routing contract** — the 27-product routing table is in sync with `AGENTS.md ## Non-goals #7`, and the prose product counts in README/BENCHMARK match the live row count (gate-14 check-non-goal-routing).
11. **Deep-E2E prompt + grader generation** for every shipping skill (gate-4d).
12. **No-regression vs the baseline** (gate-5) — every previously-PASS cell on the 3-variant constant-grader scoreboard still PASSes.
13. **Jenkinsfile syntax** (gate-4c) and **`metadata.kind` frontmatter** invariants (gate-4b).

Every release of this bundle has already passed those 14 gates. You don't need any of the CI tooling to load and use the skills — just clone the repo, run `./install.sh --agent <your-agent>`, and ask your agent a DOCA question.

---

## Getting Help & Contributing

For **DOCA product questions** — building applications, runtime errors, performance issues, hardware compatibility — use the [NVIDIA DOCA Developer Forum](https://forums.developer.nvidia.com/c/infrastructure/doca/370). The bundle's skills route you there as the escalation channel for everything that's not solvable from the docs.

For **bundle-level issues** — a skill gave a wrong answer, a skill is missing a topic, a `SKILL.md` doesn't match a recent DOCA release — open an issue on the repo where you got this bundle.

For **DOCA contributions** — patches to the libraries / services / tools themselves — go through the upstream DOCA team; this bundle's content is mirrored from the public monorepo and does not author DOCA itself.

---

## License

Dual-licensed — same scheme as the upstream [`NVIDIA/skills`](https://github.com/NVIDIA/skills) catalog:

- **Apache License 2.0** for code and configuration (the `install.sh` installer, the YAML metadata files, and any future scripted assets).
- **Creative Commons Attribution 4.0 International (CC BY 4.0)** for documentation (every `*.md` under `skills/`, plus `AGENTS.md`, `BENCHMARK.md`, `CODE_OF_CONDUCT.md`, `README.md`, `SKILLS.md`).

The full license text lives in [`LICENSE`](LICENSE) at repo root. SPDX header: `Apache-2.0 AND CC-BY-4.0`. The DOCA samples and applications referenced from the public [`NVIDIA-DOCA/doca-samples`](https://github.com/NVIDIA-DOCA/doca-samples) repository retain their upstream licenses as shipped with the NVIDIA DOCA SDK.
