#!/usr/bin/env bash
#
# System Utilities Helper Scripts
# Supporting scripts for system.conf bindings
#

set -euo pipefail

# ============================================================================
# SCREENSHOT WITH EDITOR
# ============================================================================
# Take screenshot and open in image editor for annotation
# Usage: screenshot_edit
#
screenshot_edit() {
  local screenshot_dir="$HOME/Pictures/Screenshots"
  mkdir -p "$screenshot_dir"

  local filename
  filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$screenshot_dir/$filename"

  # Take screenshot
  if grim "$filepath"; then
    notify-send "  Screenshot" "Captured: $filename"

    # Open in editor (try satty, swappy, or fallback to gimp/krita)
    if command -v satty &>/dev/null; then
      satty -f "$filepath" --output-filename "$filepath"
    elif command -v swappy &>/dev/null; then
      swappy -f "$filepath"
    elif command -v gimp &>/dev/null; then
      gimp "$filepath" &
    elif command -v krita &>/dev/null; then
      krita "$filepath" &
    else
      notify-send "  Error" "No image editor found (satty, swappy, gimp, krita)"
    fi
  else
    notify-send "  Error" "Screenshot failed"
  fi
}

# ============================================================================
# SAVE SCREENSHOT TO FILE
# ============================================================================
# Save full screenshot to Pictures/Screenshots
# Usage: screenshot_save
#
screenshot_save() {
  local screenshot_dir="$HOME/Pictures/Screenshots"
  mkdir -p "$screenshot_dir"

  local filename
  filename="screenshot_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$screenshot_dir/$filename"

  if grim "$filepath"; then
    notify-send "  Screenshot Saved" "$filename"
  else
    notify-send "  Error" "Screenshot failed"
  fi
}

# ============================================================================
# SAVE SELECTION SCREENSHOT TO FILE
# ============================================================================
# Interactive selection screenshot saved to file
# Usage: screenshot_save_selection
#
screenshot_save_selection() {
  local screenshot_dir="$HOME/Pictures/Screenshots"
  mkdir -p "$screenshot_dir"

  local filename
  filename="selection_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$screenshot_dir/$filename"

  if grim -g "$(slurp)" "$filepath"; then
    notify-send "  Selection Saved" "$filename"
  else
    notify-send "  Cancelled" "Screenshot cancelled"
  fi
}

# ============================================================================
# SCREENSHOT CURRENT WINDOW
# ============================================================================
# Capture only the active window
# Usage: screenshot_window
#
screenshot_window() {
  local screenshot_dir="$HOME/Pictures/Screenshots"
  mkdir -p "$screenshot_dir"

  local filename
  filename="window_$(date +%Y%m%d_%H%M%S).png"
  local filepath="$screenshot_dir/$filename"

  # Get active window geometry
  local geometry
  geometry=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')

  if [[ -n "$geometry" ]]; then
    grim -g "$geometry" "$filepath"
    notify-send "  Window Screenshot" "Saved: $filename"
  else
    notify-send "  Error" "Could not get window geometry"
  fi
}

# ============================================================================
# TOGGLE GAPS
# ============================================================================
# Toggle gaps on/off for current workspace
# Usage: toggle_gaps
#
toggle_gaps() {
  # Get current gaps_in value
  local current_gaps
  current_gaps=$(hyprctl getoption general:gaps_in -j | jq -r '.int')

  if [[ "$current_gaps" -eq 0 ]]; then
    # Restore gaps
    hyprctl keyword general:gaps_in 6
    hyprctl keyword general:gaps_out 10
    notify-send "  Gaps Enabled" "Restored default gaps"
  else
    # Remove gaps
    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
    notify-send "  Gaps Disabled" "Maximized workspace"
  fi
}

# ============================================================================
# POWER MENU
# ============================================================================
# Interactive power menu for shutdown, restart, logout, etc.
# Usage: power_menu
#
power_menu() {
  local options="Lock\nLogout\nSuspend\nRestart\nShutdown"

  # Use walker, rofi, or wofi for menu
  local chosen
  if command -v walker &>/dev/null; then
    chosen=$(echo -e "$options" | walker --dmenu)
  elif command -v rofi &>/dev/null; then
    chosen=$(echo -e "$options" | rofi -dmenu -p "Power Menu")
  elif command -v wofi &>/dev/null; then
    chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")
  else
    notify-send "  Error" "No menu program found (walker, rofi, wofi)"
    return 1
  fi

  case "$chosen" in
  Lock)
    loginctl lock-session
    ;;
  Logout)
    hyprctl dispatch exit
    ;;
  Suspend)
    systemctl suspend
    ;;
  Restart)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
  *)
    # Cancelled or unknown
    ;;
  esac
}

# ============================================================================
# SHOW KEYBINDINGS
# ============================================================================
# Display all configured keybindings in a readable format
# Usage: show_keybindings
#
show_keybindings() {
  # Get all bindings from hyprctl
  local bindings
  bindings=$(hyprctl binds)

  # Display in terminal or GUI
  if command -v walker &>/dev/null; then
    echo "$bindings" | walker --dmenu
  elif command -v rofi &>/dev/null; then
    echo "$bindings" | rofi -dmenu -p "Keybindings"
  elif command -v kitty &>/dev/null; then
    kitty --class floating-terminal -e bash -c "echo '$bindings' | less"
  else
    notify-send "  Keybindings" "See ~/.config/hypr/bindings/ for all keybindings"
  fi
}

# ============================================================================
# TOGGLE SCREENRECORDING
# ============================================================================
# Start/stop screen recording
# Usage: toggle_screenrecord
#
toggle_screenrecord() {
  if pgrep -x wf-recorder >/dev/null; then
    # Stop recording
    pkill -SIGINT wf-recorder
    notify-send "  Recording Stopped" "Video saved to ~/Videos/Recordings/"
  else
    # Start recording
    local recording_dir="$HOME/Videos/Recordings"
    mkdir -p "$recording_dir"

    local filename
    filename="recording_$(date +%Y%m%d_%H%M%S).mp4"
    local filepath="$recording_dir/$filename"

    wf-recorder -f "$filepath" &
    notify-send "  Recording Started" "Recording to: $filename"
  fi
}

# ============================================================================
# SCREENRECORD SELECTION
# ============================================================================
# Record a specific region of the screen
# Usage: screenrecord_selection
#
screenrecord_selection() {
  local recording_dir="$HOME/Videos/Recordings"
  mkdir -p "$recording_dir"

  local filename
  filename="recording_$(date +%Y%m%d_%H%M%S).mp4"
  local filepath="$recording_dir/$filename"

  # Get selection geometry
  local geometry
  geometry=$(slurp)

  if [[ -n "$geometry" ]]; then
    wf-recorder -g "$geometry" -f "$filepath" &
    notify-send "  Recording Selection" "Recording to: $filename\nPress SUPER+ALT+PRINT to stop"
  else
    notify-send "  Cancelled" "Recording cancelled"
  fi
}

# ============================================================================
# SHOW NETWORK INFO
# ============================================================================
# Display current network connection information
# Usage: show_network_info
#
show_network_info() {
  # Get WiFi info
  local ssid
  ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

  # Get IP address
  local ip
  ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)

  # Get connection type
  local connection_type
  connection_type=$(nmcli -t -f TYPE,STATE con show --active | grep ':activated' | cut -d: -f1 | head -n1)

  if [[ -n "$ssid" ]]; then
    notify-send "  Network" "SSID: $ssid\nIP: ${ip:-unknown}\nType: ${connection_type:-unknown}"
  else
    notify-send "  Network" "Not connected\nType: ${connection_type:-unknown}"
  fi
}

# ============================================================================
# SHOW SYSTEM RESOURCES
# ============================================================================
# Display CPU, RAM, and disk usage
# Usage: show_system_resources
#
show_system_resources() {
  # Get CPU usage
  local cpu_usage
  cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')

  # Get RAM usage
  local mem_usage
  mem_usage=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')

  # Get disk usage
  local disk_usage
  disk_usage=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')

  notify-send "  System Resources" "CPU: $cpu_usage\nRAM: $mem_usage\nDisk: $disk_usage"
}

# ============================================================================
# OCR SCREENSHOT
# ============================================================================
# Capture region and extract text via OCR
# Usage: ocr_screenshot
#
ocr_screenshot() {
  if ! command -v tesseract &>/dev/null; then
    notify-send "  Error" "Tesseract OCR not installed"
    return 1
  fi

  local tmp_img
  tmp_img=$(mktemp /tmp/ocr-XXXX.png)
  local tmp_txt
  tmp_txt=$(mktemp /tmp/ocr-XXXX.txt)

  # Capture selection
  if grim -g "$(slurp)" "$tmp_img"; then
    # Run OCR
    tesseract "$tmp_img" "${tmp_txt%.*}" 2>/dev/null

    # Copy to clipboard
    if [[ -f "$tmp_txt" ]]; then
      wl-copy <"$tmp_txt"
      notify-send "  OCR Complete" "Text copied to clipboard"
    else
      notify-send "  OCR Failed" "Could not extract text"
    fi
  else
    notify-send "  Cancelled" "OCR cancelled"
  fi

  # Cleanup
  rm -f "$tmp_img" "$tmp_txt"
}

# ============================================================================
# SCAN QR CODE
# ============================================================================
# Scan QR code from screen region
# Usage: scan_qr_code
#
scan_qr_code() {
  if ! command -v zbarimg &>/dev/null; then
    notify-send "  Error" "zbar-tools not installed"
    return 1
  fi

  local tmp_img
  tmp_img=$(mktemp /tmp/qr-XXXX.png)

  # Capture selection
  if grim -g "$(slurp)" "$tmp_img"; then
    # Scan QR code
    local result
    result=$(zbarimg -q --raw "$tmp_img" 2>/dev/null)

    if [[ -n "$result" ]]; then
      echo "$result" | wl-copy
      notify-send "  QR Code Scanned" "$result"
    else
      notify-send "  No QR Code Found" "Could not detect QR code in selection"
    fi
  else
    notify-send "  Cancelled" "QR scan cancelled"
  fi

  # Cleanup
  rm -f "$tmp_img"
}

# ============================================================================
# EMOJI PICKER
# ============================================================================
# Simple emoji picker (alternative to walker/rofi)
# Usage: emoji_picker
#
emoji_picker() {
  # Simple emoji list (expand as needed)
  local emojis="😀 😁 😂 🤣 😃 😄 😅 😆 😉 😊 😋 😎 😍 😘 🥰 😗 😙 😚 ☺️ 🙂 🤗 🤩 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 😴 😌 😛 😜 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 ☹️ 🙁 😖 😞 😟 😤 😢 😭 😦 😧 😨 😩 🤯 😬 😰 😱 🥵 🥶 😳 🤪 😵 😡 😠 🤬 👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🤙 💪 🦾 🙏 ✍️ 💅 🤳 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🔒 🔓 🔑 🗝️ 🔨 ⛏️ ⚒️ 🛠️ 🗡️ ⚔️ 💣 🏹 🛡️ 🔧 🔩 ⚙️ 🗜️ ⚖️ 🦯 🔗 ⛓️ 🧰 🧲 ⚗️ 🧪 🧫 🧬 🔬 🔭 📡 💉 💊 🚪 🛏️ 🛋️ 🪑 🚽 🚿 🛁 🧴 🧷 🧹 🧺 🧻 🧼 🧽 🧯 🛒 🚬 ⚰️ ⚱️ 🗿 🔮 📿 💎 🔪 🏺 🗺️ 💰 💴 💵 💶 💷 💸 💳 🧾 💹 ✉️ 📧 📨 📩 📤 📥 📦 📫 📪 📬 📭 📮 🗳️ ✏️ ✒️ 🖋️ 🖊️ 🖌️ 🖍️ 📝 💼 📁 📂 🗂️ 📅 📆 🗒️ 🗓️ 📇 📈 📉 📊 📋 📌 📍 📎 🖇️ 📏 📐 ✂️ 🗃️ 🗄️ 🗑️ 🔒 🔓 🔐 🔑 🗝️ 🔨 ⚒️ 🛠️ 🗡️ ⚔️ 🔫 🏹 🛡️ 🔧 🔩 ⚙️ 🗜️ ⚖️ 🔗 ⛓️ 🧰 🧲 ⚗️"

  if command -v rofi &>/dev/null; then
    local chosen
    chosen=$(echo "$emojis" | tr ' ' '\n' | rofi -dmenu -p "Emoji")
    if [[ -n "$chosen" ]]; then
      echo -n "$chosen" | wl-copy
      notify-send "  Emoji Copied" "$chosen"
    fi
  else
    notify-send "  Emoji Picker" "Install rofi or use SUPER+CTRL+E with walker"
  fi
}

# ============================================================================
# SHARE MENU
# ============================================================================
# Menu for sharing files via various methods
# Usage: share_menu
#
share_menu() {
  local options="LocalSend\nKDE Connect\nEmail\nUpload to Cloud"

  local chosen
  if command -v rofi &>/dev/null; then
    chosen=$(echo -e "$options" | rofi -dmenu -p "Share")
  else
    notify-send "  Share" "No menu program available"
    return 1
  fi

  case "$chosen" in
  LocalSend)
    if command -v localsend_app &>/dev/null; then
      uwsm-app -- localsend_app &
    else
      notify-send "  Error" "LocalSend not installed"
    fi
    ;;
  "KDE Connect")
    if command -v kdeconnect-cli &>/dev/null; then
      # Would need file selection logic here
      notify-send "  KDE Connect" "Feature not fully implemented"
    else
      notify-send "  Error" "KDE Connect not installed"
    fi
    ;;
  Email)
    uwsm-app -- thunderbird &
    ;;
  "Upload to Cloud")
    notify-send "  Cloud Upload" "Feature not implemented"
    ;;
  esac
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================
# Allow calling functions directly from command line
# Usage: ./system.sh function_name [args...]
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
    echo "  - screenshot_edit"
    echo "  - screenshot_save"
    echo "  - screenshot_save_selection"
    echo "  - screenshot_window"
    echo "  - toggle_gaps"
    echo "  - power_menu"
    echo "  - show_keybindings"
    echo "  - toggle_screenrecord"
    echo "  - screenrecord_selection"
    echo "  - show_network_info"
    echo "  - show_system_resources"
    echo "  - ocr_screenshot"
    echo "  - scan_qr_code"
    echo "  - emoji_picker"
    echo "  - share_menu"
    exit 1
  fi
fi
