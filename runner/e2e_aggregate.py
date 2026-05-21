#!/usr/bin/env python3
"""e2e_aggregate.py — collect grades/<art>.json into aggregate.json + a summary.

Companion to `runner/e2e_generate.py`. Once the operator has dispatched the
agent + grader per artifact and populated `grades/<art>.json`, this script:

  1. Walks index.json + grades/ and produces aggregate.json with rows
     {artifact, kind, D1..D5, verdict_overall, blocker_findings, ...}.
  2. Computes pass-rate, blocker count, med count.
  3. Writes a human-readable summary.md the CI step archives + comments on
     the PR.
  4. Exits non-zero iff blockers_total > 0 OR pass_rate < --min-pass-rate
     (default 1.0 — the project rule is "no regression, every commit
     improves or at least does not damage").

Use:
  python3 runner/e2e_aggregate.py \\
      --suite-dir /tmp/e2e \\
      --min-pass-rate 1.0
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path


def load_grade(path: Path) -> dict | None:
    """Tolerate graders that wrap the JSON in Markdown fences."""
    raw = path.read_text(encoding="utf-8", errors="replace").strip()
    if raw.startswith("```"):
        # strip fenced code block
        raw = "\n".join(raw.splitlines()[1:-1] if raw.endswith("```") else raw.splitlines()[1:])
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # Try to recover by extracting the first {...} block.
        depth = 0
        start = raw.find("{")
        if start < 0:
            return None
        for i in range(start, len(raw)):
            if raw[i] == "{":
                depth += 1
            elif raw[i] == "}":
                depth -= 1
                if depth == 0:
                    try:
                        return json.loads(raw[start:i+1])
                    except json.JSONDecodeError:
                        return None
        return None


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--suite-dir", required=True, type=Path,
                   help="The directory `runner/e2e_generate.py` populated "
                        "(must contain index.json + grades/).")
    p.add_argument("--min-pass-rate", type=float, default=1.0,
                   help="Minimum overall pass rate before exit 2 (default 1.0 = 100%%, "
                        "matches the project's no-regression rule).")
    p.add_argument("--allow-missing-grades", action="store_true",
                   help="Treat artifacts without a grades/<art>.json as MISSING rather than FAIL. "
                        "Useful for partial CI runs where the dispatcher hasn't completed yet.")
    args = p.parse_args()

    suite_dir = args.suite_dir.resolve()
    index_path = suite_dir / "index.json"
    grades_dir = suite_dir / "grades"
    if not index_path.exists():
        print(f"ERROR: {index_path} not found. Run runner/e2e_generate.py first.",
              file=sys.stderr)
        return 2
    catalog = json.loads(index_path.read_text())

    rows: list[dict] = []
    missing: list[str] = []
    parse_failed: list[str] = []
    for entry in catalog:
        art = entry["art"]
        grade_path = grades_dir / f"{art}.json"
        if not grade_path.exists():
            missing.append(art)
            if not args.allow_missing_grades:
                rows.append({
                    "artifact": art,
                    "kind": entry.get("kind"),
                    "verdict_overall": "MISSING",
                    "blocker_findings": ["no grade file"],
                    "med_findings": [],
                    "low_findings": [],
                })
            continue
        grade = load_grade(grade_path)
        if grade is None:
            parse_failed.append(art)
            rows.append({
                "artifact": art,
                "kind": entry.get("kind"),
                "verdict_overall": "PARSE_FAIL",
                "blocker_findings": ["grader response could not be parsed as JSON"],
                "med_findings": [],
                "low_findings": [],
            })
            continue
        grade["_art"] = art
        if "artifact" not in grade:
            grade["artifact"] = art
        if "kind" not in grade:
            grade["kind"] = entry.get("kind")
        rows.append(grade)

    overall_total = len(rows)
    overall_pass = sum(1 for r in rows if r.get("verdict_overall") == "PASS")
    blockers_total = sum(len(r.get("blocker_findings", []) or []) for r in rows)
    med_total = sum(len(r.get("med_findings", []) or []) for r in rows)
    # If we're in --allow-missing-grades AND no artifact has yet been graded,
    # the aggregator has nothing to assess — that's a "generate-only" or
    # "dispatch still in flight" run, not a regression. Skip the pass-rate
    # gate in that case so the caller can use the generated artifacts
    # without the gate spuriously failing the build.
    skip_pass_gate = bool(args.allow_missing_grades and overall_total == 0)

    aggregate = {
        "rows": rows,
        "overall_pass_rate_text": f"{overall_pass}/{overall_total}",
        "overall_pass_rate":      (overall_pass / overall_total) if overall_total else 0.0,
        "blockers_total": blockers_total,
        "med_total": med_total,
        "missing":     missing,
        "parse_failed": parse_failed,
    }

    (suite_dir / "aggregate.json").write_text(
        json.dumps(aggregate, indent=2) + "\n", encoding="utf-8")

    # by-kind breakdown
    by_kind = Counter()
    pass_by_kind = Counter()
    for r in rows:
        by_kind[r.get("kind")] += 1
        if r.get("verdict_overall") == "PASS":
            pass_by_kind[r.get("kind")] += 1

    lines = []
    lines.append("# Deep E2E suite — aggregate summary")
    lines.append("")
    lines.append(f"- Overall:     {overall_pass}/{overall_total} PASS "
                 f"({aggregate['overall_pass_rate']:.0%})")
    lines.append(f"- Blockers:    {blockers_total}")
    lines.append(f"- MED gaps:    {med_total}")
    if missing:
        lines.append(f"- Missing grades ({len(missing)}): {', '.join(missing)}")
    if parse_failed:
        lines.append(f"- Parse-failed grades ({len(parse_failed)}): {', '.join(parse_failed)}")
    lines.append("")
    lines.append("## By kind")
    for k in sorted(by_kind.keys()):
        lines.append(f"- {k}: {pass_by_kind[k]}/{by_kind[k]} PASS")
    lines.append("")
    lines.append("## Per-artifact verdicts")
    for r in rows:
        art = r.get("artifact", "?")
        verdict = r.get("verdict_overall", "?")
        blocker_n = len(r.get("blocker_findings") or [])
        med_n = len(r.get("med_findings") or [])
        marker = "✅" if verdict == "PASS" else ("❌" if verdict in ("FAIL", "MISSING", "PARSE_FAIL") else "?")
        lines.append(f"- {marker} `{art}` ({r.get('kind', '?')}): {verdict} "
                     f"[blockers={blocker_n}, med={med_n}]")
    (suite_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("\n".join(lines[:8]))
    print(f"\nWrote {suite_dir / 'aggregate.json'} and {suite_dir / 'summary.md'}.")

    if blockers_total > 0:
        print(f"\nFAIL: {blockers_total} blocker finding(s) across {sum(1 for r in rows if r.get('blocker_findings'))} artifact(s). "
              f"Project rule: no regression — every commit improves or at least does not damage.",
              file=sys.stderr)
        return 2
    if skip_pass_gate:
        print("\nNOTE: --allow-missing-grades AND no artifact graded yet; "
              "pass-rate gate skipped. Treat this as a 'generate / partial' "
              "run, not a regression check.", file=sys.stderr)
        return 0
    pass_rate = aggregate["overall_pass_rate"]
    if pass_rate < args.min_pass_rate:
        print(f"\nFAIL: pass-rate {pass_rate:.0%} below --min-pass-rate {args.min_pass_rate:.0%}.",
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
