#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
################################################################################
# DAEMONS
################################################################################
#
# Goal: Configure critical system services including firewall (UFW), DNS
#       resolver (systemd-resolved), and power management profiles. This step
#       ensures the system has appropriate security settings and power policies
#       before the first boot.
#

################################################################################
# FIREWALL
# Configures and enables the UFW firewall with a default deny policy and
# specific rules for services like Docker.
_configure_firewall() {
  log_info "Configuring firewall (UFW)..."
  _install_pacman_packages "ufw"
  _install_aur_packages "ufw-docker"

  run_cmd sudo ufw default deny incoming
  run_cmd sudo ufw default allow outgoing
  run_cmd sudo ufw allow 53317/udp
  run_cmd sudo ufw allow 53317/tcp
  run_cmd sudo ufw allow 22/tcp comment 'allow-ssh'
  # Allow Docker DNS
  run_cmd sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  run_cmd sudo ufw --force enable
  _enable_service "ufw"
  run_cmd sudo ufw-docker install
  run_cmd sudo ufw reload
}

################################################################################
# SSH ACCESS
# Installs and enables OpenSSH so the VM harness and remote maintenance can
# connect without requiring a graphical session.
# TODO: add templates for ssh config.
_configure_ssh_access() {
  log_info "Installing and enabling OpenSSH..."
  _install_pacman_packages "openssh"
  run_cmd sudo mkdir -p "$HOME/.ssh"
  run_cmd sudo systemctl enable --now sshd
}

################################################################################
# DNS RESOLVER
# Configures systemd-resolved by creating the correct symlink for /etc/resolv.conf.
_configure_dns_resolver() {
  log_info "Configuring systemd-resolved..."
  run_cmd sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

################################################################################
# POWER MANAGEMENT
# Configures power management settings based on whether the system has a
# battery, setting the profile to 'balanced' for laptops and 'performance'
# for desktops.
_configure_power_management() {
  log_info "Configuring power management..."
  _install_pacman_packages "power-profiles-daemon"

  if ls /sys/class/power_supply/BAT* &>/dev/null; then
    log_info "Battery detected. Setting power profile to 'balanced'."
    if ! run_cmd sudo powerprofilesctl set balanced; then
      log_info "Unable to set balanced profile via powerprofilesctl; continuing."
    fi
  else
    log_info "No battery detected. Setting power profile to 'performance'."
    if ! run_cmd sudo powerprofilesctl set performance; then
      log_info "Unable to set performance profile via powerprofilesctl; continuing."
    fi
  fi

  _deploy_battery_monitor_timer
}

################################################################################
# BATTERY MONITOR
# Deploys the user-level battery monitor timer/service pair so laptops surface
# low-charge notifications even before the desktop session is customized.
#
_deploy_battery_monitor_timer() {
  log_info "Configuring battery monitor user service..."
  local source_dir="$ARCHENEMY_DEFAULTS_DAEMONS_DIR/systemd/user"
  local user_dir="$ARCHENEMY_USER_CONFIG_DIR/systemd/user"
  local service="battery-monitor.service"
  local timer="battery-monitor.timer"

  if [[ ! -f "$source_dir/$service" || ! -f "$source_dir/$timer" ]]; then
    log_info "Battery monitor units not found in $source_dir; skipping."
    return
  fi

  run_cmd mkdir -p "$user_dir"
  run_cmd cp "$source_dir/$service" "$user_dir/"
  run_cmd cp "$source_dir/$timer" "$user_dir/"

  if systemctl --user status >/dev/null 2>&1; then
    run_as_user systemctl --user enable --now "$timer" || log_info "Unable to enable $timer (no active user session?)"
  else
    log_info "User systemd session unavailable; skipping enablement for $timer."
  fi
}

################################################################################
# SYSTEM SERVICES
# Applies structural system service tweaks that should not live in user
# customization steps (e.g., updatedb, faster shutdown timeouts).
#
_configure_system_services() {
  log_info "Applying supplemental system service tweaks..."

  run_cmd sudo updatedb

  run_cmd sudo mkdir -p /etc/systemd/system.conf.d
  run_cmd bash -c "echo -e '[Manager]\nDefaultTimeoutStopSec=5s' | sudo tee /etc/systemd/system.conf.d/10-faster-shutdown.conf >/dev/null"

  run_cmd sudo systemctl daemon-reload
}

################################################################################
# RUN
################################################################################

run_setup_daemons() {
  log_info "Starting Step 6: Daemons..."

  # --- Sub-step 1: Configure system firewall ---
  _configure_firewall

  # --- Sub-step 2: Provision SSH access ---
  _configure_ssh_access

  # --- Sub-step 3: Configure systemd-resolved for DNS ---
  _configure_dns_resolver

  # --- Sub-step 4: Configure power management based on hardware ---
  _configure_power_management

  # --- Sub-step 5: Apply supplemental system service tweaks ---
  _configure_system_services

  log_success "Step 6: Daemons completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_daemons "$@"
fi
