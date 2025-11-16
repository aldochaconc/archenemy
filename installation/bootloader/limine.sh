#!/bin/bash
# Limine + Snapper helper functions. Installs Limine configuration, restores
# mkinitcpio hooks, and wires snapper services during preinstall; refreshes
# Limine once the system boots natively.
# Preconditions: commons + bootloader lib sourced; Limine binaries installed;
# defaults/bootloader/mkinitcpio available.
# Postconditions: Limine defaults/conf regenerated, snapper configs created.

# BOOTLOADER_DIR=bootloader helper directory.
BOOTLOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$BOOTLOADER_DIR/../commons/common.sh"
# shellcheck source=installation/bootloader/lib.sh
source "$BOOTLOADER_DIR/lib.sh"

##################################################################
# ARCHENEMY_BOOTLOADER_CONFIGURE_LIMINE_AND_SNAPPER
# Sets up Limine, the mkinitcpio hook, and Snapper configs during
# preinstall so later modules can depend on snapshots + UKIs.
##################################################################
archenemy_bootloader_configure_limine_and_snapper() {
  log_info "Configuring Limine bootloader and Snapper integration..."
  if ! command -v limine &>/dev/null; then
    log_error "Limine is not installed; rerun package installation."
    return 1
  fi

  local hooks_template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/mkinitcpio/archenemy_hooks.conf"
  if [[ ! -f "$hooks_template" ]]; then
    log_error "Missing mkinitcpio hooks template at $hooks_template"
    return 1
  fi
  run_cmd sudo install -D -m 644 "$hooks_template" /etc/mkinitcpio.conf.d/archenemy_hooks.conf

  local boot_mode esp_path
  boot_mode="$(archenemy_bootloader_detect_boot_mode)"
  esp_path="$(archenemy_bootloader_find_esp_mountpoint)"
  archenemy_bootloader_write_limine_default_file "$boot_mode" "$esp_path"
  archenemy_bootloader_reset_limine_conf

  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    run_cmd sudo snapper -c root create-config /
  fi
  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    run_cmd sudo snapper -c home create-config /home
  fi

  run_cmd sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

  log_info "Re-enabling mkinitcpio pacman hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"

  if [[ -f "${install_hook}.disabled" ]]; then
    run_cmd sudo mv "${install_hook}.disabled" "$install_hook"
  fi
  if [[ -f "${remove_hook}.disabled" ]]; then
    run_cmd sudo mv "${remove_hook}.disabled" "$remove_hook"
  fi

  log_info "Rebuilding initramfs with restored hooks..."
  run_cmd sudo mkinitcpio -P

  if [[ "$boot_mode" == "bios" ]]; then
    local -a bios_disks
    mapfile -t bios_disks < <(archenemy_bootloader_unique_bios_disks)
    if [[ ${#bios_disks[@]} -gt 0 ]]; then
      log_info "Running limine bios-install for disks: ${bios_disks[*]}"
      local disk
      for disk in "${bios_disks[@]}"; do
        run_cmd sudo limine bios-install "/dev/$disk"
      done
    else
      log_warn "Unable to detect BIOS target disks; limine bios-install skipped."
    fi
  fi

  log_info "Updating Limine configuration..."
  run_cmd sudo limine-update

  _enable_service "limine-snapper-sync.service"
  if [[ "${ARCHENEMY_CHROOT_INSTALL:-false}" == false ]]; then
    run_cmd sudo systemctl start limine-snapper-sync.service
  fi

  local windows_boot="${esp_path}/EFI/Microsoft/Boot/bootmgfw.efi"
  if [[ -f "$windows_boot" ]]; then
    log_info "Detected Windows Boot Manager at $windows_boot; Limine will expose it via FIND_BOOTLOADERS."
  fi
}

##################################################################
# ARCHENEMY_BOOTLOADER_REFRESH_LIMINE_POSTINSTALL
# Re-runs Limine refresh after the system boots natively so the
# kernel command line reflects the final environment.
##################################################################
archenemy_bootloader_refresh_limine_postinstall() {
  log_info "Refreshing Limine configuration from the target root..."
  if ! command -v limine &>/dev/null; then
    log_warn "Limine is not installed; skipping refresh."
    return
  fi
  archenemy_bootloader_refresh_limine_config
}
