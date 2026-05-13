---
name: doca-discover-environment
description: Run read-only DOCA source-package discovery without hardcoded version, package, device, or topology facts.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source-package and environment discovery
Read when: measuring what a DOCA source package or installed SDK exposes

# DOCA Discover Environment

Use this skill before answering what a DOCA source package contains, which SDK packages are installed, or what
environment facts are known.

## Read First

- `getting-started/quickstart.md`
- `contracts/tasks/discover-doca-environment.yaml`
- `skills/doca-task-router/SKILL.md`

## Commands

```sh
find <source-package-root> -maxdepth 1 -name VERSION -print
find <source-package-root> -name meson.build -print | head
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For API inventory after discovery:

```sh
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

For local topology inventory, run only commands that exist:

```sh
lspci -Dnn | grep -Ei "nvidia|mellanox|bluefield|connectx"
ip -br link
ip -d link show
devlink dev show
devlink port show
devlink dev eswitch show
rdma dev show
rdma link show
ibv_devinfo -v
nvidia-smi topo -m
```

## Rules

- Do not hardcode PCI addresses, interface names, representors, GPU IDs, package versions, firmware, or topology.
- Treat source-visible examples as evidence of source coverage, not proof that current runtime hardware is configured.
- If a sensor or evidence source is missing, report it as `not_measured` or an unmet prerequisite.
- Do not install packages, mutate devices, change networking, or run samples.

## Return

Report `source_version`, `available_capabilities`, `experimental_api_summary`, topology coverage, measured sensors,
blockers, and next safe command.
