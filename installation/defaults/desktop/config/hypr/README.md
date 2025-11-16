# Archenemy Hyprland Configuration

A comprehensive, modular, and well-documented Hyprland configuration system with vim-inspired keybindings.

## 📁 Structure

```
hypr/
├── hyprland.conf          # Main orchestrator file
├── envs.conf              # Environment variables (Wayland, toolkits)
├── monitors.conf          # Display configuration
├── input.conf             # Keyboard, mouse, touchpad
├── looknfeel.conf         # Decorations, animations, layouts
├── autostart.conf         # Startup applications
├── windows.conf           # Global window rules
├── bindings/              # Keybindings organized by function
│   ├── vim-nav.conf       # Vim-style navigation (hjkl + arrows)
│   ├── apps.conf          # Application launchers
│   ├── apps.sh            # Application helper scripts
│   ├── tiling.conf        # Workspaces, window management, groups
│   ├── media.conf         # Volume, brightness, playback
│   ├── media.sh           # Media control scripts
│   ├── system.conf        # Screenshots, notifications, toggles
│   └── system.sh          # System utility scripts
└── apps/                  # Per-application window rules
    ├── browser.conf       # Chromium, Firefox, etc.
    ├── terminals.conf     # kitty, Alacritty, Ghostty
    ├── system.conf        # File pickers, settings, media players
    ├── jetbrains.conf     # IntelliJ, PyCharm, WebStorm
    ├── steam.conf         # Steam client and games
    ├── discord.conf       # Discord, Slack, Signal, Telegram
    └── vscode.conf        # VSCode, Cursor, VSCodium
```

## 🎯 Key Features

### Modular Organization

- **Core config files**: Separated by function (envs, monitors, input, etc.)
- **Bindings by category**: Apps, tiling, media, system utilities
- **App-specific rules**: Each application type has its own config file
- **Helper scripts**: Colocated with their binding configs

### Comprehensive Documentation

- Every option documented inline with:
  - Purpose and effect
  - Valid values and ranges
  - Usage examples
  - Alternative configurations
- No need to constantly reference external docs
- Self-contained and educational

### Vim-Inspired Keybindings

- **hjkl navigation** with arrow key fallbacks
- **Modal approach**: SUPER (normal), SUPER+SHIFT (actions), SUPER+CTRL (config), SUPER+ALT (advanced)
- **Vim parallels**: w (close), o (other split), / (search), : (command), v (visual/float)
- Muscle memory transfers between vim and window management

### Intelligent Window Management

- Tag-based classification (browsers, terminals, etc.)
- Automatic opacity adjustments
- Video site detection (full opacity for YouTube, Zoom, etc.)
- JetBrains IDE quirk fixes
- Steam game optimizations
- Terminal scroll speed tuning

## ⌨️ Quick Reference

### Core Navigation

```
SUPER + hjkl/arrows       Move focus between windows
SUPER + SHIFT + hjkl      Swap windows
SUPER + CTRL + hjkl       Resize windows
SUPER + 1-9               Switch to workspace
SUPER + SHIFT + 1-9       Move window to workspace
```

### Window Management

```
SUPER + w/q               Close window
SUPER + v                 Toggle floating
SUPER + x/m               Fullscreen
SUPER + t                 Toggle split
SUPER + s                 Toggle scratchpad
SUPER + g                 Toggle grouping
ALT + TAB                 Cycle windows
```

### Applications

```
SUPER + RETURN            Terminal
SUPER + b                 Browser
SUPER + f                 File manager
SUPER + e                 Editor
SUPER + SPACE / /         App launcher
```

### Media & System

```
XF86 Keys                 Volume, brightness, playback
PRINT                     Screenshot to clipboard
SHIFT + PRINT             Selection screenshot
SUPER + CTRL + n          Toggle nightlight
SUPER + CTRL + i          Toggle idle lock
SUPER + COMMA             Dismiss notification
```

### Utilities

```
SUPER + ESCAPE            Power menu
SUPER + k                 Show keybindings
SUPER + CTRL + e          Emoji picker
SUPER + CTRL + v          Clipboard history
SUPER + CTRL + c          Color picker
SUPER + CTRL + t          Show time
SUPER + CTRL + b          Battery status
```

## 🔧 Customization

### Override Defaults

Simply edit the files in `~/.config/hypr/` (they source from these defaults)

### Add Custom Bindings

Add to the end of relevant binding files or create `~/.config/hypr/user.conf`

### Modify App Behavior

Edit the corresponding file in `apps/` directory

### Add New Applications

1. Identify window class: `hyprctl activewindow | grep class`
2. Add rules to appropriate apps config
3. Consider creating new config if it's a complex app

## 🚀 Helper Scripts

### apps.sh / `ae apps` Commands

- `launch_or_focus APP_CLASS [CMD]` - Focus existing or launch new
- `get_terminal_cwd` / `launch_terminal_cwd [TERMINAL]` - Reuse/copy working directories
- `launch_webapp URL [BROWSER]` / `launch_or_focus_webapp TITLE URL [BROWSER]`
- `summon_app APP_CLASS`, `get_app_workspace APP_CLASS`
- `check_app_available CMD [PKG]`, `launch_with_fallbacks APP1 [...]`

### media.sh / `ae media` Commands

- `switch_audio_output` - Cycle through audio devices
- `toggle_nightlight` - Toggle blue light filter
- `get_focused_monitor` - Get active monitor name
- `get_current_volume` / `get_current_brightness`
- `apple_display_brightness CHANGE` - Control external Apple displays
- `show_media_info` - Display current track (playerctl)

### system.sh / `ae system` Commands

The historical `system.sh` helpers now forward to the shared CLI (`ae system`)
so they can be triggered both from Hypr bindings and from command launchers.

- `screenshot_edit` - Capture and edit screenshot
- `screenshot_clipboard` / `screenshot_selection_clipboard` - Copy full/region captures to clipboard
- `screenshot_save` / `screenshot_save_selection` - Save captures to `~/Pictures/Screenshots`
- `toggle_gaps` - Toggle workspace gaps
- `power_menu` - Interactive power options
- `show_keybindings` - Display all keybindings
- `toggle_screenrecord` / `screenrecord_selection` - Start/stop monitor or region recordings (GPU fallback to wf-recorder)
- `ocr_screenshot` - Capture region and extract text
- `scan_qr_code` - Scan QR code from screen
- `launch_walker` - Launch the configured app launcher (walker/rofi fallback)
- `toggle_idle_lock` - Start/stop hypridle to disable/enable locking
- `toggle_waybar` - Toggle Waybar visibility (or start it if not running)
- `show_battery` - Display battery percentage/state via upower/sysfs
- `launch_wifi` - Open the Wi-Fi helper (impala/nm-connection-editor/nmtui)
- `share_menu` / `share_clipboard` / `share_file` / `share_folder` - Share clipboard data or files via LocalSend

## 📝 Philosophy

### Configuration as Documentation

Every file serves as both configuration and documentation. You should be able to:

- Understand what each option does without external references
- See examples of alternative configurations
- Learn about available features through comments
- Discover related options in context

### Progressive Enhancement

- Works out of the box with sensible defaults
- Easy to find and modify settings
- Commented alternatives for different preferences
- Clear upgrade paths for advanced features

### Maintainability

- Logical file organization by function
- Consistent naming conventions
- Scripts colocated with their configs
- Tag-based rules for easier management

## 🔍 Troubleshooting

### Config won't load

```bash
# Check for syntax errors
hyprctl reload 2>&1 | grep -i error

# Verify file paths
ls -la ~/.config/hypr/
```

### Keybinding not working

```bash
# List all bindings
hyprctl binds | grep -i "your_key"

# Test binding manually
hyprctl dispatch exec "your-command"
```

### Window rules not applying

```bash
# Check window properties
hyprctl activewindow

# List all clients
hyprctl clients | grep -A 10 "your_app"
```

### Script not executing

```bash
# Verify executable permission
ls -la ~/.config/hypr/bindings/*.sh

# Test script directly
~/.config/hypr/bindings/apps.sh function_name args
```

## 📚 Resources

- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Window Rules](https://wiki.hyprland.org/Configuring/Window-Rules/)
- [Keybinding Syntax](https://wiki.hyprland.org/Configuring/Binds/)
- [Variables Reference](https://wiki.hyprland.org/Configuring/Variables/)

## 🎨 Credits

Inspired by:

- **Hyprland** official example configuration
- **Omarchy** modular organization approach
- **Vim** keybinding philosophy and modal thinking
- The Arch Linux and Hyprland communities

---

**Note**: This configuration is designed for Archenemy - an Arch Linux distribution focusing on a clean, modular, and well-documented system setup.
