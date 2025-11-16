#!/usr/bin/env bash

AE_MODULE_MENU_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=modules/menu/actions.sh
source "$AE_MODULE_MENU_DIR/actions.sh"
# Ensure system helpers exist for menu actions
# shellcheck source=modules/system/actions.sh
source "$AE_ROOT/modules/system/actions.sh"

ae_module_menu_usage() {
  cat <<'EOF'
Usage: ae menu <command>

Commands:
  trigger       Capture/share/toggle top-level menu
  capture       Screenshot/screenrecord/color submenu
  share         Clipboard/File/Folder share menu
  toggle        Screensaver/Nightlight/Idle lock/Waybar
  style         Theme/font/background menu
  setup         Audio/Wi-Fi/Bluetooth/etc.
  install       Package/AUR/Webapp/etc.

Extra:
  list          Show available menus
  help          Show this message
EOF
}

ae_module_menu_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    trigger) ae_menu_trigger "$@" ;;
    capture) ae_menu_capture "$@" ;;
    share) ae_menu_share "$@" ;;
    toggle) ae_menu_toggle "$@" ;;
    style) ae_menu_style "$@" ;;
    setup) ae_menu_setup "$@" ;;
    install) ae_menu_install "$@" ;;
    list) ae_menu_list_commands ;;
    help | --help | -h | "")
      ae_module_menu_usage
      [[ -z "$cmd" ]] && return 1 || return 0
      ;;
    *)
      ae_cli_log_error "ae menu: unknown command '$cmd'"
      ae_module_menu_usage
      return 1
      ;;
  esac
}

ae_register_module "menu" ae_module_menu_main "Session menus (capture/share/toggles)" "$AE_MODULE_MENU_DIR"
