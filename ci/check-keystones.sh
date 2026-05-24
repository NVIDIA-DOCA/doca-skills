#!/usr/bin/env bash
# ci/check-keystones.sh - structural keystone gate for the doca-skills bundle.
#
# Runs the deterministic "did anybody delete the load-bearing keystones?" check
# on the bundle layout AGENTS.md, doca-setup, doca-debug, doca-flow, doca-version,
# and doca-hardware-safety. Catches the most common regression class (someone
# refactors a skill file and accidentally drops the universal verification
# contract, the debug-loop contract, the deploy-loop bridge, the binding-layer
# stanza, the agent activation checklists, the canonical orientation teasers,
# or the Flow CT rollback overlay) without any LLM-driven re-scoring.
#
# The keystones are the load-bearing structural anchors measured in the
# 6-variant constant-grader scoreboard (A → C‴ = 20.0 % → 91.4 % YES, fully measured); deleting
# any of them in a future PR regresses the bundle to the prior wave's headline
# silently. This check makes that regression a HARD FAIL at PR time.
#
# Usage:
#   ci/check-keystones.sh [<doca-skills-root>]
#
# Default <doca-skills-root> is the parent of this script's directory
# (the bundle root, when this script lives at <bundle>/ci/check-keystones.sh).
# Override with an absolute path for CI integration that lints multiple
# bundle copies.
#
# Exit codes:
#   0   all keystones present and structurally valid
#   1   at least one keystone is missing, malformed, or out of place
#
# Output: one line per keystone with PASS / FAIL prefix and a one-sentence
# reason, plus a final summary line.

set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --self-test mode runs the gate, then deliberately perturbs each keystone in
# a scratch copy of the bundle and confirms the gate trips on every perturbation.
# This is the "find bugs in the gate itself" check; integrators should run it
# whenever this script is modified.
if [[ "${1:-}" == "--self-test" ]]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    BUNDLE_SRC="${REPO_ROOT}"
    BUNDLE_SRC="$(cd "${BUNDLE_SRC}" && pwd)"

    workdir="$(mktemp -d)"
    trap 'rm -rf "${workdir}"' EXIT

    printf '== self-test: stress-checking the keystone gate ==\n\n'

    # Use rsync to skip .git (cp -R hits permission-denied on macOS sandbox).
    mkdir -p "${workdir}/bundle"
    rsync -a --exclude='.git' --exclude='.git/' "${BUNDLE_SRC}/" "${workdir}/bundle/"

    printf '[baseline] running the gate against the unmodified bundle (must pass)\n'
    if ! "${SCRIPT_PATH}" "${workdir}/bundle" >/dev/null 2>&1; then
        printf 'FAIL[self-test]: baseline bundle did not pass the gate; cannot run self-test\n'
        exit 1
    fi
    printf 'OK\n\n'

    # Each entry: "label|path|sed-pattern-to-break"
    perturbations=(
        "AGENTS.md verification contract|AGENTS.md|s/^## The universal verification contract$/## BROKEN VC HEADER/"
        "AGENTS.md debug-loop contract|AGENTS.md|s/^## The universal debug-loop contract$/## BROKEN DLC HEADER/"
        "AGENTS.md binding stanza|AGENTS.md|s/^## Hardware binding-layer command stanza$/## BROKEN BS HEADER/"
        "AGENTS.md canonical teasers (Step 4)|AGENTS.md|s/^### Canonical answer-shape teasers/### BROKEN CT HEADER/"
        "doca-setup deploy-loop bridge (Step 4)|skills/doca-setup/CAPABILITIES.md|s/^### Deploy-loop bridge/### BROKEN DLB HEADER/"
        "doca-setup verification contract|skills/doca-setup/CAPABILITIES.md|s/^## Universal verification contract$/## BROKEN UVC HEADER/"
        "doca-setup binding stanza|skills/doca-setup/CAPABILITIES.md|s/^## Hardware binding-layer command stanza$/## BROKEN HBS HEADER/"
        "doca-debug debug-loop contract|skills/doca-debug/CAPABILITIES.md|s/^## Universal debug-loop contract$/## BROKEN UDLC HEADER/"
        "doca-flow flow-ct anchor|skills/libs/doca-flow/TASKS.md|s/^## flow-ct$/## BROKEN FC ANCHOR/"
        "doca-flow rollback overlay (Step 4)|skills/libs/doca-flow/TASKS.md|s/\\*\\*rollback overlay\\.\\*\\*/**BROKEN_ROLLBACK_LABEL**/"
        "doca-flow non-CT rollback anchor (Lane A)|skills/libs/doca-flow/TASKS.md|s/^## rollback$/## BROKEN ROLLBACK ANCHOR/"
        "doca-rdmi rollback anchor (Lane A)|skills/libs/doca-rdmi/TASKS.md|s/^## rollback$/## BROKEN ROLLBACK ANCHOR/"
        "doca-rdmi 5-phase debug-loop block (Lane A)|skills/libs/doca-rdmi/TASKS.md|s/5-phase universal debug-loop instantiation (RDMI)/BROKEN 5PHASE LABEL/"
        "doca-gpunetio rollback anchor (Lane A)|skills/libs/doca-gpunetio/TASKS.md|s/^## rollback$/## BROKEN ROLLBACK ANCHOR/"
        "doca-gpunetio 5-phase debug-loop block (Lane A)|skills/libs/doca-gpunetio/TASKS.md|s/5-phase universal debug-loop instantiation (GPUNetIO)/BROKEN 5PHASE LABEL/"
        "doca-compress rollback anchor (Lane A)|skills/libs/doca-compress/TASKS.md|s/^## rollback$/## BROKEN ROLLBACK ANCHOR/"
        "doca-compress 5-phase debug-loop block (Lane A)|skills/libs/doca-compress/TASKS.md|s/5-phase universal debug-loop instantiation (Compress)/BROKEN 5PHASE LABEL/"
        "doca-apsh rollback anchor (Lane A)|skills/libs/doca-apsh/TASKS.md|s/^## rollback$/## BROKEN ROLLBACK ANCHOR/"
        "doca-apsh 5-phase debug-loop block (Lane A)|skills/libs/doca-apsh/TASKS.md|s/5-phase universal debug-loop instantiation (Apsh)/BROKEN 5PHASE LABEL/"
        "AGENTS.md per-library rollback overlay table (Lane A)|AGENTS.md|s/^## Per-library rollback overlay/## BROKEN PL ROLLBACK HEADER/"
        "AGENTS.md beginner-orientation staged-roadmap rule (review feedback)|AGENTS.md|s/^### Beginner-orientation staged-roadmap rule/### BROKEN STAGED ROADMAP HEADER/"
        "doca-setup Stage 1 vs Stage 2 table (review feedback)|skills/doca-setup/TASKS.md|s/Stage 1 vs Stage 2 — open every/BROKEN STAGE TABLE LABEL/"
        "doca-setup NGC tag selection rule (review feedback)|skills/doca-setup/TASKS.md|s/^### How to pick an NGC tag without guessing$/### BROKEN NGC TAG HEADER/"
        "README.md Beginner roadmap (review feedback)|README.md|s/^## Beginner roadmap — Stage 1/## BROKEN BEGINNER ROADMAP/"
        "README.md resume-point hand-off (review feedback)|README.md|s/Resume point inside the container/BROKEN RESUME POINT/"
        "doca-setup/TASKS.md resume-point hand-off (review feedback)|skills/doca-setup/TASKS.md|s/resume point inside the container/BROKEN_resume_point/g;s/Resume point inside the container/BROKEN Resume Point/g"
        "doca-public-knowledge-map MAINTAINERS-NOTES sibling (audit history; internal-only, stripped from public bundle)|skills/doca-public-knowledge-map/MAINTAINERS-NOTES.md|s/^# Maintainer-only notes/# BROKEN MAINTAINERS HEADER/"
        "AUTHORING.md vendored at bundle root|AUTHORING.md|1s/^.*$/BROKEN AUTHORING HEADER (no leading hash)/"
        "CONTRIBUTING.md vendored at bundle root|CONTRIBUTING.md|s/^# Contributing/# BROKEN CONTRIBUTING/"
        "SECURITY.md vendored at bundle root|SECURITY.md|s/^# Security Policy/# BROKEN SECURITY POLICY/"
        "ci/check-skill.sh vendored into bundle|ci/check-skill.sh|s|^#!/usr/bin/env bash|# stripped shebang|"
        "ci/check-reference-hygiene.py vendored into bundle|ci/check-reference-hygiene.py|s|^#!/usr/bin/env python3|# stripped shebang|"
        "doca-hardware-safety activation checklist|skills/doca-hardware-safety/SKILL.md|s/Agent activation checklist/BROKEN AC LABEL/g;s/### Activation checklist/### BROKEN AC HEADER/g"
        "doca-version activation checklist|skills/doca-version/SKILL.md|s/Agent activation checklist/BROKEN AC LABEL/g;s/### Activation checklist/### BROKEN AC HEADER/g"
    )

    fails_caught=0
    fails_missed=0

    # Extra cross-gate self-test: inject an internal-only path leak into a
    # runtime SKILL.md and confirm the keystone gate trips it (via the
    # reference-hygiene gate it now runs).
    rm -rf "${workdir}/bundle"
    mkdir -p "${workdir}/bundle"
    rsync -a --exclude='.git' --exclude='.git/' "${BUNDLE_SRC}/" "${workdir}/bundle/"
    leak_target="${workdir}/bundle/skills/doca-setup/SKILL.md"
    if [[ -f "${leak_target}" ]]; then
        printf '\nSee [`devops/AUTHORING.md`](../../devops/AUTHORING.md) for design.\n' >> "${leak_target}"
        if "${SCRIPT_PATH}" "${workdir}/bundle" >/dev/null 2>&1; then
            printf 'FAIL[self-test/reference-hygiene gate cross-check] keystone gate did NOT trip on a synthetic internal-only path leak\n'
            fails_missed=$((fails_missed + 1))
        else
            printf 'PASS[self-test/reference-hygiene gate cross-check] keystone gate tripped on injected ../devops/ leak\n'
            fails_caught=$((fails_caught + 1))
        fi
    fi

    for entry in "${perturbations[@]}"; do
        label="${entry%%|*}"
        rest="${entry#*|}"
        relpath="${rest%%|*}"
        pattern="${rest#*|}"

        # restore a clean copy
        rm -rf "${workdir}/bundle"
        mkdir -p "${workdir}/bundle"
        rsync -a --exclude='.git' --exclude='.git/' "${BUNDLE_SRC}/" "${workdir}/bundle/"

        # perturb
        target="${workdir}/bundle/${relpath}"
        if [[ ! -f "${target}" ]]; then
            printf 'FAIL[self-test/%s] target file missing: %s\n' "${label}" "${relpath}"
            fails_missed=$((fails_missed + 1))
            continue
        fi
        sed -i.bak "${pattern}" "${target}"

        # run the gate; must fail
        if "${SCRIPT_PATH}" "${workdir}/bundle" >/dev/null 2>&1; then
            printf 'FAIL[self-test/%s] gate did NOT trip when keystone broken\n' "${label}"
            fails_missed=$((fails_missed + 1))
        else
            printf 'PASS[self-test/%s] gate tripped as expected\n' "${label}"
            fails_caught=$((fails_caught + 1))
        fi
    done

    printf '\nSelf-test summary: %d / %d perturbations correctly tripped the gate\n' \
        "${fails_caught}" "$((fails_caught + fails_missed))"
    if (( fails_missed > 0 )); then
        printf 'FAIL: %d perturbation(s) did NOT trip the gate; the gate has blind spots\n' "${fails_missed}"
        exit 1
    fi
    printf 'OK: every keystone perturbation was caught by the gate\n'
    exit 0
fi

BUNDLE_ROOT="${1:-${REPO_ROOT}}"
BUNDLE_ROOT="$(cd "${BUNDLE_ROOT}" && pwd)"

pass=0
fail=0

check() {
    local label="$1"
    local file="$2"
    local pattern="$3"
    if [[ ! -f "${file}" ]]; then
        printf 'FAIL[%s] missing file: %s\n' "${label}" "${file##${BUNDLE_ROOT}/}"
        fail=$((fail + 1))
        return
    fi
    if grep -qE "${pattern}" "${file}"; then
        printf 'PASS[%s]\n' "${label}"
        pass=$((pass + 1))
    else
        printf 'FAIL[%s] pattern not found in %s: /%s/\n' "${label}" "${file##${BUNDLE_ROOT}/}" "${pattern}"
        fail=$((fail + 1))
    fi
}

check_count() {
    local label="$1"
    local file="$2"
    local pattern="$3"
    local expected="$4"
    if [[ ! -f "${file}" ]]; then
        printf 'FAIL[%s] missing file: %s\n' "${label}" "${file##${BUNDLE_ROOT}/}"
        fail=$((fail + 1))
        return
    fi
    local actual
    actual="$(grep -cE "${pattern}" "${file}" || true)"
    if (( actual >= expected )); then
        printf 'PASS[%s] (%d matches; threshold %d)\n' "${label}" "${actual}" "${expected}"
        pass=$((pass + 1))
    else
        printf 'FAIL[%s] %d matches in %s, expected >= %d for /%s/\n' \
            "${label}" "${actual}" "${file##${BUNDLE_ROOT}/}" "${expected}" "${pattern}"
        fail=$((fail + 1))
    fi
}

printf 'Bundle root: %s\n\n' "${BUNDLE_ROOT}"
printf '=== AGENTS.md cross-cutting trigger keystones ===\n'
check 'AGENTS.md ## Cross-cutting overlay activation triggers' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^## Cross-cutting overlay activation triggers$'
check 'AGENTS.md ## The universal verification contract' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^## The universal verification contract$'
check 'AGENTS.md ## The universal debug-loop contract' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^## The universal debug-loop contract$'
check 'AGENTS.md ## Hardware binding-layer command stanza' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^## Hardware binding-layer command stanza$'
check 'AGENTS.md ### Canonical answer-shape teasers (Step 4)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^### Canonical answer-shape teasers'
check 'AGENTS.md deploy-loop bridge cross-reference (Step 4)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    'Deploy-loop bridge|deploy-loop bridge'

printf '\n=== AGENTS.md ground rules + non-goals ===\n'
check_count 'AGENTS.md ## Ground rules every agent must follow (>= 5 numbered)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^[0-9]\. \*\*' \
    5
check_count 'AGENTS.md ## Non-goals (>= 7 numbered)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^[0-9]\. \*\*' \
    7

printf '\n=== doca-setup keystones ===\n'
check 'doca-setup/CAPABILITIES.md ## Universal verification contract' \
    "${BUNDLE_ROOT}/skills/doca-setup/CAPABILITIES.md" \
    '^## Universal verification contract$'
check 'doca-setup/CAPABILITIES.md ### Deploy-loop bridge (Step 4)' \
    "${BUNDLE_ROOT}/skills/doca-setup/CAPABILITIES.md" \
    '^### Deploy-loop bridge'
check 'doca-setup/CAPABILITIES.md ## Hardware binding-layer command stanza' \
    "${BUNDLE_ROOT}/skills/doca-setup/CAPABILITIES.md" \
    '^## Hardware binding-layer command stanza$'
check_count 'doca-setup binding-layer stanza rows (>= 6 distinct rows)' \
    "${BUNDLE_ROOT}/skills/doca-setup/CAPABILITIES.md" \
    '^\| \*\*(PCIe presence|Driver / device state|NUMA topology|IRQ affinity|Firmware / configuration snapshot|Kernel module state)\*\*' \
    6

printf '\n=== doca-debug keystones ===\n'
check 'doca-debug/CAPABILITIES.md ## Universal debug-loop contract' \
    "${BUNDLE_ROOT}/skills/doca-debug/CAPABILITIES.md" \
    '^## Universal debug-loop contract$'

printf '\n=== doca-flow keystones ===\n'
check 'doca-flow/TASKS.md ## flow-ct' \
    "${BUNDLE_ROOT}/skills/libs/doca-flow/TASKS.md" \
    '^## flow-ct$'
check 'doca-flow/TASKS.md ## flow-ct rollback overlay (Step 4)' \
    "${BUNDLE_ROOT}/skills/libs/doca-flow/TASKS.md" \
    '\*\*rollback overlay\.\*\*'
check 'doca-flow/TASKS.md ## rollback (Lane A — non-CT pipeline-edit overlay)' \
    "${BUNDLE_ROOT}/skills/libs/doca-flow/TASKS.md" \
    '^## rollback$'

printf '\n=== Lane A per-library rollback overlays + 5-phase debug-loop instantiations ===\n'
check 'doca-rdmi/TASKS.md ## rollback (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-rdmi/TASKS.md" \
    '^## rollback$'
check 'doca-rdmi/TASKS.md 5-phase debug-loop instantiation (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-rdmi/TASKS.md" \
    '5-phase universal debug-loop instantiation \(RDMI\)'
check 'doca-gpunetio/TASKS.md ## rollback (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-gpunetio/TASKS.md" \
    '^## rollback$'
check 'doca-gpunetio/TASKS.md 5-phase debug-loop instantiation (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-gpunetio/TASKS.md" \
    '5-phase universal debug-loop instantiation \(GPUNetIO\)'
check 'doca-compress/TASKS.md ## rollback (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-compress/TASKS.md" \
    '^## rollback$'
check 'doca-compress/TASKS.md 5-phase debug-loop instantiation (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-compress/TASKS.md" \
    '5-phase universal debug-loop instantiation \(Compress\)'
check 'doca-apsh/TASKS.md ## rollback (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-apsh/TASKS.md" \
    '^## rollback$'
check 'doca-apsh/TASKS.md 5-phase debug-loop instantiation (Lane A)' \
    "${BUNDLE_ROOT}/skills/libs/doca-apsh/TASKS.md" \
    '5-phase universal debug-loop instantiation \(Apsh\)'
check 'AGENTS.md ## Per-library rollback overlay table (Lane A)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^## Per-library rollback overlay'

printf '\n=== Beginner-orientation staged-roadmap + NGC tag rule (review feedback wave) ===\n'
check 'AGENTS.md ### Beginner-orientation staged-roadmap rule (Stage 1 → Stage 2)' \
    "${BUNDLE_ROOT}/AGENTS.md" \
    '^### Beginner-orientation staged-roadmap rule'
check 'doca-setup/TASKS.md Stage 1 vs Stage 2 staged-roadmap table' \
    "${BUNDLE_ROOT}/skills/doca-setup/TASKS.md" \
    'Stage 1 vs Stage 2 — open every'
check 'doca-setup/TASKS.md ### How to pick an NGC tag without guessing' \
    "${BUNDLE_ROOT}/skills/doca-setup/TASKS.md" \
    '^### How to pick an NGC tag without guessing$'
check 'README.md ## Beginner roadmap (Stage 1 / Stage 2)' \
    "${BUNDLE_ROOT}/README.md" \
    '^## Beginner roadmap — Stage 1'
check 'README.md How to pick an NGC tag without guessing' \
    "${BUNDLE_ROOT}/README.md" \
    'How to pick an NGC tag without guessing'
check 'README.md "Resume point inside the container" hand-off (reviewer feedback)' \
    "${BUNDLE_ROOT}/README.md" \
    'Resume point inside the container'
check 'doca-setup/TASKS.md "resume point inside the container" hand-off (reviewer feedback)' \
    "${BUNDLE_ROOT}/skills/doca-setup/TASKS.md" \
    '[Rr]esume point inside the container'

printf '\n=== Self-containment hygiene (no internal-only path leaks; review feedback wave) ===\n'
check 'doca-public-knowledge-map MAINTAINERS-NOTES.md sibling (audit-history moved out of SKILL.md; internal-only, stripped from public bundle by make-public-bundle.sh)' \
    "${BUNDLE_ROOT}/skills/doca-public-knowledge-map/MAINTAINERS-NOTES.md" \
    '^# Maintainer-only notes'
check 'doca-public-knowledge-map/SKILL.md ## URL audit section is present (audit-history kept in maintainer sibling, summary stays in runtime SKILL.md)' \
    "${BUNDLE_ROOT}/skills/doca-public-knowledge-map/SKILL.md" \
    '^## URL audit'
check 'ci/check-skill.sh vendored into bundle (self-contained CI gate)' \
    "${BUNDLE_ROOT}/ci/check-skill.sh" \
    '^#!/usr/bin/env bash'
check 'ci/check-reference-hygiene.py vendored into bundle (durable safety net)' \
    "${BUNDLE_ROOT}/ci/check-reference-hygiene.py" \
    '^#!/usr/bin/env python3'
check 'AUTHORING.md vendored into bundle root (no devops/ sister-repo reference)' \
    "${BUNDLE_ROOT}/AUTHORING.md" \
    '^# '
check 'CONTRIBUTING.md vendored into bundle root' \
    "${BUNDLE_ROOT}/CONTRIBUTING.md" \
    '^# Contributing'
check 'SECURITY.md vendored into bundle root' \
    "${BUNDLE_ROOT}/SECURITY.md" \
    '^# Security Policy'

printf '\n=== Reference-hygiene gate must run clean against the bundle (review feedback wave) ===\n'
if python3 "${BUNDLE_ROOT}/ci/check-reference-hygiene.py" >/dev/null 2>&1; then
    printf 'PASS[reference-hygiene gate clean]\n'
    pass=$((pass + 1))
else
    printf 'FAIL[reference-hygiene gate] python3 ci/check-reference-hygiene.py exited non-zero — internal-only path leaks or missing files. Run the gate directly to see the violations.\n'
    fail=$((fail + 1))
fi

printf '\n=== doca-version + doca-hardware-safety activation checklists ===\n'
check 'doca-hardware-safety/SKILL.md activation checklist' \
    "${BUNDLE_ROOT}/skills/doca-hardware-safety/SKILL.md" \
    '(Agent activation checklist|### Activation checklist)'
check 'doca-version/SKILL.md activation checklist' \
    "${BUNDLE_ROOT}/skills/doca-version/SKILL.md" \
    '(Agent activation checklist|### Activation checklist)'

printf '\n=== Summary ===\n'
total=$((pass + fail))
printf 'Checks: %d total — %d pass, %d fail\n' "${total}" "${pass}" "${fail}"

if (( fail > 0 )); then
    printf '\nAt least one structural keystone is missing.\n'
    printf 'These keystones are load-bearing for the 6-variant constant-grader headline (A 20.0%% → C‴ 91.4%% YES, fully measured on all 12 prompts).\n'
    printf 'Deleting any of them silently regresses the bundle to the prior wave; do NOT merge this PR until they are restored.\n'
    exit 1
fi

printf '\nAll keystones present. Bundle structure matches the C‴ measurement baseline.\n'
exit 0
