# Package Use

Applies to: DOCA AI guidance and source-package-tool procedures
Read when: deciding how to use this repository with a DOCA SDK source package
Load next: `getting-started/quickstart.md`,
`getting-started/first-commands.md`, `getting-started/validation.md`

This repository is a standalone helper payload. Use it next to a DOCA SDK source package, installed SDK headers, or
package metadata that the local workspace already exposes.

## Recommended Layout

Keep this repository separate from the DOCA SDK source package under analysis. Run source-evidence commands from this
repository or against the source package root when a command needs package evidence.

```bash
find contracts -maxdepth 2 -type f \( -name '*.json' -o -name '*.yaml' \) -print
find <source-package-root> -maxdepth 1 -name VERSION -print
pkg-config --list-all 2>/dev/null | grep '^doca-' || true
```

For sample or application build planning, use planner-only mode first:

```bash
find <sample-or-application-path> -maxdepth 2 \( -name meson.build -o -name meson.build \) -print
pkg-config --print-errors --exists <pkg-name>
```

## Evidence Roots

Use this helper repository only when checking bundled contracts. Use `<source-package-root>` in evidence commands for
SDK facts from the DOCA source package. `contracts/agent-manifest.json` lists the helper repository's bundled task and
capability contracts.

If the source package has no contracts, keep that as a blocker instead of blending helper-repository evidence with
package evidence. For an installed SDK fallback, inspect only files and package metadata that already exist:

```bash
prefix=${DOCA_PREFIX:-/opt/mellanox/doca}
find "$prefix/include" -maxdepth 1 -name 'doca*.h' -print
find "$prefix" -path '*/pkgconfig/doca-*.pc' -print
```

Use those results to name available headers and packages. Do not treat missing helper contracts as permission to install
packages, edit system paths, or guess device capability.

## Binary Context Maps

If a binary package owner provides a passive AI context bundle, use its install map as the path evidence source. The map
should conform to `contracts/schemas/binary-context-install-map.schema.json` and identify package owned context roots,
read-only source-package tools, adapter templates, validation commands, and blocked mutation classes. See
`examples/binary-context-install-map.example.json` for the package-visible shape without treating the example paths as
an install decision.

Missing or invalid context maps are blockers. Do not scan arbitrary system paths, write global agent settings, or create
workspace adapters unless the user explicitly runs an export command for a chosen workspace.

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
