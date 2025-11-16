#!/bin/bash
# Cleanup module. Restores pacman defaults and removes temporary sudo rules
# once the system boots from disk.
# Preconditions: commons sourced; system defaults present under defaults/system.
# Postconditions: pacman config reset, temporary sudoers entries removed.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

##################################################################
# _CLEANUP_PACMAN_DEFAULTS
# Restores pacman.conf/mirrorlist from the system module defaults.
##################################################################
_cleanup_pacman_defaults() {
  log_info "Restoring default pacman configuration..."
  local system_defaults="$ARCHENEMY_DEFAULTS_DIR/system"
  local pacman_conf_path="$system_defaults/pacman/pacman.conf"
  local pacman_mirrorlist_path="$system_defaults/pacman/mirrorlist"

  if [[ ! -f "$pacman_conf_path" || ! -f "$pacman_mirrorlist_path" ]]; then
    log_error "Pacman defaults missing; cannot restore configuration."
    return 1
  fi

  run_cmd sudo install -m 644 "$pacman_conf_path" /etc/pacman.conf
  run_cmd sudo install -m 644 "$pacman_mirrorlist_path" /etc/pacman.d/mirrorlist
}

##################################################################
# _REMOVE_TEMPORARY_SUDO_RULES
# Deletes the one-off sudoers file created during preinstall.
##################################################################
_remove_temporary_sudo_rules() {
  log_info "Cleaning up temporary sudo rules..."
  local sudoers_file="/etc/sudoers.d/archenemy-first-run"
  if run_cmd sudo test -f "$sudoers_file"; then
    run_cmd sudo rm -f "$sudoers_file"
  fi
}

##################################################################
# RUN_CLEANUP_PREINSTALL
# No-op; cleanup runs only after the system boots from disk.
##################################################################
run_cleanup_preinstall() {
  log_info "Cleanup module skipped during preinstall."
}

##################################################################
# RUN_CLEANUP_POSTINSTALL
# Entry point for phase 2 cleanup.
##################################################################
run_cleanup_postinstall() {
  log_info "Starting cleanup..."
  _cleanup_pacman_defaults
  _remove_temporary_sudo_rules
  log_success "Cleanup completed."
}

##################################################################
# RUN_CLEANUP
# Dispatch wrapper.
##################################################################
run_cleanup() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_cleanup_postinstall "$@"
  else
    run_cleanup_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_cleanup "$@"
fi
