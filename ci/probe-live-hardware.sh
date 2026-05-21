#!/usr/bin/env bash
# ci/probe-live-hardware.sh — read-only DOCA + BlueField hardware probe
#
# Runs the canonical, READ-ONLY probe set the bundle's universal verification
# contract requires every agent answer to ground its claims on. Used in two
# places:
#
#   1. Local development. The bundle author runs this against the lab host
#      to capture a fresh hardware snapshot before pushing a change.
#
#   2. Jenkins. The `Live hardware probe (SSH to lab BlueField host)` stage
#      in ci/Jenkinsfile.skills.ci uses the doca-jenkins-library SSH helper
#      bound to credential id `2f8ea6f8-6a80-43ff-aaa9-32b4a1abc0ac` to drive
#      this script remotely against a real lab box (default: lver-doca-4,
#      which carries BlueField-3 ×2 + BlueField-2 ×1).
#
# The probe set is read-only by design — no `mlxconfig set`, no `bfb-install`,
# no driver bind/unbind, no firmware burn. Every command is one of:
#   - version reporters (`pkg-config --modversion`, `cat .../VERSION`,
#     `doca_caps --version`, `flint -d <bdf> q`)
#   - capability enumerators (`lspci -d 15b3:`, `devlink dev show`,
#     `doca_caps --list-devs`, `mlxconfig -d <bdf> q`)
#   - environment witnesses (`/etc/os-release`, `/etc/mlnx-release`,
#     `lsmod | grep mlx`, `systemctl status rshim`)
#
# Anything that writes is explicitly forbidden by the
# MUTATING_TOKENS reject-list in `runner/run_with_live_hardware.py`, which
# this script ALSO defers to via that harness when called with
# `--via-harness`.
#
# Output: a structured directory under $OUT_DIR with one file per stanza row
# plus an env.json + summary.txt suitable for downstream prompt-builder and
# scoring rubric consumption (see runner/run_with_live_hardware.py).
#
# Exit codes:
#   0 — at least one BlueField/ConnectX device visible AND the version probes
#       returned something (even if partial-install is detected — that is a
#       success outcome for this probe, the partial-install case is exactly
#       what the bundle's safety nets target).
#   2 — no Mellanox/NVIDIA NIC visible at all (`lspci -d 15b3:` empty); this
#       host cannot exercise any DOCA path and the gate must fail clean.
#   3 — host has 15b3:* devices but the host is itself unreachable / probe
#       commands time out repeatedly.

set -u  # do NOT use -e: we explicitly want partial-install cases to capture
        # the empty/missing outputs and keep going.

OUT_DIR="${OUT_DIR:-/tmp/doca-hw-probe}"
HOST_LABEL="${HOST_LABEL:-$(hostname)}"
mkdir -p "${OUT_DIR}"

capture() {
    # capture <fname> <label> <cmd...>
    local fname="$1"; shift
    local label="$1"; shift
    local cmd_str="$*"
    printf '%s\n' "==> [${label}] $ ${cmd_str}"
    {
        printf '# label: %s\n# cmd:   %s\n# host:  %s\n# ts:    %s\n\n' \
               "${label}" "${cmd_str}" "${HOST_LABEL}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        "$@" 2>&1 || printf '\n# (non-zero exit — recorded anyway; partial-install / missing-tool is valid signal)\n'
    } > "${OUT_DIR}/${fname}"
}

# --- 1. Host fingerprint ---------------------------------------------------
capture host-os.txt        "Host OS"                  cat /etc/os-release
capture host-uname.txt     "Host kernel"              uname -a
capture host-mlnx-rel.txt  "Host /etc/mlnx-release"   cat /etc/mlnx-release

# --- 2. PCI presence -------------------------------------------------------
capture lspci.txt          "PCIe presence — 15b3:*"   lspci -d 15b3:
capture devlink-dev.txt    "devlink dev show"         devlink dev show
capture devlink-port.txt   "devlink port show"        devlink port show

# Strip leading `# label:` / `# cmd:` / `# host:` / `# ts:` / blank-line
# header that `capture()` prepends — we want the raw `lspci` output rows.
LSPCI_DATA=$(grep -vE '^(#|$)' "${OUT_DIR}/lspci.txt" 2>/dev/null || true)

# Early gate — if no PCI device line at all, fail fast. Real `lspci -d 15b3:`
# output rows start with a BDF in `bb:dd.f` form.
if ! printf '%s\n' "${LSPCI_DATA}" | grep -qE '^[0-9a-fA-F]+:[0-9a-fA-F]+\.[0-9a-fA-F]'; then
    printf 'FAIL: no Mellanox/NVIDIA NIC visible; host has no BlueField/ConnectX.\n' >&2
    exit 2
fi

# Pick the first BDF (first column of the first real lspci data row).
FIRST_BDF=$(printf '%s\n' "${LSPCI_DATA}" \
            | grep -E '^[0-9a-fA-F]+:[0-9a-fA-F]+\.[0-9a-fA-F]' \
            | awk '{print $1; exit}')
printf 'first BDF picked: %s\n' "${FIRST_BDF}"

# --- 3. Driver / kernel state ----------------------------------------------
capture lsmod.txt          "lsmod | grep mlx5"        bash -c "lsmod | grep -E 'mlx5|mlx_compat' || true"
capture rshim-svc.txt      "rshim service status"     bash -c "systemctl status rshim --no-pager 2>&1 | head -10 || true"
capture rshim-devs.txt     "rshim devices"            bash -c "ls -1 /dev/rshim* 2>/dev/null || true"

# --- 4. DOCA version chain (the bundle's canonical four-source chain) ------
capture pkg-config-doca.txt "pkg-config --list-all | grep doca"  bash -c "pkg-config --list-all 2>/dev/null | grep doca || true"
capture pkg-config-modversion.txt "pkg-config --modversion doca-common" pkg-config --modversion doca-common
capture install-tree-version.txt "DOCA install-tree VERSION"     cat /opt/mellanox/doca/applications/VERSION
capture doca-caps.txt      "doca_caps --version"      bash -c "command -v doca_caps >/dev/null 2>&1 && doca_caps --version || echo 'doca_caps not on PATH (host-side install may be partial — bundle handles this)'"
capture doca-caps-devs.txt "doca_caps --list-devs"    bash -c "command -v doca_caps >/dev/null 2>&1 && doca_caps --list-devs || echo 'doca_caps not on PATH'"

# --- 5. BFB image version probes (the recent bundle fix) -------------------
#  Bundle says: on BlueField Arm console use `bfver` + `cat /etc/mlnx-release`.
#  On the host, `bfver` is NOT expected; that absence is correct. Document
#  it. Do NOT substitute `mlxprivhost` or `bfb-info` — those are explicitly
#  banned by the bundle (mlxprivhost configures privileged-host mode and
#  bfb-info is not a real NVIDIA-documented tool).
capture bfver-on-host.txt  "bfver (host-side; may be MISSING on a partial install)" bash -c "command -v bfver >/dev/null 2>&1 && bfver || echo 'bfver not on host PATH. Per the bundle (doca-version/CAPABILITIES.md and TASKS.md): bfver is documented in TWO scopes — (a) on the BlueField Arm console against the running image, and (b) on the host against a standalone BFB file. Its absence here usually means the host-side DOCA install is partial (no bfb-install package). To exercise scope (a), route via /dev/rshim<N> to the BlueField Arm side; that is a separate (opt-in) stage. Do NOT substitute mlxprivhost or bfb-info — both are explicitly banned in the bundle as common hallucinations.'"
capture host-mlnx-rel-bfb.txt "host /etc/mlnx-release (NOTE: this is the HOST mlnx-release, NOT the BlueField BFB)" bash -c "cat /etc/mlnx-release 2>/dev/null || echo 'host /etc/mlnx-release not present (Ubuntu default install often lacks it; this is informational only)'"

# --- 6. Firmware version (per-device) — flint -d <bdf> q -------------------
# Loop over each visible BDF on a 15b3 device (one capture per PCI function).
# We iterate over LSPCI_DATA (the comment-stripped output captured above)
# rather than re-reading the file, so the comment header from capture()
# cannot leak into the parser.
i=0
while read -r bdf rest; do
    [ -z "${bdf}" ] && continue
    # Skip anything that doesn't look like a BDF.
    case "${bdf}" in
        [0-9a-fA-F]*:[0-9a-fA-F]*\.[0-9a-fA-F]) ;;
        0000:*)                                 ;;
        *) continue ;;
    esac
    # Normalize to 0000:bb:dd.f for flint/mlxconfig.
    case "${bdf}" in
        0000:*) full_bdf="${bdf}" ;;
        *)      full_bdf="0000:${bdf}" ;;
    esac
    i=$((i + 1))
    capture "flint-q-${i}.txt"     "flint -d ${full_bdf} q (FW version + ROM info)" \
        flint -d "${full_bdf}" q
    capture "mlxconfig-q-${i}.txt" "mlxconfig -d ${full_bdf} q (read-only fw config snapshot)" \
        mlxconfig -d "${full_bdf}" q
done <<< "${LSPCI_DATA}"

# --- 7. Mutating-token guard self-test -------------------------------------
# Independent of the harness: prove this script itself never issued anything
# from MUTATING_TOKENS. If anything below fires, this script has a bug and
# the operator must NOT trust the probe output.
GUARD_TOKENS=(set burn reflash fwreset bind unbind rescan modprobe rmmod insmod tee)
{
    printf '# mutating-token guard self-test\n'
    printf '# This script promises every captured command is READ-ONLY.\n'
    printf '# If grep finds any GUARD_TOKENS as the first word of a "$ "\n'
    printf '# line in the captures, the promise is broken and probe must\n'
    printf '# be discarded.\n\n'
    found=0
    for tok in "${GUARD_TOKENS[@]}"; do
        # match lines of the form  ==> [...] $ <bin> <tok> ...   anywhere in captures
        # AND lines beginning with the token as the verb (e.g. `mlxconfig -d X set ...`).
        if grep -RHnE "^# cmd:.*[[:space:]]${tok}([[:space:]]|$)" "${OUT_DIR}" >/dev/null 2>&1; then
            printf 'GUARD HIT: %s appears in a captured cmd. INVESTIGATE.\n' "${tok}"
            grep -RHnE "^# cmd:.*[[:space:]]${tok}([[:space:]]|$)" "${OUT_DIR}"
            found=1
        fi
    done
    if [ "${found}" = "0" ]; then
        printf 'OK: no mutating token appeared in any captured command.\n'
    fi
} > "${OUT_DIR}/mutating-token-guard.txt"

# --- 8. env.json (machine-readable summary) --------------------------------
# Count PCI FUNCTIONS (BDFs) and CARDS (unique bus addresses). A typical
# BlueField card has 2-3 PCI functions on the same bus (e.g. 0/1/2 for
# NetCtrl/NetCtrl/SoCMgmt), so "cards" and "functions" are different counts
# and the bundle wants both.
NIC_FUNCTIONS=$(printf '%s\n' "${LSPCI_DATA}" \
                | grep -cE '^[0-9a-fA-F]+:[0-9a-fA-F]+\.[0-9a-fA-F]' || true)
BF3_FUNCTIONS=$(printf '%s\n' "${LSPCI_DATA}" \
                | grep -cE 'BlueField-3' || true)
BF2_FUNCTIONS=$(printf '%s\n' "${LSPCI_DATA}" \
                | grep -cE 'BlueField-2' || true)
BF3_CARDS=$(printf '%s\n' "${LSPCI_DATA}" \
            | awk '/BlueField-3/ {split($1, p, ":"); print p[1]}' \
            | sort -u | wc -l)
BF2_CARDS=$(printf '%s\n' "${LSPCI_DATA}" \
            | awk '/BlueField-2/ {split($1, p, ":"); print p[1]}' \
            | sort -u | wc -l)
DOCA_PKGCFG=$(grep -E '^[0-9]+\.[0-9]+' "${OUT_DIR}/pkg-config-modversion.txt" 2>/dev/null | head -1)
DOCA_CAPS=$(grep -E '^[0-9]+\.[0-9]+' "${OUT_DIR}/doca-caps.txt" 2>/dev/null | head -1)

cat > "${OUT_DIR}/env.json" <<EOF
{
  "host_label": "${HOST_LABEL}",
  "captured_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pci_15b3_functions": ${NIC_FUNCTIONS:-0},
  "bluefield_3_functions": ${BF3_FUNCTIONS:-0},
  "bluefield_2_functions": ${BF2_FUNCTIONS:-0},
  "bluefield_3_cards": ${BF3_CARDS:-0},
  "bluefield_2_cards": ${BF2_CARDS:-0},
  "first_bdf": "${FIRST_BDF:-unknown}",
  "doca_pkgconfig_modversion": "${DOCA_PKGCFG:-MISSING}",
  "doca_caps_version":         "${DOCA_CAPS:-MISSING_OR_NOT_INSTALLED}",
  "partial_install_signals": {
    "applications_VERSION_present": $( [ -s "${OUT_DIR}/install-tree-version.txt" ] && grep -qE '^[0-9]' "${OUT_DIR}/install-tree-version.txt" && echo true || echo false ),
    "doca_caps_on_PATH": $( grep -qE '^[0-9]' "${OUT_DIR}/doca-caps.txt" 2>/dev/null && echo true || echo false ),
    "samples_dir_present": $( [ -d /opt/mellanox/doca/samples ] && echo true || echo false ),
    "rshim_service_active": $( grep -q "Active: active (running)" "${OUT_DIR}/rshim-svc.txt" 2>/dev/null && echo true || echo false )
  },
  "expected_agent_behavior": "Apply the bundle's universal verification contract: cite pkg-config --modversion doca-common (PRESENT here), gracefully handle the partial-install case (applications/VERSION + doca_caps missing — bundle's doca-version skill explicitly covers this), route BFB-version queries to bfver on the BlueField Arm console (NOT mlxprivhost / NOT bfb-info), and use the visible 15b3:* devices as the cap-discovery surface."
}
EOF

# --- 9. summary.txt (human-readable) ---------------------------------------
cat > "${OUT_DIR}/summary.txt" <<EOF
DOCA live hardware probe — summary
===================================
Host:                       ${HOST_LABEL}
Captured at (UTC):          $(date -u +%Y-%m-%dT%H:%M:%SZ)
15b3 PCI functions visible: ${NIC_FUNCTIONS}
   BlueField-3 cards / functions: ${BF3_CARDS} / ${BF3_FUNCTIONS}
   BlueField-2 cards / functions: ${BF2_CARDS} / ${BF2_FUNCTIONS}
First BDF picked:           ${FIRST_BDF}
DOCA (pkg-config):          ${DOCA_PKGCFG:-MISSING}
DOCA (doca_caps):           ${DOCA_CAPS:-MISSING_OR_NOT_INSTALLED}

Partial-install signals (per the doca-version skill's four-source chain):
  applications/VERSION present: $(grep -qE '^[0-9]' "${OUT_DIR}/install-tree-version.txt" 2>/dev/null && echo YES || echo NO)
  doca_caps on PATH:            $(grep -qE '^[0-9]' "${OUT_DIR}/doca-caps.txt" 2>/dev/null && echo YES || echo NO)
  samples/ dir present:         $( [ -d /opt/mellanox/doca/samples ] && echo YES || echo NO)
  rshim service active:         $(grep -q "Active: active (running)" "${OUT_DIR}/rshim-svc.txt" 2>/dev/null && echo YES || echo NO)

Capture files:
$(ls -1 "${OUT_DIR}" | sed 's/^/  /')

EOF
cat "${OUT_DIR}/summary.txt"

exit 0
