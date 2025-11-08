#!/bin/bash
################################################################################
# STEP 7: USER CONFIGURATION
################################################################################
#
# Goal: Apply all user-specific configurations, including dotfiles, themes,
#       branding, and various system tweaks. This step transitions the base
#       system into a fully configured Archenemy desktop environment.
#
run_step_7_apply_user_config() {
  log_info "Starting Step 7: User Configuration..."

  # --- Sub-step 7.1: Apply base dotfile configurations ---
  _apply_base_config

  # --- Sub-step 7.2: Create the core theme directory structure ---
  _create_theme_directory_structure

  # --- Sub-step 7.3: Apply GTK and icon themes ---
  _apply_gtk_theme

  # --- Sub-step 7.4: Apply application-specific themes ---
  _apply_app_specific_themes

  # --- Sub-step 7.5: Apply user-specific preferences ---
  _apply_user_preferences

  # --- Sub-step 7.6: Apply miscellaneous system tweaks ---
  _apply_system_tweaks

  # --- Sub-step 7.7: Set default applications (MIME types) ---
  _apply_mimetypes

  # --- Sub-step 7.8: Set up default keyring for password management ---
  _setup_default_keyring

  # --- Sub-step 7.9: Mark first-run tasks for desktop session ---
  _schedule_first_run_tasks

  log_success "Step 7: User Configuration completed."
}

#
# Copies the base configuration files for various applications (Hyprland,
# Alacritty, etc.) from the Archenemy repository into the user's ~/.config
# directory.
#
_apply_base_config() {
  log_info "Applying base dotfile configurations..."
  # This function now copies the core configuration directories from the
  # user's detached dotfiles directory to the system's .config location.
  mkdir -p "$HOME/.config"
  cp -r "$HOME/.config/dotfiles/hypr" "$HOME/.config/"
  cp -r "$HOME/.config/dotfiles/alacritty" "$HOME/.config/"
  # Copy other core configs as needed...

  cp "$HOME/.config/dotfiles/bashrc" "$HOME/.bashrc"
}

#
# Creates the foundational directory structure for Archenemy's theme management.
# This structure is used by other scripts and applications to determine the
# current theme and assets. By default, it is set to the 'archenemy' theme.
# This is NOT a symlink, but a pointer for other tools to read.
#
_create_theme_directory_structure() {
  log_info "Creating theme directory structure..."
  local theme_dir="$HOME/.config/archenemy/current"
  mkdir -p "$theme_dir"
  # These files act as pointers to the current theme, NOT symlinks to the content.
  echo "$ARCHENEMY_PATH/themes/archenemy" >"$theme_dir/theme_path"
  echo "$ARCHENEMY_PATH/themes/archenemy/backgrounds/01.png" >"$theme_dir/background_path"
}

#
# Applies the default GTK and icon themes for a consistent look and feel across
# graphical applications.
#
_apply_gtk_theme() {
  log_info "Applying GTK and icon themes..."
  _install_pacman_packages "gnome-themes-extra"
  _install_aur_packages "yaru-icon-theme"

  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  gsettings set org.gnome.desktop.interface icon-theme "Yaru-blue"

  sudo gtk-update-icon-cache /usr/share/icons/Yaru
}

#
# Copies theme files for specific applications from the user's dotfiles
# directory to their final configuration locations. This is a COPY, not a
# symlink, to maintain the detached nature of the user's dotfiles.
#
_apply_app_specific_themes() {
  log_info "Applying application-specific themes..."
  # Set theme for btop - copy from dotfiles
  mkdir -p "$HOME/.config/btop/themes"
  cp "$HOME/.config/dotfiles/btop/themes/archenemy.theme" "$HOME/.config/btop/themes/current.theme"

  # Set theme for mako - copy from dotfiles
  mkdir -p "$HOME/.config/mako"
  cp "$HOME/.config/dotfiles/mako/config" "$HOME/.config/mako/config"
}

#
# Configures user-specific settings like Git credentials.
#
_apply_user_preferences() {

  log_info "Applying user preferences (git)..."
  # Configure git
  if [[ -n "${ARCHENEMY_USER_NAME:-}" ]]; then
    git config --global user.name "$ARCHENEMY_USER_NAME"
  fi
  if [[ -n "${ARCHENEMY_USER_EMAIL:-}" ]]; then
    git config --global user.email "$ARCHENEMY_USER_EMAIL"
  fi

  # GPG logic has been moved to STEP 3.
}

#
# Applies a variety of system tweaks for security and usability, such as
# increasing sudo password retries, adjusting keyboard layouts, and fixing
# common system issues.
#
_apply_system_tweaks() {
  log_info "Applying miscellaneous system tweaks..."
  # Increase sudo password tries
  echo "Defaults passwd_tries=10" | sudo tee /etc/sudoers.d/passwd-tries >/dev/null
  sudo chmod 440 /etc/sudoers.d/passwd-tries

  # Detect and apply keyboard layout to Hyprland
  local vconsole_conf="/etc/vconsole.conf"
  local hypr_input_conf="$HOME/.config/hypr/input.conf"
  if [ -f "$vconsole_conf" ] && [ -f "$hypr_input_conf" ]; then
    if grep -q '^XKBLAYOUT=' "$vconsole_conf"; then
      local layout
      layout=$(grep '^XKBLAYOUT=' "$vconsole_conf" | cut -d= -f2 | tr -d '"')
      sed -i "/^ *kb_layout/c\    kb_layout = $layout" "$hypr_input_conf"
    fi
  fi
}

#
# Sets default applications for common file types (MIME types), such as
# setting the default web browser, image viewer, and video player.
#
_apply_mimetypes() {
  log_info "Setting default applications (MIME types)..."
  update-desktop-database ~/.local/share/applications

  # Images
  xdg-mime default imv.desktop image/png image/jpeg image/gif image/webp

  # PDF
  xdg-mime default org.gnome.Evince.desktop application/pdf

  # Web Browser
  xdg-settings set default-web-browser chromium.desktop
  xdg-mime default chromium.desktop x-scheme-handler/http x-scheme-handler/https

  # Video
  xdg-mime default mpv.desktop video/mp4 video/x-matroska video/webm
}

#
# Creates a default, unlocked keyring. This prevents applications from
# repeatedly asking to create a new keyring on first launch.
#
_setup_default_keyring() {
  log_info "Setting up default, unlocked keyring..."
  local keyring_dir="$HOME/.local/share/keyrings"
  mkdir -p "$keyring_dir"
  tee "$keyring_dir/Default_keyring.keyring" >/dev/null <<EOF
[keyring]
display-name=Default keyring
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
EOF
  echo "Default_keyring" >"$keyring_dir/default"
}

#
# Creates the sentinel file that tells the desktop session to run
# first-run tasks (e.g., firewall hardening, DNS fixes, welcome tips)
# exactly once on the first Hyprland login.
#
_schedule_first_run_tasks() {
  log_info "Scheduling desktop first-run tasks..."
  local state_dir="$HOME/.local/state/archenemy"
  mkdir -p "$state_dir"
  touch "$state_dir/first-run.mode"
}
