#!/usr/bin/env bash

AE_MODULE_INFO_DIR="${AE_MODULE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

ae_module_info_main() {
  local CYAN='' BOLD='' RESET=''
  if [[ -t 1 ]]; then
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
  fi

  printf "%bArchenemy System Information%b\n\n" "$BOLD" "$RESET"

  printf "%bHyprland:%b\n" "$CYAN" "$RESET"
  if command -v hyprctl &>/dev/null; then
    hyprctl version | head -3
  else
    printf '  Not running\n'
  fi

  printf "\n%bDisplay:%b\n" "$CYAN" "$RESET"
  if command -v hyprctl &>/dev/null; then
    hyprctl monitors | grep -E "Monitor|resolution" | head -4
  else
    printf "  hyprctl not available\n"
  fi

  printf "\n%bGPU:%b\n" "$CYAN" "$RESET"
  lspci | grep -i vga

  printf "\n%bMemory:%b\n" "$CYAN" "$RESET"
  free -h | awk '/^Mem:/ {print "  Total: "$2" | Used: "$3" | Free: "$4}'

  printf "\n%bUptime:%b\n" "$CYAN" "$RESET"
  uptime -p
}

ae_register_module "info" ae_module_info_main "Show system information" "$AE_MODULE_INFO_DIR" i
