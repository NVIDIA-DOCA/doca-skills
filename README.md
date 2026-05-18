# NVIDIA DOCA Skills

![DOCA software Stack](doca-software.jpg "DOCA Software Stack")

**Where to start (humans):** Read this README for context, then if
you are an AI agent (or running one), open [AGENTS.md](AGENTS.md) for
the ground rules and [SKILLS.md](SKILLS.md) for the skill index. Each
skill under [skills/](skills/) opens with its own *Where to start*
header pointing at the right next file inside it.

A **public, drop-in DOCA skills bundle for AI coding agents**, on top of the same NVIDIA DOCA samples and reference applications shipped here. Any developer who clones this repo can open it in their AI coding tool of choice — Cursor, Claude Code, Codex, Gemini, custom in-house LLMs — and the agent will know how to help with DOCA without any extra setup, without the developer needing to clone or download anything else.

## AI agent skills — what makes this repo agent-ready out of the box

**Who this is for:** *external developers building applications that **consume** DOCA libraries* — i.e., users who want to call DOCA Flow, DOCA RDMA, DOCA Comch, etc. from their own networking application to offload work onto a NVIDIA BlueField DPU or ConnectX NIC. The bundle scopes itself to NVIDIA's public DOCA documentation surfaces; questions about NVIDIA-internal infrastructure or DOCA contributor workflows are out of scope and enforced by the ground rules in [`AGENTS.md`](AGENTS.md).

**Language scope:** the skills are language-agnostic about the *consumer* application. DOCA itself is shipped as C libraries with a stable C ABI and `pkg-config` modules, and the only application source code NVIDIA ships in this repository's `samples/` and `applications/` trees is C/C++. So:

- **C / C++ consumers** are the canonical case. The "first app" workflow is *modify a shipped C sample on your DOCA-installed Linux host*; the build manifest is meson + `pkg-config doca-<library>`. Most of the prescriptive examples in the skills assume this path.
- **Other-language consumers** (Rust, Go, Python, etc.) consume DOCA via FFI / language-specific bindings against the same `*.so` libraries the C samples link against. The skills do not author your wrapper for you and do not claim NVIDIA ships official non-C bindings unless that has been verified at the time the consumer reads this; the skills' contribution in that case is to route you to the public C API surface (which is what your bindings will call) and to keep the install/runtime/safety guidance language-agnostic. Your build system (cargo, go build, setup.py, …) is your concern; DOCA appears to it as a system C library.

The skills layer is currently shipped on the `ai-mvp-with-files` branch; `master` carries the public DOCA samples *without* the skills layer so the two are easy to compare side-by-side.

**Where the agent guidance lives:**

- [AGENTS.md](AGENTS.md) — canonical entry point for every AI coding agent. Read this first.
- [SKILLS.md](SKILLS.md) — index of installed skills with one-line "when to load" triggers, plus the layout convention.
- [skills/](skills/) — the skill source files, layered: top-level cross-cutting skills, `libs/<library>/`, `services/<service>/`, `tools/<tool>/`. The path is intentionally vendor-neutral (`skills/`, not `.claude/skills/` or any other runtime-specific directory) so the bundle reads naturally to any agent — Cursor, Codex, Gemini, Claude Code, or in-house LLMs. Discovery is driven by [`AGENTS.md`](AGENTS.md) (industry convention); a stub `CLAUDE.md` at repo root exists only to redirect Claude Code's auto-discovery back to `AGENTS.md`.
- [CLAUDE.md](CLAUDE.md) — one-line stub routing Claude Code back to `AGENTS.md`.

**What the skills give you (three cross-cutting + per-artifact layers):**

| Skill | Slot | What it covers | When the agent loads it |
| --- | --- | --- | --- |
| `doca-public-knowledge-map` | top-level | The routing table for every authoritative DOCA information source: public docs URLs, the on-disk layout of an installed `/opt/mellanox/doca`, public GitHub repos, NGC catalog, the developer forum, the DOCA services index, the DOCA tools index, and how to check the installed DOCA version. | Any "what / where / which doc" DOCA question. |
| `doca-setup` | top-level | **Env-class only.** Install verification, build environment (`pkg-config`, headers, hugepages, devlink), env-class debugging, and the *I have no install yet* path with the public NGC DOCA container (`nvcr.io/nvidia/doca/doca`) as the universal Stage-1 fallback for any user on macOS, Windows, or Linux without DOCA — alongside lab-host, cloud-Linux, and hardware paths. Stops at *"the install is healthy and the env is ready"*. | The user is installing or troubleshooting DOCA, or has no install at all and needs to reach one. |
| `doca-programming-guide` | top-level | **General DOCA programming patterns shared across every library.** The canonical `pkg-config doca-<library>` + meson build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library skill extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. | The user has a healthy DOCA env and is asking a programming-class question — *how do I structure a build, derive a first app, debug a `DOCA_ERROR_*`* — independent of which library they're using. |
| `doca-flow` | `libs/` | DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counters and traces, version compatibility, and debugging `DOCA_ERROR_*` failures. Builds on `doca-setup` (env) and `doca-programming-guide` (cross-library patterns) and layers Flow specifics on top. | The user is writing or debugging DOCA Flow code. |
| `doca-dms` | `services/` | DOCA Management Service — gRPC-based device management for BlueField / ConnectX. Two-process daemon (`dmsd` frontend + `dmspe` privileged backend), gNMI for config, gNOI for system ops, YANG-modeled paths, four documented auth modes, three deployment shapes, `dmsgroup` authorization, and a layered debug taxonomy from gRPC transport down to underlying-tool failures. Currently beta per the public guide. | The user is deploying or operating DMS. |
| `doca-caps` | `tools/` | DOCA Capabilities Print Tool (`/opt/mellanox/doca/tools/doca_caps`) — read-only CLI that prints DOCA devices, representors, supported libraries, per-device per-library capabilities, and DOCA logger names. Available since DOCA 2.6.0. The canonical first-step capability snapshot called out from `doca-setup ## test` and `doca-programming-guide ## debug`. | The user — or the agent itself — needs a side-effect-free, documented snapshot of *what DOCA sees on this host* before doing anything that changes state. |

When other DOCA libraries / services / tools ship their own skills (`doca-rdma`, `doca-comch`, `doca-dts`, `doca-bench`, …), each plugs into the same three cross-cutting foundations — `doca-public-knowledge-map` for routing, `doca-setup` for env, `doca-programming-guide` for cross-library programming patterns — and contributes only the *artifact-specific* overrides on top, in its own `libs/` / `services/` / `tools/` slot.

**Quick start:**

1. Clone this repo (`git clone https://github.com/NVIDIA-DOCA/doca-skills.git`) on the `ai-mvp-with-files` branch and open it in your AI coding tool.
2. Ask any DOCA question. The agent reads `AGENTS.md` automatically and pulls the matching skill in.
3. To see the difference the skills layer makes, open the same repo on the `master` branch in a second window and ask the same question.

## Install — three deployment shapes

The bundle is **markdown-only**: there is no `pip install`, no `npm
install`, no daemon, no MCP server to launch. You make the skills
available to an AI agent in whichever way that agent discovers
contributor docs. Three shapes are documented and CI-verified:

### Shape 1 — clone alongside your DOCA work (the canonical case)

```bash
# Clone next to wherever you keep your DOCA work.
git clone https://github.com/NVIDIA-DOCA/doca-skills.git
cd doca-skills
git checkout ai-mvp-with-files
```

Open the cloned folder in your AI coding tool. The tool's agent
discovers `AGENTS.md`, walks to `SKILLS.md`, and loads the matching
per-skill `SKILL.md` (plus `CAPABILITIES.md` / `TASKS.md`) when your
question matches a *When to load* trigger. No further wiring is
required.

### Shape 2 — bring the skills into an existing workspace

If you already work in another repo and want the DOCA skills loaded
alongside it, add this repo as a git submodule (or a sibling clone)
and either symlink `doca-skills/AGENTS.md` into your workspace root,
or copy its contents into your existing `AGENTS.md`. Agents resolve
`AGENTS.md` at workspace root by convention.

### Shape 3 — vet the bundle in CI before merging a skill change

The CI gates live in `devops/ci/` (sibling repo). To validate a skill
change locally before opening a PR, run:

```bash
# Structural lint + non-public-info check + symlink ban.
bash devops/ci/check-skill.sh --all

# Live URL HEAD check (network required; takes ~30s).
bash devops/ci/check-skill.sh --all --check-urls

# Anchor density floor.
bash devops/ci/check-anchor-density.sh --all

# Per-artifact SKILL + PROMPT + KMAP coverage + routing discoverability
# (all HARD-FAIL).
bash devops/ci/check-coverage.sh \
  --routing-discoverability-hard-fail \
  --prompt-coverage-hard-fail \
  --skill-coverage-hard-fail-below=100 \
  --hard-fail-below=100

# Anthropic SKILL.md frontmatter validator (one-time setup; see
# devops/AUTHORING.md § 11).
claude-skill-check skills/<slot>/<your-skill>/SKILL.md
```

A passing local run mirrors what Jenkins will gate on the PR.

For deeper contributor rules and the security-reporting path, read
`devops/CONTRIBUTING.md`, `devops/SECURITY.md`, and
`devops/AUTHORING.md` in the sibling `devops/` working tree before
opening a PR. (Those three files are staged in `devops/` today and
will land at `doca-skills/` bundle root when the working tree merges
into the public repo — see `devops/round2-backlog.md` for migration
status.)

**Conformance:** [`ci/check-skill.sh`](ci/check-skill.sh) enforces the rules every skill in `skills/` must satisfy. Run it locally before opening a PR that touches any skill file.

| Check | Default | Network required |
| --- | --- | --- |
| Frontmatter validity, required H2 anchors, cross-anchor resolution, no symlinks. | always on | no |
| Non-public references: any `*.nvidia.com` URL whose host isn't on the public allowlist (`docs.nvidia.com`, `developer.nvidia.com`, `catalog.ngc.nvidia.com`, `ngc.nvidia.com`, `forums.developer.nvidia.com`, `nvcr.io`, …) fails. Internal-tooling vocabulary in URL or path context (`gerrit`, `nvbugs`, `*.internal.*`, `gitlab-master`, `labhome`, …) fails. | always on | no |
| URL HEAD validity: every `https?://` URL in any skill file must respond `2xx`/`3xx` (with a small GET fallback for hosts that 405 HEAD). Catches the *page renamed / page deleted* failure mode the earlier Samples Overview URL hit. | opt-in via `--check-urls` | yes |

Examples:

```bash
ci/check-skill.sh --all                # structural + non-public, no network
ci/check-skill.sh --all --check-urls   # also HEAD every skill URL
ci/check-skill.sh --self-test          # confirm every gating check still trips
```

**Ground rules every agent follows** (full list in `AGENTS.md`): public sources only — never reference internal NVIDIA hostnames; prefer the local install at `/opt/mellanox/doca` over the web; never invent symbols, URLs, paths, or package names; always check the installed DOCA version before quoting API names.

---

##  Purpose

The DOCA samples repository is an educational resource provided as a guide on how to program on the NVIDIA BlueField networking platform using DOCA API.

The repository consist of 2 parts:
* [Samples](https://github.com/NVIDIA-DOCA/doca-samples-demo/tree/main/samples):  simplistic code snippets that demonstrate the API usage 
* [Applications](https://github.com/NVIDIA-DOCA/doca-samples-demo/tree/main/applications): Advanced samples that implements a logic that might cross different SDK libs.


For instructions regarding the development environment and installation, refer to the [NVIDIA DOCA Developer Guide](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Developer+Guide) and the [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Installation+Guide+for+Linux) respectively.

##  Prerequisites

Install DOCA Software Package:

A detailed step-by-step process for downloading and installing the required development software on both the host and BlueField can be found in the [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Installation+Guide+for+Linux).

note: Use doca-all profile, This profile is the super-set of components, which also includes the content of doca-ofed and doca-networking.


##  Installation

clone the sample repository

    git clone https://github.com/NVIDIA-DOCA/doca-samples.git

## Compilation

To compile all the reference applications:

Move to the applications directory:

    cd doca-samples/applications
    meson /tmp/build
    ninja -C /tmp/build

Info
    The generated applications are located under the /tmp/build/ directory, using the following path /tmp/build/<application_name>/doca_<application_name>.

Note
    Compilation against DOCA's SDK relies on environment variables which are automatically defined per user session upon login. For more information, please refer to section "Meson Complains About Missing Dependencies" in the [NVIDIA DOCA Troubleshooting Guide](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Troubleshooting+Guide#src-2957507292_id-.NVIDIADOCATroubleshootingGuidev2.8.0-FailuretoSetHugePages).


## Developer Configurations
When recompiling the reference applications, meson compiles them by default in "debug" mode. Therefore, the binaries would not be optimized for performance as they would include the debug symbol. For comparison, the programs binaries shipped as part of DOCA's installation are compiled in "release" mode. To compile the applications in something other than debug, please consult Meson's configuration guide.

The reference applications also offer developers the ability to use the DOCA log's TRACE level (DOCA_LOG_TRC) on top of the existing DOCA log levels. Enabling the TRACE log level during compilation activates various developer log messages left out of the release compilation. Activating the TRACE log level may be done through enable_trace_log in the meson_options.txt file, or directly from the command line:

[Meson configuration guide](https://mesonbuild.com/)

Prepare the compilation definitions to use the trace log level:

    meson /tmp/build -Denable_trace_log=true
