# DOCA Environment Discovery

Applies to: read-only DOCA source, package, library, and capability discovery
Read when: a user asks what DOCA version, libraries, or capabilities are available
Load next: `getting-started/first-commands.md`, `getting-started/validation.md`, `contracts/README.md`, `skills/doca-ai-runner/SKILL.md`

Use read-only discovery before proposing build, source-change, or runtime commands. Do not infer package, device, or
capability facts from memory.

## Discovery Commands

Use the baseline source-package discovery commands in `getting-started/first-commands.md`. For a named library or SDK
topic, add the API or library lookup command from the same file before selecting functions, headers, packages, or
lifecycle steps.

## Facts To Report

- `source_version` from the local source package.
- Available capability IDs from the manifest.
- SDK-header experimental API marker summary.
- Package metadata when `package-info.json` exists.
- Missing discovery utilities as blockers, not guessed facts.

If runtime work is requested, discover the environment first and stop before device, network, hugepage, credential, or
persistent system mutation unless the local owner explicitly approves that action class.
