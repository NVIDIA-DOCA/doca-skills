#!/usr/bin/env bash
# devops/ci/check-jtbd-coverage.sh
#
# JTBD coverage gate — compares the JTBDs the doca-skills bundle CLAIMS
# to cover (as enumerated in devops/ci/jtbd-coverage/bundle-jtbd-coverage.md,
# auto-derived from the bundle's class-shape prompts) against a freshly-
# extracted JTBD set produced by the upstream jtbd-extraction-skills suite
# (https://github.com/NVIDIA/jtbd-extraction-skills, which is the internal
# DevEx team's HITL-gated extraction toolchain).
#
# What this gate is and is NOT
# ----------------------------
# The jtbd-extraction-skills suite is itself a SKILL bundle for Claude Code
# with HITL gates between every stage; it cannot be invoked as a turnkey
# CLI in CI. The supported workflow is:
#
#   1. A human operator periodically runs the three jtbd-extraction-skills
#      against the DOCA documentation corpus (the docs.nvidia.com/doca/sdk/
#      tree, mirrored under doca/docs/ in the @doca monorepo). Cadence:
#      typically nightly via an OPUS-equipped Claude Code agent driven by
#      a small wrapper script that owns the HITL fallbacks (default answers
#      to "review per-component abstraction verdicts" etc.).
#
#   2. The wrapper drops the CONSOLIDATED output (the
#      FINAL-CONSOLIDATED-JTBD.md produced by /jtbd-extraction-consolidation)
#      into devops/ci/jtbd-coverage/freshly-extracted/FINAL-CONSOLIDATED-JTBD.md.
#
#   3. THIS gate runs in CI, opens that consolidated file, extracts every
#      JTBD row, and audits each one against the bundle's claimed coverage
#      (one row per class-shape prompt's `intent:` field; see
#      devops/ci/jtbd-coverage/bundle-jtbd-coverage.md).
#
#   4. Each JTBD lands in one of three buckets:
#        FULL    — a bundle prompt's intent fully expresses the extracted JTBD.
#        PARTIAL — at least one bundle prompt's intent overlaps but does not
#                  fully express the JTBD.
#        GAP     — no bundle prompt's intent overlaps the JTBD.
#
#   5. Exit conditions:
#        --full-fail-below=<pct>            HARD-fail if FULL share < pct.
#        --full-plus-partial-fail-below=<pct> HARD-fail if (FULL+PARTIAL) < pct.
#        --soft-warn                        (default) print the report; never fail.
#        --strict                           shortcut for both --full-fail-below=60 and
#                                           --full-plus-partial-fail-below=85, per the
#                                           PR3 § 11 SOFT-then-HARD promotion plan.
#
# CI promotion plan (PR3 § 11)
# ----------------------------
# - Day 0:  SOFT WARN only (this script run without --strict). Produces a
#           printed report so reviewers see the trend.
# - Day +N: after 1-3 clean nightly runs, promote to HARD by running with
#           `--strict` (full ≥ 60% AND full+partial ≥ 85%).
#
# When no freshly-extracted input is present
# ------------------------------------------
# If devops/ci/jtbd-coverage/freshly-extracted/FINAL-CONSOLIDATED-JTBD.md is
# absent, this gate exits 0 with a "skipped — no extracted set" message
# (CI must not fail when the human operator has not run the upstream
# extraction yet). Once the file appears, the gate's mode flag determines
# whether it warns or fails.
#
# Exit codes
# ----------
#   0  OK (or SOFT WARN, or skipped).
#   1  HARD FAIL: one of the configured percentage gates is below threshold.
#   2  Usage / environment error.
#
# Run locally
# -----------
#   bash devops/ci/check-jtbd-coverage.sh                  # SOFT WARN
#   bash devops/ci/check-jtbd-coverage.sh --strict          # HARD (60/85)
#   bash devops/ci/check-jtbd-coverage.sh --full-fail-below=50 \
#                                        --full-plus-partial-fail-below=80

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BUNDLE_COVERAGE_FILE="${BUNDLE_ROOT}/ci/jtbd-coverage/bundle-jtbd-coverage.md"
EXTRACTED_FILE="${EXTRACTED_FILE:-${BUNDLE_ROOT}/ci/jtbd-coverage/freshly-extracted/FINAL-CONSOLIDATED-JTBD.md}"

FULL_FAIL_BELOW=""
FULL_PARTIAL_FAIL_BELOW=""
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --strict)                         STRICT=1; shift ;;
    --soft-warn)                      shift ;;
    --full-fail-below=*)              FULL_FAIL_BELOW="${1#--full-fail-below=}"; shift ;;
    --full-plus-partial-fail-below=*) FULL_PARTIAL_FAIL_BELOW="${1#--full-plus-partial-fail-below=}"; shift ;;
    --extracted-file=*)               EXTRACTED_FILE="${1#--extracted-file=}"; shift ;;
    -h|--help)
      sed -n '1,60p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "$STRICT" -eq 1 ]; then
  FULL_FAIL_BELOW="${FULL_FAIL_BELOW:-60}"
  FULL_PARTIAL_FAIL_BELOW="${FULL_PARTIAL_FAIL_BELOW:-85}"
fi

echo "============================================================"
echo "JTBD coverage gate"
echo "============================================================"
echo "bundle coverage file : ${BUNDLE_COVERAGE_FILE}"
echo "extracted JTBD file  : ${EXTRACTED_FILE}"
echo "FULL fail-below      : ${FULL_FAIL_BELOW:-(SOFT WARN)}"
echo "FULL+PARTIAL fail-below: ${FULL_PARTIAL_FAIL_BELOW:-(SOFT WARN)}"
echo ""

if [ ! -f "$BUNDLE_COVERAGE_FILE" ]; then
  echo "FAIL: bundle coverage file missing at ${BUNDLE_COVERAGE_FILE}."
  echo "      Generate it by running:"
  echo "        bash devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh"
  exit 2
fi

if [ ! -f "$EXTRACTED_FILE" ]; then
  echo "SKIPPED: no freshly-extracted JTBD set at ${EXTRACTED_FILE}."
  echo "         To produce one, run the upstream jtbd-extraction-skills"
  echo "         suite (https://github.com/NVIDIA/jtbd-extraction-skills)"
  echo "         against doca/docs/ via an OPUS-equipped Claude Code agent,"
  echo "         then drop the consolidated FINAL-CONSOLIDATED-JTBD.md into"
  echo "         devops/ci/jtbd-coverage/freshly-extracted/."
  echo ""
  echo "         This gate exits 0 when no input is present so CI does not"
  echo "         block on the human-driven upstream extraction cadence."
  exit 0
fi

# --- extract candidate JTBDs from both files --------------------------------
# Bundle coverage file: one row per prompt's `intent` (machine-derived; see
#   devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh).
# Extracted file: the upstream suite produces a Markdown table with
#   columns Context | Job | Outcome | Persona | Evidence. We extract the
#   `Job` column as the JTBD identifier and the `Outcome` column for
#   matching context.

bundle_intents="$(awk -F'|' '
  /^\| .* \| .* \|/ && !/^\| --/ && !/^\| Intent/ {
    gsub(/^[ \t]+|[ \t]+$/, "", $2)
    if ($2 != "" && $2 != "Intent") print $2
  }' "$BUNDLE_COVERAGE_FILE")"

extracted_jobs="$(awk -F'|' '
  /^\| .* \| .* \| .* \|/ && !/^\| --/ && !/^\| Context/ && !/^\| Job/ {
    gsub(/^[ \t]+|[ \t]+$/, "", $3)
    if ($3 != "" && $3 != "Job") print $3
  }' "$EXTRACTED_FILE")"

bundle_intent_count=$(printf '%s\n' "$bundle_intents" | grep -c '.' || true)
extracted_job_count=$(printf '%s\n' "$extracted_jobs"   | grep -c '.' || true)

echo "Bundle-claimed JTBDs (from prompt intents): ${bundle_intent_count}"
echo "Freshly-extracted JTBDs (from upstream suite): ${extracted_job_count}"
echo ""

if [ "$extracted_job_count" -eq 0 ]; then
  echo "WARN: extracted JTBD file had 0 parseable Job rows. Skipping audit."
  exit 0
fi

# --- per-JTBD bucket pass ---------------------------------------------------
# Heuristic: a bundle intent (lowercased, normalized) FULL-covers a JTBD if
# the JTBD's lowercased text contains every "load-bearing" word (≥4 chars)
# of the intent, or vice versa. PARTIAL: at least one shared load-bearing
# word with ≥3 chars. GAP: nothing shared. This is a STRUCTURAL match
# heuristic; the canonical match is human review of the printed report.

normalize() {
  printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9' '\n' | grep -E '.{3,}' || true
}

full_count=0
partial_count=0
gap_count=0
gap_list=""

while IFS= read -r job; do
  [ -z "$job" ] && continue
  job_norm=$(normalize "$job" | sort -u | tr '\n' ' ')
  best="gap"
  while IFS= read -r intent; do
    [ -z "$intent" ] && continue
    intent_norm=$(normalize "$intent" | sort -u | tr '\n' ' ')
    # intersection
    intersect=$(printf '%s\n%s\n' "$intent_norm" "$job_norm" | tr ' ' '\n' \
                | sort | uniq -d | tr '\n' ' ')
    icount=$(printf '%s\n' "$intersect" | tr ' ' '\n' | grep -c '.' || true)
    [ "$icount" -lt 1 ] && continue
    intent_strong=$(printf '%s' "$intent_norm" | tr ' ' '\n' | grep -E '.{4,}' | grep -c '.' || true)
    intersect_strong=$(printf '%s' "$intersect" | tr ' ' '\n' | grep -E '.{4,}' | grep -c '.' || true)
    if [ "$intent_strong" -gt 0 ] && [ "$intersect_strong" -ge "$intent_strong" ]; then
      best="full"; break
    fi
    if [ "$best" = "gap" ] && [ "$icount" -ge 1 ]; then
      best="partial"
    fi
  done < <(printf '%s\n' "$bundle_intents")
  case "$best" in
    full)    full_count=$((full_count+1)) ;;
    partial) partial_count=$((partial_count+1)) ;;
    gap)     gap_count=$((gap_count+1)); gap_list="${gap_list}    - ${job}\n" ;;
  esac
done < <(printf '%s\n' "$extracted_jobs")

total=$((full_count + partial_count + gap_count))
full_pct=0
fp_pct=0
if [ "$total" -gt 0 ]; then
  full_pct=$(( (full_count * 100) / total ))
  fp_pct=$(( ((full_count + partial_count) * 100) / total ))
fi

echo "------------------------------------------------------------"
echo "JTBD coverage audit"
echo "------------------------------------------------------------"
printf '  %-9s %4d  (%3d%%)\n' "FULL"    "$full_count"    "$full_pct"
printf '  %-9s %4d  (%3d%%)\n' "PARTIAL" "$partial_count" "$((total > 0 ? (partial_count*100)/total : 0))"
printf '  %-9s %4d  (%3d%%)\n' "GAP"     "$gap_count"     "$((total > 0 ? (gap_count*100)/total : 0))"
printf '  %-9s %4d\n'          "TOTAL"   "$total"
echo "  FULL + PARTIAL share: ${fp_pct}%"
echo ""

if [ "$gap_count" -gt 0 ]; then
  echo "  GAP JTBDs (consider authoring a class-shape prompt that covers each):"
  printf "${gap_list}"
  echo ""
fi

# --- gate verdict -----------------------------------------------------------
verdict=0
if [ -n "$FULL_FAIL_BELOW" ] && [ "$full_pct" -lt "$FULL_FAIL_BELOW" ]; then
  echo "FAIL: FULL coverage ${full_pct}% < ${FULL_FAIL_BELOW}% (HARD GATE)"
  verdict=1
fi
if [ -n "$FULL_PARTIAL_FAIL_BELOW" ] && [ "$fp_pct" -lt "$FULL_PARTIAL_FAIL_BELOW" ]; then
  echo "FAIL: FULL+PARTIAL coverage ${fp_pct}% < ${FULL_PARTIAL_FAIL_BELOW}% (HARD GATE)"
  verdict=1
fi

if [ "$verdict" -eq 0 ]; then
  if [ -z "$FULL_FAIL_BELOW" ] && [ -z "$FULL_PARTIAL_FAIL_BELOW" ]; then
    echo "OK (SOFT WARN mode — promote to HARD by adding --strict or"
    echo "    --full-fail-below=<pct> --full-plus-partial-fail-below=<pct>"
    echo "    after 1-3 clean runs per PR3 § 11)."
  else
    echo "OK: all configured percentage gates are met."
  fi
fi

exit $verdict
