#!/bin/bash
# Core driver utilities. Provides kernel detection helpers, GPU probes, and
# mkinitcpio manipulation used by vendor-specific installers.
# Preconditions: commons sourced; `pacman`, `lspci`, and `mkinitcpio` available.
# Postconditions: helper callers can detect hardware and update mkinitcpio.

# DRIVERS_MODULE_DIR=location of drivers helper scripts.
DRIVERS_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$DRIVERS_MODULE_DIR/../commons/common.sh"

##################################################################
# ARCHENEMY_DRIVERS_GET_KERNEL
# Detects which kernel package is currently installed so vendor
# modules can pull the matching headers.
##################################################################
archenemy_drivers_get_kernel() {
  if pacman -Q linux-zen &>/dev/null; then
    echo "linux-zen"
  elif pacman -Q linux-lts &>/dev/null; then
    echo "linux-lts"
  else
    echo "linux"
  fi
}

##################################################################
# ARCHENEMY_DRIVERS_GET_KERNEL_HEADERS
# Mirrors the logic above but returns the matching -headers package.
##################################################################
archenemy_drivers_get_kernel_headers() {
  if pacman -Q linux-zen &>/dev/null; then
    echo "linux-zen-headers"
  elif pacman -Q linux-lts &>/dev/null; then
    echo "linux-lts-headers"
  else
    echo "linux-headers"
  fi
}

##################################################################
# ARCHENEMY_DRIVERS_HAS_GPU
# Greps lspci for a vendor string to decide whether a driver stack
# should be installed.
##################################################################
archenemy_drivers_has_gpu() {
  local vendor="$1"
  lspci | grep -iE 'vga|3d|display' | grep -qi "$vendor"
}

##################################################################
# ARCHENEMY_DRIVERS_HAS_NVIDIA_OPEN_GPU
# Detects RTX 20+/GTX16 GPUs that support the open NVIDIA driver.
##################################################################
archenemy_drivers_has_nvidia_open_gpu() {
  lspci | grep -i 'nvidia' | grep -q -E "RTX [2-9][0-9]|GTX 16"
}

##################################################################
# ARCHENEMY_DRIVERS_APPEND_MKINITCPIO_MODULES
# Inserts modules into MODULES=() if they are missing, preserving
# order and avoiding duplicates on repeated runs.
##################################################################
archenemy_drivers_append_mkinitcpio_modules() {
  local -a modules=("$@")
  local -a missing=()
  local module
  for module in "${modules[@]}"; do
    [[ -z "$module" ]] && continue
    if ! grep -Eq "MODULES=.*\\b${module}\\b" /etc/mkinitcpio.conf; then
      missing+=("$module")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    return
  fi
  local prefix
  prefix="${missing[*]} "
  run_cmd sudo sed -i -E "s/^(MODULES=\()/\\1${prefix}/" /etc/mkinitcpio.conf
  run_cmd sudo sed -i -E 's/  +/ /g' /etc/mkinitcpio.conf
}
