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

  log_info "Syncing system packages with refreshed mirrors..."
  run_cmd sudo pacman -Syyu --noconfirm --disable-download-timeout
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
  _install_pacman_packages \
    "base-devel" \
    "git" \
    "go" \
    "gcc" \
    "nvim" \
    "zsh" \
    "curl" \
    "wget" \
    "tar" \
    "zip" \
    "unzip" \
    "7zip" \
    "bzip2" \
    "gzip" \
    "xz"
}

_query_packages_with_pacman() {
  local packages=("$@")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    return
  fi
  # Use pacman's sync databases to verify availability without installing. This
  # mirrors a dry-run so failures surface early when mirrors or manifests drift.
  run_query_cmd sudo pacman -Sp --needed --print-format '%n %v' "${packages[@]}"
}

_query_packages_with_yay() {
  local packages=("$@")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    return
  fi
  # Querying the AUR metadata exposes vanished or renamed packages before attempting a build.
  run_query_cmd yay -Si "${packages[@]}"
}

# Manifest install pipeline: query first (fail fast on typos/stale names), then
# install. Mirrors pacman's `-Sp` flow so reruns stay predictable.
_install_packages_from_manifest() {
  local manifest="$1"
  local installer="${2:-pacman}"

  if [[ ! -f "$manifest" ]]; then
    log_warn "Package manifest $manifest not found; skipping."
    return
  fi

  local -a packages=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    packages+=("$pkg")
  done < <(sed -E 's/#.*$//' "$manifest" | awk '{$1=$1; if (NF) print}' || true)

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log_info "Package manifest $manifest is empty; nothing to install."
    return
  fi

  if [[ "$installer" == "aur" ]]; then
    _query_packages_with_yay "${packages[@]}"
  else
    _query_packages_with_pacman "${packages[@]}"
  fi

  if [[ "$_ARCHENEMY_DRY_RUN" == true ]]; then
    # Dry-run proves availability without mutating the filesystem. Stopping here
    # matches `pacman -Sp` semantics and keeps manifest fixes low risk.
    log_info "Dry run active; skipping installation for $manifest"
    return
  fi

  if [[ "$installer" == "aur" ]]; then
    _install_aur_packages "${packages[@]}"
  else
    _install_pacman_packages "${packages[@]}"
  fi
}

_install_curated_pacman_manifests() {
  local manifests=(
    "$ARCHENEMY_INSTALL_ROOT/core.packages"
    "$ARCHENEMY_INSTALL_ROOT/pacman.packages"
  )

  for manifest in "${manifests[@]}"; do
    _install_packages_from_manifest "$manifest" "pacman"
  done
}

_install_curated_aur_manifest() {
  local manifest="$ARCHENEMY_INSTALL_ROOT/aur.packages"
  _install_packages_from_manifest "$manifest" "aur"
}

_detect_primary_user() {
  local metadata_env_file="/var/lib/archenemy/primary-user.env"

  if [[ -f "$metadata_env_file" ]]; then
    # shellcheck disable=SC1090
    source "$metadata_env_file"
    if [[ -n "${ARCHENEMY_PRIMARY_USER:-}" ]] && id -u "$ARCHENEMY_PRIMARY_USER" >/dev/null 2>&1; then
      # Reuse the user detected during install.sh so repeated runs (or postreboot
      # resumes) never guess the wrong account; this keeps permissions stable.
      echo "$ARCHENEMY_PRIMARY_USER"
      return
    fi
  fi

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

  local aur_user
  aur_user="$(_detect_primary_user)"
  log_info "Using user '$aur_user' to build yay via makepkg."

  local repo_dir
  repo_dir="$(mktemp -d /tmp/yay.XXXXXX)"
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo chown "$aur_user":"$aur_user" "$repo_dir"
  fi
  run_cmd sudo pacman -S --noconfirm --needed git base-devel

  local -a aur_user_prefix=()
  if [[ "$EUID" -eq 0 ]]; then
    aur_user_prefix=(sudo -u "$aur_user")
  fi

  run_cmd "${aur_user_prefix[@]}" git clone https://aur.archlinux.org/yay.git "$repo_dir"
  run_cmd cd "$repo_dir"
  run_cmd "${aur_user_prefix[@]}" makepkg -si --noconfirm

  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo rm -rf "$repo_dir"
  else
    run_cmd rm -rf "$repo_dir"
  fi
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

  # --- 7. Install curated pacman manifests ---
  _install_curated_pacman_manifests

  # --- 8. Install AUR helper (yay) ---
  _install_aur_helper

  # --- 9. Install curated AUR manifests ---
  _install_curated_aur_manifest

  log_success "System preparation completed."
}

# Standalone execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_setup_base_system "$@"
fi
