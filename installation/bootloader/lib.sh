#!/bin/bash
# Shared bootloader helper library. Provides Limine, Plymouth, and SDDM helper
# functions consumed by the higher-level bootloader scripts.
# Preconditions: commons must be available; defaults must exist relative to
# `installation/defaults/bootloader`.
# Postconditions: helper callers can rely on detection/sanitization utilities.

if [[ "${ARCHENEMY_BOOTLOADER_LIB_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_BOOTLOADER_LIB_SOURCED=true

# LIB_DIR=bootloader helper directory.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# COMMON_SH=path to commons aggregator.
COMMON_SH="$LIB_DIR/../commons/common.sh"

if [[ "${ARCHENEMY_COMMON_SOURCED:-false}" != true ]]; then
  # shellcheck source=installation/commons/common.sh
  source "$COMMON_SH"
fi

##################################################################
# ARCHENEMY_BOOTLOADER_DETECT_BOOT_MODE
# Returns 'efi' when /sys/firmware/efi exists, otherwise 'bios'.
##################################################################
archenemy_bootloader_detect_boot_mode() {
  if [[ -d /sys/firmware/efi ]]; then
    echo "efi"
  else
    echo "bios"
  fi
}

##################################################################
# ARCHENEMY_BOOTLOADER_FIND_ESP_MOUNTPOINT
# Locates a mounted ESP (common mount points) so we can write Limine
# artifacts to the correct path.
##################################################################
archenemy_bootloader_find_esp_mountpoint() {
  local candidates=("/boot/efi" "/efi" "/boot")
  local path
  for path in "${candidates[@]}"; do
    if mountpoint -q "$path"; then
      echo "$path"
      return
    fi
  done
  log_warn "ESP mountpoint not detected; defaulting to /boot."
  echo "/boot"
}

##################################################################
# ARCHENEMY_BOOTLOADER_PARTITION_FROM_MOUNT
# Maps a mountpoint to its block device.
##################################################################
archenemy_bootloader_partition_from_mount() {
  local mount="$1"
  findmnt -n -o SOURCE "$mount" 2>/dev/null || true
}

##################################################################
# ARCHENEMY_BOOTLOADER_UNIQUE_BIOS_DISKS
# Collects unique disks hosting /, /boot, /boot/efi so limine
# bios-install can run on each once.
##################################################################
archenemy_bootloader_unique_bios_disks() {
  declare -A seen=()
  local partitions=()
  partitions+=("$(archenemy_bootloader_partition_from_mount /)")
  partitions+=("$(archenemy_bootloader_partition_from_mount /boot)")
  partitions+=("$(archenemy_bootloader_partition_from_mount /boot/efi)")
  local part disk
  for part in "${partitions[@]}"; do
    [[ -z "$part" ]] && continue
    disk="$(lsblk -no pkname "$part" 2>/dev/null)"
    [[ -z "$disk" ]] && continue
    seen["$disk"]=1
  done
  for disk in "${!seen[@]}"; do
    echo "$disk"
  done
}

##################################################################
# ARCHENEMY_BOOTLOADER_SANITIZE_KERNEL_CMDLINE
# Strips BOOT_IMAGE/initrd entries and collapses whitespace so the
# Limine default file works regardless of archinstall quirks.
##################################################################
archenemy_bootloader_sanitize_kernel_cmdline() {
  local cmdline
  cmdline="$(tr -d '\0' </proc/cmdline 2>/dev/null || true)"
  cmdline="$(echo "$cmdline" | sed -E 's/(^| )BOOT_IMAGE=[^ ]*//g' | sed -E 's/(^| )initrd=[^ ]*//g' | tr -s ' ' | sed 's/^ //;s/ $//')"
  if [[ -z "$cmdline" ]]; then
    cmdline="rw quiet loglevel=3"
  fi
  echo "$cmdline"
}

##################################################################
# ARCHENEMY_BOOTLOADER_WRITE_LIMINE_DEFAULT_FILE
# Generates /etc/default/limine with sane defaults + UKI toggles.
##################################################################
archenemy_bootloader_write_limine_default_file() {
  local boot_mode="$1"
  local esp_path="$2"
  local cmdline
  cmdline="$(archenemy_bootloader_sanitize_kernel_cmdline)"

  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<EOF
TARGET_OS_NAME="Archenemy"
ESP_PATH="$esp_path"
KERNEL_CMDLINE[default]="$cmdline quiet splash"
FIND_BOOTLOADERS=yes
BOOT_ORDER="*, *fallback, Snapshots"
MAX_SNAPSHOT_ENTRIES=5
SNAPSHOT_FORMAT_CHOICE=5
EOF
  if [[ "$boot_mode" == "efi" ]]; then
    cat >>"$tmp" <<'EOF'
ENABLE_UKI=yes
CUSTOM_UKI_NAME="archenemy"
ENABLE_LIMINE_FALLBACK=yes
EOF
  fi
  run_cmd sudo install -D -m 644 "$tmp" /etc/default/limine
  rm -f "$tmp"
}

##################################################################
# ARCHENEMY_BOOTLOADER_RESET_LIMINE_CONF
# Writes a clean /boot/limine.conf so limine-update can populate
# entries deterministically.
##################################################################
archenemy_bootloader_reset_limine_conf() {
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp" <<'EOF'
### Read more at https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md
#timeout: 3
default_entry: 1
interface_branding: Archenemy Bootloader
interface_branding_color: 6
hash_mismatch_panic: no

term_background: 0c0d11
term_palette: 0c0d11;f07078;9ed072;ffd47e;7aa2f7;bb9af7;7dcfff;d7dae0
term_palette_bright: 161821;f07078;9ed072;ffd47e;7aa2f7;bb9af7;7dcfff;f7f8fa
term_foreground: d7dae0
term_foreground_bright: f7f8fa
EOF
  run_cmd sudo install -D -m 644 "$tmp" /boot/limine.conf
  rm -f "$tmp"
}

##################################################################
# ARCHENEMY_BOOTLOADER_SYNC_PLYMOUTH_THEME
# Copies the repo theme into /usr/share/plymouth and selects it via
# plymouth-set-default-theme.
##################################################################
archenemy_bootloader_sync_plymouth_theme() {
  local plymouth_source="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/plymouth"
  local plymouth_target="/usr/share/plymouth/themes/archenemy"

  if [[ ! -d "$plymouth_source" ]]; then
    log_error "Missing Plymouth theme at $plymouth_source. Run Step 1 (Bootstrap) before continuing."
    return 1
  fi

  run_cmd sudo rm -rf "$plymouth_target"
  run_cmd sudo cp -r "$plymouth_source" "$plymouth_target"
  run_cmd sudo plymouth-set-default-theme archenemy
}

##################################################################
# ARCHENEMY_BOOTLOADER_RENDER_SDDM_AUTOLOGIN
# Creates /etc/sddm.conf.d/autologin.conf with the detected desktop
# user and session name.
##################################################################
archenemy_bootloader_render_sddm_autologin() {
  local session="${1:-${ARCHENEMY_DEFAULT_SESSION:-hyprland-uwsm}}"
  local template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/sddm/autologin.conf"
  if [[ ! -f "$template" ]]; then
    log_error "Missing SDDM autologin template at $template"
    return 1
  fi

  local autologin_user
  autologin_user="$(archenemy_get_primary_user)"

  local tmp
  tmp="$(mktemp)"
  sed -e "s|__USER__|$autologin_user|g" \
    -e "s|__SESSION__|$session|g" \
    "$template" >"$tmp"
  run_cmd sudo install -D -m 644 "$tmp" /etc/sddm.conf.d/autologin.conf
  rm -f "$tmp"
}

##################################################################
# ARCHENEMY_BOOTLOADER_INSTALL_SDDM_BRANDING
# Drops theme snippets + a face icon so SDDM matches the desktop
# branding.
##################################################################
archenemy_bootloader_install_sddm_branding() {
  local branding_template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/sddm/theme.conf"
  if [[ -f "$branding_template" ]]; then
    run_cmd sudo install -D -m 644 "$branding_template" /etc/sddm.conf.d/archenemy-theme.conf
  fi

  local -a face_candidates=(
    "${ARCHENEMY_PATH:-$HOME/.config/archenemy}/icon.png"
    "${ARCHENEMY_PATH:-$HOME/.config/archenemy}/logo.png"
    "${ARCHENEMY_PATH:-$HOME/.config/archenemy}/logo.svg"
  )
  local face_source=""
  for candidate in "${face_candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      face_source="$candidate"
      break
    fi
  done

  if [[ -n "$face_source" ]]; then
    run_cmd sudo install -D -m 644 "$face_source" /usr/share/sddm/faces/archenemy.face.icon
  fi
}

##################################################################
# ARCHENEMY_BOOTLOADER_REFRESH_LIMINE_CONFIG
# Rewrites the Limine defaults/conf and runs bios-install/update as
# needed; shared by both phases.
##################################################################
archenemy_bootloader_refresh_limine_config() {
  local boot_mode="${1:-$(archenemy_bootloader_detect_boot_mode)}"
  local esp_path="${2:-$(archenemy_bootloader_find_esp_mountpoint)}"

  archenemy_bootloader_write_limine_default_file "$boot_mode" "$esp_path"
  archenemy_bootloader_reset_limine_conf

  if [[ "$boot_mode" == "bios" ]]; then
    local -a bios_disks
    mapfile -t bios_disks < <(archenemy_bootloader_unique_bios_disks)
    if [[ ${#bios_disks[@]} -gt 0 ]]; then
      log_info "Running limine bios-install for disks: ${bios_disks[*]}"
      local disk
      for disk in "${bios_disks[@]}"; do
        run_cmd sudo limine bios-install "/dev/$disk"
      done
    else
      log_warn "Unable to detect BIOS target disks; limine bios-install skipped."
    fi
  fi

  run_cmd sudo limine-update
}
