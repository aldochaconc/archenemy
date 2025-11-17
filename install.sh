#!/bin/bash
# ################################################################################
# archenemy Installer Bootstrap
# ################################################################################
#
# This minimal script is the entry point for the archenemy installer. It is
# designed to be downloaded and executed via curl.
#
# Responsibilities:
#   1. Detect whether the script runs from the live ISO or an installed system
#   2. Fetch the repository (git when available, tarball fallback otherwise)
#   3. Execute installation/boot.sh from the correct context (directly or via
#      arch-chroot when running from the live media)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/archenemy/main/install.sh | bash
#
# ################################################################################

set -euo pipefail

# Configuration -----------------------------------------------------------------
CUSTOM_REPO="${CUSTOM_REPO:-aldochaconc/archenemy}"
CUSTOM_REF="${CUSTOM_REF:-master}"
DEFAULT_ARCHENEMY_PATH="$HOME/.config/archenemy"
DEFAULT_ARCHENEMY_TARGET_ROOT="/mnt"

if [[ -n "${ARCHENEMY_PATH:-}" ]]; then
  ARCHENEMY_PATH_USER_DEFINED=true
else
  ARCHENEMY_PATH_USER_DEFINED=false
  ARCHENEMY_PATH="$DEFAULT_ARCHENEMY_PATH"
fi

RUN_IN_CHROOT=false
ARCHENEMY_PATH_IN_CHROOT="$ARCHENEMY_PATH"

# Logging -----------------------------------------------------------------------
log_info() { printf "\e[34m[INFO] %s\e[0m\n" "$1"; }
log_error() { printf "\e[31m[ERROR] %s\e[0m\n" "$1" >&2; }

# Helpers -----------------------------------------------------------------------
is_live_iso() {
  [[ -d /run/archiso ]] || grep -q 'archiso' /proc/cmdline 2>/dev/null
}

target_root_ready() {
  local root="$1"
  [[ -d "$root" && -f "$root/etc/arch-release" ]]
}

require_online() {
  if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    return
  fi

  if curl -fs --max-time 5 https://mirror.rackspace.com/archlinux/ >/dev/null 2>&1; then
    return
  fi

  log_error "An active internet connection is required for the archenemy installer (per the Arch Linux installation guide)."
  exit 1
}

detect_primary_user() {
  local root="${ARCHENEMY_TARGET_ROOT:-/}"
  local passwd_file="$root/etc/passwd"
  local requested_user="${ARCHENEMY_USER_NAME:-}"
  local entry=""

  if [[ ! -f "$passwd_file" ]]; then
    log_error "Unable to read $passwd_file to detect the desktop user."
    exit 1
  fi

  if [[ -n "$requested_user" ]]; then
    entry="$(grep -E "^${requested_user}:" "$passwd_file" | head -n1 || true)"
    if [[ -z "$entry" ]]; then
      log_error "ARCHENEMY_USER_NAME '$requested_user' was not found in $passwd_file."
      exit 1
    fi
  else
    entry="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $0; exit}' "$passwd_file")"
    if [[ -z "$entry" ]]; then
      log_error "No non-root users (UID >= 1000) were found in $passwd_file. Create your desktop user before running archenemy."
      exit 1
    fi
  fi

  IFS=: read -r PRIMARY_USER _ PRIMARY_UID PRIMARY_GID _ PRIMARY_HOME _ <<<"$entry"
  if [[ -z "${PRIMARY_HOME:-}" || "${PRIMARY_HOME:0:1}" != "/" ]]; then
    log_error "User '$PRIMARY_USER' has an invalid home directory entry."
    exit 1
  fi

  ARCHENEMY_PRIMARY_USER="$PRIMARY_USER"
  ARCHENEMY_PRIMARY_UID="$PRIMARY_UID"
  ARCHENEMY_PRIMARY_GID="$PRIMARY_GID"
  ARCHENEMY_PRIMARY_HOME="$PRIMARY_HOME"
}

resolve_user_home_paths() {
  local root="${ARCHENEMY_TARGET_ROOT:-/}"
  local rel_home="$ARCHENEMY_PRIMARY_HOME"

  if [[ "$root" == "/" ]]; then
    ARCHENEMY_PRIMARY_HOME_HOST="$rel_home"
  else
    ARCHENEMY_PRIMARY_HOME_HOST="$root$rel_home"
  fi

  if [[ ! -d "$ARCHENEMY_PRIMARY_HOME_HOST" ]]; then
    log_error "Home directory $ARCHENEMY_PRIMARY_HOME_HOST does not exist. Verify the user was created during archinstall."
    exit 1
  fi
}

configure_archenemy_paths() {
  if [[ "$ARCHENEMY_PATH_USER_DEFINED" == false ]]; then
    ARCHENEMY_PATH="${ARCHENEMY_PRIMARY_HOME_HOST}/.config/archenemy"
  fi

  if [[ "$RUN_IN_CHROOT" == true ]]; then
    case "$ARCHENEMY_PATH" in
    "$ARCHENEMY_TARGET_ROOT"*) ;;
    *)
      log_error "ARCHENEMY_PATH ($ARCHENEMY_PATH) must reside inside ARCHENEMY_TARGET_ROOT ($ARCHENEMY_TARGET_ROOT)."
      exit 1
      ;;
    esac
    ARCHENEMY_PATH_IN_CHROOT="${ARCHENEMY_PATH#"$ARCHENEMY_TARGET_ROOT"}"
    [[ "$ARCHENEMY_PATH_IN_CHROOT" == /* ]] || ARCHENEMY_PATH_IN_CHROOT="/$ARCHENEMY_PATH_IN_CHROOT"
    ARCHENEMY_HOME_FOR_BOOT="$ARCHENEMY_PRIMARY_HOME"
    log_info "Live ISO detected; cloning into ${ARCHENEMY_PATH} and launching via arch-chroot."
  else
    ARCHENEMY_PATH_IN_CHROOT="$ARCHENEMY_PATH"
    ARCHENEMY_HOME_FOR_BOOT="$ARCHENEMY_PRIMARY_HOME_HOST"
  fi

  export ARCHENEMY_USER_NAME="$ARCHENEMY_PRIMARY_USER"
}

# Persisting the detected user data lets every subsequent phase reuse the same
# identity. Without this, reruns after a failed postinstall could guess the
# wrong user and clobber ownership, making recovery painful.
persist_primary_user_metadata() {
  local state_root env_file
  state_root="${ARCHENEMY_TARGET_ROOT:-/}/var/lib/archenemy"
  env_file="$state_root/primary-user.env"

  install -d -m 755 "$state_root"
  cat >"$env_file" <<EOF
ARCHENEMY_PRIMARY_USER="$ARCHENEMY_PRIMARY_USER"
ARCHENEMY_PRIMARY_UID="$ARCHENEMY_PRIMARY_UID"
ARCHENEMY_PRIMARY_GID="$ARCHENEMY_PRIMARY_GID"
ARCHENEMY_PRIMARY_HOME="$ARCHENEMY_PRIMARY_HOME"
ARCHENEMY_PRIMARY_HOME_HOST="$ARCHENEMY_PRIMARY_HOME_HOST"
EOF
}

chown_repo_to_primary_user() {
  if [[ $EUID -ne 0 ]]; then
    return
  fi
  if [[ -z "${ARCHENEMY_PRIMARY_UID:-}" || -z "${ARCHENEMY_PRIMARY_GID:-}" ]]; then
    return
  fi
  if [[ -d "$ARCHENEMY_PATH" ]]; then
    chown -R "${ARCHENEMY_PRIMARY_UID}:${ARCHENEMY_PRIMARY_GID}" "$ARCHENEMY_PATH"
  fi
}

setup_install_context() {
  local detected_root="${ARCHENEMY_TARGET_ROOT:-}"
  if [[ -z "$detected_root" ]]; then
    if is_live_iso; then
      detected_root="$DEFAULT_ARCHENEMY_TARGET_ROOT"
    else
      detected_root="/"
    fi
  fi

  if [[ "$detected_root" != "/" ]]; then
    if ! target_root_ready "$detected_root"; then
      log_error "ARCHENEMY_TARGET_ROOT ($detected_root) does not contain an installed Arch Linux system."
      exit 1
    fi

    RUN_IN_CHROOT=true

    if ! command -v arch-chroot >/dev/null 2>&1; then
      log_error "arch-chroot is required when running from the live ISO (package: arch-install-scripts)."
      exit 1
    fi
  fi

  ARCHENEMY_TARGET_ROOT="$detected_root"
  export ARCHENEMY_TARGET_ROOT
}

clone_repo_with_git() {
  local repo_url="https://github.com/${CUSTOM_REPO}.git"
  log_info "Cloning ${repo_url} (ref: ${CUSTOM_REF})..."

  if git clone --depth 1 --single-branch --branch "$CUSTOM_REF" "$repo_url" "$ARCHENEMY_PATH" >/dev/null 2>&1; then
    return 0
  fi

  log_info "Unable to clone ref '${CUSTOM_REF}' directly. Falling back to default branch..."
  rm -rf "$ARCHENEMY_PATH"
  if ! git clone "$repo_url" "$ARCHENEMY_PATH" >/dev/null 2>&1; then
    return 1
  fi

  if [[ "$CUSTOM_REF" != "master" ]]; then
    (cd "$ARCHENEMY_PATH" && git fetch origin "$CUSTOM_REF" >/dev/null 2>&1 && git checkout "$CUSTOM_REF" >/dev/null 2>&1)
  fi
}

download_repo_tarball() {
  local tar_url="https://codeload.github.com/${CUSTOM_REPO}/tar.gz/${CUSTOM_REF}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  log_info "Downloading ${CUSTOM_REPO}@${CUSTOM_REF} as a tarball..."
  curl -fsSL "$tar_url" | tar -xz --strip-components=1 -C "$tmp_dir"

  rm -rf "$ARCHENEMY_PATH"
  install -d -m 755 "$(dirname "$ARCHENEMY_PATH")"
  mv "$tmp_dir" "$ARCHENEMY_PATH"

  trap - RETURN
}

fetch_repository() {
  install -d -m 755 "$(dirname "$ARCHENEMY_PATH")"
  rm -rf "$ARCHENEMY_PATH"

  if command -v git >/dev/null 2>&1; then
    if clone_repo_with_git; then
      log_info "Repository cloned into $ARCHENEMY_PATH"
      return
    fi
    log_info "git clone failed; falling back to tarball download."
    rm -rf "$ARCHENEMY_PATH"
  else
    log_info "git is not available; falling back to tarball download."
  fi

  download_repo_tarball
  log_info "Repository extracted into $ARCHENEMY_PATH"
}

ensure_chroot_prereqs() {
  if [[ "$RUN_IN_CHROOT" == false ]]; then
    return
  fi
  log_info "Ensuring sudo is available inside the target system..."
  arch-chroot "$ARCHENEMY_TARGET_ROOT" pacman -Sy --noconfirm --needed sudo
}

launch_main_installer() {
  log_info "Launching main installer..."
  if [[ "$RUN_IN_CHROOT" == true ]]; then
    env CUSTOM_REPO="$CUSTOM_REPO" CUSTOM_REF="$CUSTOM_REF" \
      ARCHENEMY_PATH="$ARCHENEMY_PATH_IN_CHROOT" \
      ARCHENEMY_HOME="$ARCHENEMY_HOME_FOR_BOOT" \
      arch-chroot "$ARCHENEMY_TARGET_ROOT" /bin/bash "$ARCHENEMY_PATH_IN_CHROOT/installation/boot.sh"
    return
  fi

  env CUSTOM_REPO="$CUSTOM_REPO" CUSTOM_REF="$CUSTOM_REF" \
    ARCHENEMY_PATH="$ARCHENEMY_PATH" \
    ARCHENEMY_HOME="$ARCHENEMY_HOME_FOR_BOOT" \
    bash "$ARCHENEMY_PATH/installation/boot.sh"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
setup_install_context
detect_primary_user
resolve_user_home_paths
configure_archenemy_paths
persist_primary_user_metadata
require_online
fetch_repository
chown_repo_to_primary_user
ensure_chroot_prereqs
launch_main_installer
