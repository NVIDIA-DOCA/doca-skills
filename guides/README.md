# DOCA Package Guides

Applies to: DOCA source-package questions
Read when: answering questions about DOCA samples, applications, build metadata, capability evidence, or public documentation
Load next: `guides/capability-map.md`; then one skill from `skills/`

Agents should ground answers in source files, Meson build metadata, packaged AI
contracts, and public NVIDIA documentation. Runtime facts should be verified on
the user's local DOCA environment before being stated as measured.

## Answer Rules

- Cite source paths inspected.
- Separate source-package evidence from runtime verification.
- Use public docs for concepts, install, and compatibility context.
- Do not rely on site-specific infrastructure, credentials, or local
  environment state to explain how the package works.
- When a capability requires runtime verification, name the local evidence or
  command that would verify it.

## Skill Selection

- Documentation and capability discovery: `skills/doca-explorer/SKILL.md`
- Capability and environment discovery: `skills/doca-discover-environment/SKILL.md`
- Programming Guide enrichment: `skills/doca-programming-guide/SKILL.md`
- Build planning: `skills/doca-build-sdk-sample/SKILL.md`
- Source-change planning: use only task IDs published in the package manifest;
  public skills packages do not publish module patch helpers.
