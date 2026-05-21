#!/usr/bin/env python3
"""ci/freeze-baseline.py — write runner/baseline_grades.json from a
clean grades directory.

Use this AFTER:
  1. a full A/B/C run is done,
  2. the no-regression gate is currently green (no PASS->FAIL since the
     previous baseline),
  3. AND every cell you intend to lock in has actually been graded
     (the gate is "no regressions on the cells we tested," not "we
     tested everything" — that's the coverage gate's job).

Locks in the current PASS / FAIL / INC table so the NEXT PR's
ci/check-no-regression.py compares against it.

Usage
-----
    ci/freeze-baseline.py \\
        --grades runner/reports/<runid>/grades \\
        --out    runner/baseline_grades.json \\
        [--variants C]           # default: all 3 (A, B, C) so the
                                 # baseline captures the full picture

The frozen file is small (a few KB), human-readable, and meant to be
committed to git as part of the same PR that produced the green run.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
from datetime import datetime, timezone


def _git_short_sha() -> str:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            capture_output=True, text=True, check=True,
        )
        return out.stdout.strip()
    except Exception:
        return "unknown"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--grades", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--variants", default="A,B,C",
                    help="Comma-separated variants to capture. Default: A,B,C.")
    ap.add_argument("--run-id", default=None,
                    help="Optional human-readable run id label to embed in the file.")
    args = ap.parse_args()

    if not args.grades.is_dir():
        print(f"ERROR: grades directory not found: {args.grades}", file=sys.stderr)
        return 2

    variant_set = {v.strip().upper() for v in args.variants.split(",") if v.strip()}
    cells: dict[str, str] = {}
    prompts_seen = 0
    for f in sorted(args.grades.glob("*.json")):
        try:
            doc = json.loads(f.read_text())
        except json.JSONDecodeError as e:
            print(f"  WARN: skipping malformed grade file {f.name}: {e}", file=sys.stderr)
            continue
        prompts_seen += 1
        pid = doc.get("prompt_id") or f.stem
        for variant, per in (doc.get("variants") or {}).items():
            if variant not in variant_set:
                continue
            if not isinstance(per, dict):
                continue
            for cid, res in per.items():
                if not isinstance(res, dict):
                    continue
                status = res.get("status")
                if status not in ("PASS", "FAIL", "INC"):
                    continue
                cells[f"{pid}:{cid}:{variant}"] = status

    run_id = args.run_id or args.grades.parent.name

    payload = {
        "frozen_at_utc": datetime.now(timezone.utc).isoformat(),
        "frozen_at_run": run_id,
        "frozen_at_commit": _git_short_sha(),
        "variants_in_scope": sorted(variant_set),
        "prompts_in_scope": prompts_seen,
        "cells": cells,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")

    n_pass = sum(1 for s in cells.values() if s == "PASS")
    n_fail = sum(1 for s in cells.values() if s == "FAIL")
    n_inc = sum(1 for s in cells.values() if s == "INC")
    print(f"OK: froze baseline -> {args.out}")
    print(f"    prompts:          {prompts_seen}")
    print(f"    variants:         {','.join(sorted(variant_set))}")
    print(f"    cells:            {len(cells)} (PASS={n_pass} FAIL={n_fail} INC={n_inc})")
    print(f"    frozen at commit: {payload['frozen_at_commit']}")
    print(f"    frozen at run:    {run_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
