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
SKILLS_ROOT="${SKILLS_ROOT:-${REPO_ROOT}/skills}"

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

# --- class-shape filename rejection (AUTHORING § 1a, load-bearing) -----------
# Reject filenames that name a SPECIFIC DOCA use case ("load balancer",
# "firewall", "NAT", ...) rather than a class of problems. Per AUTHORING.md
# § 1a, every artifact in this bundle must teach a CLASS; specific instances
# appear only as worked examples INSIDE class-shaped artifacts.
#
# A filename like libs/doca-flow/references/flow-load-balancer.md trips this
# gate by construction: it commits the bundle to maintain N use-case docs
# instead of one taxonomy + examples. The fix is to fold the worked example
# into a class-shaped doc (e.g. references/pattern-library.md with a
# "load balancer" section).
#
# Each pattern matches the *suffix* of the stem of an .md or .yaml file
# (case-insensitive). Pre-stem text is intentionally unconstrained so
# `flow-load-balancer.md`, `nat-l4.md`, etc., all trip; `pattern-library.md`
# does not.
INSTANCE_SHAPE_PATTERNS=(
  '(^|[-_])load[-_]?balancer$'
  '(^|[-_])firewall$'
  '(^|[-_])nat$'
  '(^|[-_])l3[-_]?router$'
  '(^|[-_])hairpin$'
  '(^|[-_])sampling$'
  '(^|[-_])mirroring$'
  '(^|[-_])switch[-_]?representor$'
  '(^|[-_])tunnel[-_]?encap$'
  '(^|[-_])tunnel[-_]?decap$'
  '(^|[-_])vxlan$'
  '(^|[-_])gre$'
  '(^|[-_])gtpu$'
  '(^|[-_])mpls$'
)

check_class_shape_filename() {
  # Args: one path. Echo + return 1 if the file's stem matches an instance
  # pattern. Caller decides what to do with the failure (lint_one returns
  # 1; --check-class-shape aggregates).
  local path="$1"
  local stem
  stem="$(basename "$path")"
  stem="${stem%.*}"
  # Lowercase for case-insensitive match (portable: tr is in POSIX).
  stem="$(printf '%s' "$stem" | tr '[:upper:]' '[:lower:]')"
  local pat
  for pat in "${INSTANCE_SHAPE_PATTERNS[@]}"; do
    if printf '%s' "$stem" | grep -Eq -- "$pat"; then
      echo "FAIL[class-shape]: instance-shaped filename '$path' matches /$pat/"
      echo "FAIL[class-shape]:   per AUTHORING.md § 1a, fold this use case as a worked example"
      echo "FAIL[class-shape]:   inside a class-shaped artifact (e.g. references/pattern-library.md)."
      return 1
    fi
  done
  return 0
}

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
    knowledge|library|service|tool) ;;
    *) echo "FAIL[$SKILL_DIR]: kind must be knowledge|library|service|tool, got '$KIND'"; return 1 ;;
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
    # Skill-name must be a real skill directory found anywhere under SKILLS_ROOT
    # (recursive lookup so libs/<lib>, services/<svc>, tools/<tool> all resolve).
    local label target_skill anchor target_dir found g
    while IFS= read -r label; do
      target_skill="${label%% ## *}"
      anchor="## ${label#* ## }"
      # Locate the skill directory by name, recursively. Excludes hidden / .git
      # directories. First match wins (skill names are expected to be unique).
      target_dir="$(find "$SKILLS_ROOT" -type d -name "$target_skill" 2>/dev/null | head -n 1)"
      if [ -z "$target_dir" ] || [ ! -d "$target_dir" ]; then
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

  # 8. Class-shape filename rejection (AUTHORING § 1a, always on). Walks
  # every *.md under the skill dir; any instance-shaped filename fails.
  local md
  while IFS= read -r md; do
    [ -n "$md" ] || continue
    check_class_shape_filename "$md" || return 1
  done < <(find "$SKILL_DIR" -type f -name '*.md' 2>/dev/null)

  # 9. URL HEAD check (gating when --check-urls is passed).
  if [ "$CHECK_URLS" = "1" ]; then
    check_urls "$SKILL_DIR" || return 1
  fi

  echo "OK[$SKILL_DIR] kind=$KIND name=$NAME"
  return 0
}

# --- self-test ---------------------------------------------------------------
self_test() {
  local TMP rc src FX_REL FX FX_OLD
  TMP="$(mktemp -d)"
  cp -R "$SKILLS_ROOT" "$TMP/skills"
  # Re-point SKILLS_ROOT for this run so cross-anchor checks resolve inside the temp tree.
  local OLD_ROOT="$SKILLS_ROOT"
  SKILLS_ROOT="$TMP/skills"

  # Locate the doca-flow fixture by name so this self-test is structure-independent
  # (works whether doca-flow lives at the top level or under libs/).
  FX="$(find "$SKILLS_ROOT" -type d -name doca-flow | head -n 1)"
  if [ -z "$FX" ] || [ ! -d "$FX" ]; then
    echo "self-test FAIL: doca-flow fixture not found under $SKILLS_ROOT"
    SKILLS_ROOT="$OLD_ROOT"; return 1
  fi
  FX_REL="${FX#"$SKILLS_ROOT"/}"
  FX_OLD="$OLD_ROOT/$FX_REL"

  echo "== self-test 1: anchor rename should fail =="
  src="$FX/CAPABILITIES.md"
  sed -i.bak 's/^## Safety policy[[:space:]]*$/## Safety policies/' "$src" && rm -f "$src.bak"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: anchor rename was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$FX_OLD/." "$FX/"

  echo "== self-test 2: symlink should fail =="
  ln -s SKILL.md "$FX/LINK.md"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: symlink was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  rm -f "$FX/LINK.md"

  echo "== self-test 3: broken cross-anchor should fail =="
  src="$FX/TASKS.md"
  sed -i.bak 's/doca-public-knowledge-map ## Layout of an installed DOCA package/doca-public-knowledge-map ## Nonexistent anchor xyz/' "$src" && rm -f "$src.bak"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: broken cross-anchor was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$FX_OLD/." "$FX/"

  echo "== self-test 4: internal NVIDIA URL should fail (gerrit hostname) =="
  src="$FX/SKILL.md"
  printf '\n<!-- self-test: this should trip non-public lint -->\nSee https://gerrit-master.nvidia.com/doca/sample\n' >> "$src"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: internal gerrit URL was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$FX_OLD/." "$FX/"

  echo "== self-test 5: non-allowlisted *.nvidia.com host should fail =="
  src="$FX/CAPABILITIES.md"
  printf '\n<!-- self-test -->\nSee https://internal-wiki.nvidia.com/doca/page for details.\n' >> "$src"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: non-allowlisted nvidia host was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$FX_OLD/." "$FX/"

  echo "== self-test 6: lab path /labhome/ should fail =="
  src="$FX/TASKS.md"
  printf '\n<!-- self-test -->\nMount the share from /labhome/svc-doca/build/ before retrying.\n' >> "$src"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: /labhome/ path was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  cp -R "$FX_OLD/." "$FX/"

  echo "== self-test 7: instance-shaped filename should fail (AUTHORING § 1a) =="
  # The class-shape gate must reject 'flow-load-balancer.md' (and friends),
  # regardless of where it sits in the skill tree.
  mkdir -p "$FX/references"
  printf '# Load balancer reference\n' > "$FX/references/flow-load-balancer.md"
  rc=0; lint_one "$FX" || rc=$?
  [ "$rc" -ne 0 ] || { echo "self-test FAIL: instance-shaped filename was not detected"; SKILLS_ROOT="$OLD_ROOT"; return 1; }
  rm -rf "$FX/references"

  SKILLS_ROOT="$OLD_ROOT"
  rm -rf "$TMP"
  echo "self-test PASS (all seven failure modes detected)"
  return 0
}

# --- standalone class-shape check on an arbitrary dir ------------------------
# Used to lint runner/prompts/ (and future templates/, scripts/, ...)
# without requiring a SKILL.md present. Walks the dir for *.md and *.yaml
# files and runs the class-shape filename gate.
check_class_shape_dir() {
  local dir="$1"
  [ -d "$dir" ] || { echo "FAIL: not a directory: $dir"; return 1; }
  local rc=0 f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    check_class_shape_filename "$f" || rc=1
  done < <(find "$dir" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null)
  if [ "$rc" -eq 0 ]; then
    echo "OK[class-shape]: $dir (no instance-shaped filenames found)"
  fi
  return $rc
}

# --- argument parsing --------------------------------------------------------
CHECK_URLS=0
CLASS_SHAPE_DIR=""
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check-urls)
      CHECK_URLS=1
      shift
      ;;
    --check-class-shape)
      CLASS_SHAPE_DIR="${2:-}"
      [ -n "$CLASS_SHAPE_DIR" ] || { echo "FAIL: --check-class-shape requires <dir>"; exit 2; }
      shift 2
      ;;
    --check-class-shape=*)
      CLASS_SHAPE_DIR="${1#--check-class-shape=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done
set -- "${ARGS[@]:-}"

# Standalone class-shape check on an arbitrary dir runs and exits first,
# independent of any SKILL.md being present.
if [ -n "$CLASS_SHAPE_DIR" ]; then
  check_class_shape_dir "$CLASS_SHAPE_DIR"
  exit $?
fi

case "${1:-}" in
  --all)
    rc=0
    # Walk every directory containing a SKILL.md, regardless of depth.
    # This lets the tree carry layered subdirs (libs/, services/, tools/)
    # without forcing a flat layout.
    while IFS= read -r d; do
      lint_one "$d" "$CHECK_URLS" || rc=1
    done < <(find "$SKILLS_ROOT" -type f -name SKILL.md \
              -exec dirname {} \; | sort -u)
    exit "$rc"
    ;;
  --self-test)
    self_test
    ;;
  "" | -h | --help)
    cat <<'EOF'
usage:
  ci/check-skill.sh <skill-dir>              [--check-urls]
  ci/check-skill.sh --all                    [--check-urls]
  ci/check-skill.sh --check-class-shape <dir>
  ci/check-skill.sh --self-test

Without --check-urls, the lint runs structural + non-public-references
checks + class-shape filename rejection (AUTHORING § 1a) only (no network
required). With --check-urls, it additionally HEADs every URL in the
skill files and fails on any non-2xx/3xx response (CI must have outbound
network for that mode).

--check-class-shape <dir> runs ONLY the AUTHORING § 1a filename gate over
.md/.yaml/.yml files in <dir>. Use this to lint runner/prompts/
(and future templates/, scripts/) without requiring a SKILL.md.
EOF
    exit 2
    ;;
  *)
    lint_one "$1" "$CHECK_URLS"
    ;;
esac
