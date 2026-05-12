# Service Module Template

Applies to: `<service-or-application-source-package-area>`
Read when: an agent needs operator, service, application, runtime prerequisite, or deployment context for `<service>`
Load next: `guides/capability-map.md`, `contracts/agent-manifest.json`

Copy this file when a source package needs focused guidance for service or application operators. Replace placeholders
with source-backed evidence from service source, application entrypoints, configs, deployment files, docs, Meson files,
package metadata, or read-only discovery output.

## Scope

- `module_id`: `<short-service-id>`
- `service_paths`: `<services, applications, extensions, or configuration paths>`
- `operator_entrypoints`: `<binaries, service names, config files, deployment files, or docs>`
- `package_metadata`: `<Meson, package, profile, or config metadata paths>`
- `out_of_scope`: `<deployments, state changes, devices, or commands this guide does not cover>`

## services_overview

- `service_name`: `<service, application, or operator-visible component name>`
- `operator_entrypoints`: `<CLI, service, config, deployment, or documentation entrypoints>`
- `runtime_prerequisites`: `<devices, packages, modes, peer setup, topology, privileges, or feature gates>`
- `safe_discovery`: `<read-only commands or files agents may inspect before suggesting actions>`
- `blocked_mutations`:
  `<traffic, device, network, credential, package-manager, firmware, or persistent changes needing approval>`
- `observability`: `<logs, counters, status commands, metrics, health checks, or validation outputs>`
- `unmet_prerequisites`: `<runtime facts not proven by source or local read-only discovery>`

## Evidence Rules

- Cite package-local service/application files, configs, Meson files, and package metadata before online or memory-based
  facts.
- Treat deployment, device, network, credential, package-manager, firmware, traffic, and persistent configuration
  actions as approval-gated.
- Do not treat sample config values, interface names, PCI addresses, ports, peer hosts, or credentials as
  current-machine facts.
- Separate source-package guidance from runtime readiness; source presence alone does not prove a service can start.
- If required runtime facts are missing, report blockers and safe discovery commands instead of inventing deployment
  steps.
