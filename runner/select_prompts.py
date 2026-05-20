#!/usr/bin/env python3
"""select_prompts.py — diff-driven prompt selection for the 3-agent A/B.

Companion to ab_runner.py. Given a git base ref (usually "main") and a
prompts directory, prints to stdout the subset of prompt YAML paths
that should run in this PR's A/B. The selection rules are:

  1. ALWAYS include "general" prompts. A prompt is general when its
     `context.baseline_artifact` is missing, null, or the literal
     string "general". Orientation, first-app, latest-tag, link-error
     all currently fall in this bucket.

  2. ALWAYS include prompts targeting any skill that this PR touches.
     "Touches" means: a path under skills/<...>/ appears in
     `git diff --name-only <base>..HEAD` for the doca-skills repo.
     A prompt targets a skill when ANY of the following match the
     skill's directory name (e.g. "doca-flow", "doca-dms"):
       - `context.baseline_artifact`
       - `context.changed_skill_in_pr`
       - any entry in `context.expected_skill_co_load`

  3. Never include a prompt twice.

Output is one absolute path per line, sorted lexicographically. The
caller pipes this to:
    ab_runner.py --prompts-files $(cat selected.txt)

Use --print-decision to also emit a human-readable rationale to stderr
explaining WHY each prompt was selected (which changed skill, which
field matched). CI captures this in the report so reviewers can see
the dynamic selection picked the right probes.

Exit codes:
  0 = at least one prompt selected (general prompts guarantee this in
      a healthy repo).
  1 = no prompts found (likely indicates broken prompts dir).
  2 = usage error.
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
import typing as _t

import yaml  # type: ignore[import-not-found]


SKILL_PATH_PREFIXES = ("skills/",)
SKILL_KIND_DIRS = ("libs", "services", "tools")


def changed_skills(repo: pathlib.Path, base: str) -> _t.Set[str]:
    """Return the set of skill directory names changed in repo since base.

    A "skill" is identified by its directory name (the leaf), so a
    change under skills/libs/doca-flow/SKILL.md yields "doca-flow".
    Top-level skills (skills/doca-debug/*) are picked up the same way.
    """
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "diff", "--name-only",
             f"{base}...HEAD"],
            capture_output=True, check=True, text=True,
        ).stdout
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(
            f"select_prompts: git diff failed against {base!r}: {exc}\n"
            f"select_prompts: stderr: {exc.stderr}\n"
            f"select_prompts: returning empty changed-skills set\n"
        )
        return set()

    touched: _t.Set[str] = set()
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith(SKILL_PATH_PREFIXES):
            continue
        parts = pathlib.PurePosixPath(line).parts
        # parts[0] is "skills"; parts[1] is either a top-level skill
        # name or one of libs/services/tools (then parts[2] is the
        # skill name).
        if len(parts) < 2:
            continue
        if parts[1] in SKILL_KIND_DIRS:
            if len(parts) >= 3:
                touched.add(parts[2])
        else:
            touched.add(parts[1])
    return touched


def prompt_targets(meta: _t.Mapping[str, _t.Any]) -> _t.Set[str]:
    """All artifact names a prompt's YAML names as targets."""
    ctx = meta.get("context") or {}
    names: _t.Set[str] = set()
    for k in ("baseline_artifact", "changed_skill_in_pr"):
        v = ctx.get(k)
        if isinstance(v, str) and v and v != "general":
            names.add(v)
    co = ctx.get("expected_skill_co_load") or []
    for v in co:
        if isinstance(v, str) and v:
            names.add(v)
    return names


def is_general(meta: _t.Mapping[str, _t.Any]) -> bool:
    ctx = meta.get("context") or {}
    ba = ctx.get("baseline_artifact")
    return ba is None or ba == "" or ba == "general"


def select(
    prompts_dir: pathlib.Path,
    changed: _t.Set[str],
) -> _t.List[_t.Tuple[pathlib.Path, str]]:
    """Return [(path, reason)] for every prompt that should run."""
    out: _t.List[_t.Tuple[pathlib.Path, str]] = []
    for path in sorted(prompts_dir.glob("*.yaml")):
        try:
            meta = yaml.safe_load(path.read_text())
        except Exception as exc:
            sys.stderr.write(f"select_prompts: skipping unparsable prompt "
                             f"{path}: {exc}\n")
            continue
        if not isinstance(meta, dict):
            continue
        if is_general(meta):
            out.append((path, "general (always-on)"))
            continue
        targets = prompt_targets(meta)
        matched = targets & changed
        if matched:
            out.append((
                path,
                f"targets changed skill(s): {', '.join(sorted(matched))}",
            ))
    return out


def main(argv: _t.Optional[_t.Sequence[str]] = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--prompts-dir", required=True, type=pathlib.Path,
                   help="Directory containing *.yaml prompt definitions.")
    p.add_argument("--skills-repo", required=True, type=pathlib.Path,
                   help="Path to the doca-skills git repo for git-diff lookup.")
    p.add_argument("--since", default="main",
                   help="Base ref for git-diff (default: main).")
    p.add_argument("--print-decision", action="store_true",
                   help="Also emit a per-prompt rationale to stderr.")
    p.add_argument("--include-all-if-empty", action="store_true",
                   help="If --since diff is empty (e.g. running on main "
                        "itself), select every prompt instead of only "
                        "general ones. Used by the 'all-prompts smoke' "
                        "Jenkins job.")
    args = p.parse_args(argv)

    if not args.prompts_dir.is_dir():
        sys.stderr.write(f"select_prompts: not a directory: {args.prompts_dir}\n")
        return 2

    changed = changed_skills(args.skills_repo, args.since)
    if not changed and args.include_all_if_empty:
        # Synthetic "every skill touched" set so all targeted prompts
        # also run. Used for full-bundle smokes.
        sys.stderr.write(
            "select_prompts: empty diff and --include-all-if-empty set; "
            "selecting every prompt.\n"
        )
        selected = [
            (p_, "all-prompts smoke (empty diff fallback)")
            for p_ in sorted(args.prompts_dir.glob("*.yaml"))
        ]
    else:
        selected = select(args.prompts_dir, changed)

    if not selected:
        sys.stderr.write("select_prompts: no prompts selected.\n")
        return 1

    if args.print_decision:
        sys.stderr.write(
            f"select_prompts: base={args.since!r} touched_skills={sorted(changed)}\n"
        )
        for path, reason in selected:
            sys.stderr.write(f"  + {path.name}: {reason}\n")

    for path, _reason in selected:
        sys.stdout.write(str(path.resolve()) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
