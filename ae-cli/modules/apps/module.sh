#!/usr/bin/env bash

AE_MODULE_APPS_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

AE_APPS_COMMANDS=(
  launch_or_focus
  get_terminal_cwd
  launch_terminal_cwd
  launch_webapp
  launch_or_focus_webapp
  check_app_available
  launch_with_fallbacks
  get_app_workspace
  summon_app
)

ae_module_apps_usage() {
  cat <<'EOF'
Usage: ae apps <command>

Commands:
  launch_or_focus APP [CMD]
  get_terminal_cwd
  launch_terminal_cwd [TERMINAL]
  launch_webapp URL [BROWSER]
  launch_or_focus_webapp TITLE_PATTERN URL [BROWSER]
  check_app_available CMD [PKG]
  launch_with_fallbacks APP1 [APP2 ...]
  get_app_workspace APP_CLASS
  summon_app APP_CLASS

Extra:
  list     Show all commands
  help     Show this message
EOF
}

ae_apps_list_commands() {
  printf '%s\n' "${AE_APPS_COMMANDS[@]}"
}

ae_apps_launch_or_focus() {
  local app_pattern="$1"
  local launch_cmd="${2:-${app_pattern,,}}"

  if hyprctl clients -j | jq -e ".[] | select(.class | test(\"${app_pattern}\"; \"i\"))" >/dev/null 2>&1; then
    local address
    address="$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .address" | head -n1)"
    if [[ -n "$address" ]]; then
      hyprctl dispatch focuswindow "address:${address}"
      ae_cli_notify "󰘍  Switched" "Focused existing ${app_pattern}"
    fi
  else
    ae_cli_notify "  Launching" "${app_pattern}..."
    uwsm-app -- "${launch_cmd}" &
  fi
}

ae_apps_get_terminal_cwd() {
  local active_class
  active_class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')"

  case "${active_class,,}" in
    *kitty* | *alacritty* | *foot* | *wezterm* | *ghostty*)
      local active_pid
      active_pid="$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // 0')"
      if [[ "$active_pid" -gt 0 ]]; then
        local shell_pid
        shell_pid="$(pgrep -P "$active_pid" | head -n1)"
        if [[ -n "$shell_pid" && -d "/proc/${shell_pid}/cwd" ]]; then
          readlink "/proc/${shell_pid}/cwd" 2>/dev/null && return
        fi
        if [[ -d "/proc/${active_pid}/cwd" ]]; then
          readlink "/proc/${active_pid}/cwd" 2>/dev/null && return
        fi
      fi
      ;;
  esac

  echo "$HOME"
}

ae_apps_launch_terminal_cwd() {
  local terminal="${1:-kitty}"
  local cwd
  cwd="$(ae_apps_get_terminal_cwd)"

  case "${terminal,,}" in
    kitty) uwsm-app -- kitty --working-directory "$cwd" & ;;
    alacritty) uwsm-app -- alacritty --working-directory "$cwd" & ;;
    foot) uwsm-app -- foot -D "$cwd" & ;;
    wezterm) uwsm-app -- wezterm start --cwd "$cwd" & ;;
    ghostty) uwsm-app -- ghostty --working-directory "$cwd" & ;;
    *)
      (cd "$cwd" && uwsm-app -- "$terminal" &) ;;
  esac
}

ae_apps_launch_webapp() {
  local url="$1"
  local browser="${2:-chromium}"

  case "${browser,,}" in
    chromium | chrome | google-chrome) uwsm-app -- chromium --app="$url" & ;;
    brave | brave-browser) uwsm-app -- brave --app="$url" & ;;
    microsoft-edge | edge) uwsm-app -- microsoft-edge --app="$url" & ;;
    vivaldi) uwsm-app -- vivaldi --app="$url" & ;;
    *)
      uwsm-app -- "$browser" "$url" & ;;
  esac

  ae_cli_notify "  Web App" "Launching ${url##*/}"
}

ae_apps_launch_or_focus_webapp() {
  local title_pattern="$1"
  local url="$2"
  local browser="${3:-chromium}"

  if hyprctl clients -j | jq -e ".[] | select(.initialTitle | test(\"${title_pattern}\"; \"i\"))" >/dev/null 2>&1; then
    local address
    address="$(hyprctl clients -j | jq -r ".[] | select(.initialTitle | test(\"${title_pattern}\"; \"i\")) | .address" | head -n1)"
    if [[ -n "$address" ]]; then
      hyprctl dispatch focuswindow "address:${address}"
      ae_cli_notify "󰘍  Switched" "Focused ${title_pattern}"
    fi
  else
    ae_apps_launch_webapp "$url" "$browser"
  fi
}

ae_apps_check_app_available() {
  local cmd="$1"
  local pkg="${2:-$1}"

  if ! command -v "$cmd" &>/dev/null; then
    ae_cli_notify "  Not Installed" "${pkg} is not available. Install with: pacman -S ${pkg}"
    return 1
  fi
  return 0
}

ae_apps_launch_with_fallbacks() {
  for app in "$@"; do
    if command -v "$app" &>/dev/null; then
      uwsm-app -- "$app" &
      return 0
    fi
  done
  ae_cli_notify "  No Application Found" "None of the following are installed: $*"
  return 1
}

ae_apps_get_app_workspace() {
  local app_pattern="$1"
  hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .workspace.id" | head -n1
}

ae_apps_summon_app() {
  local app_pattern="$1"
  local address
  address="$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .address" | head -n1)"
  if [[ -n "$address" ]]; then
    local workspace
    workspace="$(hyprctl activeworkspace -j | jq -r '.id')"
    hyprctl dispatch movetoworkspacesilent "address:${address},${workspace}"
    hyprctl dispatch focuswindow "address:${address}"
    ae_cli_notify "  Summoned" "${app_pattern} moved to current workspace"
  else
    ae_cli_notify "  Not Running" "${app_pattern} is not currently running"
  fi
}

ae_module_apps_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    launch_or_focus) ae_apps_launch_or_focus "$@" ;;
    get_terminal_cwd) ae_apps_get_terminal_cwd "$@" ;;
    launch_terminal_cwd) ae_apps_launch_terminal_cwd "$@" ;;
    launch_webapp) ae_apps_launch_webapp "$@" ;;
    launch_or_focus_webapp) ae_apps_launch_or_focus_webapp "$@" ;;
    check_app_available) ae_apps_check_app_available "$@" ;;
    launch_with_fallbacks) ae_apps_launch_with_fallbacks "$@" ;;
    get_app_workspace) ae_apps_get_app_workspace "$@" ;;
    summon_app) ae_apps_summon_app "$@" ;;
    list) ae_apps_list_commands ;;
    help | --help | -h | "")
      ae_module_apps_usage
      [[ -z "$cmd" ]] && return 1 || return 0
      ;;
    *)
      ae_cli_log_error "Unknown apps command '$cmd'"
      ae_module_apps_usage
      return 1
      ;;
  esac
}

ae_register_module "apps" ae_module_apps_main "Application helper commands" "$AE_MODULE_APPS_DIR" a app
