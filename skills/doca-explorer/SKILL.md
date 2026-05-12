---
name: doca-explorer
description: Explore DOCA source-package docs, samples, applications, contracts, and module templates with libraries/services/tools overviews.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source-package exploration and libraries/services/tools overviews
Read when: a `doca-skills` export needs a short exploration skill

# DOCA Explorer

Use this skill when the user asks what an agent can learn or safely do with a DOCA source package.

## Read First

- `llms.txt`
- `getting-started/quickstart.md`
- `guides/capability-map.md`
- `modules/README.md`
- `modules/library-template.md`
- `modules/service-template.md`
- `modules/tool-template.md`
- `skills/doca-ai-runner/SKILL.md`

## Commands

```sh
python3 tools/lookup_capability.py --repo-root <source-package-root> --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>
```

## Return

Use source-backed sections:

- `documentation_entrypoints`
- `libraries_overview`: SDK/library users, headers, APIs, Meson/pkg-config evidence.
- `services_overview`: service or application operators, runtime prerequisites, blocked mutations.
- `tools_overview`: CLI, build, debug helpers, validation commands.
- `capability_coverage`
- `topology_coverage`
- `safety_boundaries`
- `unmet_prerequisites`

Use `not_measured` or `requires_runtime_verification` for facts not proven by current source or read-only tool output.
