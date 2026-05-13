# Source-package Tool Procedures

Applies to: `NVIDIA-DOCA/doca-skills/tools`
Read when: choosing a package evidence procedure
Load next: `contracts/README.md`, `skills/doca-ai-runner/SKILL.md`

Packages do not ship Python helper code. Use already-installed source-package tools and source files to inspect package
evidence before changing advice or proposing commands.

| Evidence | Procedure |
| --- | --- |
| Contracts | Read `contracts/agent-manifest.json`, `contracts/capability-catalog.json`, and matching task YAML. |
| Source headers | Use `find` and `grep` or `rg` to inspect SDK headers and examples. |
| Package metadata | Use `pkg-config --modversion`, `pkg-config --cflags --libs`, and installed `doca-*.pc` files. |
| Build planning | Read Meson files and run Meson/Ninja only after local build-output approval. |

## Safe Defaults

- Read the capability catalog before choosing a capability.
- Use `grep` or `rg` over SDK headers before naming APIs.
- Use `pkg-config` before naming installed packages or link flags.
- Treat missing files, tools, or command failures as useful evidence. Report the blocker and next safe command instead
  of guessing.
