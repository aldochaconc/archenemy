#!/bin/bash
#
# ################################################################################
# Archenemy Installation Helpers
# ################################################################################
#
# This library centralizes shared helper functions so that the main installer
# stays focused on orchestration. It is sourced right after the repository is
# cloned, providing consistent logging, package helpers, and systemd utilities.
#

# --- Defensive Defaults -------------------------------------------------------
#
# Ensure critical variables exist even if the caller forgot to export them.
#
: "${ARCHENEMY_INSTALL_LOG_FILE:=/var/log/archenemy-install.log}"
: "${ARCHENEMY_CHROOT_INSTALL:=false}"

# --- Logging Primitives -------------------------------------------------------
#
# Provides the same colorized output format used in boot.sh.
# Messages are echoed to stdout/stderr for immediate
# feedback, while run_task handles detailed log redirection.
#
__archenemy__print_log() {
  local level="$1"
  local message="$2"
  local color_code

  case "$level" in
  INFO) color_code="\e[34m" ;;
  SUCCESS) color_code="\e[32m" ;;
  ERROR) color_code="\e[31m" ;;
  *) color_code="\e[0m" ;;
  esac

  printf "%b[%s] %s\e[0m\n" "$color_code" "$level" "$message"
}

log_info() {
  __archenemy__print_log "INFO" "$1"
}

log_success() {
  __archenemy__print_log "SUCCESS" "$1"
}

log_error() {
  __archenemy__print_log "ERROR" "$1" >&2
}

# --- Package Helpers ----------------------------------------------------------
#
# Thin wrappers around pacman/yay that keep logging consistent and soften the
# calling code.
#
_install_pacman_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing pacman packages: $*"
  sudo pacman -S --noconfirm --needed "$@"
}

_install_aur_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing AUR packages: $*"
  yay -S --noconfirm --needed "$@"
}

# --- Hardware & Driver Helpers ------------------------------------------------
#
# Functions to detect hardware and determine correct driver configurations.
#

#
# Determines the correct kernel headers package to install.
# It checks for common custom kernels like 'zen' or 'lts' and defaults to
# the standard 'linux-headers' if none are found.
#
# Outputs:
#   The name of the headers package (e.g., "linux-zen-headers").
#
_get_kernel_headers() {
  if pacman -Q linux-zen &>/dev/null; then
    echo "linux-zen-headers"
  elif pacman -Q linux-lts &>/dev/null; then
    echo "linux-lts-headers"
  else
    echo "linux-headers"
  fi
}

#
# Checks if a GPU from a specific vendor is present in the system.
#
# Arguments:
#   $1: The vendor to check for (e.g., "intel", "amd", "nvidia").
#
# Returns:
#   0 if the GPU is found, 1 otherwise.
#
_has_gpu() {
  lspci | grep -iE 'vga|3d|display' | grep -qi "$1"
}

#
# Checks if a newer NVIDIA GPU is present that supports open-source drivers.
# This specifically looks for RTX 20 series and newer, and GTX 16 series.
#
# Returns:
#   0 if a supported GPU is found, 1 otherwise.
#
_has_nvidia_open_gpu() {
  lspci | grep -i 'nvidia' | grep -q -E "RTX [2-9][0-9]|GTX 16"
}

# --- Desktop Entry Helpers ----------------------------------------------------
#
# Functions to create .desktop files for TUIs and Webapps, allowing them to
# be launched from application menus.
#

#
# Creates a .desktop file for a given terminal application.
#
# Arguments:
#   $1: The application name (e.g., "LazyDocker").
#   $2: The command to execute (e.g., "lazydocker").
#   $3: A comment describing the application.
#   $4: The application category (e.g., "utilities").
#
_create_desktop_entry() {
  local name="$1"
  local exec_cmd="$2"
  local comment="$3"
  local category="$4"
  local desktop_file="$HOME/.local/share/applications/${name}.desktop"

  tee "$desktop_file" >/dev/null <<EOF
[Desktop Entry]
Name=${name}
Exec=${exec_cmd}
Comment=${comment}
Type=Application
Categories=${category}
Terminal=true
EOF
}

#
# Creates a .desktop file for a web application.
#
# Arguments:
#   $1: The application name (e.g., "GitHub").
#   $2: The URL to open (e.g., "https://github.com").
#
_create_webapp_entry() {
  local name="$1"
  local url="$2"
  local desktop_file="$HOME/.local/share/applications/${name}.desktop"

  tee "$desktop_file" >/dev/null <<EOF
[Desktop Entry]
Name=${name}
Exec=chromium --app=${url}
Type=Application
Categories=Network;WebBrowser;
EOF
}

# --- systemd Helpers ----------------------------------------------------------
#
# Enabling services differs between chroot installs (where daemons cannot be
# started) and live installs. This helper encapsulates that branching logic.
#
_enable_service() {
  local unit="$1"
  shift || true
  local extra_args=("$@")

  if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
    sudo systemctl enable "$unit"
    return
  fi

  if [[ ${#extra_args[@]} -gt 0 ]]; then
    sudo systemctl enable "${extra_args[@]}" "$unit"
  else
    sudo systemctl enable "$unit"
  fi
}
