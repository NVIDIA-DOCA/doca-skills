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
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root <source-package-root> --focus-path <sample-or-application-path>
```

Use output fields `target_path`, `package_build_files`, `package_dependency_files`, `required_packages`,
`helper_sources`, `include_directories`, `validation_command_candidates`, and `unmet_prerequisites`.

## Execute

Run a build only after explicit approval for repository-contained build output:

```sh
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root <source-package-root> \
  --focus-path <sample-or-application-path> --execute --approve local_build_output \
  --build-dir <planner-reported-build-dir>
```

Do not install packages, start services, mutate devices, change networking, or run runtime samples as part of build
planning.
