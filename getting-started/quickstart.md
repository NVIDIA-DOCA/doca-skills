# Quickstart

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: starting agent-assisted DOCA SDK work from this helper repository
Load next: `README.md`, `getting-started/README.md`, `getting-started/first-commands.md`, `examples/README.md`, `skills/doca-user-rules/SKILL.md`, `skills/doca-ai-runner/SKILL.md`

This repository gives agents a small, source-backed starting point for DOCA SDK questions. It is a helper repository,
not the SDK source tree.

## Choose Mode

Use helper repository mode when checking the guidance and contracts in this repository:

```bash
find contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print
```

Use SDK source package mode when answering SDK version, header, dependency, sample, application, device, or topology
questions:

```bash
find <source-package-root> -maxdepth 1 -name VERSION -print
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
pkg-config --modversion <pkg-name>
```

Do not treat helper repository facts as SDK facts. If the SDK source package is missing contracts, headers, metadata,
source-package tools, or sensors, report that gap instead of guessing from this repository.

## First Ten Minutes

1. Read `README.md`, this file, and `skills/doca-user-rules/SKILL.md`.
2. Read `examples/README.md` if you want prompt shapes and expected agent flow diagrams before running an evidence
   command.
3. Run `find contracts -maxdepth 2 -type f -print` to verify the helper repository contract surface.
4. If the task targets a DOCA SDK source package, rerun discovery against `<source-package-root>`.
5. For SDK API questions, inspect contracts, SDK headers, Meson files, and `pkg-config` metadata before naming headers,
   functions, dependencies, or samples.
6. For sample or application builds, start with planner-only mode:

   ```bash
   find <sample-or-application-path> -maxdepth 2 \( -name meson.build -o -name meson.build \) -print
   pkg-config --print-errors --exists <pkg-name>
   ```

7. Treat package installs, device changes, network changes, persistent configuration, credentials, runtime traffic, and
   runtime samples as blocked until the local owner approves that action class.

## Expected Answer Shape

Useful answers should name:

- Guidance files read from this repository.
- SDK source package path used, or `not_provided`.
- Commands run and their structured results.
- Capability or task ID selected.
- Source-backed libraries, services, and tools overviews when relevant.
- Missing files, metadata, sensors, packages, devices, or approvals.
- Exact next safe command.
