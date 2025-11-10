#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# CLEANUP
################################################################################
#
# Goal: Clean up temporary installer artifacts and restore default system
#       configurations. This step removes temporary sudoers rules and restores
#       the original pacman configuration.
#

################################################################################
# PACMAN CLEANUP
# Restores the default pacman configuration files. This ensures the system
# uses standard repositories after the installation is complete.
#
_run_pacman_cleanup() {
  log_info "Restoring default pacman configuration..."
  local pacman_conf_path="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman/pacman.conf"
  local pacman_mirrorlist_path="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman/mirrorlist"

  if [[ ! -f "$pacman_conf_path" || ! -f "$pacman_mirrorlist_path" ]]; then
    log_error "Pacman defaults missing under $ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman. Cannot restore configuration."
    return 1
  fi

  run_cmd sudo install -m 644 "$pacman_conf_path" /etc/pacman.conf
  run_cmd sudo install -m 644 "$pacman_mirrorlist_path" /etc/pacman.d/mirrorlist
}

################################################################################
# INSTALLER SUDO RULES
# Removes the temporary sudoers file that was created at the beginning of the
# installation process.
#
_cleanup_installer_sudo_rules() {
  log_info "Cleaning up temporary sudo rules..."
  local sudoers_file="/etc/sudoers.d/archenemy-first-run"
  if run_cmd sudo test -f "$sudoers_file"; then
    run_cmd sudo rm -f "$sudoers_file"
  fi
}

################################################################################
# RUN
################################################################################

run_cleanup() {
  log_info "Starting Cleanup..."

  # --- Sub-step 1: Restore original pacman configuration ---
  _run_pacman_cleanup

  # --- Sub-step 2: Clean up temporary installer sudo rules ---
  _cleanup_installer_sudo_rules

  log_success "Cleanup completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_cleanup "$@"
fi
