# Security Policy

This repository ships **documentation-only agent guidance** for the
NVIDIA DOCA SDK. The bundle does not ship runnable code, build
artifacts, container images, or anything that executes on a user's
machine at install time. The threat model is therefore narrower than
for a runtime project, but two classes of issue are still in scope:

## Reporting a vulnerability

| Class | What to do |
| --- | --- |
| **Leaked confidential or NVIDIA-internal information in a skill file** — internal URLs, internal hostnames, internal Jira / Bug numbers, customer names, embargoed unreleased features. | Do not open a public Issue. Email the maintainers at the email listed in the repository's `CODEOWNERS` (or, if none, contact NVIDIA Product Security at <https://www.nvidia.com/en-us/security/>) with the offending file path and line. We will rewrite or remove the content and force-push history if required. |
| **Skill content that, if followed by an agent, could damage hardware or destabilise production** — wrong rollback procedure, missing safety pre-flight, hot-applied `mlxconfig`-class change. | Open an Issue on this repository and tag it `safety-bug`. Reference the offending skill file, the offending anchor, and the production scenario it misroutes. The on-call DOCA-skills maintainer triages safety-bugs ahead of feature work. |
| **External skill recommends running a third-party binary / curl-pipe-bash / unverified container image.** | Open a public Issue. Recommendations of that shape are out of policy and will be rewritten to route to the matching public NVIDIA install path. |

## Out of scope

- Vulnerabilities in DOCA itself (the C libraries / services / tools
  documented by this bundle). Report those via NVIDIA PSIRT at
  <https://www.nvidia.com/en-us/security/>, not here.
- Bugs in third-party AI agents, IDEs, or runtimes that load this
  bundle. Report those to the agent / IDE vendor.

## What this repository will never ask you to do

The skills here will **never** ask the user — or the agent on the
user's behalf — to:

- Disable host firewalling, IOMMU, or SELinux outside an explicit
  documented maintenance step that links to the NVIDIA public guide
  describing the trade-off.
- Run an `mlxconfig`-class write without the safety pre-flight in
  `doca-skills/skills/doca-hardware-safety/`.
- Pull a non-`nvcr.io` container image when an `nvcr.io` image
  exists for the same workload.
- Hand-edit firmware files (`*.bfb`, `*.bin`) outside the documented
  `mlxfwmanager` / BFB-install path.

If you find a skill that violates any of the above, file it as a
`safety-bug`.

## Supply chain

This repository contains markdown only — no `package.json`,
`requirements.txt`, `Cargo.toml`, or other dependency manifest at
runtime. The only programs invoked by the bundle's CI are
`bash` (for the gate scripts) and standard Unix tools (`awk`, `find`,
`grep`, `python3`), which are pre-installed on the Jenkins build
image.
