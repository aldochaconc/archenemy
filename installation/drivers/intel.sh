#!/bin/bash
# Intel GPU installer. Installs Mesa/VAAPI/Vulkan stacks, configures i915, and
# regenerates initramfs when Intel hardware is detected.
# Preconditions: commons + drivers core sourced; `lspci`, `pacman`, `mkinitcpio`
# available.
# Postconditions: Intel packages installed and initramfs rebuilt if needed.

# DRIVERS_DIR=location of drivers helper scripts.
DRIVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$DRIVERS_DIR/../commons/common.sh"
# shellcheck source=installation/drivers/core.sh
source "$DRIVERS_DIR/core.sh"

##################################################################
# ARCHENEMY_INSTALL_INTEL_DRIVERS
# Installs the Mesa/VAAPI/Vulkan stack for Intel GPUs and ensures
# the initramfs picks up i915 tuning.
##################################################################
archenemy_install_intel_drivers() {
  log_info "Checking for Intel GPU..."
  if ! archenemy_drivers_has_gpu "intel"; then
    log_info "No Intel GPU detected. Skipping."
    return 0
  fi
  log_info "Intel GPU detected. Installing drivers..."
  local packages_to_install=(
    "mesa"
    "libva-intel-driver"
    "intel-media-driver"
    "vulkan-intel"
    "lib32-mesa"
    "lib32-vulkan-intel"
  )
  _install_pacman_packages "${packages_to_install[@]}"
  run_cmd sudo tee /etc/modprobe.d/i915.conf >/dev/null <<<"options i915 enable_fbc=1 enable_psr=1 enable_guc=3"
  log_info "Regenerating initramfs for Intel..."
  run_cmd sudo mkinitcpio -P
}
