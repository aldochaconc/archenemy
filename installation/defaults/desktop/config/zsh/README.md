# Archenemy ZSH Configuration

Clean, modern ZSH configuration with useful defaults and Archenemy integration.

## Philosophy

This ZSH configuration is designed to be:

1. **Clean** - No bloat, only useful features
2. **Fast** - Minimal startup time
3. **Portable** - Works with or without Oh-My-Zsh
4. **Modular** - Easy to customize individual components
5. **Self-contained** - Uses ZDOTDIR (`~/.config/zsh/`)

## Installation

The Archenemy installer will:

1. Copy `zsh/.zshenv` → `~/.zshenv` (sets ZDOTDIR)
2. Copy `zsh/` directory → `~/.config/zsh/`
3. Your ZSH will automatically use `~/.config/zsh/.zshrc`

### Manual Installation

```bash
# Copy .zshenv to home directory
cp ~/.config/zsh/.zshenv ~/.zshenv

# Restart shell
exec zsh
```

## File Structure

```
~/.config/zsh/
├── .zshenv          # ZDOTDIR setup (copy to ~/.zshenv)
├── .zshrc           # Main configuration file
├── bindings.zsh     # ZLE key bindings
├── envs.zsh         # Environment variables
├── init.zsh         # Tool initialization (mise, starship, zoxide, fzf)
├── aliases.zsh      # Generic useful aliases
├── inputrc.zsh      # Readline-style configuration
└── README.md        # This file
```

## Components

### Core Files

#### `.zshenv`
**Location**: Should be copied to `~/.zshenv` (home directory)

Sets ZDOTDIR to `~/.config/zsh/` so all ZSH configuration lives in `.config/`.

```zsh
export ZDOTDIR="$HOME/.config/zsh"
```

#### `.zshrc`
Main ZSH configuration. Sources all other modules and integrates Archenemy CLI.

**What it does:**
- Loads ZSH utilities (bindings, envs, init, aliases)
- Integrates Archenemy CLI (`ae` command)
- Shows welcome message on first login

#### `bindings.zsh`
ZLE (Z-Line Editor) key bindings and completion settings.

**Features:**
- Emacs-style keybindings
- Case-insensitive completion
- Menu selection
- Colored completion lists
- History search with arrow keys

#### `envs.zsh`
Environment variable exports.

**Current exports:**
- `SUDO_EDITOR` - Editor for sudo operations
- `BAT_THEME` - Theme for bat (syntax highlighter)

**Customize:**
Add your own environment variables here.

#### `init.zsh`
Initializes external tools if they're available.

**Supports:**
- `mise` - Runtime version manager
- `starship` - Prompt
- `zoxide` - Smart directory navigation
- `fzf` - Fuzzy finder

**Safe:** Only initializes tools that are installed. No errors if missing.

#### `aliases.zsh`
Generic useful aliases for productivity.

**Categories:**
- Enhanced standard commands (ls → eza, cat → bat, etc.)
- Directory navigation (.., ..., conf, work, etc.)
- Git shortcuts (gs, ga, gc, gp, etc.)
- Package management (paci, pacu, pacs, etc.)
- System monitoring (htop, ports, memtop, etc.)
- Docker (d, dc, dps, etc.)
- Development (serve, npm shortcuts, cargo shortcuts)
- Miscellaneous (myip, weather, typo corrections)

**Note:** Archenemy-specific aliases are in `~/.config/archenemy/ae-cli/archenemy-aliases.zsh`

#### `inputrc.zsh`
Readline-style input configuration (alternative to `~/.inputrc` for ZSH).

### Archenemy Integration

When Archenemy is installed, `.zshrc` automatically:

1. Adds `~/.config/archenemy/ae-cli` to PATH
2. Sources `archenemy.zsh` (PATH setup)
3. Sources `archenemy-aliases.zsh` (ae shortcuts)
4. Sources `archenemy-completion.zsh` (tab completion)

This gives you access to:
```bash
ae keys              # Archenemy CLI
keys                 # Quick alias
hypr-reload          # Shortcut
```

## Customization

### Adding Custom Aliases

Edit `aliases.zsh`:

```zsh
# Add your custom aliases
alias myalias='some command'
```

### Adding Environment Variables

Edit `envs.zsh`:

```zsh
export MY_VAR="value"
```

### Changing Keybindings

Edit `bindings.zsh`:

```zsh
# Add custom bindings
bindkey '^P' up-line-or-history
```

### Disabling Tool Initialization

Edit `init.zsh` and comment out tools you don't use:

```zsh
# Disable starship
# eval "$(starship init zsh)"
```

## ZDOTDIR Explained

Traditional ZSH uses `~/.zshrc`, `~/.zshenv`, etc. in your home directory.

With ZDOTDIR, you can keep all ZSH config in `~/.config/zsh/`:

```
~/.zshenv           # Sets ZDOTDIR (must be in ~/)
~/.config/zsh/      # All other ZSH config
```

**Benefits:**
- Cleaner home directory
- Better organization
- Easier to manage dotfiles
- Standard XDG Base Directory compliance

**How it works:**
1. ZSH always reads `~/.zshenv` first
2. `~/.zshenv` sets `ZDOTDIR="$HOME/.config/zsh"`
3. ZSH then looks for `.zshrc` in `$ZDOTDIR` instead of `~`

## Troubleshooting

**ZSH doesn't load config**
- Check `~/.zshenv` exists: `ls -la ~/.zshenv`
- Check ZDOTDIR is set: `echo $ZDOTDIR`
- Should show: `/home/user/.config/zsh`
- Restart shell: `exec zsh`

**Aliases not working**
```zsh
# Check if aliases.zsh is sourced
which ls
# Should show: eza or ls with --color

# Manually source
source ~/.config/zsh/aliases.zsh
```

**Completions not working**
```zsh
# Reload completions
autoload -U compinit && compinit
```

**Archenemy integration not working**
- Check directory exists: `ls ~/.config/archenemy/ae-cli/`
- Check PATH: `echo $PATH | grep ae-cli`
- Manually test: `~/.config/archenemy/ae-cli/ae --version`

**Want to go back to traditional config**
```bash
# Remove or rename ~/.zshenv
mv ~/.zshenv ~/.zshenv.bak

# Create traditional ~/.zshrc
cp ~/.config/zsh/.zshrc ~/.zshrc

# Edit ~/.zshrc and update paths
# Change $ZDOTDIR references to ~/.config/zsh
```

## Dependencies

### Required
- `zsh` - Obviously

### Optional (Enhanced Features)
- `eza` - Modern ls replacement
- `bat` - Syntax-highlighted cat
- `fzf` - Fuzzy finder
- `zoxide` - Smart cd
- `starship` - Modern prompt
- `mise` - Runtime version manager

All optional dependencies are gracefully handled. Config works without them.

## Performance

This configuration is designed to be fast:

- Minimal plugin loading
- Conditional tool initialization
- Efficient completion caching
- No heavy frameworks (unless you want Oh-My-Zsh)

Typical startup time: < 100ms (without Oh-My-Zsh)

## Philosophy

This is the **default Archenemy ZSH configuration**. It represents a clean, useful baseline.

**What it includes:**
- Essential ZSH features (completions, bindings, history)
- Useful aliases everyone needs
- Tool integrations that enhance productivity
- Archenemy CLI integration

**What it doesn't include:**
- Heavy frameworks (but compatible with Oh-My-Zsh if you want it)
- Opinionated themes (use starship or your own)
- Bloat or unnecessary plugins
- Archenemy-specific clutter in core files

**Customization is encouraged.** This is your ZSH config. Make it yours.
