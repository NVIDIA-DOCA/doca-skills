#!/usr/bin/env bash
# Run-9 gate: every externally-productized product named in
# AGENTS.md ## Non-goals #7 MUST have a routing-table row in
# skills/doca-public-knowledge-map/SKILL.md, and that row MUST
# contain a docs.nvidia.com URL.
#
# Why: an external user surfaced that the agent honored
# "recognize + name boundary" for SNAP but skipped "route with
# substance" (no per-product docs URL / no gotcha / no forum). The
# routing table closes that gap. This gate prevents the table from
# silently drifting out of sync with the rule.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

AGENTS_MD="AGENTS.md"
MAP_MD="skills/doca-public-knowledge-map/SKILL.md"

if [[ ! -f "$AGENTS_MD" ]]; then
  echo "FAIL: $AGENTS_MD not found"
  exit 1
fi
if [[ ! -f "$MAP_MD" ]]; then
  echo "FAIL: $MAP_MD not found"
  exit 1
fi

# Canonical list of products the bundle promises to route for. This
# list is intentionally hard-coded (not parsed out of AGENTS.md free
# text) so that an editorial reword of AGENTS.md cannot silently shrink
# the gate. If you genuinely want to retire a product from the routing
# contract, edit BOTH this list AND AGENTS.md ## Non-goals #7 in the
# same commit.
#
# Each entry is: "DISPLAY_NAME|REGEX_FOR_AGENTS_MD|REGEX_FOR_TABLE_ROW"
# REGEX_FOR_AGENTS_MD asserts the product is still listed in non-goal #7.
# REGEX_FOR_TABLE_ROW asserts the routing table has a row for it.
PRODUCTS=(
  "DOCA SNAP|DOCA SNAP Services|DOCA SNAP Services"
  "DOCA HBN|DOCA HBN Service|DOCA HBN Service"
  "DOCA BlueMan|DOCA BlueMan Service|DOCA BlueMan Service"
  "DOCA Virtio-net|DOCA Virtio-net Service|DOCA Virtio-net Service"
  "DOCA Telemetry Service (DTS) as-deployed|DOCA Telemetry Service (DTS) as-deployed|DOCA Telemetry Service .DTS. . as-deployed"
  "DOCA-DPACC-Compiler|DOCA-DPACC-Compiler|DOCA DPACC Compiler"
  "DPA-Tools|DPA-Tools|DPA Tools"
  "DOCA-DPU-CLI|DOCA-DPU-CLI|DOCA DPU CLI"
  "DOCA-Ngauge|DOCA-Ngauge|DOCA Ngauge"
  "doca-hugepages|doca-hugepages|doca-hugepages"
  "BlueField BSP / BFB / bfb-install / RShim|BlueField BSP / BFB|BlueField BSP / BFB"
  "DOCA Platform Framework (DPF)|DOCA Platform Framework (DPF)|DOCA Platform Framework \\(DPF\\)"
  "NVIDIA Network Operator|NVIDIA Network Operator|NVIDIA Network Operator"
  "MLNX_OFED separately installed|MLNX_OFED|MLNX_OFED"
  "NVIDIA UFM|NVIDIA UFM|NVIDIA UFM"
  "NVIDIA Cumulus Linux|NVIDIA Cumulus Linux|NVIDIA Cumulus Linux"
  "NVIDIA Firmware Tools (MFT)|NVIDIA Firmware Tools (MFT|NVIDIA Firmware Tools \\(MFT"
  "NVIDIA Rivermax SDK|NVIDIA Rivermax SDK|NVIDIA Rivermax SDK"
  "BlueField BMC software|BlueField BMC software|BlueField BMC Software"
  "DOCA Privileged Executor (DPE)|DOCA Privileged Executor (DPE)|DOCA Privileged Executor \\(DPE\\)"
  "NIC Configuration Operator|NIC Configuration Operator|NIC Configuration Operator"
  "NVIDIA NetQ|NVIDIA NetQ|NVIDIA NetQ"
  "NVIDIA NVOS|NVIDIA NVOS|NVIDIA NVOS"
  "NVIDIA Spectrum-X Validated Solution Stack|NVIDIA Spectrum-X Validated Solution Stack|NVIDIA Spectrum-X Validated Solution Stack"
  "NVIDIA GPU Operator|NVIDIA GPU Operator|NVIDIA GPU Operator"
)

FAILS=0

# ---------------------------------------------------------------------
# Gate 1: every product is still mentioned in AGENTS.md ## Non-goals #7
# ---------------------------------------------------------------------
# Extract the non-goal #7 paragraph (from the "7." line to the next
# blank line + "The shape" sentinel that closes the section).
NONGOAL7="$(awk '
  /^7\. \*\*Externally-productized/ {flag=1}
  flag {print}
  flag && /^The shape of a good agent response/ {flag=0}
' "$AGENTS_MD")"

if [[ -z "$NONGOAL7" ]]; then
  echo "FAIL: could not locate '## Non-goals' rule #7 in $AGENTS_MD"
  exit 1
fi

for entry in "${PRODUCTS[@]}"; do
  display="${entry%%|*}"
  rest="${entry#*|}"
  agents_re="${rest%%|*}"

  if ! grep -qF "$agents_re" <<<"$NONGOAL7"; then
    echo "FAIL: AGENTS.md ## Non-goals #7 no longer mentions '$display' (looking for substring '$agents_re')"
    FAILS=$((FAILS+1))
  fi
done

# ---------------------------------------------------------------------
# Gate 2: the routing-table H2 section exists in the knowledge map
# ---------------------------------------------------------------------
ROUTING_H2_LINE='## Externally-productized DOCA software — not in this bundle, but here is where to route'
if ! grep -qF "$ROUTING_H2_LINE" "$MAP_MD"; then
  echo "FAIL: $MAP_MD missing H2 '$ROUTING_H2_LINE'"
  echo "  This H2 is the canonical routing table referenced by AGENTS.md ## Non-goals #7."
  FAILS=$((FAILS+1))
fi

# ---------------------------------------------------------------------
# Gate 3: each product has a row in the routing table
# ---------------------------------------------------------------------
# Extract everything from the H2 above to the next H2 (## ).
ROUTING_TABLE="$(awk -v h2="$ROUTING_H2_LINE" '
  $0 == h2 {flag=1; next}
  flag && /^## / {flag=0}
  flag {print}
' "$MAP_MD")"

if [[ -z "$ROUTING_TABLE" ]]; then
  echo "FAIL: could not extract routing table body from $MAP_MD"
  exit 1
fi

for entry in "${PRODUCTS[@]}"; do
  display="${entry%%|*}"
  rest="${entry#*|}"
  table_re="${rest#*|}"

  if ! grep -qE "$table_re" <<<"$ROUTING_TABLE"; then
    echo "FAIL: routing table missing row for '$display' (regex '$table_re')"
    FAILS=$((FAILS+1))
  fi
done

# ---------------------------------------------------------------------
# Gate 4: every routing-table row has a docs.nvidia.com URL
# ---------------------------------------------------------------------
# Count table rows (lines that start with "| **" — the product column).
TABLE_ROWS="$(grep -cE '^\| \*\*' <<<"$ROUTING_TABLE" || true)"
if [[ "$TABLE_ROWS" -lt 25 ]]; then
  echo "FAIL: routing table has $TABLE_ROWS product rows; expected at least 25"
  FAILS=$((FAILS+1))
fi

# Each row that starts with "| **" must contain a docs.nvidia.com URL on
# the same line.
BAD_ROWS="$(grep -E '^\| \*\*' <<<"$ROUTING_TABLE" | grep -vE 'docs\.nvidia\.com' || true)"
if [[ -n "$BAD_ROWS" ]]; then
  echo "FAIL: the following routing-table rows are missing a docs.nvidia.com URL:"
  printf '  %s\n' "$BAD_ROWS"
  FAILS=$((FAILS+1))
fi

# ---------------------------------------------------------------------
# Gate 5: every routing-table row has a forum URL with a search hint
# ---------------------------------------------------------------------
NO_FORUM_ROWS="$(grep -E '^\| \*\*' <<<"$ROUTING_TABLE" | grep -vE 'forums\.developer\.nvidia\.com' || true)"
if [[ -n "$NO_FORUM_ROWS" ]]; then
  echo "FAIL: the following routing-table rows are missing forums.developer.nvidia.com URL:"
  printf '  %s\n' "$NO_FORUM_ROWS"
  FAILS=$((FAILS+1))
fi

# ---------------------------------------------------------------------
# Gate 6: AGENTS.md ## Non-goals #7 must reference the routing table
# (force the rule to point at the table, not just describe it abstractly)
# ---------------------------------------------------------------------
if ! grep -qF "doca-public-knowledge-map" <<<"$NONGOAL7"; then
  echo "FAIL: AGENTS.md ## Non-goals #7 must link to the doca-public-knowledge-map routing table"
  FAILS=$((FAILS+1))
fi

if ! grep -qF "externally-productized-doca-software" <<<"$NONGOAL7"; then
  echo "FAIL: AGENTS.md ## Non-goals #7 must link to the routing table anchor (#externally-productized-doca-software...)"
  FAILS=$((FAILS+1))
fi

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------
if [[ "$FAILS" -gt 0 ]]; then
  echo ""
  echo "FAIL: $FAILS non-goal-routing gate violation(s)"
  echo "  AGENTS.md ## Non-goals #7 and the routing table in"
  echo "  $MAP_MD MUST stay in sync."
  echo "  If you genuinely want to retire a product from the contract,"
  echo "  edit BOTH AGENTS.md AND this gate's PRODUCTS array in the same commit."
  exit 1
fi

echo "OK: non-goal routing contract is in sync (${#PRODUCTS[@]} products covered in AGENTS.md + routing table; every row has a docs.nvidia.com / network.nvidia.com URL + forums.developer.nvidia.com URL)"
