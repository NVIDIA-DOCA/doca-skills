---
name: doca-discover-environment
description: Run read-only DOCA source-package discovery and report package, capability, version, and topology facts without hardcoded assumptions.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA source-package and environment discovery
Read when: a `doca-skills` export needs a short discovery skill

# DOCA Discover Environment

Use this skill before answering what a DOCA source package contains, what capabilities are visible, or what environment
facts are known.

## Read First

- `getting-started/environment-discovery.md`
- `getting-started/first-commands.md`
- `contracts/tasks/discover-doca-environment.yaml`
- `skills/doca-ai-runner/SKILL.md`

## Command

```sh
find <source-package-root> -maxdepth 1 -name VERSION -print
find <source-package-root>/contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print 2>/dev/null
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For API inventory after discovery:

```sh
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

## Rules

- Do not hardcode PCI addresses, interface names, representors, GPU IDs, package versions, firmware, or topology.
- Treat source-visible examples as evidence of source coverage, not proof that current runtime hardware is configured.
- If a sensor or evidence source is missing, report it as `not_measured` or an unmet prerequisite.
- Do not install packages, mutate devices, change networking, or run samples.

## Return

Report `source_version`, `available_capabilities`, `experimental_api_summary`, measured sensors, blockers, and next safe
command.
