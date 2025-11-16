#!/usr/bin/env bash
#
# System Utilities Entry Point
# ---------------------------
# Historical helper functions now live inside the shared ae-system CLI. This
# wrapper keeps Hyprland bindings working while exposing the same commands to
# launchers and ae-cli.
#
# Usage:
#   ~/.config/hypr/bindings/system.sh <command>
#   ae system <command>
#

set -euo pipefail

ARCHENEMY_PATH="${ARCHENEMY_PATH:-$HOME/.config/archenemy}"
AE_CLI_BIN="${AE_CLI_BIN:-$ARCHENEMY_PATH/ae-cli/ae}"

_system_wrapper_error() {
  local message="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "  Hypr System" "$message"
  else
    echo "$message" >&2
  fi
  exit 1
}

if [[ ! -x "$AE_CLI_BIN" ]]; then
  _system_wrapper_error "ae CLI not found at $AE_CLI_BIN"
fi

if [[ $# -eq 0 ]]; then
  exec "$AE_CLI_BIN" system help
fi

exec "$AE_CLI_BIN" system "$@"
