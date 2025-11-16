#!/bin/bash
# Drivers module entry point. Detects hardware (GPU/network/peripherals) and
# installs the corresponding packages, configuring mkinitcpio/modules as needed.
# Preconditions: commons sourced; `lspci`, `pacman`, `mkinitcpio`, and `systemctl`
# available in the environment.
# Postconditions: networking services enabled, GPU driver stacks installed, and
# initramfs regenerated when vendor drivers are present.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

# DRIVERS_DIR=directory containing helper scripts.
DRIVERS_DIR="$MODULE_DIR/drivers"
# shellcheck source=installation/drivers/core.sh
source "$DRIVERS_DIR/core.sh"
# shellcheck source=installation/drivers/network.sh
source "$DRIVERS_DIR/network.sh"
# shellcheck source=installation/drivers/intel.sh
source "$DRIVERS_DIR/intel.sh"
# shellcheck source=installation/drivers/amd.sh
source "$DRIVERS_DIR/amd.sh"
# shellcheck source=installation/drivers/nvidia.sh
source "$DRIVERS_DIR/nvidia.sh"

##################################################################
# RUN_DRIVERS_PREINSTALL
# Installs networking/peripheral packages, then dispatches each
# vendor stack so the compositor sees a ready system post reboot.
##################################################################
run_drivers_preinstall() {
  log_info "Starting drivers & hardware configuration..."
  archenemy_drivers_configure_networking
  archenemy_drivers_configure_peripherals
  archenemy_install_intel_drivers
  archenemy_install_amd_drivers
  archenemy_install_nvidia_drivers
  log_success "Drivers & hardware configuration completed."
}

##################################################################
# RUN_DRIVERS_POSTINSTALL
# Placeholder for future driver refresh logic.
##################################################################
run_drivers_postinstall() {
  log_info "Drivers module postinstall: no actions yet."
}

##################################################################
# RUN_DRIVERS
# Dispatches to the right phase handler.
##################################################################
run_drivers() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_drivers_postinstall "$@"
  else
    run_drivers_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_drivers "$@"
fi
