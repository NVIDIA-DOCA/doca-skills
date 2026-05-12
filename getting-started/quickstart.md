# Quickstart

Applies to: agents using a DOCA SDK source package
Read when: preparing an agent to inspect, build, or modify DOCA sources from a packaged source tree
Load next: `llms.txt`, `getting-started/README.md`, `getting-started/first-commands.md`, `getting-started/package-install.md`, `getting-started/validation.md`, `skills/doca-user-rules/SKILL.md`, `skills/doca-ai-runner/SKILL.md`, `skills/doca-programming-guide/SKILL.md`

This quickstart is the package-facing entry point for using the packaged DOCA AI guidance with coding agents. It assumes
the user has a DOCA source package that already contains the root adapter files and `top-level guidance directories`.

## What The Package Provides

An agent-ready source package includes:

- Root adapter files such as `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `JULES.md`, `SKILLS.md`, `llms.txt`,
  `.github/copilot-instructions.md`, `.windsurfrules`, `.clinerules`, and `.roo/rules/doca.md`.
- Source-package safe guidance under `getting-started/`, reference coding rules under `reference/`, and module guidance
  under `modules/`.
- Filtered machine-readable contracts under `contracts/`.
- Standard-library Python helpers under `tools/`.
- Portable skills under `skills/` for base user rules, read-only discovery, Programming Guide enrichment, DOCA
  capability exploration, build planning, and the common `doca-ai-runner`; when the filesystem supports it, matching
  `.agents/skills/<name>` adapters.

The package is self-contained for source guidance, read-only discovery, and planning. Device credentials and global
agent configuration are only relevant for user-approved runtime workflows that explicitly require them.

## Requirements

Use the package from its source root. The read-only discovery commands require only Python 3 from the standard library.
Build planning and validation can inspect source without installing packages. Actual local builds require the normal SDK
build tools and dependencies that the package source declares, such as Meson, Ninja, `pkg-config`, a compiler toolchain,
and the relevant DOCA development packages.

Agents must not install system packages, change network or device state, edit global IDE configuration, write into
`$HOME`, or run runtime traffic/device commands unless the local owner explicitly approves that class of action.

## First Ten Minutes

Start at the source package root and run the baseline source-package discovery commands in
`getting-started/first-commands.md` to verify what the package exposes.

For SDK or API questions, inspect the package-local capability before writing guidance or code by using the API or
library lookup commands in that file.

For samples or application capability questions, load the DOCA capability map and report source-package evidence
together with runtime or package metadata still needed. Use the sample or application audit commands in
`getting-started/first-commands.md`.

The expected answer should include documentation entrypoints, coding standards, libraries/services/tools overviews,
capability and topology coverage, lifecycle/schema coverage, dry-run commands, observability coverage, safety
boundaries, version facts, and conformance gaps. Use `guides/capability-map.md` and `skills/doca-explorer/SKILL.md` for
the exact fields.

For build requests, start with planner-only mode. It reports target paths, nearby build files, output directories,
commands, and unmet prerequisites without creating build output. Use the package-build planner command in
`getting-started/first-commands.md`.

If the local owner approves build output, run only the executor command and build directory reported by the planner, or
the approval-gated local build form in `getting-started/first-commands.md`.

For source-change requests, use only task IDs listed by the current source package manifest. If no source-change task is
present, inspect and validate changes through the local source owner's normal review flow.

## Agent Prompt Template

Users can give this prompt to a coding agent from the source root:

```text
Use the packaged DOCA AI guidance in this source tree. Read llms.txt or the
root adapter, then getting-started/quickstart.md,
getting-started/first-commands.md, and
skills/doca-user-rules/SKILL.md. Before suggesting runtime commands or
code changes, use skills/doca-discover-environment/SKILL.md, run
read-only discovery, report source_version, available_capabilities, and
experimental_api_summary, and state any unmet prerequisites instead of
installing packages or changing device state.
```

For API-specific work, add:

```text
Use lookup_capability.py --api-index for the relevant capability before naming
SDK headers, functions, Meson dependencies, or sample references.
Use skills/doca-programming-guide/SKILL.md when Programming
Guide context is needed, and report local source/package evidence before
applying online documentation to this package.
```

## Self-Check

After unpacking the source package, verify these points before asking an agent to build, explain, or modify DOCA code:

- The source root contains `llms.txt` plus the adapter files your agent already knows how to read, such as `AGENTS.md`,
  `CLAUDE.md`, `GEMINI.md`, `JULES.md`, or `SKILLS.md`.
- `package-info.json` reports the package manifest when the source view was produced by the AI docs package tool.
- `run_agent_task.py --task discover-doca-environment` returns structured source facts and does not mutate the system.
- `lookup_capability.py --api-index` reports SDK headers, exported symbols, package dependencies, and sample references
  from this source package.
- Planner-only build commands report next steps and blockers before creating build output.
- Source packages with samples or applications can still produce a structured capability audit through
  `skills/doca-explorer/SKILL.md`; missing library source, topology sensors, runtime counters, or conformance tests
  should appear as explicit gaps rather than guessed facts.
