#!/bin/bash
# AMD GPU installer. Installs AMDGPU/Mesa stacks, enables DRM modeset, updates
# mkinitcpio modules, and rebuilds the initramfs when AMD hardware exists.
# Preconditions: commons + drivers core sourced; `lspci`, `pacman`, `mkinitcpio`
# available.
# Postconditions: AMD packages installed, mkinitcpio updated, initramfs rebuilt.

# DRIVERS_DIR=location of drivers helper scripts.
DRIVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$DRIVERS_DIR/../commons/common.sh"
# shellcheck source=installation/drivers/core.sh
source "$DRIVERS_DIR/core.sh"

##################################################################
# ARCHENEMY_INSTALL_AMD_DRIVERS
# Installs AMDGPU/mesa bits, enforces DRM modeset, and rebuilds the
# initramfs so amdgpu loads early.
##################################################################
archenemy_install_amd_drivers() {
  log_info "Checking for AMD GPU..."
  if ! archenemy_drivers_has_gpu "amd"; then
    log_info "No AMD GPU detected. Skipping."
    return 0
  fi
  log_info "AMD GPU detected. Installing drivers..."
  local kernel_headers
  kernel_headers="$(archenemy_drivers_get_kernel_headers)"
  local packages_to_install=(
    "$kernel_headers"
    "mesa"
    "xf86-video-amdgpu"
    "libva-mesa-driver"
    "mesa-vdpau"
    "vulkan-radeon"
    "lib32-mesa"
    "lib32-vulkan-radeon"
  )
  _install_pacman_packages "${packages_to_install[@]}"
  run_cmd sudo tee /etc/modprobe.d/amdgpu.conf >/dev/null <<<"options amdgpu modeset=1"
  archenemy_drivers_append_mkinitcpio_modules amdgpu
  log_info "Regenerating initramfs for AMD..."
  run_cmd sudo mkinitcpio -P
}
