#!/bin/bash
################################################################################
# STEP 6: DESKTOP SOFTWARE
################################################################################
#
# Goal: Install all user-facing software, including desktop assets like fonts
#       and icons, core applications, and terminal user interfaces (TUIs). This
#       step also configures essential system daemons like Docker and sets up
#       Zsh as the default shell.
#
run_step_6_install_software() {
  log_info "Starting Step 6: Desktop Software..."

  # --- Sub-step 6.1: Install desktop assets (fonts and icons) ---
  _install_assets

  # --- Sub-step 6.2: Configure Zsh and Oh My Zsh ---
  _configure_zsh

  # --- Sub-step 6.3: Configure system services ---
  _configure_system_services

  # --- Sub-step 6.4: Install and configure TUIs ---
  _install_and_configure_tuis

  # --- Sub-step 6.5: Install and configure Webapps ---
  _install_and_configure_webapps

  # --- Sub-step 6.6: Generate desktop first-run helper ---
  _create_first_run_runner

  log_success "Step 6: Desktop Software completed."
}

#
# Installs custom fonts and application icons for the Archenemy environment.
#
_install_assets() {
  log_info "Installing fonts and icons..."
  _install_pacman_packages "ttf-fira-code" "noto-fonts" "noto-fonts-emoji"
  # Install fonts
  local fonts_dir="$HOME/.local/share/fonts"
  mkdir -p "$fonts_dir"
  cp "$ARCHENEMY_PATH/config/fira-code.ttf" "$fonts_dir/"
  fc-cache

  # Install icons
  local icons_dir="$HOME/.local/share/icons"
  mkdir -p "$icons_dir"
  cp -r "$ARCHENEMY_PATH/applications/icons/." "$icons_dir/"
}

#
# Installs Zsh, sets it as the default shell for the user, and copies the
# Archenemy default Zsh configuration files.
#
_configure_zsh() {
  log_info "Configuring Zsh as the default shell..."
  _install_pacman_packages "zsh" "zsh-completions"
  _install_aur_packages "oh-my-zsh-git"

  rm -rf "$HOME/.oh-my-zsh"
  mkdir -p "$HOME/.config/zsh"
  for zsh_file in "$ARCHENEMY_PATH"/default/zsh/*.zsh; do
    cp "$zsh_file" "$HOME/.config/zsh/"
  done
  cp "$ARCHENEMY_PATH/default/zshrc" "$HOME/.zshrc"
  sudo chsh -s /bin/zsh "$USER"
}

#
# Configures and enables key system services, including Docker, the 'locate'
# database, and settings for a faster shutdown.
#
_configure_system_services() {
  log_info "Configuring system services (Docker, etc.)..."
  _install_pacman_packages "docker"

  # Configure Docker
  _enable_service "docker.service"
  sudo usermod -aG docker "$USER"
  sudo mkdir -p /etc/docker
  sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF

  # Update 'locate' database
  sudo updatedb

  # Configure faster shutdown
  sudo mkdir -p /etc/systemd/system.conf.d
  echo -e "[Manager]\nDefaultTimeoutStopSec=5s" | sudo tee /etc/systemd/system.conf.d/10-faster-shutdown.conf >/dev/null
  sudo systemctl daemon-reload
}

#
# Installs and creates desktop entries for Terminal User Interfaces (TUIs).
# This provides a blueprint for adding TUIs with proper desktop integration.
#
_install_and_configure_tuis() {
  log_info "Installing and configuring TUIs..."
  _install_aur_packages "lazydocker" "lazyjournal"

  _create_desktop_entry "LazyDocker" "lazydocker" "Docker TUI" "utilities"
  _create_desktop_entry "LazyJournal" "lazyjournal" "Journal TUI" "utilities"
}

#
# Creates desktop entries for common web applications, allowing them to be
# launched as if they were native applications.
#
_install_and_configure_webapps() {
  log_info "Creating desktop entries for webapps..."
  _install_pacman_packages "chromium"

  _create_webapp_entry "GitHub" "https://github.com"
  _create_webapp_entry "Discord" "https://discord.com/channels/@me"
}

#
# Emits the helper script that will run the first time Hyprland launches after
# installation, finishing user-session tasks that require a graphical session.
#
_create_first_run_runner() {
  log_info "Creating desktop first-run runner..."
  local runner="$ARCHENEMY_PATH/bin/archenemy-first-run"
  mkdir -p "$(dirname "$runner")"
  tee "$runner" >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail

log() {
  printf '[archenemy-first-run] %s\n' "$1"
}

FLAG="$HOME/.local/state/archenemy/first-run.mode"

if [[ ! -f "$FLAG" ]]; then
  exit 0
fi

rm -f "$FLAG"

configure_power() {
  log "Configuring power profile..."
  if ls /sys/class/power_supply/BAT* &>/dev/null; then
    powerprofilesctl set balanced 2>/dev/null || true
    systemctl --user enable --now omarchy-battery-monitor.timer 2>/dev/null || true
  else
    powerprofilesctl set performance 2>/dev/null || true
  fi
}

cleanup_reboot_sudoers() {
  log "Removing temporary reboot sudo rule..."
  if sudo test -f /etc/sudoers.d/99-archenemy-installer-reboot; then
    sudo rm -f /etc/sudoers.d/99-archenemy-installer-reboot
  fi
}

configure_firewall() {
  log "Applying firewall defaults..."
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 53317/udp
  sudo ufw allow 53317/tcp
  sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  sudo ufw --force enable
  _enable_service "ufw"
  sudo ufw-docker install
  sudo ufw reload
}

configure_dns() {
  log "Linking systemd-resolved stub resolver..."
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

apply_gnome_theme() {
  log "Applying GTK/icon theme..."
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme "Yaru-blue" 2>/dev/null || true
  sudo gtk-update-icon-cache /usr/share/icons/Yaru 2>/dev/null || true
}

send_notifications() {
  log "Sending welcome notifications..."
  notify-send "    Update System" "When you have internet, click to update the system." -u critical || true
  notify-send "    Learn Keybindings" "Super + K for cheatsheet.\nSuper + Space for application launcher.\nSuper + Alt + Space for the Archenemy menu." -u critical || true
}

prompt_wifi() {
  log "Checking connectivity..."
  if ! ping -c3 -W1 1.1.1.1 >/dev/null 2>&1; then
    notify-send "󰖩    Click to Setup Wi-Fi" "Tab to navigate, Space to select, ? for help." -u critical -t 30000 || true
  fi
}

configure_power
cleanup_reboot_sudoers
configure_firewall
configure_dns
apply_gnome_theme
send_notifications
prompt_wifi
EOF
  chmod +x "$runner"
}
