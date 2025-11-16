#!/usr/bin/env bash

AE_MODULE_REFRESH_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=modules/refresh/actions.sh
source "$AE_MODULE_REFRESH_DIR/actions.sh"

ae_module_refresh_usage() {
  cat <<'EOF'
Usage: ae refresh <command>

Commands:
  hyprland           Sync configs + hyprctl reload
  hypridle           Copy defaults + restart hypridle
  hyprlock           Copy hyprlock config
  hyprsunset         Copy config + restart hyprsunset
  walker             Sync walker config + restart
  waybar             Sync waybar config + restart/toggle
  swayosd            Sync swayosd config + restart
  hypridle-restart   Restart hypridle only
  hyprsunset-restart Restart hyprsunset only
  walker-restart     Restart walker only
  waybar-restart     Restart waybar only
  swayosd-restart    Restart swayosd only

Extra:
  list               Show available commands
  help               Show this message
EOF
}

ae_module_refresh_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    hyprland) ae_refresh_hyprland "$@" ;;
    hypridle) ae_refresh_hypridle "$@" ;;
    hyprlock) ae_refresh_hyprlock "$@" ;;
    hyprsunset) ae_refresh_hyprsunset "$@" ;;
    walker) ae_refresh_walker "$@" ;;
    waybar) ae_refresh_waybar "$@" ;;
    swayosd) ae_refresh_swayosd "$@" ;;
    hypridle-restart) ae_refresh_hypridle_restart "$@" ;;
    hyprsunset-restart) ae_refresh_hyprsunset_restart "$@" ;;
    walker-restart) ae_refresh_walker_restart "$@" ;;
    waybar-restart) ae_refresh_waybar_restart "$@" ;;
    swayosd-restart) ae_refresh_swayosd_restart "$@" ;;
    list) ae_refresh_list_commands ;;
    help | --help | -h | "")
      ae_module_refresh_usage
      [[ -z "$cmd" ]] && return 1 || return 0
      ;;
    *)
      ae_cli_log_error "ae refresh: unknown command '$cmd'"
      ae_module_refresh_usage
      return 1
      ;;
  esac
}

ae_register_module "refresh" ae_module_refresh_main "Sync/restart session components" "$AE_MODULE_REFRESH_DIR"
