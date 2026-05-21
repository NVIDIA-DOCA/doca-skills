#!/usr/bin/env bash
# ci/check-coverage.sh
#
# Coverage audit for the doca-skills bundle. Verifies that every public
# DOCA library / service / tool listed in the live SDK index has at
# least one entry in the bundle's routing tables in
# doca-public-knowledge-map/SKILL.md.
#
# Why this exists:
#   The "agent focuses on what it knows" failure mode is structurally
#   caused by gaps in the bundle's catalog. If a library is missing from
#   the routing tables, agents loaded with the bundle will not point
#   users at it. This script makes that gap visible so PRs that add a
#   skill (or a new SDK release) cannot land without updating the
#   catalog.
#
# Outputs:
#   - Per-category coverage rows (libraries / services / tools).
#   - Bundle-wide coverage percentage.
#   - One YAML / JSON-friendly summary at the end (for ab_runner to
#     pick up and put in the report).
#
# Exit codes:
#   0  = SOFT WARN. Coverage gaps printed; pipeline does NOT fail.
#         Phase-2 contract: every fail condition starts as SOFT WARN.
#   2  = HARD FAIL. Coverage below threshold (only when invoked with
#         --hard-fail-below=<pct>; default OFF). Reserved for after
#         3-5 runs of signal demonstrate the floor we want to enforce.
#   3  = Script error (ENV problem; not a content gap).
#
# Usage:
#   ci/check-coverage.sh                                 # SOFT WARN report
#   ci/check-coverage.sh --hard-fail-below=80            # HARD FAIL if <80%
#                                                        # routing-table coverage
#   ci/check-coverage.sh --skill-coverage-hard-fail-below=20
#                                                        # HARD FAIL if <20% of
#                                                        # EXPECTED_* artifacts
#                                                        # have a 3-file skill
#                                                        # dir (SKILL.md +
#                                                        # CAPABILITIES.md +
#                                                        # TASKS.md). SOFT WARN
#                                                        # otherwise.
#   ci/check-coverage.sh --prompt-coverage               # SOFT WARN (default)
#                                                        # per-artifact PROMPT
#                                                        # coverage check.
#   ci/check-coverage.sh --prompt-coverage-hard-fail     # HARD FAIL when any
#                                                        # libs/services/tools
#                                                        # skill lacks a
#                                                        # targeted prompt in
#                                                        # runner/prompts/.
#   ci/check-coverage.sh --report-only                   # only print the summary
#   ci/check-coverage.sh --json                          # machine-readable summary
set -eu

# Path resolution:
#   1. Bundle-layout (preferred): the script lives at <bundle>/ci/check-coverage.sh
#      and the bundle root carries skills/, runner/, ci/. In this layout
#      REPO_ROOT = <bundle> and PROMPTS_ROOT = <bundle>/runner/prompts/.
#   2. Legacy sibling layout: the script lives at <repo>/devops/ci/check-coverage.sh
#      and the <repo>/ root has both doca-skills/ and devops/ as siblings.
#      In this layout REPO_ROOT = <repo> and PROMPTS_ROOT = <repo>/devops/runner/prompts/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_PARENT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -d "$SCRIPT_PARENT/skills" ] && [ -d "$SCRIPT_PARENT/runner" ]; then
  # Bundle layout — the parent of ci/ IS the bundle.
  REPO_ROOT="$SCRIPT_PARENT"
else
  # Legacy sibling layout — walk up to find a doca-skills/ subdir.
  candidate="$SCRIPT_DIR"
  while [ "$candidate" != "/" ]; do
    if [ -d "$candidate/doca-skills" ]; then
      REPO_ROOT="$candidate"
      break
    fi
    candidate="$(dirname "$candidate")"
  done
  REPO_ROOT="${REPO_ROOT:-$SCRIPT_PARENT}"
fi
# When the script lives at <bundle>/ci/check-coverage.sh (the public-bundle
# layout, where the bundle root IS the repo root), default SKILLS_ROOT to
# the sibling skills/ folder rather than insisting on a doca-skills/ subdir.
if [ ! -d "${REPO_ROOT}/doca-skills" ] && [ -d "${REPO_ROOT}/skills" ]; then
  SKILLS_ROOT="${SKILLS_ROOT:-${REPO_ROOT}/skills}"
else
  SKILLS_ROOT="${SKILLS_ROOT:-${REPO_ROOT}/doca-skills/skills}"
fi
KMAP_FILE="${KMAP_FILE:-${SKILLS_ROOT}/doca-public-knowledge-map/SKILL.md}"
# The prompts harness is OPTIONAL — the public bundle does not ship it.
# Override with PROMPTS_ROOT=<dir> when running coverage from a workspace
# that has a prompts harness. The default search order: <repo>/runner/prompts/,
# <repo>/devops/runner/prompts/, then skip with a SOFT WARN.
if [ -z "${PROMPTS_ROOT:-}" ]; then
  if [ -d "${REPO_ROOT}/runner/prompts" ]; then
    PROMPTS_ROOT="${REPO_ROOT}/runner/prompts"
  elif [ -d "${REPO_ROOT}/devops/runner/prompts" ]; then
    PROMPTS_ROOT="${REPO_ROOT}/devops/runner/prompts"
  else
    PROMPTS_ROOT=""
  fi
fi

# --- argument parsing --------------------------------------------------------
HARD_FAIL_BELOW=""
SKILL_COV_HARD_FAIL_BELOW=""
PROMPT_COV_HARD_FAIL=0
ROUTING_HARD_FAIL=0
REPORT_ONLY=0
JSON_OUT=0
for a in "$@"; do
  case "$a" in
    --hard-fail-below=*)              HARD_FAIL_BELOW="${a#*=}" ;;
    --skill-coverage-hard-fail-below=*) SKILL_COV_HARD_FAIL_BELOW="${a#*=}" ;;
    --prompt-coverage)                : ;; # always-on; flag retained for clarity
    --prompt-coverage-hard-fail)      PROMPT_COV_HARD_FAIL=1 ;;
    --routing-discoverability-hard-fail) ROUTING_HARD_FAIL=1 ;;
    --report-only)                    REPORT_ONLY=1 ;;
    --json)                           JSON_OUT=1 ;;
    -h|--help)
      sed -n '1,60p' "$0"; exit 2 ;;
    *) echo "unknown arg: $a" >&2; exit 3 ;;
  esac
done

if [ ! -f "$KMAP_FILE" ]; then
  echo "ERR: knowledge map not found at $KMAP_FILE" >&2
  echo "ERR: set KMAP_FILE or SKILLS_ROOT" >&2
  exit 3
fi

# --- expected catalog --------------------------------------------------------
# Sourced from the live https://docs.nvidia.com/doca/sdk/DOCA-Libraries
# enumeration done in the round-2 coverage audit (audit row in
# doca-public-knowledge-map ## URL audit, batch 3). Update this list when
# the live SDK adds a library / service / tool. The CI re-audit cadence
# lives in the round2-backlog.
#
# The match key is the canonical URL slug fragment. The bundle is
# considered to "cover" an entry if that slug appears anywhere in the
# knowledge-map file (which is also where the routing-table rows live).

EXPECTED_LIBRARIES=(
  # PR3-final state: every entry maps 1:1 to a doca/libs/ directory at
  # doca/VERSION=3.5.0019. Strict alignment is now enforced by the
  # separate check-doca-inventory.sh HARD gate (which uses doca/{libs,
  # services,tools} as the source of truth). This hardcoded list remains
  # only for the per-public-URL knowledge-map cross-check that grew up
  # alongside the routing table. Update it in step with any new doca/libs/
  # entry on the next DOCA release.
  "DOCA-Libraries"             # umbrella
  "DOCA-Core"
  "DOCA-Common"
  "DOCA-Flow"
  "DOCA-Ethernet"
  "DOCA-RDMA"
  "DOCA-Verbs"
  "DOCA-DPA"
  "DOCA-Flow-DPA-Provider"
  "DOCA-GPUNetIO"
  "DOCA-GPI"
  "DOCA-Comch"
  "DOCA-Telemetry"
  "DOCA-Telemetry-Exporter"
  "DOCA-DMA"
  "DOCA-Compress"
  "DOCA-AES-GCM"
  "DOCA-SHA"
  "DOCA-Erasure-Coding"
  "DOCA-App-Shield"
  "DOCA-PCC"
  "DOCA-PCC-ZTR-RTTCC-Algo"
  "DOCA-UROM"
  "DOCA-Arg-Parser"
  "DOCA-Device-Emulation"
  "DOCA-MGMT"
  "DOCA-RDMI"
  "DOCA-Storage-Applications"
  "DOCA-Rivermax"
  "DOCA-STA"
  "DOCA-Reference-Applications"
)

EXPECTED_SERVICES=(
  # PR3-final state: 1:1 with doca/services/ at doca/VERSION=3.5.0019
  # (excluding the shared infra dirs base_image + framework). The
  # check-doca-inventory.sh HARD gate is the source of truth.
  "DOCA-Services"              # umbrella
  "DOCA-Management-Service-Guide"
  "DOCA-Firefly-Service-Guide"
  "DOCA-Flow-Inspector-Service-Guide"
  "DOCA-UROM-Service-Guide"
  "DOCA-Argus-Service-Guide"
  "DOCA-OS-Inspector-Service-Guide"
  "DOCA-Container-Deployment-Guide"
)

EXPECTED_TOOLS=(
  # PR3-final state: 1:1 with doca/tools/ at doca/VERSION=3.5.0019
  # (excluding the shared infra dir tools/common). The
  # check-doca-inventory.sh HARD gate is the source of truth.
  # DOCA-Flow-Tune is the consolidated single artifact (replaces
  # the historical -Tool / -Server pair).
  "DOCA-Tools"                 # umbrella
  "DOCA-Capabilities-Print-Tool"
  "DOCA-Bench"
  "DOCA-Bench-Extension"
  "DOCA-Comm-Channel-Admin-Tool"
  "DOCA-Flow-Tune"
  "DOCA-Flow-Perf"
  "DOCA-Flow-DPA-Perf"
  "DOCA-Flow-gRPC-Server"
  "DOCA-PCC-Counter-Tool"
  "DOCA-Socket-Relay"
  "DOCA-App-Shield-Config"
  "DOCA-DPA-HL-Tracer"
  "DOCA-GPI-IB-Write-Lat"
  "DOCA-GPUNetIO-IB-Write-BW"
  "DOCA-GPUNetIO-IB-Write-Lat"
  "DOCA-SHA-Offload-Engine"
  "DOCA-SPCX-CC"
  "DOCA-Telemetry-Utils"
)

# --- coverage check ----------------------------------------------------------
covered_count=0
missing_count=0
declare -a MISSING_LIBS=()
declare -a MISSING_SVCS=()
declare -a MISSING_TOOLS=()

check_one() {
  local slug="$1"
  if grep -qF "$slug" "$KMAP_FILE"; then
    covered_count=$((covered_count + 1))
    return 0
  else
    missing_count=$((missing_count + 1))
    return 1
  fi
}

for slug in "${EXPECTED_LIBRARIES[@]}"; do
  check_one "$slug" || MISSING_LIBS+=("$slug")
done

for slug in "${EXPECTED_SERVICES[@]}"; do
  check_one "$slug" || MISSING_SVCS+=("$slug")
done

for slug in "${EXPECTED_TOOLS[@]}"; do
  check_one "$slug" || MISSING_TOOLS+=("$slug")
done

# --- per-skill catalog: every <kind>/<name> dir must be in the catalog too --
# This is the OTHER half of the coverage check: a NEW skill landing in the
# tree without a corresponding row in doca-public-knowledge-map is itself
# a coverage gap (that's how Argus / DPACC / the other under-cataloged
# entries got missed in round 1).
declare -a MISSING_SKILL_ROWS=()
skill_dirs_count=0
skill_dirs_uncatalogued=0

while IFS= read -r d; do
  # Skip the top-level / umbrella skills; those carry the catalog itself.
  case "$d" in
    "$SKILLS_ROOT/doca-public-knowledge-map") continue ;;
    "$SKILLS_ROOT/doca-debug")                continue ;;
    "$SKILLS_ROOT/doca-setup")                continue ;;
    "$SKILLS_ROOT/doca-programming-guide")    continue ;;
  esac
  skill_dirs_count=$((skill_dirs_count + 1))
  skill_name="$(basename "$d")"
  # Strip the doca- prefix to get the routing token used in catalog rows
  # (e.g. doca-flow -> "doca-flow" appears in the prose; "skills/libs/doca-flow"
  # appears in the cross-link). Either match form is acceptable.
  if grep -qE "(${skill_name}|skills/(libs|services|tools)/${skill_name})" "$KMAP_FILE"; then
    :
  else
    skill_dirs_uncatalogued=$((skill_dirs_uncatalogued + 1))
    MISSING_SKILL_ROWS+=("$d")
  fi
done < <(find "$SKILLS_ROOT" -type d -mindepth 2 -name 'doca-*' \
            -not -path '*/.*' | sort)

# --- per-artifact SKILL coverage --------------------------------------------
# For each EXPECTED_* slug, check whether a 3-file skill directory
# (SKILL.md + CAPABILITIES.md + TASKS.md) exists for it under SKILLS_ROOT.
# This is the gate the user asked for: "every public DOCA lib/svc/tool
# has a corresponding skill directory". It starts as SOFT WARN; flip to
# HARD FAIL with --skill-coverage-hard-fail-below=<pct> once the bundle
# has caught up.

# Translate an EXPECTED_* slug to candidate skill directory names. Most
# slugs follow the convention lowercase-with-dashes; a handful have
# established short aliases (doca-dms for DOCA-Management-Service-Guide,
# doca-caps for DOCA-Capabilities-Print-Tool). Both legal names cause a
# match.
slug_to_skill_candidates() {
  local slug="$1"
  local generic
  generic="$(printf '%s' "$slug" | tr '[:upper:]' '[:lower:]' \
              | sed -e 's/-guide$//' -e 's/+tools$/-tools/')"
  case "$slug" in
    "DOCA-Management-Service-Guide")     echo "doca-dms doca-management-service" ;;
    "DOCA-Capabilities-Print-Tool")      echo "doca-caps doca-capabilities-print-tool doca-capabilities-print" ;;
    "DOCA-Ethernet")                     echo "doca-eth doca-ethernet" ;;
    "DOCA-App-Shield")                   echo "doca-apsh doca-app-shield" ;;
    "DOCA-Arg-Parser")                   echo "doca-argp doca-arg-parser" ;;
    "DOCA-Storage-Applications")         echo "doca-sta doca-storage-applications doca-storage" ;;
    "DOCA-Firefly-Service-Guide")        echo "doca-firefly" ;;
    "DOCA-Flow-Inspector-Service-Guide") echo "doca-flow-inspector" ;;
    "DOCA-UROM-Service-Guide")           echo "doca-urom-svc doca-urom-service" ;;
    "DOCA-Argus-Service-Guide")          echo "doca-argus doca-argus-svc" ;;
    "DOCA-OS-Inspector-Service-Guide")   echo "doca-os-inspector" ;;
    "DOCA-Container-Deployment-Guide")   echo "doca-container-deployment" ;;
    "DOCA-Device-Emulation")             echo "doca-devemu doca-device-emulation" ;;
    "DOCA-Rivermax")                     echo "doca-rmax doca-rivermax" ;;
    "DOCA-Comm-Channel-Admin-Tool")      echo "doca-comm-channel-admin" ;;
    "DOCA-Flow-Tune")                    echo "doca-flow-tune" ;;
    "DOCA-Flow-Perf")                    echo "doca-flow-perf" ;;
    "DOCA-Flow-DPA-Perf")                echo "doca-flow-dpa-perf" ;;
    "DOCA-Flow-gRPC-Server")             echo "doca-flow-grpc-server" ;;
    "DOCA-PCC-Counter-Tool")             echo "doca-pcc-counters" ;;
    "DOCA-Socket-Relay")                 echo "doca-socket-relay" ;;
    "DOCA-Bench-Extension")              echo "doca-bench-extension" ;;
    "DOCA-App-Shield-Config")            echo "doca-apsh-config" ;;
    "DOCA-DPA-HL-Tracer")                echo "doca-dpa-hl-tracer" ;;
    "DOCA-GPI-IB-Write-Lat")             echo "doca-gpi-ib-write-lat" ;;
    "DOCA-GPUNetIO-IB-Write-BW")         echo "doca-gpunetio-ib-write-bw" ;;
    "DOCA-GPUNetIO-IB-Write-Lat")        echo "doca-gpunetio-ib-write-lat" ;;
    "DOCA-SHA-Offload-Engine")           echo "doca-sha-offload-engine" ;;
    "DOCA-SPCX-CC")                      echo "doca-spcx-cc" ;;
    "DOCA-Telemetry-Utils")              echo "doca-telemetry-utils" ;;
    "DOCA-OS-Inspector-Service-Guide")   echo "doca-os-inspector" ;;
    "DOCA-Common")                       echo "doca-common" ;;
    "DOCA-Verbs")                        echo "doca-verbs" ;;
    "DOCA-MGMT")                         echo "doca-mgmt" ;;
    "DOCA-RDMI")                         echo "doca-rdmi" ;;
    "DOCA-GPI")                          echo "doca-gpi" ;;
    "DOCA-Flow-DPA-Provider")            echo "doca-flow-dpa-provider" ;;
    "DOCA-PCC-ZTR-RTTCC-Algo")           echo "doca-pcc-ztr-rttcc-algo" ;;
    # Umbrellas + cross-cutting catalogs that are intentionally NOT shipped
    # as discrete library skills (covered by routing tables / cross-cutting
    # skills instead).
    "DOCA-Core")                         echo "__umbrella__" ;; # core SDK surface, covered by doca-programming-guide
    "DOCA-Reference-Applications")       echo "__umbrella__" ;; # catalog of example apps, not a single library
    "DOCA-Libraries")                    echo "__umbrella__" ;; # umbrella; skip
    "DOCA-Services")                     echo "__umbrella__" ;;
    "DOCA-Tools")                        echo "__umbrella__" ;;
    *)                                   echo "$generic" ;;
  esac
}

artifact_has_skill() {
  local slug="$1"
  local candidates dir_name dir f
  candidates="$(slug_to_skill_candidates "$slug")"
  if [ "$candidates" = "__umbrella__" ]; then
    # Umbrella entries (DOCA-Libraries, DOCA-Services, DOCA-Tools) are
    # routing-table only; they intentionally don't have their own skill.
    return 0
  fi
  for dir_name in $candidates; do
    dir="$(find "$SKILLS_ROOT" -type d -name "$dir_name" 2>/dev/null | head -n 1)"
    if [ -n "$dir" ]; then
      local complete=1
      for f in SKILL.md CAPABILITIES.md TASKS.md; do
        [ -f "$dir/$f" ] || { complete=0; break; }
      done
      [ "$complete" -eq 1 ] && return 0
    fi
  done
  return 1
}

declare -a MISSING_SKILL_LIBS=()
declare -a MISSING_SKILL_SVCS=()
declare -a MISSING_SKILL_TOOLS=()
sk_lib_covered=0
sk_svc_covered=0
sk_tool_covered=0
sk_lib_umbrella=0
sk_svc_umbrella=0
sk_tool_umbrella=0

for slug in "${EXPECTED_LIBRARIES[@]}"; do
  candidates="$(slug_to_skill_candidates "$slug")"
  if [ "$candidates" = "__umbrella__" ]; then
    sk_lib_umbrella=$((sk_lib_umbrella + 1)); continue
  fi
  if artifact_has_skill "$slug"; then
    sk_lib_covered=$((sk_lib_covered + 1))
  else
    MISSING_SKILL_LIBS+=("$slug")
  fi
done
for slug in "${EXPECTED_SERVICES[@]}"; do
  candidates="$(slug_to_skill_candidates "$slug")"
  if [ "$candidates" = "__umbrella__" ]; then
    sk_svc_umbrella=$((sk_svc_umbrella + 1)); continue
  fi
  if artifact_has_skill "$slug"; then
    sk_svc_covered=$((sk_svc_covered + 1))
  else
    MISSING_SKILL_SVCS+=("$slug")
  fi
done
for slug in "${EXPECTED_TOOLS[@]}"; do
  candidates="$(slug_to_skill_candidates "$slug")"
  if [ "$candidates" = "__umbrella__" ]; then
    sk_tool_umbrella=$((sk_tool_umbrella + 1)); continue
  fi
  if artifact_has_skill "$slug"; then
    sk_tool_covered=$((sk_tool_covered + 1))
  else
    MISSING_SKILL_TOOLS+=("$slug")
  fi
done

sk_total_expected=$(( ${#EXPECTED_LIBRARIES[@]} + ${#EXPECTED_SERVICES[@]} + ${#EXPECTED_TOOLS[@]} \
                      - sk_lib_umbrella - sk_svc_umbrella - sk_tool_umbrella ))
sk_total_covered=$(( sk_lib_covered + sk_svc_covered + sk_tool_covered ))
if [ "$sk_total_expected" -gt 0 ]; then
  sk_covered_pct=$(( sk_total_covered * 100 / sk_total_expected ))
else
  sk_covered_pct=0
fi

# --- per-artifact PROMPT coverage -------------------------------------------
# For every libs/services/tools skill dir, verify ≥ 1 prompt YAML under
# PROMPTS_ROOT names it as either baseline_artifact: or in expected_skill_co_load:.
# This is the gate that prevents new skills from shipping without an A/B
# probe — and prevents the A/B framework from becoming a museum of stale
# prompts targeting deleted skills.

declare -a SKILLS_WITHOUT_PROMPT=()
declare -a PROMPTS_WITHOUT_SKILL=()
prompts_total=0
prompts_general=0
prompts_targeted=0

skill_dirs_count_for_prompts=0
skill_with_prompt_count=0

# Build two sets:
#   all_targetable_skills - libs/services/tools dirs only. Each MUST have
#     at least one targeted prompt; that is what the per-artifact
#     prompt-coverage gate verifies.
#   all_known_skills      - every doca-* skill dir under SKILLS_ROOT
#     (including top-level skills like doca-setup / doca-debug /
#     doca-public-knowledge-map / doca-programming-guide). Used for the
#     "is this prompt referring to a typo?" check so that legitimate
#     references via expected_skill_co_load to top-level skills are
#     recognized as valid.
all_targetable_skills=()
all_known_skills=()
while IFS= read -r d; do
  [ -f "$d/SKILL.md" ] || continue
  bn="$(basename "$d")"
  case "$d" in
    "$SKILLS_ROOT/libs/"*|"$SKILLS_ROOT/services/"*|"$SKILLS_ROOT/tools/"*)
      all_targetable_skills+=("$bn")
      skill_dirs_count_for_prompts=$((skill_dirs_count_for_prompts + 1))
      ;;
  esac
  all_known_skills+=("$bn")
done < <(find "$SKILLS_ROOT" -type d -name 'doca-*' 2>/dev/null | sort -u)

# Walk PROMPTS_ROOT and inspect each YAML file's baseline_artifact and
# expected_skill_co_load lines. A prompt with baseline_artifact: general
# (or no baseline_artifact: at all) counts as general; otherwise targeted.
all_prompt_targets=()
if [ -d "$PROMPTS_ROOT" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    prompts_total=$((prompts_total + 1))
    # baseline_artifact: may be top-level or indented under "context:".
    target="$(awk -F': *' '/^[[:space:]]*baseline_artifact:/ {gsub(/^[[:space:]]+/,"",$0); print $2; exit}' "$p" | tr -d '"' | tr -d "'" | sed 's/[[:space:]]*$//')"
    if [ -z "$target" ] || [ "$target" = "general" ]; then
      prompts_general=$((prompts_general + 1))
    else
      prompts_targeted=$((prompts_targeted + 1))
      all_prompt_targets+=("$target")
    fi
    # Also harvest expected_skill_co_load entries (multi-line list, may
    # be indented under context:). Use indentation-tolerant matching.
    awk '
      /^[[:space:]]*expected_skill_co_load:/ { flag=1; next }
      flag && /^[[:space:]]*-[[:space:]]+/ {
        line=$0
        sub(/^[[:space:]]*-[[:space:]]+/, "", line)
        gsub(/[\"\x27]/, "", line)
        sub(/[[:space:]]+$/, "", line)
        print line
        next
      }
      flag && /^[[:space:]]*[A-Za-z_]/ { flag=0 }
    ' "$p" >> /tmp/.coverage_co_load.$$
  done < <(find "$PROMPTS_ROOT" -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
fi
if [ -f "/tmp/.coverage_co_load.$$" ]; then
  while IFS= read -r co; do
    all_prompt_targets+=("$co")
  done < /tmp/.coverage_co_load.$$
  rm -f /tmp/.coverage_co_load.$$
fi

# Build a uniq'd set of targets for membership testing. Filter out empty
# strings (general prompts with no baseline_artifact: at all add nothing).
unique_targets="$(printf '%s\n' "${all_prompt_targets[@]:-}" | grep -v '^$' | sort -u || true)"

# Every targetable skill must appear in unique_targets.
for s in "${all_targetable_skills[@]:-}"; do
  [ -n "$s" ] || continue
  if [ -n "$unique_targets" ] && printf '%s\n' "$unique_targets" | grep -qx "$s"; then
    skill_with_prompt_count=$((skill_with_prompt_count + 1))
  else
    SKILLS_WITHOUT_PROMPT+=("$s")
  fi
done

# Every targeted prompt must point at a known skill (catches typo'd
# baseline_artifact: / expected_skill_co_load:). Match against the
# broader "known skills" set so legitimate references to top-level
# skills (doca-setup, doca-debug, ...) are not flagged.
if [ -n "$unique_targets" ]; then
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    found=0
    for s in "${all_known_skills[@]:-}"; do
      [ "$s" = "$t" ] && { found=1; break; }
    done
    [ "$found" -eq 1 ] || PROMPTS_WITHOUT_SKILL+=("$t")
  done <<< "$unique_targets"
fi

# --- per-skill ROUTING DISCOVERABILITY check --------------------------------
# Every libs/services/tools skill dir must be mentioned BY ITS SHORT NAME in
# BOTH the bundle's SKILLS.md (the entry-point index) AND the knowledge-map
# routing file. A skill that exists on disk but is missing from either is a
# "phantom" — fresh agents will never load it because the discovery walk
# (AGENTS.md -> SKILLS.md -> kmap -> per-skill SKILL.md) never references it.
# This gate exists because the audit at PR2 found 48 / 51 per-artifact skills
# were phantom after the bulk-author batches.
# Bundle-layout aware: when SKILLS.md is right next to skills/ in REPO_ROOT
# (i.e. we ARE the bundle), look there first; otherwise fall back to the
# legacy <repo>/doca-skills/SKILLS.md sibling location.
if [ -z "${SKILLS_INDEX_FILE:-}" ]; then
  if [ -f "${REPO_ROOT}/SKILLS.md" ]; then
    SKILLS_INDEX_FILE="${REPO_ROOT}/SKILLS.md"
  else
    SKILLS_INDEX_FILE="${REPO_ROOT}/doca-skills/SKILLS.md"
  fi
fi
declare -a ROUTING_MISSING_FROM_INDEX=()
declare -a ROUTING_MISSING_FROM_KMAP=()
routing_total=0
routing_ok_count=0
if [ -f "$SKILLS_INDEX_FILE" ] && [ -f "$KMAP_FILE" ]; then
  index_text="$(cat "$SKILLS_INDEX_FILE")"
  kmap_text="$(cat "$KMAP_FILE")"
  for s in "${all_targetable_skills[@]:-}"; do
    [ -n "$s" ] || continue
    routing_total=$((routing_total + 1))
    in_idx=0; in_kmap=0
    printf '%s\n' "$index_text" | grep -q "\b$s\b" && in_idx=1
    printf '%s\n' "$kmap_text"  | grep -q "\b$s\b" && in_kmap=1
    if [ "$in_idx" -eq 1 ] && [ "$in_kmap" -eq 1 ]; then
      routing_ok_count=$((routing_ok_count + 1))
    else
      [ "$in_idx" -eq 0 ]  && ROUTING_MISSING_FROM_INDEX+=("$s")
      [ "$in_kmap" -eq 0 ] && ROUTING_MISSING_FROM_KMAP+=("$s")
    fi
  done
fi
if [ "$routing_total" -gt 0 ]; then
  routing_pct=$(( routing_ok_count * 100 / routing_total ))
else
  routing_pct=0
fi

# --- summary ----------------------------------------------------------------
total_expected=$(( ${#EXPECTED_LIBRARIES[@]} + ${#EXPECTED_SERVICES[@]} + ${#EXPECTED_TOOLS[@]} ))
covered_pct=$(( covered_count * 100 / total_expected ))

# --- JSON helper: print a JSON array, safe for empty bash arrays ------------
# Usage: json_arr ARRAY_NAME
# Emits: ["a","b","c"]  (no items: [])
# Uses indirect array expansion so an unset/empty array under set -u is safe.
json_arr() {
  local name="$1"
  eval "local len=\${#${name}[@]:-0}"
  printf '['
  if [ "$len" -gt 0 ]; then
    eval "local arr=(\"\${${name}[@]}\")"
    local i=0 s
    for s in "${arr[@]}"; do
      [ "$i" -gt 0 ] && printf ', '
      printf '"%s"' "$s"
      i=$((i + 1))
    done
  fi
  printf ']'
}

if [ "$JSON_OUT" -eq 1 ]; then
  printf '{\n'
  printf '  "expected_total": %d,\n' "$total_expected"
  printf '  "covered_count": %d,\n' "$covered_count"
  printf '  "missing_count": %d,\n' "$missing_count"
  printf '  "covered_pct": %d,\n' "$covered_pct"
  printf '  "missing_libraries": '; json_arr MISSING_LIBS;   printf ',\n'
  printf '  "missing_services": ';  json_arr MISSING_SVCS;   printf ',\n'
  printf '  "missing_tools": ';     json_arr MISSING_TOOLS;  printf ',\n'
  printf '  "skill_dirs_total": %d,\n' "$skill_dirs_count"
  printf '  "skill_dirs_uncatalogued": %d,\n' "$skill_dirs_uncatalogued"
  printf '  "missing_skill_rows": ';  json_arr MISSING_SKILL_ROWS; printf ',\n'
  printf '  "skill_coverage": {\n'
  printf '    "expected_total":   %d,\n' "$sk_total_expected"
  printf '    "covered_total":    %d,\n' "$sk_total_covered"
  printf '    "covered_pct":      %d,\n' "$sk_covered_pct"
  printf '    "missing_libraries":'; json_arr MISSING_SKILL_LIBS;  printf ',\n'
  printf '    "missing_services": ';  json_arr MISSING_SKILL_SVCS;  printf ',\n'
  printf '    "missing_tools":    ';  json_arr MISSING_SKILL_TOOLS; printf '\n'
  printf '  },\n'
  printf '  "prompt_coverage": {\n'
  printf '    "skill_dirs_total":         %d,\n' "$skill_dirs_count_for_prompts"
  printf '    "skill_dirs_with_prompt":   %d,\n' "$skill_with_prompt_count"
  printf '    "prompts_total":            %d,\n' "$prompts_total"
  printf '    "prompts_general":          %d,\n' "$prompts_general"
  printf '    "prompts_targeted":         %d,\n' "$prompts_targeted"
  printf '    "skills_without_prompt": ';  json_arr SKILLS_WITHOUT_PROMPT; printf ',\n'
  printf '    "prompts_without_skill": ';  json_arr PROMPTS_WITHOUT_SKILL; printf '\n'
  printf '  },\n'
  printf '  "routing_discoverability": {\n'
  printf '    "skill_dirs_total":         %d,\n' "$routing_total"
  printf '    "skill_dirs_routed_ok":     %d,\n' "$routing_ok_count"
  printf '    "covered_pct":              %d,\n' "$routing_pct"
  printf '    "missing_from_index":       '; json_arr ROUTING_MISSING_FROM_INDEX; printf ',\n'
  printf '    "missing_from_kmap":        '; json_arr ROUTING_MISSING_FROM_KMAP; printf '\n'
  printf '  }\n'
  printf '}\n'
else
  echo "==================================================================="
  echo "DOCA-skills bundle coverage report"
  echo "==================================================================="
  echo "Expected (live SDK catalog): $total_expected entries"
  echo "  libraries: ${#EXPECTED_LIBRARIES[@]}"
  echo "  services:  ${#EXPECTED_SERVICES[@]}"
  echo "  tools:     ${#EXPECTED_TOOLS[@]}"
  echo "Covered in knowledge-map:    $covered_count entries  (${covered_pct}%)"
  echo "Missing from knowledge-map:  $missing_count entries"
  echo
  if [ "${#MISSING_LIBS[@]}" -gt 0 ]; then
    echo "MISSING libraries:"
    for s in "${MISSING_LIBS[@]}"; do echo "  - $s"; done
    echo
  fi
  if [ "${#MISSING_SVCS[@]}" -gt 0 ]; then
    echo "MISSING services:"
    for s in "${MISSING_SVCS[@]}"; do echo "  - $s"; done
    echo
  fi
  if [ "${#MISSING_TOOLS[@]}" -gt 0 ]; then
    echo "MISSING tools:"
    for s in "${MISSING_TOOLS[@]}"; do echo "  - $s"; done
    echo
  fi
  echo "-------------------------------------------------------------------"
  echo "Per-skill catalog cross-check"
  echo "-------------------------------------------------------------------"
  echo "Per-skill dirs (libs/services/tools): $skill_dirs_count"
  echo "  uncatalogued:                       $skill_dirs_uncatalogued"
  if [ "${#MISSING_SKILL_ROWS[@]}" -gt 0 ]; then
    echo "  Skills without a knowledge-map mention:"
    for s in "${MISSING_SKILL_ROWS[@]}"; do echo "    - $s"; done
  fi
  echo
  echo "-------------------------------------------------------------------"
  echo "Per-artifact SKILL coverage (every lib/service/tool has 3-file skill?)"
  echo "-------------------------------------------------------------------"
  echo "Expected (non-umbrella): $sk_total_expected"
  echo "Covered with skill dir:  $sk_total_covered  (${sk_covered_pct}%)"
  echo "  libraries: $sk_lib_covered/$(( ${#EXPECTED_LIBRARIES[@]} - sk_lib_umbrella ))"
  echo "  services:  $sk_svc_covered/$(( ${#EXPECTED_SERVICES[@]} - sk_svc_umbrella ))"
  echo "  tools:     $sk_tool_covered/$(( ${#EXPECTED_TOOLS[@]} - sk_tool_umbrella ))"
  if [ "${#MISSING_SKILL_LIBS[@]}" -gt 0 ]; then
    echo "  libraries without a 3-file skill dir:"
    for s in "${MISSING_SKILL_LIBS[@]}"; do echo "    - $s"; done
  fi
  if [ "${#MISSING_SKILL_SVCS[@]}" -gt 0 ]; then
    echo "  services without a 3-file skill dir:"
    for s in "${MISSING_SKILL_SVCS[@]}"; do echo "    - $s"; done
  fi
  if [ "${#MISSING_SKILL_TOOLS[@]}" -gt 0 ]; then
    echo "  tools without a 3-file skill dir:"
    for s in "${MISSING_SKILL_TOOLS[@]}"; do echo "    - $s"; done
  fi
  echo
  echo "-------------------------------------------------------------------"
  echo "Per-artifact PROMPT coverage (every libs/services/tools skill has ≥1 prompt?)"
  echo "-------------------------------------------------------------------"
  echo "Skill dirs (libs/services/tools): $skill_dirs_count_for_prompts"
  echo "Skill dirs with ≥1 prompt:        $skill_with_prompt_count"
  if [ -z "$PROMPTS_ROOT" ] || [ ! -d "$PROMPTS_ROOT" ]; then
    echo "Prompts harness: (none; PROMPTS_ROOT not set or directory missing — prompt coverage skipped)"
  else
    echo "Prompts under $PROMPTS_ROOT"
    echo "  total:    $prompts_total"
    echo "  general:  $prompts_general"
    echo "  targeted: $prompts_targeted"
  fi
  if [ "${#SKILLS_WITHOUT_PROMPT[@]}" -gt 0 ]; then
    echo "  Skills without a targeted prompt:"
    for s in "${SKILLS_WITHOUT_PROMPT[@]}"; do echo "    - $s"; done
  fi
  if [ "${#PROMPTS_WITHOUT_SKILL[@]}" -gt 0 ]; then
    echo "  Prompts targeting a missing skill (typo or stale prompt):"
    for s in "${PROMPTS_WITHOUT_SKILL[@]}"; do echo "    - $s"; done
  fi
  echo
  echo "-------------------------------------------------------------------"
  echo "Routing DISCOVERABILITY (every skill mentioned in SKILLS.md AND kmap?)"
  echo "-------------------------------------------------------------------"
  echo "Skill dirs (libs/services/tools): $routing_total"
  echo "Routed in both entry points:      $routing_ok_count  (${routing_pct}%)"
  if [ "${#ROUTING_MISSING_FROM_INDEX[@]}" -gt 0 ]; then
    echo "  Skills missing from doca-skills/SKILLS.md:"
    for s in "${ROUTING_MISSING_FROM_INDEX[@]}"; do echo "    - $s"; done
  fi
  if [ "${#ROUTING_MISSING_FROM_KMAP[@]}" -gt 0 ]; then
    echo "  Skills missing from doca-public-knowledge-map/SKILL.md:"
    for s in "${ROUTING_MISSING_FROM_KMAP[@]}"; do echo "    - $s"; done
  fi
  echo
fi

# --- exit policy -----------------------------------------------------------
exit_rc=0

if [ -n "$HARD_FAIL_BELOW" ]; then
  if [ "$covered_pct" -lt "$HARD_FAIL_BELOW" ]; then
    echo "FAIL: routing-table coverage ${covered_pct}% < hard-fail floor ${HARD_FAIL_BELOW}%" >&2
    exit_rc=2
  fi
fi

if [ -n "$SKILL_COV_HARD_FAIL_BELOW" ]; then
  if [ "$sk_covered_pct" -lt "$SKILL_COV_HARD_FAIL_BELOW" ]; then
    echo "FAIL: per-artifact skill coverage ${sk_covered_pct}% < hard-fail floor ${SKILL_COV_HARD_FAIL_BELOW}%" >&2
    exit_rc=2
  fi
fi

if [ "$PROMPT_COV_HARD_FAIL" -eq 1 ]; then
  if [ -z "$PROMPTS_ROOT" ] || [ ! -d "$PROMPTS_ROOT" ]; then
    echo "FAIL: --prompt-coverage-hard-fail requested but no prompts harness present (PROMPTS_ROOT='$PROMPTS_ROOT')." >&2
    echo "FAIL: set PROMPTS_ROOT=<dir> to your prompts harness, or drop --prompt-coverage-hard-fail when running the public bundle standalone." >&2
    exit_rc=2
  elif [ "${#SKILLS_WITHOUT_PROMPT[@]}" -gt 0 ] || [ "${#PROMPTS_WITHOUT_SKILL[@]}" -gt 0 ]; then
    echo "FAIL: per-artifact prompt coverage gaps detected (hard-fail mode)." >&2
    echo "FAIL: every libs/services/tools skill needs ≥1 prompt that names it." >&2
    exit_rc=2
  fi
fi

if [ "$missing_count" -gt 0 ] || [ "$skill_dirs_uncatalogued" -gt 0 ]; then
  echo "WARN: routing-table coverage gaps detected (SOFT WARN; not failing pipeline)." >&2
  echo "WARN: promote to HARD FAIL with --hard-fail-below=<pct> after 3-5 signal runs." >&2
fi

if [ "${#MISSING_SKILL_LIBS[@]}" -gt 0 ] || [ "${#MISSING_SKILL_SVCS[@]}" -gt 0 ] || [ "${#MISSING_SKILL_TOOLS[@]}" -gt 0 ]; then
  echo "WARN: per-artifact skill coverage gaps detected (SOFT WARN; not failing pipeline)." >&2
  echo "WARN: promote to HARD FAIL with --skill-coverage-hard-fail-below=<pct> after Wave 3 lands all libs/services/tools." >&2
fi

if [ "$PROMPT_COV_HARD_FAIL" -eq 0 ] && { [ "${#SKILLS_WITHOUT_PROMPT[@]}" -gt 0 ] || [ "${#PROMPTS_WITHOUT_SKILL[@]}" -gt 0 ]; }; then
  echo "WARN: per-artifact prompt coverage gaps detected (SOFT WARN; not failing pipeline)." >&2
  echo "WARN: pass --prompt-coverage-hard-fail to fail the build on these." >&2
fi

if [ "$ROUTING_HARD_FAIL" -eq 1 ]; then
  if [ "${#ROUTING_MISSING_FROM_INDEX[@]}" -gt 0 ] || [ "${#ROUTING_MISSING_FROM_KMAP[@]}" -gt 0 ]; then
    echo "FAIL: routing-discoverability gaps detected (hard-fail mode)." >&2
    echo "FAIL: every libs/services/tools skill must be mentioned in BOTH doca-skills/SKILLS.md AND doca-public-knowledge-map/SKILL.md." >&2
    exit_rc=2
  fi
elif [ "${#ROUTING_MISSING_FROM_INDEX[@]}" -gt 0 ] || [ "${#ROUTING_MISSING_FROM_KMAP[@]}" -gt 0 ]; then
  echo "WARN: routing-discoverability gaps detected (SOFT WARN; not failing pipeline)." >&2
  echo "WARN: pass --routing-discoverability-hard-fail to fail the build on these." >&2
fi

exit "$exit_rc"
