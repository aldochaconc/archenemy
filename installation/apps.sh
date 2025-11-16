#!/bin/bash
# Apps module. Installs custom .desktop launchers and icon assets bundled in
# `installation/defaults/applications` so webapps/native apps integrate cleanly.
# Preconditions: commons sourced; defaults/applications directory populated.
# Postconditions: ~/.local/share/applications and ~/.local/share/icons updated.

# MODULE_DIR=absolute path to installation scripts root.
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$MODULE_DIR/commons/common.sh"

# APPS_DEFAULTS_DIR=directory containing .desktop files, hidden entries, icons.
APPS_DEFAULTS_DIR="$ARCHENEMY_DEFAULTS_DIR/applications"

##################################################################
# _APPS_COPY_ICON_ASSETS
# Copies PNG assets bundled with the module so desktop entries look
# native even when no system icon exists.
##################################################################
_apps_copy_icon_assets() {
  local icons_source="$APPS_DEFAULTS_DIR/icons"
  local icons_target="$HOME/.local/share/icons"
  if [[ -d "$icons_source" ]]; then
    log_info "Installing app icon assets..."
    run_cmd mkdir -p "$icons_target"
    run_cmd cp -r "$icons_source/." "$icons_target/"
  fi
}

##################################################################
# _APPS_INSTALL_DESKTOP_ENTRIES
# Installs .desktop launchers (and hidden helper entries) from the
# module defaults into ~/.local/share/applications.
##################################################################
_apps_install_desktop_entries() {
  local applications_dir="$HOME/.local/share/applications"
  if [[ ! -d "$APPS_DEFAULTS_DIR" ]]; then
    log_info "Apps defaults not found at $APPS_DEFAULTS_DIR"
    return
  fi
  log_info "Installing desktop/webapp launchers..."
  run_cmd mkdir -p "$applications_dir"
  while IFS= read -r -d '' entry; do
    local name
    name="$(basename "$entry")"
    if [[ "$name" == "icons" ]]; then
      continue
    fi
    if [[ -d "$entry" ]]; then
      run_cmd rm -rf "$applications_dir/$name"
      run_cmd cp -r "$entry" "$applications_dir/"
    else
      run_cmd cp "$entry" "$applications_dir/"
    fi
  done < <(find "$APPS_DEFAULTS_DIR" -mindepth 1 -maxdepth 1 -print0)
  run_cmd update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
}

##################################################################
# RUN_APPS_PREINSTALL
# Installs any helper packages (desktop-file-utils) and stages the
# launchers/icons prior to copying the desktop blueprint.
##################################################################
run_apps_preinstall() {
  log_info "Apps module preinstall: staging desktop entries..."
  _apps_copy_icon_assets
  _apps_install_desktop_entries
  log_success "Apps module preinstall completed."
}

##################################################################
# RUN_APPS_POSTINSTALL
# Idempotently refreshes launchers so re-runs stay consistent.
##################################################################
run_apps_postinstall() {
  log_info "Apps module postinstall: refreshing desktop database..."
  _apps_install_desktop_entries
  log_success "Apps module postinstall completed."
}

##################################################################
# RUN_APPS
# Dispatches to phase-appropriate handler.
##################################################################
run_apps() {
  if [[ "${ARCHENEMY_PHASE:-preinstall}" == "postinstall" ]]; then
    run_apps_postinstall "$@"
  else
    run_apps_preinstall "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  run_apps "$@"
fi
