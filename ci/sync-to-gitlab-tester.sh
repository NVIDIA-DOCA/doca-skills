#!/usr/bin/env bash
# sync-to-gitlab-tester.sh — strip internal files and push the public
# bundle into the GitLab tester repo at doca-devops/doca-skills.
#
# This is the *tester*-facing distribution of the doca-skills bundle:
# the tester clones the GitLab repo, runs ./install.sh --agent <theirs>,
# and gets exactly the public surface — no ci/, no runner/, no
# fixtures/, no internal authoring docs. Identical strip set as
# ci/make-public-bundle.sh (this script wraps it).
#
# Usage:
#
#   ci/sync-to-gitlab-tester.sh                          # sync from HEAD, no push
#   ci/sync-to-gitlab-tester.sh --rev HEAD               # same
#   ci/sync-to-gitlab-tester.sh --rev origin/ai-mvp-with-files
#   ci/sync-to-gitlab-tester.sh --rev HEAD --push        # sync + git push
#   ci/sync-to-gitlab-tester.sh --rev HEAD --push \
#       --message "doca-skills: sync from <sha> for external tester review"
#
# Environment overrides:
#
#   GITLAB_REPO=/abs/path     Override the target repo path
#                             (default: ../gitlab-test-proj/doca-skills,
#                              i.e. the workspace sibling to doca-skills/).
#
# Defensive defaults:
#   * Never force-pushes; commits on top of whatever GITLAB_REPO's HEAD is.
#   * Refuses to run if GITLAB_REPO/.git is missing or has a non-GitLab
#     'origin' (so we don't accidentally push the stripped bundle into
#     the wrong remote).
#   * Refuses to run if SKILLS_REPO is dirty unless --allow-dirty.
#   * --dry-run prints what would happen without writing.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────
# Arg parsing
# ─────────────────────────────────────────────────────────────────────────
REV="HEAD"
DO_PUSH=0
DO_DRY_RUN=0
ALLOW_DIRTY=0
COMMIT_MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rev)            shift; REV="$1"; shift ;;
    --push)           DO_PUSH=1; shift ;;
    --dry-run)        DO_DRY_RUN=1; shift ;;
    --allow-dirty)    ALLOW_DIRTY=1; shift ;;
    --message|-m)     shift; COMMIT_MSG="$1"; shift ;;
    --help|-h)
      sed -n '1,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)
      echo "sync-to-gitlab-tester.sh: error: unknown arg: $1" >&2
      exit 2 ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────────
# Self-locate source repo + resolve target repo
# ─────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$SKILLS_REPO/.." && pwd)"
GITLAB_REPO="${GITLAB_REPO:-$WORKSPACE_ROOT/gitlab-test-proj/doca-skills}"

[[ -d "$SKILLS_REPO/.git" ]] || {
  echo "FATAL: $SKILLS_REPO is not a git checkout" >&2; exit 3
}
[[ -d "$GITLAB_REPO/.git" ]] || {
  echo "FATAL: target $GITLAB_REPO is not a git checkout" >&2
  echo "       create it with: git clone <gitlab-url> $GITLAB_REPO" >&2
  exit 3
}

# Sanity-check the target remote (must look like gitlab-master, not github).
GITLAB_ORIGIN="$(git -C "$GITLAB_REPO" remote get-url origin 2>/dev/null || true)"
if [[ -z "$GITLAB_ORIGIN" ]]; then
  echo "FATAL: $GITLAB_REPO has no 'origin' remote" >&2; exit 3
fi
if [[ "$GITLAB_ORIGIN" != *gitlab* ]]; then
  echo "FATAL: $GITLAB_REPO origin does not look like a GitLab remote:" >&2
  echo "       $GITLAB_ORIGIN" >&2
  echo "       refusing to publish the stripped bundle there." >&2
  exit 3
fi

# Source repo cleanliness check (so the strip is reproducible).
if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  if [[ -n "$(git -C "$SKILLS_REPO" status --porcelain)" ]]; then
    echo "FATAL: source repo $SKILLS_REPO has uncommitted changes." >&2
    echo "       Commit or stash them first, or pass --allow-dirty." >&2
    exit 3
  fi
fi

REV_SHA="$(git -C "$SKILLS_REPO" rev-parse --short "$REV")"
REV_FULL="$(git -C "$SKILLS_REPO" rev-parse "$REV")"

echo "[sync] source repo  : $SKILLS_REPO"
echo "[sync] source rev   : $REV  ($REV_SHA)"
echo "[sync] target repo  : $GITLAB_REPO"
echo "[sync] target origin: $GITLAB_ORIGIN"
echo "[sync] push?        : $([[ $DO_PUSH -eq 1 ]] && echo yes || echo no)"
echo "[sync] dry-run?     : $([[ $DO_DRY_RUN -eq 1 ]] && echo YES || echo no)"
echo

# ─────────────────────────────────────────────────────────────────────────
# Stage 1: produce the stripped public bundle in a scratch dir
# ─────────────────────────────────────────────────────────────────────────
SCRATCH="$(mktemp -d -t doca-skills-sync.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT
STAGED="$SCRATCH/staged"

if [[ "$DO_DRY_RUN" -eq 1 ]]; then
  echo "[sync] [dry-run] would: bash $SCRIPT_DIR/make-public-bundle.sh $REV $STAGED"
else
  bash "$SCRIPT_DIR/make-public-bundle.sh" "$REV" "$STAGED"
fi
[[ "$DO_DRY_RUN" -eq 0 && ! -d "$STAGED/skills" ]] && {
  echo "FATAL: make-public-bundle.sh did not produce $STAGED/skills" >&2
  exit 4
}

# ─────────────────────────────────────────────────────────────────────────
# Stage 2: sync into the GitLab repo. Preserve .git, remove everything
# else, copy the staged tree in, restore .git.
# ─────────────────────────────────────────────────────────────────────────
echo "[sync] preparing target tree (preserving .git/)..."
if [[ "$DO_DRY_RUN" -eq 1 ]]; then
  echo "[sync] [dry-run] would: rsync -a --delete --exclude='.git/' $STAGED/ $GITLAB_REPO/"
else
  # Use rsync to mirror exactly: delete everything not in $STAGED, but
  # leave .git/ alone so we keep the GitLab remote / history.
  if ! command -v rsync >/dev/null 2>&1; then
    echo "FATAL: rsync not installed" >&2; exit 5
  fi
  rsync -a --delete --exclude='.git/' "$STAGED/" "$GITLAB_REPO/"
fi

# ─────────────────────────────────────────────────────────────────────────
# Stage 3: commit (and optionally push)
# ─────────────────────────────────────────────────────────────────────────
cd "$GITLAB_REPO"

if [[ "$DO_DRY_RUN" -eq 1 ]]; then
  echo "[sync] [dry-run] would: git add -A && git commit"
  [[ "$DO_PUSH" -eq 1 ]] && echo "[sync] [dry-run] would: git push origin HEAD"
  echo "[sync] dry-run complete."
  exit 0
fi

# Add everything (including deletes).
git add -A

if git diff --staged --quiet; then
  echo "[sync] no changes vs current GitLab HEAD — nothing to commit."
else
  if [[ -z "$COMMIT_MSG" ]]; then
    COMMIT_MSG="doca-skills: sync public bundle from $REV ($REV_SHA)"
  fi

  git commit -m "$COMMIT_MSG" -m "Source: $SKILLS_REPO @ $REV_FULL" \
      --author "doca-skills sync <doca-skills-sync@nvidia.local>" \
      || { echo "FATAL: commit failed" >&2; exit 6; }

  echo "[sync] committed: $(git log --oneline -1)"
fi

if [[ "$DO_PUSH" -eq 1 ]]; then
  echo "[sync] pushing to origin (current branch)..."
  git push origin HEAD || { echo "FATAL: push failed" >&2; exit 7; }
  echo "[sync] pushed."
fi

echo
echo "[sync] done. Tester can now:"
echo "         git clone $GITLAB_ORIGIN doca-skills"
echo "         cd doca-skills"
echo "         ./install.sh --agent cursor"
