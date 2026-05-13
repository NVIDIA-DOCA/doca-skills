# DOCA Skills

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: starting agent-assisted DOCA SDK source-package work
Load next: `getting-started/quickstart.md`, `skills/README.md`,
`contracts/agent-manifest.json`

This repository is a standalone helper payload for DOCA SDK source-package work. It helps an agent choose a narrow
skill, run read-only discovery, look up Programming Guide/API evidence, and plan SDK sample builds without changing user
state.

It is not the SDK source tree. When the task needs SDK facts, inspect the `<source-package-root>` provided by the user
and report the exact evidence path used.

## Start

1. Read `getting-started/quickstart.md`.
2. Choose one skill from `skills/README.md`.
3. Read `contracts/agent-manifest.json` for the available task IDs.
4. Run read-only commands against this repository or `<source-package-root>`.
5. Return measured facts, blockers, and the next safe command.

## Repository Map

| Path | Purpose |
| --- | --- |
| `getting-started/quickstart.md` | First workflow, DOCA knowledge map, troubleshooting, and links. |
| `skills/` | Three focused skills for docs lookup, discovery, and task routing. |
| `contracts/` | Minimal capability and task contracts for source-backed agent work. |
| `.agents/skills/` | Skill discovery links for agents that scan a standard location. |
| `package-info.json` | Small package descriptor for the helper payload. |

## Skill Set

| Skill | Use When |
| --- | --- |
| `skills/doca-programming-guide/SKILL.md` | Answer API, lifecycle, dependency, or DOCA Flow questions. |
| `skills/doca-discover-environment/SKILL.md` | Measure SDK source, version, package, and tool availability. |
| `skills/doca-task-router/SKILL.md` | Route task contracts and build-planning evidence safely. |

## Default Commands

```bash
find contracts -maxdepth 2 -type f -print
find <source-package-root> -maxdepth 1 -name VERSION -print
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For sample or application build planning, inspect only metadata first:

```bash
find <sample-or-application-path> -maxdepth 2 -name meson.build -print
pkg-config --print-errors --exists <pkg-name>
```

## Boundary

Default work is read-only. Do not install packages, mutate devices, change networking, write credentials, change
persistent configuration, run traffic, or execute runtime samples unless the local owner explicitly approves that action
class outside this helper payload.
