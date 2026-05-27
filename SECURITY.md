# Security Policy

This repository ships **documentation-only agent guidance** for the
NVIDIA DOCA SDK. The bundle does not ship runnable code, build
artifacts, container images, or anything that executes on a user's
machine at install time. The threat model is therefore narrower than
for a runtime project, but two classes of issue are still in scope.

## Reporting a vulnerability

| Class | What to do |
| --- | --- |
| **Leaked confidential or NVIDIA-internal information in a skill file** — internal URLs, internal hostnames, internal Jira / Bug numbers, customer names, embargoed unreleased features. | Do **not** open a public Issue. Email NVIDIA Product Security via <https://www.nvidia.com/en-us/security/> with the offending file path and line. We will rewrite or remove the content and force-push history if required. |
| **Skill content that, if followed by an agent, could damage hardware or destabilise production** — wrong rollback procedure, missing safety pre-flight, hot-applied `mlxconfig`-class change. | Open an Issue on this repository and tag it `safety-bug`. Reference the offending skill file, the offending anchor, and the production scenario it misroutes. The on-call DOCA-skills maintainer triages safety-bugs ahead of feature work. |
| **External skill recommends running a third-party binary / curl-pipe-bash / unverified container image.** | Open a public Issue. Recommendations of that shape are out of policy and will be rewritten to route to the matching public NVIDIA install path. |

## Out of scope

- Vulnerabilities in DOCA itself (the C libraries / services / tools
  documented by this bundle). Report those via NVIDIA PSIRT at
  <https://www.nvidia.com/en-us/security/>, not here.
- Bugs in third-party AI agents, IDEs, or runtimes that load this
  bundle. Report those to the agent / IDE vendor.
- Bugs in NVIDIA's NVCARPS scanning + signing pipeline. Report those
  through the channel documented at the NVIDIA Skills catalog
  (<https://github.com/NVIDIA/skills>).

## What this repository will never ask you to do

The skills here will **never** ask the user — or the agent on the
user's behalf — to:

- Disable host firewalling, IOMMU, or SELinux outside an explicit
  documented maintenance step that links to the NVIDIA public guide
  describing the trade-off.
- Run an `mlxconfig`-class write without the safety pre-flight
  described by the `doca-hardware-safety` meta-skill.
- Pull a non-`nvcr.io` container image when an `nvcr.io` image
  exists for the same workload.
- Hand-edit firmware files (`*.bfb`, `*.bin`) outside the documented
  `mlxfwmanager` / BFB-install path.

If you find a skill that violates any of the above, file it as a
`safety-bug` per the table above.

## Supply chain

This repository contains markdown only — no `package.json`,
`requirements.txt`, `Cargo.toml`, or other dependency manifest at
runtime. The installer (`install.sh`) is a dependency-free POSIX
shell script that copies skill directories into the consuming
agent's skill discovery path.

Each skill carries a `SKILLCARD.yaml` with provenance metadata
(`source.repo`, `source.path`, `source.branch`, `source.license`)
and an NVCARPS-issued cryptographic signature at publication time.
Consumers verifying a skill's authenticity should validate the
signature against the NVCARPS public keyring published alongside
the NVIDIA Skills catalog.
