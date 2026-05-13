# NVIDIA DOCA Samples
![DOCA software Stack](doca-software.jpg "DOCA Software Stack")

## AI agent skills — make this repo agent-ready out of the box

This repository is intended as a **public, drop-in DOCA skills bundle** for AI coding agents. Any developer who clones it can open it in their AI coding tool of choice — Cursor, Claude Code, Codex, Gemini, custom in-house LLMs — and the agent will know how to help with DOCA without any extra setup, without the developer needing to clone or download anything else.

The skills layer is currently shipped on the `ai-mvp-with-files` branch; `master` carries the public DOCA samples *without* the skills layer so the two are easy to compare side-by-side.

**Where the agent guidance lives:**

- [AGENTS.md](AGENTS.md) — canonical entry point for every AI coding agent. Read this first.
- [SKILLS.md](SKILLS.md) — index of installed skills with one-line "when to load" triggers.
- [.claude/skills/](.claude/skills/) — the skill source files. The `.claude/` path is Claude Code's auto-discovery location, but the files themselves are vendor-neutral Markdown that any agent can read directly.
- [CLAUDE.md](CLAUDE.md) — one-line stub routing Claude Code back to `AGENTS.md`.

**What the skills give you (three complementary layers):**

| Skill | What it covers | When the agent loads it |
| --- | --- | --- |
| `doca-public-knowledge-map` | The routing table for every authoritative DOCA information source: public docs URLs, the on-disk layout of an installed `/opt/mellanox/doca`, public GitHub repos, NGC catalog, the developer forum, and how to check the installed DOCA version. | Any "what / where / which doc" DOCA question. |
| `doca-setup` | The bridge between *"DOCA is installed"* and *"I have a running first program"*: install verification, build environment (`pkg-config`, headers, meson, hugepages), building and running shipped samples, and deriving a custom first application from a sample. Library-agnostic. | The user has DOCA installed and wants to actually run something — sanity checks, build a sample, modify it into a first app. |
| `doca-flow` | DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counters and traces, version compatibility, and debugging `DOCA_ERROR_*` failures. Builds on `doca-setup` for environment preparation. | The user is writing or debugging DOCA Flow code. |

When other DOCA libraries (`doca-rdma`, `doca-comch`, …) ship their own skills, each will plug into the same `doca-setup` bridge — extending it with a library-specific *"first app"* template — without duplicating the install/build/runtime layer.

**Quick start:**

1. Clone this repo (`git clone https://github.com/NVIDIA-DOCA/doca-skills.git`) on the `ai-mvp-with-files` branch and open it in your AI coding tool.
2. Ask any DOCA question. The agent reads `AGENTS.md` automatically and pulls the matching skill in.
3. To see the difference the skills layer makes, open the same repo on the `master` branch in a second window and ask the same question.

**Conformance:** [`ci/check-skill.sh`](ci/check-skill.sh) enforces the structural rules every skill in `.claude/skills/` must satisfy (frontmatter validity, required H2 anchors, cross-anchor resolution, no symlinks). Run it locally before opening a PR that touches any skill file.

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
