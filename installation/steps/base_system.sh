#!/bin/bash
# shellcheck source=../common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common.sh"
################################################################################
# CONFIGURE BASE SYSTEM
################################################################################
#
# Goal: Configure the base system prerequisites before installing packages or
#       drivers. This includes setting up pacman, creating temporary sudo
#       permissions for a smooth installation, disabling disruptive hooks, and
#       installing the core packages required for building AUR packages.
#

################################################################################
# PACMAN
# Configures pacman with the Archenemy mirrorlist and installs essential
# build tools. This ensures that the system can fetch packages correctly.
#
_configure_pacman() {
  log_info "Configuring pacman..."
  local pacman_conf_path="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman/pacman.conf"
  local pacman_mirrorlist_path="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman/mirrorlist"

  if [[ ! -f "$pacman_conf_path" || ! -f "$pacman_mirrorlist_path" ]]; then
    log_error "Pacman defaults missing under $ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/pacman"
    exit 1
  fi

  run_cmd sudo install -m 644 "$pacman_conf_path" /etc/pacman.conf
  run_cmd sudo install -m 644 "$pacman_mirrorlist_path" /etc/pacman.d/mirrorlist

  log_info "Installing reflector for dynamic mirror management..."
  run_cmd sudo pacman -Syy --noconfirm --needed --disable-download-timeout reflector

  _refresh_pacman_mirrorlist

  log_info "Syncing system packages with refreshed mirrors..."
  run_cmd sudo pacman -Syyu --noconfirm --disable-download-timeout
}

_refresh_pacman_mirrorlist() {
  log_info "Refreshing pacman mirrorlist with reflector..."
  local save_path="/etc/pacman.d/mirrorlist"
  local reflector_cmd=(
    sudo reflector
    --protocol https
    --latest 20
    --sort rate
    --save "$save_path"
  )

  if run_cmd "${reflector_cmd[@]}"; then
    log_success "Mirrorlist updated with fastest HTTPS mirrors."
  else
    log_warn "Reflector failed to refresh mirrors; continuing with bundled list."
  fi
}

################################################################################
# SYSTEM GPG
# Configures system-wide GPG to ensure pacman can correctly import and
# verify package signatures. This is crucial for system security and stability.
#
_configure_system_gpg() {
  log_info "Configuring system GPG for pacman..."
  local gpg_conf_path="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/gpg/dirmngr.conf"

  if [[ ! -f "$gpg_conf_path" ]]; then
    log_error "Missing GPG configuration at $gpg_conf_path."
    exit 1
  fi

  run_cmd sudo install -D -m 644 "$gpg_conf_path" /etc/gnupg/dirmngr.conf
  # The following commands from the original script are often unnecessary
  # and can cause issues in automated scripts. Pacman's hooks typically
  # handle the dirmngr restarts when needed.
  # sudo gpgconf --kill dirmngr || true
  # sudo gpgconf --launch dirmngr || true
}

################################################################################
# FIRST RUN PRIVILEGES
# Sets up temporary, passwordless sudo rules for the current user. This allows
# the installer to perform system-wide changes without repeatedly asking for a
# password. These rules are removed at the end of the installation.
#
_setup_first_run_privileges() {
  log_info "Setting up temporary sudo privileges..."
  local sudoers_file="/etc/sudoers.d/archenemy-first-run"
  local template="$ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR/sudoers/archenemy-first-run"

  if [[ ! -f "$template" ]]; then
    log_error "Missing sudoers template at $template"
    exit 1
  fi

  run_cmd sed \
    -e "s|__SUDOERS_FILE__|$sudoers_file|g" \
    -e "s|__USER__|$USER|g" \
    "$template" | run_cmd sudo tee "$sudoers_file" >/dev/null
  run_cmd sudo chmod 440 "$sudoers_file"
}

################################################################################
# SUDO POLICY
# Applies persistent sudo policy tweaks (e.g., passwd_tries) that should remain
# after the installer finishes.
#
_configure_sudo_policy() {
  log_info "Configuring sudo policy..."
  local sudoers_file="/etc/sudoers.d/archenemy-passwd-policy"
  run_cmd bash -c "echo 'Defaults passwd_tries=10' | sudo tee $sudoers_file >/dev/null"
  run_cmd sudo chmod 440 "$sudoers_file"
}

################################################################################
# MKINITCPIO HOOKS
# Temporarily disables the mkinitcpio hooks that run during package
# installations. This prevents multiple, unnecessary initramfs regenerations,
# significantly speeding up the installation process. The hooks are re-enabled
# later, before the final initramfs is built.
#
_disable_mkinitcpio_hooks() {
  log_info "Temporarily disabling mkinitcpio pacman hooks..."
  local install_hook="/usr/share/libalpm/hooks/90-mkinitcpio-install.hook"
  local remove_hook="/usr/share/libalpm/hooks/60-mkinitcpio-remove.hook"

  if [ -f "$install_hook" ]; then
    run_cmd sudo mv "$install_hook" "${install_hook}.disabled"
  fi

  if [ -f "$remove_hook" ]; then
    run_cmd sudo mv "$remove_hook" "${remove_hook}.disabled"
  fi
}

################################################################################
# BASE DEVELOPMENT TOOLS
# Installs the 'base-devel' package group, which contains essential tools
# like make, gcc, and patch, required for building packages, including
# those from the AUR.
#
_install_base_packages() {
  log_info "Installing base development tools..."
  _install_pacman_packages "base-devel"
}

_detect_primary_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    echo "$SUDO_USER"
    return
  fi

  if [[ "$EUID" -ne 0 && "${USER:-}" != "root" ]]; then
    echo "$USER"
    return
  fi

  if [[ -n "${ARCHENEMY_USER_NAME:-}" ]] && id -u "$ARCHENEMY_USER_NAME" >/dev/null 2>&1; then
    echo "$ARCHENEMY_USER_NAME"
    return
  fi

  local first_user
  first_user="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd)"
  if [[ -n "$first_user" ]]; then
    echo "$first_user"
    return
  fi

  log_error "Unable to locate a non-root user for AUR builds. Create a user before running the installer."
  exit 1
}

################################################################################
# AUR HELPER
# Installs 'yay' AUR helper. This is done by cloning its repository
# and building it using 'makepkg'. This allows the installer to subsequently
# install packages from the Arch User Repository.
#
_install_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    log_info "AUR helper (yay) already installed. Skipping rebuild."
    return
  fi

  log_info "Installing AUR helper (yay)..."
  _install_pacman_packages "git" "go"

  local aur_user
  aur_user="$(_detect_primary_user)"
  log_info "Using user '$aur_user' to build yay via makepkg."

  local build_root
  build_root="$(mktemp -d /tmp/archenemy-yay.XXXXXX)"
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo chown "$aur_user":"$aur_user" "$build_root"
  fi

  local repo_dir="$build_root/yay"
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo -u "$aur_user" git clone https://aur.archlinux.org/yay.git "$repo_dir"
    run_cmd sudo -u "$aur_user" bash -c "cd '$repo_dir' && makepkg -s --noconfirm"
  else
    run_cmd git clone https://aur.archlinux.org/yay.git "$repo_dir"
    run_cmd bash -c "cd '$repo_dir' && makepkg -s --noconfirm"
  fi

  local pkg_file
  pkg_file="$(find "$repo_dir" -maxdepth 1 -type f -name 'yay-*.pkg.tar.*' | sort | tail -n1)"
  if [[ -z "$pkg_file" ]]; then
    log_error "makepkg did not produce a yay package. Check the build logs above."
    exit 1
  fi

  run_cmd sudo pacman -U --noconfirm "$pkg_file"
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo rm -rf "$build_root"
  else
    run_cmd rm -rf "$build_root"
  fi
}

run_install_aur_helper_if_needed() {
  if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
    log_info "Skipping AUR helper install inside chroot; it will be installed after reboot."
    return
  fi
  _install_aur_helper
}

################################################################################
# RUN
################################################################################

run_setup_base_system() {
  log_info "Starting system preparation..."

  # --- 1. Configure pacman and system repositories ---
  _configure_pacman

  # --- 2. Configure GPG for pacman keyrings ---
  _configure_system_gpg

  # --- 3. Set up temporary sudo privileges for first run ---
  _setup_first_run_privileges

  # --- 4. Configure persistent sudo policy ---
  _configure_sudo_policy

  # --- 5. Temporarily disable mkinitcpio hooks ---
  _disable_mkinitcpio_hooks

  # --- 6. Install base development tools ---
  _install_base_packages

  # --- 7. Install AUR helper (yay) ---
  run_install_aur_helper_if_needed

  log_success "System preparation completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_base_system "$@"
fi
