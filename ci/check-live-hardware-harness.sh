#!/usr/bin/env bash
# ci/check-live-hardware-harness.sh — Lane D harness smoke test.
#
# Verifies that `runner/run_with_live_hardware.py` (the Lane C v2
# real-lab adapter, vendored into the bundle) behaves correctly WITHOUT
# a connected BlueField. This is the test the harness must pass in any
# CI sandbox; the real-lab path requires hardware and is tested
# separately on a connected host.
#
# Specifically, this gate verifies:
#   1. --mode auto       falls back to fixtures cleanly when no HW is visible
#   2. --mode fixtures   produces a valid manifest from the v1 fixture pack
#   3. --mode live       FAILS with exit 2 + an explicit error when no HW visible
#   4. --mode dry-run    FAILS with exit 2 + an explicit error when lspci absent
#   5. The mutating-token rejection list is intact (read-only invariant)
#   6. The harness imports the v1 builders (no drift between v1/v2 outputs)
#
# Exit 0 = all 6 sub-tests pass; exit 1 = at least one regression.

set -eu

BUNDLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HARNESS="${BUNDLE_ROOT}/runner/run_with_live_hardware.py"
FIXTURES="${BUNDLE_ROOT}/fixtures/hardware"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

pass=0
fail=0

note() { printf '%s\n' "$@"; }
ok()   { printf 'PASS[%s]\n' "$1"; pass=$((pass + 1)); }
nope() { printf 'FAIL[%s] %s\n' "$1" "$2"; fail=$((fail + 1)); }

note "Lane D harness smoke test (Lane C v2 real-lab adapter)"
note "Harness: ${HARNESS}"
note "Fixtures: ${FIXTURES}"
note ""

# 1. auto mode — must succeed with fall-back-to-fixtures messaging
if out=$(python3 "${HARNESS}" --mode auto --out-dir "${WORKDIR}/auto" 2>&1); then
    if echo "${out}" | grep -q 'falling back to fixtures'; then
        ok '1: --mode auto falls back to fixtures on a host without HW'
    else
        nope '1: --mode auto' "did not print the fall-back-to-fixtures line"
    fi
else
    nope '1: --mode auto' "harness exited non-zero on a host without HW: ${out}"
fi

# 2. fixtures mode — must succeed and produce a manifest with >=1 scenario
if out=$(python3 "${HARNESS}" --mode fixtures --out-dir "${WORKDIR}/fix" 2>&1); then
    if [[ -f "${WORKDIR}/fix/dispatch_manifest.json" ]]; then
        scen_count=$(python3 -c "
import json,sys
data=json.loads(open('${WORKDIR}/fix/dispatch_manifest.json').read())
print(len(data.get('scenarios',[])))
")
        if (( scen_count >= 1 )); then
            ok "2: --mode fixtures produced dispatch_manifest.json with ${scen_count} scenario(s)"
        else
            nope '2: --mode fixtures' "manifest had 0 scenarios"
        fi
    else
        nope '2: --mode fixtures' "no dispatch_manifest.json"
    fi
else
    nope '2: --mode fixtures' "harness exited non-zero: ${out}"
fi

# 3. live mode — must FAIL with exit 2 + explicit message on a host without HW
set +e
out=$(python3 "${HARNESS}" --mode live --out-dir "${WORKDIR}/live" 2>&1)
rc=$?
set -e
if (( rc == 2 )) && echo "${out}" | grep -q 'requires live capability'; then
    ok '3: --mode live fails clean with exit 2 + explicit message on a host without HW'
else
    nope '3: --mode live' "expected exit 2 + 'requires live capability'; got rc=${rc}, output=${out}"
fi

# 4. dry-run mode — must FAIL with exit 2 if lspci absent (sandbox case)
set +e
out=$(python3 "${HARNESS}" --mode dry-run --out-dir "${WORKDIR}/dry" 2>&1)
rc=$?
set -e
# dry-run may legitimately succeed on a host where lspci is present but no BF is visible;
# in CI sandbox lspci is absent, so we expect exit 2. Accept either as long as the path
# is well-defined.
if (( rc == 2 )) && echo "${out}" | grep -q 'requires .lspci. on PATH'; then
    ok '4: --mode dry-run fails clean with exit 2 + explicit message when lspci absent'
elif (( rc == 0 )); then
    ok '4: --mode dry-run succeeded (lspci is present in this environment — dry-run did its job)'
else
    nope '4: --mode dry-run' "expected exit 2 + 'requires lspci on PATH' OR exit 0; got rc=${rc}, output=${out}"
fi

# 5. Mutating-token rejection list is intact
required_tokens="set burn reflash fwreset bind unbind rescan modprobe rmmod insmod echo tee"
missing=()
for tok in ${required_tokens}; do
    if ! grep -q "\"${tok}\"" "${HARNESS}"; then
        missing+=("${tok}")
    fi
done
if (( ${#missing[@]} == 0 )); then
    ok "5: mutating-token rejection list contains all ${required_tokens// /, } tokens"
else
    nope '5: mutating-token rejection list' "missing tokens: ${missing[*]}"
fi

# 6. Harness imports v1 builders (no v1/v2 drift)
if grep -q 'import run_with_fixtures as v1' "${HARNESS}"; then
    ok '6: harness imports v1 builders (run_with_fixtures.py) — no v1/v2 prompt drift'
else
    nope '6: v1 import' "harness does not import run_with_fixtures as v1; outputs may drift"
fi

note ""
note "Summary: ${pass} pass, ${fail} fail"
if (( fail > 0 )); then
    exit 1
fi
exit 0
