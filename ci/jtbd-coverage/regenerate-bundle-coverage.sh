#!/usr/bin/env bash
# devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh
#
# Regenerates bundle-jtbd-coverage.md from the class-shape prompts under
# devops/runner/prompts/. Each prompt's `intent:` field (in the prompt's
# `context:` block) is the closest existing thing to a "JTBD the bundle is
# built to answer" — class-shape filenames + class-shape prompt bodies are
# designed exactly to express ONE shape of job the bundle exists to
# answer well.
#
# The output is a stable Markdown table consumed by check-jtbd-coverage.sh.
# Re-run any time the prompt set changes; commit the regenerated file.
#
# Usage:
#   bash devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
candidate="$SCRIPT_DIR"
while [ "$candidate" != "/" ]; do
  if [ -d "$candidate/doca-skills" ]; then
    REPO_ROOT="$candidate"; break
  fi
  candidate="$(dirname "$candidate")"
done
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

PROMPTS_DIR="${REPO_ROOT}/devops/runner/prompts"
OUT="${SCRIPT_DIR}/bundle-jtbd-coverage.md"
TMP="$(mktemp)"

cat > "$TMP" <<'EOF'
# Bundle JTBD coverage manifest

This file enumerates the JTBDs the doca-skills bundle CLAIMS to cover,
machine-derived from each class-shape prompt's `intent:` field under
`devops/runner/prompts/`. Class-shape prompts are designed (per AUTHORING
§ 1a + § 13) to each express ONE shape of job — so the prompt's intent
is the closest authoritative answer to "what jobs is this bundle built
to answer well?".

**Regenerate**:

```
bash devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh
```

**Consumer**: [`devops/ci/check-jtbd-coverage.sh`](../check-jtbd-coverage.sh)
(SOFT WARN by default, promotable to HARD via `--strict`).

| Intent | Prompt | Audience | Baseline artifact |
| --- | --- | --- | --- |
EOF

extract_yaml_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    /^context:/ { in_ctx=1; next }
    in_ctx && /^[^ ]/ { in_ctx=0 }
    in_ctx && $0 ~ "^ +"field":" {
      sub("^ +"field": *", "")
      gsub(/^[ \t"]+|[ \t"]+$/, "")
      print
      exit
    }
  ' "$file"
}

for f in "$PROMPTS_DIR"/*.yaml; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .yaml)
  intent=$(extract_yaml_field "$f" "intent")
  audience=$(extract_yaml_field "$f" "audience")
  baseline=$(extract_yaml_field "$f" "baseline_artifact")
  [ -z "$intent" ] && intent="(no intent field)"
  [ -z "$audience" ] && audience="(unspecified)"
  [ -z "$baseline" ] && baseline="(general)"
  printf "| %s | %s | %s | %s |\n" "$intent" "$base" "$audience" "$baseline" >> "$TMP"
done

mv "$TMP" "$OUT"
count=$(grep -c '^| ' "$OUT")
echo "Wrote ${OUT} (${count} table rows including header / separator)."
