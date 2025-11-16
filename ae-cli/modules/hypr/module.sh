#!/usr/bin/env bash

AE_MODULE_HYPR_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

ae_module_hypr_check() {
  if ! command -v hyprctl &>/dev/null; then
    ae_cli_log_error "Hyprland not running or hyprctl missing"
    return 1
  fi
}

ae_module_hypr_help() {
  local BOLD='' CYAN='' RESET=''
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  cat <<EOF
${BOLD}ae hypr${RESET} - Hyprland Control Interface

Usage:
  ae hypr <command>

Commands:
  ${CYAN}reload, r${RESET}        Reload Hyprland configuration
  ${CYAN}info, i${RESET}          Show system information
  ${CYAN}monitors, m${RESET}      Display monitor configuration
  ${CYAN}windows, w${RESET}       List open windows
  ${CYAN}workspaces, ws${RESET}   Show workspace overview
  ${CYAN}binds, k${RESET}         Display active keybindings
  ${CYAN}rules${RESET}            Show window rules
  ${CYAN}plugins${RESET}          List loaded plugins
  ${CYAN}logs${RESET}             Tail Hyprland logs
  ${CYAN}debug, d${RESET}         Show debug information
EOF
}

ae_module_hypr_reload() {
  printf 'Reloading Hyprland configuration...\n'
  hyprctl reload
  printf '[OK] Configuration reloaded\n'
}

ae_module_hypr_info() {
  printf 'System Information\n'
  hyprctl systeminfo
}

ae_module_hypr_monitors() {
  if command -v jq &>/dev/null; then
    hyprctl monitors -j | jq -r '.[] | "[\(.id)] \(.name) - \(.width)x\(.height)@\(.refreshRate)Hz (\(.x),\(.y))"'
  else
    hyprctl monitors
  fi
}

ae_module_hypr_clients() {
  if command -v jq &>/dev/null; then
    hyprctl clients -j | jq -r '.[] | "[\(.workspace.id)] \(.class) - \(.title)"'
  else
    hyprctl clients
  fi
}

ae_module_hypr_workspaces() {
  if command -v jq &>/dev/null; then
    hyprctl workspaces -j | jq -r '.[] | "Workspace \(.id): \(.windows) windows"'
  else
    hyprctl workspaces
  fi
}

ae_module_hypr_binds() {
  hyprctl binds | ${PAGER:-less}
}

ae_module_hypr_rules() {
  printf 'Window Rules\n'
  grep -E "^(windowrule|windowrulev2|layerrule)" ~/.config/hypr/**/*.conf 2>/dev/null || printf 'No rules found\n'
}

ae_module_hypr_plugins() {
  hyprctl plugins list
}

ae_module_hypr_logs() {
  local latest_dir
  latest_dir=$(find /tmp/hypr/ -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  local log_file="$latest_dir/hyprland.log"

  if [[ -f "$log_file" ]]; then
    tail -f "$log_file"
  else
    ae_cli_log_error "Log file not found"
    return 1
  fi
}

ae_module_hypr_debug() {
  local CYAN='' RESET=''
  if [[ -t 1 ]]; then
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  printf '%bDebug Information%b\n\n' "$CYAN" "$RESET"
  printf '%bVersion:%b\n' "$CYAN" "$RESET"
  hyprctl version
  printf '\n%bActive Window:%b\n' "$CYAN" "$RESET"
  hyprctl activewindow
  printf '\n%bCursor Position:%b\n' "$CYAN" "$RESET"
  hyprctl cursorpos
}

ae_module_hypr_main() {
  if ! ae_module_hypr_check; then
    return 1
  fi

  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    reload | r) ae_module_hypr_reload ;;
    info | i) ae_module_hypr_info ;;
    monitors | mon | m) ae_module_hypr_monitors ;;
    windows | win | w) ae_module_hypr_clients ;;
    workspaces | ws) ae_module_hypr_workspaces ;;
    binds | keys | k) ae_module_hypr_binds ;;
    rules) ae_module_hypr_rules ;;
    plugins | plug) ae_module_hypr_plugins ;;
    logs | log) ae_module_hypr_logs ;;
    debug | d) ae_module_hypr_debug ;;
    --help | -h | help | "")
      ae_module_hypr_help
      ;;
    *)
      ae_cli_log_error "Unknown command '$cmd'"
      ae_module_hypr_help
      return 1
      ;;
  esac
}

ae_register_module "hypr" ae_module_hypr_main "Hyprland control interface" "$AE_MODULE_HYPR_DIR" h
