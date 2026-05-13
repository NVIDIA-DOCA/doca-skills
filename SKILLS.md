# Skill index

Skills installed in this repository. Each row gives the skill ID, where to
find its source file, and a one-line trigger for when an agent should load it.

For the discovery convention and ground rules every agent must follow, see
[AGENTS.md](AGENTS.md).

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-public-knowledge-map` | [.claude/skills/doca-public-knowledge-map/SKILL.md](.claude/skills/doca-public-knowledge-map/SKILL.md) | The user asks anything about DOCA where you need to locate authoritative documentation, installed package paths, downloads, samples, the developer forum, or how to find the installed DOCA version — without access to the DOCA source repository. |
| `doca-setup` | [.claude/skills/doca-setup/SKILL.md](.claude/skills/doca-setup/SKILL.md) | Env-class only. The user is installing DOCA, verifying the install, preparing the build env (`pkg-config`, headers, hugepages, devlink), debugging an env-class failure, or asking *I'm on macOS / Windows / Linux without DOCA — how do I reach an install?* (the canonical Stage-1 answer is the public NGC DOCA container `nvcr.io/nvidia/doca/doca`, alongside lab-host, cloud-Linux, and hardware paths). Hands off to `doca-programming-guide` once the env is healthy. |
| `doca-programming-guide` | [.claude/skills/doca-programming-guide/SKILL.md](.claude/skills/doca-programming-guide/SKILL.md) | The user has a healthy DOCA env and is asking a general DOCA programming question — the canonical `pkg-config doca-<library>` build pattern (C/C++ direct or non-C via FFI / bindings), the universal *derive a custom first app from a shipped sample* workflow that every library extends, the universal `cfg-create → init → start → use → stop → destroy` lifecycle, the cross-library `DOCA_ERROR_*` taxonomy with `doca_error_get_descr()`, the validate-before-commit rule, or the program-side debug order. Library-agnostic; library-specific overlays live in the matching library skill. |
| `doca-flow` | [.claude/skills/doca-flow/SKILL.md](.claude/skills/doca-flow/SKILL.md) | The user is working with DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, Flow counters and traces, Flow version compatibility, or debugging `DOCA_ERROR_*` failures from the Flow API. Builds on `doca-setup` (env) and `doca-programming-guide` (cross-library patterns) and layers Flow specifics on top. |

## Adding a new skill

1. Create a directory under `.claude/skills/<kebab-case-id>/` with a
   `SKILL.md` inside.
2. Use the frontmatter contract documented in `ci/check-skill.sh` (`name`,
   `description ≤ 1024 chars`, `kind: knowledge | library`).
3. Add a row to the table above with a single-line "when to load" trigger.
4. Run `ci/check-skill.sh` locally and confirm it passes.
