#!/usr/bin/env bash

AE_MODULE_KEYS_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
KEYBINDINGS_FILE="${AE_KEYBINDINGS_FILE:-$ARCHENEMY_PATH/installation/defaults/desktop/config/hypr/KEYBINDINGS.md}"
REF_DIR="$(ae_data_path reference)"

ae_module_keys_help() {
  local BOLD='' CYAN='' RESET=''
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  cat <<EOF
${BOLD}ae keys${RESET} - Keybinding Reference

Usage:
  ae keys [options]

Options:
  ${CYAN}--layer, -l${RESET} <name>   Show specific layer (super/shift/ctrl/alt/special)
  ${CYAN}--search, -s${RESET}         Interactive search (requires fzf)
  ${CYAN}--vim, -v${RESET}            Show Vim parallels
  ${CYAN}--cheat, -c${RESET}          Compact cheat sheet
  ${CYAN}--live${RESET}               Show live Hyprland bindings
  ${CYAN}--help, -h${RESET}           Show this help
EOF
}

ae_module_keys_show_full() {
  if [[ -f "$KEYBINDINGS_FILE" ]] && command -v bat &>/dev/null; then
    bat --style=plain --paging=always "$KEYBINDINGS_FILE"
  elif [[ -f "$KEYBINDINGS_FILE" ]]; then
    less "$KEYBINDINGS_FILE"
  else
    ae_cli_log_error "KEYBINDINGS.md not found"
    return 1
  fi
}

ae_module_keys_show_layer() {
  local layer="$1"
  if [[ ! -f "$KEYBINDINGS_FILE" ]]; then
    ae_cli_log_error "KEYBINDINGS.md not found"
    return 1
  fi

  case "$layer" in
    super | base)
      sed -n '/^## SUPER Layer/,/^## /p' "$KEYBINDINGS_FILE" | head -n -1 | ${PAGER:-less}
      ;;
    shift)
      sed -n '/^## SHIFT Layer/,/^## /p' "$KEYBINDINGS_FILE" | head -n -1 | ${PAGER:-less}
      ;;
    ctrl)
      sed -n '/^## CTRL Layer/,/^## /p' "$KEYBINDINGS_FILE" | head -n -1 | ${PAGER:-less}
      ;;
    alt)
      sed -n '/^## ALT Layer/,/^## /p' "$KEYBINDINGS_FILE" | head -n -1 | ${PAGER:-less}
      ;;
    special)
      sed -n '/^## Special Keys/,/^## /p' "$KEYBINDINGS_FILE" | head -n -1 | ${PAGER:-less}
      ;;
    *)
      ae_cli_log_error "Unknown layer '$layer'. Valid layers: super, shift, ctrl, alt, special"
      return 1
      ;;
  esac
}

ae_module_keys_show_search() {
  if ! command -v fzf &>/dev/null; then
    ae_cli_log_error "fzf not found. Install with: sudo pacman -S fzf"
    return 1
  fi

  if [[ -f "$REF_DIR/keybindings.txt" ]]; then
    grep -v "^#" "$REF_DIR/keybindings.txt" | fzf --header="Search Keybindings" --preview-window=wrap
  else
    ae_cli_log_error "keybindings.txt not found"
    return 1
  fi
}

ae_module_keys_show_vim() {
  local file="$REF_DIR/vim-parallels.txt"
  if [[ -f "$file" ]]; then
    cat "$file" | ${PAGER:-less}
  else
    ae_cli_log_error "vim-parallels.txt not found"
    return 1
  fi
}

ae_module_keys_show_cheat() {
  local BOLD='' CYAN='' RESET=''
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  cat <<EOF
${BOLD}Archenemy Quick Reference${RESET}

${CYAN}NAVIGATION${RESET}
  SUPER + hjkl/arrows    Move focus
  SUPER + SHIFT + hjkl   Swap windows
  SUPER + o              Cycle window focus

${CYAN}WORKSPACES${RESET}
  SUPER + 1-9            Switch workspace
  SUPER + SHIFT + 1-9    Move window to workspace
  SUPER + TAB            Next workspace
  SUPER + CTRL + TAB     Previous workspace

${CYAN}WINDOW STATES${RESET}
  SUPER + w/q            Close window
  SUPER + v              Toggle floating
  SUPER + f              Toggle fullscreen
  SUPER + m              Toggle maximize
  SUPER + p              Pin window

${CYAN}APPLICATIONS${RESET}
  SUPER + RETURN         Terminal
  SUPER + b              Browser
  SUPER + /              Search (launcher)
  SUPER + r              Run command

${CYAN}SYSTEM${RESET}
  SUPER + CTRL + n       Toggle nightlight
  SUPER + CTRL + i       Toggle idle/lock
  SUPER + SHIFT + s      Screenshot area
EOF
}

ae_module_keys_show_live() {
  if ! command -v hyprctl &>/dev/null; then
    ae_cli_log_error "Hyprland not running"
    return 1
  fi
  hyprctl binds | ${PAGER:-less}
}

ae_module_keys_main() {
  local mode="${1:-}"
  case "$mode" in
    --layer | -l)
      ae_module_keys_show_layer "${2:-}"
      ;;
    --search | -s)
      ae_module_keys_show_search
      ;;
    --vim | -v)
      ae_module_keys_show_vim
      ;;
    --cheat | -c)
      ae_module_keys_show_cheat
      ;;
    --live)
      ae_module_keys_show_live
      ;;
    --help | -h)
      ae_module_keys_help
      ;;
    "")
      ae_module_keys_show_full
      ;;
    *)
      ae_cli_log_error "Unknown option '$mode'"
      ae_module_keys_help
      return 1
      ;;
  esac
}

ae_register_module "keys" ae_module_keys_main "Keybinding reference" "$AE_MODULE_KEYS_DIR" k
