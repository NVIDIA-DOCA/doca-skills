# DOCA Framework Drivers Template

Applies to: `<driver-or-driver-facing-source-package-area>`
Read when: an agent needs driver, device binding, host prerequisite, or installed SDK context for `<driver-or-driver-facing-component>`
Load next: `guides/capability-map.md`, `contracts/agent-manifest.json`

Copy this file when a source package needs focused guidance for driver-facing users. Replace placeholders with
source-backed evidence from headers, service or library source, package metadata, docs, device-info APIs, and read-only
installed-tool output.

## Scope

- `framework_area`: `drivers`
- `guide_id`: `<short-driver-id>`
- `primary_persona`: `driver integrator`
- `driver_paths`: `<driver-facing headers, libraries, services, or package paths>`
- `device_evidence`: `<device-info APIs, installed metadata, header constants, or docs agents may inspect>`
- `package_metadata`: `<Meson, pkg-config, dependency, or package metadata paths>`
- `out_of_scope`:
  `<device mutations, host configuration, firmware, package installation, or runtime modes this guide does not cover>`

## drivers_overview

- `driver_name`: `<driver, device family, or driver-facing SDK component>`
- `user_goals`: `<host prerequisite review, capability checks, API/device binding, or troubleshooting>`
- `source_evidence`: `<headers, contracts, Meson files, package metadata, or docs that prove the guidance>`
- `safe_discovery`: `<read-only commands or file inspections agents may run or suggest>`
- `device_capability_checks`: `<APIs, metadata, or commands that measure support without mutation>`
- `blocked_mutations`: `<driver reloads>`, `<firmware changes>`, `<sysfs/devlink writes>`, `<hugepages>`,
  `<package installs>`, `<persistent config>`, or `<network/device state changes>`
- `unmet_prerequisites`: `<missing metadata>`, `<permissions>`, `<devices>`, `<firmware facts>`, `<packages>`, or
  `<runtime measurements>`

## Evidence Rules

- Cite package-local headers, contracts, Meson files, package metadata, and installed metadata before online or
  memory-based facts.
- Optimize answers for users who need prerequisites, support checks, and clear separation between API evidence and
  runtime driver state.
- Treat driver reloads, firmware, sysfs/devlink writes, hugepages, package installation, network/device state changes,
  and persistent configuration as approval-gated.
- Do not invent device names, PCI addresses, firmware versions, driver module names, flags, output paths, package names,
  or environment variables.
- If driver evidence is absent from the source package, report the missing path and closest safe package-local or
  installed-metadata check.
