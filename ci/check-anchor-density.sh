#!/usr/bin/env bash
# ci/check-anchor-density.sh
#
# Anchor-density gate: every REQUIRED H2 anchor in every skill must carry
# real content. This stops the failure mode "anchor exists, body is one
# sentence" that lint can't catch (lint only confirms the anchor is
# present, not that it has substance).
#
# Why this exists:
#   - AUTHORING.md § 8 requires CAPABILITIES.md to "carry the actual
#     content"; AUTHORING.md § 11 makes the two-agent A/B a hard merge
#     gate. Both depend on each anchor under each skill being substantive,
#     not a stub. Reviewers cannot scale "is this section deep enough?"
#     by eyeball; this script makes it a count.
#
# What it enforces:
#   - For each SKILL.md / CAPABILITIES.md / TASKS.md the existing
#     check-skill.sh requires anchors for, this script counts non-blank
#     lines between that anchor and the next H2 (or EOF).
#   - A floor of MIN_LINES_DEFAULT applies, overridden per-anchor by the
#     ANCHOR_OVERRIDES table for anchors that are legitimately short
#     (e.g. "## Deferred task verbs" may be a 2-3 line list).
#
# Exit codes:
#   0 = all required anchors meet their density floor.
#   1 = at least one required anchor is under-filled.
#   2 = usage error.
#
# Usage:
#   ci/check-anchor-density.sh                # walk every skill
#   ci/check-anchor-density.sh <skill-dir>    # one skill
#   ci/check-anchor-density.sh --self-test    # failure-mode test
#
# Env overrides:
#   SKILLS_ROOT          - root of skills tree (default: <repo>/doca-skills/skills)
#   MIN_LINES_DEFAULT    - default density floor (default: 5)
#
# Companion to check-skill.sh (structure) and check-coverage.sh (coverage).
# This script is HARD FAIL by design - stub anchors degrade agent
# performance as much as missing anchors.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Walk up to find a doca-skills/ sibling, the same way check-coverage.sh does.
candidate="$SCRIPT_DIR"
while [ "$candidate" != "/" ]; do
  if [ -d "$candidate/doca-skills" ]; then
    REPO_ROOT="$candidate"; break
  fi
  candidate="$(dirname "$candidate")"
done
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SKILLS_ROOT="${SKILLS_ROOT:-${REPO_ROOT}/doca-skills/skills}"
MIN_LINES_DEFAULT="${MIN_LINES_DEFAULT:-5}"

# Per-anchor floor overrides. Pipe-separated "anchor|min". Anchors that
# are legitimately short live here. Everything else falls back to
# MIN_LINES_DEFAULT.
ANCHOR_OVERRIDES=(
  "## Deferred task verbs|3"
  "## Safety policy|3"
)

# Required anchors by file. Keep these in sync with check-skill.sh § 3-4
# (universal + kind=library structural requirements).
REQUIRED_IN_SKILL_MD=(
  "## When to load this skill"
)
REQUIRED_IN_CAPABILITIES_MD=(
  "## Capabilities and modes"
  "## Version compatibility"
  "## Error taxonomy"
  "## Observability"
  "## Safety policy"
)
REQUIRED_IN_TASKS_MD=(
  "## configure"
  "## build"
  "## modify"
  "## run"
  "## test"
  "## debug"
  "## Deferred task verbs"
)

# --- helpers ----------------------------------------------------------------

min_for_anchor() {
  # Look up per-anchor override or fall back to default.
  local a="$1" entry name floor
  for entry in "${ANCHOR_OVERRIDES[@]}"; do
    name="${entry%%|*}"
    floor="${entry##*|}"
    if [ "$name" = "$a" ]; then
      printf '%s' "$floor"; return 0
    fi
  done
  printf '%s' "$MIN_LINES_DEFAULT"
}

count_lines_under_anchor() {
  # Args: file anchor. Output: integer count of non-blank lines between
  # the anchor (exclusive) and the next H2 (exclusive), or EOF.
  local file="$1" anchor="$2"
  awk -v a="$anchor" '
    BEGIN { in_section = 0; count = 0 }
    {
      line = $0
      sub(/[[:space:]]+$/, "", line)
    }
    !in_section && line == a { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && NF > 0 { count++ }
    END { print count + 0 }
  ' "$file"
}

check_anchors_in_file() {
  # Args: file, then one or more required-anchor strings.
  # Echoes FAIL lines for each under-filled anchor; returns 1 if any
  # failed, 0 if all pass. Anchors missing from the file are ignored
  # here (check-skill.sh already reports them as hard fails).
  local file="$1"; shift
  local rc=0 a floor n
  [ -f "$file" ] || return 0
  for a in "$@"; do
    grep -Eq "^${a}[[:space:]]*$" "$file" || continue
    floor="$(min_for_anchor "$a")"
    n="$(count_lines_under_anchor "$file" "$a")"
    if [ "$n" -lt "$floor" ]; then
      echo "FAIL[anchor-density]: $file"
      echo "  anchor:        $a"
      echo "  content lines: $n  (floor: $floor)"
      echo "  AUTHORING.md § 8: every required anchor must carry real content,"
      echo "  not a placeholder. Expand this section or move the content here"
      echo "  from another file."
      rc=1
    fi
  done
  return $rc
}

check_one_skill() {
  local skill_dir="$1"
  local rc=0
  [ -d "$skill_dir" ] || { echo "FAIL: not a directory: $skill_dir"; return 1; }
  check_anchors_in_file "$skill_dir/SKILL.md"        "${REQUIRED_IN_SKILL_MD[@]}"        || rc=1
  check_anchors_in_file "$skill_dir/CAPABILITIES.md" "${REQUIRED_IN_CAPABILITIES_MD[@]}" || rc=1
  check_anchors_in_file "$skill_dir/TASKS.md"        "${REQUIRED_IN_TASKS_MD[@]}"        || rc=1
  if [ "$rc" -eq 0 ]; then
    echo "OK[anchor-density]: $skill_dir"
  fi
  return $rc
}

# --- self-test --------------------------------------------------------------
self_test() {
  local TMP FX FX_REL src rc OLD_ROOT
  TMP="$(mktemp -d)"
  cp -R "$SKILLS_ROOT" "$TMP/skills"
  OLD_ROOT="$SKILLS_ROOT"
  SKILLS_ROOT="$TMP/skills"
  FX="$(find "$SKILLS_ROOT" -type d -name doca-flow | head -n 1)"
  [ -d "$FX" ] || { echo "self-test FAIL: doca-flow fixture missing"; SKILLS_ROOT="$OLD_ROOT"; return 1; }

  echo "== self-test 1: empty ## Safety policy section should fail =="
  src="$FX/CAPABILITIES.md"
  # Replace the existing Safety policy body with a single placeholder line
  # by truncating from "## Safety policy" to the next H2.
  python3 - "$src" <<'PYEOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = re.search(r'(^## Safety policy\s*$)(.*?)(?=^## |\Z)', s, re.MULTILINE|re.DOTALL)
if not m:
    sys.exit("Safety policy not present in fixture")
new = m.group(1) + "\n\n_(placeholder)_\n\n"
open(p, "w").write(s[:m.start()] + new + s[m.end():])
PYEOF
  rc=0; check_one_skill "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: empty Safety policy not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }

  SKILLS_ROOT="$OLD_ROOT"
  rm -rf "$TMP"
  echo "self-test PASS"
  return 0
}

# --- main -------------------------------------------------------------------
case "${1:-}" in
  --self-test)
    self_test
    ;;
  -h|--help|"")
    sed -n '1,40p' "$0"
    exit 2
    ;;
  --all)
    rc=0
    while IFS= read -r d; do
      check_one_skill "$d" || rc=1
    done < <(find "$SKILLS_ROOT" -type f -name SKILL.md -exec dirname {} \; | sort -u)
    exit "$rc"
    ;;
  *)
    check_one_skill "$1"
    ;;
esac
