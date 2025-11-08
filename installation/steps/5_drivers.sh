#!/bin/bash
################################################################################
# STEP 5: DRIVERS & HARDWARE
################################################################################
#
# Goal: Detect and configure all necessary hardware drivers. This includes
#       networking, peripherals like Bluetooth and printers, and crucially,
#       the GPU drivers. The GPU driver functions are refactored to be robust
#       and clean, handling kernel module updates and initramfs regeneration.
#
run_step_5_drivers_and_hardware() {
  log_info "Starting Step 5: Drivers & Hardware..."

  # --- Sub-step 5.1: Setup networking services ---
  _setup_networking

  # --- Sub-step 5.2: Setup peripheral drivers and services ---
  _setup_peripherals

  # --- Sub-step 5.3: Install Intel GPU drivers ---
  _install_intel_drivers

  # --- Sub-step 5.4: Install AMD GPU drivers ---
  _install_amd_drivers

  # --- Sub-step 5.5: Install NVIDIA GPU drivers ---
  _install_nvidia_drivers

  log_success "Step 5: Drivers & Hardware completed."
}

#
# Enables core networking services and applies necessary workarounds to ensure
# a stable network connection on boot.
#
_setup_networking() {
  log_info "Configuring networking services..."
  _install_pacman_packages "iwd" "wireless-regdb" "nss-mdns"
  # Enable iwd service for wireless networking
  _enable_service "iwd.service"

  # Prevent boot delays caused by systemd-networkd-wait-online
  sudo systemctl disable systemd-networkd-wait-online.service
  sudo systemctl mask systemd-networkd-wait-online.service

  # Set wireless regulatory domain based on timezone for optimal performance
  # (Simplified from original script for clarity)
  local country_code
  country_code=$(curl -s ipinfo.io/country)
  if [[ -n "$country_code" ]]; then
    log_info "Setting wireless regulatory domain to $country_code"
    echo "WIRELESS_REGDOM=\"$country_code\"" | sudo tee /etc/conf.d/wireless-regdom >/dev/null
    sudo iw reg set "$country_code"
  fi
}

#
# Configures common peripherals like Bluetooth, printers (CUPS), and disables
# USB autosuspend to prevent issues with mice and keyboards.
#
_setup_peripherals() {
  log_info "Configuring peripherals (Bluetooth, Printers, USB)..."
  _install_pacman_packages "bluez" "bluez-utils" "cups" "avahi"
  # Enable Bluetooth service
  _enable_service "bluetooth.service"

  # Enable CUPS for printing
  _enable_service "cups.service"
  _enable_service "avahi-daemon.service" # For network printer discovery
  _enable_service "cups-browsed.service"

  # Disable USB autosuspend
  echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
}

#
# Detects and installs the appropriate video acceleration drivers for
# Intel integrated GPUs.
#
_install_intel_drivers() {
  log_info "Checking for Intel GPU..."
  if _has_gpu "intel"; then
    log_info "Intel GPU detected. Installing drivers..."
    _install_pacman_packages "intel-media-driver" "libva-intel-driver"
  else
    log_info "No Intel GPU detected. Skipping."
  fi
}

#
# Detects and installs drivers for AMD GPUs. This function handles both
# dedicated and integrated (APU) graphics, installing the necessary Mesa
# stack, Vulkan drivers, and kernel modules. It also regenerates the
# initramfs to ensure modules are loaded at boot.
#
_install_amd_drivers() {
  log_info "Checking for AMD GPU..."
  if ! _has_gpu "amd"; then
    log_info "No AMD GPU detected. Skipping."
    return 0
  fi

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
  echo "options amdgpu modeset=1" | sudo tee /etc/modprobe.d/amdgpu.conf >/dev/null

  # Add amdgpu to mkinitcpio modules
  sudo sed -i -E "s/^(MODULES=\\()/\\1amdgpu /" /etc/mkinitcpio.conf
  sudo sed -i -E 's/  +/ /g' /etc/mkinitcpio.conf

  log_info "Regenerating initramfs for AMD..."
  sudo mkinitcpio -P
}

#
# Detects and installs drivers for NVIDIA GPUs. This function selects the
# appropriate driver (open-source vs. proprietary), configures kernel modules
# for early KMS, and regenerates the initramfs. It correctly handles hybrid
# GPU setups by ensuring iGPU modules are loaded first.
#
_install_nvidia_drivers() {
  log_info "Checking for NVIDIA GPU..."
  if ! _has_gpu "nvidia"; then
    log_info "No NVIDIA GPU detected. Skipping."
    return 0
  fi

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

  log_info "Configuring NVIDIA kernel modules..."
  echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf >/dev/null

  local nvidia_modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
  local hybrid_modules=""
  if _has_gpu "intel"; then
    hybrid_modules="i915 "
  elif _has_gpu "amd"; then
    hybrid_modules="amdgpu "
  fi

  # Add modules to mkinitcpio, ensuring hybrid modules come first
  sudo sed -i -E "s/^(MODULES=\\()/\\1${hybrid_modules}${nvidia_modules} /" /etc/mkinitcpio.conf
  sudo sed -i -E 's/  +/ /g' /etc/mkinitcpio.conf

  log_info "Regenerating initramfs for NVIDIA..."
  sudo mkinitcpio -P
}
