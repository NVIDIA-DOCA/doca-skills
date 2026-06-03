# Skill Card

## Description

The `doca-public-knowledge-map` skill is used when the user needs to locate authoritative information about NVIDIA DOCA without access to the source tree — finding the right docs.nvidia.com page for a library/service/tool, identifying which DOCA libraries are installed and at what version, locating a sample on disk or its public GitHub source, decoding an on-disk path under /opt/mellanox/doca, or recovering from a 404'd or renamed doc URL.

This skill is **documentation-only** (it ships no runnable code) and is intended
for developer guidance and demonstration use, not as a production control plane.

## Owner

NVIDIA DOCA team (NVIDIA-DOCA/doca-skills)

## License/Terms of Use

Apache-2.0 AND CC-BY-4.0

## Use Case

For external developers building on the NVIDIA DOCA SDK with a BlueField DPU or
ConnectX NIC, driven by an AI coding agent. The agent loads this skill when a
task matches its trigger surface (see the `description` in `SKILL.md`) and
follows the procedural guidance to configure, build, run, validate, or debug
the relevant DOCA knowledge. This is a cross-cutting skill graded as part of the bundle-wide structural suite; see the bundle `BENCHMARK.md`.

## Deployment Geography for Use

Global. The guidance references only public NVIDIA documentation and the user's
own local DOCA install; it carries no region-specific constraints.

## Known Risks and Mitigations

Risk: The skill may recommend commands that change DPU/NIC hardware or firmware
state (for example `mlxconfig` writes, a BlueField mode flip, a BFB reflash, or
hugepage reservation).
Mitigation: every hardware-touching step is routed through the
`doca-hardware-safety` meta-policy (pre-flight inventory, out-of-band access,
maintenance window, replica-first validation, and a rollback path), and the
agent must surface the change for human review before executing it.

Risk: The skill names DOCA API symbols, tool flags, pkg-config modules, and
on-disk paths that an agent could otherwise fabricate.
Mitigation: the bundle's authoring contract forbids unverified tokens; the
agent is instructed to confirm every symbol, flag, and path against the live
install (`pkg-config`, `--help`, on-disk headers) before relying on it.

Risk: The skill could drift from the installed DOCA version and suggest an
API or layout that does not match the user's release.
Mitigation: version detection, pairing, and rollback are routed to the
`doca-version` skill, and the bundle is aligned to publicly-released DOCA 3.3.0109.

## References

- [`skills/doca-public-knowledge-map/SKILL.md`](SKILL.md) — the skill instructions consumed by the agent
- `../../../BENCHMARK.md` — how this bundle is graded and the latest measurement
- `../../../nvskills/components.d/doca.yml` — catalog product registration
- [NVIDIA DOCA SDK documentation](https://docs.nvidia.com/doca/sdk/) — the authoritative public source

## Skill Output

Output type(s): natural-language guidance and analysis. The bundle is
documentation-only and produces no code, files, or API calls of its own.

Output format: Markdown instructions consumed by an AI agent.

Other properties: no direct side effects. Any commands the agent runs as a
result of the guidance are gated by the human-review and hardware-safety rules
in `AGENTS.md` and `doca-hardware-safety`.

## Skill Version

Aligned to publicly-released DOCA 3.3.0109. The signed release version and signing identifier
(`skill.oms.sig`) are populated by the NVCARPS scan/sign pipeline at publish
time; the machine-readable companion record is `SKILLCARD.yaml`.

## Ethical Considerations

Guidance must not be executed blindly. Any change touching shared hardware
requires human review and an appropriate maintenance window. The skill cites
only public NVIDIA documentation and must not surface NVIDIA-internal
information.
