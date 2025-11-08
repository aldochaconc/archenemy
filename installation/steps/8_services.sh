#!/bin/bash

################################################################################
# STEP 8: SERVICES CONFIGURATION
################################################################################
#
# Goal: Configure critical system services including firewall (UFW), DNS
#       resolver (systemd-resolved), and power management profiles. This step
#       ensures the system has appropriate security settings and power policies
#       before the first boot.
#
run_step_8_configure_services() {
  log_info "Starting Step 8: Services Configuration..."

  # --- Sub-step 8.1: Configure system firewall ---
  _configure_firewall

  # --- Sub-step 8.2: Configure systemd-resolved for DNS ---
  _configure_dns_resolver

  # --- Sub-step 8.3: Configure power management based on hardware ---
  _configure_power_management

  log_success "Step 8: Services Configuration completed."
}

#
# Configures and enables the UFW firewall with a default deny policy and
# specific rules for services like Docker.
#
_configure_firewall() {
  log_info "Configuring firewall (UFW)..."
  _install_pacman_packages "ufw"
  _install_aur_packages "ufw-docker"

  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 53317/udp
  sudo ufw allow 53317/tcp
  # Allow Docker DNS
  sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  sudo ufw --force enable
  _enable_service "ufw"
  sudo ufw-docker install
  sudo ufw reload
}

#
# Configures systemd-resolved by creating the correct symlink for /etc/resolv.conf.
#
_configure_dns_resolver() {
  log_info "Configuring systemd-resolved..."
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

#
# Configures power management settings based on whether the system has a
# battery, setting the profile to 'balanced' for laptops and 'performance'
# for desktops.
#
_configure_power_management() {
  log_info "Configuring power management..."
  _install_pacman_packages "power-profiles-daemon"

  if ls /sys/class/power_supply/BAT* &>/dev/null; then
    log_info "Battery detected. Setting power profile to 'balanced'."
    powerprofilesctl set balanced || true
    if systemctl --user status >/dev/null 2>&1; then
      systemctl --user enable --now omarchy-battery-monitor.timer || log_info "Unable to enable user battery monitor (systemd --user inactive)."
    else
      log_info "User systemd not active; skipping battery monitor timer enable."
    fi
  else
    log_info "No battery detected. Setting power profile to 'performance'."
    powerprofilesctl set performance || true
  fi
}
