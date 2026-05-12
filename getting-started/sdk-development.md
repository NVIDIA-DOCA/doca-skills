# SDK Development Guidance

Applies to: SDK-facing C/C++ code, samples, applications, and build snippets
Read when: changing source that may be used as SDK reference material
Load next: `getting-started/source-boundaries.md`, `getting-started/pkg-config.md`, `getting-started/troubleshooting.md`, `modules/samples-applications.md`

Prefer examples that teach one DOCA concept at a time. Keep setup, argument parsing, resource creation, and cleanup easy
to inspect, even when production library code would use denser helper layers.

## C And C++ Conventions

- Follow the repository `.clang-format`.
- Preserve neighboring naming and error-handling style.
- Use `doca_error_t` for DOCA API-facing error flow when surrounding code does.
- Keep cleanup paths explicit and easy to audit.
- Log actionable failures in applications and samples with the logging macros already used nearby.

## Meson Guidance

- Keep `meson.build` files tab-indented.
- Use existing option names from `meson_options.txt` instead of inventing local switches for global behavior.
- Do not reorder top-level Meson subdirectories.
- If a sample supports a source package layout, check whether it has a package-specific Meson file before assuming only
  the repository layout exists.

## Dependencies

Use dependencies already declared by the target module. When a new dependency is required, update the matching Meson
dependency file and any package metadata that the existing module pattern requires.

For standalone SDK examples, prefer the package's Meson dependency names instead of private include paths or
repository-only helper libraries. Discover the dependency names from the nearest `meson.build` or the dynamic API
inventory:

```bash
python3 tools/lookup_capability.py --repo-root . --api-index <capability-id>
```

For sample and application build planning, also read the `package_build_files` and `package_dependency_files` fields
returned by the build planner. A nearby `meson.build` is the package-facing staging contract for source package views; a
sample or application `dependencies/meson.build` records the DOCA and driver packages that the package-facing build
checks before entering the target directory. Use those files to report required packages, helper sources, and include
directories before running any local build.

Use these common package anchors only as starting points; the selected `meson.build` and dependency files remain
authoritative:

| SDK area | Common package names to verify first |
| --- | --- |
| Common SDK scaffolding, logging, errors, devices, buffers, and ARGP-based samples | `doca-common`, `doca-argp` |
| DOCA Flow samples and DPDK-backed demo applications | `doca-flow`, `doca-dpdk-bridge`, `doca-argp`, `libdpdk` |
| Security, secure-channel, service-chain, and UPF applications | Start from the selected application `dependencies/meson.build`; common anchors include `doca-flow`, `doca-dpdk-bridge`, `doca-comch`, `doca-apsh`, `doca-telemetry-exporter`, `json-c`, and `libdpdk` |
| DMA and other task-style SDK examples | `doca-dma`, `doca-common`, `doca-argp` |
| Applications with helper libraries or agent-produced code | The `app_doca_depends` and `app_driver_depends` entries from the selected `applications/**/dependencies/meson.build` |

When `meson setup` or `pkg-config` cannot find a DOCA dependency, report it as an unmet prerequisite and show the local
validation command that failed. Do not install packages, edit system paths, or claim the build passed. In source-package
answers, include an `unmet_prerequisites` field when dependencies are absent so the result remains machine-checkable.

For environment diagnosis, start with the baseline discovery and API or library lookup commands in
`getting-started/first-commands.md`, then verify the local SDK installation exposes the selected dependency:

```bash
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

If any command fails, keep the exact missing package name and command stderr in the response.

## Installed Package Fallback

Some users ask from an installed package tree rather than a source package checkout. When `tools/run_agent_task.py` or
`tools/lookup_capability.py` is not present, use the installed SDK surface instead of inventing source-package results.
Start with the install-only discovery fallback in `getting-started/validation.md`, then run pkg-config checks for the
selected dependency:

```bash
pkg-config --modversion <pkg-name>
pkg-config --cflags --libs <pkg-name>
```

For API lookup, cite the installed SDK header path or the `pkg-config --cflags` include path used to verify the symbol.
For sample and application work, cite installed samples under `<prefix>/samples` or `<prefix>/applications` when
present. Do not reference repository-only helpers or package-absent paths in an installed-package answer.

Keep structured comparison fields in the response even when source helper tools are missing:

- `status`
- `library_name`
- `key_functions`
- `required_packages`
- `lifecycle_steps`
- `code_snippet`
- `error_handling_notes`
- `unmet_prerequisites`
- `verification_commands`

Populate `unmet_prerequisites` with the missing `tools` path, absent headers, missing `pkg-config` packages, or skipped
build/runtime commands. Mark verification commands that could not run instead of treating them as passed. Set `status`
to `not_measured`, `blocked`, or `partial` when the answer comes from installed headers but an executable source helper
could not run.

## Core SDK Object Map

Many SDK examples use the same core primitives even when the target library is Flow, DMA, RDMA, Compress, or another
module. Before writing a new example, inspect the SDK headers and nearby samples returned by the API inventory, then map
object lifetimes around these roles:

- `doca_error_t`: status value returned by DOCA APIs. Preserve the first failure when cleanup can also fail.
- `doca_dev` and `doca_devinfo`: discovered device handle and device metadata. Do not hard-code PCI addresses or device
  names in SDK examples.
- `doca_mmap`: memory registration object for buffers that a DOCA context may access.
- `doca_buf_inventory` and `doca_buf`: buffer allocation and buffer handles used by task-based APIs.
- `doca_pe`: progress engine that drives asynchronous task completion.
- `doca_ctx`: common context interface exposed by task-capable libraries.
- `doca_task`: asynchronous operation handle. Configure callbacks, submit work, progress the PE, and release resources
  according to the library sample.

For task lifecycle answers, include the selected library, required package dependencies, the source-backed SDK
functions, and cleanup order. If the current package does not expose the expected symbol, report the missing symbol from
the API inventory rather than substituting an API from memory.
