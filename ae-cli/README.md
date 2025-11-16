# Archenemy CLI (ae)

Command-line interface for managing your Archenemy Hyprland configuration.

## Installation

These scripts will be installed to `~/.config/archenemy/ae-cli/` by the Archenemy installer.

The installer will also:

1. Copy `~/.config/zsh/.zshenv` to `~/.zshenv` (sets ZDOTDIR)
2. Copy ZSH config to `~/.config/zsh/`
3. The `ae` command will be available in your PATH

## Usage

### Main Command

```bash
ae <command> [options]
```

### Available Commands

#### Keybinding Reference

```bash
ae keys              # Show full keyboard layout
ae keys --layer super   # Show specific layer
ae keys --search        # Interactive search (requires fzf)
ae keys --vim           # Vim parallels
ae keys --cheat         # Quick cheat sheet
ae keys --live          # Live Hyprland bindings
```

#### Configuration Editor

```bash
ae edit              # Interactive menu (requires fzf)
ae edit hyprland     # Edit main config
ae edit envs         # Edit environment variables
ae edit monitors     # Edit monitor config
ae edit bindings     # Edit keybindings directory
ae edit waybar       # Edit Waybar config
```

**Available targets:**
hyprland, envs, monitors, input, looknfeel, autostart, windows, bindings, vim, apps, waybar, mako, kitty

#### Hyprland Control

```bash
ae hypr reload       # Reload configuration
ae hypr info         # System information
ae hypr monitors     # Monitor configuration
ae hypr windows      # List open windows
ae hypr workspaces   # Workspace overview
ae hypr binds        # Active keybindings
ae hypr rules        # Window rules
ae hypr debug        # Debug information
ae hypr logs         # View logs (tail -f)
```

#### Quick Reference

```bash
ae ref keys          # Keybinding reference (text)
ae ref vim           # Vim parallels (text)
ae ref commands      # Available commands (text)
ae ref hypr          # Hyprland variables (text)
ae ref troubleshoot  # Common issues (text)
```

#### System Info

```bash
ae info              # Show system and Hyprland info
```

## Aliases

When ZSH integration is loaded, these aliases are available:

### Short Commands

```bash
ae-keys              # ae keys
ae-edit              # ae edit
ae-hypr              # ae hypr
```

### Quick Access

```bash
keys                 # ae keys
keys-vim             # ae keys --vim
keys-cheat           # ae keys --cheat
keys-search          # ae keys --search
```

### Config Editing

```bash
ae-conf-hypr         # ae edit hyprland
ae-conf-keys         # ae edit bindings
ae-conf-waybar       # ae edit waybar
```

### Hyprland Control

```bash
hypr-reload          # ae hypr reload
hypr-info            # ae hypr info
hypr-win             # ae hypr windows
hypr-ws              # ae hypr workspaces
```

## Dependencies

### Required

- `bash` - Core shell (any recent version)
- `hyprctl` - Hyprland control utility (comes with Hyprland)

### Optional (Enhanced Features)

- `fzf` - Interactive search and menus
- `bat` - Syntax-highlighted file viewing
- `jq` - JSON parsing for pretty output
- `eza` - Modern `ls` replacement (used by aliases)

All scripts work without optional dependencies, but functionality is enhanced when available.

## File Structure

```
~/.config/archenemy/ae-cli/
├── ae                       # Main CLI entry point (loads runtime + modules)
├── lib/
│   └── core/                # Runtime, logging, helpers
├── modules/                 # Feature modules
│   ├── apps/
│   ├── edit/
│   ├── hypr/
│   ├── info/
│   ├── keys/
│   ├── media/
│   ├── menu/
│   ├── refresh/
│   ├── ref/
│   └── system/
├── share/
│   └── reference/           # Static text references
├── archenemy.zsh            # ZSH integration (PATH + wrapper)
├── archenemy-aliases.zsh    # Shortcut aliases
├── archenemy-completion.zsh # Tab completion
└── README.md
```

## Architecture

`ae` now uses a lightweight runtime (`lib/core/runtime.sh`) that:

- Loads common helpers (`lib/core/common.sh`)
- Auto-discovers modules under `modules/` and user overrides in `~/.config/archenemy/ae-cli/modules.d`
- Registers each module’s handler/description/aliases for help, completions, and dispatch

Each module is an isolated directory that can expose as many actions as it needs (e.g., `modules/system` sources its `actions.sh` helper). This keeps the CLI portable Bash while enabling reuse: adding a new command is as simple as dropping a module with `ae_register_module`.

Static data lives in `share/` (reference docs, templates) so scripts aren’t tied to fragile relative paths.

## Development

### Testing

```bash
cd ~/.config/archenemy/ae-cli

# Syntax check core + modules
shellcheck ae lib/core/*.sh modules/**/*.sh

# Test individual scripts
./ae --version
./ae keys --cheat
./ae edit --help
```

### Verify Installation

```bash
# Check ae is in PATH
which ae
# Should show: ~/.config/archenemy/ae-cli/ae

# Test command
ae --version
# Should show: Archenemy v1.0.0

# Test subcommand
ae keys --cheat
# Should display keybinding cheat sheet
```

## Troubleshooting

**Command not found: ae**

- Ensure ZDOTDIR is set: `echo $ZDOTDIR` should show `/home/user/.config/zsh`
- Check `~/.zshenv` exists and contains `export ZDOTDIR="$HOME/.config/zsh"`
- Verify scripts are executable: `ls -la ~/.config/archenemy/ae-cli/ae*`
- Check PATH includes ae-cli: `echo $PATH | grep ae-cli`

**Completions not working**

- Ensure `archenemy-completion.zsh` is sourced in `.zshrc`
- Try: `compinit` to reload completions
- Check ZSH modules are loaded: `source ~/.config/zsh/.zshrc`

**Missing features (search, pretty output)**

- Install optional dependencies: `sudo pacman -S fzf bat jq eza`

**ZDOTDIR not working**

- Ensure `~/.zshenv` exists (not `~/.config/zsh/.zshenv`)
- `.zshenv` must be in home directory to set ZDOTDIR
- After creating/updating `~/.zshenv`, restart your shell: `exec zsh`
