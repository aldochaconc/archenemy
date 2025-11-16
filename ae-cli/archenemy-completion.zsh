#!/usr/bin/env zsh
# shellcheck shell=bash disable=SC2296,SC2298,SC2086
#
# Archenemy ZSH Completions
# Tab completion for all ae commands
# Note: Uses ZSH-specific parameter expansions and completion syntax

# Main ae completion
_ae() {
  local -a commands
  commands=(
    'keys:Show keybinding reference'
    'edit:Open configuration editor'
    'hypr:Hyprland control interface'
    'info:Show system information'
    'ref:Show quick reference'
    'help:Show help message'
    'version:Show version information'
  )
  
  _arguments -C \
    '1: :->command' \
    '*::arg:->args'
  
  case "$state" in
    command)
      _describe -t commands 'ae commands' commands
      ;;
    args)
      case "$line[1]" in
        keys|k)
          _ae_keys
          ;;
        edit|e)
          _ae_edit
          ;;
        hypr|h)
          _ae_hypr
          ;;
        ref|reference)
          _ae_ref
          ;;
      esac
      ;;
  esac
}

# ae keys completion
_ae_keys() {
  local -a options
  options=(
    '--layer:Show specific layer'
    '--search:Interactive search'
    '--vim:Show vim parallels'
    '--cheat:Compact cheat sheet'
    '--live:Show live bindings'
    '--help:Show help'
  )
  
  local -a layers
  layers=(
    'super:Base layer (SUPER)'
    'shift:SUPER + SHIFT layer'
    'ctrl:SUPER + CTRL layer'
    'alt:SUPER + ALT layer'
    'alt-only:ALT standalone layer'
    'special:Special keys layer'
  )
  
  if [[ "$words[CURRENT-1]" == "--layer" || "$words[CURRENT-1]" == "-l" ]]; then
    _describe -t layers 'keyboard layers' layers
  else
    _describe -t options 'keys options' options
  fi
}

# ae edit completion
_ae_edit() {
  local -a targets
  targets=(
    'hyprland:Main Hyprland config'
    'envs:Environment variables'
    'monitors:Monitor configuration'
    'input:Input device settings'
    'looknfeel:Appearance settings'
    'autostart:Startup applications'
    'windows:Window rules'
    'bindings:Keybinding directory'
    'vim:Vim navigation bindings'
    'apps:App-specific rules'
    'waybar:Waybar configuration'
    'mako:Mako configuration'
    'kitty:Kitty terminal config'
  )
  
  _describe -t targets 'configuration targets' targets
}

# ae hypr completion
_ae_hypr() {
  local -a commands
  commands=(
    'reload:Reload Hyprland configuration'
    'info:Show system information'
    'monitors:Display monitor configuration'
    'windows:List and manage windows'
    'workspaces:Show workspace overview'
    'binds:Display keybindings'
    'rules:Show window rules'
    'plugins:List loaded plugins'
    'logs:View Hyprland logs'
    'debug:Show debug information'
    'help:Show help'
  )
  
  _describe -t commands 'hypr commands' commands
}

# ae ref completion
_ae_ref() {
  local -a refs
  refs=(
    'keys:Keybinding reference'
    'vim:Vim parallels'
    'commands:Available commands'
    'hypr:Hyprland variables'
    'troubleshoot:Common issues'
  )
  
  _describe -t refs 'reference types' refs
}

# Register completions
compdef _ae ae
compdef _ae ae

# Alias completions
compdef _ae_keys ae-keys
compdef _ae_keys ae-keys
compdef _ae_edit ae-edit
compdef _ae_edit ae-edit
compdef _ae_hypr ae-hypr
compdef _ae_hypr ae-hypr

# Hyprctl completion (enhanced)
_hyprctl() {
  local -a commands
  commands=(
    'reload:Reload Hyprland config'
    'monitors:List monitors'
    'workspaces:List workspaces'
    'clients:List windows'
    'activewindow:Show active window'
    'binds:List keybindings'
    'dispatch:Execute dispatcher'
    'keyword:Set config keyword'
    'getoption:Get config option'
    'version:Show version'
    'systeminfo:Show system info'
  )
  
  _arguments -C \
    '1: :->command' \
    '*::arg:->args'
  
  case "$state" in
    command)
      _describe -t commands 'hyprctl commands' commands
      ;;
    args)
      case "$line[1]" in
        dispatch)
          _hyprctl_dispatch
          ;;
      esac
      ;;
  esac
}

_hyprctl_dispatch() {
  local -a dispatchers
  dispatchers=(
    'killactive:Close active window'
    'togglefloating:Toggle floating'
    'fullscreen:Toggle fullscreen'
    'pseudo:Toggle pseudotile'
    'pin:Pin window'
    'movefocus:Move focus (l/r/u/d)'
    'movewindow:Move window (l/r/u/d)'
    'swapwindow:Swap window (l/r/u/d)'
    'workspace:Switch workspace'
    'movetoworkspace:Move to workspace'
    'togglespecialworkspace:Toggle scratchpad'
    'togglegroup:Toggle grouping'
    'changegroupactive:Change group window'
    'exec:Execute command'
    'exit:Exit Hyprland'
    'reload:Reload config'
  )
  
  _describe -t dispatchers 'dispatchers' dispatchers
}

compdef _hyprctl hyprctl

# Hyprland-specific completions
_hyprland_workspaces() {
  local -a workspaces
  if command -v hyprctl &>/dev/null; then
    workspaces=("${(@f)$(hyprctl workspaces -j | jq -r '.[].id' 2>/dev/null)}")
  else
    workspaces=(1 2 3 4 5 6 7 8 9 10)
  fi
  
  _describe -t workspaces 'workspaces' workspaces
}

_hyprland_windows() {
  local -a windows
  if command -v hyprctl &>/dev/null; then
    windows=("${(@f)$(hyprctl clients -j | jq -r '.[] | "\(.address):\(.class) - \(.title[0:50])"' 2>/dev/null)}")
    _describe -t windows 'windows' windows
  fi
}

# File path completions for edit commands
_ae_conf_files() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
  
  _alternative \
    "hypr:Hyprland configs:_files -W $config_dir/hypr" \
    "configs:Other configs:_files -W $config_dir"
}

# Smart completion for config edit aliases
compdef '_files -W ~/.config/hypr' ae-conf-hypr
compdef '_files -W ~/.config/hypr' ae-conf-envs
compdef '_files -W ~/.config/hypr' ae-conf-monitors
compdef '_files -W ~/.config/hypr/bindings' ae-conf-keys
compdef '_files -W ~/.config/hypr/apps' ae-conf-apps
compdef '_files -W ~/.config/waybar' ae-conf-waybar
compdef '_files -W ~/.config/mako' ae-conf-mako
compdef '_files -W ~/.config/kitty' ae-conf-kitty

# Git completions (if not already provided by oh-my-zsh or similar)
if ! command -v __git_complete &>/dev/null; then
  compdef _git g=git
  compdef _git gs=git-status
  compdef _git ga=git-add
  compdef _git gc=git-commit
  compdef _git gp=git-push
  compdef _git gl=git-log
  compdef _git gd=git-diff
  compdef _git gco=git-checkout
  compdef _git gb=git-branch
fi

# Docker completions (if applicable)
if command -v docker &>/dev/null; then
  compdef _docker d=docker
  compdef _docker-compose dc=docker-compose
fi

# Enhanced completion settings
# These improve the overall completion experience
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%F{cyan}%d%f%b'
zstyle ':completion:*:messages' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'
zstyle ':completion:*:corrections' format '%B%F{red}%d (errors: %e)%f%b'

# Completion for common command options
zstyle ':completion:*:*:ae:*' verbose yes
zstyle ':completion:*:*:ae:*' group-order commands options
zstyle ':completion:*:*:ae:*' verbose yes
zstyle ':completion:*:*:ae:*' group-order commands options

# Cache completions for speed
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/completion

# Initialize completion system if not already done
# This is usually called in .zshrc, but we ensure it here
autoload -Uz compinit
# Only check for new functions once a day
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

