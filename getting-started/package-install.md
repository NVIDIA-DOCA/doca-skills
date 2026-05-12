# Package Use

Applies to: DOCA AI guidance and helper tools
Read when: deciding how to use this repository with a DOCA SDK source package
Load next: `getting-started/quickstart.md`,
`getting-started/first-commands.md`, `getting-started/validation.md`

This repository is a standalone helper payload. Use it next to a DOCA SDK source package, installed SDK headers, or
package metadata that the local workspace already exposes.

## Recommended Layout

Keep this repository separate from the DOCA SDK source package under analysis. Run helper commands from this repository
and pass the source package root with `--repo-root` when a command needs package evidence.

```bash
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>
```

For sample or application build planning, use planner-only mode first:

```bash
python3 tools/run_agent_task.py \
    --task build-sdk-sample \
    --repo-root <source-package-root> \
    --focus-path <sample-or-application-path>
```

## Evidence Roots

Use `--repo-root .` only when checking this helper repository's bundled contracts and tools. Use
`--repo-root <source-package-root>` for SDK facts from the DOCA source package. `contracts/agent-manifest.json` lists
the helper repository's bundled task and capability contracts.

If the source package has no helper contracts, keep that as a blocker instead of blending helper-repository evidence
with package evidence. For an installed SDK fallback, inspect only files and package metadata that already exist:

```bash
prefix=${DOCA_PREFIX:-/opt/mellanox/doca}
find "$prefix/include" -maxdepth 1 -name 'doca*.h' -print
find "$prefix" -path '*/pkgconfig/doca-*.pc' -print
```

Use those results to name available headers and packages. Do not treat missing helper contracts as permission to install
packages, edit system paths, or guess device capability.

## Activation

Coding agents should start from `AGENTS.md`. Use `llms.txt` as a compact index when a tool wants a short repository map
before loading the root instructions.

No command in this repository should edit global agent settings or write into user home directories. If a local owner
wants editor-specific activation, use the repository-local `AGENTS.md` entrypoint or copy a short local pointer outside
this repository.

## Boundaries

Default helper flows inspect files and report facts. They do not install packages, change devices, configure networking,
write credentials, alter persistent configuration, run traffic, or execute runtime samples. Report those needs as
blockers and ask the local owner for the right package, device, or runtime evidence.
