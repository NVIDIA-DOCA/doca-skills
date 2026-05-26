#!/usr/bin/env bash
# ci/check-doca-inventory.sh
#
# Strict 1:1 inventory gate between the doca-skills bundle and the doca/
# monorepo at the currently checked-out branch.
#
# Why this exists:
#   Reviewer feedback on the bundle: skills exist that don't map to any
#   doca/libs|services|tools directory, and some skill names use stale
#   naming that doca/ already renamed. The bundle's promise is to be
#   the canonical agent guidance for the DOCA SDK at a known version;
#   if the bundle's artifact list is not a strict 1:1 with what doca/
#   actually ships at that version, the promise is broken.
#
#   This gate enforces the 1:1 by reading doca/{libs,services,tools}/
#   directly and reporting every drift:
#     - MISSING:   doca/ has the artifact, doca-skills has no skill
#     - EXTRA:     doca-skills has the skill, doca/ has no artifact
#     - VERSION:   the DOCA version the bundle is aligned to (from doca/VERSION)
#
# Naming convention (canonical):
#   doca/libs/doca_<x>        →  doca-skills/skills/libs/doca-<x-with-dashes>
#   doca/services/<name>      →  doca-skills/skills/services/doca-<name-with-dashes>
#                                 (or doca-<name>-svc if doca/libs/doca_<name>
#                                  also exists and the -svc disambiguator is
#                                  needed)
#   doca/tools/<name>         →  doca-skills/skills/tools/doca-<name-with-dashes>
#
# Exclusion rules (artifacts NOT expected to have a public skill):
#   doca/libs/doca_gpunetio_internal   (internal-only)
#   doca/services/{base_image,framework}  (infra, not user-facing)
#   doca/tools/common                  (shared helper, not a user-facing tool)
#   meson.build files                  (build glue)
#
# Exit codes:
#   0  OK. Inventory aligned 1:1 (modulo declared exclusions).
#   1  FAIL. At least one MISSING or EXTRA entry.
#   2  USAGE.
#   3  ENV. Either doca/ not present or required dirs missing.
#
# Usage:
#   ci/check-doca-inventory.sh                     # default; HARD
#   ci/check-doca-inventory.sh --doca-root DIR     # override doca root
#   ci/check-doca-inventory.sh --skills-root DIR   # override skills root
#   ci/check-doca-inventory.sh --json              # JSON output

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
candidate="$SCRIPT_DIR"
REPO_ROOT=""
while [ "$candidate" != "/" ]; do
  if [ -d "$candidate/doca-skills" ] && [ -d "$candidate/doca" ]; then
    REPO_ROOT="$candidate"
    break
  fi
  candidate="$(dirname "$candidate")"
done
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

DOCA_ROOT="${DOCA_ROOT:-$REPO_ROOT/doca}"
SKILLS_ROOT="${SKILLS_ROOT:-$REPO_ROOT/doca-skills/skills}"
JSON_OUT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --doca-root)   DOCA_ROOT="$2";    shift 2 ;;
    --skills-root) SKILLS_ROOT="$2";  shift 2 ;;
    --json)        JSON_OUT=1;        shift ;;
    -h|--help)     sed -n '1,50p' "$0"; exit 2 ;;
    *)             echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ ! -d "$DOCA_ROOT" ];   then echo "ERR: doca root not found at $DOCA_ROOT"     >&2; exit 3; fi
if [ ! -d "$SKILLS_ROOT" ]; then echo "ERR: skills root not found at $SKILLS_ROOT" >&2; exit 3; fi
for d in libs services tools; do
  if [ ! -d "$DOCA_ROOT/$d" ];   then echo "ERR: $DOCA_ROOT/$d missing"   >&2; exit 3; fi
  if [ ! -d "$SKILLS_ROOT/$d" ]; then echo "ERR: $SKILLS_ROOT/$d missing" >&2; exit 3; fi
done

DOCA_VERSION="$(cat "$DOCA_ROOT/VERSION" 2>/dev/null || echo "unknown")"

python3 - "$DOCA_ROOT" "$SKILLS_ROOT" "$DOCA_VERSION" "$JSON_OUT" << 'PY'
import os, sys, json

DOCA_ROOT, SKILLS_ROOT, DOCA_VERSION, JSON_OUT = sys.argv[1:5]
JSON_OUT = JSON_OUT == "1"

# Artifacts in doca/{libs,services,tools}/ that are intentionally NOT in
# the public skill bundle. Each entry must come with a one-line reason
# so reviewers can audit the exclusion list.
EXCLUDE_DOCA = {
    ("libs",     "doca_gpunetio_internal"): "internal-only API, never public",
    ("services", "base_image"):             "shared container base image, not a user-facing service",
    ("services", "framework"):              "shared service framework, not a user-facing service",
    ("tools",    "common"):                 "shared helper, not a user-facing tool",
}

# Skills that exist in the bundle but have NO corresponding artifact in
# the currently-checked-out doca/ tree. Listed here only when the skill
# documents a tool / library / service that NVIDIA ships publicly in
# *some* DOCA build configuration (e.g. CUDA-enabled, RHEL-only) but the
# source directory is not present in our generic doca/ working tree.
# Each entry MUST come with a one-line reason and an authoritative public
# URL so reviewers can confirm the skill is grounded in real documentation,
# not fabricated content.
EXTRA_SKILL_ALLOWLIST = {
    ("tools", "doca-gpi-ib-write-lat"):
        "GPU-Initiated communication ib_write_lat benchmark — ships only in "
        "CUDA-enabled DOCA builds, source dir gated by NVCC at meson time. "
        "Skill is grounded in the public doca-gpi library API "
        "(docs.nvidia.com/doca/sdk/NVIDIA+DOCA+GPI+Programming+Guide). "
        "Allowlist tracked so future doca/ check-outs that DO ship the dir "
        "are picked up automatically as aligned (not EXTRA).",
}

def doca_name_to_skill(name):
    return "doca-" + name.removeprefix("doca_").replace("_", "-")

def list_doca_artifacts(slot):
    out = []
    base = os.path.join(DOCA_ROOT, slot)
    for entry in sorted(os.listdir(base)):
        full = os.path.join(base, entry)
        if not os.path.isdir(full):
            continue
        if entry.startswith("."):
            continue
        out.append(entry)
    return out

def list_skill_artifacts(slot):
    out = []
    base = os.path.join(SKILLS_ROOT, slot)
    for entry in sorted(os.listdir(base)):
        full = os.path.join(base, entry)
        if not os.path.isdir(full):
            continue
        out.append(entry)
    return out

results = {
    "doca_version": DOCA_VERSION,
    "doca_root":    DOCA_ROOT,
    "skills_root":  SKILLS_ROOT,
    "slots":        {},
    "exclusions":   [
        {"slot": s, "artifact": a, "reason": r}
        for (s, a), r in sorted(EXCLUDE_DOCA.items())
    ],
}

total_missing = 0
total_extra   = 0
total_aligned = 0

for slot in ("libs", "services", "tools"):
    doca_artifacts = list_doca_artifacts(slot)
    skill_artifacts = set(list_skill_artifacts(slot))

    expected_skills = {}     # skill name -> doca artifact name
    for a in doca_artifacts:
        if (slot, a) in EXCLUDE_DOCA:
            continue
        expected_skills[doca_name_to_skill(a)] = a

    expected_set = set(expected_skills.keys())

    missing = sorted(expected_set - skill_artifacts)
    extra_raw = sorted(skill_artifacts - expected_set)
    aligned = sorted(expected_set & skill_artifacts)

    # Filter out documented extras (skills whose underlying tool/lib/service
    # ships only in specific DOCA build configurations and isn't present in
    # our generic doca/ working tree).
    allowlisted_extras = sorted(
        e for e in extra_raw if (slot, e) in EXTRA_SKILL_ALLOWLIST
    )
    extra = sorted(e for e in extra_raw if (slot, e) not in EXTRA_SKILL_ALLOWLIST)

    # Some services keep a "-svc" disambiguator when a same-named lib exists.
    # E.g. doca/services/urom + doca/libs/doca_urom → skills/services/doca-urom-svc.
    # Treat a `<canonical>-svc` skill as satisfying its `<canonical>` requirement,
    # but only when the lib counterpart actually exists in doca/.
    if slot == "services":
        lib_set = set(list_doca_artifacts("libs"))
        promoted_missing = []
        for m in missing:
            doca_artifact = expected_skills[m]
            lib_counterpart = "doca_" + doca_artifact.replace("-", "_")
            svc_skill = m + "-svc"
            if lib_counterpart in lib_set and svc_skill in skill_artifacts:
                aligned.append(svc_skill)
                if svc_skill in extra:
                    extra.remove(svc_skill)
            else:
                promoted_missing.append(m)
        missing = sorted(promoted_missing)
        aligned = sorted(set(aligned))

    results["slots"][slot] = {
        "doca_count":          len(doca_artifacts),
        "excluded_count":      len([1 for a in doca_artifacts if (slot, a) in EXCLUDE_DOCA]),
        "expected_count":      len(expected_set),
        "skill_count":         len(skill_artifacts),
        "aligned_count":       len(aligned),
        "missing":             missing,
        "extra":               extra,
        "allowlisted_extras":  allowlisted_extras,
        "aligned":             aligned,
    }

    total_missing += len(missing)
    total_extra   += len(extra)
    total_aligned += len(aligned)

results["totals"] = {
    "aligned": total_aligned,
    "missing": total_missing,
    "extra":   total_extra,
}

if JSON_OUT:
    print(json.dumps(results, indent=2))
else:
    print(f"DOCA inventory alignment gate")
    print(f"=" * 60)
    print(f"doca/VERSION            : {DOCA_VERSION}")
    print(f"doca root               : {DOCA_ROOT}")
    print(f"doca-skills root        : {SKILLS_ROOT}")
    print(f"exclusions (declared)   : {len(EXCLUDE_DOCA)}")
    for (s, a), r in sorted(EXCLUDE_DOCA.items()):
        print(f"    - {s}/{a}  --  {r}")
    print()
    print(f"extra-skill allowlist   : {len(EXTRA_SKILL_ALLOWLIST)}")
    for (s, a), r in sorted(EXTRA_SKILL_ALLOWLIST.items()):
        print(f"    - {s}/{a}  --  {r}")
    print()
    for slot in ("libs", "services", "tools"):
        r = results["slots"][slot]
        print(f"[{slot}]")
        print(f"  doca/{slot}:      {r['doca_count']:>3} artifacts ({r['excluded_count']} excluded)")
        print(f"  expected skills: {r['expected_count']:>3}")
        print(f"  skills present:  {r['skill_count']:>3}")
        print(f"  aligned:         {r['aligned_count']:>3}")
        print(f"  MISSING:         {len(r['missing']):>3}", end="")
        if r['missing']:
            print(f"  --  {', '.join(r['missing'])}")
        else:
            print()
        print(f"  EXTRA:           {len(r['extra']):>3}", end="")
        if r['extra']:
            print(f"  --  {', '.join(r['extra'])}")
        else:
            print()
        if r['allowlisted_extras']:
            print(f"  allowlisted:     {len(r['allowlisted_extras']):>3}  --  {', '.join(r['allowlisted_extras'])}")
        print()
    print(f"TOTAL aligned: {total_aligned}")
    print(f"TOTAL MISSING: {total_missing}")
    print(f"TOTAL EXTRA:   {total_extra}")
    print()
    if total_missing == 0 and total_extra == 0:
        print("OK: skills bundle inventory is strictly 1:1 with doca/ at this branch.")
    else:
        print("FAIL: inventory drift detected. See MISSING / EXTRA above.")
        print("      MISSING = doca/ has the artifact, bundle has no skill (add).")
        print("      EXTRA   = bundle has the skill, doca/ has no artifact (delete or move).")

sys.exit(0 if (total_missing == 0 and total_extra == 0) else 1)
PY
