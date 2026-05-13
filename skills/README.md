# Skill Catalog

Applies to: `NVIDIA-DOCA/doca-skills/skills`
Read when: selecting one DOCA Agent Skill
Load next: the matching `skills/<name>/SKILL.md`

Pick one top-level skill and keep the first pass narrow.

| Skill | Use When | Output |
| --- | --- | --- |
| `doca-programming-guide` | Programming Guide, API, lifecycle, dependency, or DOCA Flow lookup. | Source-backed API answer with doc links and mismatch notes. |
| `doca-discover-environment` | Source, version, package, tool, device, or topology discovery. | Measured facts, blockers, and next safe command. |
| `doca-ai-runner` | Contract routing, task selection, or SDK sample build planning. | Selected task/capability, commands, and approval gates. |

## Selection Rules

- Use `doca-discover-environment` before version, package, device, or topology claims.
- Use `doca-programming-guide` before naming APIs, lifecycle order, dependencies, or DOCA Flow behavior.
- Use `doca-ai-runner` when the prompt asks what can be done safely or how to plan a sample/application build.
- If a task spans more than one row, start with discovery, then use the skill that answers the main user question.
