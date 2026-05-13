# DOCA Agent Capability Map

Applies to: DOCA samples and applications capability, host installation,
topology, lifecycle, schema, observability, and conformance questions
Read when: evaluating AI capabilities for samples and applications in the
current DOCA source package
Load next: `guides/README.md`,
`guides/persona-routing.md`, `getting-started/quickstart.md`, `getting-started/first-commands.md`,
`framework/README.md`, `reference/c-cpp-style.md`, `skills/doca-explorer/SKILL.md`

Use this map when the user asks what an agent can do with DOCA samples or applications. The answer should report
source-package evidence, safe read-only commands, and runtime evidence needed for hardware or environment-specific
facts.

## Capability Summary

Start capability audits by classifying the requester with `guides/persona-routing.md`. Library developers,
service/application operators, tool workflow users, sample/application builders, host/package installers, and setup
investigators need different evidence and safety boundaries. Keep the overview sections separate even when one prompt
touches more than one persona.

| Capability | Source-package behavior |
| --- | --- |
| Documentation explorer | Start from `llms.txt`, root entrypoints, this file, quickstart, package-facing SDK docs, framework templates and capability-map guidance, and any framework guidance present in `framework/`. Return the exact files used. |
| Coding standards and code review | Use `reference/c-cpp-style.md`, `getting-started/sdk-development.md`, and `framework/README.md` to review sample readability, cleanup, license style, DOCA logging, dependency handling, and runtime-action safety. |
| Libraries overview | For SDK and library users, build the overview from package-visible `contracts/capability-catalog.json`, SDK headers, `libs/**/meson.build`, package-facing Meson files, dependency files, and nearby samples. Mark absent headers or unmeasured runtime facts as requiring package-owner or runtime verification. |
| Services overview | For service or application operators, build the overview from `services/`, `applications/`, package-facing application Meson files, service/application framework guidance, runtime prerequisites, and blocked mutation classes. Keep service startup, traffic, device, network, credential, and persistent configuration actions approval-gated. |
| Drivers overview | For driver-facing users, build the overview from SDK headers, installed metadata, package evidence, safe support checks, and driver framework guidance. Keep driver reloads, firmware, sysfs/devlink writes, hugepages, package installation, and persistent host changes approval-gated. |
| Tools overview | For CLI, build, debug, and validation users, build the overview from package-visible tools, evidence procedures, validation commands, and package-local guidance. Keep tool output source-backed and separate developer-only tools from package-visible helpers. |
| Capability discovery | Read `contracts/agent-manifest.json`, `contracts/capability-catalog.json`, and the first-command discovery procedure. Report capability IDs, source version, package metadata, missing sensors, and available package-facing build files. |
| DOCA-Host installation | Use source-package install guidance, package metadata, installed-package fallback checks, and validation docs to describe host prerequisites and package-visible commands. Do not install packages, alter system paths, load drivers, configure hugepages, or change persistent host state without explicit approval. |
| Topology discovery | Use only read-only sensors reported by `discover-doca-environment`, such as package, RDMA, PCI, or devlink probes when available. Host, BlueField, GPU, NIC, PCIe, NUMA, memory-domain, representor, and offload topology must be `not_measured` when sensors are missing or runtime access is not approved. |
| Standard object lifecycle | Derive create, configure, validate, start, query, stop, and destroy phases from SDK headers when present, package-visible framework guidance, and sample/application source. If headers are absent, report sample-observed lifecycle only and mark API completeness as partial. |
| Machine-readable schemas | Prefer `contracts/agent-manifest.json`, `capability-catalog.json`, task schemas, package metadata, and planner JSON. Library-specific API/config/error/counter schemas are only available when present in the package; do not invent them from sample code. |
| Dry-run or validate mode | Use planner-only contract procedures first. Build and source-change executors require explicit local approvals and repo-contained output paths. Runtime/device validation requires explicit user approval. |
| Unified error taxonomy | Use task `structured_errors`, `doca_error_t` style guidance, observed sample error handling, and recovery hints from validation docs. If a library lacks package-visible error taxonomy, return a gap instead of normalizing undocumented errors. |
| Structured observability | Report health, counters, traces, resource ownership, telemetry, or queue state only when package-visible samples, online docs, or read-only sensors expose them. Runtime counters and traces require explicit approval and hardware access. |
| Permission and safety model | Default to read-only source/package inspection. Block package installation, device mutation, network changes, persistent configuration, credentials, runtime traffic, and production actions unless the local owner explicitly approves the action class. |
| Version and compatibility reporting | Use `VERSION`, `package-info.json`, `pkg-config --modversion <pkg-name>`, manifest digests, and source-package discovery output. If package metadata is absent, mark version facts as unknown. |
| Conformance tests | Use package dry-run/smoke checks, adapter/contract validators, and planner outputs as current conformance evidence. Per-library runtime conformance requires explicit test or SDK/package harness evidence. |

## Required Response Shape

For capability audits, return these keys so source-owner reviews can compare runs:

- `source_view`: whether the package exposes samples, applications, SDK headers, contracts, helper scripts, and module
  docs.
- `persona_route`: chosen persona, why it matched, and guidance files read.
- `documentation_entrypoints`: files read for documentation exploration.
- `coding_standards`: style and review rules applied to sample/application code.
- `libraries_overview`: SDK/library capabilities, SDK headers, API evidence, package dependencies, and samples relevant
  to library users.
- `services_overview`: service/application capabilities, operator-facing prerequisites, runtime evidence still needed,
  and blocked mutation classes.
- `tools_overview`: package-visible tools, helper scripts, CLI/build/debug entrypoints, and validation commands relevant
  to tool users.
- `capability_coverage`: devices, libraries, modes, and offloads that were measured, source-visible, or require runtime
  verification.
- `host_installation`: source-package or installed-package host evidence, missing prerequisites, package-visible
  validation commands, and blocked host mutation classes.
- `topology_coverage`: host, BlueField, GPU, NIC, PCIe, NUMA, and memory-domain facts, each marked measured,
  source-visible, or requiring runtime verification.
- `lifecycle_coverage`: visible object lifecycle phases and the evidence file for each phase.
- `schema_coverage`: machine-readable contracts, configs, errors, counters, and constraints present in the package.
- `dry_run_commands`: planner or validation commands that do not mutate state.
- `observability_coverage`: health, counters, traces, and resource ownership facts visible without runtime mutation.
- `safety_boundaries`: action classes that require explicit user approval.
- `version_compatibility`: package version and compatibility facts plus any unknowns.
- `conformance_status`: package-smoke, validator, or test evidence plus runtime evidence still needed.

## Safe First Commands

Run the baseline discovery and sample/application audit commands from `getting-started/first-commands.md`. For a named
sample or application, use the planner-only build or source-change command from that file before any build output or
source write.

If the package lacks `tools`, switch to the installed-package fallback in `getting-started/validation.md` and report
missing evidence paths in `unmet_prerequisites`.
