# DOCA Flow Source-Package Guide Example

Applies to: `libs/doca_flow/**`, `samples/doca_flow/**`, installed DOCA Flow headers and pkg-config metadata
Read when: drafting the first library guide for DOCA Flow users
Load next: `framework/libs-template.md`, `guides/capability-map.md`, `contracts/agent-manifest.json`

Use this as the first example shape for a DOCA Framework library guide. Keep the guide evidence-based: inspect the
source package or installed SDK metadata before naming functions, dependencies, samples, or runtime prerequisites.

## Scope

- `framework_area`: `libs`
- `library_name`: `doca_flow`
- `primary_persona`: `SDK library developer`
- `source_paths`: `libs/doca_flow/**`, `samples/doca_flow/**`, `tools/flow_tune/**` when present
- `installed_fallback`: `$DOCA_PREFIX/include`, `doca-flow.pc`, and `pkg-config doca-flow`
- `out_of_scope`: runtime port setup, traffic, hugepages, device mode changes, firmware changes, and package
  installation

## Source Evidence Procedure

Use `rg` when available; otherwise use `grep`.

```bash
sed -n '1p' VERSION 2>/dev/null || true
find libs/doca_flow -path '*/include/public/*.h' -print 2>/dev/null
grep -R "doca_flow_init\\|doca_flow_pipe_create\\|doca_flow_pipe_add_entry" libs/doca_flow 2>/dev/null
find samples/doca_flow -maxdepth 2 -name meson.build -print 2>/dev/null
pkg-config --modversion doca-flow
pkg-config --cflags --libs doca-flow
```

For an installed-only view, use package-owned metadata and installed headers:

```bash
prefix=${DOCA_PREFIX:-/opt/mellanox/doca}
find "$prefix/include" -name 'doca_flow*.h' -print 2>/dev/null
grep -R "doca_flow_init\\|doca_flow_pipe_create\\|doca_flow_pipe_add_entry" "$prefix/include" 2>/dev/null
pkg-config --modversion doca-flow
pkg-config --cflags --libs doca-flow
```

## Expected Answer Shape

- `source_version`: version from `VERSION` or `pkg-config --modversion`.
- `available_capabilities`: Flow source paths, headers, contracts, samples, and installed metadata found.
- `experimental_api_summary`: APIs marked by local headers or explicitly `not_measured`.
- `library_name`: `doca_flow`.
- `key_functions`: functions proven by headers or samples, such as init, port start, pipe creation, entry add,
  process/status, and cleanup APIs.
- `required_packages`: pkg-config package names proven by local metadata.
- `unmet_prerequisites`: missing headers, missing pkg-config packages, absent samples, unavailable devices, or runtime
  facts not measured.
- `verification_commands`: read-only commands used plus any build-only Meson/Ninja command that needs local build-output
  approval.

## Safety Rules

- Do not run Flow samples, start traffic, configure ports, change hugepages, or mutate device/network state without
  explicit local approval.
- Do not invent Flow function names; report missing headers or samples when the current view cannot prove an API.
- Treat source presence as API evidence only. Runtime readiness requires a separate environment discovery step.
- Prefer source-package files and installed metadata over memory or online summaries.
