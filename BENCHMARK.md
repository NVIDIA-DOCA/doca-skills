# Benchmark

This document describes how the DOCA Agent Skills bundle measures itself: what
the test surface is, how it is graded, what counts as "green", and where the
artifacts live. It is the BENCHMARK.md companion to `LICENSE`, `CONTRIBUTING.md`,
and `SECURITY.md`.

The skills themselves are documentation. The grading rubric is deliberately strict: the bundle's job is to
keep agents from inventing symbols, paths, flags, or subcommands, and from
skipping safety-relevant preconditions.

## What is measured

Two orthogonal axes:

| Axis | What it measures | How it runs |
| --- | --- | --- |
| **A. Structural regression** | The bundle still satisfies every declared contract (skill structure, links and anchors, public-source URLs, frontmatter `kind`, AgentSkills.io validity, non-goal routing, JTBD coverage, plugin qualification, and publishing readiness). | The manifest-driven suite runs every required static gate and reports any optional or post-evaluation gate separately; a skip is never printed as an all-gates pass. |
| **B. Per-skill end-to-end agent behavior** | A real AI agent is handed the bundle and one end-to-end prompt per shipping skill. The response is graded on 5 dimensions against the bundle's authoritative skill files. | Each skill's prompt is run against an agent and the response is scored against the rubric below. |

Both axes run from the same source-of-truth bundle layout (`AGENTS.md`,
`SKILLS.md`, `skills/<kind>/<name>/{SKILL,CAPABILITIES,TASKS}.md`).

## Structural regression contract (Axis A)

Every change runs a versioned set of static checks before it can merge or
publish. They cover:

- skill structure and Agent Skills (AgentSkills.io) frontmatter compliance;
- relative links, anchors and required workflow sections;
- catalog, prompt and discoverability coverage;
- public-source rules: every URL is a public NVIDIA or standards page and
  resolves, and every DOCA API name, path and package matches the public
  DOCA release;
- the published file set and its hygiene;
- routing of the 25 externally-productized products out of the bundle.

After evaluation, a regression check blocks any change that makes a
previously passing task fail. Missing checks or tools fail closed.

## Release evidence policy

- `skill-card.md` is the required canonical card for every skill. A signer may
  also generate `SKILLCARD.yaml`; its presence does not replace the canonical
  card and does not widen the public allowlist.
- Missing behavioral evidence is reported as `NOT_MEASURED`, never inferred as
  a pass from deterministic or signing checks.

## Per-skill end-to-end behavior (Axis B)

For each shipping skill, the evaluation defines:

- A **prompt** that asks the agent to walk a complete end-to-end workflow for
  that artifact: confirm env, discover devices/capabilities, modify a real
  shipped sample, build/run/validate with a concrete observable, and lay down
  a first-failure ladder.
- A **grading rubric** that checks the response on five dimensions, each a
  hard PASS/FAIL:

  | Dim | What it tests | What FAIL looks like |
  | --- | --- | --- |
  | D1 invented_tokens | Every symbol, flag, subcommand, path, and pkg-config module is traceable to the bundle, AGENTS.md, or a real NVIDIA public doc. | Fabricated names (e.g. `--pipeline` on a tool that has no such flag, `_v1` suffix on a real symbol, `samples/gpunetio/` when the documented path differs). |
  | D2 sequence_correctness | Steps satisfy each other's preconditions; the 5-step contract is visibly walked. | Build before install, or skipping the discovery step. |
  | D3 validation_concreteness | Step 4 names a concrete observable tied to the artifact's semantics. | "Exit 0 / no error" alone. |
  | D4 debug_concreteness | Step 5 names 3 distinct layers each with a distinguishing symptom. | A single generic "rerun with `-vvv`" bullet. |
  | D5 consumer_concreteness | Step 3 points to a real shipped sample/config/unit/image. | Hand-rolled example invented from whole cloth. |

  A response passes only when it passes all five dimensions.

## Latest measurement

The current generated inventory is 53 skills: 12 cross-cutting and 41 product
skills (23 libraries, 5 services, 13 tools). Per-skill results are in each
skill's BENCHMARK.md.

## How to reproduce

Downstream consumers who want to reproduce the per-skill end-to-end measurement against their own agent can
do so directly from this repository:

1. Load this bundle into the target agent (`./install.sh --agent <agent>`).
2. For each shipping skill, dispatch the eval prompt from
   `skills/<kind>/<art>/evals/evals.json` to the agent.
3. Score the agent's response against the grading rubric (also in
   `evals/evals.json`).
4. Count a response as passing only when it passes all five dimensions.

Each skill's `evals/evals.json` holds the prompts, expected outputs and
assertions.

## Multi-environment coverage

The same suite is run in both of the operational environments the bundle
targets:

| Env | What changes | How it's covered |
| --- | --- | --- |
| Public DOCA inventory | The bundle aligns only to the publicly released DOCA documentation set for the aligned release. | Validated against the versioned inventory sourced from the DOCA Libraries, Services, and Tools indexes. |
| Without NVIDIA-internal sources (the customer's normal environment) | The bundle must be self-sufficient — no internal-only paths, no hostnames that resolve only inside NVIDIA, no references to files that only exist inside NVIDIA. | The reference-hygiene gate blocks any such reference; AgentSkills.io compliance gate blocks any unresolved reference. |
| BlueField hardware | The TMFIFO, RShim, apt-source, log-level, and `bf.cfg` claims must match the public BlueField documentation. | Hardware-facing claims are aligned to the public BlueField documentation. |

## Out of scope for this benchmark

- Single-agent latency or token count. The bundle is documentation; the agent
  vendor's runtime characteristics are not measured here.
- "How many skills does each agent discover" — that is a function of the
  agent's skill discovery model and is covered by `install.sh` per the
  per-agent install-path matrix in `README.md`, not by this benchmark.
- Skill *adoption* metrics (how often a skill triggers, customer satisfaction,
  bug-rate reduction). Those live downstream of publication and are measured after publication.
