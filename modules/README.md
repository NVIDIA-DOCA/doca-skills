# DOCA Skills Navigation

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: deciding whether a source package needs module-specific guidance
Load next: `modules/library-template.md`,
`modules/service-template.md`, `modules/tool-template.md`, `guides/capability-map.md`, `contracts/agent-manifest.json`

This directory contains only reusable module guidance structure. It should not ship one module as the example because
that makes the template look owned by that module. Copy the template that matches the released product shape: library,
service, or tool.

Use `guides/persona-routing.md` before choosing a template. Use the template that matches the primary user:

- `library-template.md`: SDK and library users, headers, APIs, Meson, and pkg-config evidence.
- `service-template.md`: service or application operators, runtime prerequisites, and blocked mutations.
- `tool-template.md`: tool users, CLI/build/debug helpers, and validation commands.

Use `contracts/agent-manifest.json` and `contracts/capability-catalog.json` to see the contract surface shipped in this
repository. Use source evidence only as narrow references back to SDK source packages, SDK headers, Meson metadata,
package metadata, samples, or applications.

## Module Guide Checklist

| Need | Fill In |
| --- | --- |
| Module scope | Exact source package, SDK header, sample, application, or package metadata paths covered by the guide. |
| Library template | API/header/dependency facts for SDK and library users. |
| Service template | Runtime prerequisites, operator-visible knobs, and blocked state changes. |
| Tool template | CLI, build, debug, and validation entrypoints. |
| Evidence | Source-backed files or commands that prove each claim. |
| Safety | Commands or state changes agents must not run without local owner approval. |

If a task requires module-specific guidance that is not present here, state that no module guide is packaged yet and ask
for the relevant documentation link or SDK source package evidence.
