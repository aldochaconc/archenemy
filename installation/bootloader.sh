#!/bin/bash
# Bootloader module entry point. Applies Limine + Plymouth + SDDM configuration
# during preinstall and refreshes assets after the first native boot so UKIs,
# snapshots, and branding stay in sync.
# Preconditions: commons must be sourced; `installation/defaults/bootloader`
# must exist with mkinitcpio hooks, plymouth theme, and SDDM templates.
# Postconditions: Limine default files/conf regenerated, plymouth/sddm assets in
# place, snapper configs created, hooks restored.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

# BOOTLOADER_DIR=directory containing helper scripts.
BOOTLOADER_DIR="$MODULE_DIR/bootloader"
# shellcheck source=installation/bootloader/lib.sh
source "$BOOTLOADER_DIR/lib.sh"
# shellcheck source=installation/bootloader/plymouth.sh
source "$BOOTLOADER_DIR/plymouth.sh"
# shellcheck source=installation/bootloader/sddm.sh
source "$BOOTLOADER_DIR/sddm.sh"
# shellcheck source=installation/bootloader/limine.sh
source "$BOOTLOADER_DIR/limine.sh"

##################################################################
# RUN_BOOTLOADER_PREINSTALL
# Installs the bootloader/display stack early so mkinitcpio hooks
# are restored before driver installation.
##################################################################
run_bootloader_preinstall() {
  log_info "Starting bootloader & display configuration..."
  archenemy_bootloader_configure_plymouth
  archenemy_bootloader_configure_sddm
  archenemy_bootloader_configure_limine_and_snapper
  log_success "Bootloader & display configuration completed."
}

##################################################################
# RUN_BOOTLOADER_POSTINSTALL
# Refreshes SDDM + Limine from the target root after the first
# native boot so UKIs/presets reflect the final environment.
##################################################################
run_bootloader_postinstall() {
  log_info "Refreshing bootloader assets postinstall..."
  archenemy_bootloader_refresh_sddm_postinstall
  archenemy_bootloader_refresh_limine_postinstall
  log_success "Bootloader postinstall refresh completed."
}

run_bootloader() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_bootloader_postinstall "$@"
  else
    run_bootloader_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_bootloader "$@"
fi
