# Getting Started

Applies to: DOCA AI guidance and helper tools
Read when: starting a DOCA source-package task with a coding agent
Load next: `getting-started/quickstart.md`,
`getting-started/first-commands.md`, `skills/doca-user-rules/SKILL.md`, `skills/doca-ai-runner/SKILL.md`,
`guides/capability-map.md`

This directory contains the starting points for agent-assisted DOCA SDK work. Use local source-package files, package
metadata, SDK headers, and the tool outputs in this repository as the evidence for answers.

## Recommended Order

1. Read `quickstart.md`.
2. Run the safe first commands in `first-commands.md`.
3. Use `building-samples.md`, `pkg-config.md`, `using-pkg-config.md`, `sdk-development.md`, and `troubleshooting.md` for
   SDK build or dependency questions.
4. Use `package-install.md` when this helper repository is separate from the source package, or when only installed SDK
   headers are available.
5. Use `validation.md` to keep source-package facts separate from runtime or device checks.
6. Use `../troubleshooting/build-issues.md` when a build failure needs a focused troubleshooting entrypoint.
7. Use `online-docs.md` only as conceptual context; local package evidence remains authoritative for what can be built
   now.

## Safety

Default helper flows are read-only or planner-only. Report missing files, missing packages, missing devices, or missing
utilities as blockers. Do not install packages, change devices, configure networking, write credentials, change
persistent configuration, run traffic, or execute runtime samples as a side effect of answering a documentation or
build-planning question.
