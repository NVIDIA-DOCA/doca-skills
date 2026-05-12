# Skill Catalog

Applies to: `NVIDIA-DOCA/doca-skills/skills`
Read when: selecting a portable DOCA skill
Load next: the matching `skills/<name>/SKILL.md`

Use these skills as focused runbooks. Pick the smallest skill that matches the task, read its `SKILL.md`, then follow
the linked guidance and helper commands.

| Skill | Use When |
| --- | --- |
| `doca-user-rules` | Start any DOCA SDK task with safe defaults and concise answer rules. |
| `doca-ai-runner` | Choose package helper tools and interpret task-result JSON. |
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
