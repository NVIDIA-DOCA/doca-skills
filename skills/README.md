# Skill Catalog

Applies to: `NVIDIA-DOCA/doca-skills/skills`
Read when: selecting a portable DOCA skill
Load next: the matching `skills/<name>/SKILL.md`

Use these skills as focused runbooks. Pick the smallest skill that matches the task, read its `SKILL.md`, then follow
the linked guidance and source-package commands.

## By Persona

| Persona | Start With | Main Output |
| --- | --- | --- |
| SDK library developer | `doca-programming-guide`, then `doca-explorer` | `libraries_overview` |
| Service or application operator | `doca-discover-environment`, then `doca-explorer` | `services_overview` |
| Tool workflow user | `doca-ai-runner`, then `doca-explorer` | `tools_overview` |
| Sample or application builder | `doca-build-sdk-sample` | build plan plus matching overview |
| Host/package installer | `doca-ai-runner`, then `getting-started/package-install.md` | `host_installation` |
| Environment/setup investigator | `doca-discover-environment` | measured facts and blockers |

Read `guides/persona-routing.md` when a prompt mixes more than one persona.

| Skill | Use When |
| --- | --- |
| `doca-user-rules` | Start any DOCA SDK task with safe defaults and concise answer rules. |
| `doca-ai-runner` | Choose source evidence and interpret package task contracts. |
| `doca-discover-environment` | Collect read-only source-package and local environment facts. |
| `doca-build-sdk-sample` | Plan sample or application builds without running the build. |
| `doca-explorer` | Inspect source layout, contracts, modules, and package evidence. |
| `doca-programming-guide` | Answer SDK architecture and API questions with local evidence first. |

## Selection

- Use `doca-user-rules` before changing assumptions or command risk.
- Use `doca-discover-environment` before answering version, package, device, or capability questions.
- Use `doca-build-sdk-sample` when the request names a sample, application, or `meson.build` path.
- Use `doca-explorer` when the user asks where something lives or what guidance applies.
- Use `doca-programming-guide` when the answer needs SDK API context, lifecycle steps, or links to NVIDIA documentation.
