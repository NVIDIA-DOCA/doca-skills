# Tool Catalog

Applies to: `NVIDIA-DOCA/doca-skills/tools`
Read when: choosing a package helper tool
Load next: `contracts/README.md`, `skills/doca-ai-runner/SKILL.md`

These small Python tools help an agent inspect package evidence before changing advice or proposing commands.

| Tool | Purpose |
| --- | --- |
| `lookup_capability.py` | List available capabilities and inspect SDK headers, Meson dependencies, and examples. |
| `run_agent_task.py` | Run read-only discovery or return planner-only build evidence for a selected target. |
| `ai_contracts.py` | Provide JSON helpers used by the other tools. |

## Safe Defaults

- Use `python3 tools/lookup_capability.py --repo-root . --list` before choosing a capability.
- Use `python3 tools/lookup_capability.py --repo-root . --api-index doca-sdk` before naming APIs, headers, or
  dependencies.
- Use `python3 tools/run_agent_task.py --task discover-doca-environment --repo-root <source-package-root>` before making
  version or environment claims.
- Treat blocked task results as useful evidence. Report the blocker and next safe command instead of guessing.
