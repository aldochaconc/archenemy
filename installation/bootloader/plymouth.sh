#!/bin/bash
# Plymouth helper functions. Synchronizes the repository theme and selects it
# as the active boot splash.
# Preconditions: commons + bootloader lib sourced; defaults/bootloader/plymouth
# must be present.
# Postconditions: Plymouth theme installed and configured.

# BOOTLOADER_DIR=bootloader helper directory.
BOOTLOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$BOOTLOADER_DIR/../commons/common.sh"
# shellcheck source=installation/bootloader/lib.sh
source "$BOOTLOADER_DIR/lib.sh"

##################################################################
# ARCHENEMY_BOOTLOADER_CONFIGURE_PLYMOUTH
# Copies the repo theme into /usr/share/plymouth and selects it.
##################################################################
archenemy_bootloader_configure_plymouth() {
  log_info "Configuring Plymouth boot splash..."
  archenemy_bootloader_sync_plymouth_theme
}
