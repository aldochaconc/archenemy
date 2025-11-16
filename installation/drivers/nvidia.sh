#!/bin/bash
# NVIDIA GPU installer. Chooses between proprietary/open DKMS packages, updates
# mkinitcpio modules (including hybrid Intel/AMD setups), and rebuilds the
# initramfs.
# Preconditions: commons + drivers core sourced; `lspci`, `pacman`, `mkinitcpio`
# available.
# Postconditions: NVIDIA driver stack installed and initramfs updated.

# DRIVERS_DIR=location of drivers helper scripts.
DRIVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$DRIVERS_DIR/../commons/common.sh"
# shellcheck source=installation/drivers/core.sh
source "$DRIVERS_DIR/core.sh"

##################################################################
# ARCHENEMY_INSTALL_NVIDIA_DRIVERS
# Chooses between proprietary vs open drivers, configures required
# modules (including hybrids), and regenerates the initramfs.
##################################################################
archenemy_install_nvidia_drivers() {
  log_info "Checking for NVIDIA GPU..."
  if ! archenemy_drivers_has_gpu "nvidia"; then
    log_info "No NVIDIA GPU detected. Skipping."
    return 0
  fi
  log_info "NVIDIA GPU detected. Installing drivers..."
  local nvidia_driver_package="nvidia-dkms"
  if archenemy_drivers_has_nvidia_open_gpu; then
    nvidia_driver_package="nvidia-open-dkms"
  fi
  local kernel_headers
  kernel_headers="$(archenemy_drivers_get_kernel_headers)"
  local packages_to_install=(
    "$kernel_headers"
    "$nvidia_driver_package"
    "nvidia-utils"
    "lib32-nvidia-utils"
    "egl-wayland"
    "libva-nvidia-driver"
    "qt5-wayland"
    "qt6-wayland"
  )
  _install_pacman_packages "${packages_to_install[@]}"
  run_cmd sudo tee /etc/modprobe.d/nvidia.conf >/dev/null <<<"options nvidia_drm modeset=1"
  local -a kernel_modules=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
  if archenemy_drivers_has_gpu "intel"; then
    kernel_modules=(i915 "${kernel_modules[@]}")
  elif archenemy_drivers_has_gpu "amd"; then
    kernel_modules=(amdgpu "${kernel_modules[@]}")
  fi
  archenemy_drivers_append_mkinitcpio_modules "${kernel_modules[@]}"
  log_info "Regenerating initramfs for NVIDIA..."
  run_cmd sudo mkinitcpio -P
}
