#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_URL="${QUICKSETUP_REPO_URL:-https://github.com/sreayan/quicksetup.git}"
DEFAULT_INSTALL_ROOT="${QUICKSETUP_INSTALL_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/quicksetup}"
CONFIG_FILE=""
PROJECT_PATH=""
ONLY_GROUPS=""
SKIP_COMPONENTS=""
NON_INTERACTIVE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--project PATH] [--config PATH] [--only a,b] [--skip x,y] [--non-interactive] [--dry-run]
EOF
}

clone_or_update_repo() {
  local target_dir="$1"
  local repo_url="$2"

  if command -v git >/dev/null 2>&1 && [[ -d "$target_dir/.git" ]]; then
    git -C "$target_dir" pull --ff-only
    return
  fi

  mkdir -p "$(dirname "$target_dir")"
  if command -v git >/dev/null 2>&1; then
    git clone "$repo_url" "$target_dir"
    return
  fi

  echo "git is required for remote bootstrap hydration" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_PATH="$2"
      shift 2
      ;;
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --only)
      ONLY_GROUPS="$2"
      shift 2
      ;;
    --skip)
      SKIP_COMPONENTS="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -f "$ROOT_DIR/scripts/linux/install.sh" && -f "$ROOT_DIR/config/default.env" ]]; then
  if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$ROOT_DIR/config/default.env"
  fi
else
  ROOT_DIR="$DEFAULT_INSTALL_ROOT"
  clone_or_update_repo "$ROOT_DIR" "$DEFAULT_REPO_URL"
  if [[ -z "$CONFIG_FILE" ]]; then
    CONFIG_FILE="$ROOT_DIR/config/default.env"
  fi
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ -n "$PROJECT_PATH" ]]; then
  PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
fi

export QUICKSETUP_ROOT="$ROOT_DIR"
export QUICKSETUP_CONFIG_FILE="$CONFIG_FILE"
export QUICKSETUP_PROJECT_PATH="$PROJECT_PATH"
export QUICKSETUP_ONLY_GROUPS="$ONLY_GROUPS"
export QUICKSETUP_SKIP_COMPONENTS="$SKIP_COMPONENTS"
export QUICKSETUP_NON_INTERACTIVE="$NON_INTERACTIVE"
export QUICKSETUP_DRY_RUN="$DRY_RUN"

exec "$ROOT_DIR/scripts/linux/install.sh"
