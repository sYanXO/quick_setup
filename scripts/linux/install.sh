#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${QUICKSETUP_ROOT:?missing QUICKSETUP_ROOT}"
CONFIG_FILE="${QUICKSETUP_CONFIG_FILE:-$ROOT_DIR/config/default.env}"
# shellcheck disable=SC1090
source "$CONFIG_FILE"
# shellcheck disable=SC1090
source "$ROOT_DIR/scripts/lib/common.sh"

DISTRO_ID=""
PKG_MANAGER=""
PACKAGES_UPDATED=0
PROJECT_PATH="${QUICKSETUP_PROJECT_PATH:-}"
PROJECT_GROUPS=()

resolve_project_path() {
  if [[ -n "$PROJECT_PATH" ]]; then
    [[ -d "$PROJECT_PATH" ]] || die "Project path not found: $PROJECT_PATH"
    return
  fi

  if is_interactive && prompt_yes_no "Use the current directory as the project path ($(pwd))?" "y"; then
    PROJECT_PATH="$(pwd)"
  fi
}

detect_project_groups() {
  [[ -n "$PROJECT_PATH" ]] || return 0

  log "Inspecting project: $PROJECT_PATH"

  [[ -f "$PROJECT_PATH/Cargo.toml" ]] && PROJECT_GROUPS+=("rust")
  [[ -f "$PROJECT_PATH/go.mod" ]] && PROJECT_GROUPS+=("go")
  [[ -f "$PROJECT_PATH/package.json" ]] && PROJECT_GROUPS+=("node")
  [[ -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/requirements.txt" || -f "$PROJECT_PATH/uv.lock" ]] && PROJECT_GROUPS+=("python")
  [[ -f "$PROJECT_PATH/CMakeLists.txt" || -f "$PROJECT_PATH/Makefile" || -d "$PROJECT_PATH/src" && -n "$(find "$PROJECT_PATH" -maxdepth 2 -type f \( -name '*.cpp' -o -name '*.cc' -o -name '*.cxx' -o -name '*.hpp' -o -name '*.hh' \) -print -quit 2>/dev/null)" ]] && PROJECT_GROUPS+=("cpp")

  if [[ "${#PROJECT_GROUPS[@]}" -gt 0 ]]; then
    log "Detected project stacks: ${PROJECT_GROUPS[*]}"
  else
    warn "No language manifests detected; default config will be used"
  fi
}

configure_selected_groups() {
  local detected_csv=""
  local group

  if [[ -n "${QUICKSETUP_ONLY_GROUPS:-}" ]]; then
    return
  fi

  if [[ "${#PROJECT_GROUPS[@]}" -eq 0 ]]; then
    return
  fi

  for group in "${PROJECT_GROUPS[@]}"; do
    if [[ -z "$detected_csv" ]]; then
      detected_csv="$group"
    else
      detected_csv="$detected_csv,$group"
    fi
  done

  if prompt_yes_no "Install only the detected language stacks ($detected_csv) plus common tooling?" "y"; then
    QUICKSETUP_ONLY_GROUPS="$detected_csv,basics,editors,shell,docker,dotfiles"
    export QUICKSETUP_ONLY_GROUPS
  fi
}

detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-unknown}"
  else
    die "Unable to detect Linux distribution"
  fi

  case "$DISTRO_ID" in
    ubuntu|ubuntu-core|debian)
      PKG_MANAGER="apt"
      ;;
    arch|omarchy)
      PKG_MANAGER="pacman"
      ;;
    *)
      if [[ "$DISTRO_ID" == *ubuntu* ]]; then
        PKG_MANAGER="apt"
      elif [[ "$DISTRO_ID" == *arch* ]]; then
        PKG_MANAGER="pacman"
      elif [[ "${ID_LIKE:-}" == *arch* ]]; then
        PKG_MANAGER="pacman"
      elif [[ "${ID_LIKE:-}" == *debian* ]]; then
        PKG_MANAGER="apt"
      else
        die "Unsupported distribution: $DISTRO_ID"
      fi
      ;;
  esac
}

package_installed() {
  local package="$1"
  case "$PKG_MANAGER" in
    apt)
      dpkg -s "$package" >/dev/null 2>&1
      ;;
    pacman)
      pacman -Q "$package" >/dev/null 2>&1
      ;;
  esac
}

update_package_index() {
  if [[ "$PACKAGES_UPDATED" == "1" ]]; then
    return
  fi
  case "$PKG_MANAGER" in
    apt)
      run_cmd sudo apt-get update
      ;;
    pacman)
      run_cmd sudo pacman -Sy --noconfirm
      ;;
  esac
  PACKAGES_UPDATED=1
}

install_packages() {
  local missing=()
  local package
  for package in "$@"; do
    if ! package_installed "$package"; then
      missing+=("$package")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return
  fi

  update_package_index
  case "$PKG_MANAGER" in
    apt)
      run_cmd sudo apt-get install -y "${missing[@]}"
      ;;
    pacman)
      run_cmd sudo pacman -S --noconfirm --needed "${missing[@]}"
      ;;
  esac
}

install_basics() {
  group_enabled basics || return 0
  log "Installing base packages"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_packages curl wget unzip zip tar git ca-certificates build-essential pkg-config ripgrep fd-find fzf tmux zsh
  else
    install_packages curl wget unzip zip tar git base-devel pkgconf ripgrep fd fzf tmux zsh
  fi
}

install_cpp() {
  group_enabled cpp || return 0
  log "Installing C++ toolchain"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_packages gcc g++ clang lldb cmake ninja-build gdb
  else
    install_packages gcc clang lldb cmake ninja gdb
  fi
}

install_rust() {
  group_enabled rust || return 0
  log "Installing Rust toolchain"
  if command -v rustup >/dev/null 2>&1; then
    run_cmd rustup toolchain install stable
    run_cmd rustup default stable
  else
    run_cmd bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  fi
  run_cmd "$HOME/.cargo/bin/rustup" component add rustfmt clippy
}

install_go() {
  group_enabled go || return 0
  log "Installing Go"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_packages golang-go
  else
    install_packages go
  fi
}

install_python() {
  group_enabled python || return 0
  log "Installing Python"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_packages python3 python3-pip python3-venv pipx
  else
    install_packages python python-pip python-pipx
  fi
}

install_node() {
  group_enabled node || return 0
  log "Installing Node.js and TypeScript"
  if command -v fnm >/dev/null 2>&1; then
    run_cmd fnm install --latest
    run_cmd fnm default latest
  else
    run_cmd bash -c "curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell"
    if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
      run_cmd "$HOME/.local/share/fnm/fnm" install --latest
      run_cmd "$HOME/.local/share/fnm/fnm" default latest
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    run_cmd npm install -g typescript typescript-language-server pnpm
  else
    warn "npm is not on PATH yet; TypeScript packages will install on the next run"
  fi
}

install_editors() {
  group_enabled editors || return 0
  log "Installing editors"
  if [[ "${INSTALL_NEOVIM:-1}" == "1" ]]; then
    if [[ "$PKG_MANAGER" == "apt" ]]; then
      install_packages neovim
    else
      install_packages neovim
    fi
  fi

  if [[ "${INSTALL_VSCODE:-1}" == "1" ]]; then
    if command -v code >/dev/null 2>&1; then
      return 0
    fi

    if [[ "$PKG_MANAGER" == "pacman" ]]; then
      install_packages code
      return 0
    fi

    if command -v snap >/dev/null 2>&1; then
      run_cmd sudo snap install code --classic
      return 0
    fi

    warn "Unable to install VS Code automatically on this distro; install it manually if needed"
  fi
}

install_docker() {
  group_enabled docker || return 0
  log "Installing Docker"
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    install_packages docker.io docker-compose-v2
  else
    install_packages docker docker-compose
  fi
  run_cmd sudo usermod -aG docker "$USER"
}

configure_shell() {
  group_enabled shell || return 0

  if [[ "${PREFERRED_SHELL:-zsh}" == "zsh" ]] && command -v zsh >/dev/null 2>&1; then
    if [[ "${SHELL:-}" != "$(command -v zsh)" ]] && prompt_yes_no "Set zsh as your default shell?" "n"; then
      run_cmd chsh -s "$(command -v zsh)"
    fi
  fi
}

apply_dotfiles() {
  group_enabled dotfiles || return 0
  log "Applying dotfiles"
  copy_if_different "$ROOT_DIR/dotfiles/.gitconfig" "$HOME/.gitconfig"
  copy_if_different "$ROOT_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
  copy_if_different "$ROOT_DIR/dotfiles/.tmux.conf" "$HOME/.tmux.conf"
  copy_if_different "$ROOT_DIR/dotfiles/nvim/init.lua" "$HOME/.config/nvim/init.lua"

  if is_dry_run; then
    log "dry-run: ensure directory $HOME/.config/Code/User"
  else
    mkdir -p "$HOME/.config/Code/User"
  fi
  copy_if_different "$ROOT_DIR/dotfiles/vscode/settings.json" "$HOME/.config/Code/User/settings.json"
  copy_if_different "$ROOT_DIR/dotfiles/vscode/extensions.txt" "$HOME/.config/Code/User/extensions.txt"
}

verify_command() {
  local label="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    log "verified: $label ($(command -v "$1"))"
  else
    warn "missing: $label"
  fi
}

print_summary() {
  log "Verification summary"
  verify_command "git" git
  verify_command "gcc" gcc
  verify_command "clang" clang
  verify_command "cmake" cmake
  verify_command "ninja" ninja
  verify_command "rustc" rustc
  verify_command "cargo" cargo
  verify_command "go" go
  verify_command "python3" python3
  verify_command "pipx" pipx
  verify_command "node" node
  verify_command "npm" npm
  verify_command "tsc" tsc
  verify_command "nvim" nvim
  verify_command "docker" docker
}

main() {
  detect_distro
  log "Detected distro: $DISTRO_ID ($PKG_MANAGER)"
  resolve_project_path
  detect_project_groups
  configure_selected_groups
  install_basics
  install_cpp
  install_rust
  install_go
  install_python
  install_node
  install_editors
  install_docker
  configure_shell
  apply_dotfiles
  print_summary
}

main "$@"
