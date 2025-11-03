#!/bin/bash
# ==============================================================================
# AMD Graphics Driver Installation Script
# ==============================================================================
# Automatically detects and configures AMD graphics hardware for Hyprland.
# Handles both dedicated GPUs (Radeon RX/Pro series) and integrated APUs.
#
# Key Features:
# - AMD-specific hardware detection (no false positives on Intel/other vendors)
# - Hybrid graphics compatibility (stable coexistence with NVIDIA)
# - Package selection based on GPU type (full stack for dedicated, minimal for APU)
# - Kernel module configuration for early boot graphics
# - Hyprland environment variables for hardware acceleration
#
# Integration: Called automatically during Omarchy installation via config/all.sh
# ==============================================================================

# Set up environment for Omarchy integration
export OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
export PATH="$OMARCHY_PATH/bin:$PATH"

# --- AMD GPU Detection ---
# Check for AMD dedicated graphics cards (discrete GPUs)
# Matches: AMD Radeon series, RX series, Pro series
AMD_DEDICATED=$(lspci | grep -iE 'vga|3d|display' | grep -i 'amd.*radeon\|amd.*rx\|amd.*pro')

# Check for AMD integrated graphics (APUs) - specific to AMD processors only
# Matches known AMD APU codenames: Renoir, Cezanne, Barcelo, Rembrandt, Phoenix, Raphael
# These are AMD-specific and will not match Intel or other vendors
AMD_INTEGRATED=$(lspci | grep -iE 'vga|3d|display' | grep -i 'amd.*renoir\|amd.*cezanne\|amd.*barcelo\|amd.*rembrandt\|amd.*phoenix\|amd.*raphael')

# Early exit if no AMD graphics hardware detected
if [ -z "$AMD_DEDICATED" ] && [ -z "$AMD_INTEGRATED" ]; then
  echo "No AMD graphics hardware detected. Skipping AMD driver installation."
  exit 0
fi

echo "Detected AMD graphics hardware. Installing drivers for compatibility..."

  # Check which kernel is installed and set appropriate headers package
  KERNEL_HEADERS="linux-headers" # Default
  if pacman -Q linux-zen &>/dev/null; then
    KERNEL_HEADERS="linux-zen-headers"
  elif pacman -Q linux-lts &>/dev/null; then
    KERNEL_HEADERS="linux-lts-headers"
  elif pacman -Q linux-hardened &>/dev/null; then
    KERNEL_HEADERS="linux-hardened-headers"
  fi

  # Base packages for all AMD GPUs
  BASE_PACKAGES=(
    "${KERNEL_HEADERS}"
    "mesa"                       # OpenGL/Vulkan drivers
    "xf86-video-amdgpu"          # X11 driver
    "libva-mesa-driver"          # Hardware video acceleration
    "mesa-vdpau"                 # Video acceleration
  )

  # Package selection based on GPU type
  # Dedicated GPUs need full driver stack including 32-bit libs for gaming/compatibility
  if [ -n "$AMD_DEDICATED" ]; then
    echo "Detected dedicated AMD GPU: installing full driver stack"
    DEDICATED_PACKAGES=(
      "vulkan-radeon"             # Vulkan API support for modern graphics
      "lib32-mesa"                # 32-bit OpenGL support for older games/apps
      "lib32-vulkan-radeon"       # 32-bit Vulkan support for Steam/gaming
      "lib32-libva-mesa-driver"   # 32-bit hardware video acceleration
      "lib32-mesa-vdpau"          # 32-bit video decode acceleration
    )
    PACKAGES_TO_INSTALL=("${BASE_PACKAGES[@]}" "${DEDICATED_PACKAGES[@]}")
  else
    echo "Detected integrated AMD GPU (APU): installing lightweight driver stack"
    # APUs typically don't need 32-bit libs as they're usually in laptops/low-power systems
    PACKAGES_TO_INSTALL=("${BASE_PACKAGES[@]}")
  fi

  # Install packages - use omarchy helper if available, fallback to pacman
  if command -v omarchy-pkg-add >/dev/null 2>&1; then
    echo "Using Omarchy package manager..."
    for package in "${PACKAGES_TO_INSTALL[@]}"; do
      omarchy-pkg-add "$package"
    done
  else
    echo "Using direct pacman installation..."
    sudo pacman -S --needed --noconfirm "${PACKAGES_TO_INSTALL[@]}"
  fi

  # Configure modprobe for early KMS
  echo "options amdgpu modeset=1" | sudo tee /etc/modprobe.d/amdgpu.conf >/dev/null

  # Configure kernel module loading for early KMS (Kernel Mode Setting)
  MKINITCPIO_CONF="/etc/mkinitcpio.conf"

  # Check for hybrid graphics setup - NVIDIA script handles module order in hybrid systems
  if grep -q "nvidia" "$MKINITCPIO_CONF" 2>/dev/null; then
    echo "Hybrid NVIDIA+AMD setup detected. NVIDIA script will handle module ordering."
  else
    # Pure AMD setup - we need to configure module loading ourselves
    echo "Pure AMD setup detected. Configuring kernel module loading..."

    # Backup original configuration before making changes
    sudo cp "$MKINITCPIO_CONF" "${MKINITCPIO_CONF}.backup"

    # Remove any existing amdgpu modules to prevent duplicates
    sudo sed -i -E 's/ amdgpu//g;' "$MKINITCPIO_CONF"

    # Add amdgpu module at the start of MODULES array for early loading
    # This ensures AMD graphics are available during boot process
    sudo sed -i -E "s/^(MODULES=\\()/\\1amdgpu /" "$MKINITCPIO_CONF"

    # Clean up any double spaces that might result from the edit
    sudo sed -i -E 's/  +/ /g' "$MKINITCPIO_CONF"

    # Regenerate initramfs with new module configuration
    sudo mkinitcpio -P
  fi

  # Add AMD environment variables to hyprland.conf
  HYPRLAND_CONF="$HOME/.config/hypr/hyprland.conf"
  if [ -f "$HYPRLAND_CONF" ]; then
    # Check if AMD variables already exist to avoid duplicates
    if ! grep -q "LIBVA_DRIVER_NAME,radeonsi" "$HYPRLAND_CONF" 2>/dev/null; then
      cat >>"$HYPRLAND_CONF" <<'EOF'

# AMD graphics environment variables
env = LIBVA_DRIVER_NAME,radeonsi
env = VDPAU_DRIVER,radeonsi
EOF
      echo "Added AMD environment variables to Hyprland configuration"
    else
      echo "AMD environment variables already configured in Hyprland"
    fi
  else
    echo "Hyprland configuration not found. Environment variables will be set on first Hyprland config refresh."
  fi

  echo "AMD graphics driver installation completed successfully."
