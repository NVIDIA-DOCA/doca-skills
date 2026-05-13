#!/usr/bin/env bash
# ci/check-skill.sh - conformance gate for .claude/skills/<skill>/
# See AGENTS.md and SKILLS.md for the contract this script enforces.
#
# Usage:
#   ci/check-skill.sh <skill-dir>                # lint one skill (structure + non-public)
#   ci/check-skill.sh <skill-dir> --check-urls   # also HEAD every URL, fail on non-2xx/3xx
#   ci/check-skill.sh --all                      # lint every skill under .claude/skills/
#   ci/check-skill.sh --all --check-urls         # add URL HEAD check
#   ci/check-skill.sh --self-test                # run failure-mode self-tests
#
# What gets enforced:
#   1. Structural contract: SKILL.md frontmatter; required H2 anchors in
#      SKILL.md / CAPABILITIES.md / TASKS.md (kind=library); no symlinks;
#      cross-anchor labels in TASKS.md resolve.
#   2. No non-public references: any URL whose hostname is *.nvidia.com
#      must be on a small public allowlist (docs.nvidia.com,
#      developer.nvidia.com, catalog.ngc.nvidia.com, ngc.nvidia.com,
#      forums.developer.nvidia.com, …); any URL or path containing
#      internal-tooling vocabulary (gerrit, nvbugs, *.internal.*,
#      gitlab-master, labhome, etc.) fails.
#   3. (--check-urls only) every http(s) URL responds 2xx/3xx to a HEAD
#      (or GET fallback for hosts that 405 HEAD).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${REPO_ROOT}/.claude/skills"

# --- non-public references ---------------------------------------------------
# Public NVIDIA hostnames the skills may reference. Any other *.nvidia.com /
# *.ngc.nvidia.com host fails check_non_public.
ALLOWED_NVIDIA_HOSTS_RE='^(nvidia\.com|www\.nvidia\.com|docs\.nvidia\.com|developer\.nvidia\.com|developer\.download\.nvidia\.com|catalog\.ngc\.nvidia\.com|ngc\.nvidia\.com|forums\.developer\.nvidia\.com|nvidianews\.nvidia\.com|nvcr\.io)$'

# URL- / path-shaped patterns that ALWAYS fail. Patterns are URL-shaped on
# purpose so prose mentions of "Gerrit"/"NVBugs" in AGENTS.md ground rules
# (e.g. "do not link to internal NVIDIA tools like Gerrit, NVBugs, ...") do
# not false-positive. Each regex below requires either a URL scheme prefix
# (`://`) or a hostname-shaped suffix (`.nvidia`, `.com`, `.io`, ...) so it
# matches references, not warnings against references.
NONPUBLIC_PATTERNS=(
  '://[A-Za-z0-9.-]*gerrit'                    # gerrit hostnames in URLs
  '[A-Za-z0-9.-]*gerrit\.(nvidia|com|net|io)'  # gerrit.<tld> as a hostname
  '://[A-Za-z0-9.-]*nvbugs'                    # nvbugs hostnames in URLs
  'nvbugs\.[A-Za-z0-9.-]+'                     # nvbugs.<tld> as a hostname
  '://[A-Za-z0-9.-]*nvbz'
  '://[A-Za-z0-9.-]*nvconfluence'
  '://[A-Za-z0-9.-]*confluence\.nvidia'
  '://[A-Za-z0-9.-]*nvjenkins'
  '://[A-Za-z0-9.-]*jenkins\.nvidia'
  '://[A-Za-z0-9.-]*labhome'
  '://[A-Za-z0-9.-]*gitlab-master'
  '://[A-Za-z0-9.-]*scm-internal'
  '://internal-mirror'
  '[A-Za-z0-9.-]+\.internal\.[A-Za-z0-9.-]+'   # any *.internal.<something>
  '/labhome/'                                  # internal lab path in non-URL context
  '/opt/internal/'
)

# --- URL extraction ----------------------------------------------------------
extract_urls() {
  # Args: file paths. Output: URLs (one per line, deduped, trailing markdown
  # punctuation stripped). Emits nothing if no input files exist.
  grep -hEo 'https?://[A-Za-z0-9._/?&=%#:+~,!@-]+' "$@" 2>/dev/null \
    | sed -e 's/[).,;:!?]*$//' -e 's/\*\*$//' -e "s/'\$//" -e 's/"$//' \
    | sort -u
}

extract_host() {
  printf '%s' "$1" | sed -E 's|^https?://([^/]+).*|\1|'
}

# --- non-public check (gating, always on) ------------------------------------
check_non_public() {
  local SKILL_DIR="$1"
  local rc=0
  local pat hits
  for pat in "${NONPUBLIC_PATTERNS[@]}"; do
    hits="$(grep -rEni -- "$pat" "$SKILL_DIR" 2>/dev/null || true)"
    if [ -n "$hits" ]; then
      echo "FAIL[$SKILL_DIR]: non-public reference pattern '$pat' matched:"
      printf '%s\n' "$hits" | sed 's/^/  /'
      rc=1
    fi
  done

  # Allowlist check for *.nvidia.com / nvcr.io URLs in skill files. Any
  # other NVIDIA host is treated as a non-public reference.
  local urls u host
  urls="$(extract_urls "$SKILL_DIR"/*.md 2>/dev/null || true)"
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    host="$(extract_host "$u")"
    case "$host" in
      *.nvidia.com|nvidia.com|nvcr.io)
        if ! printf '%s' "$host" | grep -Eq "$ALLOWED_NVIDIA_HOSTS_RE"; then
          echo "FAIL[$SKILL_DIR]: non-allowlisted NVIDIA host: $host (URL: $u)"
          rc=1
        fi
        ;;
    esac
  done <<< "$urls"

  return $rc
}

# --- URL HEAD check (opt-in via --check-urls) --------------------------------
check_urls() {
  local SKILL_DIR="$1"
  local rc=0 urls u code
  urls="$(extract_urls "$SKILL_DIR"/*.md 2>/dev/null || true)"
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    code="$(curl -sLI -o /dev/null -w '%{http_code}' --max-time 10 --retry 1 "$u" 2>/dev/null || echo "000")"
    case "$code" in
      2*|3*) ;;
      405|501|400|403)
        # Server doesn't like HEAD; some sites also 403 HEAD requests
        # while serving GET. Fall back to a tiny GET to confirm.
        code="$(curl -sL -o /dev/null -w '%{http_code}' --max-time 15 --retry 1 -r 0-0 "$u" 2>/dev/null || echo "000")"
        case "$code" in
          2*|3*) ;;
          *) echo "FAIL[$SKILL_DIR]: URL returned $code (HEAD->GET): $u"; rc=1 ;;
        esac
        ;;
      000)
        echo "FAIL[$SKILL_DIR]: URL unreachable (timeout / DNS / network): $u"; rc=1
        ;;
      *)
        echo "FAIL[$SKILL_DIR]: URL returned $code: $u"; rc=1
        ;;
    esac
  done <<< "$urls"
  return $rc
}

# --- structural lint (one skill) ---------------------------------------------
lint_one() {
  local SKILL_DIR="$1"
  local CHECK_URLS="${2:-0}"
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

  # 7. Non-public references (gating, always on).
  check_non_public "$SKILL_DIR" || return 1

  # 8. URL HEAD check (gating when --check-urls is passed).
  if [ "$CHECK_URLS" = "1" ]; then
    check_urls "$SKILL_DIR" || return 1
  fi

  echo "OK[$SKILL_DIR] kind=$KIND name=$NAME"
  return 0
}

# --- self-test ---------------------------------------------------------------
self_test() {
  local TMP rc src
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
  sed -i.bak 's/doca-public-knowledge-map ## Layout of an installed DOCA package/doca-public-knowledge-map ## Nonexistent anchor xyz/' "$src" && rm -f "$src.bak"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: broken cross-anchor was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  echo "== self-test 4: internal NVIDIA URL should fail (gerrit hostname) =="
  src="$SKILLS_ROOT/doca-flow/SKILL.md"
  printf '\n<!-- self-test: this should trip non-public lint -->\nSee https://gerrit-master.nvidia.com/doca/sample\n' >> "$src"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: internal gerrit URL was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  echo "== self-test 5: non-allowlisted *.nvidia.com host should fail =="
  src="$SKILLS_ROOT/doca-flow/CAPABILITIES.md"
  printf '\n<!-- self-test -->\nSee https://internal-wiki.nvidia.com/doca/page for details.\n' >> "$src"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: non-allowlisted nvidia host was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  echo "== self-test 6: lab path /labhome/ should fail =="
  src="$SKILLS_ROOT/doca-flow/TASKS.md"
  printf '\n<!-- self-test -->\nMount the share from /labhome/svc-doca/build/ before retrying.\n' >> "$src"
  rc=0; lint_one "$SKILLS_ROOT/doca-flow" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: /labhome/ path was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$OLD_ROOT/doca-flow/." "$SKILLS_ROOT/doca-flow/"

  SKILLS_ROOT="$OLD_ROOT"
  rm -rf "$TMP"
  echo "self-test PASS (all six failure modes detected)"
  return 0
}

# --- argument parsing --------------------------------------------------------
CHECK_URLS=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --check-urls) CHECK_URLS=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]:-}"

case "${1:-}" in
  --all)
    rc=0
    for d in "$SKILLS_ROOT"/*/; do
      lint_one "${d%/}" "$CHECK_URLS" || rc=1
    done
    exit "$rc"
    ;;
  --self-test)
    self_test
    ;;
  "" | -h | --help)
    cat <<'EOF'
usage:
  ci/check-skill.sh <skill-dir> [--check-urls]
  ci/check-skill.sh --all       [--check-urls]
  ci/check-skill.sh --self-test

Without --check-urls, the lint runs structural + non-public-references
checks only (no network required). With --check-urls, it additionally
HEADs every URL in the skill files and fails on any non-2xx/3xx
response (CI must have outbound network for that mode).
EOF
    exit 2
    ;;
  *)
    lint_one "$1" "$CHECK_URLS"
    ;;
esac
