#!/bin/bash
# ################################################################################
# archenemy Installer Orchestrator
# ################################################################################
#
# This script orchestrates the archenemy installation process. It is executed by
# install.sh after the repository has been cloned.
#
# Responsibilities:
#   - Define and export global environment variables
#   - Set up error handling and logging primitives
#   - Source and execute each installation step in sequence
#
# The installation is divided into 8 sequential steps:
#   1. System Preparation: Configure pacman, GPG, sudo, install AUR helper
#   2. Bootloader & Display: Configure Limine, Plymouth, SDDM
#   3. Drivers & Hardware: Install networking, peripherals, GPU drivers
#   4. Graphics Environment: Install Hyprland stack, fonts, GTK, keyring
#   5. Dotfiles & Application Launchers: Apply ~/.config dotfiles and scaffolding
#   6. Services Configuration: Configure firewall, DNS, power management
#   7. Cleanup: Remove temporary files and restore default configurations
#   8. Reboot: Display completion message and prompt for reboot
#
# ################################################################################

# --- Strict Mode and Error Handling ---
#
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if no command exited
#              with a non-zero status.
set -euo pipefail

# Ensure all relative paths resolve from the installation directory.
BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BOOT_DIR"

# --- Global Environment Variables ---
#
# These variables define the core paths and settings for the installer. They are
# centralized here to ensure consistency throughout the installation process.
# All variables are exported to make them available to sourced step scripts.
#
export ARCHENEMY_ONLINE_INSTALL=true
: "${ARCHENEMY_PATH:="$HOME/.config/archenemy"}"
export ARCHENEMY_PATH
export ARCHENEMY_INSTALL_LOG_FILE="/var/log/archenemy-install.log"
export ARCHENEMY_CHROOT_INSTALL=true
export PATH="$ARCHENEMY_PATH/bin:$PATH"
export CUSTOM_REPO="${CUSTOM_REPO:-aldochaconc/archenemy}"
export CUSTOM_REF="${CUSTOM_REF:-main}"
export ARCHENEMY_USER_NAME="${ARCHENEMY_USER_NAME:-}"
export ARCHENEMY_USER_EMAIL="${ARCHENEMY_USER_EMAIL:-}"

# shellcheck source=./common.sh
# Ensure log file exists and is writable for the current user.
ensure_log_file() {
  local log_file="$1"
  local log_dir
  log_dir="$(dirname "$log_file")"

  sudo install -d -m 755 "$log_dir"
  if [[ ! -f "$log_file" ]]; then
    sudo touch "$log_file"
  fi
  sudo chown "$USER":"$USER" "$log_file"
  sudo chmod 644 "$log_file"
}

ensure_log_file "$ARCHENEMY_INSTALL_LOG_FILE"

# shellcheck source=./common.sh
source "./common.sh"

################################################################################
# MAIN ORCHESTRATOR
################################################################################
#
# This function is the entry point of the installer. It sources and executes
# each installation step in the correct sequence.
#
# All step files use relative paths from the repository root, allowing shellcheck
# to validate function calls and variable usage across files.
#
main() {
  log_info "archenemy installer orchestrator starting..."
  _require_online_install
  setup_error_trap

  # Source and execute each installation step in sequence.
  # Shellcheck can follow these paths because boot.sh is executed from within
  # the cloned repository.

  # Step 1: System Preparation - Configure pacman, GPG, sudo, AUR helper
  # shellcheck source=./steps/base_system.sh
  source "./steps/base_system.sh"
  run_setup_base_system

  # Step 2: Bootloader & Display - Configure Limine, Plymouth, SDDM
  # shellcheck source=./steps/bootloader.sh
  source "./steps/bootloader.sh"
  run_setup_bootloader

  # Step 3: Drivers & Hardware - Install networking, peripherals, GPU drivers
  # shellcheck source=./steps/drivers.sh
  source "./steps/drivers.sh"
  run_setup_drivers

  # Step 4: Graphics Environment - Install Hyprland stack, GTK, keyring
  # shellcheck source=./steps/graphics.sh
  source "./steps/graphics.sh"
  run_setup_graphics

  # Step 5: Dotfiles - Apply ~/.config dotfiles and Git identity
  # shellcheck source=./steps/dotfiles.sh
  source "./steps/dotfiles.sh"
  run_setup_dotfiles

  # Step 6: Services Configuration - Configure firewall, DNS, power management
  # shellcheck source=./steps/daemons.sh
  source "./steps/daemons.sh"
  run_setup_daemons

  # Step 7: Cleanup - Remove temporary files and restore defaults
  # shellcheck source=./steps/cleanup.sh
  source "./steps/cleanup.sh"
  run_cleanup

  # Step 8: Reboot - Display completion message and prompt for reboot
  # shellcheck source=./steps/reboot.sh
  source "./steps/reboot.sh"
  run_reboot

  log_success "archenemy installation completed."
}

# --- Script Entry Point ---
main "$@"
