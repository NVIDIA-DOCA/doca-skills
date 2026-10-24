# Skill Benchmark: doca-dts

> ✅ **Overall verdict: PASS — Recommended for publication**

## Publication Recommendation

Recommended for publication based on the completed evaluation evidence in this report.

## Evaluation Metadata

- Skill: `doca-dts`
- Evaluation date: 2026-10-24
- Evaluator version: `1.5.6`
- Agents: Claude Code (`aws/anthropic/bedrock-claude-opus-5-5`), Codex (`openai/openai/gpt-6.1-sol`)
- Tasks: 6 evaluation tasks (4 positive, 2 negative)
- Dataset digest: `sha256:1f0a5dec87b17e5f794f9aa7e1c80561854711f5e5b6fdd87c357e0f4a3b0a8c` (skill-evaluator-dataset-snapshot/1)
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
| Overall | 86.6% — baseline ran, but no comparable score was available; uplift unavailable | 79.6% — baseline ran, but no comparable score was available; uplift unavailable |
| Security | 91.7% → 100.0% (+8.3 points) | 91.7% → 83.3% (-8.4 points) |
| Correctness | 76.7% → 83.3% (+6.6 points) | 66.7% → 80.0% (+13.3 points) |
| Discoverability | 100.0% — baseline ran, but no comparable score was available; uplift unavailable | 95.0% — baseline ran, but no comparable score was available; uplift unavailable |
| Effectiveness | 38.3% → 68.3% (+30.0 points) | 48.9% → 73.6% (+24.7 points) |
| Efficiency | 81.1% — baseline ran, but no comparable score was available; uplift unavailable | 66.2% — baseline ran, but no comparable score was available; uplift unavailable |

**How to read this table:** baseline is the same task attempted without the target skill. Scores are rounded to one decimal; threshold-adjacent values use additional precision so their displayed band matches the verdict. Uplift is derived from those displayed scores and shown in percentage points.

Example: `47.0% → 92.0% (+45.0 points)` means the skill-assisted run scored 92.0%, 45.0 percentage points above its 47.0% no-skill baseline.

A partial dimension was calculated from only the available configured signals; review the detailed report before relying on it.

## Token Usage

Actual Tier 3 execution usage is reported for every observed agent/case pair and both conditions.

| Agent | Dataset case | With skill | Without skill | Delta | Change | Coverage |
|---|---|---:|---:|---:|---:|---|
| claude-code | All cases | 1,460,985 | 2,524,789 | -1,063,804 | -42.13% | skill 6/6; base 6/6 |
| claude-code | doca-dts.explicit-positive.v1 | 376,582 | 93,330 | +283,252 | +303.50% | skill 1/1; base 1/1 |
| claude-code | doca-dts.implicit-positive.v1 | 175,161 | 123,190 | +51,971 | +42.19% | skill 1/1; base 1/1 |
| claude-code | doca-dts.implicit-positive.v2 | 336,502 | 122,403 | +214,099 | +174.91% | skill 1/1; base 1/1 |
| claude-code | doca-dts.implicit-positive.v3 | 251,329 | 1,531,301 | -1,279,972 | -83.59% | skill 1/1; base 1/1 |
| claude-code | doca-dts.negative.v1 | 159,119 | 98,084 | +61,035 | +62.23% | skill 1/1; base 1/1 |
| claude-code | doca-dts.negative.v2 | 162,292 | 556,481 | -394,189 | -70.84% | skill 1/1; base 1/1 |
| codex | All cases | 729,041 | 424,117 | +304,924 | +71.90% | skill 6/6; base 6/6 |
| codex | doca-dts.explicit-positive.v1 | 125,522 | 58,703 | +66,819 | +113.83% | skill 1/1; base 1/1 |
| codex | doca-dts.implicit-positive.v1 | 121,290 | 30,761 | +90,529 | +294.30% | skill 1/1; base 1/1 |
| codex | doca-dts.implicit-positive.v2 | 109,675 | 30,944 | +78,731 | +254.43% | skill 1/1; base 1/1 |
| codex | doca-dts.implicit-positive.v3 | 157,194 | 45,710 | +111,484 | +243.89% | skill 1/1; base 1/1 |
| codex | doca-dts.negative.v1 | 43,226 | 61,147 | -17,921 | -29.31% | skill 1/1; base 1/1 |
| codex | doca-dts.negative.v2 | 172,134 | 196,852 | -24,718 | -12.56% | skill 1/1; base 1/1 |
| ALL AGENTS | Dataset aggregate | 2,190,026 | 2,948,906 | -758,880 | -25.73% | skill 12/12; base 12/12 |

Prompt tokens include cached reads, so total tokens are `prompt + completion` (cached is not added twice). The Efficiency score uses `(prompt - cached) + completion`. N/A means the relevant trajectory counters were not available; coverage is never estimated.

## Tier Status

| Tier | Purpose | Status | Evidence |
|---|---|---|---|
| Tier 1 | Static validation | **PASSED WITH OBSERVATIONS** | 11 validator(s); 21 finding(s) |
| Tier 2 | Semantic deduplication | **PASSED WITH OBSERVATIONS** | 2 validator(s); 1 finding(s) |
| Tier 3 | Live agent evaluation | **PASS** | 2 agent(s); 6 task(s) |

## Findings and Observations

<details>
<summary>Show detailed findings and successful checks</summary>

- **CRITICAL** CONTENT_DEDUP/llm_error: LLM analysis failed for a content cluster (`skills/services/doca-dts`)
- **MEDIUM** QUALITY/quality_correctness: SKILL_SPEC recommended field missing: 'metadata.author' (`skills/services/doca-dts/SKILL.md`)
- **MEDIUM** QUALITY/quality_correctness: SKILL_SPEC recommended field missing: 'metadata.tags' (`skills/services/doca-dts/SKILL.md`)
- **MEDIUM** SCHEMA/metadata_key_style: Metadata key 'doca_version' is not kebab-case (`skills/services/doca-dts/SKILL.md`)
- **MEDIUM** SCHEMA/folder_hierarchy: Unexpected nesting depth for general skill (`skills/services/doca-dts`)
- 17 additional finding(s) are available in the full evaluation artifacts.

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
- `token_efficiency` (Token Efficiency): actual uncached prompt plus completion usage (50% of Efficiency).

</details>

## Freshness

Regenerate this benchmark when the skill, evaluation dataset, target agent/model, evaluator version, environment, or scoring policy changes.
