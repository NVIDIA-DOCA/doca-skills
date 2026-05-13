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


The manifest includes only contracts that match files in this package.

## Package Checks

Use package-local evidence before suggesting runtime, device, network, credential, package-manager, or persistent system
changes:

```bash
find contracts -maxdepth 2 -type f -print
find skills -maxdepth 2 -name SKILL.md -print
```

## Read-Only Tool Calls

These package-supported calls use standard commands and source evidence only. Helper wrappers are not included.

| Call ID | Purpose | Command |
| --- | --- | --- |
| `contract-files` | List packaged contract files. | `find contracts -maxdepth 2 -type f -print` |
| `skill-files` | List packaged Agent Skill files. | `find skills -maxdepth 2 -name SKILL.md -print` |

Source-package evidence includes `VERSION`, package metadata, contract JSON, SDK headers, Meson files, installed
`doca-*.pc` files, and read-only command output from standard tools such as `find`, `grep`, `pkg-config`, Meson, and
Ninja. Planner responses should return target paths, package-facing build files, unmet prerequisites, and approval gates
without running builds unless the local owner explicitly approves build output.

## Contract Rules

- Use only capability IDs and task IDs listed in the manifest.
- Treat missing source paths, package metadata, devices, tools, or sensors as blockers to report.
- Keep runtime, device, network, credential, package-manager, firmware, hugepage, `devlink`, `sysfs`, and production
  actions approval-gated.
- Back API-stability or experimental-API claims with package-local source evidence or local header evidence.
