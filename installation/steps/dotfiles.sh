#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
################################################################################
# DOTFILES
################################################################################
#
# Goal: Synchronize the detached user dotfiles repository (Hyprland, mako,
#       waybar, shells, tooling) with the live ~/.config tree and apply the
#       remaining user-level preferences (Git identity, Hypr keyboard layout).
#

################################################################################
# DOTFILES PREP
# Refreshes ~/.config/dotfiles with the curated blueprint shipped under
# default/dotfiles, copying known directories/files explicitly to avoid
# accidental globbing.
#
_prepare_dotfiles_blueprint() {
  log_info "Syncing dotfiles blueprint..."
  local defaults_source="$ARCHENEMY_DEFAULTS_DOTFILES_DIR"
  local dotfiles_dir="$ARCHENEMY_USER_DOTFILES_DIR"

  if [[ ! -d "$defaults_source" ]]; then
    log_error "Dotfile defaults missing at $defaults_source"
    exit 1
  fi

  run_cmd mkdir -p "$dotfiles_dir"

  local blueprint_dirs=("alacritty" "btop" "git" "lazygit" "ghostty" "kitty")
  for dir in "${blueprint_dirs[@]}"; do
    local source_dir="$defaults_source/$dir"
    if [[ -d "$source_dir" ]]; then
      run_cmd rm -rf "$dotfiles_dir/$dir"
      run_cmd cp -r "$source_dir" "$dotfiles_dir/"
    else
      log_info "Skipping dotfiles blueprint directory '$dir'; not found in defaults."
    fi
  done

  local blueprint_files=("bashrc" "neovim.lua" "starship.toml")
  for file in "${blueprint_files[@]}"; do
    local source_file="$defaults_source/$file"
    if [[ -f "$source_file" ]]; then
      run_cmd cp "$source_file" "$dotfiles_dir/$file"
    else
      log_info "Skipping dotfiles blueprint file '$file'; not found in defaults."
    fi
  done

  if [[ -z "$(find "$dotfiles_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    log_error "Dotfiles blueprint sync produced an empty directory; aborting."
    exit 1
  fi
}

################################################################################
# DOTFILES SYNC
# Copies curated directories/files from ~/.config/dotfiles into ~/.config.
#
_copy_dotfiles_to_config() {
  log_info "Copying dotfiles into ~/.config..."
  local dotfiles_dir="$ARCHENEMY_USER_DOTFILES_DIR"
  local config_dir="$HOME/.config"

  if [[ ! -d "$dotfiles_dir" ]]; then
    log_error "User dotfiles directory missing at $dotfiles_dir. Run the graphics step first."
    exit 1
  fi

  if [[ -z "$(find "$dotfiles_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    log_error "User dotfiles directory is empty; aborting."
    exit 1
  fi

  run_cmd mkdir -p "$config_dir"

  local dotfile_dirs=("alacritty" "btop" "git" "lazygit" "ghostty" "kitty")

  for dir in "${dotfile_dirs[@]}"; do
    local source_path="$dotfiles_dir/$dir"
    if [[ -d "$source_path" ]]; then
      run_cmd rm -rf "$config_dir/$dir"
      run_cmd cp -r "$source_path" "$config_dir/"
    else
      log_info "Skipping optional dotfiles directory '$dir'; not found in $dotfiles_dir."
    fi
  done

  local dotfile_files=("neovim.lua" "starship.toml")
  for file in "${dotfile_files[@]}"; do
    local source_file="$dotfiles_dir/$file"
    if [[ -f "$source_file" ]]; then
      run_cmd cp "$source_file" "$config_dir/$file"
    fi
  done

  local bashrc_path="$dotfiles_dir/bashrc"
  if [[ -f "$bashrc_path" ]]; then
    run_cmd cp "$bashrc_path" "$HOME/.bashrc"
  fi
  if systemctl --user status >/dev/null 2>&1; then
    run_as_user systemctl --user daemon-reload || log_info "Unable to reload user systemd; no active user session."
  fi
}

################################################################################
# SHELL PACKAGES
# Installs Zsh and supporting plugins before applying any shell configuration.
#
_install_shell_packages() {
  log_info "Installing shell and terminal packages..."
  _install_pacman_packages "zsh" "zsh-completions" "kitty"
  _install_aur_packages "oh-my-zsh-git" "ghostty-bin"
}

################################################################################
# APPLICATION LAUNCHER HELPERS
# Provides scaffolding for desktop entries (TUI/webapp) so integrators can add
# custom applications without re-implementing boilerplate.
#
_create_desktop_entry() {
  local name="$1"
  local exec_cmd="$2"
  local comment="$3"
  local category="$4"
  local applications_dir="$HOME/.local/share/applications"
  local desktop_file="$applications_dir/${name}.desktop"

  run_cmd mkdir -p "$applications_dir"
  tee "$desktop_file" >/dev/null <<EOF
[Desktop Entry]
Name=${name}
Exec=${exec_cmd}
Comment=${comment}
Type=Application
Categories=${category}
Terminal=true
EOF
}

_create_webapp_entry() {
  local name="$1"
  local url="$2"
  local applications_dir="$HOME/.local/share/applications"
  local desktop_file="$applications_dir/${name}.desktop"

  run_cmd mkdir -p "$applications_dir"
  tee "$desktop_file" >/dev/null <<EOF
[Desktop Entry]
Name=${name}
Exec=chromium --app=${url}
Type=Application
Categories=Network;WebBrowser;
EOF
}

_install_and_configure_tuis() {
  log_info "Installing and configuring TUIs..."
  # Example blueprint:
  # _install_aur_packages "lazydocker" "lazyjournal"
  # _create_desktop_entry "LazyDocker" "lazydocker" "Docker TUI" "utilities"
}

_install_and_configure_webapps() {
  log_info "Configuring web application launchers..."
  # Chromium is installed/configured during the graphics step; reuse that binary.
  # Example blueprint:
  # _create_webapp_entry "GitHub" "https://github.com"
  # _create_webapp_entry "Discord" "https://discord.com/channels/@me"
}

################################################################################
# ZSH
# Applies the Zsh configuration and sets it as the default shell.
#
_configure_zsh() {
  log_info "Applying Zsh configuration..."
  local zsh_dir="$ARCHENEMY_DEFAULTS_DOTFILES_DIR/zsh"
  local zshrc="$ARCHENEMY_DEFAULTS_DOTFILES_DIR/zshrc"

  if [[ ! -d "$zsh_dir" || ! -f "$zshrc" ]]; then
    log_info "Zsh defaults not found; skipping shell customization."
    return
  fi

  run_cmd mkdir -p "$HOME/.config/zsh"
  run_cmd cp -r "$zsh_dir/." "$HOME/.config/zsh/"
  run_cmd cp "$zshrc" "$HOME/.zshrc"
  run_cmd sudo chsh -s /bin/zsh "$USER"
}

################################################################################
# GIT
# Configures user-specific settings like Git credentials.
#
_configure_git() {
  log_info "Configuring Git..."
  if [[ -n "${ARCHENEMY_USER_NAME:-}" ]]; then
    run_cmd git config --global user.name "$ARCHENEMY_USER_NAME"
  fi
  if [[ -n "${ARCHENEMY_USER_EMAIL:-}" ]]; then
    run_cmd git config --global user.email "$ARCHENEMY_USER_EMAIL"
  fi
}

################################################################################
# RUN
################################################################################

run_setup_dotfiles() {
  log_info "Starting Step 5: Dotfiles..."

  _prepare_dotfiles_blueprint
  _install_shell_packages
  _copy_dotfiles_to_config
  _configure_zsh
  _configure_git
  _install_and_configure_tuis
  _install_and_configure_webapps

  log_success "Step 5: Dotfiles completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_dotfiles "$@"
fi
