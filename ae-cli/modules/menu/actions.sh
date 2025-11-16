#!/usr/bin/env bash

if [[ "${AE_MENU_COMMANDS_SOURCED:-false}" == true ]]; then
  return 0
fi
AE_MENU_COMMANDS_SOURCED=true

AE_MENU_COMMANDS=(
  trigger
  capture
  share
  toggle
  setup
  install
  style
)

ae_menu_list_commands() {
  printf '%s\n' "${AE_MENU_COMMANDS[@]}"
}

_ae_menu_run_launcher() {
  local prompt="$1"
  local options="$2"
  local extra_args="$3"

  read -r -a args <<<"$extra_args"

  if command -v walker >/dev/null 2>&1; then
    echo -e "$options" | walker --dmenu --width 295 --minheight 1 --maxheight 600 -p "$prompt…" "${args[@]}" 2>/dev/null
  elif command -v rofi >/dev/null 2>&1; then
    echo -e "$options" | rofi -dmenu -p "$prompt…" "${args[@]}" 2>/dev/null
  else
    echo -e "$options" | fzf --prompt "$prompt> " 2>/dev/null
  fi
}

ae_menu_trigger() {
  case "$(_ae_menu_run_launcher \
    "Trigger" \
    "  Capture\n  Share\n󰔎  Toggle" \
    "")" in
    *Capture*) ae_menu_capture ;;
    *Share*) ae_menu_share ;;
    *Toggle*) ae_menu_toggle ;;
  esac
}

ae_menu_capture() {
  case "$(_ae_menu_run_launcher \
    "Capture" \
    "  Screenshot\n  Screenrecord\n󰃉  Color Picker" \
    "")" in
    *Screenshot*) ae_menu_screenshot ;;
    *Screenrecord*) ae_menu_screenrecord ;;
    *Color*) pkill hyprpicker >/dev/null 2>&1 || hyprpicker -a ;;
  esac
}

ae_menu_screenshot() {
  case "$(_ae_menu_run_launcher \
    "Screenshot" \
    "  Snap with Editing\n  Clipboard\n  Save to File" \
    "")" in
    *Editing*) ae_system_screenshot_edit ;;
    *Clipboard*) ae_system_screenshot_clipboard ;;
    *File*) ae_system_screenshot_save ;;
  esac
}

ae_menu_screenrecord() {
  case "$(_ae_menu_run_launcher \
    "Screenrecord" \
    "  Region\n  Display" \
    "")" in
    *Region*) ae_system_screenrecord_selection ;;
    *Display*) ae_system_toggle_screenrecord ;;
  esac
}

ae_menu_share() {
  case "$(_ae_menu_run_launcher \
    "Share" \
    "  Clipboard\n  File\n  Folder" \
    "")" in
    *Clipboard*) ae_system_share_clipboard ;;
    *File*) ae_system_share_file ;;
    *Folder*) ae_system_share_folder ;;
  esac
}

ae_menu_toggle() {
  case "$(_ae_menu_run_launcher \
    "Toggle" \
    "󱄄  Screensaver\n󰔎  Nightlight\n󱫖  Idle Lock\n󰍜  Top Bar" \
    "")" in
    *Screensaver*) if pgrep -f swayidle >/dev/null 2>&1; then pkill -f swayidle; else setsid swayidle >/dev/null 2>&1 & fi ;;
    *Nightlight*) ae_cli_notify "  Nightlight" "Use ae media toggle_nightlight" && "$ARCHENEMY_PATH/ae-cli/ae" media toggle_nightlight ;;
    *Idle*) ae_system_toggle_idle_lock ;;
    *Top*) ae_system_toggle_waybar ;;
  esac
}

ae_menu_style() {
  case "$(_ae_menu_run_launcher \
    "Style" \
    "󰸌  Theme\n  Font\n  Background\n  Hyprland\n󱄄  Screensaver\n  About" \
    "")" in
    *Theme*) ae_cli_notify "  Theme" "Open ~/.config/hypr/looknfeel.conf to edit theme." ;;
    *Font*) ae_cli_notify "  Font" "Change font via your terminal/theme settings." ;;
    *Background*) ae_cli_notify "  Background" "Set wallpaper via your theme manager." ;;
    *Hyprland*) if command -v "${EDITOR:-nano}" >/dev/null 2>&1; then "${EDITOR:-nano}" ~/.config/hypr/hyprland.conf; fi ;;
    *Screensaver*) if command -v "${EDITOR:-nano}" >/dev/null 2>&1; then "${EDITOR:-nano}" ~/.config/archenemy/branding/screensaver.txt; fi ;;
    *About*) if command -v "${EDITOR:-nano}" >/dev/null 2>&1; then "${EDITOR:-nano}" ~/.config/archenemy/branding/about.txt; fi ;;
  esac
}

ae_menu_setup() {
  local options="  Audio\n  Wifi\n󰂯  Bluetooth\n󱐋  Power Profile\n󰍹  Monitors"
  [ -f ~/.config/hypr/bindings.conf ] && options="$options\n  Keybindings"
  [ -f ~/.config/hypr/input.conf ] && options="$options\n  Input"
  options="$options\n  Defaults\n󰱔  DNS\n  Security\n  Config"

  case "$(_ae_menu_run_launcher "Setup" "$options" "")" in
    *Audio*) if command -v wiremix >/dev/null 2>&1; then wiremix; fi ;;
    *Wifi*) ae_system_launch_wifi ;;
    *Bluetooth*) blueman-manager >/dev/null 2>&1 & ;;
    *Power*) if command -v powerprofilesctl >/dev/null 2>&1; then
      local profile
      profile="$(powerprofilesctl list | awk '/Active:/ {print $2}')"
      powerprofilesctl set "$profile"
    fi ;;
    *Monitors*) "${EDITOR:-nano}" ~/.config/hypr/monitors.conf ;;
    *Keybindings*) "${EDITOR:-nano}" ~/.config/hypr/bindings.conf ;;
    *Input*) "${EDITOR:-nano}" ~/.config/hypr/input.conf ;;
    *Defaults*) "${EDITOR:-nano}" ~/.config/uwsm/default ;;
    *DNS*) ae_cli_notify "  Setup" "Configure DNS via system settings." ;;
    *Security*) ae_cli_notify "  Setup" "Security setup TODO." ;;
    *Config*) ae_cli_notify "  Setup" "Edit configs under ~/.config/hypr/..." ;;
  esac
}

ae_menu_install() {
  local options="󰣇  Package\n󰣇  AUR\n  Web App\n  Service\n  Style\n󰵮  Development\n  Editor\n  Terminal\n󱚤  AI\n󰍲  Windows\n  Gaming"
  case "$(_ae_menu_run_launcher "Install" "$options" "")" in
    *Package*) ae_cli_notify "  Install" "Use pacman/yay manually for now." ;;
    *AUR*) ae_cli_notify "  Install" "Use yay manually for now." ;;
    *Web*) ae_cli_notify "  Install" "Use ae apps launch_webapp to pin PWAs." ;;
    *Service*) ae_cli_notify "  Install" "Service install TBD." ;;
    *Style*) ae_menu_style ;;
    *Development*) ae_cli_notify "  Install" "Dev env install TBD." ;;
    *Editor*) ae_cli_notify "  Install" "Editor install TBD." ;;
    *Terminal*) ae_cli_notify "  Install" "Terminal install TBD." ;;
    *AI*) ae_cli_notify "  Install" "AI tools install TBD." ;;
    *Windows*) ae_cli_notify "  Install" "Windows VM install TBD." ;;
    *Gaming*) ae_cli_notify "  Install" "Gaming setup TBD." ;;
  esac
}
