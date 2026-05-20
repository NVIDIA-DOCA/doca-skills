#!/usr/bin/env bash
# make-public-bundle.sh — emit exactly what the public consumer / reviewer sees.
#
# Reads from a doca-skills git checkout at a given rev; writes a clean
# stripped bundle to OUT_DIR containing ONLY the public surface:
#
#   AGENTS.md, SKILLS.md, README.md, CLAUDE.md, LICENSE.md (if present),
#   skills/**
#
# Drops every internal-only path (the same set check-reference-hygiene.py
# defends against in PUBLIC files): ci/, runner/, fixtures/, env/,
# AUTHORING.md, CONTRIBUTING.md, SECURITY.md, .gitignore, .git/,
# .DS_Store, any leftover devops/, future-plan/, .ngci/.
#
# Usage (run from anywhere — script self-locates the doca-skills repo
# it lives inside):
#
#   doca-skills/ci/make-public-bundle.sh <REV> <OUT_DIR>
#
# Examples:
#   ci/make-public-bundle.sh HEAD          /tmp/doca-skills-public-c
#   ci/make-public-bundle.sh origin/main   /tmp/doca-skills-public-b
#
# Override the source repo if you want to strip some OTHER checkout:
#   SKILLS_REPO=/path/to/other-clone ci/make-public-bundle.sh HEAD /tmp/out
#
# After producing OUT_DIR, hand the reviewer either OUT_DIR itself
# or a tarball:
#   tar -czf OUT_DIR.tgz -C "$(dirname OUT_DIR)" "$(basename OUT_DIR)"
#
# This script is intentionally placed under ci/ so it is INTERNAL-ONLY
# and will be stripped out of every public bundle it produces. The
# reviewer never sees it.

set -euo pipefail

REV="${1:?git rev (HEAD, origin/main, sha, …)}"
OUT_DIR="${2:?output directory for the stripped bundle}"

# Self-locate the doca-skills repo this script lives inside, unless the
# caller overrode via SKILLS_REPO.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SKILLS_REPO="${SKILLS_REPO:-$( cd "${SCRIPT_DIR}/.." && pwd )}"

if [[ ! -d "$SKILLS_REPO/.git" ]]; then
  echo "FATAL: ${SKILLS_REPO} is not a git checkout" >&2
  echo "       (set SKILLS_REPO=/path/to/doca-skills if running from outside)" >&2
  exit 2
fi

# 1) Materialize the rev's tree fresh.
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
git -C "$SKILLS_REPO" archive "$REV" | tar -xf - -C "$OUT_DIR"

# 2) Strip every internal-only path. Keep this list in sync with
#    INTERNAL_ONLY_FIRST_PATH_SEGMENTS / INTERNAL_ONLY_ROOT_FILES in
#    ci/check-reference-hygiene.py.
INTERNAL_DIRS=(ci runner fixtures env .ngci devops future-plan .git)
INTERNAL_FILES=(AUTHORING.md CONTRIBUTING.md SECURITY.md .gitignore .DS_Store)

for d in "${INTERNAL_DIRS[@]}"; do
  if [[ -e "$OUT_DIR/$d" ]]; then
    rm -rf "$OUT_DIR/$d"
  fi
done
for f in "${INTERNAL_FILES[@]}"; do
  if [[ -e "$OUT_DIR/$f" ]]; then
    rm -f "$OUT_DIR/$f"
  fi
done
# Recursively strip any stray .DS_Store anywhere.
find "$OUT_DIR" -name ".DS_Store" -delete 2>/dev/null || true

# 3) Sanity check: bundle must look like a public bundle.
missing=()
required_public=(AGENTS.md SKILLS.md README.md skills)
for r in "${required_public[@]}"; do
  if [[ ! -e "$OUT_DIR/$r" ]]; then
    missing+=("$r")
  fi
done
if (( ${#missing[@]} > 0 )); then
  echo "FATAL: stripped bundle is missing required public surface:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 3
fi

# 4) Sanity check: no internal-only paths leaked through.
leaked=()
for d in "${INTERNAL_DIRS[@]}"; do
  [[ -e "$OUT_DIR/$d" ]] && leaked+=("$d/")
done
for f in "${INTERNAL_FILES[@]}"; do
  [[ -e "$OUT_DIR/$f" ]] && leaked+=("$f")
done
if (( ${#leaked[@]} > 0 )); then
  echo "FATAL: internal paths leaked into stripped bundle:" >&2
  printf '  - %s\n' "${leaked[@]}" >&2
  exit 4
fi

# 5) Report.
cd "$OUT_DIR"
md_count=$(find . -name '*.md' | wc -l | tr -d ' ')
skill_dirs=$(find skills -mindepth 1 -maxdepth 3 -type d -name 'doca-*' | wc -l | tr -d ' ')
size_kb=$(du -sk . | awk '{print $1}')

echo "OK: stripped public bundle @ $OUT_DIR"
echo "    source repo:  $SKILLS_REPO"
echo "    rev:          $REV ($(git -C "$SKILLS_REPO" rev-parse --short "$REV"))"
echo "    *.md files:   $md_count"
echo "    skill dirs:   $skill_dirs"
echo "    size:         ${size_kb} KB"
echo ""
echo "    root entries:"
ls -1A . | sed 's/^/      /'
