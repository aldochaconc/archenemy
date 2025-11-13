#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# BOOTLOADER & DISPLAY CONFIGURATION
################################################################################
#
# Goal: Configure the bootloader (Limine), boot splash (Plymouth), and the
#       display manager (SDDM) early in the process. Setting up the bootloader
#       here is crucial as it involves re-enabling mkinitcpio hooks, which is
#       necessary before driver and kernel module installations occur.
#

_detect_boot_mode() {
  if [[ -d /sys/firmware/efi ]]; then
    echo "efi"
  else
    echo "bios"
  fi
}

_find_esp_mountpoint() {
  local candidates=("/boot/efi" "/efi" "/boot")
  for path in "${candidates[@]}"; do
    if mountpoint -q "$path"; then
      echo "$path"
      return 0
    fi
  done
  log_warn "ESP mountpoint not detected; defaulting to /boot."
  echo "/boot"
}

_partition_from_mount() {
  local mount="$1"
  findmnt -n -o SOURCE "$mount" 2>/dev/null || true
}

_unique_bios_disks() {
  declare -A seen=()
  local partitions=()
  partitions+=("$(_partition_from_mount /)")
  partitions+=("$(_partition_from_mount /boot)")
  partitions+=("$(_partition_from_mount /boot/efi)")
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

_sanitize_kernel_cmdline() {
  local cmdline
  cmdline="$(tr -d '\0' </proc/cmdline 2>/dev/null || true)"
  cmdline="$(echo "$cmdline" | sed -E 's/(^| )BOOT_IMAGE=[^ ]*//g' | sed -E 's/(^| )initrd=[^ ]*//g' | tr -s ' ' | sed 's/^ //;s/ $//')"
  if [[ -z "$cmdline" ]]; then
    cmdline="rw quiet loglevel=3"
  fi
  echo "$cmdline"
}

_write_limine_default_file() {
  local boot_mode="$1"
  local esp_path="$2"
  local cmdline
  cmdline="$(_sanitize_kernel_cmdline)"

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

_reset_limine_conf() {
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

################################################################################
# CONFIGURE PLYMOUTH
# Sets up the Plymouth theme for a graphical boot splash screen. It copies the
# Archenemy theme files and sets it as the default.
#
_configure_plymouth() {
  log_info "Configuring Plymouth boot splash..."
  _install_pacman_packages "plymouth"
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

################################################################################
# CONFIGURE DESKTOP DISPLAY MANAGER
# Configures the SDDM (Simple Desktop Display Manager) for autologin. It creates
# a configuration file that logs the current user into a Hyprland session
# automatically on boot.
#
_configure_desktop_display_manager() {
  log_info "Configuring SDDM for autologin..."
  _install_pacman_packages "sddm"
  run_cmd sudo install -d -m 755 /etc/sddm.conf.d

  if [ ! -f /etc/sddm.conf.d/autologin.conf ]; then
    local template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/sddm/autologin.conf"
    if [[ ! -f "$template" ]]; then
      log_error "Missing SDDM autologin template at $template"
      exit 1
    fi
    run_cmd sed -e "s|__USER__|$USER|g" "$template" | run_cmd sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null
    run_cmd sudo chmod 644 /etc/sddm.conf.d/autologin.conf
  fi
  _enable_service "sddm.service"
}

################################################################################
# CONFIGURE LIMINE AND SNAPPER
# Configures the Limine bootloader, Btrfs snapshot integration with Snapper,
# and re-enables the mkinitcpio hooks. This is a complex but critical step
# that prepares the system for boot-time recovery features.
#
_configure_limine_and_snapper() {
  log_info "Configuring Limine bootloader and Snapper..."
  local limine_dependencies=(
    limine
    dosfstools
    mtools
    sbctl
  )
  _install_pacman_packages "${limine_dependencies[@]}" "snapper"
  _install_aur_packages "limine-mkinitcpio-hook" "limine-snapper-sync"
  if ! command -v limine &>/dev/null; then
    log_error "Limine bootloader failed to install. Verify the pacman output above."
    return 1
  fi

  # Define hooks for mkinitcpio with btrfs overlay support
  local hooks_template="$ARCHENEMY_DEFAULTS_BOOTLOADER_DIR/mkinitcpio/archenemy_hooks.conf"
  if [[ ! -f "$hooks_template" ]]; then
    log_error "Missing mkinitcpio hooks template at $hooks_template"
    return 1
  fi
  run_cmd sudo install -D -m 644 "$hooks_template" /etc/mkinitcpio.conf.d/archenemy_hooks.conf

  local boot_mode esp_path
  boot_mode="$(_detect_boot_mode)"
  esp_path="$(_find_esp_mountpoint)"
  _write_limine_default_file "$boot_mode" "$esp_path"
  _reset_limine_conf

  # Set up Snapper if not already configured
  if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
    run_cmd sudo snapper -c root create-config /
  fi
  if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
    run_cmd sudo snapper -c home create-config /home
  fi

  # Tweak default Snapper configs for better performance
  run_cmd sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
  run_cmd sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

  log_info "Re-enabling mkinitcpio hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"

  if [ -f "${install_hook}.disabled" ]; then
    run_cmd sudo mv "${install_hook}.disabled" "$install_hook"
  fi
  if [ -f "${remove_hook}.disabled" ]; then
    run_cmd sudo mv "${remove_hook}.disabled" "$remove_hook"
  fi

  log_info "Rebuilding initramfs with restored hooks..."
  run_cmd sudo mkinitcpio -P

  if [[ "$boot_mode" == "bios" ]]; then
    local -a bios_disks=()
    mapfile -t bios_disks < <(_unique_bios_disks)
    if [[ ${#bios_disks[@]} -gt 0 ]]; then
      log_info "Running limine bios-install for disks: ${bios_disks[*]}"
      for disk in "${bios_disks[@]}"; do
        run_cmd sudo limine bios-install "/dev/$disk"
      done
    else
      log_warn "Unable to detect BIOS target disks; limine bios-install skipped."
    fi
  fi

  log_info "Updating Limine configuration..."
  run_cmd sudo limine-update

  _enable_service "limine-snapper-sync.service"
  if [[ "${ARCHENEMY_CHROOT_INSTALL:-false}" == false ]]; then
    run_cmd sudo systemctl start limine-snapper-sync.service
  fi

  local windows_boot="${esp_path}/EFI/Microsoft/Boot/bootmgfw.efi"
  if [[ -f "$windows_boot" ]]; then
    log_info "Detected Windows Boot Manager at $windows_boot; Limine will expose it via FIND_BOOTLOADERS."
  fi
}

################################################################################
# RUN
################################################################################

run_setup_bootloader() {
  log_info "Starting bootloader & display configuration..."

  # --- 1. Configure Plymouth boot splash ---
  _configure_plymouth

  # --- 2. Configure SDDM display manager ---
  _configure_desktop_display_manager

  # --- 3. Configure Limine bootloader and Snapper ---
  _configure_limine_and_snapper

  log_success "Bootloader & display configuration completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_bootloader "$@"
fi
