# Skill Benchmark: doca-perftest

> ✅ **Overall verdict: PASS — Recommended for publication**

## Publication Recommendation

Recommended for publication based on the completed evaluation evidence in this report.

## Evaluation Metadata

- Skill: `doca-perftest`
- Evaluation date: 2026-10-24
- Evaluator version: `1.5.6`
- Agents: Claude Code (`aws/anthropic/bedrock-claude-opus-5-5`), Codex (`openai/openai/gpt-6.1-sol`)
- Tasks: 5 evaluation tasks (4 positive, 1 negative)
- Dataset digest: `sha256:16d2f423b7376e1445ab440eb3b6b4b6275ff4baf5bb70b10319618ba118cc02` (skill-evaluator-dataset-snapshot/1)
- Attempts per task: 1
- Environment: `k8s-sandbox`
- Tier 2 evidence: required for publication
- Tier 3 evidence: required for publication

Each task attempt ran in its own isolated sandbox pod.

## What This Report Answers

The three-tier evaluation checks whether the skill:

- is safe to use;
- produces correct answers;
- is discovered and activated when needed;
- helps the agent complete the user's goal and expected workflow; and
- avoids wasted skill and tool usage.

## Results at a Glance

| Measure | Claude Code (Baseline → Skill Uplift) | Codex (Baseline → Skill Uplift) |
|---|---:|---:|
| Overall | 87.7% — baseline ran, but no comparable score was available; uplift unavailable | 79.2% — baseline ran, but no comparable score was available; uplift unavailable |
| Security | 100.0% → 100.0% (±0.0 points) | 100.0% → 100.0% (±0.0 points) |
| Correctness | 52.0% → 96.0% (+44.0 points) | 72.0% → 100.0% (+28.0 points) |
| Discoverability | 85.0% — baseline ran, but no comparable score was available; uplift unavailable | 81.3% — baseline ran, but no comparable score was available; uplift unavailable |
| Effectiveness | 31.5% → 78.5% (+47.0 points) | 53.0% → 75.5% (+22.5 points) |
| Efficiency | 79.2% — baseline ran, but no comparable score was available; uplift unavailable | 39.2% — baseline ran, but no comparable score was available; uplift unavailable |

**How to read this table:** baseline is the same task attempted without the target skill. Scores are rounded to one decimal; threshold-adjacent values use additional precision so their displayed band matches the verdict. Uplift is derived from those displayed scores and shown in percentage points.

Example: `47.0% → 92.0% (+45.0 points)` means the skill-assisted run scored 92.0%, 45.0 percentage points above its 47.0% no-skill baseline.

A partial dimension was calculated from only the available configured signals; review the detailed report before relying on it.

## Token Usage

Actual Tier 3 execution usage is reported for every observed agent/case pair and both conditions.

| Agent | Dataset case | With skill | Without skill | Delta | Change | Coverage |
|---|---|---:|---:|---:|---:|---|
| claude-code | All cases | 717,668 | 718,824 | N/A | N/A | skill 4/5; base 4/5 |
| claude-code | doca-perftest.explicit-positive.v1 | 166,115 | 94,822 | +71,293 | +75.19% | skill 1/1; base 1/1 |
| claude-code | doca-perftest.implicit-positive.v1 | 329,952 | 372,448 | -42,496 | -11.41% | skill 1/1; base 1/1 |
| claude-code | doca-perftest.implicit-positive.v2 | N/A | N/A | N/A | N/A | skill 0/1; base 0/1 |
| claude-code | doca-perftest.negative.v1 | 95,525 | 99,812 | -4,287 | -4.30% | skill 1/1; base 1/1 |
| claude-code | doca-perftest.negative.v2 | 126,076 | 151,742 | -25,666 | -16.91% | skill 1/1; base 1/1 |
| codex | All cases | 263,074 | 267,826 | N/A | N/A | skill 4/5; base 4/5 |
| codex | doca-perftest.explicit-positive.v1 | 71,200 | 57,356 | +13,844 | +24.14% | skill 1/1; base 1/1 |
| codex | doca-perftest.implicit-positive.v1 | N/A | N/A | N/A | N/A | skill 0/1; base 0/1 |
| codex | doca-perftest.implicit-positive.v2 | 113,121 | 86,197 | +26,924 | +31.24% | skill 1/1; base 1/1 |
| codex | doca-perftest.negative.v1 | 34,979 | 53,297 | -18,318 | -34.37% | skill 1/1; base 1/1 |
| codex | doca-perftest.negative.v2 | 43,774 | 70,976 | -27,202 | -38.33% | skill 1/1; base 1/1 |
| ALL AGENTS | Dataset aggregate | 980,742 | 986,650 | N/A | N/A | skill 8/10; base 8/10 |

Prompt tokens include cached reads, so total tokens are `prompt + completion` (cached is not added twice). The Efficiency score uses `(prompt - cached) + completion`. N/A means the relevant trajectory counters were not available; coverage is never estimated.

## Tier Status

| Tier | Purpose | Status | Evidence |
|---|---|---|---|
| Tier 1 | Static validation | **PASSED WITH OBSERVATIONS** | 11 validator(s); 13 finding(s) |
| Tier 2 | Semantic deduplication | **PASSED WITH OBSERVATIONS** | 2 validator(s); 2 finding(s) |
| Tier 3 | Live agent evaluation | **PASS** | 2 agent(s); 5 task(s) |

## Findings and Observations

<details>
<summary>Show detailed findings and successful checks</summary>

- **CRITICAL** CONTENT_DEDUP/llm_error: LLM analysis failed for a content cluster (`skills/tools/doca-perftest`)
- **HIGH** DUPLICATE/duplicate: Duplicate content found across CAPABILITIES.md and TASKS.md:
  "## Drivers" in CAPABILITIES.md (lines 23-29)
  vs "## select-driver" in TASKS.md (lines 31-37) (`CAPABILITIES.md:23`)
- **MEDIUM** QUALITY/quality_discoverability: Description uses first/second person (`skills/tools/doca-perftest/SKILL.md`)
- **MEDIUM** SCHEMA/metadata_key_style: Metadata key 'doca_version' is not kebab-case (`skills/tools/doca-perftest/SKILL.md`)
- **MEDIUM** SCHEMA/folder_hierarchy: Unexpected nesting depth for general skill (`skills/tools/doca-perftest`)
- 10 additional finding(s) are available in the full evaluation artifacts.

</details>

## Scoring Methodology

<details>
<summary>Show dimension definitions, source signals, and thresholds</summary>

| Dimension | Question | Scored signals |
|---|---|---|
| Security | Is it safe to use? | `security` (100%) |
| Correctness | Is the answer correct? | `accuracy` (100%) |
| Discoverability | Was the right skill loaded when needed? | `skill_execution` (100%) |
| Effectiveness | Did the skill help complete the task? | `goal_accuracy` (50%) + `behavior_check` (50%) |
| Efficiency | Did it avoid wasted tool calls and token usage? | `skill_efficiency` (50%) + `token_efficiency` (50%) |

- Dimension bands: PASS at 50% or above; NEUTRAL from 40% to below 50%; FAIL below 40%.
- Overall Tier 3 lift: PASS at +5 points or more; FAIL at -10 points or less; values between those bands are NEUTRAL.
- Overall verdict: PASS only when every configured dimension passes for at least one supported agent. Lift is reported as diagnostic evidence and does not override this gate.
- The 50% attempt pass threshold is a separate per-task gate; it is not the dimension pass threshold.
- Effectiveness is the equal-weight mean of goal completion (`goal_accuracy`) and expected workflow adherence (`behavior_check`).
- Efficiency is 50% tool-call productivity (the backward-compatible `skill_efficiency` wire id) and 50% `token_efficiency`. Positive-case skill routing is scored under Discoverability, not Efficiency; a negative case without a routing target is N/A. N/A sources are omitted, remaining weights are renormalized, and the dimension is marked partial.

Signals present in this run:

- `security` (Security): unsafe operations, secret leakage, and unauthorized access.
- `skill_execution` (Skill Execution): whether the expected skill was selected, decoys were avoided, and the workflow executed.
- `skill_efficiency` (Tool Productivity): tool-call productivity (legacy wire id; routing is scored under Discoverability).
- `accuracy` (Accuracy): final-answer correctness against the reference answer.
- `goal_accuracy` (Goal Accuracy): whether the user's goal was achieved.
- `behavior_check` (Behavior Check): whether the expected workflow behavior was followed.

</details>

## Freshness

Regenerate this benchmark when the skill, evaluation dataset, target agent/model, evaluator version, environment, or scoring policy changes.
