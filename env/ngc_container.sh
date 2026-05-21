#!/usr/bin/env bash
# devops/env/ngc_container.sh — pull and execute commands inside the
# public NGC DOCA container. Used by ab_runner.py's AppExampleRunner
# to materialize the "full_compile" sub-protocol: take the commands
# the agent recommended in its first-app response, run them inside a
# real DOCA install, and report exit codes.
#
# Public registry only. The container is anonymously pullable per
# the doca-skills bundle's `doca-setup ## no-install` Path 0
# documentation.
#
# Usage:
#   ./ngc_container.sh pull
#   ./ngc_container.sh exec "pkg-config --modversion doca-common"
#   ./ngc_container.sh exec_script ./build_first_app.sh
#   ./ngc_container.sh shell    # interactive, for debugging only
#
# Configuration (env vars; defaults are sensible):
#   DOCA_NGC_REPO    — default 'nvcr.io/nvidia/doca/doca'
#   DOCA_NGC_TAG     — REQUIRED. The runner sets this from the bundle's
#                      audit footer (see doca-public-knowledge-map). The
#                      script refuses to run without an explicit tag,
#                      so the run is reproducible.
#   DOCA_NGC_ARCH    — auto-detected from `uname -m` if unset.
#                      Maps x86_64 → amd64, aarch64/arm64 → arm64.
#   NGC_PULL_TIMEOUT — default 600 seconds.
#   NGC_EXEC_TIMEOUT — default 600 seconds (per-command).
#
# Exit codes:
#   0   — command succeeded inside the container
#   1   — script-level usage / config error
#   2   — docker not available or NGC pull failed
#   N>2 — passed through from the in-container command

set -euo pipefail

DOCA_NGC_REPO="${DOCA_NGC_REPO:-nvcr.io/nvidia/doca/doca}"
DOCA_NGC_TAG="${DOCA_NGC_TAG:-}"
NGC_PULL_TIMEOUT="${NGC_PULL_TIMEOUT:-600}"
NGC_EXEC_TIMEOUT="${NGC_EXEC_TIMEOUT:-600}"

err()  { printf 'ngc_container.sh: ERROR: %s\n' "$*" >&2; }
warn() { printf 'ngc_container.sh: WARN:  %s\n' "$*" >&2; }
info() { printf 'ngc_container.sh: INFO:  %s\n' "$*" >&2; }

# --- arch detection ---------------------------------------------------------
detect_arch() {
  if [ -n "${DOCA_NGC_ARCH:-}" ]; then
    printf '%s' "$DOCA_NGC_ARCH"
    return 0
  fi
  case "$(uname -m)" in
    x86_64)          printf 'amd64' ;;
    aarch64|arm64)   printf 'arm64' ;;
    *)
      err "unsupported uname -m: $(uname -m); set DOCA_NGC_ARCH=amd64|arm64 explicitly"
      return 1 ;;
  esac
}

# --- preflight --------------------------------------------------------------
require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    err "docker not found in PATH; this script requires a Docker engine"
    exit 2
  fi
  if ! docker info >/dev/null 2>&1; then
    err "docker engine not reachable (docker info failed); is the daemon running?"
    exit 2
  fi
}

require_tag() {
  if [ -z "${DOCA_NGC_TAG:-}" ]; then
    err "DOCA_NGC_TAG is not set."
    err "This script intentionally refuses to default the tag — pinning is the runner's"
    err "job, not the script's. Set DOCA_NGC_TAG to the tag the bundle's audit footer"
    err "currently certifies (see doca-skills/skills/doca-public-knowledge-map/SKILL.md"
    err "## URL audit) or to the tag the PR is exercising."
    exit 1
  fi
}

# --- image identity ---------------------------------------------------------
image_ref() {
  require_tag
  local arch
  arch="$(detect_arch)"
  # Per the bundle's tag-shape guidance (<doca-version>-<base-os>-<arch>),
  # the runner is responsible for assembling the full tag. This script
  # accepts either a fully-qualified DOCA_NGC_TAG (already includes arch)
  # or appends the detected arch when DOCA_NGC_TAG looks arch-less.
  if printf '%s' "$DOCA_NGC_TAG" | grep -qE -- '-(amd64|arm64)(-host|-dpu)?$'; then
    printf '%s:%s' "$DOCA_NGC_REPO" "$DOCA_NGC_TAG"
  else
    # Fallback: append `-<arch>-host` (typical for first-app build/learn).
    printf '%s:%s-%s-host' "$DOCA_NGC_REPO" "$DOCA_NGC_TAG" "$arch"
  fi
}

# --- subcommands ------------------------------------------------------------
cmd_pull() {
  require_docker
  local img
  img="$(image_ref)"
  info "pulling $img (timeout ${NGC_PULL_TIMEOUT}s)"
  if ! timeout "${NGC_PULL_TIMEOUT}" docker pull "$img"; then
    err "docker pull of $img failed"
    err "common causes: bad tag (verify in https://catalog.ngc.nvidia.com),"
    err "no outbound network, or the build agent is not allowed to reach nvcr.io"
    exit 2
  fi
  info "pull ok: $img"
}

cmd_exec() {
  require_docker
  if [ "$#" -lt 1 ]; then
    err "usage: $0 exec <command line>"; exit 1
  fi
  local img
  img="$(image_ref)"
  # Pull on demand; docker pull is idempotent + fast when cached.
  cmd_pull >/dev/null 2>&1 || cmd_pull
  info "exec in $img: $*"
  set +e
  timeout "${NGC_EXEC_TIMEOUT}" docker run --rm \
    -e DOCA_LOG_LEVEL="${DOCA_LOG_LEVEL:-30}" \
    "$img" \
    /bin/bash -lc "$*"
  rc=$?
  set -e
  return "$rc"
}

cmd_exec_script() {
  require_docker
  if [ "$#" -lt 1 ] || [ ! -f "$1" ]; then
    err "usage: $0 exec_script <path/to/script.sh>"; exit 1
  fi
  local img script
  img="$(image_ref)"
  script="$1"
  cmd_pull >/dev/null 2>&1 || cmd_pull
  info "exec_script in $img: $script"
  # Mount the host script directory read-only so the container can run it
  # without being able to mutate the host workspace.
  set +e
  timeout "${NGC_EXEC_TIMEOUT}" docker run --rm \
    -e DOCA_LOG_LEVEL="${DOCA_LOG_LEVEL:-30}" \
    -v "$(realpath "$(dirname "$script")")":/work:ro \
    -w /work \
    "$img" \
    /bin/bash -l "/work/$(basename "$script")"
  rc=$?
  set -e
  return "$rc"
}

cmd_shell() {
  require_docker
  local img
  img="$(image_ref)"
  cmd_pull >/dev/null 2>&1 || cmd_pull
  info "interactive shell in $img"
  exec docker run --rm -it "$img" /bin/bash -l
}

cmd_help() {
  sed -n '2,30p' "$0" | sed -e 's/^# *//'
}

# --- entry ------------------------------------------------------------------
case "${1:-help}" in
  pull)        shift; cmd_pull "$@" ;;
  exec)        shift; cmd_exec "$@" ;;
  exec_script) shift; cmd_exec_script "$@" ;;
  shell)       shift; cmd_shell "$@" ;;
  help|-h|--help) cmd_help ;;
  *) err "unknown subcommand: $1"; cmd_help; exit 1 ;;
esac
