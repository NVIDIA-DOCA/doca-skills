# Module Guidance Template

Applies to: `<source-package-area-or-sdk-topic>`
Read when: an agent needs module-specific context for `<topic>`
Load next: `guides/capability-map.md`,
`contracts/agent-manifest.json`

Copy this file when a source package or SDK area needs module-specific guidance. Replace placeholder text with
source-backed evidence. Keep the three persona sections even when one is not applicable, and mark that section
`not_applicable` with evidence.

## Scope

- `module_id`: `<short-id>`
- `source_paths`: `<sdk-header-or-package-paths>`
- `sample_paths`: `<sample-or-application-paths>`
- `package_metadata`: `<package-meson-or-package-metadata-paths>`
- `out_of_scope`: `<paths-or-actions-this-guide-does-not-cover>`

## libraries_overview

Use this section for SDK and library users.

- `sdk_headers`: `<headers and APIs agents may cite>`
- `key_apis`: `<functions, structs, lifecycle calls, and stability notes>`
- `dependencies`: `<pkg-config names, Meson dependencies, package names>`
- `build_evidence`: `<Meson files, package metadata, source commands>`
- `validation_commands`: `<read-only or build-planning commands>`
- `unmet_prerequisites`: `<facts the local package must still prove>`

## services_overview

Use this section for service, application, and operator workflows.

- `operator_entrypoints`: `<services, applications, config files, or docs>`
- `runtime_prerequisites`: `<devices, packages, modes, peer setup, or topology>`
- `safe_discovery`: `<read-only commands or files agents may inspect>`
- `blocked_mutations`: `<traffic, device, network, credential, or persistent changes requiring approval>`
- `observability`: `<logs, counters, status commands, or validation outputs>`
- `unmet_prerequisites`: `<runtime facts not proven by source alone>`

## tools_overview

Use this section for tool users and build/debug workflows.

- `cli_tools`: `<CLI helpers, scripts, or helper commands>`
- `build_tools`: `<Meson, Ninja, pkg-config, compiler, or package helpers>`
- `debug_tools`: `<log, trace, status, or validation helpers>`
- `safe_commands`: `<read-only or planner-only commands>`
- `approval_gated_commands`: `<commands that write files, run traffic, or mutate state>`
- `output_artifacts`: `<files, directories, or reports produced when approved>`

## Evidence Rules

- Cite package-local files before online or memory-based facts.
- Keep runtime evidence separate from source and package evidence.
- Report missing headers, dependencies, devices, or tools as blockers.
- Do not invent API names, package names, devices, ports, or topology.
- Do not install packages, configure networking, write credentials, mutate devices, run traffic, or execute runtime
  samples without local owner approval.
