#!/bin/bash
# System module entry point. Coordinates core OS configuration both during the
# live installer ("preinstall") and once the system reboots natively
# ("postinstall"). Ensures pacman/GPG defaults, sudo policy, firewall, power,
# and service hooks match the desired opinionated setup.
# Preconditions: commons must be sourced first; ARCHENEMY_* env vars must point
# to the installation tree. Requires sudo privileges for most steps.
# Postconditions: pacman mirrors, sudo policy, firewall, resolver, and power
# profiles are applied; AUR helper and sentinel services are installed as needed.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"
# SYSTEM_DEFAULTS_DIR=system-level defaults shipped in the repo.
SYSTEM_DEFAULTS_DIR="$ARCHENEMY_DEFAULTS_DIR/system"
# SYSTEM_POWER_UNITS_DIR=location of user-level battery monitor units.
SYSTEM_POWER_UNITS_DIR="$SYSTEM_DEFAULTS_DIR/power/systemd/user"

##################################################################
# _SYSTEM_CONFIGURE_PACMAN
# Applies repo pacman.conf/mirrorlist so future package installs
# use predictable mirrors even inside the live environment.
##################################################################
_system_configure_pacman() {
  log_info "Configuring pacman mirrors and defaults..."
  local pacman_conf_path="$SYSTEM_DEFAULTS_DIR/pacman/pacman.conf"
  local pacman_mirrorlist_path="$SYSTEM_DEFAULTS_DIR/pacman/mirrorlist"
  if [[ ! -f "$pacman_conf_path" || ! -f "$pacman_mirrorlist_path" ]]; then
    log_error "Pacman defaults missing under $SYSTEM_DEFAULTS_DIR/pacman"
    exit 1
  fi
  run_cmd sudo install -m 644 "$pacman_conf_path" /etc/pacman.conf
  run_cmd sudo install -m 644 "$pacman_mirrorlist_path" /etc/pacman.d/mirrorlist
  log_info "Syncing packages with refreshed mirrors..."
  run_cmd sudo pacman -Syyu --noconfirm --disable-download-timeout
}

##################################################################
# _SYSTEM_CONFIGURE_SYSTEM_GPG
# Drops the curated dirmngr.conf so pacman key operations behave in
# constrained lab networks.
##################################################################
_system_configure_system_gpg() {
  log_info "Configuring system GPG defaults..."
  local gpg_conf_path="$SYSTEM_DEFAULTS_DIR/gpg/dirmngr.conf"
  if [[ ! -f "$gpg_conf_path" ]]; then
    log_error "Missing GPG configuration at $gpg_conf_path"
    exit 1
  fi
  run_cmd sudo install -D -m 644 "$gpg_conf_path" /etc/gnupg/dirmngr.conf
}

##################################################################
# _SYSTEM_SETUP_FIRST_RUN_PRIVILEGES
# Renders a temporary sudoers entry that lets the installer perform
# privileged operations without prompting repeatedly.
##################################################################
_system_setup_first_run_privileges() {
  log_info "Rendering temporary sudo privileges..."
  local sudoers_file="/etc/sudoers.d/archenemy-first-run"
  local template="$SYSTEM_DEFAULTS_DIR/sudoers/archenemy-first-run"
  if [[ ! -f "$template" ]]; then
    log_error "Missing sudoers template at $template"
    exit 1
  fi
  run_cmd sed -e "s|__SUDOERS_FILE__|$sudoers_file|g" -e "s|__USER__|$USER|g" "$template" |
    run_cmd sudo tee "$sudoers_file" >/dev/null
  run_cmd sudo chmod 440 "$sudoers_file"
}

##################################################################
# _SYSTEM_CONFIGURE_SUDO_POLICY
# Applies the long-term sudo policy (passwd_tries, etc.) that should
# remain after the installer exits.
##################################################################
_system_configure_sudo_policy() {
  log_info "Applying sudo policy tweaks..."
  local sudoers_file="/etc/sudoers.d/archenemy-passwd-policy"
  run_cmd sudo tee "$sudoers_file" >/dev/null <<<"Defaults passwd_tries=10"
  run_cmd sudo chmod 440 "$sudoers_file"
}

##################################################################
# _SYSTEM_DISABLE_MKINITCPIO_HOOKS
# Prevents repeated mkinitcpio rebuilds while bulk-installing
# packages; later modules re-enable the hooks.
##################################################################
_system_disable_mkinitcpio_hooks() {
  log_info "Temporarily disabling mkinitcpio pacman hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"
  if [[ -f "$install_hook" ]]; then
    run_cmd sudo mv "$install_hook" "${install_hook}.disabled"
  fi
  if [[ -f "$remove_hook" ]]; then
    run_cmd sudo mv "$remove_hook" "${remove_hook}.disabled"
  fi
}

##################################################################
# _SYSTEM_INSTALL_AUR_HELPER
# Bootstraps yay using the detected desktop user so future modules
# can install AUR packages non-interactively.
##################################################################
_system_install_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    log_info "AUR helper already installed; skipping."
    return
  fi
  local aur_user
  aur_user="$(archenemy_get_primary_user)"
  if [[ "$aur_user" == "root" ]]; then
    aur_user="archenemy-aur"
    if ! id -u "$aur_user" >/dev/null 2>&1; then
      log_warn "No non-root desktop user detected. Creating temporary builder '$aur_user' for yay bootstrap..."
      run_cmd sudo useradd --create-home --shell /bin/bash "$aur_user"
    else
      log_warn "Falling back to existing builder account '$aur_user' for yay bootstrap."
    fi
  fi
  log_info "Using user '$aur_user' to bootstrap yay..."
  local repo_dir
  repo_dir="$(mktemp -d /tmp/yay.XXXXXX)"
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo chown "$aur_user":"$aur_user" "$repo_dir"
  fi
  run_cmd sudo pacman -S --noconfirm --needed git base-devel
  local -a aur_user_prefix=(sudo -H -u "$aur_user")
  if [[ "$EUID" -ne 0 ]]; then
    aur_user_prefix=()
  fi
  run_cmd "${aur_user_prefix[@]}" git clone https://aur.archlinux.org/yay.git "$repo_dir"
  pushd "$repo_dir" >/dev/null || exit 1
  run_cmd "${aur_user_prefix[@]}" makepkg -si --noconfirm
  popd >/dev/null || exit 1
  run_cmd sudo rm -rf "$repo_dir"
}

##################################################################
# _SYSTEM_CONFIGURE_FIREWALL
# Applies UFW defaults, opens required ports, and installs the
# ufw-docker bridge so container DNS keeps working.
##################################################################
_system_configure_firewall() {
  log_info "Configuring firewall (UFW)..."
  run_cmd sudo ufw default deny incoming
  run_cmd sudo ufw default allow outgoing
  run_cmd sudo ufw allow 53317/udp
  run_cmd sudo ufw allow 53317/tcp
  run_cmd sudo ufw allow 22/tcp comment 'allow-ssh'
  run_cmd sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
  run_cmd sudo ufw --force enable
  _enable_service "ufw"
  if command -v ufw-docker >/dev/null 2>&1; then
    run_cmd sudo ufw-docker install
  fi
  run_cmd sudo ufw reload
}

##################################################################
# _SYSTEM_CONFIGURE_SSH
# Installs OpenSSH and enables sshd so remote access is available
# before the graphical session starts.
##################################################################
_system_configure_ssh() {
  log_info "Enabling OpenSSH..."
  run_cmd sudo mkdir -p "$HOME/.ssh"
  run_cmd sudo systemctl enable --now sshd
}

##################################################################
# _SYSTEM_CONFIGURE_DNS_RESOLVER
# Symlinks resolv.conf to systemd-resolved's stub to standardize DNS.
##################################################################
_system_configure_dns_resolver() {
  log_info "Configuring systemd-resolved stub resolver..."
  run_cmd sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
}

##################################################################
# _SYSTEM_CONFIGURE_POWER_PROFILES
# Selects balanced/performance via powerprofilesctl based on whether
# a battery is present.
##################################################################
_system_configure_power_profiles() {
  log_info "Configuring power-profiles-daemon..."
  if ls /sys/class/power_supply/BAT* &>/dev/null; then
    log_info "Battery detected. Setting profile to balanced."
    run_cmd sudo powerprofilesctl set balanced || log_info "Unable to set balanced profile; continuing."
  else
    log_info "No battery detected. Setting profile to performance."
    run_cmd sudo powerprofilesctl set performance || log_info "Unable to set performance profile; continuing."
  fi
}

##################################################################
# _SYSTEM_DEPLOY_BATTERY_MONITOR
# Installs the bundled user-level systemd units that emit low-battery
# notifications in laptops.
##################################################################
_system_deploy_battery_monitor() {
  if [[ ! -d "$SYSTEM_POWER_UNITS_DIR" ]]; then
    log_info "No battery monitor systemd units found; skipping."
    return
  fi
  local user_systemd_dir="$ARCHENEMY_USER_CONFIG_DIR/systemd/user"
  run_cmd mkdir -p "$user_systemd_dir"
  local unit
  for unit in battery-monitor.service battery-monitor.timer; do
    if [[ -f "$SYSTEM_POWER_UNITS_DIR/$unit" ]]; then
      run_cmd cp "$SYSTEM_POWER_UNITS_DIR/$unit" "$user_systemd_dir/"
    fi
  done
  if systemctl --user status >/dev/null 2>&1; then
    run_as_user systemctl --user enable --now battery-monitor.timer || log_info "Unable to enable battery-monitor.timer"
  else
    log_info "User systemd session unavailable; enable battery-monitor.timer manually later."
  fi
}

##################################################################
# RUN_SYSTEM_PREINSTALL
# Main entry point during phase 1: applies pacman/gpg/sudo changes,
# disables mkinitcpio hooks, and ensures yay exists.
##################################################################
run_system_preinstall() {
  log_info "Starting system preparation..."
  _system_configure_pacman
  _system_configure_system_gpg
  _system_setup_first_run_privileges
  _system_configure_sudo_policy
  _system_disable_mkinitcpio_hooks
  _system_install_aur_helper
  log_success "System preparation completed."
}

##################################################################
# RUN_SYSTEM_POSTINSTALL
# Runs the security + power configuration once the system boots
# natively.
##################################################################
run_system_postinstall() {
  log_info "System postinstall: applying security + power configuration..."
  _system_configure_sudo_policy
  _system_configure_firewall
  _system_configure_ssh
  _system_configure_dns_resolver
  _system_configure_power_profiles
  _system_deploy_battery_monitor
  log_success "System postinstall completed."
}

##################################################################
# RUN_SYSTEM
# Dispatches to the appropriate phase-specific function.
##################################################################
run_system() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_system_postinstall "$@"
  else
    run_system_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_system "$@"
fi
