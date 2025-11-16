#!/usr/bin/env bash

AE_MODULE_SYSTEM_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=modules/system/actions.sh
source "$AE_MODULE_SYSTEM_DIR/actions.sh"

ae_module_system_usage() {
  cat <<'EOF'
Usage: ae system <command>

Available commands:
  screenshot_edit
  screenshot_save
  screenshot_save_selection
  screenshot_window
  screenshot_clipboard
  screenshot_selection_clipboard
  toggle_gaps
  power_menu
  show_keybindings
  toggle_screenrecord
  screenrecord_selection
  show_network_info
  show_system_resources
  ocr_screenshot
  scan_qr_code
  emoji_picker
  share_menu
  share_clipboard
  share_file
  share_folder
  launch_walker
  toggle_idle_lock
  toggle_waybar
  show_battery
  launch_wifi

Extra commands:
  list        Print command list
  help        Show this message
EOF
}

ae_module_system_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    screenshot_edit) ae_system_screenshot_edit "$@" ;;
    screenshot_save) ae_system_screenshot_save "$@" ;;
    screenshot_save_selection) ae_system_screenshot_save_selection "$@" ;;
    screenshot_window) ae_system_screenshot_window "$@" ;;
    screenshot_clipboard) ae_system_screenshot_clipboard "$@" ;;
    screenshot_selection_clipboard) ae_system_screenshot_selection_clipboard "$@" ;;
    toggle_gaps) ae_system_toggle_gaps "$@" ;;
    power_menu) ae_system_power_menu "$@" ;;
    show_keybindings) ae_system_show_keybindings "$@" ;;
    toggle_screenrecord) ae_system_toggle_screenrecord "$@" ;;
    screenrecord_selection) ae_system_screenrecord_selection "$@" ;;
    show_network_info) ae_system_show_network_info "$@" ;;
    show_system_resources) ae_system_show_system_resources "$@" ;;
    ocr_screenshot) ae_system_ocr_screenshot "$@" ;;
    scan_qr_code) ae_system_scan_qr_code "$@" ;;
    emoji_picker) ae_system_emoji_picker "$@" ;;
    share_menu) ae_system_share_menu "$@" ;;
    share_clipboard) ae_system_share_clipboard "$@" ;;
    share_file) ae_system_share_file "$@" ;;
    share_folder) ae_system_share_folder "$@" ;;
    launch_walker) ae_system_launch_walker "$@" ;;
    toggle_idle_lock) ae_system_toggle_idle_lock "$@" ;;
    toggle_waybar) ae_system_toggle_waybar "$@" ;;
    show_battery) ae_system_show_battery "$@" ;;
    launch_wifi) ae_system_launch_wifi "$@" ;;
    list) ae_system_list_commands ;;
    help | --help | -h | "")
      ae_module_system_usage
      [[ -z "$cmd" ]] && return 1 || return 0
      ;;
    *)
      ae_cli_log_error "Unknown system command '$cmd'"
      ae_module_system_usage
      return 1
      ;;
  esac
}

ae_register_module "system" ae_module_system_main "System utility commands" "$AE_MODULE_SYSTEM_DIR" s sys
