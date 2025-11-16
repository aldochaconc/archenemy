#!/usr/bin/env bash

if [[ "${AE_SYSTEM_UTILS_SOURCED:-false}" == true ]]; then
  return 0
fi
AE_SYSTEM_UTILS_SOURCED=true

AE_SYSTEM_COMMANDS=(
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
  launch_walker
  toggle_idle_lock
  toggle_waybar
  show_battery
  launch_wifi
  share_clipboard
  share_file
  share_folder
)

ae_system_list_commands() {
  printf '%s\n' "${AE_SYSTEM_COMMANDS[@]}"
}

_ae_system_screenshot_dir() {
  local dir="$ARCHENEMY_HOME/Pictures/Screenshots"
  mkdir -p "$dir"
  echo "$dir"
}

ae_system_screenshot_edit() {
  local dir
  dir="$(_ae_system_screenshot_dir)"
  local filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$dir/$filename"

  if grim "$filepath"; then
    ae_cli_notify "  Screenshot" "Captured: $filename"
    if command -v satty >/dev/null 2>&1; then
      satty -f "$filepath" --output-filename "$filepath"
    elif command -v swappy >/dev/null 2>&1; then
      swappy -f "$filepath"
    elif command -v gimp >/dev/null 2>&1; then
      gimp "$filepath" &
    elif command -v krita >/dev/null 2>&1; then
      krita "$filepath" &
    else
      ae_cli_notify "  Error" "No image editor found (satty, swappy, gimp, krita)"
    fi
  else
    ae_cli_notify "  Error" "Screenshot failed"
    return 1
  fi
}

ae_system_screenshot_save() {
  local dir
  dir="$(_ae_system_screenshot_dir)"
  local filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$dir/$filename"

  if grim "$filepath"; then
    ae_cli_notify "  Screenshot Saved" "$filename"
  else
    ae_cli_notify "  Error" "Screenshot failed"
    return 1
  fi
}

ae_system_screenshot_save_selection() {
  local dir
  dir="$(_ae_system_screenshot_dir)"
  local filename="selection_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$dir/$filename"

  local region
  region="$(slurp 2>/dev/null || true)"
  if [[ -z "$region" ]]; then
    ae_cli_notify "  Cancelled" "Screenshot cancelled"
    return 1
  fi

  if grim -g "$region" "$filepath"; then
    ae_cli_notify "  Selection Saved" "$filename"
  else
    ae_cli_notify "  Error" "Screenshot failed"
    return 1
  fi
}

ae_system_screenshot_window() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    ae_cli_notify "  Error" "Hyprctl not found (window capture unavailable)"
    return 1
  fi

  local dir
  dir="$(_ae_system_screenshot_dir)"
  local filename="window_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$dir/$filename"
  local geometry
  geometry="$(hyprctl activewindow -j | jq -r '"'"'\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])'"'"')"

  if [[ -z "$geometry" || "$geometry" == "null null" ]]; then
    ae_cli_notify "  Error" "Could not get window geometry"
    return 1
  fi

  if grim -g "$geometry" "$filepath"; then
    ae_cli_notify "  Window Screenshot" "Saved: $filename"
  else
    ae_cli_notify "  Error" "Screenshot failed"
    return 1
  fi
}

ae_system_toggle_gaps() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    ae_cli_notify "  Error" "Hyprctl not found (toggle_gaps unavailable)"
    return 1
  fi
  local current_gaps
  current_gaps="$(hyprctl getoption general:gaps_in -j | jq -r '.int')"
  if [[ "$current_gaps" -eq 0 ]]; then
    hyprctl keyword general:gaps_in 6
    hyprctl keyword general:gaps_out 10
    ae_cli_notify "  Gaps Enabled" "Restored default gaps"
  else
    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
    ae_cli_notify "  Gaps Disabled" "Maximized workspace"
  fi
}

ae_system_power_menu() {
  local options="Lock\nLogout\nSuspend\nRestart\nShutdown"
  local chosen=""
  if command -v walker >/dev/null 2>&1; then
    chosen="$(echo -e "$options" | walker --dmenu)"
  elif command -v rofi >/dev/null 2>&1; then
    chosen="$(echo -e "$options" | rofi -dmenu -p "Power Menu")"
  elif command -v wofi >/dev/null 2>&1; then
    chosen="$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")"
  else
    ae_cli_notify "  Error" "No menu program found (walker, rofi, wofi)"
    return 1
  fi

  case "$chosen" in
    Lock) loginctl lock-session ;;
    Logout) hyprctl dispatch exit ;;
    Suspend) systemctl suspend ;;
    Restart) systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
    *) ;;
  esac
}

ae_system_show_keybindings() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    ae_cli_notify "  Keybindings" "hyprctl not found (are you inside Hyprland?)"
    return 1
  fi

  local bindings
  bindings="$(hyprctl binds)"

  if command -v walker >/dev/null 2>&1; then
    echo "$bindings" | walker --dmenu
  elif command -v rofi >/dev/null 2>&1; then
    echo "$bindings" | rofi -dmenu -p "Keybindings"
  elif command -v kitty >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp)"
    printf '%s\n' "$bindings" >"$tmp"
    kitty --class floating-terminal -e less "$tmp"
    rm -f "$tmp"
  else
    ae_cli_notify "  Keybindings" "See ~/.config/hypr/bindings/ for all keybindings"
  fi
}

_ae_system_screenrecord_dir() {
  local xdg="${XDG_VIDEOS_DIR:-$ARCHENEMY_HOME/Videos}"
  local dir="$xdg/Recordings"
  mkdir -p "$dir"
  echo "$dir"
}

_ae_system_screenrecord_active() {
  pgrep -f "gpu-screen-recorder" >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1
}

_ae_system_screenrecord_stop() {
  if pgrep -f "gpu-screen-recorder" >/dev/null 2>&1; then
    pkill -SIGINT -f "gpu-screen-recorder"
    sleep 1
    pkill -9 -f "gpu-screen-recorder" >/dev/null 2>&1 || true
    ae_cli_notify "  Recording Stopped" "Video saved to $(_ae_system_screenrecord_dir)"
    return
  fi
  if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -SIGINT wf-recorder
    ae_cli_notify "  Recording Stopped" "Video saved to $(_ae_system_screenrecord_dir)"
  fi
}

_ae_system_screenrecord_start_gpu() {
  local mode="$1"
  local target="$2"
  local dir
  dir="$(_ae_system_screenrecord_dir)"
  local filename="$dir/recording_$(date +%Y%m%d_%H%M%S).mp4"
  local audio_arg=""
  if [[ "${AE_SYSTEM_SCREENRECORD_AUDIO:-true}" == "true" ]]; then
    audio_arg="-a default_output|default_input"
  fi
  if [[ "$mode" == "output" ]]; then
    gpu-screen-recorder -w "$target" -f 60 -c mp4 -o "$filename" $audio_arg &
  else
    gpu-screen-recorder -w region -r "$target" -f 60 -c mp4 -o "$filename" $audio_arg &
  fi
  ae_cli_notify "  Recording Started" "Recording to: $(basename "$filename")"
}

_ae_system_screenrecord_start_wf() {
  local args="$1"
  local geom="$2"
  local dir
  dir="$(_ae_system_screenrecord_dir)"
  local filename="$dir/recording_$(date +%Y%m%d_%H%M%S).mp4"
  if [[ "$args" == "output" ]]; then
    wf-recorder -o "$geom" -f "$filename" &
  else
    wf-recorder -g "$geom" -f "$filename" &
  fi
  ae_cli_notify "  Recording Started" "Recording to: $(basename "$filename")"
}

ae_system_toggle_screenrecord() {
  if _ae_system_screenrecord_active; then
    _ae_system_screenrecord_stop
    return
  fi

  if command -v gpu-screen-recorder >/dev/null 2>&1; then
    local output
    output="$(slurp -o -f "%o" 2>/dev/null || true)"
    if [[ -z "$output" ]]; then
      ae_cli_notify "  Recording" "Monitor selection cancelled"
      return 1
    fi
    _ae_system_screenrecord_start_gpu "output" "$output"
  else
    local output
    output="$(slurp -o -f "%o" 2>/dev/null || true)"
    if [[ -z "$output" ]]; then
      ae_cli_notify "  Recording" "Monitor selection cancelled"
      return 1
    fi
    _ae_system_screenrecord_start_wf "output" "$output"
  fi
}

ae_system_screenrecord_selection() {
  if _ae_system_screenrecord_active; then
    _ae_system_screenrecord_stop
    return
  fi

  local region
  region="$(slurp -f "%wx%h+%x+%y" 2>/dev/null || true)"
  if [[ -z "$region" ]]; then
    ae_cli_notify "  Recording" "Selection cancelled"
    return 1
  fi

  if command -v gpu-screen-recorder >/dev/null 2>&1; then
    local scaled="$region"
    if [[ "$region" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
      local scale
      scale="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .scale')"
      local w h x y
      w=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * ${scale:-1}}")
      h=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[2]} * ${scale:-1}}")
      x=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[3]} * ${scale:-1}}")
      y=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[4]} * ${scale:-1}}")
      scaled="${w}x${h}+${x}+${y}"
    fi
    _ae_system_screenrecord_start_gpu "region" "$scaled"
  else
    _ae_system_screenrecord_start_wf "region" "$region"
  fi
}

ae_system_show_network_info() {
  if ! command -v nmcli >/dev/null 2>&1; then
    ae_cli_notify "  Network" "nmcli not available (NetworkManager not running)"
    return 1
  fi

  local ssid
  ssid="$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)"
  local ip
  ip="$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)"
  local connection_type
  connection_type="$(nmcli -t -f TYPE,STATE con show --active | grep ':activated' | cut -d: -f1 | head -n1)"

  if [[ -n "$ssid" ]]; then
    ae_cli_notify "  Network" "SSID: $ssid\nIP: ${ip:-unknown}\nType: ${connection_type:-unknown}"
  else
    ae_cli_notify "  Network" "Not connected\nType: ${connection_type:-unknown}"
  fi
}

ae_system_show_system_resources() {
  local cpu_usage
  cpu_usage="$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
  local mem_usage
  mem_usage="$(free -h | awk '/^Mem:/ {print $3 " / " $2}')"
  local disk_usage
  disk_usage="$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
  ae_cli_notify "  System Resources" "CPU: $cpu_usage\nRAM: $mem_usage\nDisk: $disk_usage"
}

ae_system_ocr_screenshot() {
  if ! command -v tesseract >/dev/null 2>&1; then
    ae_cli_notify "  Error" "Tesseract OCR not installed"
    return 1
  fi

  local tmp_img
  tmp_img="$(mktemp /tmp/ocr-XXXX.png)"
  local tmp_txt
  tmp_txt="$(mktemp /tmp/ocr-XXXX.txt)"

  if grim -g "$(slurp)" "$tmp_img"; then
    tesseract "$tmp_img" "${tmp_txt%.*}" >/dev/null 2>&1
    if [[ -f "$tmp_txt" ]]; then
      wl-copy <"$tmp_txt"
      ae_cli_notify "  OCR Complete" "Text copied to clipboard"
    else
      ae_cli_notify "  OCR Failed" "Could not extract text"
    fi
  else
    ae_cli_notify "  Cancelled" "OCR cancelled"
  fi

  rm -f "$tmp_img" "$tmp_txt"
}

ae_system_scan_qr_code() {
  if ! command -v zbarimg >/dev/null 2>&1; then
    ae_cli_notify "  Error" "zbar-tools not installed"
    return 1
  fi

  local tmp_img
  tmp_img="$(mktemp /tmp/qr-XXXX.png)"
  if grim -g "$(slurp)" "$tmp_img"; then
    local result
    result="$(zbarimg -q --raw "$tmp_img" 2>/dev/null)"
    if [[ -n "$result" ]]; then
      echo "$result" | wl-copy
      ae_cli_notify "  QR Code Scanned" "$result"
    else
      ae_cli_notify "  No QR Code Found" "Could not detect QR code in selection"
    fi
  else
    ae_cli_notify "  Cancelled" "QR scan cancelled"
  fi
  rm -f "$tmp_img"
}

ae_system_emoji_picker() {
  local emojis="😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 😋 😎 😍 😘 🥰 😗 😙 😚 ☺️ 🙂 🤗 🤩 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 😴 😌 😛 😜 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 ☹️ 🙁 😖 😞 😟 😤 😢 😭 😦 😧 😨 😩 🤯 😬 😰 😱 🥵 🥶 😳 🤪 😵 😡 😠 🤬 👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤙 💪 🦾 🙏 ✍️ 💅 🤳 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🔒 🔓 🔑 🗝️ 🔨 ⛏️ ⚒️ 🛠️ 🗡️ ⚔️ 💣 🏹 🛡️ 🔧 🔩 ⚙️ 🗜️ ⚖️ 🦯 🔗 ⛓️ 🧰 🧲 ⚗️ 🧪 🧫 🧬 🔬 🔭 📡 💉 💊 🚪 🛏️ 🛋️ 🪑 🚽 🚿 🛁 🧴 🧷 🧹 🧺 🧻 🧼 🧽 🧯 🛒 🚬 ⚰️ ⚱️ 🗿 🔮 📿 💎 🔪 🏺 🗺️ 💰 💴 💵 💶 💷 💸 💳 🧾 💹 ✉️ 📧 📨 📩 📤 📥 📦 📫 📪 📬 📭 📮 🗳️ ✏️ ✒️ 🖋️ 🖊️ 🖌️ 🖍️ 📝 💼 📁 📂 🗂️ 📅 📆 🗒️ 🗓️ 📇 📈 📉 📊 📋 📌 📍 📎 🖇️ 📏 📐 ✂️ 🗃️ 🗄️ 🗑️ 🔒 🔓 🔐 🔑 🗝️ 🔨 ⚒️ 🛠️ 🗡️ ⚔️ 🔫 🏹 🛡️ 🔧 🔩 ⚙️ 🗜️ ⚖️ 🔗 ⛓️ 🧰 🧲 ⚗️"

  if command -v rofi >/dev/null 2>&1; then
    local chosen
    chosen="$(echo "$emojis" | tr ' ' '\n' | rofi -dmenu -p "Emoji")"
    if [[ -n "$chosen" ]]; then
      printf '%s' "$chosen" | wl-copy
      ae_cli_notify "  Emoji Copied" "$chosen"
    fi
  else
    ae_cli_notify "  Emoji Picker" "Install rofi or trigger walker symbols mode"
  fi
}

_ae_system_share_send() {
  if ! command -v localsend >/dev/null 2>&1; then
    ae_cli_notify "  Share" "localsend not installed"
    return 1
  fi
  if [[ $# -eq 0 ]]; then
    ae_cli_notify "  Share" "No files to send"
    return 1
  fi
  systemd-run --user --quiet --collect localsend --headless send "$@" >/dev/null 2>&1 &
  ae_cli_notify "  Share" "Sending via LocalSend..."
}

ae_system_share_clipboard() {
  local tmp
  tmp="$(mktemp /tmp/share-XXXX.txt)"
  wl-paste >"$tmp"
  _ae_system_share_send "$tmp"
}

ae_system_share_file() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    if command -v zenity >/dev/null 2>&1; then
      path="$(zenity --file-selection --title="Select file to share" 2>/dev/null || true)"
    fi
  fi
  [[ -z "$path" ]] && return 1
  _ae_system_share_send "$path"
}

ae_system_share_folder() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    if command -v zenity >/dev/null 2>&1; then
      path="$(zenity --file-selection --directory --title="Select folder to share" 2>/dev/null || true)"
    fi
  fi
  [[ -z "$path" ]] && return 1
  _ae_system_share_send "$path"
}

ae_system_share_menu() {
  if ! command -v rofi >/dev/null 2>&1; then
    ae_cli_notify "  Share" "No menu program available"
    return 1
  fi

  local options="Clipboard\nFile\nFolder"
  local chosen
  chosen="$(echo -e "$options" | rofi -dmenu -p "Share")"

  case "$chosen" in
    Clipboard) ae_system_share_clipboard ;;
    File) ae_system_share_file ;;
    Folder) ae_system_share_folder ;;
    *) ;;
  esac
}

ae_system_launch_walker() {
  local launcher="${AE_SYSTEM_LAUNCHER:-walker}"
  if command -v "$launcher" >/dev/null 2>&1; then
    if command -v uwsm-app >/dev/null 2>&1; then
      setsid uwsm-app -- "$launcher" "$@" >/dev/null 2>&1 &
    else
      setsid "$launcher" "$@" >/dev/null 2>&1 &
    fi
    return 0
  fi

  if command -v rofi >/dev/null 2>&1; then
    setsid rofi -show drun >/dev/null 2>&1 &
    return 0
  fi

  ae_cli_notify "  Launcher" "No launcher available (walker/rofi missing)"
  return 1
}

ae_system_toggle_idle_lock() {
  if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle
    ae_cli_notify "  Idle Lock Disabled" "Screen will not auto-lock"
    return 0
  fi

  if command -v uwsm-app >/dev/null 2>&1; then
    setsid uwsm-app -- hypridle >/dev/null 2>&1 &
  else
    setsid hypridle >/dev/null 2>&1 &
  fi
  ae_cli_notify "  Idle Lock Enabled" "Screen will auto-lock when idle"
}

ae_system_toggle_waybar() {
  if pgrep -x waybar >/dev/null 2>&1; then
    pkill -SIGUSR1 waybar
    ae_cli_notify "  Waybar" "Toggled visibility"
    return 0
  fi

  if command -v uwsm-app >/dev/null 2>&1; then
    setsid uwsm-app -- waybar >/dev/null 2>&1 &
  else
    setsid waybar >/dev/null 2>&1 &
  fi
  ae_cli_notify "  Waybar" "Waybar started"
}

ae_system_show_battery() {
  local level=""
  local status=""

  if command -v upower >/dev/null 2>&1; then
    local device
    device="$(upower -e | grep -m1 battery || true)"
    if [[ -n "$device" ]]; then
      level="$(upower -i "$device" | awk -F': *' '/percentage/ {print $2}')"
      status="$(upower -i "$device" | awk -F': *' '/state/ {print $2}')"
    fi
  fi

  if [[ -z "$level" && -r /sys/class/power_supply/BAT0/capacity ]]; then
    level="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)%"
    status="$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)"
  fi

  if [[ -z "$level" ]]; then
    ae_cli_notify "󰁹  Battery" "Battery information unavailable"
    return 1
  fi

  ae_cli_notify "󰁹  Battery" "Level: ${level}\nStatus: ${status:-unknown}"
}

ae_system_launch_wifi() {
  if command -v impala >/dev/null 2>&1; then
    setsid uwsm-app -- impala wifi >/dev/null 2>&1 &
    return 0
  fi

  if command -v nm-connection-editor >/dev/null 2>&1; then
    setsid uwsm-app -- nm-connection-editor >/dev/null 2>&1 &
    return 0
  fi

  if command -v gnome-control-center >/dev/null 2>&1; then
    setsid uwsm-app -- gnome-control-center wifi >/dev/null 2>&1 &
    return 0
  fi

  local terminal=""
  if command -v foot >/dev/null 2>&1; then
    terminal="foot"
  elif command -v kitty >/dev/null 2>&1; then
    terminal="kitty"
  elif command -v alacritty >/dev/null 2>&1; then
    terminal="alacritty"
  fi

  if [[ -n "$terminal" ]] && command -v nmtui >/dev/null 2>&1; then
    if [[ "$terminal" == "foot" ]]; then
      setsid uwsm-app -- "$terminal" -e nmtui >/dev/null 2>&1 &
    else
      setsid uwsm-app -- "$terminal" -e nmtui >/dev/null 2>&1 &
    fi
    return 0
  fi

  ae_cli_notify "  Wi-Fi" "No Wi-Fi launcher available (impala/nm-connection-editor/nmtui missing)"
  return 1
}
ae_system_screenshot_clipboard() {
  local tmp
  tmp="$(mktemp /tmp/shot-XXXX.png)"
  if grim "$tmp"; then
    wl-copy <"$tmp"
    ae_cli_notify "  Screenshot" "Copied full screen to clipboard"
  else
    ae_cli_notify "  Error" "Screenshot failed"
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

ae_system_screenshot_selection_clipboard() {
  local tmp
  tmp="$(mktemp /tmp/shot-XXXX.png)"
  if grim -g "$(slurp)" "$tmp"; then
    wl-copy <"$tmp"
    ae_cli_notify "  Screenshot" "Selection copied to clipboard"
  else
    ae_cli_notify "  Error" "Screenshot failed"
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}
