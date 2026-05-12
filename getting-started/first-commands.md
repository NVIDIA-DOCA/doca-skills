# Source-Package First Commands

Applies to: source-package discovery, capability lookup, SDK build planning, and optional source-change task routing
Read when: another doc or portable skill needs safe first commands for a DOCA source package
Load next: `getting-started/validation.md`, `contracts/README.md`, `skills/doca-ai-runner/SKILL.md`

Run these commands from the repository or source-package root. Skip a command
only when the helper is absent from the package, and record that absence in
`unmet_prerequisites` instead of guessing package, device, or capability facts.

## Baseline Source-Package Discovery

```bash
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root .
```

Use these before naming runtime commands, local capabilities, package metadata,
or source-package gaps. The discovery result should anchor `source_version`,
`available_capabilities`, and `experimental_api_summary`.

## API Or Library Lookup

```bash
python3 tools/lookup_capability.py --repo-root . --summary <capability-id>
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id> --symbol-filter <symbol-or-topic>
```

Use `contracts/capability-catalog.json` or the capability list command
to map user terms to capability IDs that are present in the current package.
Do not assume module-specific capabilities exist unless the current package
manifest lists them.

## Sample Or Application Audit

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . --focus-path <samples-or-applications-path>
```

Use this for manager, sample, application, or package-build questions. The
planner-only build task reports package-facing build files, dependency files,
helper sources, include directories, output directories, approval classes, and
unmet prerequisites without creating build output.

Source-change planners are not part of the skills repository. If a DOCA
source package publishes a source-change task in its manifest, use that exact
task ID and keep execution under the local package owner's policy.

## Approval-Gated Local Build

Run local build execution only after the local owner approves build output and
only with the planner-reported focus path and build directory:

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . \
  --focus-path <sample-or-application-path> --execute --approve local_build_output \
  --build-dir build/ai-planner/build-sdk-sample/<derived-focus-path>
```

This executor is limited to repository-root Meson setup and compile commands.
It must not install packages or run runtime, device, network, credential, or
production actions.

## Missing Helper Fallback

If `tools` helpers are not present, switch to the installed-package
fallback in `getting-started/validation.md`. Keep the same structured fields
where possible, mark unavailable runner checks explicitly, and do not hide the
difference between source-package discovery and install-only discovery.
