# Capability Index

Applies to: `NVIDIA-DOCA/doca-skills/capabilities`
Read when: checking which DOCA agent capabilities are ready, partial, or TBD
Load next: `skills/README.md`, `guides/capability-map.md`,
`contracts/agent-manifest.json`, `contracts/capability-catalog.json`

Use this index before choosing a skill. It shows what this helper repository can route today, what needs source-package
evidence, and what remains a planned capability group.

## Status Meanings

- Ready: documented route exists and the agent can return source-backed answers with read-only commands.
- Partial: route exists, but some facts depend on package-visible evidence, hardware access, or a library-specific
  contract that may be absent.
- TBD: named capability group is visible for planning, but no dedicated source-package guide is bundled yet.

## Capability Matrix

| Capability | Status | Start With | Expected Output |
| --- | --- | --- | --- |
| Programming Guide and API reference | Ready | `skills/doca-programming-guide/SKILL.md`; `contracts/capability-catalog.json` | `library_name`, `key_functions`, lifecycle steps, required packages, verification commands, and version mismatch notes. |
| Machine-readable API, config, error, counter, and constraint schemas | Partial | `contracts/agent-manifest.json`; `contracts/schemas/`; `guides/capability-map.md` | Existing task and capability schemas plus explicit gaps for missing library-specific API/config/error/counter schemas. |
| DOCA Services | TBD | `skills/doca-explorer/SKILL.md`; `framework/services-template.md` | `services_overview`, runtime prerequisites, observability hints, blocked service startup or traffic actions. |
| DOCA libs | TBD | `skills/doca-explorer/SKILL.md`; `framework/libs-template.md` | `libraries_overview`, SDK headers, dependencies, sample evidence, and missing library-guide gaps. |
| DOCA Tools | TBD | `skills/doca-explorer/SKILL.md`; `guides/capability-map.md` | `tools_overview`, package-visible commands, approval-gated actions, output artifacts, and failure interpretation. |
| DOCA-Host installation | Ready | `skills/doca-ai-runner/SKILL.md`; `getting-started/package-install.md` | `host_installation`, package metadata, installed-prefix fallback, blocked host mutations, and next safe command. |
| Device capability discovery | Ready | `skills/doca-discover-environment/SKILL.md`; `contracts/tasks/discover-doca-environment.yaml` | `source_version`, `available_capabilities`, measured sensors, not-measured facts, and blockers. |
| Topology discovery | Partial | `skills/doca-discover-environment/SKILL.md`; `guides/capability-map.md` | Host, BlueField, NIC, GPU, PCIe, NUMA, representor, queue, and memory-domain facts marked measured, source-visible, or not measured. |
| Standard object lifecycle | Partial | `skills/doca-programming-guide/SKILL.md`; `skills/doca-explorer/SKILL.md` | Create, configure, validate, start, query, stop, and destroy phases when headers or samples expose them; gaps when evidence is incomplete. |
| Unified error taxonomy with recovery hints | Partial | `guides/capability-map.md`; `getting-started/troubleshooting.md`; task `structured_errors` | Documented errors, observed `doca_error_t` handling, recovery hints, and missing taxonomy gaps. |
| Structured observability | Partial | `skills/doca-explorer/SKILL.md`; `guides/capability-map.md` | Logging, health, counters, traces, queue state, and resource ownership only when visible without runtime mutation. |
| Permission and safety model for agent-driven actions | Ready | `skills/doca-user-rules/SKILL.md`; `skills/doca-ai-runner/SKILL.md` | Blocked actions, approval classes, read-only defaults, and exact next safe command. |
| Version and compatibility | Ready | `skills/doca-discover-environment/SKILL.md`; `getting-started/pkg-config.md` | Source version, package metadata, pkg-config versions, compatibility notes, and unknowns. |

## User Flow

1. Read this index and choose the matching capability row.
2. Load the listed skill and contract files.
3. Run only read-only evidence commands unless the local owner approves a build, runtime, device, network, credential,
   or persistent configuration action.
4. Return the expected output fields and mark unavailable facts as gaps.
