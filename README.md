# NVIDIA DOCA Samples
![DOCA software Stack](doca-software.jpg "DOCA Software Stack")

## AI agent skills (this branch)

This branch (`ai-mvp-with-files`) ships **Anthropic-style Skills** for AI coding agents on top of the public DOCA samples. Any agent that opens this repository — Cursor, Claude Code, Codex, Gemini, custom in-house LLMs — will discover the skills via the standard cross-tool entry points.

**Where the agent guidance lives:**

- [AGENTS.md](AGENTS.md) — canonical entry point for every AI coding agent. Read this first.
- [SKILLS.md](SKILLS.md) — index of installed skills with one-line "when to load" triggers.
- [.claude/skills/](.claude/skills/) — the skill source files. The `.claude/` path is Claude Code's auto-discovery location, but the files themselves are vendor-neutral Markdown that any agent can read directly.
- [CLAUDE.md](CLAUDE.md) — one-line stub routing Claude Code back to `AGENTS.md`.

**What the skills give you:**

| Skill | What it covers |
| --- | --- |
| `doca-public-knowledge-map` | Where to find authoritative DOCA information without the source repo: every public docs page, the on-disk layout of an installed `/opt/mellanox/doca`, public GitHub repos, NGC catalog, the developer forum, and how to check the installed DOCA version. |
| `doca-flow` | DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counters and traces, version compatibility, and debugging `DOCA_ERROR_*` failures. Loads `CAPABILITIES.md` for the technical surface and `TASKS.md` for step-by-step workflows on demand. |

**Quick start:**

1. Open this repo (on the `ai-mvp-with-files` branch) in your AI coding tool of choice.
2. Ask any DOCA question. The agent should read `AGENTS.md` automatically and pull the matching skill in.
3. The `master` branch contains the same DOCA samples without any of the agent-skills layer, so you can compare both side by side and see what the skills add.

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
