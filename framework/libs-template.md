# DOCA Framework Libs Template

Applies to: `<library-source-package-area>`
Read when: an agent needs SDK library, header, API, dependency, or sample context for `<library-or-sdk-area>`
Load next: `guides/capability-map.md`, `contracts/agent-manifest.json`

Copy this file when a source package needs focused guidance for SDK library users. Replace placeholders with
source-backed evidence from headers, Meson files, package metadata, samples, applications, and read-only installed tool
output.

## Scope

- `framework_area`: `libs`
- `guide_id`: `<short-library-id>`
- `primary_persona`: `SDK library developer`
- `library_paths`: `<libs/<name> paths or installed source-package paths>`
- `sdk_headers`: `<headers agents may inspect or cite>`
- `sample_paths`: `<samples or applications that exercise the APIs>`
- `package_metadata`: `<meson.build, pkg-config, or package metadata paths>`
- `out_of_scope`: `<paths, APIs, runtime modes, or commands this guide does not cover>`

## libraries_overview

- `library_name`: `<SDK library name or package-facing component name>`
- `user_goals`: `<API lookup, lifecycle explanation, dependency mapping, or sample usage>`
- `headers`: `<header paths that prove available APIs>`
- `key_apis`: `<functions, structs, lifecycle calls, callback types, and stability notes>`
- `dependencies`: `<pkg-config names, Meson dependency names, package names, and nearby dependency files>`
- `build_evidence`: `<Meson files, package metadata, source commands, and sample references>`
- `lifecycle_notes`: `<init, configure, submit/progress, callback/error handling, cleanup>`
- `validation_commands`: `<read-only discovery, lookup, or build-planning commands>`
- `unmet_prerequisites`: `<headers, packages, installed tools, devices, or build outputs not proven locally>`

## Evidence Rules

- Cite package-local headers and Meson/package metadata before online or memory-based facts.
- Optimize answers for developers writing or reviewing source that calls the SDK APIs.
- Inspect contracts, SDK headers, Meson files, and `pkg-config` metadata before naming APIs or dependencies.
- Keep source evidence separate from runtime availability; source presence does not prove a device or offload is usable.
- Do not invent API names, package names, dependency names, sample paths, devices, ports, or topology.
- If the requested library is absent, report the missing paths and stop before producing pseudo-code with unverified
  APIs.
