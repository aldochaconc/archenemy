#!/bin/bash
# archenemy installer orchestrator. install.sh clones the repo and calls this
# entrypoint from inside installation/.

# --- Strict Mode and Error Handling ---
#
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if no command exited
#              with a non-zero status.
set -euo pipefail

BOOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BOOT_DIR"

# shellcheck source=installation/commons/common.sh
source "./commons/common.sh"
# shellcheck source=installation/system.sh
source "./system.sh"
# shellcheck source=installation/packages.sh
source "./packages.sh"
# shellcheck source=installation/bootloader.sh
source "./bootloader.sh"
# shellcheck source=installation/drivers.sh
source "./drivers.sh"
# shellcheck source=installation/desktop.sh
source "./desktop.sh"
# shellcheck source=installation/apps.sh
source "./apps.sh"
# shellcheck source=installation/cleanup.sh
source "./cleanup.sh"
# shellcheck source=installation/reboot.sh
source "./reboot.sh"

parse_cli_args "$@"
ensure_install_log_file "$ARCHENEMY_INSTALL_LOG_FILE"
archenemy_initialize_phase

# main bootstraps the flow (phase detection, module sequencing, sentinel).
main() {
  log_info "archenemy installer orchestrator starting (phase: $ARCHENEMY_PHASE)..."
  _require_online_install
  setup_error_trap

  if [[ "$ARCHENEMY_PHASE" == "preinstall" ]]; then
    run_system
    run_packages
    run_bootloader
    run_drivers
    run_desktop
    run_apps
    display_phase1_completion_message
    if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
      log_info "Phase 1 completed inside chroot; registering postinstall sentinel."
      archenemy_register_sentinel
    else
      log_info "Already running on installed system; skipping sentinel registration."
    fi
  else
    run_system
    run_bootloader
    run_desktop
    run_apps
    run_packages
    run_cleanup
    run_reboot
    archenemy_remove_sentinel || true
  fi

  log_success "archenemy installation completed."
}

main "$@"
