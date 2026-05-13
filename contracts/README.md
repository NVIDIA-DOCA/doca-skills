# DOCA Agent Contracts

Applies to: `contracts/**`, capability contracts, task runbooks
Read when: consuming machine-readable DOCA guidance from this source package
Load next: `contracts/agent-manifest.json`, `contracts/capabilities/`, `contracts/tasks/`

Agent contracts describe package-visible capabilities and task wrappers. They identify source paths, risk class, allowed
commands, structured outputs, recovery notes, and local checks so agents do not infer missing modules or runtime facts.

## Contract Files

- `contracts/agent-manifest.json`: package entrypoint with visible capabilities and tasks.
- `contracts/capability-catalog.json`: compact capability list for lookup.
- `contracts/capabilities/`: capability records selected for this source view.
- `contracts/tasks/`: task runbooks selected for this source view.
- `contracts/schemas/`: JSON schemas for task results, manifests, and package-owner handoff artifacts such as binary
  context install maps.

The manifest includes only contracts that match files in this package.

## Package Checks

Use package-local helpers before suggesting runtime, device, network, credential, package-manager, or persistent system
changes:

```bash
python3 tools/lookup_capability.py --repo-root . --list
```

`tools/run_agent_task.py` reports source version, visible capabilities, experimental API marker summary, and read-only
sensor status for `discover-doca-environment` when source metadata is present. Planner tasks return target paths,
package-facing build files, unmet prerequisites, and approval gates without running builds unless the task contract
requires explicit local-output approval.

## Contract Rules

- Use only capability IDs and task IDs listed in the manifest.
- Treat missing source paths, helper tools, package metadata, devices, or sensors as blockers to report.
- Keep runtime, device, network, credential, package-manager, firmware, hugepage, `devlink`, `sysfs`, and production
  actions approval-gated.
- Back API-stability or experimental-API claims with package-local helper output or local header evidence.
