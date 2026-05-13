# Skill index

Skills installed in this repository. Each row gives the skill ID, where to
find its source file, and a one-line trigger for when an agent should load it.

For the discovery convention and ground rules every agent must follow, see
[AGENTS.md](AGENTS.md).

| Skill | Source | When to load |
| --- | --- | --- |
| `doca-public-knowledge-map` | [.claude/skills/doca-public-knowledge-map/SKILL.md](.claude/skills/doca-public-knowledge-map/SKILL.md) | The user asks anything about DOCA where you need to locate authoritative documentation, installed package paths, downloads, samples, the developer forum, or how to find the installed DOCA version — without access to the DOCA source repository. |
| `doca-flow` | [.claude/skills/doca-flow/SKILL.md](.claude/skills/doca-flow/SKILL.md) | The user is working with DOCA Flow on BlueField — port and representor setup, pipe creation, match/action specifications, pipe validation before hardware programming, Flow counters and traces, Flow version compatibility, or debugging `DOCA_ERROR_*` failures from the Flow API. |

## Adding a new skill

1. Create a directory under `.claude/skills/<kebab-case-id>/` with a
   `SKILL.md` inside.
2. Use the frontmatter contract documented in `ci/check-skill.sh` (`name`,
   `description ≤ 1024 chars`, `kind: knowledge | library`).
3. Add a row to the table above with a single-line "when to load" trigger.
4. Run `ci/check-skill.sh` locally and confirm it passes.
