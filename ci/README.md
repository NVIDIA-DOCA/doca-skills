# devops/ci — bundle regression checks

This folder holds the per-PR and periodic regression gates for the `doca-skills` bundle.

## TL;DR — run the full per-PR gate

```bash
devops/ci/run-bundle-regression-check.sh                 # all gates, no network
devops/ci/run-bundle-regression-check.sh --check-urls    # also HEAD every URL
devops/ci/run-bundle-regression-check.sh --with-self-test  # add gate-self-test pass (weekly)
```

Exit 0 = bundle structurally matches the C‴ measurement baseline (6-variant constant-grader scoreboard at A 20.0 % → C‴ 91.4 % YES, fully measured on all 12 prompts); exit 1 = at least one gate failed and the PR must not merge.

## Gate chain

Each gate is a separate script and can be invoked standalone. The orchestrator (`run-bundle-regression-check.sh`) runs them in this order; the failure of any single gate is the failure of the PR.

| Order | Script | What it protects | Hard fail? |
| ----- | ------ | ----------------- | ---------- |
| 0 (opt-in) | `check-keystones.sh --self-test` | The keystone gate itself — runs each keystone perturbation in turn and confirms the gate trips. Catches bugs in the gate. | Yes (when run) |
| 1 | `check-keystones.sh` | **The 5-variant constant-grader baseline.** Confirms every load-bearing structural keystone is still present: AGENTS.md cross-cutting trigger sections (verification contract, debug-loop contract, binding stanza, deploy-loop bridge cross-ref, canonical answer-shape teasers, ground rules, non-goals), `doca-setup/CAPABILITIES.md` (verification contract, deploy-loop bridge, binding stanza ≥ 6 rows), `doca-debug/CAPABILITIES.md` debug-loop contract, `doca-flow/TASKS.md ## flow-ct` and the Step-4 rollback overlay, `doca-hardware-safety` + `doca-version` activation checklists. **Deleting any of these silently regresses the bundle to a prior wave; this gate prevents that.** | Yes |
| 2 | `check-skill.sh --all` | Per-skill conformance — frontmatter validity, required H2 anchors per kind, no-private-references, optional URL HEAD validity. The bundle's original CI gate. | Yes |
| 3a | `check-doca-inventory.sh` | The bundle's 1:1 inventory with `doca/{libs,services,tools}` at the currently-aligned DOCA release (28 libs + 7 services + 18 tools = 53 per-artifact skills). | Yes |
| 3b | `check-crosslinks.sh` | Every `[text](path.md#anchor)` cross-link resolves to a real anchor (Python-flavoured slug rule). | Yes |
| 3c | `check-anchor-density.sh --all` | Every required H2 anchor in every skill carries real content, not a stub (per-anchor density floor with overrides). | Yes |
| 3d | `check-coverage.sh` | Routing discoverability — every per-artifact skill is registered in `SKILLS.md` + `doca-public-knowledge-map`, and every skill has ≥ 1 prompt under `devops/runner/prompts/`. | Yes |
| 3e | `check-jtbd-coverage.sh` | Coverage of the upstream JTBD set (soft skip when no extraction file is present; soft warn otherwise). | Soft warn |

## How this relates to the constant-grader scoreboard

The 5-variant constant-grader scoreboard is the measurement of record for the bundle:

| Variant | Bundle state | YES of applicable (constant grader) | Δ from A |
| ------- | ------------ | ----------------------------------: | -------: |
| A | no bundle | 20.0 % | — |
| B | `main` at deep-test time (empty) | 17.1 % | −2.9 pp |
| C | Step-1 PR HEAD | 49.5 % | +29.5 pp |
| C′ | Step-2 PR HEAD | 68.6 % | +48.6 pp |
| C″ | Step-3 PR HEAD | 86.7 % | +66.7 pp |
| **C‴ (fully measured)** | **Step-4 / on-`main` ship state** | **91.4 %** | **+71.4 pp** |

Each wave's lift came from specific keystones in the bundle. The keystone gate (`check-keystones.sh`) maps 1:1 to those keystones: deleting the universal verification contract regresses the bundle to ~C (Step 1 = ~49 % YES); deleting the universal debug-loop contract regresses C12 / C4 back to ~14 % YES; deleting the binding-layer command stanza regresses C8 back to ~38 % YES; deleting the Step-4 deploy-loop bridge regresses C12 on deploy prompts back to PARTIAL; deleting the Flow CT rollback overlay re-introduces the single NO cell that C″ had eliminated.

**The keystone gate is therefore the cheapest possible proxy for "did this PR re-introduce a measured regression."** Re-running the full 5-variant LLM grade after every PR is impractical (cost, time, grader variance); the structural gate catches the load-bearing class without any LLM cost.

## Periodic LLM-driven re-measurement

The structural gate catches deletions but not subtle drift (someone refactors `doca-flow/TASKS.md ## flow-ct` keeping the rollback overlay structurally present but with reduced substance). That class is caught by a periodic LLM-driven re-measurement:

| Cadence | What to run | Where it lives |
| ------- | ----------- | -------------- |
| Per PR (automated) | `run-bundle-regression-check.sh` (all gates above) | This README |
| Nightly / weekly (automated, needs LLM API) | Dispatch the breadth-60 subagent slate via `devops/runner/ab_runner.py` with the integrator's `AgentAdapter` and `JudgeAdapter`; compare to `devops/runner/reports/breadth_60_2026-05-19/scores/breadth_60_self_scores.json` baseline | `devops/runner/reports/breadth_60_2026-05-19/` |
| Per major bundle change (human-driven) | Dispatch a fresh 5-variant deep-test + constant-grader pass via Cursor subagents (see `devops/runner/reports/3agent_pr3pr4_ab_2026-05-18/VERDICT.md ## Provenance` for the exact dispatch shape) | `devops/runner/reports/3agent_pr3pr4_ab_2026-05-18/` |

## Adding a new keystone gate

When a new load-bearing keystone is added to the bundle (typically a new H2 / H3 section in `AGENTS.md` or a cross-cutting skill), update `check-keystones.sh` in two places:

1. Add a new `check ...` (or `check_count ...`) call in the matching section.
2. Add a matching perturbation entry to the `perturbations=(…)` array inside the `--self-test` mode so the gate's self-check covers the new keystone.

Then re-run `check-keystones.sh --self-test` and confirm the total perturbation count went up by one and that every perturbation (including the new one) trips the gate.

## Reproducing the measurement of record

Every number cited in this README and in `devops/runner/reports/*/VERDICT.md` is reproducible:

| Artifact | Reproducer |
| -------- | ---------- |
| 5-variant unified constant-grader scoreboard | `python3 devops/runner/reports/3agent_pr3pr4_ab_2026-05-18/scores/build_constant_strict.py` |
| 60-prompt breadth headline | `python3 devops/runner/reports/breadth_60_2026-05-19/scores/aggregate_breadth_60.py` |
| Step-4 stress-test scoreboard | `python3 devops/runner/reports/step4_2026-05-19/scores/aggregate_step4.py` |
| Structural keystone state (this gate) | `devops/ci/check-keystones.sh` |
| Structural keystone state (self-test) | `devops/ci/check-keystones.sh --self-test` |
| Full per-PR gate chain | `devops/ci/run-bundle-regression-check.sh` |

The aggregator scripts read the raw subagent transcripts that were saved under each report's `raw_responses/` folder; re-running them recomputes the exact numbers without re-dispatching any subagent.
