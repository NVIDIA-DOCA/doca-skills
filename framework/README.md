# DOCA Skills Framework Navigation

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: deciding whether a source package needs DOCA Framework guidance
Load next: `framework/libs-template.md`,
`framework/services-template.md`, `framework/drivers-template.md`, `framework/examples/doca-flow-source-guide.md`,
`guides/capability-map.md`, `contracts/agent-manifest.json`

This directory contains reusable DOCA Framework guidance structure. Copy the template that matches the released product
shape: libs, services, or drivers. Use the DOCA Flow example as a concrete library guide shape when a source package
needs one worked example.

Use `guides/persona-routing.md` before choosing a template. Use the template that matches the primary user:

- `libs-template.md`: SDK and library users, headers, APIs, Meson, and pkg-config evidence.
- `services-template.md`: service or application operators, runtime prerequisites, and blocked mutations.
- `drivers-template.md`: driver-facing users, host prerequisites, support checks, installed metadata, and blocked host
  or device mutations.
- `examples/doca-flow-source-guide.md`: first worked library guide example for DOCA Flow.

Use `contracts/agent-manifest.json` and `contracts/capability-catalog.json` to see the contract surface shipped in this
repository. Use source evidence only as narrow references back to SDK source packages, SDK headers, Meson metadata,
package metadata, samples, or applications.

## Framework Guide Checklist

| Need | Fill In |
| --- | --- |
| Framework scope | Exact source package, SDK header, sample, application, driver-facing, or package metadata paths covered by the guide. |
| Libs template | API/header/dependency facts for SDK and library users. |
| Services template | Runtime prerequisites, operator-visible knobs, and blocked state changes. |
| Drivers template | Host prerequisites, support checks, installed metadata, and approval-gated driver or device changes. |
| Evidence | Source-backed files or commands that prove each claim. |
| Safety | Commands or state changes agents must not run without local owner approval. |

If a task requires framework-specific guidance that is not present here, state that no framework guide is packaged yet
and ask for the relevant documentation link or SDK source package evidence.
