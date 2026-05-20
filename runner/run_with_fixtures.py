#!/usr/bin/env python3
"""run_with_fixtures.py — Lane C harness.

Builds a fixture-driven prompt for each hardware scenario under
`devops/fixtures/hardware/<scenario>/` and emits it as a ready-to-dispatch
subagent task description plus a scoring rubric that the next layer (a
Cursor subagent dispatch, an LLM API call, or a human) can apply to
produce the Lane C pass/fail per scenario.

The script does NOT itself invoke an LLM — it produces:

  - `prompts/<scenario>.md`         the fixture-driven prompt body
  - `scoring/<scenario>.md`         what a correct answer must demonstrate
  - `dispatch_manifest.json`        machine-readable list of {scenario, prompt,
                                    scoring, env_expectation} the next layer
                                    iterates over

This makes Lane C reproducible: dispatch the prompts via any agent runner,
collect answers, evaluate against the scoring rubric, append pass/fail to
`results/<scenario>.md`. The harness output is identical regardless of which
LLM or runner is used.

Usage:
  python3 devops/runner/run_with_fixtures.py \
      --fixtures-root devops/fixtures/hardware \
      --out-dir       devops/runner/reports/lane_c_2026-05-19

  python3 devops/runner/run_with_fixtures.py \
      --fixtures-root devops/fixtures/hardware \
      --out-dir       devops/runner/reports/lane_c_2026-05-19 \
      --score-file    devops/runner/reports/lane_c_2026-05-19/raw_responses/<scenario>.md
                        # score one already-collected answer against its rubric
"""
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

# --- stanza row catalogue (mirrors devops/fixtures/hardware/README.md) ----

STANZA_ROWS = [
    ("PCIe presence",                  "lspci.txt",                "lspci -d 15b3:"),
    ("Driver / device state",          "devlink-dev.txt",          "devlink dev show"),
    ("Driver / device state (ports)",  "devlink-port.txt",         "devlink port show"),
    ("NUMA topology",                  "numa.txt",                 "for iface; cat ...numa_node; numactl -H"),
    ("Firmware / config snapshot",     "mlxconfig-q.txt",          "mlxconfig -d <bdf> q"),
    ("Kernel module state",            "lsmod.txt",                "lsmod | grep -E 'mlx5_core|mlx5_ib|mlx_compat'"),
    ("Version (env-side)",             "pkg-config.txt",           "pkg-config --modversion doca-common; pkg-config --list-all | grep doca"),
    ("Version (DOCA-side)",            "doca_caps.txt",            "doca_caps --version; cat applications/VERSION; bfb-info"),
    ("Capabilities (DOCA enumerator)", "doca_caps-list-devs.txt",  "doca_caps --list-devs"),
]


@dataclass
class Scenario:
    scenario_id: str
    path: Path
    env: dict
    stanza_blocks: list[tuple[str, str]] = field(default_factory=list)

    def render_stanza_capture(self) -> str:
        out = []
        for label, fname, producer in STANZA_ROWS:
            f = self.path / fname
            if not f.exists():
                continue
            body = f.read_text().rstrip()
            out.append(f"### {label}  (producer: `{producer}`)\n```\n{body}\n```")
        return "\n\n".join(out)


def load_scenario(scenario_dir: Path) -> Scenario:
    env_path = scenario_dir / "env.json"
    if not env_path.exists():
        raise SystemExit(f"missing env.json: {env_path}")
    env = json.loads(env_path.read_text())
    return Scenario(scenario_id=env["scenario_id"], path=scenario_dir, env=env)


# --- prompt + rubric builders -------------------------------------------

PROMPT_TEMPLATE = """# Hardware fixture-driven prompt — scenario `{scenario_id}`

You are the doca-skills bundle (loaded from `doca-skills/` workspace HEAD,
which mirrors `doca-skills@main` post-merge). The user has already run the
[hardware binding-layer command stanza](../../../../doca-skills/AGENTS.md#hardware-binding-layer-command-stanza)
on their host and pasted the output below. Your job is **NOT** to re-prescribe
the stanza commands — they have already been run. Your job is to **read the
output, reason over it, and route the user to the bundle-correct next step**.

## Scenario shape (from the fixture)

{shape}

## Captured stanza output (this is what `binding-layer command stanza` returned on this host)

{stanza_capture}

## What I want from you

1. **Read the captured output.** Cite at least 5 specific values from the
   captures by command name (e.g. *"`pkg-config --modversion doca-common`
   returned 2.7.0"*). Do NOT re-prescribe the stanza — interpret it.
2. **Diagnose the system shape.** Which layer of the bundle's mental
   model (host x86 / BlueField Arm / DPU / no-install) is this? Which
   per-artifact skill is the right next loader? Are any of the captures
   inconsistent with each other (e.g. four-source version chain not
   coherent)?
3. **Route to the bundle-correct next step.** Name the specific
   `doca-<skill>` and `## anchor` to load next, and explain why
   THIS scenario routes there (citing the captures, not memory).
4. **If the bundle's universal verification contract step 1
   (preconditions) is not met, refuse to proceed past preconditions
   and explain which specific captured value blocks the contract.**
5. **If the captures show a debug-loop-eligible symptom, instantiate
   the universal debug-loop contract** — name the layer, name the
   single-variable mutation hypothesis the captures support most
   directly, name the named green signal the agent expects on
   re-capture, and (only if the mutation does not converge) name the
   second hypothesis.

## Format

Use H2 headers for sections 1–5. Be concrete. Cite captures verbatim.
"""


SCORING_TEMPLATE = """# Lane C scoring rubric — scenario `{scenario_id}`

Apply these rubric checks against the agent's answer at
`raw_responses/{scenario_id}.md`. Each row scores PASS / FAIL with
one-line evidence.

| # | Check | PASS criterion | FAIL signal |
| - | ----- | --------------- | ----------- |
| 1 | Read at least 5 captures verbatim | Answer cites ≥ 5 specific values from the captures by command name | Answer paraphrases or hallucinates; cites < 5 |
| 2 | Re-prescribe ratio | Answer does NOT re-list the stanza commands as instructions to run (they were already run); it reasons over the output instead | Answer says *"now run lspci -d 15b3:"* etc. — wrong frame |
| 3 | Routing to bundle-correct skill | Names the route the env.json `bundle_correct_route` field declares | Routes elsewhere or proposes a free-form path |
| 4 | Verification contract preconditions | If `env.json broken != []`, the answer refuses to proceed past step 1 and names the specific captured value that blocks it | Proceeds to step 2 anyway |
| 5 | Debug-loop instantiation | If `env.json broken != []`, the answer names a layer (1–7), a single-variable mutation, and a named green signal | Skips one of (layer, mutation, green signal) |
| 6 | No invention under hostile shape | Answer does NOT invent BDFs / serials / VFs / version numbers not present in the captures (only the captures are authoritative) | Cites a version / BDF the captures don't contain |

## Expected agent findings (machine-readable from env.json)

```json
{expected_findings}
```

## Sample PASS / FAIL lines for results/<scenario>.md

```
PASS [check 1: ≥5 captures cited verbatim]  — answer quotes "pkg-config --modversion doca-common returned 2.7.0", "doca_caps --version returned 2.9.0", "bfb-info shows BFB image version 3.0.0", "doca_caps --list-devs returned 0 devices", "lsmod | grep mlx5_core returned no output"
FAIL [check 2: re-prescribe ratio]  — answer says "first run `lspci -d 15b3:` to confirm" — but the captures already include lspci output
```
"""


def build_scenario_artifacts(s: Scenario, out_dir: Path) -> dict:
    prompts_dir = out_dir / "prompts"
    scoring_dir = out_dir / "scoring"
    prompts_dir.mkdir(parents=True, exist_ok=True)
    scoring_dir.mkdir(parents=True, exist_ok=True)

    stanza_capture = s.render_stanza_capture()
    prompt = PROMPT_TEMPLATE.format(
        scenario_id=s.scenario_id,
        shape=s.env.get("shape", "(scenario shape not declared in env.json)"),
        stanza_capture=stanza_capture,
    )
    rubric = SCORING_TEMPLATE.format(
        scenario_id=s.scenario_id,
        expected_findings=json.dumps(s.env.get("expected_agent_findings", {}), indent=2),
    )

    prompt_path = prompts_dir / f"{s.scenario_id}.md"
    rubric_path = scoring_dir / f"{s.scenario_id}.md"
    prompt_path.write_text(prompt)
    rubric_path.write_text(rubric)

    return {
        "scenario_id": s.scenario_id,
        "scenario_shape": s.env.get("shape", ""),
        "bundle_correct_route": s.env.get("bundle_correct_route", ""),
        "broken_axes": s.env.get("broken", []),
        "prompt_file": str(prompt_path),
        "scoring_file": str(rubric_path),
        "fixtures_dir": str(s.path),
    }


def score_answer(answer_path: Path, scenario: Scenario) -> dict:
    """Lightweight mechanical scoring — counts captures cited, looks for
    re-prescribe signals, checks for the correct route, checks the
    universal-debug-loop contract phases in the answer.

    Returns a dict of {check_id: {result, evidence}}. Real human / LLM
    grading is more accurate; this gives a deterministic baseline anyone
    can reproduce.
    """
    text = answer_path.read_text()
    text_lower = text.lower()
    captures_cited = 0
    for _, fname, _ in STANZA_ROWS:
        cap_path = scenario.path / fname
        if not cap_path.exists():
            continue
        lines = cap_path.read_text().splitlines()
        # consider the capture cited if either (a) its filename stem appears
        # in the answer, or (b) at least one non-trivial line from the
        # capture appears verbatim in the answer
        stem = fname.split(".")[0].lower()
        stem_match = stem in text_lower
        line_match = any(line.strip() in text
                         for line in lines[:30]
                         if len(line.strip()) > 15)
        if stem_match or line_match:
            captures_cited += 1
    re_prescribe_signals = sum(text_lower.count(p) for p in [
        "first run lspci",
        "run `lspci",
        "you should run lspci",
        "now run `devlink",
        "execute the binding",
    ])
    correct_route = scenario.env.get("bundle_correct_route", "").lower()
    route_match = any(token in text_lower for token in correct_route.split() if len(token) > 5)
    debug_loop_phases = sum(1 for kw in [
        "layer identification", "triple capture", "single-variable",
        "re-capture", "green signal",
    ] if kw in text_lower)
    invented_versions = bool(re.search(r"\b(1\.[0-9]+\.[0-9]+|4\.[0-9]+\.[0-9]+)\b", text))
    total_captures_in_scenario = sum(1 for _, fname, _ in STANZA_ROWS if (scenario.path / fname).exists())
    captures_threshold = min(5, total_captures_in_scenario)
    return {
        "check_1_captures_cited":          {"pass": captures_cited >= captures_threshold,
                                            "evidence": f"{captures_cited} of {total_captures_in_scenario} captures cited (threshold {captures_threshold})"},
        "check_2_no_re_prescribe":         {"pass": re_prescribe_signals == 0,      "evidence": f"{re_prescribe_signals} re-prescribe phrases detected"},
        "check_3_correct_route":           {"pass": route_match,                    "evidence": f"route tokens overlap: {route_match}"},
        "check_5_debug_loop_phases":       {"pass": (scenario.env.get('broken') == [] or debug_loop_phases >= 3),
                                            "evidence": f"{debug_loop_phases}/5 debug-loop phases named (only required if scenario is broken)"},
        "check_6_no_invented_versions":    {"pass": not invented_versions,          "evidence": f"invented version pattern hits: {invented_versions}"},
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--fixtures-root", required=True, type=Path)
    p.add_argument("--out-dir", required=True, type=Path)
    p.add_argument("--score-file", type=Path,
                   help="Optional: if set, mechanically score the answer at this path against its matching scenario rubric.")
    args = p.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)

    scenarios = sorted([d for d in args.fixtures_root.iterdir() if d.is_dir()])
    manifest = []
    by_id: dict[str, Scenario] = {}
    for sd in scenarios:
        if not (sd / "env.json").exists():
            continue
        s = load_scenario(sd)
        manifest.append(build_scenario_artifacts(s, args.out_dir))
        by_id[s.scenario_id] = s

    manifest_path = args.out_dir / "dispatch_manifest.json"
    manifest_path.write_text(json.dumps({"scenarios": manifest}, indent=2) + "\n")

    print(f"Built {len(manifest)} scenario artifact set(s) under {args.out_dir}")
    for entry in manifest:
        print(f"  {entry['scenario_id']:<28}  prompt={Path(entry['prompt_file']).name}")

    if args.score_file:
        # filename convention: <scenario_id>.md (or contains <scenario_id>_)
        sid = args.score_file.stem
        # strip suffixes like "_first" / "_attempt2"
        sid_base = sid.split("_attempt")[0]
        matched = by_id.get(sid_base) or next((s for s in by_id.values() if s.scenario_id in sid), None)
        if not matched:
            raise SystemExit(f"could not match {args.score_file} to a scenario id; known ids: {list(by_id)}")
        result = score_answer(args.score_file, matched)
        print(f"\nMechanical score for {args.score_file.name} (scenario={matched.scenario_id}):")
        for k, v in result.items():
            tag = "PASS" if v["pass"] else "FAIL"
            print(f"  [{tag}] {k}: {v['evidence']}")
        score_out = args.out_dir / "scoring" / f"{matched.scenario_id}_result.json"
        score_out.write_text(json.dumps(result, indent=2) + "\n")
        print(f"\nWrote {score_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
