---
name: doca-build-sdk-sample
description: Plan a DOCA SDK sample or application build from source evidence, then run only an explicitly approved repository-contained build.
---

License: see repository root `LICENSE.md`.

Applies to: DOCA sample and application build planning
Read when: a `doca-skills` export needs a short build-planning skill

# DOCA Build SDK Sample

Use this skill for sample or application build requests.

## Read First

- `getting-started/first-commands.md`
- `getting-started/sdk-development.md`
- `contracts/tasks/build-sdk-sample.yaml`
- `skills/doca-ai-runner/SKILL.md`

## Plan

Start planner-only:

```sh
find <sample-or-application-path> -maxdepth 2 \( -name meson.build -o -name meson.build \) -print
find <sample-or-application-path> -path '*/dependencies/meson.build' -print
pkg-config --print-errors --exists <pkg-name>
```

Use output fields `target_path`, `package_build_files`, `package_dependency_files`, `required_packages`,
`helper_sources`, `include_directories`, `validation_command_candidates`, and `unmet_prerequisites`.

## Execute

Run a build only after explicit approval for repository-contained build output:

```sh
meson setup <build-dir> <source-package-root> --reconfigure
ninja -C <build-dir> <target>
```

Do not install packages, start services, mutate devices, change networking, or run runtime samples as part of build
planning.
