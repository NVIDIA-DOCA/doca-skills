#!/usr/bin/env bash
# ci/run-e2e-suite.sh — orchestrate the deep E2E suite end-to-end.
#
# Steps:
#   1. Generate prompts/ + graders/ + index.json for every artifact under
#      skills/{libs,services,tools}/ (`runner/e2e_generate.py`).
#   2. Dispatch each prompt to an agent. Two modes:
#         AGENT_CMD       — operator-supplied shell command. Receives the
#                           prompt file path as $1 and the response file
#                           path as $2; the command is responsible for
#                           writing the response.
#         AGENT_CMD unset — skip dispatch (generate-only). The CI gate
#                           then runs the aggregator with
#                           --allow-missing-grades so the run still
#                           produces structured artifacts the operator
#                           can inspect.
#   3. Dispatch each grader the same way (GRADER_CMD).
#   4. Aggregate (`runner/e2e_aggregate.py`).
#   5. Exit non-zero if blockers_total > 0 OR pass-rate < MIN_PASS_RATE
#      (default 1.0 — the "no regression, every commit improves or at
#      least does not damage" rule).
#
# Env vars (all optional unless noted):
#   BUNDLE_ROOT       (default: dir containing this script's parent, i.e.
#                      doca-skills/)
#   E2E_OUT_DIR       (default: $WORKSPACE/_run/e2e if WORKSPACE set, else
#                      /tmp/e2e_$(date +%s))
#   AGENT_CMD         "agent CLI invocation"; e.g.
#                      "cursor-agent --model claude-opus-4 --prompt-file"
#                      The script appends $prompt_path and $response_path.
#   GRADER_CMD        same shape as AGENT_CMD but for the strict grader pass.
#   MIN_PASS_RATE     float in [0.0, 1.0]; default 1.0.
#   PARALLEL          int; how many prompts to dispatch in parallel
#                      (default 4; 1 = serial).
#   ALLOW_MISSING_GRADES  if set non-empty, the aggregator tolerates
#                      missing grades/ files (use for partial runs).
#
# Exit codes:
#   0   suite passed (or generate-only run completed)
#   2   blocker or below-threshold pass-rate; gate fails
#   3   harness / generator error

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="${BUNDLE_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
WORKSPACE="${WORKSPACE:-}"
DEFAULT_OUT="${WORKSPACE:+${WORKSPACE}/_run/e2e}"
DEFAULT_OUT="${DEFAULT_OUT:-/tmp/e2e_$(date +%s)}"
E2E_OUT_DIR="${E2E_OUT_DIR:-${DEFAULT_OUT}}"
PARALLEL="${PARALLEL:-4}"
MIN_PASS_RATE="${MIN_PASS_RATE:-1.0}"

PY="${PY:-python3}"

echo "=== ci/run-e2e-suite.sh ==="
echo "  BUNDLE_ROOT     = ${BUNDLE_ROOT}"
echo "  E2E_OUT_DIR     = ${E2E_OUT_DIR}"
echo "  AGENT_CMD       = ${AGENT_CMD:-<unset; generate-only>}"
echo "  GRADER_CMD      = ${GRADER_CMD:-<unset; will not run grader>}"
echo "  PARALLEL        = ${PARALLEL}"
echo "  MIN_PASS_RATE   = ${MIN_PASS_RATE}"

if [ ! -f "${BUNDLE_ROOT}/AGENTS.md" ]; then
    echo "FATAL: ${BUNDLE_ROOT} does not look like a doca-skills bundle (no AGENTS.md)." >&2
    exit 3
fi

mkdir -p "${E2E_OUT_DIR}"

# --- 1. Generate prompts + graders -----------------------------------------
echo "=== [1/4] generate prompts + graders ==="
if ! "${PY}" "${BUNDLE_ROOT}/runner/e2e_generate.py" \
        --bundle-root "${BUNDLE_ROOT}" \
        --out-dir     "${E2E_OUT_DIR}"; then
    echo "FATAL: e2e_generate.py failed." >&2
    exit 3
fi

ART_COUNT=$(${PY} -c "import json,sys; print(len(json.load(open('${E2E_OUT_DIR}/index.json'))))")
echo "  generated suite for ${ART_COUNT} artifacts."

# Helper: dispatch one CMD per prompt in parallel, capped at $PARALLEL.
dispatch_dir() {
    local label="$1"; shift
    local cmd="$1"; shift          # the CMD string ('' = skip)
    local input_dir="$1"; shift    # prompts/ or graders/
    local input_suffix="$1"; shift # .prompt.txt or .grader.txt
    local output_dir="$1"; shift   # responses/ or grades/
    local output_suffix="$1"; shift # .md or .json

    if [ -z "${cmd}" ]; then
        echo "  [${label}] CMD unset; skipping dispatch."
        return 0
    fi

    mkdir -p "${output_dir}"
    local idx=0
    local pids=()
    for f in "${input_dir}"/*"${input_suffix}"; do
        [ -e "${f}" ] || continue
        local art
        art=$(basename "${f}" "${input_suffix}")
        local out="${output_dir}/${art}${output_suffix}"
        if [ -s "${out}" ]; then
            echo "  [${label}] skip ${art}: ${out} already present"
            continue
        fi
        ( bash -c "${cmd} '${f}' '${out}'" \
              > "${output_dir}/${art}.dispatch.log" 2>&1 \
              || echo "[${label}] dispatch failed for ${art}; see ${output_dir}/${art}.dispatch.log" ) &
        pids+=($!)
        idx=$((idx + 1))
        if [ "${#pids[@]}" -ge "${PARALLEL}" ]; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
        fi
    done
    for pid in "${pids[@]}"; do
        wait "${pid}" || true
    done
    echo "  [${label}] dispatched ${idx} job(s)."
}

# --- 2. Dispatch agent responses -------------------------------------------
echo "=== [2/4] dispatch agent (AGENT_CMD) ==="
dispatch_dir "agent" "${AGENT_CMD:-}" \
    "${E2E_OUT_DIR}/prompts"   ".prompt.txt" \
    "${E2E_OUT_DIR}/responses" ".md"

# --- 3. Dispatch graders ---------------------------------------------------
echo "=== [3/4] dispatch grader (GRADER_CMD) ==="
dispatch_dir "grader" "${GRADER_CMD:-}" \
    "${E2E_OUT_DIR}/graders" ".grader.txt" \
    "${E2E_OUT_DIR}/grades"  ".json"

# --- 4. Aggregate ----------------------------------------------------------
echo "=== [4/4] aggregate ==="
agg_args=("--suite-dir" "${E2E_OUT_DIR}" "--min-pass-rate" "${MIN_PASS_RATE}")
if [ -n "${ALLOW_MISSING_GRADES:-}" ] || [ -z "${AGENT_CMD:-}" ] || [ -z "${GRADER_CMD:-}" ]; then
    agg_args+=("--allow-missing-grades")
fi

agg_rc=0
"${PY}" "${BUNDLE_ROOT}/runner/e2e_aggregate.py" "${agg_args[@]}" || agg_rc=$?
if [ "${agg_rc}" -ne 0 ]; then
    echo "FAIL: e2e_aggregate.py exited ${agg_rc}." >&2
    exit "${agg_rc}"
fi

echo "OK: deep E2E suite complete. Artifacts under ${E2E_OUT_DIR}."
echo "    Aggregate: ${E2E_OUT_DIR}/aggregate.json"
echo "    Summary:   ${E2E_OUT_DIR}/summary.md"
exit 0
