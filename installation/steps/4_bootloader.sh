#!/bin/bash
################################################################################
# STEP 4: BOOTLOADER & DISPLAY
################################################################################
#
# Goal: Configure the bootloader (Limine), boot splash (Plymouth), and the
#       display manager (SDDM) early in the process. Setting up the bootloader
#       here is crucial as it involves re-enabling mkinitcpio hooks, which is
#       necessary before driver and kernel module installations occur.
#
run_step_4_configure_bootloader() {
  log_info "Starting Step 4: Bootloader & Display..."

  # --- Sub-step 4.1: Configure Plymouth boot splash ---
  _configure_plymouth

  # --- Sub-step 4.2: Configure SDDM display manager ---
  _configure_sddm

  # --- Sub-step 4.3: Configure Limine bootloader and Snapper ---
  _configure_limine_and_snapper

  log_success "Step 4: Bootloader & Display completed."
}

#
# Sets up the Plymouth theme for a graphical boot splash screen. It copies the
# Archenemy theme files and sets it as the default.
#
_configure_plymouth() {
  log_info "Configuring Plymouth boot splash..."
  _install_pacman_packages "plymouth"
  if [ "$(plymouth-set-default-theme)" != "archenemy" ]; then
    sudo cp -r "$ARCHENEMY_PATH/default/plymouth" /usr/share/plymouth/themes/archenemy
    sudo plymouth-set-default-theme archenemy
  fi
}

#
# Configures the SDDM (Simple Desktop Display Manager) for autologin.
# It creates a configuration file that logs the current user into a Hyprland
# session automatically on boot.
#
_configure_sddm() {
  log_info "Configuring SDDM for autologin..."
  _install_pacman_packages "sddm"
  sudo mkdir -p /etc/sddm.conf.d

  if [ ! -f /etc/sddm.conf.d/autologin.conf ]; then
    sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<EOF
[Autologin]
User=$USER
Session=hyprland
[Theme]
Current=breeze
EOF
  fi
  _enable_service "sddm.service"
}

#
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
  sudo tee /etc/mkinitcpio.conf.d/archenemy_hooks.conf >/dev/null <<EOF
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs-overlayfs)
EOF

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
    sudo snapper -c root create-config /
  fi
  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    sudo snapper -c home create-config /home
  fi

  # Tweak default Snapper configs for better performance
  sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

  log_info "Re-enabling mkinitcpio hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"

  if [ -f "${install_hook}.disabled" ]; then
    sudo mv "${install_hook}.disabled" "$install_hook"
  fi
  if [ -f "${remove_hook}.disabled" ]; then
    sudo mv "${remove_hook}.disabled" "$remove_hook"
  fi

  log_info "Updating Limine configuration..."
  sudo limine-update
}
