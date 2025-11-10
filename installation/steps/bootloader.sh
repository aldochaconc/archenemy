#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# BOOTLOADER & DISPLAY CONFIGURATION
################################################################################
#
# Goal: Configure the bootloader (Limine), boot splash (Plymouth), and the
#       display manager (SDDM) early in the process. Setting up the bootloader
#       here is crucial as it involves re-enabling mkinitcpio hooks, which is
#       necessary before driver and kernel module installations occur.
#

################################################################################
# CONFIGURE PLYMOUTH
# Sets up the Plymouth theme for a graphical boot splash screen. It copies the
# Archenemy theme files and sets it as the default.
#
_configure_plymouth() {
  log_info "Configuring Plymouth boot splash..."
  _install_pacman_packages "plymouth"
  local plymouth_source="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/plymouth"
  local plymouth_target="/usr/share/plymouth/themes/archenemy"

  if [[ ! -d "$plymouth_source" ]]; then
    log_error "Missing Plymouth theme at $plymouth_source. Run Step 1 (Bootstrap) before continuing."
    return 1
  fi

  run_cmd sudo rm -rf "$plymouth_target"
  run_cmd sudo cp -r "$plymouth_source" "$plymouth_target"
  run_cmd sudo plymouth-set-default-theme archenemy
}

################################################################################
# CONFIGURE DESKTOP DISPLAY MANAGER
# Configures the SDDM (Simple Desktop Display Manager) for autologin. It creates
# a configuration file that logs the current user into a Hyprland session
# automatically on boot.
#
_configure_desktop_display_manager() {
  log_info "Configuring SDDM for autologin..."
  _install_pacman_packages "sddm"
  run_cmd sudo install -d -m 755 /etc/sddm.conf.d

  if [ ! -f /etc/sddm.conf.d/autologin.conf ]; then
    local template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/sddm/autologin.conf"
    if [[ ! -f "$template" ]]; then
      log_error "Missing SDDM autologin template at $template"
      exit 1
    fi
    run_cmd sed -e "s|__USER__|$USER|g" "$template" | run_cmd sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
    run_cmd sudo chmod 644 /etc/sddm.conf.d/autologin.conf
  fi
  _enable_service "sddm.service"
}

################################################################################
# CONFIGURE LIMINE AND SNAPPER
# Configures the Limine bootloader, Btrfs snapshot integration with Snapper,
# and re-enables the mkinitcpio hooks. This is a complex but critical step
# that prepares the system for boot-time recovery features.
#
_configure_limine_and_snapper() {
  log_info "Configuring Limine bootloader and Snapper..."
  _install_pacman_packages "limine" "snapper"
  if ! command -v limine &>/dev/null; then
    log_info "Limine bootloader not found. Skipping configuration."
    return 0
  fi

  # Define hooks for mkinitcpio with btrfs overlay support
  local hooks_template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/mkinitcpio/archenemy_hooks.conf"
  if [[ ! -f "$hooks_template" ]]; then
    log_error "Missing mkinitcpio hooks template at $hooks_template"
    return 1
  fi
  run_cmd sudo install -D -m 644 "$hooks_template" /etc/mkinitcpio.conf.d/archenemy_hooks.conf

  # Determine Limine config path (EFI vs BIOS)
  local limine_config
  if [[ -f /boot/EFI/limine/limine.conf ]] || [[ -f /boot/EFI/BOOT/limine.conf ]]; then
    if [[ -f /boot/EFI/BOOT/limine.conf ]]; then
      limine_config="/boot/EFI/BOOT/limine.conf"
    else
      limine_config="/boot/EFI/limine/limine.conf"
    fi
  else
    limine_config="/boot/limine/limine.conf"
  fi

  if [[ ! -f "$limine_config" ]]; then
    log_error "Limine config not found at $limine_config. Cannot proceed."
    return 1
  fi

  # Set up Snapper if not already configured
  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    run_cmd sudo snapper -c root create-config /
  fi
  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    run_cmd sudo snapper -c home create-config /home
  fi

  # Tweak default Snapper configs for better performance
  run_cmd sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

  log_info "Re-enabling mkinitcpio hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"

  if [ -f "${install_hook}.disabled" ]; then
    run_cmd sudo mv "${install_hook}.disabled" "$install_hook"
  fi
  if [ -f "${remove_hook}.disabled" ]; then
    run_cmd sudo mv "${remove_hook}.disabled" "$remove_hook"
  fi

  log_info "Updating Limine configuration..."
  run_cmd sudo limine-update
}

################################################################################
# RUN
################################################################################

run_setup_bootloader() {
  log_info "Starting bootloader & display configuration..."

  # --- 1. Configure Plymouth boot splash ---
  _configure_plymouth

  # --- 2. Configure SDDM display manager ---
  _configure_desktop_display_manager

  # --- 3. Configure Limine bootloader and Snapper ---
  _configure_limine_and_snapper

  log_success "Bootloader & display configuration completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_bootloader "$@"
fi
