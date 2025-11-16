#!/bin/bash
# Environment bootstrap for installer runs. Defines canonical paths so every
# module references the same directories regardless of where it is executed.
# Preconditions: `$HOME` must resolve to the target user; optional overrides may
# be exported prior to sourcing.
# Postconditions: exported variables point to installer directories.

if [[ "${ARCHENEMY_COMMONS_ENV_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMONS_ENV_SOURCED=true

# ARCHENEMY_HOME=base user home for config placement.
: "${ARCHENEMY_HOME:="$HOME"}"
# ARCHENEMY_PATH=root of the archenemy configuration tree under HOME.
: "${ARCHENEMY_PATH:="$ARCHENEMY_HOME/.config/archenemy"}"
# ARCHENEMY_INSTALL_ROOT=directory containing installer scripts and defaults.
: "${ARCHENEMY_INSTALL_ROOT:="$ARCHENEMY_PATH/installation"}"
# ARCHENEMY_USER_CONFIG_DIR=target ~/.config path for dotfiles.
: "${ARCHENEMY_USER_CONFIG_DIR:="$ARCHENEMY_HOME/.config"}"
# ARCHENEMY_USER_STATE_DIR=target ~/.local/state path for daemon state.
: "${ARCHENEMY_USER_STATE_DIR:="$ARCHENEMY_HOME/.local/state"}"
# ARCHENEMY_ARCHINSTALL_DIR=workspace used by the bootstrap process.
: "${ARCHENEMY_ARCHINSTALL_DIR:="$ARCHENEMY_PATH/archinstall"}"
# ARCHENEMY_DEFAULTS_DIR=root for assets shipped with the installer.
: "${ARCHENEMY_DEFAULTS_DIR:="$ARCHENEMY_INSTALL_ROOT/defaults"}"

export ARCHENEMY_HOME
export ARCHENEMY_PATH
export ARCHENEMY_INSTALL_ROOT
export ARCHENEMY_USER_CONFIG_DIR
export ARCHENEMY_USER_STATE_DIR
export ARCHENEMY_ARCHINSTALL_DIR
export ARCHENEMY_DEFAULTS_DIR

# ARCHENEMY_DEFAULTS_BOOTLOADER_DIR=plymouth + SDDM defaults consumed later.
ARCHENEMY_DEFAULTS_BOOTLOADER_DIR="$ARCHENEMY_DEFAULTS_DIR/bootloader"
export ARCHENEMY_DEFAULTS_BOOTLOADER_DIR

ARCHENEMY_GLOBALS_FILE="$ARCHENEMY_INSTALL_ROOT/commons/config.sh"
if [[ -f "$ARCHENEMY_GLOBALS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ARCHENEMY_GLOBALS_FILE"
fi


archenemy_detect_phase() {
  local explicit="${1:-${ARCHENEMY_PHASE:-}}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"
    return
  fi

  local sentinel="$ARCHENEMY_ARCHINSTALL_DIR/postinstall-required"
  if [[ -f "$sentinel" ]]; then
    echo "postinstall"
    return
  fi

  if grep -q 'archiso' /proc/cmdline 2>/dev/null || [[ -d /run/archiso ]]; then
    echo "preinstall"
    return
  fi

  if [[ -d /mnt && -f /mnt/etc/arch-release ]]; then
    echo "preinstall"
    return
  fi

  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --chroot >/dev/null 2>&1; then
    echo "preinstall"
    return
  fi

  echo "postinstall"
}

archenemy_initialize_phase() {
  if [[ -z "${ARCHENEMY_PHASE:-}" ]]; then
    ARCHENEMY_PHASE="$(archenemy_detect_phase)"
  fi
  export ARCHENEMY_PHASE
  if [[ "$ARCHENEMY_PHASE" == "preinstall" ]]; then
    export ARCHENEMY_CHROOT_INSTALL=true
  else
    export ARCHENEMY_CHROOT_INSTALL=false
  fi
}

display_phase1_completion_message() {
  _display_splash
  cat <<'MSG'

============================================================
Phase 1 complete. Reboot into the installed system, log in
on a terminal (TTY), and rerun the installer to finish the
service activation + cleanup phase.
============================================================

MSG
}

archenemy_get_primary_user() {
  if [[ -n "${ARCHENEMY_PRIMARY_USER:-}" ]] && id -u "$ARCHENEMY_PRIMARY_USER" >/dev/null 2>&1; then
    echo "$ARCHENEMY_PRIMARY_USER"
    return
  fi

  local metadata_env_file="/var/lib/archenemy/primary-user.env"
  if [[ -f "$metadata_env_file" ]]; then
    # shellcheck disable=SC1090
    source "$metadata_env_file"
    if [[ -n "${ARCHENEMY_PRIMARY_USER:-}" ]] && id -u "$ARCHENEMY_PRIMARY_USER" >/dev/null 2>&1; then
      echo "$ARCHENEMY_PRIMARY_USER"
      return
    fi
  fi

  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && id -u "$SUDO_USER" >/dev/null 2>&1; then
    echo "$SUDO_USER"
    return
  fi

  if [[ -n "${USER:-}" && "${USER}" != "root" ]] && id -u "$USER" >/dev/null 2>&1; then
    echo "$USER"
    return
  fi

  local fallback
  fallback="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1; exit}' /etc/passwd 2>/dev/null || true)"
  if [[ -n "$fallback" ]]; then
    echo "$fallback"
    return
  fi

  log_error "Unable to detect the primary desktop user. Set ARCHENEMY_PRIMARY_USER before rerunning."
  exit 1
}

run_as_user() {
  local target_user="${SUDO_USER:-$USER}"
  if [[ -z "$target_user" ]]; then
    log_error "Unable to determine non-root user for run_as_user"
    exit 1
  fi
  if [[ "$EUID" -eq 0 ]]; then
    run_cmd sudo -u "$target_user" "$@"
  else
    run_cmd "$@"
  fi
}
