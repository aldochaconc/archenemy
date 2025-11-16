#!/usr/bin/env bash

AE_MODULE_REF_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
REF_DIR="$(ae_data_path reference)"

ae_module_ref_help() {
  local BOLD='' CYAN='' RESET=''
  if [[ -t 1 ]]; then
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
  fi
  cat <<EOF
${BOLD}ae ref${RESET} - Quick Reference

Usage:
  ae ref <type>

Types:
  ${CYAN}keys${RESET}          Keybinding reference
  ${CYAN}vim${RESET}           Vim parallels
  ${CYAN}commands${RESET}      Available commands
  ${CYAN}hypr${RESET}          Hyprland variables
  ${CYAN}troubleshoot${RESET}  Common issues
EOF
}

ae_module_ref_main() {
  local type="${1:-keys}"
  case "$type" in
    keys)
      cat "$REF_DIR/keybindings.txt" | ${PAGER:-less}
      ;;
    vim)
      cat "$REF_DIR/vim-parallels.txt" | ${PAGER:-less}
      ;;
    commands)
      cat "$REF_DIR/commands.txt" | ${PAGER:-less}
      ;;
    hypr)
      cat "$REF_DIR/hyprland-vars.txt" | ${PAGER:-less}
      ;;
    troubleshoot)
      cat "$REF_DIR/troubleshooting.txt" | ${PAGER:-less}
      ;;
    --help | -h)
      ae_module_ref_help
      ;;
    *)
      ae_cli_log_error "Unknown reference type '$type'"
      ae_module_ref_help
      return 1
      ;;
  esac
}

ae_register_module "ref" ae_module_ref_main "Quick reference cheatsheets" "$AE_MODULE_REF_DIR" r reference
