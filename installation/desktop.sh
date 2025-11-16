#!/bin/bash
# Desktop module. Applies dotfiles, icons/fonts, shell defaults, and user-level
# systemd watchers so the graphical environment matches repository assets.
# Preconditions: commons sourced; `installation/defaults/desktop/{config,home}`
# must exist; user should have write access to $HOME and ~/.config.
# Postconditions: configs synced, watchers enabled, keyring/default apps set.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

# DESKTOP_CONFIG_DEFAULTS=source tree for ~/.config (rsynced).
DESKTOP_CONFIG_DEFAULTS="$ARCHENEMY_DEFAULTS_DIR/desktop/config"
# DESKTOP_HOME_DEFAULTS=optional overrides synced into $HOME.
DESKTOP_HOME_DEFAULTS="$ARCHENEMY_DEFAULTS_DIR/desktop/home"
# DESKTOP_CONFIG_WATCHERS=user systemd path units that refresh configs.
DESKTOP_CONFIG_WATCHERS=(
  "ae-refresh-hyprland.path"
  "ae-refresh-walker.path"
  "ae-refresh-waybar.path"
)

_desktop_sync_config_tree() {
  if [[ ! -d "$DESKTOP_CONFIG_DEFAULTS" ]]; then
    log_error "Desktop config defaults missing at $DESKTOP_CONFIG_DEFAULTS"
    exit 1
  fi
  log_info "Syncing ~/.config with desktop defaults..."
  run_cmd mkdir -p "$ARCHENEMY_USER_CONFIG_DIR"
  run_cmd rsync -a --delete "$DESKTOP_CONFIG_DEFAULTS/." "$ARCHENEMY_USER_CONFIG_DIR/"
}

_desktop_sync_home_overrides() {
  if [[ ! -d "$DESKTOP_HOME_DEFAULTS" ]]; then
    return
  fi
  log_info "Applying home directory overrides..."
  run_cmd rsync -a "$DESKTOP_HOME_DEFAULTS/." "$HOME/"
}

_desktop_set_default_shell() {
  local desired_shell="${ARCHENEMY_DEFAULT_SHELL:-}"
  if [[ -z "$desired_shell" ]]; then
    return
  fi

  local shell_path=""
  if command -v "$desired_shell" >/dev/null 2>&1; then
    shell_path="$(command -v "$desired_shell")"
  elif [[ -x "$desired_shell" ]]; then
    shell_path="$desired_shell"
  fi

  if [[ -z "$shell_path" ]]; then
    log_warn "Requested default shell '$desired_shell' not found; skipping change."
    return
  fi

  if [[ "$SHELL" == "$shell_path" ]]; then
    return
  fi

  log_info "Setting default shell to $shell_path..."
  run_cmd sudo chsh -s "$shell_path" "$USER"
}

_desktop_sync_hypr_keyboard_layout() {
  log_info "Syncing Hyprland keyboard layout with /etc/vconsole.conf..."
  local vconsole_conf="/etc/vconsole.conf"
  local hypr_conf="$ARCHENEMY_USER_CONFIG_DIR/hypr/hyprland.conf"
  if [[ ! -f "$vconsole_conf" || ! -f "$hypr_conf" ]]; then
    log_info "Skipping Hyprland keyboard sync; required files missing."
    return
  fi
  if grep -q '^XKBLAYOUT=' "$vconsole_conf"; then
    local layout
    layout=$(grep '^XKBLAYOUT=' "$vconsole_conf" | cut -d= -f2 | tr -d '"')
    run_cmd sed -i -E "s/^(\\s*kb_layout =).*/\\1 $layout/" "$hypr_conf" || true
  fi
}

_desktop_install_fonts() {
  log_info "Installing bundled fonts..."
  local fonts_dir="$HOME/.local/share/fonts"
  local bundled_font="$DESKTOP_CONFIG_DEFAULTS/fonts/fira-code.ttf"
  run_cmd mkdir -p "$fonts_dir"
  if [[ -f "$bundled_font" ]]; then
    run_cmd cp "$bundled_font" "$fonts_dir/"
  fi
  run_cmd fc-cache || true
}

_desktop_install_icons() {
  log_info "Installing application icons..."
  local icons_dir="$HOME/.local/share/icons"
  local defaults_icons_dir="$ARCHENEMY_DEFAULTS_DIR/applications/icons"
  run_cmd mkdir -p "$icons_dir"
  if [[ -d "$defaults_icons_dir" ]]; then
    run_cmd cp -r "$defaults_icons_dir/." "$icons_dir/"
  fi
}

_desktop_configure_gtk_gnome() {
  log_info "Configuring GTK/GNOME defaults..."
  run_cmd gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' >/dev/null 2>&1 || true
  run_cmd gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 || true
  run_cmd gsettings set org.gnome.desktop.interface icon-theme 'Yaru-blue' >/dev/null 2>&1 || true
  run_cmd sudo gtk-update-icon-cache /usr/share/icons/Yaru >/dev/null 2>&1 || true
}

_desktop_configure_mimetypes() {
  log_info "Configuring default applications..."
  run_cmd update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  run_cmd xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp >/dev/null 2>&1 || true
  run_cmd xdg-mime default org.gnome.Evince.desktop application/pdf >/dev/null 2>&1 || true
  run_cmd xdg-settings set default-web-browser chromium.desktop >/dev/null 2>&1 || true
  run_cmd xdg-mime default chromium.desktop x-scheme-handler/http x-scheme-handler/https >/dev/null 2>&1 || true
  run_cmd xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm >/dev/null 2>&1 || true
}

_desktop_configure_default_keyring() {
  log_info "Creating default, unlocked keyring..."
  local keyring_dir="$HOME/.local/share/keyrings"
  local keyring_file="$keyring_dir/Default_keyring.keyring"
  run_cmd mkdir -p "$keyring_dir"
  run_cmd tee "$keyring_file" >/dev/null <<'KEYRING'
[keyring]
display-name=Default keyring
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
KEYRING
  run_cmd tee "$keyring_dir/default" >/dev/null <<<"Default_keyring"
}

_desktop_configure_git_identity() {
  if [[ -n "${ARCHENEMY_USER_NAME:-}" ]]; then
    run_cmd git config --global user.name "$ARCHENEMY_USER_NAME"
  fi
  if [[ -n "${ARCHENEMY_USER_EMAIL:-}" ]]; then
    run_cmd git config --global user.email "$ARCHENEMY_USER_EMAIL"
  fi
}

_desktop_reload_user_systemd() {
  if command -v systemctl >/dev/null 2>&1; then
    run_as_user systemctl --user daemon-reload || true
  fi
}

_desktop_enable_config_watchers() {
  local user_systemd_dir="$ARCHENEMY_USER_CONFIG_DIR/systemd/user"
  if [[ ! -d "$user_systemd_dir" ]]; then
    log_info "No user systemd directory found; skipping ae refresh watchers."
    return
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    log_info "systemctl unavailable; skipping ae refresh watchers."
    return
  fi
  if ! run_as_user systemctl --user status >/dev/null 2>&1; then
    log_info "User systemd session unavailable; enable ae refresh watchers manually later."
    return
  fi
  log_info "Enabling ae refresh watchers (Hyprland/Waybar/Walker)..."
  run_as_user systemctl --user daemon-reload || true
  local watcher
  for watcher in "${DESKTOP_CONFIG_WATCHERS[@]}"; do
    if ! run_as_user systemctl --user enable --now "$watcher" >/dev/null 2>&1; then
      log_warn "Unable to enable $watcher; run systemctl --user enable --now $watcher manually."
    fi
  done
}

run_desktop_preinstall() {
  log_info "Starting desktop + dotfiles configuration..."
  _desktop_sync_config_tree
  _desktop_sync_home_overrides
  _desktop_sync_hypr_keyboard_layout
  _desktop_set_default_shell
  _desktop_install_fonts
  _desktop_install_icons
  _desktop_configure_gtk_gnome
  _desktop_configure_mimetypes
  _desktop_configure_default_keyring
  _desktop_configure_git_identity
  _desktop_reload_user_systemd
  _desktop_enable_config_watchers
  log_success "Desktop environment configured."
}

run_desktop_postinstall() {
  log_info "Desktop module postinstall: refreshing keyring + defaults..."
  _desktop_configure_default_keyring
  _desktop_enable_config_watchers
  log_success "Desktop postinstall completed."
}

run_desktop() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_desktop_postinstall "$@"
  else
    run_desktop_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_desktop "$@"
fi
