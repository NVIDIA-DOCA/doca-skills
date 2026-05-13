---
name: doca-ai-runner
description: Route DOCA task contracts and build-planning evidence with read-only commands by default.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source evidence, task contracts, discovery, capability lookup, and build planning
Read when: choosing a safe DOCA task flow or planning an SDK sample build

# DOCA AI Runner

Use this skill when work needs a contract-backed flow before build, runtime, API, or package claims.

## Read First

- `getting-started/quickstart.md`
- `contracts/README.md`
- `contracts/agent-manifest.json`

## Commands

```sh
find contracts -maxdepth 2 -type f -print
find <source-package-root> -maxdepth 1 -name VERSION -print
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For a separate SDK source package, pass that package path:

```sh
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

For SDK sample/application build planning, inspect metadata only:

```sh
find <sample-or-application-path> -maxdepth 2 -name meson.build -print
pkg-config --print-errors --exists <pkg-name>
```

## Rules

- Treat contracts, SDK headers, package metadata, and source files as evidence.
- Use planner-only evidence before any build or source edit.
- Do not install packages, mutate devices, change networking, write credentials, alter persistent config, run traffic,
  or execute runtime samples as a side effect of answering.
- Report missing contracts, packages, headers, sensors, or approvals as blockers.

## Return

Include `diagnosis`, `source_inventory`, selected contract or capability ID, commands run, `build_plan` when relevant,
`unmet_prerequisites`, approval gates, and exact next safe command.
