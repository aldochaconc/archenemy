#!/usr/bin/env bash
#
# Application Launcher Helper Scripts
# Supporting scripts for apps.conf bindings
#

set -euo pipefail

# ============================================================================
# LAUNCH OR FOCUS
# ============================================================================
# Check if application is running, focus it if so, otherwise launch it
# Usage: launch_or_focus "app_class_or_name" ["launch_command"]
#
# Arguments:
#   $1: Window class or name to search for (regex pattern)
#   $2: Command to launch if not found (defaults to $1 in lowercase)
#
# Examples:
#   launch_or_focus "firefox" "firefox"
#   launch_or_focus "discord" "discord --enable-features=UseOzonePlatform --ozone-platform=wayland"
#   launch_or_focus "spotify"  # Will launch: spotify (lowercase of class)
#
launch_or_focus() {
  local app_pattern="$1"
  local launch_cmd="${2:-${app_pattern,,}}" # Default: lowercase of pattern

  # Check if app is already running
  if hyprctl clients -j | jq -e ".[] | select(.class | test(\"${app_pattern}\"; \"i\"))" >/dev/null 2>&1; then
    # App found, focus it
    local address
    address=$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .address" | head -n1)

    if [[ -n "$address" ]]; then
      hyprctl dispatch focuswindow "address:${address}"
      notify-send "󰘍  Switched" "Focused existing ${app_pattern}"
    fi
  else
    # App not found, launch it
    notify-send "  Launching" "${app_pattern}..."
    uwsm-app -- "${launch_cmd}" &
  fi
}

# ============================================================================
# GET TERMINAL CURRENT WORKING DIRECTORY
# ============================================================================
# Get the working directory of the currently focused terminal
# Returns the CWD or $HOME if not a terminal or can't determine
#
# Supports: kitty, Alacritty, foot, wezterm, ghostty
#
get_terminal_cwd() {
  local active_class
  active_class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // ""')

  # Check if active window is a terminal
  case "${active_class,,}" in
  *kitty* | *alacritty* | *foot* | *wezterm* | *ghostty*)
    # Get the PID of the active window
    local active_pid
    active_pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // 0')

    if [[ "$active_pid" -gt 0 ]]; then
      # Find the shell process (likely child of terminal)
      local shell_pid
      shell_pid=$(pgrep -P "$active_pid" | head -n1)

      if [[ -n "$shell_pid" ]]; then
        # Get CWD of shell process
        if [[ -d "/proc/${shell_pid}/cwd" ]]; then
          readlink "/proc/${shell_pid}/cwd" 2>/dev/null || echo "$HOME"
          return
        fi
      fi

      # Fallback: Use terminal process CWD
      if [[ -d "/proc/${active_pid}/cwd" ]]; then
        readlink "/proc/${active_pid}/cwd" 2>/dev/null || echo "$HOME"
        return
      fi
    fi
    ;;
  esac

  # Not a terminal or couldn't determine CWD
  echo "$HOME"
}

# ============================================================================
# LAUNCH TERMINAL WITH CWD
# ============================================================================
# Launch terminal in the current working directory of focused terminal
# Falls back to $HOME if not a terminal or can't determine
#
launch_terminal_cwd() {
  local cwd
  cwd=$(get_terminal_cwd)

  local terminal="${1:-kitty}" # Default to kitty if not specified

  case "${terminal,,}" in
  kitty)
    uwsm-app -- kitty --working-directory "$cwd" &
    ;;
  alacritty)
    uwsm-app -- alacritty --working-directory "$cwd" &
    ;;
  foot)
    uwsm-app -- foot -D "$cwd" &
    ;;
  wezterm)
    uwsm-app -- wezterm start --cwd "$cwd" &
    ;;
  ghostty)
    uwsm-app -- ghostty --working-directory "$cwd" &
    ;;
  *)
    # Generic fallback
    cd "$cwd" && uwsm-app -- "$terminal" &
    ;;
  esac
}

# ============================================================================
# LAUNCH WEB APPLICATION
# ============================================================================
# Launch web application in browser app mode (looks like native app)
# Usage: launch_webapp "URL" ["browser"]
#
# Arguments:
#   $1: URL to open
#   $2: Browser to use (optional, defaults to chromium)
#
# Examples:
#   launch_webapp "https://chatgpt.com"
#   launch_webapp "https://web.whatsapp.com" "brave"
#   launch_webapp "https://gmail.com"
#
launch_webapp() {
  local url="$1"
  local browser="${2:-chromium}" # Default to chromium

  # Determine the correct flags for the browser
  case "${browser,,}" in
  chromium | chrome | google-chrome)
    uwsm-app -- chromium --app="$url" &
    ;;
  brave | brave-browser)
    uwsm-app -- brave --app="$url" &
    ;;
  microsoft-edge | edge)
    uwsm-app -- microsoft-edge --app="$url" &
    ;;
  vivaldi)
    uwsm-app -- vivaldi --app="$url" &
    ;;
  *)
    # Fallback: open in new window
    uwsm-app -- "$browser" "$url" &
    ;;
  esac

  notify-send "  Web App" "Launching ${url##*/}"
}

# ============================================================================
# LAUNCH OR FOCUS WEB APPLICATION
# ============================================================================
# Like launch_or_focus but for web apps (checks by initialTitle)
# Usage: launch_or_focus_webapp "TITLE_PATTERN" "URL" ["browser"]
#
launch_or_focus_webapp() {
  local title_pattern="$1"
  local url="$2"
  local browser="${3:-chromium}"

  # Check if web app is already running (by initialTitle)
  if hyprctl clients -j | jq -e ".[] | select(.initialTitle | test(\"${title_pattern}\"; \"i\"))" >/dev/null 2>&1; then
    # Web app found, focus it
    local address
    address=$(hyprctl clients -j | jq -r ".[] | select(.initialTitle | test(\"${title_pattern}\"; \"i\")) | .address" | head -n1)

    if [[ -n "$address" ]]; then
      hyprctl dispatch focuswindow "address:${address}"
      notify-send "󰘍  Switched" "Focused ${title_pattern}"
    fi
  else
    # Web app not found, launch it
    launch_webapp "$url" "$browser"
  fi
}

# ============================================================================
# CHECK APPLICATION AVAILABILITY
# ============================================================================
# Check if an application is installed before trying to launch
# Usage: check_app_available "command_name" "package_name"
#
check_app_available() {
  local cmd="$1"
  local pkg="${2:-$1}"

  if ! command -v "$cmd" &>/dev/null; then
    notify-send "  Not Installed" "${pkg} is not available. Install with: pacman -S ${pkg}"
    return 1
  fi
  return 0
}

# ============================================================================
# LAUNCH WITH FALLBACKS
# ============================================================================
# Try launching app, with fallbacks if not available
# Usage: launch_with_fallbacks "app1" "app2" "app3"
#
launch_with_fallbacks() {
  for app in "$@"; do
    if command -v "$app" &>/dev/null; then
      uwsm-app -- "$app" &
      return 0
    fi
  done

  notify-send "  No Application Found" "None of the following are installed: $*"
  return 1
}

# ============================================================================
# GET WORKSPACE OF APP
# ============================================================================
# Find which workspace an app is on
# Usage: get_app_workspace "app_class_pattern"
#
get_app_workspace() {
  local app_pattern="$1"

  hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .workspace.id" | head -n1
}

# ============================================================================
# MOVE APP TO CURRENT WORKSPACE
# ============================================================================
# Move an application to the current workspace and focus it
# Usage: summon_app "app_class_pattern"
#
summon_app() {
  local app_pattern="$1"

  # Get app window address
  local address
  address=$(hyprctl clients -j | jq -r ".[] | select(.class | test(\"${app_pattern}\"; \"i\")) | .address" | head -n1)

  if [[ -n "$address" ]]; then
    # Move to current workspace and focus
    hyprctl dispatch movetoworkspacesilent "address:${address},$(hyprctl activeworkspace -j | jq -r '.id')"
    hyprctl dispatch focuswindow "address:${address}"
    notify-send "  Summoned" "${app_pattern} moved to current workspace"
  else
    notify-send "  Not Running" "${app_pattern} is not currently running"
  fi
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================
# Allow calling functions directly from command line
# Usage: ./apps.sh function_name [args...]
#
if [[ $# -gt 0 ]]; then
  function_name="$1"
  shift

  # Check if function exists
  if declare -f "$function_name" >/dev/null; then
    "$function_name" "$@"
  else
    echo "Error: Function '$function_name' not found"
    echo "Available functions:"
    echo "  - launch_or_focus APP_CLASS [LAUNCH_CMD]"
    echo "  - get_terminal_cwd"
    echo "  - launch_terminal_cwd [TERMINAL]"
    echo "  - launch_webapp URL [BROWSER]"
    echo "  - launch_or_focus_webapp TITLE_PATTERN URL [BROWSER]"
    echo "  - check_app_available CMD [PKG]"
    echo "  - launch_with_fallbacks APP1 [APP2 APP3...]"
    echo "  - get_app_workspace APP_CLASS"
    echo "  - summon_app APP_CLASS"
    exit 1
  fi
fi
