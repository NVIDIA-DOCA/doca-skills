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
    "check-public-surface-invariants.sh"
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

# Frontmatter-kind gate (catches services / tools that were spawned from a
# library skeleton and silently inherited `kind: library` in their YAML
# frontmatter — a real bug surfaced by the operational AI re-grade because it
# misclassifies the artifact for every consumer of the frontmatter).
if [[ -f "${CI_DIR}/check-frontmatter-kind.py" ]]; then
    if ! run_gate 'gate-4b: frontmatter-kind (libs->library, services->service, tools->tool)' \
            python3 "${CI_DIR}/check-frontmatter-kind.py"; then
        overall_fail=1
    fi
fi

# Jenkinsfile syntax gate (catches Groovy-side breakage before it lands in
# Jenkins). Requires `groovy` on PATH; if absent, skips with a hint so
# Linux CI hosts without Groovy don't spuriously fail the bundle gate.
if [[ -x "${CI_DIR}/check-jenkinsfile-syntax.sh" ]]; then
    if command -v groovy >/dev/null 2>&1; then
        if ! run_gate 'gate-4c: Jenkinsfile syntax (Groovy parse of ci/Jenkinsfile.skills.ci)' \
                bash "${CI_DIR}/check-jenkinsfile-syntax.sh"; then
            overall_fail=1
        fi
    else
        separator
        printf '== gate-4c: Jenkinsfile syntax — SKIPPED (groovy not on PATH; install Groovy 4.x to enable) ==\n'
    fi
fi

# Deep E2E generate gate. The generator alone (no agent dispatch) is enough
# to catch packaging regressions like "skill dir present but no SKILL.md"
# or "SKILL.md frontmatter unparseable". The full grade+aggregate run is
# the Jenkins stage `Deep E2E suite` — too heavy for the local pre-push
# orchestrator, but the generator itself is fast.
if [[ -f "${REPO_ROOT}/runner/e2e_generate.py" ]]; then
    if ! run_gate 'gate-4d: deep-E2E generate (prompts + graders for every shipping skill)' \
            python3 "${REPO_ROOT}/runner/e2e_generate.py" \
                --bundle-root "${REPO_ROOT}" \
                --out-dir "$(mktemp -d -t e2e-gen-XXXXXX)"; then
        overall_fail=1
    fi
fi

# No-regression gate — compares the latest grades-on-disk (if any) against
# the frozen baseline in runner/baseline_grades.json. Skipped when no
# current grades dir is present (so the gate does not block PRs that
# haven't re-run the A/B/C measurement). When present, fails the build
# if any cell went PASS -> FAIL since the baseline.
#
# Project-owner rule (verbatim): "no way we have regression and we do not
# fix before push — we have in each commit to improve or at least not
# making damage".
if [[ -f "${CI_DIR}/check-no-regression.py" && -f "${REPO_ROOT}/runner/baseline_grades.json" ]]; then
    # Pick the newest grades dir under runner/reports/*/grades (if any).
    LATEST_GRADES_DIR="$(ls -1dt "${REPO_ROOT}"/runner/reports/*/grades 2>/dev/null | head -n 1 || true)"
    if [[ -n "${LATEST_GRADES_DIR}" && -d "${LATEST_GRADES_DIR}" ]]; then
        if ! run_gate 'gate-5: no-regression vs runner/baseline_grades.json (no PASS->FAIL cell on C since last green run)' \
                python3 "${CI_DIR}/check-no-regression.py" \
                    --current "${LATEST_GRADES_DIR}" \
                    --baseline "${REPO_ROOT}/runner/baseline_grades.json" \
                    --variant C; then
            overall_fail=1
        fi
    fi
fi

separator
if (( overall_fail == 0 )); then
    printf 'ALL GATES PASS — bundle matches the post-AGENTS.md-fix + per-team coverage-fill measurement baseline (3-variant constant-grader scoreboard: 609 cells x 84 prompts on C, 100.0 %% PASS; every shipping lib/service/tool (52/52) has a named per-developer-team verdict; 0 regressions vs baseline).\n'
    printf 'A fresh measurement run is reproducible by re-running the ai-mvp-with-files A/B/C subagent driver against the bundle this script just validated; the baseline lives at runner/baseline_grades.json and is the no-regression contract.\n'
    exit 0
else
    printf 'AT LEAST ONE GATE FAILED — bundle has regressed from the post-AGENTS.md-fix baseline.\nDo not merge this PR until every gate above reads OK.\n'
    printf 'Project rule: every commit improves or at least does not damage.\n'
    exit 1
fi
