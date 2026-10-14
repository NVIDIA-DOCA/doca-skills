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

## Unreleased

Content queued for the next promotion to the published bundle.

### Skill changes

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

### Evaluation changes

- `doca-verbs` negative-routing evaluation now distinguishes conceptual terms
  from invented API symbols, and no longer asserts a subjective judgment that
  produced inconsistent verdicts across repeated runs. The remaining
  assertions still cover grounding and hallucination.

### Notes for consumers

No action required. No skill was added or removed, and no evaluation dataset
changed size.

## Known limitations

These are tracked and not yet resolved. They are recorded here so consumers
are not surprised by them.

- **Benchmark evidence reports one attempt per task.** The per-skill
  `BENCHMARK.md` files are generated and signed upstream, and they record
  `Attempts per task: 1`. The bundle's own regression evaluation is stricter:
  it refuses to run fewer than three attempts and requires a majority to pass.
  Correcting the published figure requires an upstream re-run and re-sign.
- **Six skills carry no Tier 3 measurement.** `doca-caps`, `doca-dpa`,
  `doca-dpdk-bridge`, `doca-erasure-coding`, `doca-eth`, and
  `doca-flow-dpa-provider` report a Tier 3 verdict without underlying results,
  because their evaluation dataset was not carried into the report payload.
  Their `BENCHMARK.md` also reports the number of recorded *trials* where the
  task count belongs, which makes their datasets look larger than they are;
  all six contain four evaluation tasks.
- **Skill card format is not uniform.** 47 skills ship `SKILLCARD.yaml`
  alongside `skill-card.md`; the remaining 13 ship only `skill-card.md`. Both
  forms are covered by their skill's signature, so converging on one format
  requires an upstream re-sign.
