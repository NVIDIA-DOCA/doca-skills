#!/usr/bin/env bash
# ci/check-public-surface-invariants.sh
#
# Five regression-class gates that protect the public surface against
# the specific bug classes surfaced by runs 2/3/4/5:
#
#   I1  no internal-CI process trivia leak (NVIDIA's internal CI /
#       DOCA_BRANCH / Jenkins parameter names) in any agent-facing file
#       (README.md is allowed exactly ONE softened mention).
#   I2  no stale DOCA package vocabulary (doca-applications, doca-tools)
#       in any agent-facing file UNLESS in the explicit "legacy on
#       older releases" rephrasing context the doca-version skill ships.
#   I3  no legacy H3 references to the universal contracts /
#       refuse-and-escalate / activation checklist / binding stanza
#       (the H3->H2 promoted anchors).
#   I4  no off-PATH-assuming `command -v doca_caps` / bare
#       `doca_caps --version` quoted as a probe without the
#       /opt/mellanox/doca/tools/ fallback noted within 10 lines.
#   I5  no invented-symbol patterns the bundle has previously fixed:
#       - `doca-pcc.so`  (must be `libdoca_pcc.so`)
#       - `bfb-info`     (not a real NVIDIA tool)
#       - `mlxconfig query` for FW version (must be `flint -d <bdf> q`)
#
# Exit 0 iff all 5 invariants hold against the public surface.
# Exit 1 on any violation; lists exact file:line for each.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Public surface = everything the make-public-bundle.sh ships.
PUBLIC_GLOBS=(
  "$BUNDLE_ROOT/AGENTS.md"
  "$BUNDLE_ROOT/SKILLS.md"
  "$BUNDLE_ROOT/README.md"
  "$BUNDLE_ROOT/CLAUDE.md"
)
SKILLS_DIR="$BUNDLE_ROOT/skills"

violations=0

# -----------------------------------------------------------------------
# Helper: print every violating file:line for a pattern restricted to the
# public surface (root .md + skills/**).
# -----------------------------------------------------------------------
public_find_lines() {
  local pattern="$1"
  local extra_args="${2:-}"
  # shellcheck disable=SC2086
  grep -EHn $extra_args "$pattern" \
    "$BUNDLE_ROOT/AGENTS.md" \
    "$BUNDLE_ROOT/SKILLS.md" \
    "$BUNDLE_ROOT/README.md" \
    "$BUNDLE_ROOT/CLAUDE.md" 2>/dev/null
  find "$SKILLS_DIR" -name '*.md' -print0 \
    | xargs -0 grep -EHn $extra_args "$pattern" 2>/dev/null
}

# -----------------------------------------------------------------------
# I1: internal-CI process trivia leak
# -----------------------------------------------------------------------
echo "== I1: no internal-CI process trivia in public surface =="
matches="$(public_find_lines "NVIDIA's internal( release)? CI|DOCA_BRANCH|enforced by.+internal CI|through internal CI" 2>/dev/null)"
# README.md is allowed ONE softened mention ("an internal CI pipeline").
i1_bad="$(echo "$matches" | grep -v "^$" | grep -v 'README.md.*an internal CI pipeline' || true)"
if [ -n "$i1_bad" ]; then
  echo "I1 FAIL: internal-CI process trivia leaked to public surface:"
  echo "$i1_bad" | sed 's/^/  /'
  violations=$((violations+1))
else
  echo "I1 OK"
fi

# -----------------------------------------------------------------------
# I2: stale DOCA package names outside legacy-context rephrasing
# -----------------------------------------------------------------------
echo ""
echo "== I2: no stale doca-applications/doca-tools as the FIRST install line =="
# Tolerated: ANY line that also contains 'legacy', 'older', 'no longer exists',
# 'on DOCA 3.3+', or 'apt-cache policy' (the rephrased / contextualised
# mentions). Forbidden: a bare `apt install doca-applications` or
# `apt install doca-tools` recommendation.
i2_bad="$(public_find_lines '\bapt(-get)?\s+install\s+[^|`]*\bdoca-(applications|tools)\b' \
  | grep -viE 'legacy|older|no longer exists|on DOCA 3\.3\+|apt-cache policy|disambiguate|absent-source|partial-install|granular' || true)"
if [ -n "$i2_bad" ]; then
  echo "I2 FAIL: stale package name prescribed without legacy context:"
  echo "$i2_bad" | sed 's/^/  /'
  violations=$((violations+1))
else
  echo "I2 OK"
fi

# -----------------------------------------------------------------------
# I3: legacy H3 references to promoted anchors
# -----------------------------------------------------------------------
echo ""
echo "== I3: no legacy H3 references to promoted-to-H2 anchors =="
i3_bad="$(public_find_lines '###\s+(The universal (verification|debug-loop) contract|Hardware binding-layer command stanza|Refuse-and-escalate is a hard rule|Universal version-coherence trigger|Agent activation checklist)' || true)"
if [ -n "$i3_bad" ]; then
  echo "I3 FAIL: legacy H3 reference to a promoted-to-H2 anchor:"
  echo "$i3_bad" | sed 's/^/  /'
  violations=$((violations+1))
else
  echo "I3 OK"
fi

# -----------------------------------------------------------------------
# I4: off-PATH-assuming doca_caps probe without nearby tools-path fallback
# -----------------------------------------------------------------------
echo ""
echo "== I4: no bare command -v doca_caps without /opt/mellanox/doca/tools/ fallback nearby =="
i4_bad=""
while IFS= read -r f; do
  # Find every line that bare-probes doca_caps via command -v
  while IFS=: read -r line_no _; do
    [ -z "$line_no" ] && continue
    # Check for the /opt/mellanox/doca/tools/ fallback within +/-15 lines
    lo=$((line_no - 15)); [ $lo -lt 1 ] && lo=1
    hi=$((line_no + 15))
    if ! sed -n "${lo},${hi}p" "$f" | grep -qE '/opt/mellanox/doca/tools/|extend.*PATH|off-PATH|dpkg -L doca-caps'; then
      i4_bad="${i4_bad}${f}:${line_no}: command -v doca_caps without nearby tools-path fallback"$'\n'
    fi
  done < <(grep -nE 'command -v doca_caps' "$f" 2>/dev/null)
done < <(find "$SKILLS_DIR" -name '*.md'; echo "$BUNDLE_ROOT/AGENTS.md"; echo "$BUNDLE_ROOT/SKILLS.md")
if [ -n "$i4_bad" ]; then
  echo "I4 FAIL:"
  echo "$i4_bad" | sed 's/^/  /'
  violations=$((violations+1))
else
  echo "I4 OK"
fi

# -----------------------------------------------------------------------
# I5: invented-symbol regression patterns
# -----------------------------------------------------------------------
echo ""
echo "== I5: no previously-banned invented symbols =="
# bfb-info: not a real NVIDIA tool. The doca-version skill bans it explicitly,
# so that mention is tolerated. Anywhere else is a regression.
i5_bad=""
# 5a: doca-pcc.so (must be libdoca_pcc.so)
matches="$(public_find_lines '\bdoca-pcc\.so\b' || true)"
if [ -n "$matches" ]; then
  i5_bad="${i5_bad}I5a: doca-pcc.so found (must be libdoca_pcc.so):"$'\n'"${matches}"$'\n'
fi
# 5b: bfb-info outside the explicit "do not substitute" ban context
matches="$(public_find_lines '\bbfb-info\b' | grep -vE 'NOT a real|not a real|hallucination|banned|Do NOT substitute|do not substitute|not a substitute' || true)"
if [ -n "$matches" ]; then
  i5_bad="${i5_bad}I5b: bfb-info found outside ban context:"$'\n'"${matches}"$'\n'
fi
# 5c: mlxconfig used for FW version (must be flint)
matches="$(public_find_lines 'mlxconfig.*(FW Version|firmware version)' | grep -vE 'NOT|not the firmware version|do not substitute|configuration|firmware \*configuration\*' || true)"
if [ -n "$matches" ]; then
  i5_bad="${i5_bad}I5c: mlxconfig prescribed for FW version (must be flint -d <bdf> q):"$'\n'"${matches}"$'\n'
fi
if [ -n "$i5_bad" ]; then
  echo "I5 FAIL:"
  echo "$i5_bad" | sed 's/^/  /'
  violations=$((violations+1))
else
  echo "I5 OK"
fi

# -----------------------------------------------------------------------
echo ""
if [ "$violations" -eq 0 ]; then
  echo "================================================================"
  echo "ALL 5 public-surface invariants PASS"
  exit 0
else
  echo "================================================================"
  echo "$violations invariant(s) FAILED"
  exit 1
fi
