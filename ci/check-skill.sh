#!/usr/bin/env bash
# ci/check-skill.sh - conformance gate for .claude/skills/<skill>/
# See AGENTS.md and SKILLS.md for the contract this script enforces.
#
# Usage:
#   ci/check-skill.sh <skill-dir>          # lint one skill
#   ci/check-skill.sh --all                # lint every skill under .claude/skills/
#   ci/check-skill.sh --self-test          # run failure-mode self-tests
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${REPO_ROOT}/.claude/skills"

lint_one() {
  local SKILL_DIR="$1"
  [ -d "$SKILL_DIR" ] || { echo "FAIL: not a directory: $SKILL_DIR"; return 1; }

  # 1. Symlink rejection (portable - no GNU -quit).
  local sym
  sym="$(find "$SKILL_DIR" -type l 2>/dev/null | head -n 1 || true)"
  if [ -n "$sym" ]; then
    echo "FAIL[$SKILL_DIR]: symlink found: $sym"
    return 1
  fi

  local SKILL_FILE="$SKILL_DIR/SKILL.md"
  [ -f "$SKILL_FILE" ] || { echo "FAIL[$SKILL_DIR]: no SKILL.md"; return 1; }

  # 2. Frontmatter parse (pure awk, no PyYAML).
  local FM NAME DESC KIND
  FM="$(awk 'BEGIN{c=0} /^---[[:space:]]*$/ {c++; next} c==1 {print} c==2 {exit}' "$SKILL_FILE")"
  NAME="$(printf '%s\n' "$FM" | awk -F': *' '$1=="name"{ $1=""; sub(/^ /,""); print; exit }')"
  DESC="$(printf '%s\n' "$FM" | awk -F': *' '$1=="description"{ $1=""; sub(/^ /,""); print; exit }')"
  KIND="$(printf '%s\n' "$FM" | awk -F': *' '$1=="kind"{ $1=""; sub(/^ /,""); print; exit }')"

  printf '%s' "$NAME" | grep -Eq '^[a-z0-9-]{1,64}$' \
    || { echo "FAIL[$SKILL_DIR]: invalid name '$NAME' (need ^[a-z0-9-]{1,64}\$)"; return 1; }
  [ -n "$DESC" ] || { echo "FAIL[$SKILL_DIR]: empty description"; return 1; }
  [ "${#DESC}" -le 1024 ] || { echo "FAIL[$SKILL_DIR]: description >1024 chars (${#DESC})"; return 1; }
  case "$KIND" in
    knowledge|library) ;;
    *) echo "FAIL[$SKILL_DIR]: kind must be knowledge|library, got '$KIND'"; return 1 ;;
  esac

  # 3. Universal anchor.
  grep -Eq '^## When to load this skill[[:space:]]*$' "$SKILL_FILE" \
    || { echo "FAIL[$SKILL_DIR]: missing H2 '## When to load this skill' in SKILL.md"; return 1; }

  # 4. kind=library: companion files and required anchors.
  if [ "$KIND" = "library" ]; then
    local f a
    for f in CAPABILITIES.md TASKS.md; do
      [ -f "$SKILL_DIR/$f" ] || { echo "FAIL[$SKILL_DIR]: missing companion $f"; return 1; }
    done
    for a in "## Capabilities and modes" "## Version compatibility" "## Error taxonomy" "## Observability" "## Safety policy"; do
      grep -Eq "^${a}[[:space:]]*$" "$SKILL_DIR/CAPABILITIES.md" \
        || { echo "FAIL[$SKILL_DIR]: missing H2 '$a' in CAPABILITIES.md"; return 1; }
    done
    for a in "## configure" "## build" "## modify" "## run" "## test" "## debug" "## Deferred task verbs"; do
      grep -Eq "^${a}[[:space:]]*$" "$SKILL_DIR/TASKS.md" \
        || { echo "FAIL[$SKILL_DIR]: missing H2 '$a' in TASKS.md"; return 1; }
    done

    # 5. Cross-anchor resolution.
    # Look only at markdown link labels of the form "[<skill-name> ## <anchor>](...)" inside TASKS.md.
    # Skill-name must be a real sibling directory under SKILLS_ROOT (avoids matching e.g. "CAPABILITIES.md ##").
    local label target_skill anchor target_dir found g
    while IFS= read -r label; do
      target_skill="${label%% ## *}"
      anchor="## ${label#* ## }"
      target_dir="${SKILLS_ROOT}/${target_skill}"
      if [ ! -d "$target_dir" ]; then
        echo "FAIL[$SKILL_DIR]: cross-anchor refers to unknown skill: '$target_skill' (label='$label')"
        return 1
      fi
      found=0
      for g in "$target_dir/SKILL.md" "$target_dir/CAPABILITIES.md" "$target_dir/TASKS.md"; do
        [ -f "$g" ] || continue
        if grep -Eq "^${anchor}[[:space:]]*$" "$g"; then
          found=1
          break
        fi
      done
      if [ "$found" -eq 0 ]; then
        echo "FAIL[$SKILL_DIR]: broken cross-anchor: '$label' -> not found in $target_skill"
        return 1
      fi
    done < <(grep -oE '\[[a-z0-9][a-z0-9-]* ## [^]]+\]\(' "$SKILL_DIR/TASKS.md" 2>/dev/null \
              | sed -e 's/^\[//' -e 's/\](\$//' -e 's/\](//')

    # 6. URL-count soft warning (not gating).
    local pat n
    for pat in 'docs.nvidia.com' '/opt/mellanox/doca'; do
      n="$(grep -Fc -- "$pat" "$SKILL_DIR/CAPABILITIES.md" 2>/dev/null | head -n 1)"
      [ -n "$n" ] || n=0
      if [ "$n" -gt 0 ] 2>/dev/null; then
        echo "WARN[$SKILL_DIR]: $n occurrence(s) of '$pat' in CAPABILITIES.md - consider cross-link to doca-public-knowledge-map"
      fi
    done
  fi

  echo "OK[$SKILL_DIR] kind=$KIND name=$NAME"
  return 0
}

self_test() {
  local TMP rc src skill_name
  TMP="$(mktemp -d)"
  cp -R "$SKILLS_ROOT" "$TMP/skills"
  # Re-point SKILLS_ROOT for this run so cross-anchor checks resolve inside the temp tree.
  local OLD_ROOT="$SKILLS_ROOT"
  SKILLS_ROOT="$TMP/skills"

  echo "== self-test 1: anchor rename should fail =="
  src="$SKILLS_ROOT/doca-flow/CAPABILITIES.md"
  sed -i.bak 's/^## Safety policy[[:space:]]*$/## Safety policies/' "$src" && rm -f "$src.bak"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: anchor rename was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  echo "== self-test 2: symlink should fail =="
  ln -s SKILL.md "$SKILLS_ROOT/doca-flow/LINK.md"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: symlink was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  rm -f "$SKILLS_ROOT/doca-flow/LINK.md"

  echo "== self-test 3: broken cross-anchor should fail =="
  src="$SKILLS_ROOT/doca-flow/TASKS.md"
  # Replace the legitimate cross-anchor anchor name with a non-existent one
  sed -i.bak 's/doca-public-knowledge-map ## Layout of an installed DOCA package/doca-public-knowledge-map ## Nonexistent anchor xyz/' "$src" && rm -f "$src.bak"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: broken cross-anchor was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  SKILLS_ROOT="$OLD_ROOT"
  rm -rf "$TMP"
  echo "self-test PASS (all three failure modes detected)"
  return 0
}

case "${1:-}" in
  --all)
    rc=0
    for d in "$SKILLS_ROOT"/*/; do
      lint_one "${d%/}" || rc=1
    done
    exit "$rc"
    ;;
  --self-test)
    self_test
    ;;
  "" | -h | --help)
    echo "usage: $0 <skill-dir> | --all | --self-test"
    exit 2
    ;;
  *)
    lint_one "$1"
    ;;
esac
