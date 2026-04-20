#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[quicksetup] %s\n' "$*"
}

warn() {
  printf '[quicksetup] warning: %s\n' "$*" >&2
}

die() {
  printf '[quicksetup] error: %s\n' "$*" >&2
  exit 1
}

is_dry_run() {
  [[ "${QUICKSETUP_DRY_RUN:-0}" == "1" ]]
}

is_interactive() {
  [[ "${QUICKSETUP_NON_INTERACTIVE:-0}" != "1" ]] && [[ -t 0 ]]
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  [[ ",$csv," == *",$needle,"* ]]
}

group_enabled() {
  local group="$1"
  local only="${QUICKSETUP_ONLY_GROUPS:-}"
  local skip="${QUICKSETUP_SKIP_COMPONENTS:-}"

  if [[ -n "$only" ]] && ! csv_contains "$only" "$group"; then
    return 1
  fi

  if [[ -n "$skip" ]] && csv_contains "$skip" "$group"; then
    return 1
  fi

  local upper
  upper="$(printf '%s' "$group" | tr '[:lower:]' '[:upper:]')"
  local var="ENABLE_${upper}"
  [[ "${!var:-1}" == "1" ]]
}

run_cmd() {
  if is_dry_run; then
    log "dry-run: $*"
  else
    log "run: $*"
    "$@"
  fi
}

prompt_yes_no() {
  local message="$1"
  local default="${2:-y}"
  local reply=""
  local prompt="[Y/n]"

  if [[ "$default" == "n" ]]; then
    prompt="[y/N]"
  fi

  if ! is_interactive; then
    [[ "$default" == "y" ]]
    return
  fi

  while true; do
    printf '[quicksetup] %s %s ' "$message" "$prompt"
    read -r reply
    reply="${reply,,}"

    if [[ -z "$reply" ]]; then
      [[ "$default" == "y" ]]
      return
    fi

    case "$reply" in
      y|yes)
        return 0
        ;;
      n|no)
        return 1
        ;;
    esac
  done
}

ensure_line_in_file() {
  local file="$1"
  local line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}

copy_if_different() {
  local src="$1"
  local dst="$2"
  if is_dry_run; then
    log "dry-run: ensure directory $(dirname "$dst")"
  else
    mkdir -p "$(dirname "$dst")"
  fi
  if [[ ! -f "$dst" ]] || ! cmp -s "$src" "$dst"; then
    if is_dry_run; then
      log "dry-run: copy $src -> $dst"
    else
      cp "$src" "$dst"
    fi
  fi
}
