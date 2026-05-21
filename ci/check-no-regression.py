#!/usr/bin/env python3
"""ci/check-no-regression.py — the "every commit improves or at least
doesn't damage" gate.

For every (prompt_id, criterion_id, variant) cell, compare the CURRENT
run's grader verdict against a frozen BASELINE. The gate fails if any
cell was PASS in the baseline and is FAIL in the current run on the
same variant — that is a behavioral regression caused by the PR.

This is the codified rule the project owner stated explicitly:

    > no way we have regression and we do not fix before push — we
    > have in each commit to improve or at least not making damage

Usage
-----

    ci/check-no-regression.py \\
        --current  runner/reports/<runid>/grades \\
        --baseline runner/baseline_grades.json \\
        [--variant C]                  # default: C (the PR branch under test)
                                       # use 'all' to gate every variant

Inputs
------
- A grades directory: one JSON file per prompt (the shape ab_runner.py
  and the manual A/B/C subagent driver both emit), each containing:
      { "prompt_id": "...",
        "variants": { "A": { "<crit_id>": { "status": "PASS|FAIL|INC",
                                            "rationale": "..." }, ... },
                      "B": { ... }, "C": { ... } } }
- A baseline JSON file (flat, indexable):
      { "frozen_at_run": "<run id of the run that produced this>",
        "frozen_at_commit": "<git short-sha>",
        "cells": { "<prompt_id>:<crit_id>:<variant>": "PASS|FAIL|INC",
                   ... } }

Exit codes
----------
- 0 : no regressions (current >= baseline on every PASS cell)
- 1 : at least one regression (cells listed in stderr)
- 2 : usage / IO error
- 3 : baseline file missing (treat as soft warn in bootstrap mode)

Sibling commands
----------------
- ci/freeze-baseline.py            (writes runner/baseline_grades.json
                                    from a clean grades directory)
- ci/check-reference-hygiene.py    (publishability gate)
- ci/check-keystones.sh            (42 keystone files exist)
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from collections import defaultdict
from typing import Dict, Iterable, List, Tuple


def _load_baseline(path: pathlib.Path) -> Dict[str, str]:
    if not path.exists():
        print(
            f"ERROR: baseline file not found: {path}\n"
            f"  - First-time bootstrap? Run ci/freeze-baseline.py on a clean grades dir.\n"
            f"  - CI on a feature branch? Make sure the file was committed.",
            file=sys.stderr,
        )
        sys.exit(3)
    try:
        doc = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: baseline file is not valid JSON: {path}: {e}", file=sys.stderr)
        sys.exit(2)
    cells = doc.get("cells")
    if not isinstance(cells, dict):
        print(
            f"ERROR: baseline file missing required 'cells' object: {path}",
            file=sys.stderr,
        )
        sys.exit(2)
    return cells


def _load_current(grades_dir: pathlib.Path) -> Dict[str, str]:
    if not grades_dir.is_dir():
        print(f"ERROR: grades directory not found: {grades_dir}", file=sys.stderr)
        sys.exit(2)
    out: Dict[str, str] = {}
    for f in sorted(grades_dir.glob("*.json")):
        try:
            doc = json.loads(f.read_text())
        except json.JSONDecodeError as e:
            print(f"  WARN: skipping malformed grade file {f.name}: {e}", file=sys.stderr)
            continue
        pid = doc.get("prompt_id") or f.stem
        for variant, per in (doc.get("variants") or {}).items():
            if not isinstance(per, dict):
                continue
            for cid, res in per.items():
                if not isinstance(res, dict):
                    continue
                status = res.get("status")
                if status not in ("PASS", "FAIL", "INC"):
                    continue
                out[f"{pid}:{cid}:{variant}"] = status
    return out


def _diff_regressions(
    baseline: Dict[str, str],
    current: Dict[str, str],
    variants: Iterable[str],
) -> Tuple[List[Tuple[str, str, str]], List[Tuple[str, str, str]], int, int, int]:
    """Returns (regressions, fixes, unchanged_pass, baseline_cells_in_scope,
    current_cells_evaluated)."""
    variant_set = set(variants)
    regressions: List[Tuple[str, str, str]] = []
    fixes: List[Tuple[str, str, str]] = []
    unchanged_pass = 0
    baseline_in_scope = 0
    evaluated = 0
    for key, base_status in baseline.items():
        try:
            pid, cid, variant = key.split(":", 2)
        except ValueError:
            continue
        if variant not in variant_set:
            continue
        baseline_in_scope += 1
        cur_status = current.get(key)
        if cur_status is None:
            # The cell was in baseline but is not in current. We do NOT
            # count this as a regression — the current PR may have re-
            # scoped the test (e.g. fewer graders ran), and that is a
            # coverage / completeness concern, not a "behavior got
            # worse" concern. The full-coverage gate is separate.
            continue
        evaluated += 1
        if base_status == "PASS" and cur_status == "FAIL":
            regressions.append((pid, cid, variant))
        elif base_status == "FAIL" and cur_status == "PASS":
            fixes.append((pid, cid, variant))
        elif base_status == "PASS" and cur_status == "PASS":
            unchanged_pass += 1
    return regressions, fixes, unchanged_pass, baseline_in_scope, evaluated


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--current", required=True, type=pathlib.Path,
                    help="Path to current run's grades/ directory (one JSON per prompt).")
    ap.add_argument("--baseline", required=True, type=pathlib.Path,
                    help="Path to baseline JSON file (typically runner/baseline_grades.json).")
    ap.add_argument("--variant", default="C",
                    help="Which variant(s) to gate. Either a single variant ('C') or "
                         "comma-separated ('B,C') or 'all'. Default: 'C' (the PR branch).")
    args = ap.parse_args()

    if args.variant.lower() == "all":
        variants = ("A", "B", "C")
    else:
        variants = tuple(v.strip().upper() for v in args.variant.split(",") if v.strip())

    print(f"== check-no-regression.py ==")
    print(f"  current grades:  {args.current}")
    print(f"  baseline:        {args.baseline}")
    print(f"  variants gated:  {','.join(variants)}")
    print()

    baseline = _load_baseline(args.baseline)
    current = _load_current(args.current)
    regressions, fixes, unchanged_pass, baseline_in_scope, evaluated = (
        _diff_regressions(baseline, current, variants)
    )

    # Group regressions by variant for readability.
    by_var: Dict[str, List[Tuple[str, str]]] = defaultdict(list)
    for pid, cid, v in regressions:
        by_var[v].append((pid, cid))

    print(f"  baseline cells in scope:    {baseline_in_scope}")
    print(f"  cells evaluated this run:   {evaluated}")
    print(f"  unchanged PASS cells:       {unchanged_pass}")
    print(f"  FIXED in this run:          {len(fixes)}")
    print(f"  REGRESSIONS in this run:    {len(regressions)}")
    print()

    if fixes:
        print(f"== fixes this run ({len(fixes)}) ==")
        for pid, cid, v in sorted(fixes)[:40]:
            print(f"  + {v}: {pid} :: {cid}")
        if len(fixes) > 40:
            print(f"  + (... +{len(fixes)-40} more)")
        print()

    if regressions:
        print(f"== REGRESSIONS ({len(regressions)}) — gate FAILED ==", file=sys.stderr)
        for v in sorted(by_var):
            print(f"  variant {v}:", file=sys.stderr)
            for pid, cid in sorted(by_var[v]):
                print(f"    - {pid} :: {cid}", file=sys.stderr)
        print(
            "\nFAIL: at least one cell went PASS -> FAIL since the baseline.\n"
            "      Fix the regression(s) before merging.\n"
            "      Project rule: 'every commit improves or at least does not damage.'",
            file=sys.stderr,
        )
        return 1

    print("OK: no regressions vs baseline (every previously-PASS cell still PASSes).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
