# Common DOCA Guidance

Applies to: whole repository
Read when: any AI assistant modifies, reviews, or explains DOCA code
Load next: `reference/c-cpp-style.md` for C/C++ work; `modules/README.md` for path-specific work

DOCA is a Meson-based C/C++ repository with SDK libraries, tools, samples, applications, services, extensions, and
verification code. Keep edits scoped to the subsystem requested by the user and follow existing local patterns before
introducing new abstractions.

## Repository Map

- `libs/`: DOCA SDK libraries and their unit tests.
- `tools/`: installed and developer tools built with the SDK.
- `samples/`: sample programs intended to demonstrate SDK usage.
- `applications/`: larger applications built from DOCA components.
- `services/`: service components that are disabled by default in the SDK build.
- `extensions/`: optional and add-on libraries, tools, and services.
- `system_tests/`: integration and system-level test assets.
- `verification/`: verification frameworks and test suites.
- `devtools/`: repository automation, coding-style hooks, CI helpers, and MCP servers.
- `configs/`: Meson feature/profile configuration and package metadata.

## Build System

The top-level `meson.build` has an intentional subdirectory order: `configs`, `third_party`, `common`, `libs`, `tools`,
`samples`, `applications`, `extensions`, `services`, `system_tests`, then `verification`. Do not reorder these entries
unless the change is explicitly about build graph ordering.

Several directories are optional during package builds. `extensions/`, `services/`, `system_tests/`, and `verification/`
may be absent or disabled in some source layouts, so agents should not assume they are always available in
release/package contexts.

Meson files in this repository use tabs for indentation. The pre-commit hook `meson-tabs-only` enforces this for
`meson.build` files.

## Version And Package Metadata

Use local metadata before relying on memory or online documentation:

- `VERSION` is the source-package version visible to local agents.
- Top-level and module `meson.build` files define source layout, enabled subdirectories, and dependency names.
- `meson.build.public` files describe package-facing sample or application builds when they differ from the full
  repository layout.
- `configs/` contains build profiles and package metadata for repository builds.
- `python3 tools/run_agent_task.py --task discover-doca-environment --repo-root .` returns a read-only JSON discovery
  result that should anchor user-facing environment answers.

If local metadata and online documentation disagree, treat the installed or source package as authoritative for what the
user can build now. Use online documentation only to enrich context, and call out version differences when they matter.

## Edit Discipline

- Prefer the existing local API, naming style, and error handling pattern.
- Keep SDK API changes narrow and update all call sites when signatures move.
- Do not edit vendored code under `third_party/` unless the task explicitly targets that vendor copy.
- Avoid derived-file churn; update the owning source instead.
- Keep documentation factual and path-specific; avoid speculative claims about unsupported platforms or package
  behavior.

## Validation Defaults

For docs-only changes, run `git diff --check` and the relevant pre-commit or `prek` file-level hooks. For code changes,
add the smallest meaningful compile, unit, or script validation that covers the touched subsystem.
