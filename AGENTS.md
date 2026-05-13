# DOCA Skills Guidance

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: any AI assistant starts work in this repository
Load next: `README.md`, `getting-started/quickstart.md`, `skills/README.md`,
`contracts/agent-manifest.json`

This repository is the standalone `doca-skills` helper payload for DOCA SDK source-package work. It is not itself the
SDK source tree.

Use this repository for agent guidance, three focused skills, task contracts, and read-only command procedures. When a
procedure needs SDK facts, inspect the DOCA SDK source-package path named by the user.

For task selection, load `contracts/agent-manifest.json`, then read the matching task and capability contracts from
`contracts/`. This repository does not ship Python helper code.

Use only files and commands visible in this repository or in the SDK source package path. Treat site-specific workflow
and infrastructure details as unavailable unless the user provides them explicitly.
