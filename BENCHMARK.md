# Benchmark

This document describes how the DOCA Agent Skills bundle measures itself: what
the test surface is, how it is graded, what counts as "green", and where the
artifacts live. It is the BENCHMARK.md companion to `LICENSE`, `CONTRIBUTING.md`,
and `SECURITY.md` required by the NVIDIA Skills Publishing Onboarding contract.

The bundle is **documentation-only** — it does not ship runnable code. The
benchmark therefore measures the *behavior an AI agent produces when handed the
bundle*, not the latency of a library call. The grading rubric is deliberately
strict: the bundle's job is to keep agents from inventing symbols, paths, flags,
or subcommands, and from skipping safety-relevant preconditions.

## What is measured

Two orthogonal axes:

| Axis | What it measures | How it runs |
| --- | --- | --- |
| **A. Structural regression** | The bundle still satisfies every contract that the constant-grader scoreboard depends on (skill structure, anchor density, public-source URLs, frontmatter `kind`, AgentSkills.io reference validity, non-goal routing, JTBD coverage, live-hardware-harness shape, reference hygiene, NVIDIA-Skills publishing readiness). | The DOCA team's internal development pipeline runs a 15-gate fail-fast suite on every PR before the bundle is mirrored into this public catalog. |
| **B. Per-skill end-to-end agent behavior** | A real AI agent is handed the bundle and one end-to-end prompt per shipping skill. A separate strict grader subagent then grades the response on 5 dimensions against the bundle's authoritative skill files. | Generator + per-prompt agent dispatch + per-response grader dispatch + aggregation. Same internal pipeline as Axis A. |

Both axes run from the same source-of-truth bundle layout (`AGENTS.md`,
`SKILLS.md`, `skills/<kind>/<name>/{SKILL,CAPABILITIES,TASKS}.md`).

## Structural regression baseline (Axis A)

The 15-gate suite is the contract every PR to the upstream development
repository must satisfy. The gate inventory:

| # | Gate | Current state |
| - | --- | --- |
| 0 | Keystone self-test (the gate-checks-the-gate) | OK (weekly) |
| 1 | Structural keystone | OK |
| 2 | Per-skill conformance (61 skills) | OK |
| 3 | DOCA inventory | OK |
| 3 | Cross-links | OK |
| 3 | Anchor density | OK |
| 3 | Coverage | OK |
| 3 | JTBD coverage | OK |
| 3 | Public-surface invariants (5/5) | OK |
| 3 | Live-hardware harness shape (6/6 fixtures) | OK |
| 3 | AgentSkills.io compliance (61 skills) | OK |
| 3 | Non-goal routing (27 products) | OK |
| 4 | Reference hygiene (no internal path leaks; no audit history in runtime `SKILL.md`) | OK |
| 4 | Frontmatter `kind` (libs→library, services→service, tools→tool — all 52) | OK |
| 4 | NVIDIA-Skills publishing readiness (LICENSE + CoC + BENCHMARK + per-skill `evals/evals.json` + `skill-card.md` (catalog-required governance card) + `SKILLCARD.yaml` (machine-readable companion) + `components.d/doca.yml`) | OK |
| 5 | No-regression vs frozen baseline (609 baseline cells, variant C) | OK — 0 regressions |

The frozen baseline is the no-regression contract: every previously-PASS cell
on the strict variant-C grader must still PASS, or the PR is blocked.

## Per-skill end-to-end behavior (Axis B)

For each of the 51 shipping artifacts (28 libraries + 6 services + 17 tools)
the deep E2E suite generates:

- A **prompt** that asks the agent to walk a complete end-to-end workflow for
  that artifact: confirm env, discover devices/capabilities, modify a real
  shipped sample, build/run/validate with a concrete observable, and lay down
  a first-failure ladder.
- A **grader rubric** that asks a strict grader subagent to verify the response
  on five dimensions, each a hard PASS/FAIL:

  | Dim | What it tests | What FAIL looks like |
  | --- | --- | --- |
  | D1 invented_tokens | Every symbol, flag, subcommand, path, and pkg-config module is traceable to the bundle, AGENTS.md, or a real NVIDIA public doc. | Fabricated names (e.g. `--pipeline` on a tool that has no such flag, `_v1` suffix on a real symbol, `samples/gpunetio/` when the real path is `tools/gpunetio_ib_write_lat/`). |
  | D2 sequence_correctness | Steps satisfy each other's preconditions; the 5-step contract is visibly walked. | Build before install, or skipping the discovery step. |
  | D3 validation_concreteness | Step 4 names a concrete observable tied to the artifact's semantics. | "Exit 0 / no error" alone. |
  | D4 debug_concreteness | Step 5 names 3 distinct layers each with a distinguishing symptom. | A single generic "rerun with `-vvv`" bullet. |
  | D5 consumer_concreteness | Step 3 points to a real shipped sample/config/unit/image. | Hand-rolled example invented from whole cloth. |

  The grader emits one JSON object per response with `verdict_overall = PASS`
  iff `blocker_findings` is empty.

## Latest measurement

```
Overall:     51/51 PASS (100%)
Blockers:    0
MED gaps:    7  (non-blocking; stylistic / could-be-more-concrete)

By kind:
  library: 28/28 PASS
  service:  6/6 PASS
  tool:    17/17 PASS
```

This is the second round of grading from the same source bundle. The first
round (against the same bundle, against the same prompts and graders) returned
46/52 PASS with 9 blockers spread across 6 tools. Every one of those blockers
was an agent-under-test fabrication, not a bundle factual error, but a real
downstream agent would have repeated the same fabrication. The fix landed as
fix batch 10: an explicit `> **Do-not-invent guard ...**` blockquote at the
top of each of the 6 affected tools' `TASKS.md ## run`, naming the specific
trap by name. The same 6 prompts re-dispatched to a fresh agent against the
hardened bundle returned 6/6 PASS, 0 blockers — converting the round to 52/52.

The `Do-not-invent guard` pattern is now part of the bundle's authoring
contract; new tool skills must include one when the tool's flag / subcommand
inventory is `--help`-driven rather than statically named.

## How to reproduce

The structural-regression suite and the deep end-to-end suite are run in the
DOCA team's internal development pipeline. Downstream consumers who want to
reproduce the per-skill end-to-end measurement against their own agent can
do so directly from this repository:

1. Load this bundle into the target agent (`./install.sh --agent <agent>`).
2. For each shipping skill, dispatch the eval prompt from
   `skills/<kind>/<art>/evals/evals.json` to the agent.
3. Dispatch the grader rubric (also in `evals/evals.json`) to a separate
   grader instance with the agent's response.
4. Parse the grader's JSON output; `verdict_overall == "PASS"` iff
   `blocker_findings` is empty.

Each skill's `evals/evals.json` is self-contained — the prompt text, grader
rubric, and the bundle's own baseline verdict all live in the same file.

## Multi-environment coverage

The same suite is run in both of the operational environments the bundle
targets:

| Env | What changes | How it's covered |
| --- | --- | --- |
| With the DOCA monorepo cloned alongside | Strict-to-doca invariants (the bundle aligns to the publicly-released DOCA `3.3.0109` source set). | Validated against the cached monorepo in the internal CI pipeline. |
| Without the DOCA monorepo (the customer's normal environment) | The bundle must be self-sufficient — no internal-only paths, no hostnames that resolve only inside NVIDIA, no references to files that only exist in the monorepo. | Reference-hygiene gate (gate 4) blocks any leak; AgentSkills.io compliance gate blocks any unresolved reference. |
| On a real BlueField host (BF2 + BF3 DPUs) | The TMFIFO, RShim, apt-source, log-level, and `bf.cfg` claims must match what the hardware actually reports. | The latest live hardware probe folded its 5 findings back into `doca-bare-metal-deployment`, `doca-version`, and `doca-public-knowledge-map`; the live-hardware harness gate (gate 3) keeps the harness shape from drifting. |

## Out of scope for this benchmark

- Single-agent latency or token count. The bundle is documentation; the agent
  vendor's runtime characteristics are not measured here.
- "How many skills does each agent discover" — that is a function of the
  agent's skill discovery model and is covered by `install.sh` per the
  per-agent install-path matrix in `README.md`, not by this benchmark.
- Skill *adoption* metrics (how often a skill triggers, customer satisfaction,
  bug-rate reduction). Those live downstream of publication and depend on
  the NVCARPS / NVIDIA-Skills catalog telemetry.
