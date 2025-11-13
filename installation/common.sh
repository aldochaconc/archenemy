#!/bin/bash
################################################################################
# Archenemy Common Library
################################################################################
#
# Provides shared logging helpers and canonical path variables used across the
# installer. Every step (and helpers) should source this file so shellcheck can
# resolve cross-file references cleanly.
#

if [[ "${ARCHENEMY_COMMON_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMON_SOURCED=true

# --- Canonical Paths ---------------------------------------------------------
: "${ARCHENEMY_HOME:="$HOME"}"
: "${ARCHENEMY_PATH:="$ARCHENEMY_HOME/.config/archenemy"}"
: "${ARCHENEMY_INSTALL_ROOT:="$ARCHENEMY_PATH/installation"}"
: "${ARCHENEMY_USER_CONFIG_DIR:="$ARCHENEMY_HOME/.config"}"
: "${ARCHENEMY_USER_DOTFILES_DIR:="$ARCHENEMY_USER_CONFIG_DIR/dotfiles"}"
: "${ARCHENEMY_ARCHINSTALL_DIR:="${ARCHENEMY_PATH}/archinstall"}"

export ARCHENEMY_HOME
export ARCHENEMY_PATH
export ARCHENEMY_INSTALL_ROOT
export ARCHENEMY_USER_CONFIG_DIR
export ARCHENEMY_USER_DOTFILES_DIR
export ARCHENEMY_ARCHINSTALL_DIR
export ARCHENEMY_DEFAULTS_DIR="${ARCHENEMY_PATH}/default"
export ARCHENEMY_DEFAULTS_BASE_SYSTEM_DIR="${ARCHENEMY_DEFAULTS_DIR}/base_system"
export ARCHENEMY_DEFAULTS_BOOTLOADER_DIR="${ARCHENEMY_DEFAULTS_DIR}/bootloader"
export ARCHENEMY_DEFAULTS_DRIVERS_DIR="${ARCHENEMY_DEFAULTS_DIR}/drivers"
export ARCHENEMY_DEFAULTS_GRAPHICS_DIR="${ARCHENEMY_DEFAULTS_DIR}/graphics"
export ARCHENEMY_DEFAULTS_DOTFILES_DIR="${ARCHENEMY_DEFAULTS_DIR}/dotfiles"
export ARCHENEMY_DEFAULTS_DAEMONS_DIR="${ARCHENEMY_DEFAULTS_DIR}/daemons"
export ARCHENEMY_DEFAULTS_CLEANUP_DIR="${ARCHENEMY_DEFAULTS_DIR}/cleanup"
export ARCHENEMY_DEFAULTS_INSTALL_SENTINEL_DIR="${ARCHENEMY_DEFAULTS_DIR}/install_sentinel"

################################################################################
# INSTALLATION UTILITIES
################################################################################

ensure_install_log_file() {
  local log_file="${1:-$ARCHENEMY_INSTALL_LOG_FILE}"
  local log_dir
  log_dir="$(dirname "$log_file")"

  sudo install -d -m 755 "$log_dir"
  if [[ ! -f "$log_file" ]]; then
    sudo touch "$log_file"
  fi
  sudo chown "$USER":"$USER" "$log_file"
  sudo chmod 644 "$log_file"
}

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

display_phase1_completion_message() {
  _display_splash
  local completion_banner='

============================================================
Phase 1 complete. Reboot into the installed system, log in,
and run the installer again to continue with phase 2.
============================================================

'
  printf "%s\n" "$completion_banner"
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

################################################################################
# DRY RUN & COMMAND EXECUTION
_ARCHENEMY_DRY_RUN=false

################################################################################
# PARSE CLI ARGS
# Parses command-line arguments to detect --dry-run.
parse_cli_args() {
  for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
      _ARCHENEMY_DRY_RUN=true
      log_info "Dry run mode enabled. No commands will be executed."
      break
    fi
  done
}

################################################################################
# RUN COMMAND
# Executes a command or prints it if --dry-run is active.
run_cmd() {
  if [[ "$_ARCHENEMY_DRY_RUN" == true ]]; then
    log_info "[DRY RUN] $*"
  else
    "$@"
  fi
}

################################################################################
# LOGGING
# Prints a log message with the appropriate color based on the level.
#
# Arguments:
#   $1: The level of the log message (INFO, SUCCESS, ERROR)
#   $2: The message to print
#
__archenemy__print_log() {
  local level="$1"
  local message="$2"
  local color_code
  local timestamp log_line

  case "$level" in
  INFO) color_code="\e[34m" ;;
  SUCCESS) color_code="\e[32m" ;;
  WARN) color_code="\e[33m" ;;
  ERROR) color_code="\e[31m" ;;
  *) color_code="\e[0m" ;;
  esac

  printf "%b[%s] %s\e[0m\n" "$color_code" "$level" "$message"

  if [[ -n "${ARCHENEMY_INSTALL_LOG_FILE:-}" ]]; then
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    log_line="[$timestamp] [$level] $message"
    {
      printf "%s\n" "$log_line"
    } >>"$ARCHENEMY_INSTALL_LOG_FILE" 2>/dev/null || true
  fi
}

log_info() {
  __archenemy__print_log "INFO" "$1"
}

log_success() {
  __archenemy__print_log "SUCCESS" "$1"
}

log_warn() {
  __archenemy__print_log "WARN" "$1"
}

log_error() {
  __archenemy__print_log "ERROR" "$1" >&2
}

################################################################################
# ERROR HANDLER & ONLINE GUARD
################################################################################

_archenemy_handle_error() {
  local line_number="$1"
  local exit_code="$2"
  local log_file="${ARCHENEMY_INSTALL_LOG_FILE:-/var/log/archenemy-install.log}"

  log_error "An error occurred on line $line_number (exit code: $exit_code)."
  log_error "Installation cannot continue. Please check the log file for details:"
  log_error "$log_file"
  exit "$exit_code"
}

setup_error_trap() {
  trap '_archenemy_handle_error $LINENO $?' ERR
}

_require_online_install() {
  if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    return
  fi

  if curl -fs --max-time 5 https://mirror.rackspace.com/archlinux/ >/dev/null 2>&1; then
    return
  fi

  log_error "An active internet connection is required for the archenemy installer (per the Arch Linux installation guide)."
  exit 1
}

################################################################################
# PACKAGE HELPERS
# Thin wrappers around pacman/yay that keep logging consistent and soften the
# calling code.
# Arguments:
#   $1: The packages to install
_install_pacman_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing pacman packages: $*"
  run_cmd sudo pacman -S --noconfirm --needed "$@"
}

_install_aur_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing AUR packages: $*"
  run_cmd yay -S --noconfirm --needed "$@"
}

################################################################################
# SYSTEMD HELPERS
# Enabling services differs between chroot installs (where daemons cannot be
# started) and live installs. This helper encapsulates that branching logic.
#
# Arguments:
#   $1: The unit to enable
#   $2: Additional arguments to pass to systemctl
_enable_service() {
  local unit="$1"
  shift || true
  local extra_args=("$@")

  if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
    sudo systemctl enable "$unit"
    return
  fi

  if [[ ${#extra_args[@]} -gt 0 ]]; then
    sudo systemctl enable "${extra_args[@]}" "$unit"
  else
    sudo systemctl enable "$unit"
  fi
}

################################################################################
# USER CONTEXT HELPER
# Executes a command as the invoking non-root user (or falls back to the current
# user when already unprivileged).
#
# Arguments:
#   $1: The command to execute
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

################################################################################
# DISPLAY SPLASH SCREEN
# Displays the initial ANSI art splash screen.
#
_display_splash() {
  local ansi_art='
 .S_SSSs     .S_sSSs      sSSs   .S    S.     sSSs   .S_sSSs      sSSs   .S_SsS_S.    .S S.
.SS~SSSSS   .SS~YS%%b    d%%SP  .SS    SS.   d%%SP  .SS~YS%%b    d%%SP  .SS~S*S~SS.  .SS SS.
S%S   SSSS  S%S    S%b  d%S     S%S    S%S  d%S     S%S    S%b  d%S     S%S  Y  S%S  S%S S%S
S%S    S%S  S%S    S%S  S%S     S%S    S%S  S%S     S%S    S%S  S%S     S%S     S%S  S%S S%S
S%S SSSS%S  S%S    d*S  S&S     S%S SSSS%S  S&S     S%S    S&S  S&S     S%S     S%S  S%S S%S
S&S  SSS%S  S&S   .S*S  S&S     S&S  SSS&S  S&S_Ss  S&S    S&S  S&S_Ss  S&S     S&S   SS SS
S&S    S&S  S&S_sdSSS   S&S     S&S    S&S  S&S~SP  S&S    S&S  S&S~SP  S&S     S&S    S S
S&S    S&S  S&S~YSY%b   S&S     S&S    S&S  S&S     S&S    S&S  S&S     S&S     S&S    SSS
S*S    S&S  S*S    S%b  S*b     S*S    S*S  S*b     S*S    S*S  S*b     S*S     S*S    S*S
S*S    S*S  S*S    S%S  S*S.    S*S    S*S  S*S.    S*S    S*S  S*S.    S*S     S*S    S*S
S*S    S*S  S*S    S&S   SSSbs  S*S    S*S   SSSbs  S*S    S*S   SSSbs  S*S     S*S    S*S
SSS    S*S  S*S    SSS    YSSP  SSS    S*S    YSSP  S*S    SSS    YSSP  SSS     S*S    S*S
       SP   SP                         SP           SP                          SP     SP
       Y    Y                          Y            Y                           Y      Y
                                                                                              '
  clear
  echo -e "\n$ansi_art\n"
}
