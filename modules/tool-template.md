# Tool Module Template

Applies to: `<tool-source-package-area>`
Read when: an agent needs CLI, build, debug, validation, or helper-tool context for `<tool-or-workflow>`
Load next: `guides/capability-map.md`, `contracts/agent-manifest.json`

Copy this file when a source package needs focused guidance for tool users. Replace placeholders with source-backed
evidence from tool source, scripts, Meson files, package metadata, docs, tests, or local helper output.

## Scope

- `module_id`: `<short-tool-id>`
- `primary_persona`: `tool workflow user`
- `tool_paths`: `<tools, scripts, helper modules, or package paths>`
- `cli_entrypoints`: `<commands, binaries, scripts, or tool docs>`
- `package_metadata`: `<Meson, pkg-config, dependency, or package metadata paths>`
- `out_of_scope`: `<runtime modes, write actions, devices, or commands this guide does not cover>`

## tools_overview

- `tool_name`: `<CLI, helper, build, debug, or validation tool name>`
- `user_goals`: `<command selection, argument mapping, output interpretation, or troubleshooting>`
- `cli_tools`: `<commands, arguments, help output, scripts, or installed binaries>`
- `build_tools`: `<Meson, Ninja, pkg-config, compiler, package, or source helper dependencies>`
- `debug_tools`: `<log, trace, status, validation, or troubleshooting helpers>`
- `safe_commands`: `<read-only or planner-only commands agents may run or suggest>`
- `approval_gated_commands`:
  `<commands that write files, run traffic, build outputs, install packages, or mutate state>`
- `output_artifacts`: `<files, directories, logs, reports, or build outputs produced when approved>`
- `unmet_prerequisites`: `<missing commands, packages, source paths, build dirs, or runtime facts>`

## Evidence Rules

- Cite package-local tool source, scripts, help output, Meson files, package metadata, and tests before online or
  memory-based facts.
- Optimize answers for users who need exact commands, inputs, outputs, and failure interpretation.
- Keep read-only commands separate from commands that create build output, write files, install packages, or mutate
  runtime state.
- Preserve documented command-line behavior unless the user explicitly asks to change it.
- Do not invent flags, output paths, package names, environment variables, or build targets.
- If a tool is absent from the source package, report the missing path and closest safe package-local alternative.
