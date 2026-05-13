---
name: doca-explorer
description: Explore DOCA source-package docs, samples, applications, contracts, and framework templates with libraries/services/drivers/tools overviews.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source-package exploration and libraries/services/tools overviews
Read when: a `doca-skills` export needs a short exploration skill

# DOCA Explorer

Use this skill when the user asks what an agent can learn or safely do with a DOCA source package.

## Read First

- `llms.txt`
- `getting-started/quickstart.md`
- `guides/persona-routing.md`
- `guides/capability-map.md`
- `framework/README.md`
- `framework/libs-template.md`
- `framework/services-template.md`
- `framework/drivers-template.md`
- `framework/examples/doca-flow-source-guide.md`
- `skills/doca-ai-runner/SKILL.md`

## Commands

```sh
find <source-package-root>/contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print 2>/dev/null
find <source-package-root>/libs -path '*/include/public/*.h' -print 2>/dev/null
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

## Return

Use source-backed sections:

- `persona_route`: primary user type, matched evidence, and any secondary user needs.
- `documentation_entrypoints`
- `libraries_overview`: SDK/library users, headers, APIs, Meson/pkg-config evidence.
- `services_overview`: service or application operators, runtime prerequisites, blocked mutations.
- `tools_overview`: CLI, build, debug helpers, validation commands.
- `capability_coverage`
- `topology_coverage`
- `safety_boundaries`
- `unmet_prerequisites`

Use `not_measured` or `requires_runtime_verification` for facts not proven by current source or read-only tool output.
