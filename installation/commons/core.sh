#!/bin/bash
# Core helpers for the installer runtime. Handles logging, dry-run plumbing,
# guarded sourcing, CLI parsing, and error handling shared by all modules.
# Preconditions: bash shell, optional ARCHENEMY_INSTALL_LOG_FILE override.
# Postconditions: logging helpers available and traps configured when requested.

# Guard repeated sourcing.
if [[ "${ARCHENEMY_COMMONS_CORE_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMONS_CORE_SOURCED=true

# ARCHENEMY_INSTALL_LOG_FILE=path to append installer logs.
: "${ARCHENEMY_INSTALL_LOG_FILE:=/var/log/archenemy-install.log}"
export ARCHENEMY_INSTALL_LOG_FILE

# _ARCHENEMY_DRY_RUN=internal flag toggled by --dry-run parsing.
_ARCHENEMY_DRY_RUN=false

__archenemy__print_log() {
  local level="$1"
  local message="$2"
  local color
  case "$level" in
  INFO) color="\e[34m" ;;
  SUCCESS) color="\e[32m" ;;
  WARN) color="\e[33m" ;;
  ERROR) color="\e[31m" ;;
  *) color="\e[0m" ;;
  esac
  printf "%b[%s] %s\e[0m\n" "$color" "$level" "$message"
  if [[ -n "${ARCHENEMY_INSTALL_LOG_FILE:-}" ]]; then
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [%s] %s\n" "$ts" "$level" "$message" >>"$ARCHENEMY_INSTALL_LOG_FILE" 2>/dev/null || true
  fi
}

log_info() { __archenemy__print_log "INFO" "$1"; }
log_success() { __archenemy__print_log "SUCCESS" "$1"; }
log_warn() { __archenemy__print_log "WARN" "$1"; }
log_error() { __archenemy__print_log "ERROR" "$1" >&2; }

_display_splash() {
  cat <<'SPLASH'
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
SPLASH
}

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

parse_cli_args() {
  for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
      _ARCHENEMY_DRY_RUN=true
      log_info "Dry run mode enabled. No commands will be executed."
      break
    fi
  done
}

run_cmd() {
  if [[ "$_ARCHENEMY_DRY_RUN" == true ]]; then
    log_info "[DRY RUN] $*"
    return 0
  fi

  # When a log file is configured, mirror command output (stdout + stderr)
  # both to the terminal and to the installer log so failures like
  # "error: target not found" are visible in archenemy-install.log.
  if [[ -n "${ARCHENEMY_INSTALL_LOG_FILE:-}" ]]; then
    # Echo the command itself for context.
    printf '$ %s\n' "$*" | tee -a "$ARCHENEMY_INSTALL_LOG_FILE"
    # Pipe command output through tee; with `set -o pipefail` the overall
    # exit status will still propagate to the ERR trap.
    "$@" 2>&1 | tee -a "$ARCHENEMY_INSTALL_LOG_FILE"
  else
    "$@"
  fi
}

run_query_cmd() {
  log_info "[QUERY] $*"
  if [[ -n "${ARCHENEMY_INSTALL_LOG_FILE:-}" ]]; then
    printf '$ %s\n' "$*" | tee -a "$ARCHENEMY_INSTALL_LOG_FILE"
    "$@" 2>&1 | tee -a "$ARCHENEMY_INSTALL_LOG_FILE"
  else
    "$@"
  fi
}

_archenemy_handle_error() {
  local line_number="$1"
  local exit_code="$2"
  log_error "An error occurred on line $line_number (exit code: $exit_code)."
  log_error "Installation cannot continue. See ${ARCHENEMY_INSTALL_LOG_FILE:-/var/log/archenemy-install.log} for details."
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
  log_error "An active internet connection is required for the archenemy installer."
  exit 1
}
