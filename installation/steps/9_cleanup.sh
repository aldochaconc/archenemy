#!/bin/bash
################################################################################
# STEP 9: CLEANUP
################################################################################
#
# Goal: Clean up temporary installer artifacts and restore default system
#       configurations. This step removes temporary sudoers rules and restores
#       the original pacman configuration.
#
run_step_9_cleanup() {
  log_info "Starting Step 9: Cleanup..."

  # --- Sub-step 9.1: Restore original pacman configuration ---
  _run_pacman_cleanup

  # --- Sub-step 9.2: Clean up temporary installer sudo rules ---
  _cleanup_installer_sudo_rules

  log_success "Step 9: Cleanup completed."
}

#
# Restores the default pacman configuration files. This ensures the system
# uses standard repositories after the installation is complete.
#
_run_pacman_cleanup() {
  log_info "Restoring default pacman configuration..."
  sudo cp -f "$ARCHENEMY_PATH/default/pacman/pacman.conf" /etc/pacman.conf
  sudo cp -f "$ARCHENEMY_PATH/default/pacman/mirrorlist" /etc/pacman.d/mirrorlist
}

#
# Removes the temporary sudoers file that was created at the beginning of the
# installation process.
#
_cleanup_installer_sudo_rules() {
  log_info "Cleaning up temporary sudo rules..."
  local sudoers_file="/etc/sudoers.d/archenemy-first-run"
  if sudo test -f "$sudoers_file"; then
    sudo rm -f "$sudoers_file"
  fi
}
