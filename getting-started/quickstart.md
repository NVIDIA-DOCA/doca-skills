# Quickstart

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: starting agent-assisted DOCA SDK work from this helper repository
Load next: `README.md`, `getting-started/README.md`, `getting-started/first-commands.md`, `examples/README.md`, `skills/doca-user-rules/SKILL.md`, `skills/doca-ai-runner/SKILL.md`

This repository gives agents a small, source-backed starting point for DOCA SDK questions. It is a helper repository,
not the SDK source tree.

## Choose Mode

Use helper repository mode when checking the guidance and tools in this repository:

```bash
python3 tools/lookup_capability.py --repo-root . --list
```

Use SDK source package mode when answering SDK version, header, dependency, sample, application, device, or topology
questions:

```bash
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>
python3 tools/lookup_capability.py --repo-root <source-package-root> --api-index <capability-id>
```

Do not treat helper repository facts as SDK facts. If the SDK source package is missing contracts, helper tools,
headers, metadata, or sensors, report that gap instead of guessing from this repository.

## First Ten Minutes

1. Read `README.md`, this file, and `skills/doca-user-rules/SKILL.md`.
2. Read `examples/README.md` if you want prompt shapes and expected agent flow diagrams before running a helper command.
3. Run `python3 tools/lookup_capability.py --repo-root . --list` to verify the helper repository contract surface.
4. If the task targets a DOCA SDK source package, rerun discovery with `--repo-root <source-package-root>`.
5. For SDK API questions, use `lookup_capability.py --api-index` against the SDK source package before naming headers,
   functions, dependencies, or samples.
6. For sample or application builds, start with planner-only mode:

   ```bash
   python3 tools/run_agent_task.py --task build-sdk-sample --repo-root <source-package-root> \
       --focus-path <sample-or-application-path>
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
