#!/usr/bin/env bash
# ci/run-bundle-regression-check.sh — orchestrator for the doca-skills
# bundle regression check. Runs every per-PR gate in order; the failure of any
# single gate is the failure of the PR.
#
# Designed to be the single entry point CI invokes for "did this PR regress
# the bundle?" — chains the structural keystone gate (catches keystone
# deletions; protects the C‴ 91.4 % YES baseline), the existing per-skill
# conformance gate (frontmatter / anchors / no-private-refs; the bundle's
# original CI), and the existing inventory + crosslink + JTBD coverage gates.
#
# Usage:
#   ci/run-bundle-regression-check.sh [--check-urls] [--with-self-test]
#
#   --check-urls       also HEAD every URL in every skill (slow, requires network)
#   --with-self-test   run check-keystones.sh --self-test BEFORE the bundle gate
#                      (catches regressions in the gate itself; recommended weekly)
#
# Exit codes:
#   0   all gates pass; bundle matches the C‴ measurement baseline
#   1   at least one gate failed; PR must not merge
#
# Provenance: the 6-variant constant-grader scoreboard (A 20.0 % → C‴ 91.4 % YES, fully measured)
# is reproducible by re-running the deep-test + breadth-60 + Step-4 subagents
# against the bundle this script just validated. See
# devops/runner/reports/3agent_pr3pr4_ab_2026-05-18/VERDICT.md for the
# measurement record.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CI_DIR="${REPO_ROOT}/ci"
CHECK_URLS=""
WITH_SELF_TEST=""

for arg in "$@"; do
    case "${arg}" in
        --check-urls) CHECK_URLS="--check-urls" ;;
        --with-self-test) WITH_SELF_TEST="1" ;;
        *) printf 'unknown arg: %s\n' "${arg}"; exit 2 ;;
    esac
done

separator() { printf '\n────────────────────────────────────────────────────────────────────\n'; }

run_gate() {
    local label="$1"
    shift
    separator
    printf '== %s ==\n' "${label}"
    if "$@"; then
        printf '\n[%s] OK\n' "${label}"
        return 0
    else
        printf '\n[%s] FAIL — PR must not merge until this gate passes\n' "${label}"
        return 1
    fi
}

overall_fail=0

if [[ -n "${WITH_SELF_TEST}" ]]; then
    if ! run_gate 'gate-0: keystone-gate self-test (the gate-checks-the-gate)' \
            "${CI_DIR}/check-keystones.sh" --self-test; then
        overall_fail=1
    fi
fi

if ! run_gate 'gate-1: structural keystone gate (5-variant constant-grader baseline)' \
        "${CI_DIR}/check-keystones.sh"; then
    overall_fail=1
fi

# check-skill.sh expects SKILLS_ROOT to be set (or the repo layout to match).
export SKILLS_ROOT="${REPO_ROOT}/skills"
if [[ -n "${CHECK_URLS}" ]]; then
    if ! run_gate 'gate-2: per-skill conformance (structure + public-sources + URL HEAD)' \
            "${CI_DIR}/check-skill.sh" --all --check-urls; then
        overall_fail=1
    fi
else
    if ! run_gate 'gate-2: per-skill conformance (structure + public-sources)' \
            "${CI_DIR}/check-skill.sh" --all; then
        overall_fail=1
    fi
fi

# Optional gates (only run if the underlying scripts exist; failures here block too).
# Map per-gate flag requirements so each is invoked the way it expects.
declare -a OPTIONAL_GATES=(
    "check-doca-inventory.sh"
    "check-crosslinks.sh"
    "check-anchor-density.sh --all"
    "check-coverage.sh"
    "check-jtbd-coverage.sh"
    "check-live-hardware-harness.sh"
)
for entry in "${OPTIONAL_GATES[@]}"; do
    script="${entry%% *}"
    args="${entry#"${script}"}"
    args="${args# }"
    if [[ -x "${CI_DIR}/${script}" ]]; then
        if [[ -n "${args}" ]]; then
            if ! run_gate "gate-3: ${script} ${args}" "${CI_DIR}/${script}" ${args}; then
                overall_fail=1
            fi
        else
            if ! run_gate "gate-3: ${script}" "${CI_DIR}/${script}"; then
                overall_fail=1
            fi
        fi
    fi
done

# Reference-hygiene gate (python script — runs after the bash gates so its
# exit code lands cleanly in overall_fail).
if [[ -f "${CI_DIR}/check-reference-hygiene.py" ]]; then
    if ! run_gate 'gate-4: reference-hygiene (no internal-only path leaks; no .DS_Store; no audit-history in runtime SKILL.md)' \
            python3 "${CI_DIR}/check-reference-hygiene.py" --bundle-root "${REPO_ROOT}"; then
        overall_fail=1
    fi
fi

separator
if (( overall_fail == 0 )); then
    printf 'ALL GATES PASS — bundle matches the C‴ measurement baseline (6-variant constant-grader scoreboard, fully measured:\nA 20.0 %% → B 17.1 %% → C 49.5 %% → C′ 68.6 %% → C″ 86.7 %% → C‴ 91.4 %% YES of applicable; +71.4 pp vs A; 0 NO cells).\n'
    printf 'You can run a fresh measurement via the runbook in devops/runner/reports/3agent_pr3pr4_ab_2026-05-18/VERDICT.md.\n'
    exit 0
else
    printf 'AT LEAST ONE GATE FAILED — bundle has structurally regressed from the C‴ baseline.\nDo not merge this PR until every gate above reads OK.\n'
    exit 1
fi
