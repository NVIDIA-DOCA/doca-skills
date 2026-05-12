---
name: doca-programming-guide
description: Route DOCA Programming Guide questions through documentation plus local source-package evidence for APIs, lifecycle, dependencies, and safety.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA Programming Guide routing and source-backed API answers
Read when: a `doca-skills` export needs a short Programming Guide skill

# DOCA Programming Guide

Use this skill for SDK architecture, compatibility, API, lifecycle, capability checking, debugging, utility, and driver
questions.

## Read First

- `getting-started/online-docs.md`
- `getting-started/first-commands.md`
- `getting-started/sdk-development.md`
- `contracts/README.md`
- `modules/README.md`

## Source Order

1. Inspect `VERSION`, package metadata, SDK headers, Meson/pkg-config files, contracts, samples, and applications in the
   source package.
2. Use <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> for conceptual routing.
3. If online docs and local source disagree, report `version_mismatch` and prefer local source for commands, APIs,
   dependencies, and file paths.

## Commands

```sh
python3 tools/lookup_capability.py --repo-root <source-package-root> --list
python3 tools/lookup_capability.py --repo-root <source-package-root> --api-index <capability-id>
```

## Return

Include `source_version`, `online_doc_context`, `version_mismatch`, `local_evidence`, `library_name`, `key_functions`,
`required_packages`, `lifecycle_steps`, `capability_check_plan`, `debuggability_plan`, `safe_boundaries`, and
`verification_commands`.

Do not turn online example device names, PCI addresses, interfaces, firmware, counters, or topology into local facts.
