#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  printf '\n==> %s\n' "$1"
}

require_files() {
  local prefix="$1"
  shift
  for relative in "$@"; do
    if [[ ! -e "$prefix/$relative" ]]; then
      echo "Missing: $prefix/$relative" >&2
      exit 1
    fi
  done
}

run_cmd() {
  printf '+ %s\n' "$*"
  "$@"
}

log "Verifying system defaults"
require_files "installation/defaults/system" \
  "pacman/pacman.conf" \
  "pacman/mirrorlist" \
  "gpg/dirmngr.conf" \
  "sudoers/archenemy-first-run" \
  "power/systemd/user/battery-monitor.service" \
  "power/systemd/user/battery-monitor.timer"
run_cmd bash -n installation/system.sh installation/cleanup.sh
run_cmd shellcheck -x installation/system.sh installation/cleanup.sh

log "Verifying bootloader defaults"
require_files "installation/defaults/bootloader/mkinitcpio" "archenemy_hooks.conf"
require_files "installation/defaults/bootloader/sddm" "autologin.conf" "theme.conf"
require_files "installation/defaults/bootloader/plymouth" \
  "archenemy.plymouth" "archenemy.script" "bullet.png" "entry.png" \
  "lock.png" "logo.png" "progress_bar.png" "progress_box.png"
run_cmd bash -n installation/bootloader.sh installation/bootloader/lib.sh installation/bootloader/plymouth.sh installation/bootloader/sddm.sh installation/bootloader/limine.sh
run_cmd shellcheck -x installation/bootloader.sh installation/bootloader/lib.sh installation/bootloader/plymouth.sh installation/bootloader/sddm.sh installation/bootloader/limine.sh

log "Verifying desktop defaults"
require_files "installation/defaults/desktop" "config" "home"
require_files "installation/defaults/desktop/config/systemd/user" \
  "ae-refresh-hyprland.path" "ae-refresh-hyprland.service" \
  "ae-refresh-walker.path" "ae-refresh-walker.service" \
  "ae-refresh-waybar.path" "ae-refresh-waybar.service"
run_cmd bash -n installation/desktop.sh
run_cmd shellcheck -x installation/desktop.sh

log "Verifying applications defaults"
require_files "installation/defaults/applications" \
  "icons/Basecamp.png" \
  "icons/Discord.png" \
  "icons/WhatsApp.png"
run_cmd bash -n installation/apps.sh
run_cmd shellcheck -x installation/apps.sh

log "Verifying sentinel defaults"
require_files "installation/defaults/sentinel" "postinstall-profile.sh"
run_cmd bash -n installation/commons/sentinel.sh
run_cmd shellcheck -x installation/commons/sentinel.sh

log "Defaults audit complete"
