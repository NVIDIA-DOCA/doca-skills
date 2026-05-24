#!/usr/bin/env bash
# Gate-13: every SKILL.md in this bundle must validate cleanly against the
# AgentSkills.io open-standard reference validator (`skills-ref`) from
# https://github.com/agentskills/agentskills/tree/main/skills-ref.
#
# The AgentSkills.io spec (https://agentskills.io/specification) is the
# vendor-neutral metadata contract for agent skills. By validating every
# skill against the reference tool, this bundle guarantees that any
# AgentSkills.io-aware client (Anthropic Claude Code, Cursor, GitHub
# Copilot, in-house LLMs, etc.) can discover, route to, and load these
# skills without surprises.
#
# Behavior:
#   - If `skills-ref` is on $PATH or in the local cache, validate all
#     61 skill directories under skills/**/SKILL.md. Fail (exit 1)
#     on the first invalid skill.
#   - If the validator is not on $PATH and `uv` is available, install
#     skills-ref into a cache under ci/.skills-ref-cache/.venv and use
#     that.
#   - If neither `skills-ref` nor `uv` is available, print an actionable
#     install hint and exit 0 (soft skip) so the gate does not block
#     dev loops for users without uv installed. The hard requirement
#     is documented in README.md (the bundle release CI always has
#     uv + skills-ref available).
#
# Exit codes:
#   0 = all skills passed validation, OR validator unavailable (soft skip)
#   1 = at least one skill failed validation
#   2 = unexpected error (e.g. could not locate skills/ tree)

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
CACHE_DIR="${SCRIPT_DIR}/.skills-ref-cache"

if [[ ! -d "${SKILLS_DIR}" ]]; then
    echo "FAIL: skills/ tree not found at ${SKILLS_DIR}" >&2
    exit 2
fi

# Locate the validator.
SKILLS_REF=""
if command -v skills-ref >/dev/null 2>&1; then
    SKILLS_REF="$(command -v skills-ref)"
elif [[ -x "${CACHE_DIR}/.venv/bin/skills-ref" ]]; then
    SKILLS_REF="${CACHE_DIR}/.venv/bin/skills-ref"
elif command -v uv >/dev/null 2>&1; then
    # Install into local cache. Skip if offline / sandboxed.
    if [[ ! -d "${CACHE_DIR}/agentskills-src/skills-ref" ]]; then
        echo "INFO: cloning agentskills/skills-ref into ${CACHE_DIR}/agentskills-src ..."
        mkdir -p "${CACHE_DIR}"
        if ! git clone --depth 1 https://github.com/agentskills/agentskills.git \
                "${CACHE_DIR}/agentskills-src" 2>&1; then
            echo "INFO: could not clone skills-ref source (offline?). Soft-skipping AgentSkills.io gate."
            echo "      To install manually: cd ${CACHE_DIR}/agentskills-src/skills-ref && uv sync"
            exit 0
        fi
    fi
    echo "INFO: uv sync skills-ref into ${CACHE_DIR}/.venv ..."
    (
        cd "${CACHE_DIR}/agentskills-src/skills-ref"
        if ! uv sync 2>&1 | tail -5; then
            echo "INFO: uv sync failed; soft-skipping AgentSkills.io gate."
            exit 0
        fi
        ln -sfn "${CACHE_DIR}/agentskills-src/skills-ref/.venv" "${CACHE_DIR}/.venv"
    )
    if [[ -x "${CACHE_DIR}/agentskills-src/skills-ref/.venv/bin/skills-ref" ]]; then
        SKILLS_REF="${CACHE_DIR}/agentskills-src/skills-ref/.venv/bin/skills-ref"
    fi
fi

if [[ -z "${SKILLS_REF}" ]]; then
    cat <<EOF
SOFT-SKIP: AgentSkills.io reference validator (\`skills-ref\`) not found.

To install:
  git clone https://github.com/agentskills/agentskills.git /tmp/agentskills
  cd /tmp/agentskills/skills-ref && uv sync
  export PATH="\$PWD/.venv/bin:\$PATH"

Then re-run this gate. Bundle-release CI requires this gate to be green.
EOF
    exit 0
fi

echo "INFO: using validator at ${SKILLS_REF}"
echo "INFO: scanning ${SKILLS_DIR} for SKILL.md directories ..."

fails=0
total=0
fail_list=()
while IFS= read -r skill_md; do
    total=$((total + 1))
    skill_dir="$(dirname "${skill_md}")"
    if ! out="$("${SKILLS_REF}" validate "${skill_dir}" 2>&1)"; then
        fails=$((fails + 1))
        fail_list+=("${skill_dir#${REPO_ROOT}/}")
        echo ""
        echo "FAIL: ${skill_dir#${REPO_ROOT}/}"
        echo "${out}" | sed 's/^/  /'
    fi
done < <(find "${SKILLS_DIR}" -name SKILL.md -print | sort)

echo ""
if (( fails > 0 )); then
    echo "FAIL: ${fails} of ${total} skills failed AgentSkills.io validation:"
    for d in "${fail_list[@]}"; do
        echo "  - ${d}"
    done
    echo ""
    echo "Fix each listed SKILL.md so its YAML frontmatter conforms to the"
    echo "AgentSkills.io spec at https://agentskills.io/specification."
    exit 1
fi

echo "OK: all ${total} skills pass AgentSkills.io reference validation"
exit 0
