#!/bin/bash
# Reboot module. Displays completion banners, sends notifications, and prompts
# for a reboot while granting temporary passwordless rights for the reboot
# command.
# Preconditions: commons sourced; notify-send available (best effort); network
# check uses ping.
# Postconditions: optional reboot triggered; temporary sudoer file created.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

##################################################################
# ALLOW_PASSWORDLESS_REBOOT
# Temporarily grants the invoking user passwordless reboot rights so
# the final prompt can reboot without re-authenticating.
##################################################################
_allow_passwordless_reboot() {
  log_info "Allowing passwordless reboot..."
  local reboot_sudoers="/etc/sudoers.d/99-archenemy-installer-reboot"
  run_cmd sudo tee "$reboot_sudoers" >/dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/reboot
EOF
  run_cmd sudo chmod 440 "$reboot_sudoers"
}

##################################################################
# DISPLAY_FINISHED_MESSAGE
# Shows the completion banner, surfaces helper notifications, and
# prompts the operator to reboot.
##################################################################
_display_finished_message() {
  log_info "Displaying finished message..."
  run_cmd notify-send 'Update System' 'When you have internet, click to update the system.' -u critical || true
  run_cmd notify-send 'Learn Keybindings' $'Super + K for cheatsheet.\nSuper + Space for launcher.' -u critical || true
  if ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
    run_cmd notify-send 'Click to Setup Wi-Fi' 'Tab to navigate, Space to select, ? for help.' -u critical -t 30000 || true
  fi

  if [[ -f "$ARCHENEMY_PATH/logo.txt" ]]; then
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

run_reboot_preinstall() {
  log_info "Reboot module skipped during preinstall."
}

run_reboot_postinstall() {
  log_info "Starting reboot prompt..."
  _allow_passwordless_reboot
  _display_finished_message
  log_success "Reboot prompt completed."
}

run_reboot() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_reboot_postinstall "$@"
  else
    run_reboot_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_reboot "$@"
fi
