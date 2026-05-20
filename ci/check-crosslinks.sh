#!/usr/bin/env bash
# ci/check-crosslinks.sh
#
# Cross-link integrity audit for the doca-skills bundle.
#
# Verifies that every Markdown link of the shape
#   [text](relative/path/to/FILE.md#anchor)
# whose target file path resolves into doca-skills/skills/:
#   (a) targets a file that actually exists, AND
#   (b) targets an anchor that actually exists in that file as
#       an H2 / H3 / H4 / H5 / H6 heading (slugified using the
#       GitHub Markdown anchor algorithm).
#
# Why this exists:
#   The PR2 pre-push sweep found 151 broken cross-links across the
#   bundle (off-by-one relative paths between sibling skills,
#   stale anchor names like `#install` instead of the renamed
#   `#configure`, and a GitHub-slug mismatch on a `--`-bearing
#   heading). An agent following any of those links would 404 —
#   exactly the failure mode the bundle exists to prevent. The
#   structural lint (check-skill.sh) does NOT catch these; it
#   only enforces *within-file* anchor presence. This gate is the
#   missing cross-file half.
#
# Exit codes:
#   0  = OK. Every cross-skill link resolves.
#   1  = FAIL. At least one broken cross-link printed to stderr.
#   3  = Script error (env problem; not a content gap).
#
# Usage:
#   ci/check-crosslinks.sh                 # always-on; HARD
#   ci/check-crosslinks.sh --json          # machine-readable
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
candidate="$SCRIPT_DIR"
while [ "$candidate" != "/" ]; do
  if [ -d "$candidate/doca-skills" ]; then
    REPO_ROOT="$candidate"
    break
  fi
  candidate="$(dirname "$candidate")"
done
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SKILLS_ROOT="${SKILLS_ROOT:-${REPO_ROOT}/doca-skills/skills}"

JSON_OUT=0
for a in "$@"; do
  case "$a" in
    --json) JSON_OUT=1 ;;
    -h|--help) sed -n '1,40p' "$0"; exit 2 ;;
    *) echo "unknown arg: $a" >&2; exit 3 ;;
  esac
done

if [ ! -d "$SKILLS_ROOT" ]; then
  echo "ERR: skills root not found at $SKILLS_ROOT" >&2
  exit 3
fi

python3 - "$SKILLS_ROOT" "$JSON_OUT" << 'PY'
import os, re, sys, json
SKILLS = sys.argv[1]
JSON_OUT = sys.argv[2] == "1"

def slug(h):
    s = h.strip().lower()
    s = re.sub(r"[^\w\s\-]+", "", s)
    s = re.sub(r"\s+", "-", s)
    return s

# Index every H2-H6 anchor in every .md under SKILLS_ROOT.
anchors = {}
for root, _, files in os.walk(SKILLS):
    for fn in files:
        if not fn.endswith(".md"):
            continue
        p = os.path.join(root, fn)
        ss = set()
        with open(p) as f:
            for line in f:
                m = re.match(r"^(#{2,6})\s+(.+?)\s*$", line)
                if m:
                    ss.add(slug(m.group(2)))
        anchors[os.path.abspath(p)] = ss

LINK = re.compile(r"\[[^\]]+\]\(([^)\s]+)\)")
total = 0
checked = 0
bad = []
for root, _, files in os.walk(SKILLS):
    for fn in files:
        if not fn.endswith(".md"):
            continue
        src = os.path.join(root, fn)
        with open(src) as f:
            text = f.read()
        for m in LINK.finditer(text):
            target = m.group(1)
            total += 1
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            rel, _, anc = target.partition("#")
            if not rel.endswith(".md"):
                continue
            tabs = os.path.abspath(os.path.normpath(os.path.join(os.path.dirname(src), rel)))
            if not tabs.startswith(os.path.abspath(SKILLS)):
                continue
            checked += 1
            if not os.path.isfile(tabs):
                bad.append({"src": src, "target": target, "reason": "FILE_MISSING"})
                continue
            if anc and anc not in anchors.get(tabs, set()):
                bad.append({"src": src, "target": target, "reason": f"ANCHOR_MISSING:{anc}"})

if JSON_OUT:
    print(json.dumps({
        "scanned_links_total": total,
        "cross_skill_links_checked": checked,
        "broken_count": len(bad),
        "broken": bad,
    }, indent=2))
else:
    print("Cross-link integrity audit")
    print("=" * 60)
    print(f"Total inline links scanned:    {total}")
    print(f"Cross-skill .md links checked: {checked}")
    print(f"Broken cross-links found:      {len(bad)}")
    print()
    if bad:
        by_src = {}
        for b in bad:
            by_src.setdefault(b["src"], []).append((b["target"], b["reason"]))
        for src in sorted(by_src):
            print(f"  {src}")
            for tgt, why in by_src[src]:
                print(f"    - {tgt}  --  {why}")
sys.exit(1 if bad else 0)
PY
