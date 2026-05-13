# Online Documentation Pointers

Applies to: DOCA SDK source packages and source-package safe AI guidance
Read when: an agent needs broader context than the packaged source files provide
Load next: `getting-started/sdk-development.md`, `contracts/README.md`

Use these documentation entry points as redirects, not as a replacement for source inspection. Prefer the local source
package for exact file layout, build options, and available contracts; use online docs to fill conceptual background
when network access is available.

| Topic | Documentation source | Agent use |
| --- | --- | --- |
| DOCA SDK documentation index | <https://docs.nvidia.com/doca/sdk/index.html> | Start here for the current SDK documentation set and release context. |
| DOCA overview | <https://docs.nvidia.com/doca/sdk/doca-overview/index.html> | Use for high-level structure: libraries, applications, tools, services, and API references. |
| DOCA programming guide | <https://docs.nvidia.com/doca/sdk/doca-programming-guide/index.html> | Use with `skills/doca-programming-guide/SKILL.md` for SDK architecture, compatibility, best-practice, library, utility, and driver routing before selecting framework-specific docs. |
| DOCA SDK architecture | <https://docs.nvidia.com/doca/sdk/doca-sdk-architecture/index.html> | Use for the device, memory-management, execution, task/event, and progress-engine model; verify local headers and samples before giving API-level guidance. |
| DOCA compatibility policy | <https://docs.nvidia.com/doca/sdk/doca-compatibility-policy/index.html> | Use for source, binary, behavioral, backward, and forward compatibility context; report local `VERSION` and package metadata before applying it to the current package. |
| DOCA capability checking | <https://docs.nvidia.com/doca/sdk/capability-checking/index.html> | Use for device, library, and core capability-check patterns; verify matching `doca_*_cap_*` symbols in local SDK headers. |
| DOCA debuggability | <https://docs.nvidia.com/doca/sdk/debuggability/index.html> | Use for return-value and logging concepts; verify `doca_error_t`, cleanup, and `doca_log` usage in local source. |
| DOCA Arg Parser | <https://docs.nvidia.com/doca/sdk/doca-arg-parser/index.html> | Use for CLI and JSON configuration concepts; verify `doca-argp` package metadata and local ARGP usage before emitting examples. |
| DOCA Flow | <https://docs.nvidia.com/doca/sdk/doca-flow/index.html> | Use for Flow port setup, device or representor selection, actions memory, and lifecycle concepts. |
| DOCA DPA | <https://docs.nvidia.com/doca/sdk/doca-dpa/index.html> | Use for DPA host/device split-build flow, DPACC context, and DPA annotation concepts. |

## Source-First Rules

- Treat online docs as versioned context. If the local `VERSION` file and online docs disagree, report the mismatch
  before using online guidance.
- Do not convert sample PCI addresses, interface names, IB device names, or representor names from online docs into
  local environment facts.
- For Flow actions, check whether actions memory must be configured before creating entries.
- For DPA code, check the local sample build files before assuming a standard host-only compiler flow.
- If online docs are unavailable, continue with local source, packaged AI contracts, and explicit blockers instead of
  inventing missing facts.
