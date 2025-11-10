#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
################################################################################
# GRAPHICS ENVIRONMENT
################################################################################
#
# Goal: Install and configure the core Hyprland graphical environment (packages,
#       fonts, icons, shells, theming, keyring, MIME handlers) so the desktop
#       launches with a sane default experience inspired by the official
#       Hyprland documentation and the Omarchy reference configs.
#

################################################################################
# COPY GRAPHICS DIR
# Copies a directory from the defaults directory to the user's configuration directory.
# Arguments:
#   $1: The relative path of the source directory.
#   $2: The target path of the destination directory.
#   $3: Whether the directory is required.
_copy_graphics_dir() {
  local relative="$1"
  local target="${2:-$relative}"
  local required="${3:-false}"
  local source_dir="$ARCHENEMY_DEFAULTS_GRAPHICS_DIR/$relative"
  local destination_dir="$ARCHENEMY_USER_CONFIG_DIR/$target"

  if [[ ! -d "$source_dir" ]]; then
    if [[ "$required" == true ]]; then
      log_error "Required defaults missing under $source_dir"
      exit 1
    fi
    log_info "Skipping $relative; defaults not found under $source_dir"
    return
  fi

  log_info "Installing $target defaults..."
  run_cmd mkdir -p "$(dirname "$destination_dir")"
  run_cmd rm -rf "$destination_dir"
  run_cmd cp -r "$source_dir" "$destination_dir"
}

################################################################################
# COPY GRAPHICS FILE
# Copies a file from the defaults directory to the user's configuration directory.
# Arguments:
#   $1: The relative path of the source file.
#   $2: The target path of the destination file.
#   $3: Whether the file is required.
_copy_graphics_file() {
  local relative="$1"
  local target="${2:-$relative}"
  local required="${3:-false}"
  local source_file="$ARCHENEMY_DEFAULTS_GRAPHICS_DIR/$relative"
  local destination_file="$ARCHENEMY_USER_CONFIG_DIR/$target"

  if [[ ! -f "$source_file" ]]; then
    if [[ "$required" == true ]]; then
      log_error "Required file $relative missing under $source_file"
      exit 1
    fi
    log_info "Skipping $relative; file not found under $source_file"
    return
  fi

  log_info "Installing $target default file..."
  run_cmd mkdir -p "$(dirname "$destination_file")"
  run_cmd cp "$source_file" "$destination_file"
}

################################################################################
# SYNC HYPRLAND KEYBOARD LAYOUT
# Synchronizes the Hyprland keyboard layout with the system configuration.
_sync_hypr_keyboard_layout() {
  log_info "Configuring Hyprland keyboard layout..."
  local vconsole_conf="/etc/vconsole.conf"
  local hypr_conf="$HOME/.config/hypr/hyprland.conf"

  if [[ ! -f "$vconsole_conf" || ! -f "$hypr_conf" ]]; then
    log_info "Skipping Hyprland keyboard sync; required files missing."
    return
  fi

  if grep -q '^XKBLAYOUT=' "$vconsole_conf"; then
    local layout
    layout=$(grep '^XKBLAYOUT=' "$vconsole_conf" | cut -d= -f2 | tr -d '"')
    run_cmd sed -i "s/^\(\s*kb_layout =\).*/\1 $layout/" "$hypr_conf"
  fi
}

################################################################################
# HYPRLAND STACK
# Installs Hyprland plus its core helpers (lock, idle, screenshots) and deploys
# the structural compositor configuration.
_install_hyprland_stack() {
  log_info "Installing Hyprland compositor stack..."
  _install_pacman_packages \
    "hyprland" \
    "hyprlock" \
    "hypridle" \
    "swaybg" \
    "xdg-desktop-portal-hyprland" \
    "wl-clipboard" \
    "grim" \
    "slurp" \
    "playerctl" \
    "imv"
  _install_aur_packages "hyprsunset"
  _copy_graphics_dir "hypr" "hypr" true
}

################################################################################
# SESSION MANAGEMENT
# Installs UWSM session descriptors so display managers can launch Hyprland.
_install_session_management() {
  log_info "Installing Wayland session descriptors..."
  _install_pacman_packages "uwsm"
  _copy_graphics_dir "uwsm" "uwsm" true
}

################################################################################
# STATUS BAR
# Provides the Waybar defaults that pair with the Hyprland layout.
_install_waybar_stack() {
  log_info "Deploying Waybar configuration..."
  _install_pacman_packages "waybar"
  _copy_graphics_dir "waybar" "waybar" true
}

################################################################################
# ELEPHANT + WALKER SUITE
# Installs Omarchy-inspired launcher helpers that complement Waybar bindings.
_install_elephant_suite() {
  log_info "Installing Elephant launcher suite..."
  _install_aur_packages \
    "walker-git" \
    "elephant" \
    "elephant-calc" \
    "elephant-clipboard" \
    "elephant-bluetooth" \
    "elephant-desktopapplications" \
    "elephant-files" \
    "elephant-menus" \
    "elephant-providerlist" \
    "elephant-runner" \
    "elephant-symbols" \
    "elephant-todo" \
    "elephant-unicode" \
    "elephant-websearch"
  _copy_graphics_dir "elephant" "elephant" true
  _copy_graphics_dir "walker" "walker" true
}

################################################################################
# NOTIFICATIONS + OSD
# Installs libnotify-compatible daemons (mako + SwayOSD) and their configs.
_install_notifications_stack() {
  log_info "Configuring notifications and on-screen display services..."
  _install_pacman_packages "mako" "swayosd" "libnotify" "brightnessctl"
  _copy_graphics_dir "mako" "mako" true
  _copy_graphics_dir "swayosd"
}

################################################################################
# INPUT METHODS
# Configures fcitx5 (IME, clipboard helpers) along with locale overrides.
_install_input_method_configs() {
  log_info "Deploying input method configuration..."
  _install_pacman_packages "fcitx5" "fcitx5-gtk" "fcitx5-im"
  _copy_graphics_dir "fcitx5" "fcitx5" true
  _copy_graphics_dir "environment.d"
}

################################################################################
# VISUAL ASSETS
# Provides supporting assets like backgrounds and fontconfig overrides.
_install_visual_assets() {
  log_info "Installing visual assets..."
  _copy_graphics_dir "backgrounds" "backgrounds" true
  _copy_graphics_dir "fontconfig"

  local default_background="$ARCHENEMY_USER_CONFIG_DIR/backgrounds/01.png"
  local background_link="$ARCHENEMY_USER_CONFIG_DIR/background"
  if [[ -f "$default_background" ]]; then
    run_cmd ln -sf "$default_background" "$background_link"
  fi
}

################################################################################
# BROWSER DEFAULTS
# Applies Chromium flags/themes that align with the Wayland session.
_configure_browser_defaults() {
  log_info "Configuring Chromium defaults..."
  _install_pacman_packages "chromium"
  _copy_graphics_dir "chromium"
  _copy_graphics_file "chromium-flags.conf"
  _copy_graphics_file "chromium.theme"
  _copy_graphics_file "icons.theme" "icons.theme" true
}

################################################################################
# FONTS
# Installs the font families required by the desktop experience.
_install_fonts() {
  log_info "Installing fonts and refreshing font cache..."
  _install_pacman_packages "ttf-fira-code" "noto-fonts" "noto-fonts-emoji"

  local fonts_dir="$HOME/.local/share/fonts"
  local bundled_font="$ARCHENEMY_DEFAULTS_GRAPHICS_DIR/fonts/fira-code.ttf"
  run_cmd mkdir -p "$fonts_dir"
  if [[ -f "$bundled_font" ]]; then
    run_cmd cp "$bundled_font" "$fonts_dir/"
  fi
  run_cmd fc-cache
}

################################################################################
# ICONS
# Installs bundled application icons into the user's profile.
_install_icons() {
  log_info "Installing application icons..."
  local icons_dir="$HOME/.local/share/icons"
  local defaults_icons_dir="$ARCHENEMY_DEFAULTS_GRAPHICS_DIR/applications/icons"
  run_cmd mkdir -p "$icons_dir"
  if [[ -d "$defaults_icons_dir" ]]; then
    run_cmd cp -r "$defaults_icons_dir/." "$icons_dir/"
  fi
}

################################################################################
# GTK / GNOME
# Applies GTK themes and installs baseline GNOME apps used as fallbacks.
_configure_gtk_gnome_defaults() {
  log_info "Applying GTK/GNOME defaults..."
  _install_pacman_packages "gnome-themes-extra" "nautilus" "gnome-text-editor"
  _install_aur_packages "yaru-icon-theme"

  run_cmd bash -c "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' >/dev/null 2>&1 || true"
  run_cmd bash -c "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 || true"
  run_cmd bash -c "gsettings set org.gnome.desktop.interface icon-theme 'Yaru-blue' >/dev/null 2>&1 || true"
  run_cmd bash -c "sudo gtk-update-icon-cache /usr/share/icons/Yaru >/dev/null 2>&1 || true"
}

################################################################################
# MIME TYPES
# Sets default applications for common file types (MIME types).
#
_configure_mimetypes() {
  log_info "Configuring default applications (MIME types)..."
  run_cmd bash -c "update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true"

  run_cmd bash -c "xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp >/dev/null 2>&1 || true"
  run_cmd bash -c "xdg-mime default org.gnome.Evince.desktop application/pdf >/dev/null 2>&1 || true"
  run_cmd bash -c "xdg-settings set default-web-browser chromium.desktop >/dev/null 2>&1 || true"
  run_cmd bash -c "xdg-mime default chromium.desktop x-scheme-handler/http x-scheme-handler/https >/dev/null 2>&1 || true"
  run_cmd bash -c "xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm >/dev/null 2>&1 || true"
}

################################################################################
# KEYRING
# Creates a default, unlocked keyring. This prevents applications from asking to
# create a new keyring on first launch.
#
_configure_default_keyring() {
  log_info "Configuring default, unlocked keyring..."
  _install_pacman_packages "gnome-keyring" "polkit-gnome"
  local keyring_dir="$HOME/.local/share/keyrings"
  local keyring_file="$keyring_dir/Default_keyring.keyring"
  run_cmd mkdir -p "$keyring_dir"
  run_cmd bash -c "cat <<EOF > \"$keyring_file\"
[keyring]
display-name=Default keyring
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
EOF
"
  run_cmd bash -c "echo 'Default_keyring' > \"$keyring_dir/default\""
}

################################################################################
# RUN
################################################################################

run_setup_graphics() {
  log_info "Starting Step 4: Graphics Environment..."

  _install_hyprland_stack
  _install_session_management
  _install_waybar_stack
  _install_notifications_stack
  _install_input_method_configs
  _install_elephant_suite
  _install_visual_assets
  _configure_browser_defaults
  _sync_hypr_keyboard_layout
  _install_fonts
  _install_icons
  _configure_gtk_gnome_defaults
  _configure_mimetypes
  _configure_default_keyring

  log_success "Step 4: Graphics Environment completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_graphics "$@"
fi
