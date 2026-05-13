# DOCA Skills Guidance

Applies to: `NVIDIA-DOCA/doca-skills`
Read when: any AI assistant starts work in this repository
Load next: `README.md`, `getting-started/README.md`, `skills/README.md`, `contracts/README.md`

This repository is the standalone `doca-skills` helper payload for DOCA SDK source-package work. It is not itself the
SDK source tree.

Use this repository for agent guidance, portable skills, task contracts, and read-only helper tools. When a helper needs
SDK facts, pass the DOCA SDK source package with `--repo-root <source-package-root>`.

For executable tasks, load `contracts/agent-manifest.json` and then the matching task and capability contracts from
`contracts/`.

Use only files and commands visible in this repository or in the SDK source package passed to `--repo-root`. Treat
site-specific workflow and infrastructure details as unavailable unless the user provides them explicitly.
