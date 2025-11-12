#!/bin/bash
# ################################################################################
# archenemy Installer Bootstrap
# ################################################################################
#
# This minimal script is the entry point for the archenemy installer. It is
# designed to be downloaded and executed via curl.
#
# Responsibilities:
#   1. Detect whether we are running from the live ISO or an installed system
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
CUSTOM_REF="${CUSTOM_REF:-dev}"
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

    if [[ "$ARCHENEMY_PATH_USER_DEFINED" == false ]]; then
      ARCHENEMY_PATH="${detected_root}${ARCHENEMY_PATH}"
    fi

    case "$ARCHENEMY_PATH" in
    "$detected_root"*)
      ;;
    *)
      log_error "ARCHENEMY_PATH ($ARCHENEMY_PATH) must reside inside ARCHENEMY_TARGET_ROOT ($detected_root)."
      exit 1
      ;;
    esac

    if ! command -v arch-chroot >/dev/null 2>&1; then
      log_error "arch-chroot is required when running from the live ISO (package: arch-install-scripts)."
      exit 1
    fi
  fi

  ARCHENEMY_TARGET_ROOT="$detected_root"
  export ARCHENEMY_TARGET_ROOT

  if [[ "$RUN_IN_CHROOT" == true ]]; then
    ARCHENEMY_PATH_IN_CHROOT="${ARCHENEMY_PATH#"$ARCHENEMY_TARGET_ROOT"}"
    [[ "$ARCHENEMY_PATH_IN_CHROOT" == /* ]] || ARCHENEMY_PATH_IN_CHROOT="/$ARCHENEMY_PATH_IN_CHROOT"
    log_info "Live ISO detected; cloning into ${ARCHENEMY_PATH} and launching via arch-chroot."
  else
    ARCHENEMY_PATH_IN_CHROOT="$ARCHENEMY_PATH"
  fi
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

  if [[ "$CUSTOM_REF" != "main" ]]; then
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
    env CUSTOM_REPO="$CUSTOM_REPO" CUSTOM_REF="$CUSTOM_REF" ARCHENEMY_PATH="$ARCHENEMY_PATH_IN_CHROOT" \
      arch-chroot "$ARCHENEMY_TARGET_ROOT" /bin/bash "$ARCHENEMY_PATH_IN_CHROOT/installation/boot.sh"
    return
  fi

  env CUSTOM_REPO="$CUSTOM_REPO" CUSTOM_REF="$CUSTOM_REF" ARCHENEMY_PATH="$ARCHENEMY_PATH" \
    bash "$ARCHENEMY_PATH/installation/boot.sh"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
setup_install_context
require_online
fetch_repository
ensure_chroot_prereqs
launch_main_installer
