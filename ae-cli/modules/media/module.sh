#!/usr/bin/env bash

AE_MODULE_MEDIA_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

AE_MEDIA_COMMANDS=(
  switch_audio_output
  get_focused_monitor
  toggle_nightlight
  get_current_volume
  get_current_brightness
  apple_display_brightness
  show_media_info
)

ae_module_media_usage() {
  cat <<'EOF'
Usage: ae media <command>

Commands:
  switch_audio_output
  get_focused_monitor
  toggle_nightlight
  get_current_volume
  get_current_brightness
  apple_display_brightness CHANGE
  show_media_info

Extra:
  list     Show all commands
  help     Show this message
EOF
}

ae_media_list_commands() {
  printf '%s\n' "${AE_MEDIA_COMMANDS[@]}"
}

ae_media_switch_audio_output() {
  if command -v wpctl >/dev/null 2>&1; then
    local sinks
    sinks="$(wpctl status | awk '/Sinks:/,/Sources:/' | grep -E '^\s*[0-9]+\.' | grep -v 'Sources:')"
    local current_sink
    current_sink="$(wpctl status | awk '/Sinks:/,/Sources:/' | grep '\*' | grep -oP '^\s*\K[0-9]+')"
    local sink_ids=()
    while IFS= read -r line; do
      local id
      id="$(echo "$line" | grep -oP '^\s*\K[0-9]+')"
      sink_ids+=("$id")
    done <<<"$sinks"

    local next_sink=""
    local i
    for i in "${!sink_ids[@]}"; do
      if [[ "${sink_ids[$i]}" == "$current_sink" ]]; then
        local next_index=$(((i + 1) % ${#sink_ids[@]}))
        next_sink="${sink_ids[$next_index]}"
        break
      fi
    done

    if [[ -n "$next_sink" ]]; then
      wpctl set-default "$next_sink"
      local sink_name
      sink_name="$(wpctl status | grep "^\\s*$next_sink\\." | sed 's/^[^.]*\. //' | sed 's/ \[.*//')"
      ae_cli_notify "  Audio Output" "Switched to: $sink_name"
    else
      ae_cli_notify "  Audio Output" "Could not determine next output"
    fi
    return
  fi

  if command -v pactl >/dev/null 2>&1; then
    local sinks
    sinks="$(pactl list short sinks | awk '{print $1}')"
    local current_sink
    current_sink="$(pactl get-default-sink)"
    local current_id
    current_id="$(pactl list short sinks | grep "$current_sink" | awk '{print $1}')"
    local sink_ids=()
    while IFS= read -r id; do
      sink_ids+=("$id")
    done <<<"$sinks"

    local next_sink=""
    local i
    for i in "${!sink_ids[@]}"; do
      if [[ "${sink_ids[$i]}" == "$current_id" ]]; then
        local next_index=$(((i + 1) % ${#sink_ids[@]}))
        next_sink="${sink_ids[$next_index]}"
        break
      fi
    done

    if [[ -n "$next_sink" ]]; then
      local sink_name
      sink_name="$(pactl list short sinks | awk -v id="$next_sink" '$1 == id {print $2}')"
      pactl set-default-sink "$sink_name"
      local friendly_name
      friendly_name="$(pactl list sinks | grep -A 20 "Name: $sink_name" | grep "Description:" | sed 's/.*Description: //')"
      ae_cli_notify "  Audio Output" "Switched to: $friendly_name"
    else
      ae_cli_notify "  Audio Output" "Could not determine next output"
    fi
    return
  fi

  ae_cli_notify "  Error" "Neither wpctl nor pactl found"
}

ae_media_get_focused_monitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true).name'
}

ae_media_toggle_nightlight() {
  if ! pgrep -x hyprsunset >/dev/null; then
    ae_cli_notify "  Nightlight" "hyprsunset not running"
    return 1
  fi
  local current_temp
  current_temp="$(hyprctl hyprsunset temperature 2>/dev/null | grep -oE "[0-9]+" || echo "6000")"
  if [[ "$current_temp" -le 4500 ]]; then
    hyprctl hyprsunset temperature 6000
    ae_cli_notify "  Nightlight Disabled" "Color temperature: 6000K (neutral)"
  else
    hyprctl hyprsunset temperature 4000
    ae_cli_notify "  Nightlight Enabled" "Color temperature: 4000K (warm)"
  fi
}

ae_media_get_current_volume() {
  if command -v wpctl >/dev/null 2>&1; then
    wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
  elif command -v pactl >/dev/null 2>&1; then
    pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1 | tr -d '%'
  else
    echo "0"
  fi
}

ae_media_get_current_brightness() {
  if command -v brightnessctl >/dev/null 2>&1; then
    local max current
    max="$(brightnessctl max)"
    current="$(brightnessctl get)"
    if [[ -n "$max" && "$max" -gt 0 ]]; then
      echo $((current * 100 / max))
      return
    fi
  fi
  echo "0"
}

ae_media_apple_display_brightness() {
  local change="$1"
  if command -v m1ddc >/dev/null 2>&1; then
    local current
    current="$(m1ddc get brightness 2>/dev/null | grep -oP '\d+' | head -n1)"
    local new_brightness
    if [[ "$change" =~ ^\+([0-9]+)$ ]]; then
      new_brightness=$((current + ${BASH_REMATCH[1]}))
    elif [[ "$change" =~ ^-([0-9]+)$ ]]; then
      new_brightness=$((current - ${BASH_REMATCH[1]}))
    else
      new_brightness="$change"
    fi
    (( new_brightness < 0 )) && new_brightness=0
    (( new_brightness > 65535 )) && new_brightness=65535
    m1ddc set brightness "$new_brightness"
    local percent=$((new_brightness * 100 / 65535))
    ae_cli_notify "  Display Brightness" "External display: ${percent}%"
    return
  fi

  if command -v ddcutil >/dev/null 2>&1; then
    local current
    current="$(ddcutil getvcp 10 | grep -oP 'current value =\s+\K\d+')"
    local new_brightness
    if [[ "$change" =~ ^\+([0-9]+)$ ]]; then
      new_brightness=$((current + ${BASH_REMATCH[1]} / 655))
    elif [[ "$change" =~ ^-([0-9]+)$ ]]; then
      new_brightness=$((current - ${BASH_REMATCH[1]} / 655))
    else
      new_brightness=$((change / 655))
    fi
    (( new_brightness < 0 )) && new_brightness=0
    (( new_brightness > 100 )) && new_brightness=100
    ddcutil setvcp 10 "$new_brightness"
    ae_cli_notify "  Display Brightness" "External display: ${new_brightness}%"
    return
  fi

  ae_cli_notify "  Error" "No display control tool found (m1ddc, ddcutil)"
  return 1
}

ae_media_show_media_info() {
  if ! command -v playerctl >/dev/null 2>&1; then
    ae_cli_notify "  Media Info" "playerctl not installed"
    return 1
  fi
  if ! playerctl status >/dev/null 2>&1; then
    ae_cli_notify "  No Media Playing" "No active media players found"
    return 0
  fi
  local artist title status player
  artist="$(playerctl metadata artist 2>/dev/null || echo "Unknown Artist")"
  title="$(playerctl metadata title 2>/dev/null || echo "Unknown Title")"
  status="$(playerctl status 2>/dev/null || echo "Unknown")"
  player="$(playerctl metadata --format '{{playerName}}' 2>/dev/null || echo "Unknown Player")"
  ae_cli_notify "  $player" "$artist - $title\nStatus: $status"
}

ae_module_media_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    switch_audio_output) ae_media_switch_audio_output "$@" ;;
    get_focused_monitor) ae_media_get_focused_monitor "$@" ;;
    toggle_nightlight) ae_media_toggle_nightlight "$@" ;;
    get_current_volume) ae_media_get_current_volume "$@" ;;
    get_current_brightness) ae_media_get_current_brightness "$@" ;;
    apple_display_brightness) ae_media_apple_display_brightness "$@" ;;
    show_media_info) ae_media_show_media_info "$@" ;;
    list) ae_media_list_commands ;;
    help | --help | -h | "")
      ae_module_media_usage
      [[ -z "$cmd" ]] && return 1 || return 0
      ;;
    *)
      ae_cli_log_error "Unknown media command '$cmd'"
      ae_module_media_usage
      return 1
      ;;
  esac
}

ae_register_module "media" ae_module_media_main "Media helper commands" "$AE_MODULE_MEDIA_DIR" m
