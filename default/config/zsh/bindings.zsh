#!/usr/bin/env zsh
# shellcheck shell=bash disable=SC2296,SC2086
#
# ZLE key bindings and completion styles equivalent to readline/inputrc
# Note: This file uses ZSH-specific syntax for parameter expansion

# Enable multibyte (UTF-8) and emacs-style keybindings
setopt MULTIBYTE
bindkey -e

# Completion behavior: case-insensitive, menu selection, complete in-word
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'

setopt AUTO_LIST               # list choices on ambiguous completion
setopt LIST_AMBIGUOUS          # keep editing line after listing
setopt AUTO_MENU               # start menu completion on a second tab
setopt COMPLETE_IN_WORD        # consider text after cursor
setopt ALWAYS_TO_END           # move cursor to end after completion
setopt AUTO_PARAM_SLASH        # append trailing / when completing directories
setopt LIST_TYPES              # show file type indicators like ls -F

# Use LS_COLORS for colored completion lists
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# History search with arrow keys (prefix-based)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[C' forward-char
bindkey '^[[D' backward-char

# Do not show '.' and '..' specially
zstyle ':completion:*' special-dirs false

# Ask before showing very large completion lists (similar to completion-query-items)
export LISTMAX=200


