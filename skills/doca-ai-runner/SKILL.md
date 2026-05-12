---
name: doca-ai-runner
description: Use public DOCA helper tools for capability lookup, source-package discovery, and build planning without mutating user state.
package_visibility: public
---

License: see repository root `LICENSE.md`.

Applies to: public DOCA helper tools, source-package discovery, capability lookup, and build planning
Read when: a public `doca-skills` export needs a short runner skill

# DOCA AI Runner

Use this skill when work needs source-backed DOCA facts before build,
runtime, API, or package claims.

## Read First

- `getting-started/quickstart.md`
- `getting-started/first-commands.md`
- `getting-started/validation.md`
- `contracts/README.md`

## Commands

```sh
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root .
```

For a separate SDK source package, pass that package path:

```sh
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>
python3 tools/lookup_capability.py --repo-root <source-package-root> --api-index <capability-id>
```

## Rules

- Treat helper output, public headers, package metadata, and source files as
  evidence.
- Use planner-only task output before any build or source edit.
- Do not install packages, mutate devices, change networking, write
  credentials, alter persistent config, run traffic, or execute runtime samples
  as a side effect of answering.
- Report missing helper paths, packages, headers, sensors, or approvals as
  blockers.

## Return

Include `diagnosis`, `source_inventory`, selected contract or capability ID,
commands run, `unmet_prerequisites`, and exact next safe command.
