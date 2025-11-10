#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# REBOOT
################################################################################
#
# Goal: Display the installation completion message, send desktop notifications,
#       and prompt the user to reboot the system. This is the final step of the
#       installation process.
#

################################################################################
# PASSWORDLESS REBOOT
# Creates a temporary sudoers rule that allows the current user to reboot the
# machine without a password. This is for convenience and is removed on the
# next boot.
#
_allow_passwordless_reboot() {
  log_info "Allowing passwordless reboot..."
  local reboot_sudoers="/etc/sudoers.d/99-archenemy-installer-reboot"
  run_cmd bash -c "cat <<EOF | sudo tee '$reboot_sudoers' >/dev/null
$USER ALL=(ALL) NOPASSWD: /usr/bin/reboot
EOF
"
  run_cmd sudo chmod 440 "$reboot_sudoers"
}

################################################################################
# DISPLAY FINISHED MESSAGE
# Displays the final completion message, the archenemy logo, and prompts the
# user to reboot the system to finalize the installation.
#
_display_finished_message() {
  log_info "Displaying finished message..."

  # Display welcome notifications
  _install_pacman_packages "libnotify" # For notify-send
  run_cmd bash -c "notify-send 'Update System' 'When you have internet, click to update the system.' -u critical || true"
  run_cmd bash -c "notify-send 'Learn Keybindings' 'Super + K for cheatsheet.\nSuper + Space for launcher.' -u critical || true"
  if ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
    run_cmd bash -c "notify-send 'Click to Setup Wi-Fi' 'Tab to navigate, Space to select, ? for help.' -u critical -t 30000 || true"
  fi

  # Display logo
  if [ -f "$ARCHENEMY_PATH/logo.txt" ]; then
    cat "$ARCHENEMY_PATH/logo.txt"
  fi
  echo
  log_success "archenemy installation finished!"
  echo
  read -p "Reboot Now? (Y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rebooting system..."
    _display_splash
    run_cmd sudo reboot
  fi
}

################################################################################
# RUN
################################################################################

run_reboot() {
  log_info "Starting Reboot..."

  # --- Sub-step 1: Allow passwordless reboot for the installer ---
  _allow_passwordless_reboot

  # --- Sub-step 2: Display the final 'finished' message and prompt for reboot ---
  _display_finished_message

  log_success "Reboot completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_reboot "$@"
fi
