#!/usr/bin/env bash
#
# Hyprland Media Helper Wrapper
# Delegates bindings to the shared ae CLI media commands.
#

set -euo pipefail

ARCHENEMY_PATH="${ARCHENEMY_PATH:-$HOME/.config/archenemy}"
AE_CLI_BIN="${AE_CLI_BIN:-$ARCHENEMY_PATH/ae-cli/ae}"

_media_wrapper_error() {
  local message="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "  Hypr Media" "$message"
  else
    echo "$message" >&2
  fi
  exit 1
}

if [[ ! -x "$AE_CLI_BIN" ]]; then
  _media_wrapper_error "ae CLI not found at $AE_CLI_BIN"
fi

if [[ $# -eq 0 ]]; then
  exec "$AE_CLI_BIN" media help
fi

exec "$AE_CLI_BIN" media "$@"
