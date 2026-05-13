---
name: doca-programming-guide
description: Use DOCA docs plus source-package evidence for APIs, lifecycle, dependencies, and DOCA Flow.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA Programming Guide routing and source-backed API answers
Read when: an answer needs SDK architecture, API, lifecycle, or dependency facts

# DOCA Programming Guide

Use this skill for SDK architecture, compatibility, API, lifecycle, capability checking, debugging, utility, driver, and
DOCA Flow questions.

## Read First

- `getting-started/quickstart.md`
- `contracts/agent-manifest.json`
- `contracts/capability-catalog.json`

## Source Order

1. Inspect `VERSION`, package metadata, SDK headers, Meson files, pkg-config metadata, samples, and applications in
   `<source-package-root>`.
2. Use <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> and related DOCA docs for concept routing.
3. If online docs and local source disagree, report `version_mismatch` and prefer local source for commands, APIs,
   dependencies, and file paths.

## Commands

```sh
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
grep -R "<symbol-or-topic>" <source-package-root>/samples <source-package-root>/applications 2>/dev/null
pkg-config --cflags --libs <pkg-name>
```

## Return

Include `source_version`, `online_doc_context`, `version_mismatch`, `local_evidence`, `library_name`, `key_functions`,
`required_packages`, `lifecycle_steps`, `capability_check_plan`, `debuggability_plan`, `safe_boundaries`, and
`verification_commands`.

Do not turn online example device names, PCI addresses, interfaces, firmware, counters, or topology into local facts.
