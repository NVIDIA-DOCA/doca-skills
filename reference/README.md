# DOCA Reference Guidance

Applies to: DOCA source-package reference and style guidance
Read when: an agent needs common safety, editing, or C/C++ style rules
Load next: `reference/c-cpp-style.md`, `guides/persona-routing.md`, `modules/README.md`

This folder contains common rules for agents that work with DOCA SDK source packages or installed DOCA prefixes. Use it
after choosing the requester type with `guides/persona-routing.md`.

## How To Use

- Load `reference/c-cpp-style.md` before writing or reviewing C/C++ examples.
- Use `modules/README.md` when a library, service, or tool needs focused local guidance.
- Use `guides/capability-map.md` when the answer must compare libraries, services, tools, setup facts, and safety
  boundaries.
- Use helper commands from `tools/` only as documented by the selected skill or task contract.

## Boundaries

- Treat the current source package or installed prefix as the evidence source.
- Keep library, service, and tool answers separated unless the user asks for an end-to-end workflow.
- Report missing headers, packages, helper commands, devices, sensors, or approvals as unmet prerequisites.
- Do not install packages, mutate devices, change networking, write credentials, alter persistent configuration, run
  traffic, or execute runtime samples unless the local owner explicitly approves that action class.

## Validation

For documentation changes, prefer `git diff --check` plus the package-local helper checks named by the relevant skill.
For source or build changes, report the smallest package-local validation command that covers the touched file and state
any missing prerequisite clearly.
