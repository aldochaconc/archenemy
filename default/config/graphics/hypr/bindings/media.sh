#!/usr/bin/env bash
#
# Media Control Helper Scripts
# Supporting scripts for media.conf bindings
#

set -euo pipefail

# ============================================================================
# SWITCH AUDIO OUTPUT
# ============================================================================
# Cycle through available audio output devices (sinks)
# Usage: switch_audio_output
#
# Cycles between: speakers, headphones, HDMI, USB audio, etc.
# Uses wireplumber/pipewire (wpctl) or pulseaudio (pactl)
#
switch_audio_output() {
  # Check if wpctl (wireplumber) is available
  if command -v wpctl &>/dev/null; then
    # Get list of audio sinks
    local sinks
    sinks=$(wpctl status | awk '/Sinks:/,/Sources:/' | grep -E '^\s*[0-9]+\.' | grep -v 'Sources:')

    # Get current default sink ID
    local current_sink
    current_sink=$(wpctl status | awk '/Sinks:/,/Sources:/' | grep '\*' | grep -oP '^\s*\K[0-9]+')

    # Get sink IDs into array
    local sink_ids=()
    while IFS= read -r line; do
      local id
      id=$(echo "$line" | grep -oP '^\s*\K[0-9]+')
      sink_ids+=("$id")
    done <<<"$sinks"

    # Find current index and get next sink
    local next_sink=""
    for i in "${!sink_ids[@]}"; do
      if [[ "${sink_ids[$i]}" == "$current_sink" ]]; then
        # Get next sink (wrap around if at end)
        local next_index=$(((i + 1) % ${#sink_ids[@]}))
        next_sink="${sink_ids[$next_index]}"
        break
      fi
    done

    # If we found next sink, switch to it
    if [[ -n "$next_sink" ]]; then
      wpctl set-default "$next_sink"

      # Get sink name for notification
      local sink_name
      sink_name=$(wpctl status | grep "^\\s*$next_sink\\." | sed 's/^[^.]*\. //' | sed 's/ \[.*//')
      notify-send "  Audio Output" "Switched to: $sink_name"
    else
      notify-send "  Audio Output" "Could not determine next output"
    fi

  elif command -v pactl &>/dev/null; then
    # Fallback to PulseAudio
    local sinks
    sinks=$(pactl list short sinks | awk '{print $1}')

    # Get current default sink
    local current_sink
    current_sink=$(pactl get-default-sink)
    local current_id
    current_id=$(pactl list short sinks | grep "$current_sink" | awk '{print $1}')

    # Get sink IDs into array
    local sink_ids=()
    while IFS= read -r id; do
      sink_ids+=("$id")
    done <<<"$sinks"

    # Find next sink
    local next_sink=""
    for i in "${!sink_ids[@]}"; do
      if [[ "${sink_ids[$i]}" == "$current_id" ]]; then
        local next_index=$(((i + 1) % ${#sink_ids[@]}))
        next_sink="${sink_ids[$next_index]}"
        break
      fi
    done

    if [[ -n "$next_sink" ]]; then
      local sink_name
      sink_name=$(pactl list short sinks | awk -v id="$next_sink" '$1 == id {print $2}')
      pactl set-default-sink "$sink_name"

      local friendly_name
      friendly_name=$(pactl list sinks | grep -A 20 "Name: $sink_name" | grep "Description:" | sed 's/.*Description: //')
      notify-send "  Audio Output" "Switched to: $friendly_name"
    else
      notify-send "  Audio Output" "Could not determine next output"
    fi
  else
    notify-send "  Error" "Neither wpctl nor pactl found"
  fi
}

# ============================================================================
# GET FOCUSED MONITOR
# ============================================================================
# Get the name of the currently focused monitor
# Usage: get_focused_monitor
#
# Returns: Monitor name (e.g., "eDP-1", "DP-1", "HDMI-A-1")
#
get_focused_monitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true).name'
}

# ============================================================================
# TOGGLE NIGHTLIGHT
# ============================================================================
# Toggle hyprsunset temperature for blue light filtering
# Usage: toggle_nightlight
#
# Toggles between:
#   - 6000K (daytime, no filter)
#   - 4000K (nighttime, warm/orange tint)
#
toggle_nightlight() {
  # Check if hyprsunset is running
  if ! pgrep -x hyprsunset >/dev/null; then
    notify-send "  Nightlight" "hyprsunset not running"
    return 1
  fi

  # Get current temperature
  local current_temp
  current_temp=$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE "[0-9]+" || echo "6000")

  # Toggle between day (6000K) and night (4000K)
  if [[ "$current_temp" -le 4500 ]]; then
    # Currently in night mode, switch to day
    hyprctl hyprsunset temperature 6000
    notify-send "  Nightlight Disabled" "Color temperature: 6000K (neutral)"
  else
    # Currently in day mode, switch to night
    hyprctl hyprsunset temperature 4000
    notify-send "  Nightlight Enabled" "Color temperature: 4000K (warm)"
  fi
}

# ============================================================================
# GET CURRENT VOLUME
# ============================================================================
# Get the current volume percentage
# Usage: get_current_volume
#
# Returns: Volume percentage (0-100)
#
get_current_volume() {
  if command -v wpctl &>/dev/null; then
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
  elif command -v pactl &>/dev/null; then
    pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1 | tr -d '%'
  else
    echo "0"
  fi
}

# ============================================================================
# GET CURRENT BRIGHTNESS
# ============================================================================
# Get the current screen brightness percentage
# Usage: get_current_brightness
#
# Returns: Brightness percentage (0-100)
#
get_current_brightness() {
  if command -v brightnessctl &>/dev/null; then
    brightnessctl get | awk '{printf "%.0f", $1}'
    echo "%" # Print percentage sign
    local max
    max=$(brightnessctl max)
    local current
    current=$(brightnessctl get)
    echo $((current * 100 / max))
  else
    echo "0"
  fi
}

# ============================================================================
# APPLE DISPLAY BRIGHTNESS CONTROL
# ============================================================================
# Control brightness of Apple external displays (XDR, Studio Display, etc.)
# Usage: apple_display_brightness [+/-]VALUE
#
# Arguments:
#   +5000: Increase brightness by 5000 units
#   -5000: Decrease brightness by 5000 units
#   +60000: Set to maximum brightness
#
# Requires: m1ddc or displayplacer or ddcutil with Apple support
#
apple_display_brightness() {
  local change="$1"

  # Check if m1ddc is available (best for Apple Silicon Macs)
  if command -v m1ddc &>/dev/null; then
    # Get current brightness
    local current
    current=$(m1ddc get brightness 2>/dev/null | grep -oP '\d+' | head -n1)

    # Calculate new brightness
    local new_brightness
    if [[ "$change" =~ ^\+([0-9]+)$ ]]; then
      new_brightness=$((current + ${BASH_REMATCH[1]}))
    elif [[ "$change" =~ ^\-([0-9]+)$ ]]; then
      new_brightness=$((current - ${BASH_REMATCH[1]}))
    else
      new_brightness="$change"
    fi

    # Clamp to valid range (0-65535 for Apple displays)
    [[ "$new_brightness" -lt 0 ]] && new_brightness=0
    [[ "$new_brightness" -gt 65535 ]] && new_brightness=65535

    # Set brightness
    m1ddc set brightness "$new_brightness"

    # Calculate percentage for notification
    local percent=$((new_brightness * 100 / 65535))
    notify-send "  Display Brightness" "External display: ${percent}%"

  elif command -v ddcutil &>/dev/null; then
    # Fallback to ddcutil (works with some Apple displays)
    local current
    current=$(ddcutil getvcp 10 | grep -oP 'current value =\s+\K\d+')

    local new_brightness
    if [[ "$change" =~ ^\+([0-9]+)$ ]]; then
      new_brightness=$((current + ${BASH_REMATCH[1]} / 655)) # Scale down
    elif [[ "$change" =~ ^\-([0-9]+)$ ]]; then
      new_brightness=$((current - ${BASH_REMATCH[1]} / 655))
    else
      new_brightness=$((change / 655))
    fi

    # Clamp to 0-100 (ddcutil percentage)
    [[ "$new_brightness" -lt 0 ]] && new_brightness=0
    [[ "$new_brightness" -gt 100 ]] && new_brightness=100

    ddcutil setvcp 10 "$new_brightness"
    notify-send "  Display Brightness" "External display: ${new_brightness}%"

  else
    notify-send "  Error" "No display control tool found (m1ddc, ddcutil)"
    return 1
  fi
}

# ============================================================================
# SHOW CURRENT MEDIA INFO
# ============================================================================
# Display currently playing media information
# Usage: show_media_info
#
show_media_info() {
  if ! command -v playerctl &>/dev/null; then
    notify-send "  Media Info" "playerctl not installed"
    return 1
  fi

  # Check if any player is running
  if ! playerctl status &>/dev/null; then
    notify-send "  No Media Playing" "No active media players found"
    return 0
  fi

  # Get media info
  local artist
  artist=$(playerctl metadata artist 2>/dev/null || echo "Unknown Artist")
  local title
  title=$(playerctl metadata title 2>/dev/null || echo "Unknown Title")
  local status
  status=$(playerctl status 2>/dev/null || echo "Unknown")
  local player
  player=$(playerctl metadata --format "{{playerName}}" 2>/dev/null || echo "Unknown Player")

  # Format status icon
  local status_icon=""
  case "$status" in
  Playing) status_icon="" ;;
  Paused) status_icon="" ;;
  Stopped) status_icon="" ;;
  *) status_icon="" ;;
  esac

  notify-send "$status_icon  $player" "$artist - $title\nStatus: $status"
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================
# Allow calling functions directly from command line
# Usage: ./media.sh function_name [args...]
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
    echo "  - switch_audio_output"
    echo "  - get_focused_monitor"
    echo "  - toggle_nightlight"
    echo "  - get_current_volume"
    echo "  - get_current_brightness"
    echo "  - apple_display_brightness CHANGE"
    echo "  - show_media_info"
    exit 1
  fi
fi
