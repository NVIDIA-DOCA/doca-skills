# NVIDIA DOCA Skills

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

Contributing to the skills layer is governed by an internal author / contributor / security policy; external consumers do not need it to use the bundle.

**What the skills give you (three cross-cutting + per-artifact layers):**

| Skill | Slot | What it covers | When the agent loads it |
| --- | --- | --- | --- |
| `doca-public-knowledge-map` | top-level | The routing table for every authoritative DOCA information source: public docs URLs, the on-disk layout of an installed `/opt/mellanox/doca`, public GitHub repos, NGC catalog, the developer forum, the DOCA services index, the DOCA tools index, and how to check the installed DOCA version. | Any "what / where / which doc" DOCA question. |
| `doca-setup` | top-level | **Env-class only.** Install verification, build environment (`pkg-config`, headers, hugepages, devlink), env-class debugging, and the *I have no install yet* path with the public NGC DOCA container (`nvcr.io/nvidia/doca/doca`) as the universal Stage-1 fallback for any user on macOS, Windows, or Linux without DOCA — alongside lab-host, cloud-Linux, and hardware paths. Stops at *"the install is healthy and the env is ready"*. | The user is installing or troubleshooting DOCA, or has no install at all and needs to reach one. |
| `doca-programming-guide` | top-level | **General DOCA programming patterns shared across every library.** The canonical `pkg-config doca-<library>` + meson build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library skill extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. | The user has a healthy DOCA env and is asking a programming-class question — *how do I structure a build, derive a first app, debug a `DOCA_ERROR_*`* — independent of which library they're using. |
| `doca-flow` | `libs/` | DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, counters and traces, version compatibility, and debugging `DOCA_ERROR_*` failures. Builds on `doca-setup` (env) and `doca-programming-guide` (cross-library patterns) and layers Flow specifics on top. | The user is writing or debugging DOCA Flow code. |
| `doca-dms` | `services/` | DOCA Management Service — gRPC-based device management for BlueField / ConnectX. Two-process daemon (`dmsd` frontend + `dmspe` privileged backend), gNMI for config, gNOI for system ops, YANG-modeled paths, four documented auth modes, three deployment shapes, `dmsgroup` authorization, and a layered debug taxonomy from gRPC transport down to underlying-tool failures. Currently beta per the public guide. | The user is deploying or operating DMS. |
| `doca-caps` | `tools/` | DOCA Capabilities Print Tool (`/opt/mellanox/doca/tools/doca_caps`) — read-only CLI that prints DOCA devices, representors, supported libraries, per-device per-library capabilities, and DOCA logger names. Available since DOCA 2.6.0. The canonical first-step capability snapshot called out from `doca-setup ## test` and `doca-programming-guide ## debug`. | The user — or the agent itself — needs a side-effect-free, documented snapshot of *what DOCA sees on this host* before doing anything that changes state. |

When other DOCA libraries / services / tools ship their own skills (`doca-rdma`, `doca-comch`, `doca-dms`, `doca-bench`, …), each plugs into the same three cross-cutting foundations — `doca-public-knowledge-map` for routing, `doca-setup` for env, `doca-programming-guide` for cross-library programming patterns — and contributes only the *artifact-specific* overrides on top, in its own `libs/` / `services/` / `tools/` slot.

**Quick start:**

1. Clone this repo (`git clone https://github.com/NVIDIA-DOCA/doca-skills.git`) on the `ai-mvp-with-files` branch and open it in your AI coding tool.
2. Ask any DOCA question. The agent reads `AGENTS.md` automatically and pulls the matching skill in.
3. To see the difference the skills layer makes, open the same repo on the `master` branch in a second window and ask the same question.

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

## Install — three deployment shapes

The bundle is **markdown-only**: there is no `pip install`, no `npm
install`, no daemon, no MCP server to launch. You make the skills
available to an AI agent in whichever way that agent discovers
contributor docs. Three shapes are documented and CI-verified:

### Shape 1 — clone alongside your DOCA work (the canonical case)

```bash
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

### Shape 3 — how skill quality is maintained behind the scenes

External consumers of this bundle do not need to run any CI gates
themselves. Skill changes are vetted by an internal CI pipeline
before each release — that pipeline verifies structural conformance
of every `SKILL.md` / `CAPABILITIES.md` / `TASKS.md`, public-sources-
only references, cross-link integrity, anchor density, per-artifact
prompt coverage, strict 1:1 alignment with the public
`doca/{libs,services,tools}` tree at a named DOCA release, and a
3-way agent A/B/C measurement that compares the current bundle
against the previous release and against a no-skills baseline.

What this means for you as a consumer: every release of this bundle
has already passed those gates. You don't need any of the CI tooling
to load and use the skills — just clone the repo and point your
agent at it.

**Ground rules every agent follows** (full list in `AGENTS.md`): public sources only — never reference internal NVIDIA hostnames; prefer the local install at `/opt/mellanox/doca` over the web; never invent symbols, URLs, paths, or package names; always check the installed DOCA version before quoting API names.

---

## About the DOCA samples shipped here

The bundle ships on top of the public **DOCA samples repository**,
which is an educational resource provided as a guide on how to program
on the NVIDIA BlueField networking platform using the DOCA API. The
sample tree has two parts:

* [Samples](https://github.com/NVIDIA-DOCA/doca-samples-demo/tree/main/samples) — simplistic code snippets that demonstrate API usage.
* [Applications](https://github.com/NVIDIA-DOCA/doca-samples-demo/tree/main/applications) — advanced samples that implement logic spanning multiple SDK libraries.

For the *human* "how do I install DOCA, build a sample, run a sample"
walk-through, the canonical source is the NVIDIA public documentation
set, not this README. The skills in this bundle are designed so an AI
agent answering an *external* user can route them directly to those
pages instead of paraphrasing:

* [NVIDIA DOCA Developer Guide](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Developer+Guide)
* [NVIDIA DOCA Installation Guide for Linux](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Installation+Guide+for+Linux) — install with the `doca-all` profile (superset of `doca-ofed` + `doca-networking`).
* [NVIDIA DOCA Troubleshooting Guide](https://docs.nvidia.com/doca/sdk/NVIDIA+DOCA+Troubleshooting+Guide)
* [Meson build configuration guide](https://mesonbuild.com/) — the build system every shipped sample uses.

If you are reading this README directly (i.e. not via an agent), the
fastest path to a working build is to follow the Installation Guide
above with the `doca-all` profile, then in the cloned sample tree run
`meson /tmp/build && ninja -C /tmp/build` from `applications/`. The
generated binaries land under `/tmp/build/<application_name>/doca_<application_name>`.

For a richer "first app" walk-through that an AI agent can drive
end-to-end against either a real DOCA install or the NGC container,
follow the staged roadmap above and let the agent take you through
[`doca-setup`](skills/doca-setup/SKILL.md) →
[`doca-programming-guide ## modify`](skills/doca-programming-guide/TASKS.md#modify) →
the matching library skill.
