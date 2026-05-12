# Capability API Lookup

Applies to: SDK API, header, and dependency lookup with `doca-skills`
Read when: the user asks which headers, functions, packages, or module persona applies
Load next: `../guides/capability-map.md`, `../modules/README.md`, `../skills/doca-explorer/SKILL.md`

## Prompt

```text
I need to use <capability-id>. Identify the SDK headers, functions, package
dependencies, examples, and whether this is mainly a library, service, or tool
task. Use local source evidence before naming APIs.
```

## Expected Agent Flow

```mermaid
flowchart TD
    prompt["Prompt asks for capability evidence"]
    catalog["Read capability catalog"]
    lookup["Run lookup_capability with --api-index"]
    modules["Open module templates"]
    split["Split answer into libraries, services, tools"]
    checks["Name missing source or runtime evidence"]
    answer["Return cited APIs, deps, persona, blockers"]

    prompt --> catalog
    catalog --> lookup
    lookup --> modules
    modules --> split
    split --> checks
    checks --> answer
```

## Command Shape

```bash
python3 tools/lookup_capability.py --repo-root <source-package-root> --api-index <capability-id>
```

## Expected Answer Shape

- Capability ID and source package path.
- SDK headers and functions found by local source inspection.
- Package or pkg-config dependency evidence.
- `libraries_overview`, `services_overview`, and `tools_overview` when relevant.
- Version, device, topology, or runtime facts that remain unknown.
- Next safe command for deeper source lookup or build planning.
