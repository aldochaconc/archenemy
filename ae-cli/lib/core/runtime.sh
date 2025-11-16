#!/usr/bin/env bash
#
# Runtime responsible for loading modules and dispatching subcommands.

set -euo pipefail

AE_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${AE_ROOT:=$(cd "$AE_RUNTIME_DIR/../.." && pwd)}"

# Load shared helpers
# shellcheck source=lib/core/common.sh
source "$AE_ROOT/lib/core/common.sh"

AE_VERSION="${AE_VERSION:-}"
if [[ -z "$AE_VERSION" ]]; then
  if [[ -f "$ARCHENEMY_PATH/version" ]]; then
    AE_VERSION="$(cat "$ARCHENEMY_PATH/version" | tr -d '[:space:]')"
  else
    AE_VERSION="1.0.0"
  fi
fi

declare -A AE_MODULE_HANDLERS=()
declare -A AE_MODULE_DESCRIPTIONS=()
declare -A AE_MODULE_ALIASES=()
declare -A AE_MODULE_ROOTS=()

ae_register_module() {
  local name="$1"
  local handler="$2"
  local description="$3"
  local module_root="$4"
  shift 4 || true

  AE_MODULE_HANDLERS["$name"]="$handler"
  AE_MODULE_DESCRIPTIONS["$name"]="$description"
  AE_MODULE_ROOTS["$name"]="$module_root"

  if [[ $# -gt 0 ]]; then
    local alias
    for alias in "$@"; do
      AE_MODULE_ALIASES["$alias"]="$name"
    done
  fi
}

ae_source_module() {
  local module_root="$1"
  local module_file="$module_root/module.sh"
  if [[ -f "$module_file" ]]; then
    AE_MODULE_ROOT="$module_root"
    # shellcheck source=/dev/null
    source "$module_file"
    unset AE_MODULE_ROOT
  fi
}

ae_load_modules() {
  local dir module
  for dir in "$AE_ROOT/modules" "${AE_USER_MODULES_DIR:-$ARCHENEMY_HOME/.config/archenemy/ae-cli/modules.d}"; do
    if [[ -d "$dir" ]]; then
      for module in "$dir"/*; do
        [[ -d "$module" ]] || continue
        ae_source_module "$module"
      done
    fi
  done
}

ae_print_help() {
  printf 'Archenemy CLI v%s - Hyprland configuration manager\n\n' "$AE_VERSION"
  printf 'Usage:\n'
  printf '  ae <command> [options]\n\n'
  printf 'Available commands:\n'

  local module
  for module in "${!AE_MODULE_HANDLERS[@]}"; do
    printf '  %-10s %s\n' "$module" "${AE_MODULE_DESCRIPTIONS[$module]}"
  done | sort

  printf '\nRun "ae <command> --help" for module-specific help.\n'
}

ae_resolve_module() {
  local name="$1"
  if [[ -n "${AE_MODULE_HANDLERS[$name]+set}" ]]; then
    printf '%s\n' "$name"
    return 0
  fi
  if [[ -n "${AE_MODULE_ALIASES[$name]+set}" ]]; then
    printf '%s\n' "${AE_MODULE_ALIASES[$name]}"
    return 0
  fi
  return 1
}

ae_runtime_main() {
  ae_load_modules

  local subcommand="${1:-}"
  if [[ -z "$subcommand" || "$subcommand" == "help" || "$subcommand" == "--help" || "$subcommand" == "-h" ]]; then
    ae_print_help
    return 0
  fi

  if [[ "$subcommand" == "version" || "$subcommand" == "--version" || "$subcommand" == "-v" ]]; then
    printf 'Archenemy v%s\n' "$AE_VERSION"
    return 0
  fi

  local module
  if ! module="$(ae_resolve_module "$subcommand")"; then
    ae_cli_log_error "Unknown command '$subcommand'"
    printf 'Run "ae help" to see available commands.\n'
    return 1
  fi
  shift

  local handler="${AE_MODULE_HANDLERS[$module]}"
  if [[ -z "$handler" ]]; then
    ae_cli_log_error "Module '$module' is not properly registered"
    return 1
  fi

  "$handler" "$@"
}
