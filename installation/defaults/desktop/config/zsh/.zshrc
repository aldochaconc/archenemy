#!/usr/bin/env zsh
#
# Archenemy ZSH Configuration
# Clean, modern ZSH setup with useful defaults

# ============================================================================
# ZSH CORE UTILITIES
# ============================================================================

# Source ZSH utility modules
[[ -f "$ZDOTDIR/bindings.zsh" ]] && source "$ZDOTDIR/bindings.zsh"
[[ -f "$ZDOTDIR/envs.zsh" ]] && source "$ZDOTDIR/envs.zsh"
[[ -f "$ZDOTDIR/init.zsh" ]] && source "$ZDOTDIR/init.zsh"
[[ -f "$ZDOTDIR/aliases.zsh" ]] && source "$ZDOTDIR/aliases.zsh"

# ============================================================================
# ARCHENEMY INTEGRATION
# ============================================================================

# Archenemy CLI and tools
if [[ -d "$HOME/.config/archenemy/ae-cli" ]]; then
  # Add ae CLI to PATH
  export PATH="$HOME/.config/archenemy/ae-cli:$PATH"
  
  # Source Archenemy integrations
  [[ -f "$HOME/.config/archenemy/ae-cli/archenemy.zsh" ]] && \
    source "$HOME/.config/archenemy/ae-cli/archenemy.zsh"
  
  [[ -f "$HOME/.config/archenemy/ae-cli/archenemy-aliases.zsh" ]] && \
    source "$HOME/.config/archenemy/ae-cli/archenemy-aliases.zsh"
  
  [[ -f "$HOME/.config/archenemy/ae-cli/archenemy-completion.zsh" ]] && \
    source "$HOME/.config/archenemy/ae-cli/archenemy-completion.zsh"
fi

# ============================================================================
# WELCOME MESSAGE (First login)
# ============================================================================

# Show welcome message on first shell startup
if [[ ! -f "$HOME/.config/archenemy/.welcome-shown" ]]; then
  mkdir -p "$HOME/.config/archenemy"

  cat <<'WELCOME'

╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                  Welcome to Archenemy!                            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

Your Hyprland environment is ready to use!

Quick Start:
  • Press SUPER (Windows key) to see the application launcher
  • SUPER + RETURN for terminal
  • SUPER + b for browser
  • SUPER + / for search

Command Center:
  • ae keys        Show all keybindings
  • ae edit        Edit configurations
  • ae hypr        Hyprland controls
  • ae help        Full command reference

Short aliases:
  • keys           Quick keybinding reference
  • keys-cheat     Compact cheat sheet
  • hypr-reload    Reload Hyprland

Documentation:
  • ~/.config/hypr/KEYBINDINGS.md    Full keyboard layout
  • ~/.config/hypr/README.md         Configuration guide
  • ae ref troubleshoot              Common issues

Tip: Press SUPER + hjkl to navigate between windows (vim-style)

WELCOME

  touch "$HOME/.config/archenemy/.welcome-shown"
  echo ""
  echo "Press Enter to continue..."
  read
fi

