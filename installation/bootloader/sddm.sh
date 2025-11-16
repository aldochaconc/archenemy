#!/bin/bash
# SDDM helper functions. Renders autologin config and branding both during
# preinstall and after the first native boot.
# Preconditions: commons + bootloader lib sourced; defaults/bootloader/sddm
# must provide autologin + theme templates.
# Postconditions: `/etc/sddm.conf.d` contains autologin + theme files, faces set.

# BOOTLOADER_DIR=bootloader helper directory.
BOOTLOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$BOOTLOADER_DIR/../commons/common.sh"
# shellcheck source=installation/bootloader/lib.sh
source "$BOOTLOADER_DIR/lib.sh"

##################################################################
# ARCHENEMY_BOOTLOADER_CONFIGURE_SDDM
# Creates /etc/sddm.conf.d/autologin.conf and ensures branding is
# applied during preinstall.
##################################################################
archenemy_bootloader_configure_sddm() {
  log_info "Configuring SDDM autologin + branding..."
  run_cmd sudo install -d -m 755 /etc/sddm.conf.d
  archenemy_bootloader_render_sddm_autologin "${ARCHENEMY_DEFAULT_SESSION:-hyprland-uwsm}"
  archenemy_bootloader_install_sddm_branding
  _enable_service "sddm.service"
}

##################################################################
# ARCHENEMY_BOOTLOADER_REFRESH_SDDM_POSTINSTALL
# Re-renders the autologin config in the native environment so the
# username/session stay up to date.
##################################################################
archenemy_bootloader_refresh_sddm_postinstall() {
  log_info "Refreshing SDDM configuration post-install..."
  archenemy_bootloader_render_sddm_autologin "${ARCHENEMY_DEFAULT_SESSION:-hyprland-uwsm}"
  archenemy_bootloader_install_sddm_branding
}
