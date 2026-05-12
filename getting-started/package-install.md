# Package Use

Applies to: DOCA AI guidance and helper tools
Read when: deciding how to use this repository with a DOCA SDK source package
Load next: `getting-started/quickstart.md`,
`getting-started/first-commands.md`, `getting-started/validation.md`

This repository is a standalone helper payload. Use it next to a DOCA SDK
source package, installed SDK headers, or package metadata that the local
workspace already exposes.

## Recommended Layout

Keep this repository separate from the DOCA SDK source package under analysis.
Run helper commands from this repository and pass the source package root with
`--repo-root` when a command needs package evidence.

```bash
python3 tools/lookup_capability.py --repo-root . --list
python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>
```

For sample or application build planning, use planner-only mode first:

```bash
python3 tools/run_agent_task.py \
    --task build-sdk-sample \
    --repo-root <source-package-root> \
    --focus-path <sample-or-application-path>
```

## Activation

Coding agents should start from the root adapter they already support:
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `JULES.md`, `SKILLS.md`, `llms.txt`,
`.github/copilot-instructions.md`, `.windsurfrules`, `.clinerules`, or
`.roo/rules/doca.md`.

No command in this repository should edit global agent settings or write into
user home directories. If a local owner wants editor-specific activation, copy
the matching template from `adapters/` into the workspace explicitly.

## Boundaries

Default helper flows inspect files and report facts. They do not install
packages, change devices, configure networking, write credentials, alter
persistent configuration, run traffic, or execute runtime samples. Report those
needs as blockers and ask the local owner for the right package, device, or
runtime evidence.
