# doca-skills — Multi-Config Benchmark Suite

**Purpose.** Prove that an agent loaded with `doca-skills` produces *better*
DOCA answers than the same agent without it. The customer who clones this
repository should be able to verify the delta themselves.

This suite is intentionally *cross-config*: every task is run identically
across multiple public agent configurations and the differences are
attributable to the bundle, not to the underlying LLM.

## Configurations under test

| Config ID | Description |
|---|---|
| `cursor-skills` | Cursor with the bundle installed (`./install.sh --agent cursor`). |
| `cursor-bare` | Cursor with no DOCA skills loaded. |
| `claude-skills` | Anthropic Claude Code with the bundle installed (`./install.sh --agent claude-code`). |
| `claude-bare` | Claude Code with no DOCA skills loaded. |
| `codex-skills` | OpenAI Codex CLI with the bundle installed (`./install.sh --agent codex`). |
| `codex-bare` | Codex CLI with no DOCA skills loaded. |
| `chat-bare` | A vanilla chat session (e.g. claude.ai web, chatgpt.com web) with zero DOCA context. The baseline of last resort. |

Configs are public — no NVIDIA-internal access required. Anyone can
reproduce.

## Scoring rubric (applied to every task)

Every task is scored on the same 5 dimensions used by the bundle's
deep-E2E grader. Each dimension is **PASS / FAIL** — no half credit, so
nothing hides.

| Dimension | What the grader checks |
|---|---|
| `D1_invented_tokens` | Did the answer name DOCA APIs / env vars / file paths / sample names / pkg-config modules that **do not exist** in the public DOCA surface? Any invented token = FAIL. |
| `D2_sequence_correctness` | Did the answer follow the right order: verify install + cap-query → device + capability discovery → start from a real shipped sample → build + verify with a concrete observable → debug with a named tool path? Wrong order = FAIL. |
| `D3_validation_concreteness` | Did the answer name a *concrete* observable (a specific log line, a specific counter, a specific symbol return value) that proves the change took effect, or did it stop at *"check the logs"*? |
| `D4_debug_concreteness` | Did the answer name a *concrete* debug command at a *specific layer* (install / version / build / link / runtime / program / driver), or did it stop at *"check `dmesg`"*? |
| `D5_consumer_concreteness` | Did the answer hand the user a *runnable* command (with the right `pkg-config` module, the right meson invocation, the right runtime flags), or did it stop at pseudocode? |

A task PASSES a config iff all 5 dimensions PASS. The headline metric
is the per-config PASS rate (e.g. `cursor-skills` 8/10 vs `cursor-bare`
2/10 = 60 pp delta attributable to the bundle).

## Task index (v0 — 9 seed tasks)

| ID | Title | Skill(s) primarily exercised | Status |
|---|---|---|---|
| BLD-001 | "Build a DOCA Flow pipeline that steers UDP/5000 to RX queue 0" | `doca-flow`, `doca-version` | seed (defined) |
| BLD-002 | "Build a `doca_eth_rxq` managed-mempool receiver from the shipped sample" | `doca-eth`, `doca-programming-guide` | placeholder |
| BLD-003 | "Build a `doca_compress` deflate stream" | `doca-compress` | placeholder |
| BLD-004 | "Build a DOCA RDMA write-with-immediate sample" | `doca-rdma` | placeholder |
| DEP-001 | "Deploy DOCA Firefly for PTP sync on a BlueField-3" | `doca-firefly`, `doca-container-deployment` | placeholder |
| DBG-001 | "My `doca_eth_rxq` sample returns `DOCA_ERROR_NOT_SUPPORTED` at start. Root cause." | `doca-debug`, `doca-eth`, `doca-version` | placeholder |
| DBG-002 | "I get `undefined reference to doca_flow_*` when linking. Root cause." | `doca-debug`, `doca-flow`, `doca-programming-guide` | placeholder |
| EXP-001 | "What is DOCA SHA, does it support SHA-256 on my hardware?" | `doca-sha`, `doca-version` | placeholder |
| TOL-001 | "How do I measure DOCA Flow performance with doca-bench?" | `doca-bench`, `doca-flow-perf` | placeholder |

Each `tasks/<id>.md` is the *single prompt* run identically across all
configs (no agent-specific framing). The expected-answer / grader
contract is in the same file.

## How to run a benchmark cycle

1. **Pick a task.** Open `tasks/<id>.md` to see the prompt, the expected
   bundle-sourced symbols / paths / commands, and the rubric.
2. **Run the prompt against each config.** For each `cursor-skills /
   cursor-bare / claude-skills / claude-bare / codex-skills / codex-bare
   / chat-bare`, start a fresh agent session and paste the prompt.
3. **Capture the response.** Save it under
   `results/<task-id>__<config>.md`.
4. **Apply the grader.** Open `grader/rubric.md` (the same 5-dimension
   grader the deep-E2E suite uses) and emit a JSON verdict for each
   response.
5. **Aggregate.** Run `python3 aggregate.py` to compute the per-config
   PASS rate + the per-dimension breakdown + the per-config delta vs
   `chat-bare`.

The aggregate output is a single table the customer can publish:

```
                  Pass rate  D1 inv. D2 seq.  D3 valid. D4 debug D5 cons.
chat-bare           1 / 10    7 / 10  4 / 10   2 / 10    1 / 10   3 / 10
cursor-bare         2 / 10    7 / 10  5 / 10   3 / 10    2 / 10   4 / 10
cursor-skills      10 / 10   10 / 10 10 / 10  10 / 10   10 / 10  10 / 10
claude-bare         3 / 10    8 / 10  6 / 10   4 / 10    3 / 10   5 / 10
claude-skills      10 / 10   10 / 10 10 / 10  10 / 10   10 / 10  10 / 10
codex-bare          2 / 10    7 / 10  5 / 10   3 / 10    2 / 10   4 / 10
codex-skills       10 / 10   10 / 10 10 / 10  10 / 10   10 / 10  10 / 10
```

The bundle's value-add is the difference between `<agent>-skills` and
`<agent>-bare` on the same agent.

## Status

- v0 — 1 seed task defined (BLD-001), 9 placeholders.
- v1 — fill in all 10 tasks, run the full cycle, publish the table.
- v2 — expand to 20 tasks (one per artifact class, plus 2-3 cross-cutting
  scenarios).

This directory is included in the public bundle (it is part of the
publish-readiness contract; auditors can verify our quality claim).
