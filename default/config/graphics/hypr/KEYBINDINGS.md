# Archenemy Hyprland Keybindings

Complete visual reference for all keyboard shortcuts in Archenemy's Hyprland configuration.

## Keyboard Layout Visual

```
╔════════════════════════════════════════════════════════════════╗
║              VIM-STYLE NAVIGATION (Primary Binds)              ║
╚════════════════════════════════════════════════════════════════╝

    ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───────┐
    │ ` │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │ 0 │ - │ = │ Back  │
    │   │WS1│WS2│WS3│WS4│WS5│WS6│WS7│WS8│WS9│   │Shk│Exp│       │
    └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───────┘
    ┌─────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬─────┐
    │ Tab │ Q │ W │ E │ R │ T │ Y │ U │ I │ O │ P │ [ │ ] │  \  │
    │     │Cls│Cls│Edt│Run│Spl│   │   │   │Oth│   │   │   │     │
    └─────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴─────┘
    ┌──────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬────────┐
    │ Caps │ A │ S │ D │ F │ G │ H │ J │ K │ L │ ; │ ' │ Enter  │
    │      │   │Scr│   │Ful│Grp│ ← │ ↓ │ ↑ │ → │   │   │        │
    └──────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴────────┘
    ┌────────┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬──────────┐
    │ Shift  │ Z │ X │ C │ V │ B │ N │ M │ , │ . │ / │  Shift   │
    │        │Ctr│Ful│Cpy│Flt│Brs│   │Max│Not│   │Sch│          │
    └────────┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴──────────┘
    ┌──────┬────┬────┬──────────────────┬────┬────┬────┬────────┐
    │ Ctrl │ FN │Alt │      SPACE       │Alt │Ctrl│ ◄  │ ▼  ▲ ► │
    │      │    │Cyc │     Launcher     │    │    │Bck │Nav Nav │
    └──────┴────┴────┴──────────────────┴────┴────┴────┴────────┘

Legend:
  WS  = Switch to Workspace N       Cls = Close window      Edt = Editor
  Spl = Toggle split               Ful = Fullscreen         Flt = Float
  Scr = Scratchpad                 Grp = Group toggle       Brs = Browser
  Not = Notifications              Cpy = Copy               Sch = Search
  Ctr = Center window              Max = Maximize           Oth = Other split
  Shk = Shrink window              Exp = Expand window      Cyc = Cycle windows
  ←↓↑→ = Navigate windows (vim hjkl)
```

## Layer-by-Layer Breakdown

### Layer 1: SUPER (Base Navigation & Apps)

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPER - Primary Layer              Most Frequently Used        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Navigation (Vim-style)                                          │
│    h / ←        Move focus left                                  │
│    j / ↓        Move focus down                                  │
│    k / ↑        Move focus up                                    │
│    l / →        Move focus right                                 │
│                                                                  │
│  Workspaces                                                      │
│    1-9          Switch to workspace 1-9                          │
│    TAB          Next workspace                                   │
│    o            Cycle to other window                            │
│                                                                  │
│  Window Control                                                  │
│    w / q        Close active window                              │
│    v            Toggle floating                                  │
│    x / m        Fullscreen                                       │
│    t            Toggle split direction                           │
│    z            Center window                                    │
│    p            Pin window (show on all workspaces)             │
│    g            Toggle window grouping                           │
│    s            Toggle scratchpad                                │
│    a            Decrease window size (-40px)                     │
│    x            Increase window size (+40px)                     │
│                                                                  │
│  Applications                                                    │
│    RETURN       Terminal                                         │
│    SPACE / /    Application launcher                             │
│    b            Browser                                          │
│    f            File manager                                     │
│    e            Editor                                           │
│    r            Run command                                      │
│    =            Calculator                                       │
│                                                                  │
│  Notifications                                                   │
│    COMMA        Dismiss last notification                        │
│                                                                  │
│  Clipboard                                                       │
│    c            Universal copy (Ctrl+Insert)                     │
│    v            Universal paste (Shift+Insert)                   │
│    x            Universal cut (Ctrl+X)                           │
│                                                                  │
│  Resize (- / = keys)                                            │
│    - (code:20)  Shrink horizontally (-100px)                    │
│    = (code:21)  Expand horizontally (+100px)                    │
│                                                                  │
│  Mouse Actions                                                   │
│    + LMB drag   Move window                                      │
│    + RMB drag   Resize window                                    │
│    + scroll     Switch workspace                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 2: SUPER + SHIFT (Actions & Secondary Apps)

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPER + SHIFT - Action Layer       Moving & Launching          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Window Movement                                                 │
│    h / ←        Swap window left                                 │
│    j / ↓        Swap window down                                 │
│    k / ↑        Swap window up                                   │
│    l / →        Swap window right                                │
│    o            Cycle to previous window                         │
│                                                                  │
│  Workspace Movement                                              │
│    1-9          Move window to workspace 1-9                     │
│    TAB          Previous workspace                               │
│                                                                  │
│  Resize (- / = keys)                                            │
│    - (code:20)  Shrink vertically (-100px)                      │
│    = (code:21)  Expand vertically (+100px)                      │
│                                                                  │
│  Applications                                                    │
│    RETURN       Floating terminal                                │
│    f            File manager (new window)                        │
│    b            Browser (new window)                             │
│    n            Notes / Editor                                   │
│    t            Task monitor (btop)                              │
│    d            Docker manager (lazydocker)                      │
│    g            Git TUI (lazygit)                                │
│    m            Music player                                     │
│    v            Code editor                                      │
│    /            Password manager                                 │
│                                                                  │
│  System                                                          │
│    SPACE        Toggle waybar visibility                         │
│    COMMA        Dismiss all notifications                        │
│    BACKSPACE    Toggle workspace gaps                            │
│    PRINT        Screenshot with editor                           │
│    /            Show keybindings help                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 3: SUPER + CTRL (System Config & Toggles)

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPER + CTRL - Configuration Layer    System Settings          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Window Resize                                                   │
│    h / ←        Resize left (-20px)                              │
│    j / ↓        Resize down (+20px)                              │
│    k / ↑        Resize up (-20px)                                │
│    l / →        Resize right (+20px)                             │
│                                                                  │
│  Workspace Navigation                                            │
│    TAB          Previous visited workspace                       │
│                                                                  │
│  System Toggles                                                  │
│    n            Toggle nightlight (hyprsunset)                   │
│    i            Toggle idle lock (hypridle)                      │
│    l            Lock screen immediately                          │
│    r            Reload Hyprland configuration                    │
│    x            Tiled fullscreen                                 │
│                                                                  │
│  Information Displays                                            │
│    t            Show current time and date                       │
│    b            Show battery status                              │
│                                                                  │
│  Utilities                                                       │
│    e            Emoji picker                                     │
│    v            Clipboard history manager                        │
│    c            Color picker (hyprpicker)                        │
│    s            Share menu                                       │
│    COMMA        Toggle Do Not Disturb                            │
│    SPACE        Next background in theme                         │
│                                                                  │
│  Window Properties                                               │
│    f            Fullscreen (tiled)                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 4: SUPER + ALT (Advanced Features)

```
┌─────────────────────────────────────────────────────────────────┐
│  SUPER + ALT - Advanced Layer       Groups & Special Features   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Group Management                                                │
│    h / ←        Join window to group on left                     │
│    j / ↓        Join window to group below                       │
│    k / ↑        Join window to group above                       │
│    l / →        Join window to group on right                    │
│    g            Move active window out of group                  │
│    TAB          Next window in group                             │
│    SHIFT+TAB    Previous window in group                         │
│    1-5          Jump to Nth window in group                      │
│                                                                  │
│  Special Workspaces                                              │
│    s            Move window to scratchpad                        │
│    SPACE        Omarchy menu                                     │
│    f            Maximize (full width)                            │
│    x            Maximize (full width mode)                       │
│                                                                  │
│  Mouse Group Navigation                                          │
│    + scroll up  Previous window in group                         │
│    + scroll dn  Next window in group                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 5: ALT (Standalone)

```
┌─────────────────────────────────────────────────────────────────┐
│  ALT - Application Switching        Window Cycling              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Window Cycling                                                  │
│    TAB          Next window (brings to top)                      │
│    SHIFT+TAB    Previous window (brings to top)                  │
│                                                                  │
│  Precision Media Control (with XF86 keys)                        │
│    + Volume↑    Increase volume by 1%                            │
│    + Volume↓    Decrease volume by 1%                            │
│    + Bright↑    Increase brightness by 1%                        │
│    + Bright↓    Decrease brightness by 1%                        │
│    PRINT        Screen recording                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 6: Special Keys (No Modifier)

```
┌─────────────────────────────────────────────────────────────────┐
│  SPECIAL KEYS - Hardware Control    Direct Media Access         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Screenshots                                                     │
│    PRINT        Full screenshot to clipboard                     │
│    SHIFT+PRINT  Selection screenshot to clipboard               │
│    SUPER+PRINT  Screenshot with editor                           │
│                                                                  │
│  Audio Control (repeats when held)                              │
│    XF86AudioRaiseVolume    Volume up (5% steps)                 │
│    XF86AudioLowerVolume    Volume down (5% steps)               │
│    XF86AudioMute           Mute/unmute toggle                    │
│    XF86AudioMicMute        Microphone mute toggle               │
│                                                                  │
│  Display Brightness (repeats when held)                         │
│    XF86MonBrightnessUp     Brightness up (5% steps)             │
│    XF86MonBrightnessDown   Brightness down (5% steps)           │
│                                                                  │
│  Media Playback                                                  │
│    XF86AudioPlay/Pause     Play/pause toggle                     │
│    XF86AudioNext           Next track                            │
│    XF86AudioPrev           Previous track                        │
│    XF86AudioStop           Stop playback                         │
│                                                                  │
│  System                                                          │
│    XF86PowerOff            Power menu                            │
│    XF86Calculator          Calculator                            │
│                                                                  │
│  Audio Output (with SUPER)                                      │
│    SUPER+XF86AudioMute     Switch audio output device           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🗺️ Modifier Matrix

Quick reference showing what each modifier combination does for common keys:

```
         │ SUPER  │ +SHIFT │  +CTRL  │  +ALT   │
    ─────┼────────┼────────┼─────────┼─────────┤
    hjkl │  Move  │  Swap  │ Resize  │  Join   │
         │  Focus │  Wins  │ Windows │  Group  │
    ─────┼────────┼────────┼─────────┼─────────┤
    1-9  │ Switch │  Move  │         │  Group  │
         │   WS   │  to WS │         │  Win N  │
    ─────┼────────┼────────┼─────────┼─────────┤
    RET  │  Term  │ Float  │         │         │
         │        │  Term  │         │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    b    │  Web   │  Web   │         │         │
         │ Browse │  New   │         │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    f    │  File  │  File  │  Full   │  Full   │
         │  Mgr   │  New   │  Screen │  Width  │
    ─────┼────────┼────────┼─────────┼─────────┤
    s    │  Scr   │        │ Share   │  Move   │
         │ Toggle │        │  Menu   │  to Scr │
    ─────┼────────┼────────┼─────────┼─────────┤
    n    │        │ Notes  │  Night  │         │
         │        │        │  Light  │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    TAB  │  Next  │  Prev  │  Last   │  Group  │
         │   WS   │   WS   │   WS    │  Cycle  │
    ─────┼────────┼────────┼─────────┼─────────┤
    SPACE│ Launch │ Toggle │  Next   │ Omarchy │
         │  Apps  │   Bar  │  BG     │  Menu   │
    ─────┼────────┼────────┼─────────┼─────────┤
    g    │  Group │  Git   │         │  Leave  │
         │ Toggle │  TUI   │         │  Group  │
    ─────┼────────┼────────┼─────────┼─────────┤
    v    │  Float │VSCode  │  Clip   │         │
         │ Toggle │        │  board  │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    COMMA│ Notif  │  All   │   DND   │         │
         │ Dismiss│ Dismiss│  Toggle │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    BKSPC│  Opc   │  Gaps  │         │         │
         │ Toggle │ Toggle │         │         │
    ─────┼────────┼────────┼─────────┼─────────┤
    ESC  │        │        │         │         │
         │        │        │         │         │
    ─────┼────────┼────────┼─────────┼─────────┤
```

## 🎯 Vim Parallels

Hyprland keybindings inspired by Vim motions:

| Vim Command  | Hyprland Equivalent  | Action                              |
| ------------ | -------------------- | ----------------------------------- |
| `hjkl`       | SUPER + hjkl         | Navigate between windows            |
| `:q` / `ZZ`  | SUPER + w/q          | Close window                        |
| `^W w`       | SUPER + o            | Cycle to other window               |
| `^W h/j/k/l` | SUPER + hjkl         | Move focus (same as vim)            |
| `^W H/J/K/L` | SUPER + SHIFT + hjkl | Swap windows                        |
| `^W o`       | SUPER + x            | Fullscreen (only this window)       |
| `^W r`       | SUPER + t            | Rotate/toggle split                 |
| `^W _`       | SUPER + m            | Maximize vertically                 |
| `/`          | SUPER + /            | Search (launcher)                   |
| `:`          | SUPER + r            | Command mode (run)                  |
| `v`          | SUPER + v            | Visual mode → Floating              |
| `gt`         | SUPER + TAB          | Next tab → Next workspace           |
| `gT`         | SUPER + SHIFT + TAB  | Previous tab → Previous workspace   |
| `{count}gt`  | SUPER + {1-9}        | Go to tab N → Go to workspace N     |
| `^A` / `^X`  | SUPER + a/x          | Decrement/increment → Shrink/expand |
| `zz`         | SUPER + z            | Center cursor → Center window       |
| `u`          | SUPER + CTRL + TAB   | Undo → Previous workspace           |
| `p`          | SUPER + p            | Put → Pin window                    |

## 🔍 Search & Filter

This document is grep-friendly! Use these patterns to find specific bindings:

```bash
# Find all SUPER bindings
grep "SUPER" KEYBINDINGS.md

# Find workspace-related bindings
grep -i "workspace" KEYBINDINGS.md

# Find all resize operations
grep -i "resize" KEYBINDINGS.md

# Find media controls
grep -i "audio\|volume\|brightness" KEYBINDINGS.md

# Find window management
grep -i "window\|float\|tile" KEYBINDINGS.md
```

## 📋 Quick Reference Categories

### Navigation

- `SUPER + hjkl/arrows` - Move focus
- `SUPER + SHIFT + hjkl/arrows` - Swap windows
- `SUPER + CTRL + hjkl/arrows` - Resize windows
- `ALT + TAB/SHIFT+TAB` - Cycle windows

### Workspaces

- `SUPER + 1-9` - Switch workspace
- `SUPER + SHIFT + 1-9` - Move window to workspace
- `SUPER + TAB/SHIFT+TAB` - Next/previous workspace
- `SUPER + CTRL + TAB` - Last visited workspace

### Window States

- `SUPER + w/q` - Close
- `SUPER + v` - Toggle floating
- `SUPER + x/m` - Fullscreen
- `SUPER + t` - Toggle split
- `SUPER + z` - Center
- `SUPER + p` - Pin

### Applications

- `SUPER + RETURN` - Terminal
- `SUPER + b` - Browser
- `SUPER + f` - Files
- `SUPER + e` - Editor
- `SUPER + SPACE` - Launcher

### System

- `SUPER + CTRL + n` - Nightlight
- `SUPER + CTRL + i` - Idle lock
- `SUPER + CTRL + l` - Lock screen
- `SUPER + CTRL + r` - Reload config
- `SUPER + ESC` - Power menu

---

**Pro Tip**: Run `archenemy keys` in terminal for an interactive keybinding reference with search!

**Configuration**: All keybindings can be customized in `~/.config/hypr/bindings/`
