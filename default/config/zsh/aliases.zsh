#!/usr/bin/env zsh
#
# ZSH Aliases
# Generic useful shortcuts for productivity

# ============================================================================
# ENHANCED STANDARD COMMANDS
# ============================================================================

# ls with eza (if available)
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -lh --group-directories-first --icons --git'
  alias la='eza -lah --group-directories-first --icons --git'
  alias lt='eza -T --group-directories-first --icons --level=2'
  alias tree='eza -T --group-directories-first --icons'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh'
  alias la='ls -lAh'
fi

# cat with bat
if command -v bat &>/dev/null; then
  alias cat='bat --style=plain'
  alias ccat='/usr/bin/cat'  # Original cat
fi

# grep with color
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Interactive operations
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I'

# Human-readable sizes
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ============================================================================
# DIRECTORY NAVIGATION
# ============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Quick access to common directories
alias home='cd ~'
alias conf='cd ~/.config'
alias hypr='cd ~/.config/hypr'
alias down='cd ~/Downloads'
alias docs='cd ~/Documents'
alias work='cd ~/Work'

# ============================================================================
# GIT SHORTCUTS
# ============================================================================

alias g='git'
alias gs='git status'
alias gst='git status --short'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gl='git pull'
alias gf='git fetch'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gsh='git show'
alias gst='git stash'
alias gstp='git stash pop'

# ============================================================================
# PACKAGE MANAGEMENT (Arch)
# ============================================================================

if command -v yay &>/dev/null; then
  alias paci='yay -S'           # Install
  alias pacu='yay -Syu'         # Update all
  alias pacr='yay -R'           # Remove
  alias pacrs='yay -Rs'         # Remove with deps
  alias pacs='yay -Ss'          # Search
  alias pacq='yay -Q'           # Query installed
  alias pacqi='yay -Qi'         # Query info
  alias pacc='yay -Sc'          # Clean cache
elif command -v pacman &>/dev/null; then
  alias paci='sudo pacman -S'
  alias pacu='sudo pacman -Syu'
  alias pacr='sudo pacman -R'
  alias pacrs='sudo pacman -Rs'
  alias pacs='pacman -Ss'
  alias pacq='pacman -Q'
  alias pacqi='pacman -Qi'
  alias pacc='sudo pacman -Sc'
fi

# ============================================================================
# SYSTEM MONITORING
# ============================================================================

alias htop='htop --tree'
alias ports='ss -tulanp'
alias listening='ss -tlnp'
alias psg='ps aux | grep'
alias memtop='ps aux --sort=-%mem | head'
alias cputop='ps aux --sort=-%cpu | head'

# Disk usage
alias duh='du -h --max-depth=1 | sort -h'
alias ncdu='ncdu --color dark'

# Journal logs
alias jctl='journalctl'
alias jctlf='journalctl -f'
alias jctlu='journalctl -u'
alias jctlb='journalctl -b'

# ============================================================================
# DOCKER (if installed)
# ============================================================================

if command -v docker &>/dev/null; then
  alias d='docker'
  alias dc='docker-compose'
  alias dps='docker ps'
  alias dpsa='docker ps -a'
  alias di='docker images'
  alias dex='docker exec -it'
  alias dlog='docker logs -f'
  alias dstop='docker stop'
  alias drm='docker rm'
  alias drmi='docker rmi'
  alias dprune='docker system prune -af'
fi

# ============================================================================
# CLIPBOARD (Wayland)
# ============================================================================

if command -v wl-copy &>/dev/null; then
  alias pbcopy='wl-copy'
  alias pbpaste='wl-paste'
  alias clip='wl-copy'
fi

# ============================================================================
# DEVELOPMENT
# ============================================================================

# Quick servers
alias serve='python -m http.server'
alias pyserve='python -m http.server'

# Node/npm
if command -v npm &>/dev/null; then
  alias ni='npm install'
  alias nid='npm install --save-dev'
  alias nig='npm install -g'
  alias nr='npm run'
  alias ns='npm start'
  alias nt='npm test'
  alias nb='npm run build'
fi

# Rust
if command -v cargo &>/dev/null; then
  alias cr='cargo run'
  alias cb='cargo build'
  alias ct='cargo test'
  alias cc='cargo check'
fi

# ============================================================================
# MISCELLANEOUS
# ============================================================================

# Quick reload
alias reload='source ~/.zshrc'
alias zshrc='$EDITOR ~/.config/zsh/.zshrc'

# IP addresses
alias myip='curl -s ifconfig.me'
alias localip='ip -4 addr show | grep inet | grep -v 127.0.0.1 | awk "{print \$2}" | cut -d/ -f1'

# Safety
alias chmod='chmod --preserve-root'
alias chown='chown --preserve-root'

# Timing
alias timer='time'
alias stopwatch='date +%s'

# Weather (if curl available)
alias weather='curl wttr.in'

# ============================================================================
# TYPO CORRECTIONS
# ============================================================================

alias sl='ls'
alias gti='git'
alias claer='clear'
alias clera='clear'
alias celar='clear'
