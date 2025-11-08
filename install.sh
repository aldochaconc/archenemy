#!/bin/bash
# ################################################################################
# archenemy Installer Bootstrap
# ################################################################################
#
# This minimal script is the entry point for the archenemy installer.
# It is designed to be downloaded and executed via curl.
#
# Responsibilities:
#   1. Install git
#   2. Clone the archenemy repository
#   3. Execute boot.sh from within the cloned repository
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/archenemy/main/install.sh | bash
#
# ################################################################################

set -euo pipefail

# Configuration
CUSTOM_REPO="${CUSTOM_REPO:-aldochaconc/archenemy}"
CUSTOM_REF="${CUSTOM_REF:-main}"
ARCHENEMY_PATH="$HOME/.config/archenemy"

# Logging
log_info() { printf "\e[34m[INFO] %s\e[0m\n" "$1"; }
log_error() { printf "\e[31m[ERROR] %s\e[0m\n" "$1" >&2; }

# Install git
log_info "Installing git..."
sudo pacman -Syu --noconfirm --needed git

# Clone repository
log_info "Cloning archenemy from https://github.com/${CUSTOM_REPO}.git"
rm -rf "$ARCHENEMY_PATH"
git clone "https://github.com/${CUSTOM_REPO}.git" "$ARCHENEMY_PATH" >/dev/null

# Checkout custom ref if specified
if [[ $CUSTOM_REF != "main" ]]; then
  log_info "Checking out branch/ref: $CUSTOM_REF"
  cd "$ARCHENEMY_PATH" || exit 1
  git fetch origin "${CUSTOM_REF}" && git checkout "${CUSTOM_REF}"
  cd - >/dev/null || exit 1
fi

# Execute main installer
log_info "Launching main installer..."
export CUSTOM_REPO
export CUSTOM_REF
bash "$ARCHENEMY_PATH/installation/boot.sh"
