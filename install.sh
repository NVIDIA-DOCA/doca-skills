#!/usr/bin/env bash
#
# install.sh — one-line installer for the NVIDIA DOCA Skills bundle.
#
# Copies (or symlinks) the bundle's 61 AgentSkills.io-compliant skill
# folders into the local agent's skill-discovery directory so the agent
# can route to them on the next reload.
#
# Quickstart:
#
#   ./install.sh --agent cursor                     # install all 61 skills into Cursor
#   ./install.sh --agent claude-code                # install all 61 skills into Anthropic Claude Code
#   ./install.sh --agent codex                      # install all 61 skills into OpenAI Codex CLI
#   ./install.sh --agent gemini-cli                 # install all 61 skills into Google Gemini CLI
#   ./install.sh --agent kiro-cli                   # install all 61 skills into Kiro CLI
#   ./install.sh --agent custom --dest /some/path/  # install to any AgentSkills.io target
#
# Targeted install:
#
#   ./install.sh --agent cursor --skill doca-flow --yes
#   ./install.sh --agent cursor --skill doca-rdma --skill doca-flow
#
# Multi-agent fan-out:
#
#   ./install.sh --agent cursor --agent claude-code --agent codex
#
# Other flags:
#
#   --list                  Print the catalog (slot / name / one-liner) and exit.
#   --dry-run               Print what would happen without writing anything.
#   --link                  Use symlinks instead of copies (default = copy).
#   --workspace             Install into ./.<agent>/skills/ at $PWD, not $HOME.
#   --force                 Overwrite an existing skill folder at the destination.
#   --yes                   Non-interactive — skip confirmation prompts.
#   --help                  Show this help.
#
# Pipe-to-bash form:
#
#   curl -fsSL <raw-url>/install.sh | bash -s -- --agent cursor --repo <repo-url>
#
# When invoked via curl-pipe-bash, --repo <url> tells the installer where to
# clone the bundle from first (the script needs the skills/ tree on disk).
#
# This installer:
#   * Touches ONLY the agent's skill-discovery directory you select.
#   * Never modifies your AGENTS.md / system files outside that directory.
#   * Is idempotent — rerunning with the same flags is a no-op (or a refresh
#     to the latest bundle state with --force).
#   * Has zero runtime dependencies beyond bash + cp + ln + mkdir + readlink.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────
# Defaults
# ─────────────────────────────────────────────────────────────────────────
AGENTS=()
SKILLS_REQUESTED=()
DEST_OVERRIDE=""
DO_LIST=0
DO_DRY_RUN=0
USE_LINK=0
WORKSPACE_LOCAL=0
FORCE=0
ASSUME_YES=0
REPO_URL=""

usage() {
  sed -n '3,42p' "${BASH_SOURCE[0]}"
  exit 0
}

die() {
  printf 'install.sh: error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[install.sh] %s\n' "$*"
}

# ─────────────────────────────────────────────────────────────────────────
# Arg parsing
# ─────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      shift; [[ $# -gt 0 ]] || die "--agent needs a value"
      AGENTS+=("$1"); shift ;;
    --skill)
      shift; [[ $# -gt 0 ]] || die "--skill needs a value"
      SKILLS_REQUESTED+=("$1"); shift ;;
    --dest)
      shift; [[ $# -gt 0 ]] || die "--dest needs a path"
      DEST_OVERRIDE="$1"; shift ;;
    --list)         DO_LIST=1; shift ;;
    --dry-run)      DO_DRY_RUN=1; shift ;;
    --link)         USE_LINK=1; shift ;;
    --workspace)    WORKSPACE_LOCAL=1; shift ;;
    --force)        FORCE=1; shift ;;
    --yes|-y)       ASSUME_YES=1; shift ;;
    --repo)
      shift; [[ $# -gt 0 ]] || die "--repo needs a URL"
      REPO_URL="$1"; shift ;;
    --help|-h)      usage ;;
    *)              die "unknown argument: $1 (try --help)" ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────
# Resolve the bundle source tree (where SKILLS/* live)
# ─────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR"

if [[ ! -d "$BUNDLE_DIR/skills" ]]; then
  # Curl-pipe-bash invocation — clone the bundle into a scratch dir.
  if [[ -z "$REPO_URL" ]]; then
    die "skills/ not found relative to installer, and --repo was not given.
       Either run install.sh from inside a cloned doca-skills checkout,
       or pass --repo <git-url> when piping from curl."
  fi
  CLONE_DIR="$(mktemp -d -t doca-skills.XXXXXX)"
  info "cloning $REPO_URL -> $CLONE_DIR"
  if [[ "$DO_DRY_RUN" -eq 0 ]]; then
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR" >/dev/null
  fi
  BUNDLE_DIR="$CLONE_DIR"
  [[ -d "$BUNDLE_DIR/skills" ]] || die "cloned repo at $REPO_URL has no skills/ tree"
fi

SKILLS_ROOT="$BUNDLE_DIR/skills"

# ─────────────────────────────────────────────────────────────────────────
# Build the catalog (slot, name, source path, one-line summary)
# ─────────────────────────────────────────────────────────────────────────
catalog_paths() {
  # Cross-cutting (top-level under skills/, excluding libs/services/tools/)
  find "$SKILLS_ROOT" -mindepth 1 -maxdepth 1 -type d \
    ! -name libs ! -name services ! -name tools | sort
  # Per-slot
  for slot in libs services tools; do
    if [[ -d "$SKILLS_ROOT/$slot" ]]; then
      find "$SKILLS_ROOT/$slot" -mindepth 1 -maxdepth 1 -type d | sort
    fi
  done
}

skill_slot() {
  local path="$1"
  case "$path" in
    */skills/libs/*)      printf 'lib' ;;
    */skills/services/*)  printf 'service' ;;
    */skills/tools/*)     printf 'tool' ;;
    *)                    printf 'cross-cutting' ;;
  esac
}

skill_name() {
  basename "$1"
}

# ─────────────────────────────────────────────────────────────────────────
# --list: print the catalog and exit
# ─────────────────────────────────────────────────────────────────────────
if [[ "$DO_LIST" -eq 1 ]]; then
  printf '\nNVIDIA DOCA Skills — catalog (%s skills)\n' "$(catalog_paths | wc -l | tr -d ' ')"
  printf '%s\n' "-----------------------------------------"
  printf '%-14s  %-40s  %s\n' SLOT NAME SOURCE
  while IFS= read -r p; do
    printf '%-14s  %-40s  %s\n' "$(skill_slot "$p")" "$(skill_name "$p")" "${p#"$BUNDLE_DIR/"}"
  done < <(catalog_paths)
  echo
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────
# Default agent selection if none given (interactive prompt, unless --yes)
# ─────────────────────────────────────────────────────────────────────────
if [[ ${#AGENTS[@]} -eq 0 ]]; then
  if [[ "$ASSUME_YES" -eq 1 || -n "$DEST_OVERRIDE" ]]; then
    if [[ -n "$DEST_OVERRIDE" ]]; then
      AGENTS=(custom)
    else
      die "no --agent given and --yes was passed; pick one of: cursor | claude-code | codex | gemini-cli | kiro-cli | custom"
    fi
  else
    printf 'Which agent do you want to install into? (cursor / claude-code / codex / gemini-cli / kiro-cli / custom): '
    read -r choice
    [[ -n "$choice" ]] || die "no agent picked, aborting"
    AGENTS=("$choice")
  fi
fi

# ─────────────────────────────────────────────────────────────────────────
# Map agent → destination skill directory
# ─────────────────────────────────────────────────────────────────────────
dest_for_agent() {
  local agent="$1"
  local base
  if [[ "$WORKSPACE_LOCAL" -eq 1 ]]; then
    base="$(pwd)"
  else
    base="$HOME"
  fi
  case "$agent" in
    cursor)         printf '%s/.cursor/skills' "$base" ;;
    claude-code)    printf '%s/.claude/skills' "$base" ;;
    codex)          printf '%s/.codex/skills' "$base" ;;
    gemini-cli)     printf '%s/.gemini/skills' "$base" ;;
    kiro-cli)       printf '%s/.kiro/skills' "$base" ;;
    custom)
      [[ -n "$DEST_OVERRIDE" ]] || die "--agent custom requires --dest <path>"
      printf '%s' "$DEST_OVERRIDE" ;;
    *)              die "unsupported --agent '$agent' (supported: cursor | claude-code | codex | gemini-cli | kiro-cli | custom)" ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────
# Resolve which skills to install
# ─────────────────────────────────────────────────────────────────────────
SELECTED_PATHS=()
if [[ ${#SKILLS_REQUESTED[@]} -eq 0 ]]; then
  while IFS= read -r p; do SELECTED_PATHS+=("$p"); done < <(catalog_paths)
else
  for want in "${SKILLS_REQUESTED[@]}"; do
    found=""
    while IFS= read -r p; do
      if [[ "$(skill_name "$p")" == "$want" ]]; then
        found="$p"; break
      fi
    done < <(catalog_paths)
    [[ -n "$found" ]] || die "no skill named '$want' in this bundle (try --list)"
    SELECTED_PATHS+=("$found")
  done
fi

if [[ ${#SELECTED_PATHS[@]} -eq 0 ]]; then
  die "no skills resolved — nothing to install"
fi

# ─────────────────────────────────────────────────────────────────────────
# Confirm with the user (unless --yes)
# ─────────────────────────────────────────────────────────────────────────
if [[ "$ASSUME_YES" -eq 0 ]]; then
  echo
  info "About to install ${#SELECTED_PATHS[@]} skill(s) into ${#AGENTS[@]} agent target(s):"
  for a in "${AGENTS[@]}"; do
    printf '  - %s -> %s\n' "$a" "$(dest_for_agent "$a")"
  done
  printf '  mode: %s\n' "$([[ "$USE_LINK" -eq 1 ]] && echo symlink || echo copy)"
  printf '  dry-run: %s\n' "$([[ "$DO_DRY_RUN" -eq 1 ]] && echo YES || echo no)"
  printf 'Proceed? [y/N]: '
  read -r ok
  case "$ok" in
    y|Y|yes|YES) : ;;
    *) info "aborted by user"; exit 0 ;;
  esac
fi

# ─────────────────────────────────────────────────────────────────────────
# Install
# ─────────────────────────────────────────────────────────────────────────
install_one() {
  local src="$1" dest_dir="$2"
  local name; name="$(skill_name "$src")"
  local dest="$dest_dir/$name"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      info "skip (already present, use --force to overwrite): $dest"
      return 0
    fi
    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
      info "[dry-run] would rm -rf $dest"
    else
      rm -rf -- "$dest"
    fi
  fi

  if [[ "$USE_LINK" -eq 1 ]]; then
    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
      info "[dry-run] would ln -s $src $dest"
    else
      ln -s "$src" "$dest"
    fi
  else
    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
      info "[dry-run] would cp -R $src $dest"
    else
      cp -R "$src" "$dest"
    fi
  fi
}

INSTALL_COUNT=0
for agent in "${AGENTS[@]}"; do
  dest_dir="$(dest_for_agent "$agent")"
  if [[ "$DO_DRY_RUN" -eq 1 ]]; then
    info "[dry-run] would mkdir -p $dest_dir"
  else
    mkdir -p "$dest_dir"
  fi
  info "installing into $agent ($dest_dir)"
  for src in "${SELECTED_PATHS[@]}"; do
    install_one "$src" "$dest_dir"
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
  done
done

echo
info "Done. Installed/refreshed $INSTALL_COUNT skill placement(s)."
info "Reload your agent (or just ask it a DOCA question) and the bundle will activate."
