# Benchmark

This document describes how the DOCA Agent Skills bundle measures itself: what
the test surface is, how it is graded, what counts as "green", and where the
artifacts live. It is the BENCHMARK.md companion to `LICENSE`, `CONTRIBUTING.md`,
and `SECURITY.md` required by the NVIDIA Skills Publishing Onboarding contract.

The skills themselves are documentation. The repository also carries a
separately qualified read-only MCP plugin and an opt-in private-review operator,
so structural qualification covers both Markdown behavior and executable plugin
contracts. The grading rubric is deliberately strict: the bundle's job is to
keep agents from inventing symbols, paths, flags, or subcommands, and from
skipping safety-relevant preconditions.

## What is measured

Two orthogonal axes:

| Axis | What it measures | How it runs |
| --- | --- | --- |
| **A. Structural regression** | The bundle still satisfies every declared contract (skill structure, links and anchors, public-source URLs, frontmatter `kind`, AgentSkills.io validity, non-goal routing, JTBD coverage, plugin qualification, and publishing readiness). | The manifest-driven suite runs every required static gate and reports any optional or post-evaluation gate separately; a skip is never printed as an all-gates pass. |
| **B. Per-skill end-to-end agent behavior** | A real AI agent is handed the bundle and one end-to-end prompt per shipping skill. A separate strict grader subagent then grades the response on 5 dimensions against the bundle's authoritative skill files. | Generator + per-prompt agent dispatch + per-response grader dispatch + aggregation. Same internal pipeline as Axis A. |

Both axes run from the same source-of-truth bundle layout (`AGENTS.md`,
`SKILLS.md`, `skills/<kind>/<name>/{SKILL,CAPABILITIES,TASKS}.md`).

## Structural regression contract (Axis A)

The qualification harness's versioned gate manifest is the source of truth.
Missing required
implementations or required environment tools fail closed. The public claim is
checked against that manifest on every run.

| Gate ID | Contract | Execution |
| --- | --- | --- |
| `keystone-self-test` | The gate-checks-the-gate fixture | Optional locally/CI; required for release |
| `structural-keystones` | Constant-grader structural prerequisites | Required static |
| `skill-conformance` | Per-skill structure and public-source rules | Required static |
| `doca-inventory` | Bundle/DOCA source inventory alignment | Required in CI/release |
| `crosslinks` | Relative file and anchor integrity | Required static |
| `anchor-density` | Required workflow anchors | Required static |
| `catalog-coverage` | Catalog, prompt, and discoverability coverage | Required static |
| `jtbd-coverage` | Jobs-to-be-done coverage | Periodic optional input; required for release |
| `gate-documentation-consistency` | This table resolves exactly to the manifest | Required static |
| `worktree-hygiene` | Generated-root allowlist and build/scan path containment | Required static |
| `quality-schema-validation` | Current/prior evidence schemas and negative fixtures | Required static |
| `eval-validity` | Complete label-free eval kinds, hard set, wrong-context arm, and grader fixtures | Required static |
| `benchmark-evidence` | Post-sign evidence has its source dataset, matching task count, PASS verdict, and the NVCARPS-recorded attempt count | Required post-sign |
| `skill-quality-report` | Generated 60-skill scorecard, context analysis, and HTML dashboard | Required static |
| `advisory-agent-policy` | Classification routing, budgets, denials, checkpoints, and human interrupt | Required static |
| `public-surface-invariants` | Five publish-surface invariants | Required static |
| `public-mirror-boundary` | Exact allowlisted mirror has no private/plugin paths or hygiene findings | Required static and release |
| `live-hardware-harness` | Read-only live-hardware adapter fixtures | Required static |
| `agentskills-io-compliance` | Agent Skills frontmatter and layout contract | Required static |
| `non-goal-routing` | Live externally-productized routing table (currently 26 product rows) and public count | Required static |
| `reference-hygiene` | No internal paths, audit history, or private references | Required static |
| `url-liveness` | Full public URL GET validation | Required in CI/release; network-declared locally |
| `nvskills-readiness` | NVIDIA Skills publishing artifacts | Required static |
| `plugin-source-verification` | Plugin unit, security, dependency, and source-coverage checks | Required pre-sign |
| `plugin-verification` | Signed plugin/operator build, reproducibility, install, and security | Required post-sign |
| `plugin-mutation` | Fixed security-mutant catalog with a 100% current baseline | Nightly/opt-in; required for release |
| `frontmatter-kind` | `libs→library`, `services→service`, `tools→tool` | Required static |
| `jenkinsfile-budget-and-syntax` | Groovy parse plus frozen monolith line budget | Required static |
| `deep-e2e-generate` | Deterministic prompt/grader generation for every skill | Required static |
| `no-regression` | Comparable post-evaluation evidence has no blocking regression | Required post-evaluation |
| `eval-replay-regression` | Candidate replay has no decisive failure (a task passing zero of its attempts), no hard veto, no unsound evidence, and no bundle pass-rate drop against the frozen baseline | Required post-evaluation; tasks that pass some attempts but not a majority are recorded as unstable and also block under `release` |

## Release evidence policy

- This release candidate is qualified against `devops-ai` harness commit
  `dabc13523ba604f8843e3993014df2f369300828` on `main`.
- `skill-card.md` is the required canonical card for every skill. A signer may
  also generate `SKILLCARD.yaml`; its presence does not replace the canonical
  card and does not widen the public allowlist.
- Private plugin source and artifacts remain in the private repository. The
  public mirror copies only the explicit allowlist and rejects every plugin
  path until a separate official signing approval and allowlist review.
- Missing behavioral evidence is reported as `NOT_MEASURED`, never inferred as
  a pass from deterministic or signing checks.

## Per-skill end-to-end behavior (Axis B)

For each shipping skill, the deep E2E suite generates:

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

The current generated inventory is 60 skills: 13 cross-cutting and 47 product
skills (27 libraries, 4 services, 16 tools). Historical measurements used a
different inventory and leaked labels in some prompts, so they are retained as
historical evidence but are not treated as a comparable current baseline.
Until the regenerated hard set and calibrated grader run, current behavioral
status is `NOT_MEASURED`, not an inferred pass.

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
| Public DOCA inventory | The bundle aligns only to the publicly released DOCA `3.3.0109` documentation set. | Validated against the versioned public inventory sourced from the DOCA Libraries, Services, and Tools indexes; unreleased source trees are never used as publication inputs. |
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
