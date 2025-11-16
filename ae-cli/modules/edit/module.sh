#!/usr/bin/env bash

AE_MODULE_EDIT_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

ae_module_edit_show_help() {
  local BOLD='' CYAN='' RESET=''
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  cat <<EOF
${BOLD}ae edit${RESET} - Configuration Editor

Usage:
  ae edit [target]

Targets:
  ${CYAN}hyprland${RESET}      Main Hyprland config
  ${CYAN}envs${RESET}          Environment variables
  ${CYAN}monitors${RESET}      Monitor configuration
  ${CYAN}input${RESET}         Input device settings
  ${CYAN}looknfeel${RESET}     Appearance settings
  ${CYAN}autostart${RESET}     Startup applications
  ${CYAN}windows${RESET}       Window rules
  ${CYAN}bindings${RESET}      Keybinding directory
  ${CYAN}vim${RESET}           Vim navigation bindings
  ${CYAN}apps${RESET}          App-specific rules
  ${CYAN}waybar${RESET}        Waybar configuration
  ${CYAN}mako${RESET}          Mako notifications
  ${CYAN}kitty${RESET}         Kitty terminal

If no target is specified, shows an interactive menu (requires fzf).
EOF
}

ae_module_edit_edit_file() {
  local file="$1"
  local editor="${EDITOR:-nvim}"
  if [[ ! -f "$file" ]]; then
    ae_cli_log_error "File not found: $file"
    return 1
  fi
  "$editor" "$file"
}

ae_module_edit_show_menu() {
  if ! command -v fzf &>/dev/null; then
    ae_cli_log_error "fzf required for interactive mode. Example: ae edit hyprland"
    return 1
  fi

  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local hypr_dir="$config_dir/hypr"
  local -a files=(
    "hyprland.conf:$hypr_dir/hyprland.conf"
    "envs.conf:$hypr_dir/envs.conf"
    "monitors.conf:$hypr_dir/monitors.conf"
    "input.conf:$hypr_dir/input.conf"
    "looknfeel.conf:$hypr_dir/looknfeel.conf"
    "autostart.conf:$hypr_dir/autostart.conf"
    "windows.conf:$hypr_dir/windows.conf"
    "vim-nav.conf:$hypr_dir/bindings/vim-nav.conf"
    "apps.conf:$hypr_dir/bindings/apps.conf"
    "tiling.conf:$hypr_dir/bindings/tiling.conf"
    "waybar:$config_dir/waybar/config"
    "mako:$config_dir/mako/config"
    "kitty:$config_dir/kitty/kitty.conf"
  )

  local choice
  choice=$(printf '%s\n' "${files[@]}" | cut -d: -f1 | fzf --header="Select config to edit")

  if [[ -n "$choice" ]]; then
    local entry
    for entry in "${files[@]}"; do
      if [[ "${entry%%:*}" == "$choice" ]]; then
        ae_module_edit_edit_file "${entry#*:}"
        break
      fi
    done
  fi
}

ae_module_edit_main() {
  local target="${1:-}"
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  local hypr_dir="$config_dir/hypr"
  local editor="${EDITOR:-nvim}"

  case "$target" in
    hyprland)
      ae_module_edit_edit_file "$hypr_dir/hyprland.conf"
      ;;
    envs)
      ae_module_edit_edit_file "$hypr_dir/envs.conf"
      ;;
    monitors)
      ae_module_edit_edit_file "$hypr_dir/monitors.conf"
      ;;
    input)
      ae_module_edit_edit_file "$hypr_dir/input.conf"
      ;;
    looknfeel)
      ae_module_edit_edit_file "$hypr_dir/looknfeel.conf"
      ;;
    autostart)
      ae_module_edit_edit_file "$hypr_dir/autostart.conf"
      ;;
    windows)
      ae_module_edit_edit_file "$hypr_dir/windows.conf"
      ;;
    bindings)
      (cd "$hypr_dir/bindings" && "$editor" .)
      ;;
    vim)
      ae_module_edit_edit_file "$hypr_dir/bindings/vim-nav.conf"
      ;;
    apps)
      (cd "$hypr_dir/apps" && "$editor" .)
      ;;
    waybar)
      ae_module_edit_edit_file "$config_dir/waybar/config"
      ;;
    mako)
      ae_module_edit_edit_file "$config_dir/mako/config"
      ;;
    kitty)
      ae_module_edit_edit_file "$config_dir/kitty/kitty.conf"
      ;;
    --help | -h)
      ae_module_edit_show_help
      ;;
    "")
      ae_module_edit_show_menu
      ;;
    *)
      ae_cli_log_error "Unknown target '$target'"
      ae_module_edit_show_help
      return 1
      ;;
  esac
}

ae_register_module "edit" ae_module_edit_main "Configuration editor" "$AE_MODULE_EDIT_DIR" e
