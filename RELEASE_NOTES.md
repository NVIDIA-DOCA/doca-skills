# Release notes

Change tracking for the DOCA agent skills bundle. Each entry records what
changed in the shipped content, what evidence qualified it, and anything a
consumer of the bundle has to act on.

## How to read these notes

- **Skill changes** are the only entries that alter agent behavior. They are
  listed per skill, because an agent loads skills individually.
- **Evidence** names the qualification that backed the release. A release with
  no comparative evidence is not a release; it is a draft.
- **Signature state** matters for consumers: signed skill content is
  redistributable, unsigned content is review-only.
- Versions are date-anchored (`YYYY.MM.N`) rather than semantic, because the
  bundle is a catalog of independent skills, not a single API surface.

## DOCA 3.5 bundle update

### Skill changes

**Improvements and DOCA 3.5 adjustments.** `doca-bench` covers GPUNetIO
benchmarks end to end, including the DOCA Bench Extension prerequisites.
`doca-flow-tune` covers the full measure-then-tune loop on the user's own
pipeline (monitor-mode baseline, analysis, re-measure). `doca-bf4-deployment`
follows the DOCA Management Service BlueField-4 install path. `doca-dts`
covers DOCA Telemetry Service deployment and configuration, and the
catalog follows the DOCA 3.5 component set. `doca-devemu`,
`doca-sha-offload-engine`, `doca-spcx-cc` and the knowledge map
follow the DOCA 3.5 headers and installed files.

**`doca-verbs`** — three corrections, all aimed at making the skill's answers
complete and its routing boundary explicit.

- Added a mandatory answer checklist so in-scope porting, lifecycle, and
  debugging answers consistently state the load-bearing facts: that
  `doca_verbs_context` is the DOCA Core context owning the verbs surface, and
  that a submit-time success followed by an I/O failure is diagnosed from the
  completion-queue entry rather than from the submit return value. Both were
  previously reachable only through supporting documents, so answers omitted
  them inconsistently.
- Made the routing boundary explicit: for routing-only questions the skill now
  stops at the conceptual boundary instead of inferring and listing
  `doca-rdma` implementation APIs that were never loaded.
- Trimmed the worked-example section to keep the skill inside its efficiency
  budget after the checklist was added. The example *classes* were redundant
  with the capability and task guidance the checklist now points at directly.

### Notes for consumers

Some skills left the catalog in this update. Re-run
`./install.sh --agent <agent> --force` and delete any skill folder that is
no longer listed in `SKILLS.md` from your agent's skills directory.

## Known limitations

These are tracked and not yet resolved. They are recorded here so consumers
are not surprised by them.

- **Benchmark evidence reports one attempt per task.** The per-skill
  `BENCHMARK.md` files record `Attempts per task: 1`.
- **Some skills carry no Tier 3 measurement.** `doca-caps`, `doca-dpa`,
  `doca-dpdk-bridge`, `doca-erasure-coding` and `doca-eth` report a Tier 3
  verdict without underlying results. Their `BENCHMARK.md` also reports the
  number of recorded *trials* where the task count belongs; all of them
  contain four evaluation tasks.
- **Skill card format is not uniform.** 41 skills ship `SKILLCARD.yaml`
  alongside `skill-card.md`; the remaining 12 ship only `skill-card.md`.
