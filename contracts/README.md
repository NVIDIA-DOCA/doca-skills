# DOCA Agent Contracts

Applies to: `contracts/**`, AI manifests, capability contracts, task runbooks
Read when: adding or consuming machine-readable DOCA guidance for coding agents
Load next: `contracts/agent-manifest.json`, `contracts/capabilities/`, `contracts/tasks/`

Agent contracts are the machine-readable layer above the human guidance in
`top-level guidance directories`. They describe what an agent may try, which repository paths are the
evidence source, which discovery sensors must run first, which mutations require
approval, what typed inputs and outputs the task expects, and how a task is
verified or recovered.

## Contract Files

Capability contracts live under `contracts/capabilities/*.json`.
Task runbooks live under `contracts/tasks/*.yaml`.
`contracts/agent-manifest.json` and
`contracts/capability-catalog.json` summarize the contract files included in this package.

This package includes only contracts and catalog entries that apply to files it contains.

Use the capability lookup helper when an agent needs a compact summary or the
next files to load:

```bash
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/lookup_capability.py --repo-root . --summary <capability-id>
python3 tools/lookup_capability.py --repo-root . --detail <capability-id>
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
```

Use `--api-index` for library, API, or lifecycle questions. It scans only the
current source view and returns SDK-header symbols, exported symbols, Meson
dependencies, and sample/application references for the selected capability.

## Manifest Structure Quick Reference

`contracts/agent-manifest.json` is an entrypoint for agents and
package tools. Treat these fields as the contract shape:

- `schema_version`: manifest format version.
- `capabilities`: capability records selected from
  `contracts/capabilities/*.json`.
- `tasks`: executable or planner-backed task records selected from
  `contracts/tasks/*.yaml`.

Capability records identify the source area, source globs, guidance
files, sensors, constraints, validation, and recovery notes for a module or
workflow. Capability records can also expose `discovery_data` with normalized
device, library, mode, offload, version, and constraint lists so agents can
reason about device-aware code paths without scraping human prose. Task records
identify the task ID, risk class, command kind, typed inputs and outputs,
structured errors, approval gates, result schema, verifier, and recovery
behavior. Consumers should read these fields instead of scraping human prose,
and source owners should update the matching capability or task file when the contract changes.

## Read-Only Runner

The initial executable contract wrapper is intentionally narrow and safe. It
implements `discover-doca-environment` and returns the common task-result JSON
shape:

```bash
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root .
```

Selected non-discovery tasks return a planner-only JSON result instead of
executing:

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . --focus-path samples/doca_flow
```

Planner-only results report target paths, nearby build and test files, approval
classes, expected local output directories, validation command candidates,
blocked prerequisites, and next commands. They must not edit, build, run
runtime commands, create output directories, or mutate state. If the runner
returns `unsupported_task`, follow the human-readable contract and do not infer
runtime or build behavior from the wrapper.

`build-sdk-sample` also has a reviewed local-build executor. It is disabled
unless the caller passes `--execute`, explicitly grants
`--approve local_build_output`, supplies exactly one `--focus-path`, and reuses
the planner-reported build directory inside the repository:

```bash
python3 tools/run_agent_task.py --task build-sdk-sample --repo-root . \
  --focus-path samples/doca_flow --execute --approve local_build_output \
  --build-dir build/ai-planner/build-sdk-sample/samples-doca_flow
```

The executor runs only Meson setup and compile commands from the repository
root. Its result reports the selected focus path, derived target directory,
build directory, command records, built targets, and unmet prerequisites. It
does not install packages or run runtime, device, network, credential, or
production actions.

Some DOCA source packages may list additional source-change task IDs. Source
skills packages do not include module patch helpers. If a package
manifest includes such a task, follow that task contract and the local source
owner's review and approval policy rather than inferring execution behavior
from a skills repository.

## Approval Profiles

Task contracts can either spell out `approval_required_for` directly or use a
reusable `approval_profile` when several contracts need the same approval gates.
The contract loader expands the profile into `approval_required_for`, so
runners and tool consumers still receive the stable approval list.

Skills packages should treat any unavailable source-change approval
profile as intentionally unavailable. Source packages that include
source-change task IDs must keep their approval profile documented in the task
contract itself.

## Contract Rules

- Every contract must include `source_globs`, `sensors`,
  `constraints`, `verifier`, and `recovery`.
- Use `discovery_data` when a capability needs machine-readable device,
  library, mode, offload, version, or constraint facts for source-aware agents.
  Keep these entries source-backed and treat runtime topology as a fact to
  discover, not infer.
- Every task must include `risk_class`, `command_kind`, typed `inputs`, typed
  `outputs`, `structured_errors`, and a `result_schema` path. Use the common
  result shape at `contracts/schemas/task-result.schema.json` unless a
  task needs a stricter schema.
- Use `approval_profile` for repeated approval gates, and keep
  task-specific `approval_required_for` entries only when the task needs
  additional gates not covered by the profile.
- Every `source_globs` entry must match at least one path in the current source
  tree so deleted modules do not leave stale AI instructions behind.
- Every task must reference existing capability IDs.
- Every actuator that can mutate system state, device state, credentials,
  networking, persistent configuration, production resources, hugepages,
  `devlink`, or `sysfs` must list an approval gate.
- Do not encode sample values as real environment facts. Use sensors to discover
  device names, PCI addresses, representors, firmware, package versions, and
  capability support.
- Claims about API stability, compatibility, or experimental API counts must
  point to a reproducible command or reproducible evidence.

## Validation

Use these package checks before relying on contract data:

```bash
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root .
```

This package exposes source-backed discovery and validation commands, not scorer inputs or scorer helpers.
