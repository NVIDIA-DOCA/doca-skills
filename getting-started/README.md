# Getting Started

Applies to: DOCA AI guidance and source-package-tool procedures
Read when: starting a DOCA source-package task with a coding agent
Load next: `getting-started/quickstart.md`,
`getting-started/first-commands.md`, `skills/doca-user-rules/SKILL.md`, `skills/doca-ai-runner/SKILL.md`,
`examples/README.md`, `guides/capability-map.md`

This directory contains the starting points for agent-assisted DOCA SDK work. Use this repository for guidance, portable
skills, and helper tooling. Use the DOCA SDK source package passed with `--repo-root <source-package-root>` for SDK
version, header, dependency, sample, application, device, and topology facts.

## Two Modes

- Helper repository mode: run commands with `--repo-root .` only to inspect the bundled contract surface and verify the
  evidence procedures.
- SDK source package mode: keep this repository next to the SDK source package and pass the SDK source path with
  `--repo-root <source-package-root>`.

Do not blend the two evidence roots. If the SDK source package lacks helper contracts or expected metadata, report the
gap instead of using this repository as a substitute for SDK facts.

## Recommended Order

1. Read `quickstart.md`.
2. Run the safe first commands in `first-commands.md`.
3. Use `../examples/README.md` to see prompt examples and expected agent flow diagrams before adapting a prompt for your
   source package.
4. Use `building-samples.md`, `pkg-config.md`, `using-pkg-config.md`, `sdk-development.md`, and `troubleshooting.md` for
   SDK build or dependency questions.
5. Use `package-install.md` when using this helper repository next to an SDK source package, or when only installed SDK
   headers are available.
6. Use `validation.md` to keep source-package facts separate from runtime or device checks.
7. Use `../troubleshooting/build-issues.md` when a build failure needs a focused troubleshooting entrypoint.
8. Use `online-docs.md` only as conceptual context; local package evidence remains authoritative for what can be built
   now.

## Safety

Default helper flows are read-only or planner-only. Report missing files, missing packages, missing devices, or missing
utilities as blockers. Do not install packages, change devices, configure networking, write credentials, change
persistent configuration, run traffic, or execute runtime samples as a side effect of answering a documentation or
build-planning question.
