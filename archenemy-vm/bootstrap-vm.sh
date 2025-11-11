#!/bin/bash
# ################################################################################
# archenemy QEMU Bootstrap Helper
# ################################################################################
#
# Development-only entry point that mounts the optional virtio-9p pacman cache
# (shared by `make run USE_CACHE=1`) and then executes the standard installer.
# Keeps VM-specific behavior outside the production installer tree.
# ################################################################################

set -euo pipefail

CUSTOM_REPO="${CUSTOM_REPO:-aldochaconc/archenemy}"
CUSTOM_REF="${CUSTOM_REF:-dev}"
ARCHENEMY_PATH="${ARCHENEMY_PATH:-$HOME/.config/archenemy}"
ARCHENEMY_VM_CACHE_TAG="${ARCHENEMY_VM_CACHE_TAG:-archenemy-cache}"
ARCHENEMY_VM_CACHE_TARGET="${ARCHENEMY_VM_CACHE_TARGET:-/var/cache/pacman/pkg}"
ARCHENEMY_VM_CACHE_OPTS="${ARCHENEMY_VM_CACHE_OPTS:-trans=virtio,msize=2097152,cache=loose}"
ARCHENEMY_ENABLE_VM_CACHE="${ARCHENEMY_ENABLE_VM_CACHE:-1}"

BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

log_info() { printf "%b[INFO]%b %s\n" "$BLUE" "$RESET" "$1"; }
log_success() { printf "%b[SUCCESS]%b %s\n" "$GREEN" "$RESET" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$RESET" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n" "$RED" "$RESET" "$1" >&2; }

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

vm_cache_mount_if_available() {
  if [[ "$ARCHENEMY_ENABLE_VM_CACHE" != 1 ]]; then
    log_info "VM cache disabled via ARCHENEMY_ENABLE_VM_CACHE."
    return 0
  fi

  local current_fs
  current_fs="$(findmnt -n -o FSTYPE "$ARCHENEMY_VM_CACHE_TARGET" 2>/dev/null || true)"
  if [[ "$current_fs" == "9p" ]]; then
    log_info "VM cache already mounted at $ARCHENEMY_VM_CACHE_TARGET."
    return 0
  fi

  if [[ ! -d /sys/bus/virtio/drivers/9pnet_virtio ]] || ! find /sys/bus/virtio/drivers/9pnet_virtio -maxdepth 1 -name 'virtio*' | grep -q .; then
    log_info "VM cache share not detected (no virtio-9p device)."
    return 0
  fi

  log_info "Mounting VM cache share '$ARCHENEMY_VM_CACHE_TAG' at $ARCHENEMY_VM_CACHE_TARGET..."
  sudo mkdir -p "$ARCHENEMY_VM_CACHE_TARGET"
  if sudo mount -t 9p -o "$ARCHENEMY_VM_CACHE_OPTS" "$ARCHENEMY_VM_CACHE_TAG" "$ARCHENEMY_VM_CACHE_TARGET"; then
    log_success "VM cache mounted at $ARCHENEMY_VM_CACHE_TARGET."
  else
    log_warn "Failed to mount VM cache share '$ARCHENEMY_VM_CACHE_TAG'. Continuing without cache."
  fi
}

bootstrap_install() {
  require_online

  log_info "Installing git..."
  sudo pacman -Syu --noconfirm --needed git

  log_info "Cloning archenemy from https://github.com/${CUSTOM_REPO}.git"
  rm -rf "$ARCHENEMY_PATH"
  git clone "https://github.com/${CUSTOM_REPO}.git" "$ARCHENEMY_PATH" >/dev/null

  if [[ "$CUSTOM_REF" != "main" ]]; then
    log_info "Checking out branch/ref: $CUSTOM_REF"
    (
      cd "$ARCHENEMY_PATH" || exit 1
      git fetch origin "$CUSTOM_REF"
      git checkout "$CUSTOM_REF"
    )
  fi

  log_info "Launching main installer..."
  export CUSTOM_REPO CUSTOM_REF ARCHENEMY_PATH
  bash "$ARCHENEMY_PATH/installation/boot.sh"
}

vm_cache_mount_if_available
bootstrap_install
