# DOCA Skills Navigation

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: deciding whether a source package needs module-specific guidance
Load next: `modules/module-template.md`,
`guides/capability-map.md`, `contracts/agent-manifest.json`

This directory contains only reusable module guidance structure. It should not ship one module as the example because
that makes the template look owned by that module. Copy `module-template.md` when a source package or SDK area needs its
own module guide.

Every module guide should use the same persona split:

- `libraries_overview`: SDK and library users, headers, APIs, Meson, and pkg-config evidence.
- `services_overview`: service or application operators, runtime prerequisites, and blocked mutations.
- `tools_overview`: tool users, CLI/build/debug helpers, and validation commands.

Use `contracts/agent-manifest.json` and `contracts/capability-catalog.json` to see the contract surface shipped in this
repository. Use source evidence only as narrow references back to SDK source packages, SDK headers, Meson metadata,
package metadata, samples, or applications.

## Module Guide Checklist

| Need | Fill In |
| --- | --- |
| Module scope | Exact source package, SDK header, sample, application, or package metadata paths covered by the guide. |
| Library persona | API/header/dependency facts for SDK and library users. |
| Service persona | Runtime prerequisites, operator-visible knobs, and blocked state changes. |
| Tool persona | CLI, build, debug, and validation entrypoints. |
| Evidence | Source-backed files or commands that prove each claim. |
| Safety | Commands or state changes agents must not run without local owner approval. |

If a task requires module-specific guidance that is not present here, state that no module guide is packaged yet and ask
for the relevant documentation link or SDK source package evidence.
