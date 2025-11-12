#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# DRIVERS & HARDWARE CONFIGURATION
################################################################################
#
# Goal: Detect and configure all necessary hardware drivers. This includes
#       networking, peripherals like Bluetooth and printers, and crucially,
#       the GPU drivers. The GPU driver functions are refactored to be robust
#       and clean, handling kernel module updates and initramfs regeneration.
#

################################################################################
# GET KERNEL
# Helper to determine the correct kernel package to install.
# It checks for common custom kernels like 'zen' or 'lts' and defaults to
# the standard 'linux' if none are found.
# Arguments: None.
# Returns: The name of the kernel package (e.g., "linux-zen").
_get_kernel() {
  if pacman -Q linux-zen &>/dev/null; then
    echo "linux-zen"
  elif pacman -Q linux-lts &>/dev/null; then
    echo "linux-lts"
  else
    echo "linux"
  fi
}

################################################################################
# GET KERNEL HEADERS
# Helper to determine the correct kernel headers package to install.
# Arguments: None.
# Returns: The name of the headers package (e.g., "linux-zen-headers").
_get_kernel_headers() {
  if pacman -Q linux-zen &>/dev/null; then
    echo "linux-zen-headers"
  elif pacman -Q linux-lts &>/dev/null; then
    echo "linux-lts-headers"
  else
    echo "linux-headers"
  fi
}

################################################################################
# GPU CHECKS
# Helper to check if a GPU from a specific vendor is present in the system.
# Arguments: $1: The vendor to check for (e.g., "intel", "amd", "nvidia").
# Returns: 0 if the GPU is found, 1 otherwise.
_has_gpu() {
  lspci | grep -iE 'vga|3d|display' | grep -qi "$1"
}

################################################################################
# NVIDIA OPEN GPU CHECK
# Helper to check if a newer NVIDIA GPU is present that supports open-source drivers.
# This specifically looks for RTX 20 series and newer, and GTX 16 series.
# Arguments: None.
# Returns: 0 if a supported GPU is found, 1 otherwise.
_has_nvidia_open_gpu() {
  lspci | grep -i 'nvidia' | grep -q -E "RTX [2-9][0-9]|GTX 16"
}

################################################################################
# NETWORKING
# Enables core networking services and applies necessary workarounds to ensure
# a stable network connection on boot.
_setup_networking() {
  log_info "Configuring networking services..."
  _install_pacman_packages "iwd" "wireless-regdb" "nss-mdns"

  ################################################################################
  # Enable iwd service for wireless networking
  _enable_service "iwd.service"

  ################################################################################
  # Prevent boot delays caused by systemd-networkd-wait-online
  run_cmd sudo systemctl disable systemd-networkd-wait-online.service
  run_cmd sudo systemctl mask systemd-networkd-wait-online.service

  ################################################################################
  # Set wireless regulatory domain based on timezone for optimal performance
  local country_code=""
  if command -v curl >/dev/null 2>&1; then
    country_code=$(curl -fs --max-time 3 ipinfo.io/country || true)
  fi
  if [[ -n "$country_code" ]]; then
    log_info "Setting wireless regulatory domain to $country_code"
    run_cmd bash -c "echo 'WIRELESS_REGDOM=\"$country_code\"' | sudo tee /etc/conf.d/wireless-regdom >/dev/null"
    run_cmd sudo iw reg set "$country_code"
  else
    log_info "Unable to detect wireless regulatory domain (ipinfo query skipped or failed)."
  fi

}

################################################################################
# PERIPHERALS
# Configures common peripherals like Bluetooth, printers (CUPS), and disables
# USB autosuspend to prevent issues with mice and keyboards.
_setup_peripherals() {
  log_info "Configuring peripherals (Bluetooth, Printers, USB)..."
  _install_pacman_packages "bluez" "bluez-utils" "cups" "avahi"

  ################################################################################
  # Enable Bluetooth support
  _enable_service "bluetooth.service"

  ################################################################################
  # Enable printing support
  _enable_service "cups.service"
  _enable_service "avahi-daemon.service"

  ################################################################################
  # Disable USB autosuspend
  log_info "Disabling USB autosuspend to prevent issues with mice and keyboards..."
  run_cmd bash -c "echo 'options usbcore autosuspend=-1' | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf >/dev/null"
}

################################################################################
# INTEL
# Detects and installs the appropriate video acceleration drivers for
# Intel integrated GPUs.
_install_intel_drivers() {
  log_info "Checking for Intel GPU..."
  if _has_gpu "intel"; then
    log_info "Intel GPU detected. Installing drivers..."
    _install_pacman_packages "intel-media-driver" "libva-intel-driver"
  else
    log_info "No Intel GPU detected. Skipping."
  fi
}

################################################################################
# AMD
# Detects and installs drivers for AMD GPUs. This function handles both
# dedicated and integrated (APU) graphics, installing the necessary Mesa
# stack, Vulkan drivers, and kernel modules. It also regenerates the
# initramfs to ensure modules are loaded at boot.
_install_amd_drivers() {
  log_info "Checking for AMD GPU..."
  ################################################################################
  # Check if AMD GPU is present
  if ! _has_gpu "amd"; then
    log_info "No AMD GPU detected. Skipping."
    return 0
  fi

  ################################################################################
  # Install AMD GPU drivers
  log_info "AMD GPU detected. Installing drivers..."
  local kernel_headers
  kernel_headers=$(_get_kernel_headers)

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

  log_info "Configuring AMD kernel modules..."
  run_cmd bash -c "echo 'options amdgpu modeset=1' | sudo tee /etc/modprobe.d/amdgpu.conf >/dev/null"

  ################################################################################
  # Add amdgpu to mkinitcpio modules
  run_cmd sudo sed -i -E "s/^(MODULES=\\()/\\1amdgpu /" /etc/mkinitcpio.conf
  run_cmd sudo sed -i -E 's/  +/ /g' /etc/mkinitcpio.conf

  ################################################################################
  # Regenerate initramfs for AMD
  log_info "Regenerating initramfs for AMD..."
  run_cmd sudo mkinitcpio -P
}

################################################################################
# NVIDIA
# Detects and installs drivers for NVIDIA GPUs. This function selects the
# appropriate driver (open-source vs. proprietary), configures kernel modules
# for early KMS, and regenerates the initramfs. It correctly handles hybrid
# GPU setups by ensuring iGPU modules are loaded first.
_install_nvidia_drivers() {
  ################################################################################
  # Check if NVIDIA GPU is present
  log_info "Checking for NVIDIA GPU..."
  if ! _has_gpu "nvidia"; then
    log_info "No NVIDIA GPU detected. Skipping."
    return 0
  fi

  ################################################################################
  # Install NVIDIA GPU drivers
  log_info "NVIDIA GPU detected. Installing drivers..."
  local nvidia_driver_package="nvidia-dkms"
  if _has_nvidia_open_gpu; then
    nvidia_driver_package="nvidia-open-dkms"
  fi

  local kernel_headers
  kernel_headers=$(_get_kernel_headers)

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

  ################################################################################
  # Configure NVIDIA kernel modules
  log_info "Configuring NVIDIA kernel modules..."
  run_cmd bash -c "echo 'options nvidia_drm modeset=1' | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null"

  local nvidia_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
  local hybrid_modules=""
  if _has_gpu "intel"; then
    hybrid_modules="i915 "
  elif _has_gpu "amd"; then
    hybrid_modules="amdgpu "
  fi

  ################################################################################
  # Add modules to mkinitcpio, ensuring hybrid modules come first
  run_cmd sudo sed -i -E "s/^(MODULES=\\()/\\1${hybrid_modules}${nvidia_modules} /" /etc/mkinitcpio.conf
  run_cmd sudo sed -i -E 's/  +/ /g' /etc/mkinitcpio.conf

  ################################################################################
  # Regenerate initramfs for NVIDIA
  log_info "Regenerating initramfs for NVIDIA..."
  run_cmd sudo mkinitcpio -P
}

################################################################################
# RUN
################################################################################

run_setup_drivers() {
  parse_cli_args "$@"

  log_info "Starting Step 3: Drivers & Hardware..."

  # --- 1. Setup networking services ---
  _setup_networking

  # --- 2. Setup peripheral drivers and services ---
  _setup_peripherals

  # --- 3. Install Intel GPU drivers ---
  _install_intel_drivers

  # --- 4. Install AMD GPU drivers ---
  _install_amd_drivers

  # --- 5. Install NVIDIA GPU drivers ---
  _install_nvidia_drivers

  log_success "Step 3: Drivers & Hardware completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_drivers "$@"
fi
