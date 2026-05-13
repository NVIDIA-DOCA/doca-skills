---
name: doca-ai-runner
description: Use DOCA source evidence and source-package tools for capability lookup, source-package discovery, and build planning without mutating user state.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source evidence, source-package tools, source-package discovery, capability lookup, and build planning
Read when: a `doca-skills` export needs a short runner skill

# DOCA AI Runner

Use this skill when work needs source-backed DOCA facts before build, runtime, API, or package claims.

## Read First

- `getting-started/quickstart.md`
- `getting-started/first-commands.md`
- `getting-started/validation.md`
- `contracts/README.md`

## Commands

```sh
find contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print
find <source-package-root> -maxdepth 1 -name VERSION -print
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For a separate SDK source package, pass that package path:

```sh
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

## Rules

- Treat contracts, SDK headers, package metadata, and source files as evidence.
- Use planner-only evidence before any build or source edit.
- Do not install packages, mutate devices, change networking, write credentials, alter persistent config, run traffic,
  or execute runtime samples as a side effect of answering.
- Report missing contracts, packages, headers, sensors, or approvals as blockers.

## Return

Include `diagnosis`, `source_inventory`, selected contract or capability ID, commands run, `unmet_prerequisites`, and
exact next safe command.
