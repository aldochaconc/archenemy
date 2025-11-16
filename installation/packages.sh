#!/bin/bash
# Packages module. Installs repository and AUR bundles up front so every other
# surface can assume dependencies exist. Validates manifest syntax before any
# write operations happen.
# Preconditions: commons must be sourced; manifests live under installation/packages.
# Postconditions: pacman/AUR bundles installed (or dry-run logged) during preinstall.

# MODULE_DIR=absolute path to the installation directory.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

# PACMAN_PACKAGE_FILE=manifest with repo packages (one per line, comments allowed).
PACMAN_PACKAGE_FILE="$MODULE_DIR/packages/pacman.package"
# AUR_PACKAGE_FILE=manifest with AUR packages.
AUR_PACKAGE_FILE="$MODULE_DIR/packages/aur.package"

##################################################################
# RUN_PACKAGES_PREINSTALL
# Installs the global pacman/AUR bundles before any module tries
# to consume packages. Acts as a guard for typos in manifests.
##################################################################
run_packages_preinstall() {
  log_info "Installing pacman bundle..."
  _install_packages_from_manifest "$PACMAN_PACKAGE_FILE" "pacman"
  log_info "Installing AUR bundle..."
  _install_packages_from_manifest "$AUR_PACKAGE_FILE" "aur"
  log_success "Global package bundles installed."
}

##################################################################
# RUN_PACKAGES_POSTINSTALL
# No-op today; future migrations can refresh manifests here if
# needed.
##################################################################
run_packages_postinstall() {
  log_info "Packages module postinstall: nothing to do (already applied)."
}

##################################################################
# RUN_PACKAGES
# Dispatches to the proper phase-specific handler.
##################################################################
run_packages() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_packages_postinstall "$@"
  else
    run_packages_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_packages "$@"
fi
