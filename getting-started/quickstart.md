# Quickstart

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: starting a first DOCA SDK task with this helper payload
Load next: `skills/README.md`, `contracts/agent-manifest.json`,
`skills/doca-task-router/SKILL.md`

This page keeps the first release small: one workflow, one knowledge map, three skills, and read-only evidence commands.

## Choose A Skill

| Need | Skill |
| --- | --- |
| Programming Guide, API, lifecycle, dependency, or DOCA Flow lookup | `skills/doca-programming-guide/SKILL.md` |
| Version, source layout, pkg-config, package, device, or topology discovery | `skills/doca-discover-environment/SKILL.md` |
| Contract routing, safe command selection, or SDK sample build planning | `skills/doca-task-router/SKILL.md` |

## Standard Workflow

1. Keep this helper repository separate from `<source-package-root>`.
2. Read `contracts/agent-manifest.json` and choose a listed task or capability.
3. Run the smallest read-only evidence command that answers the question.
4. Prefer source-package evidence over online examples for APIs, paths, and build dependencies.
5. Report missing files, tools, sensors, devices, or approvals as blockers.
6. Give one exact next command that remains inside the approved action class.

## Install And Dependencies

This payload does not install DOCA. Use it beside a DOCA SDK source package or an already installed DOCA SDK. Before
answering build or API questions, measure what is present:

```bash
find <source-package-root> -maxdepth 1 -name VERSION -print
find <source-package-root> -name meson.build -print | head
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For device and topology inventory, use available read-only probes:

```bash
lspci -Dnn | grep -Ei "nvidia|mellanox|bluefield|connectx"
ip -br link
ip -d link show
devlink dev show
devlink port show
devlink dev eswitch show
rdma dev show
rdma link show
ibv_devinfo -v
nvidia-smi topo -m
```

If the task requires a build, start with planning. Do not create build directories, install dependencies, or run runtime
samples unless the user grants that action class.

```bash
find <sample-or-application-path> -maxdepth 2 -name meson.build -print
pkg-config --print-errors --exists <pkg-name>
```

## Coding Guidelines

When the answer includes code guidance:

- Use the SDK headers and sample sources from `<source-package-root>`.
- Check lifecycle order in local headers, Meson files, samples, and the Programming Guide before writing snippets.
- Use `doca_error_t` paths and cleanup steps that are visible in local source.
- Do not invent PCI addresses, representors, interfaces, queue counts, firmware versions, package versions, or topology.
- Treat runtime, device, network, credential, persistent configuration, traffic, and package-manager changes as
  approval-gated.

## DOCA Framework Map

Use this compact map before selecting files:

| Area | Evidence To Inspect |
| --- | --- |
| Services | Service source, application entrypoints, Meson dependencies, config files, and service logs named by the user. |
| Libs | `libs/*/include/public`, matching implementation files, samples, pkg-config metadata, and lifecycle docs. |
| Tools | Tool source, CLI argument parsing, config schema, output examples, and pkg-config metadata. |
| Samples and applications | The named sample/app directory, nearby `meson.build`, dependency files, common helpers, and README files. |

DOCA Flow work should start with local `doca-flow` headers, Flow samples, Meson dependencies, and pkg-config metadata,
then use the DOCA Flow documentation only for conceptual checks.

## Troubleshooting

For build failures:

```bash
pkg-config --print-errors --exists <pkg-name>
pkg-config --cflags --libs <pkg-name>
find <source-package-root> -name meson.build -print | grep '<sample-or-lib-name>'
```

For API or lifecycle confusion:

```bash
grep -R "<symbol-or-topic>" <source-package-root>/libs/*/include/public 2>/dev/null
grep -R "<symbol-or-topic>" <source-package-root>/samples <source-package-root>/applications 2>/dev/null
```

For traces, counters, or logs, report what file or command would provide the evidence and whether approval is needed
before running it. Do not treat an example trace as a local fact.

## Documentation Links

Use online docs only as secondary context after checking local source evidence:

| Topic | Link |
| --- | --- |
| DOCA SDK docs | <https://docs.nvidia.com/doca/sdk/index.html> |
| DOCA overview | <https://docs.nvidia.com/doca/sdk/doca-overview/index.html> |
| DOCA Programming Guide | <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> |
| DOCA SDK architecture | <https://docs.nvidia.com/doca/sdk/doca-sdk-architecture/index.html> |
| DOCA capability checking | <https://docs.nvidia.com/doca/sdk/capability-checking/index.html> |
| DOCA debuggability | <https://docs.nvidia.com/doca/sdk/debuggability/index.html> |
| DOCA Flow | <https://docs.nvidia.com/doca/sdk/doca-flow/index.html> |

If an online doc conflicts with local source, report `version_mismatch` and prefer local source for commands, APIs,
dependencies, and file paths.
