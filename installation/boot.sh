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
# The installation is divided into 10 sequential steps:
#   1. Bootstrap: Display splash screen and load helpers
#   2. Dotfiles Setup: Create dotfiles directory structure
#   3. System Preparation: Configure pacman, GPG, sudo, install AUR helper
#   4. Bootloader & Display: Configure Limine, Plymouth, SDDM
#   5. Drivers & Hardware: Install networking, peripherals, GPU drivers
#   6. Desktop Software: Install fonts, icons, applications, TUIs, webapps
#   7. User Configuration: Apply dotfiles, themes, Git settings, MIME types
#   8. Services Configuration: Configure firewall, DNS, power management
#   9. Cleanup: Remove temporary files and restore default configurations
#  10. Reboot: Display completion message and prompt for reboot
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

# --- Global Environment Variables ---
#
# These variables define the core paths and settings for the installer. They are
# centralized here to ensure consistency throughout the installation process.
# All variables are exported to make them available to sourced step scripts.
#
export ARCHENEMY_ONLINE_INSTALL=true
export ARCHENEMY_PATH="$HOME/.config/archenemy"
export ARCHENEMY_INSTALL_LOG_FILE="/var/log/archenemy-install.log"
export ARCHENEMY_CHROOT_INSTALL=true
export PATH="$ARCHENEMY_PATH/bin:$PATH"
export CUSTOM_REPO="${CUSTOM_REPO:-aldochaconc/archenemy}"
export CUSTOM_REF="${CUSTOM_REF:-main}"
export ARCHENEMY_USER_NAME="${ARCHENEMY_USER_NAME:-}"
export ARCHENEMY_USER_EMAIL="${ARCHENEMY_USER_EMAIL:-}"

# --- Logging Primitives ---
#
# These functions provide consistent, colorized logging throughout the installer.
# They are defined here in boot.sh to ensure they are available before any step
# scripts are sourced.
#

#
# Generic logging function.
#
# Arguments:
#   $1: The log level (e.g., "INFO", "SUCCESS", "ERROR").
#   $2: The message to log.
#
__archenemy__print_log() {
  local level="$1"
  local message="$2"
  local color_code

  case "$level" in
  INFO) color_code="\e[34m" ;;    # Blue
  SUCCESS) color_code="\e[32m" ;; # Green
  ERROR) color_code="\e[31m" ;;   # Red
  *) color_code="\e[0m" ;;        # Default
  esac

  printf "${color_code}[%s] %s\e[0m\n" "$level" "$message"
}

#
# Logs an informational message.
#
# Arguments:
#   $1: The message to log.
#
log_info() {
  __archenemy__print_log "INFO" "$1"
}

#
# Logs a success message.
#
# Arguments:
#   $1: The message to log.
#
log_success() {
  __archenemy__print_log "SUCCESS" "$1"
}

#
# Logs an error message to stderr.
#
# Arguments:
#   $1: The message to log.
#
log_error() {
  __archenemy__print_log "ERROR" "$1" >&2
}

# --- Error Handler ---
#
# This function is triggered by the trap command on any script error.
#

#
# Centralized error handler. This function is triggered by the 'trap' command
# on any script error.
#
# Arguments:
#   $1: The line number where the error occurred.
#   $2: The exit code of the failed command.
#
_handle_error() {
  local line_number="$1"
  local exit_code="$2"

  log_error "An error occurred on line $line_number (exit code: $exit_code)."
  log_error "Installation cannot continue. Please check the log file for details:"
  log_error "$ARCHENEMY_INSTALL_LOG_FILE"
  exit "$exit_code"
}

#
# Sets a trap to call the error handler function whenever a command fails.
# The `ERR` signal is triggered by `set -e`.
#
trap '_handle_error $LINENO $?' ERR

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

  # Source and execute each installation step in sequence.
  # Shellcheck can follow these paths because boot.sh is executed from within
  # the cloned repository.

  # Step 1: Bootstrap - Display splash and load helpers
  # shellcheck source=steps/1_bootstrap.sh
  source "steps/1_bootstrap.sh"
  run_step_1_bootstrap

  # Step 2: Dotfiles Setup - Create dotfiles directory structure
  # shellcheck source=steps/2_dotfiles.sh
  source "steps/2_dotfiles.sh"
  run_step_2_setup_dotfiles

  # Step 3: System Preparation - Configure pacman, GPG, sudo, AUR helper
  # shellcheck source=steps/3_system_prep.sh
  source "steps/3_system_prep.sh"
  run_step_3_prepare_system

  # Step 4: Bootloader & Display - Configure Limine, Plymouth, SDDM
  # shellcheck source=steps/4_bootloader.sh
  source "steps/4_bootloader.sh"
  run_step_4_configure_bootloader

  # Step 5: Drivers & Hardware - Install networking, peripherals, GPU drivers
  # shellcheck source=steps/5_drivers.sh
  source "steps/5_drivers.sh"
  run_step_5_drivers_and_hardware

  # Step 6: Desktop Software - Install fonts, icons, apps, TUIs, webapps
  # shellcheck source=steps/6_software.sh
  source "steps/6_software.sh"
  run_step_6_install_software

  # Step 7: User Configuration - Apply dotfiles, themes, settings
  # shellcheck source=steps/7_user_config.sh
  source "steps/7_user_config.sh"
  run_step_7_apply_user_config

  # Step 8: Services Configuration - Configure firewall, DNS, power management
  # shellcheck source=steps/8_services.sh
  source "steps/8_services.sh"
  run_step_8_configure_services

  # Step 9: Cleanup - Remove temporary files and restore defaults
  # shellcheck source=steps/9_cleanup.sh
  source "steps/9_cleanup.sh"
  run_step_9_cleanup

  # Step 10: Reboot - Display completion message and prompt for reboot
  # shellcheck source=steps/10_reboot.sh
  source "steps/10_reboot.sh"
  run_step_10_reboot

  log_success "archenemy installation completed."
}

# --- Script Entry Point ---
main "$@"
