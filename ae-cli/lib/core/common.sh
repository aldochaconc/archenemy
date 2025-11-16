#!/usr/bin/env bash
#
# Shared helpers used across all ae-cli modules.

if [[ "${AE_CORE_COMMON_SOURCED:-false}" == true ]]; then
  return 0
fi
AE_CORE_COMMON_SOURCED=true

AE_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${AE_ROOT:=$(cd "$AE_CORE_DIR/../.." && pwd)}"
: "${ARCHENEMY_PATH:=$(cd "$AE_ROOT/.." && pwd)}"
: "${ARCHENEMY_HOME:=$HOME}"
: "${ARCHENEMY_USER_CONFIG_DIR:=$ARCHENEMY_HOME/.config}"
: "${ARCHENEMY_DEFAULTS_DIR:=$ARCHENEMY_PATH/installation/defaults}"
: "${ARCHENEMY_DEFAULT_SHELL:=}"

ae_cli_log() {
  local level="$1"
  shift || true
  printf '[ae-cli][%s] %s\n' "$level" "$*"
}

ae_cli_log_info() { ae_cli_log INFO "$*"; }
ae_cli_log_warn() { ae_cli_log WARN "$*"; }
ae_cli_log_error() { ae_cli_log ERROR "$*" >&2; }

ae_cli_notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  else
    ae_cli_log_info "$*"
  fi
}

ae_data_path() {
  local relative="$1"
  printf '%s/%s\n' "$AE_ROOT/share" "$relative"
}

ae_module_data_path() {
  local module_root="$1"
  local relative="$2"
  printf '%s/%s\n' "$module_root" "$relative"
}
