#!/usr/bin/env bash

if [[ "${AE_REFRESH_COMMANDS_SOURCED:-false}" == true ]]; then
  return 0
fi
AE_REFRESH_COMMANDS_SOURCED=true

AE_REFRESH_COMMANDS=(
  hyprland
  hypridle
  hyprlock
  hyprsunset
  walker
  waybar
  swayosd
  hypridle-restart
  hyprsunset-restart
  walker-restart
  waybar-restart
  swayosd-restart
)

ae_refresh_list_commands() {
  printf '%s\n' "${AE_REFRESH_COMMANDS[@]}"
}

_ae_refresh_rsync() {
  local src="$1"
  local dest="$2"
  if [[ ! -d "$src" ]]; then
    ae_cli_log_warn "refresh" "Source $src missing"
    return 1
  fi
  rsync -a --delete "$src/." "$dest/"
}

_ae_refresh_restart_service() {
  local service="$1"
  if command -v uwsm-app >/dev/null 2>&1; then
    pkill -x "$service" >/dev/null 2>&1 || true
    setsid uwsm-app -- "$service" >/dev/null 2>&1 &
  else
    pkill -x "$service" >/dev/null 2>&1 || true
    setsid "$service" >/dev/null 2>&1 &
  fi
}

ae_refresh_hyprland() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/hypr"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/hypr"
  _ae_refresh_rsync "$src" "$dest"
  hyprctl reload >/dev/null 2>&1 || true
  ae_cli_log_info "refresh" "Hyprland configuration updated."
}

ae_refresh_hypridle() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/hypr/hypridle.conf"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/hypr/hypridle.conf"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
  fi
  ae_refresh_hypridle_restart
}

ae_refresh_hyprlock() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/hypr/hyprlock.conf"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/hypr/hyprlock.conf"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
  fi
  ae_cli_log_info "refresh" "Hyprlock config updated."
}

ae_refresh_hyprsunset() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/hypr/hyprsunset.conf"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/hypr/hyprsunset.conf"
  if [[ -f "$src" ]]; then
    cp "$src" "$dest"
  fi
  ae_refresh_hyprsunset_restart
}

ae_refresh_walker() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/walker"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/walker"
  _ae_refresh_rsync "$src" "$dest"
  ae_refresh_walker_restart
}

ae_refresh_waybar() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/waybar"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/waybar"
  _ae_refresh_rsync "$src" "$dest"
  ae_refresh_waybar_restart
}

ae_refresh_swayosd() {
  local src="$ARCHENEMY_DEFAULTS_DIR/desktop/config/swayosd"
  local dest="$ARCHENEMY_USER_CONFIG_DIR/swayosd"
  _ae_refresh_rsync "$src" "$dest"
  ae_refresh_swayosd_restart
}

ae_refresh_hypridle_restart() {
  _ae_refresh_restart_service hypridle
  ae_cli_log_info "refresh" "Hypridle restarted."
}

ae_refresh_hyprsunset_restart() {
  _ae_refresh_restart_service hyprsunset
  ae_cli_log_info "refresh" "Hyprsunset restarted."
}

ae_refresh_walker_restart() {
  _ae_refresh_restart_service walker
  ae_cli_log_info "refresh" "Walker restarted."
}

ae_refresh_waybar_restart() {
  pkill -SIGUSR1 waybar >/dev/null 2>&1 || true
  if ! pgrep -x waybar >/dev/null 2>&1; then
    _ae_refresh_restart_service waybar
  fi
  ae_cli_log_info "refresh" "Waybar toggled/restarted."
}

ae_refresh_swayosd_restart() {
  _ae_refresh_restart_service swayosd
  ae_cli_log_info "refresh" "SwayOSD restarted."
}
