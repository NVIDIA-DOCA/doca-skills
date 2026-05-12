---
name: doca-user-rules
description: "Apply base DOCA skill behavior: inspect local source evidence first, use read-only tools, keep actions scoped, and report blockers."
---

License: see repository root `LICENSE.md`.

Applies to: DOCA base user rules and safe first responses
Read when: a `doca-skills` export needs a short base behavior skill

# DOCA User Rules

Use this as the base behavior for DOCA source-package tasks.

## Read First

- `llms.txt`
- `README.md`
- `getting-started/quickstart.md`
- `getting-started/first-commands.md`
- `skills/doca-ai-runner/SKILL.md`

## Rules

- Start from the repository or source-package root.
- Read the smallest relevant guidance set for the task.
- Run read-only discovery before naming runtime commands, package versions,
  available capabilities, or environment facts.
- Use capability lookup before naming headers, functions, dependencies,
  lifecycle steps, samples, or applications.
- Treat missing tools, metadata, devices, or paths as blockers to report.
- Ask only when the answer decides between source writes, build output, runtime
  execution, device state, networking, credentials, or persistent config.

## Forbidden By Default

Do not install packages, mutate devices, change networking, write credentials,
edit global agent or IDE configuration, change persistent system settings, run
traffic, or execute runtime samples unless the user explicitly approves that
action class.

## Result

Close with `diagnosis`, `source_inventory`, selected contract or capability,
commands run, `verification_commands`, `unmet_prerequisites`,
`blocked_actions`, and exact next safe command.
