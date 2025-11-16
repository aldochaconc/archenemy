#!/bin/bash
# Networking/peripheral helpers. Configures NetworkManager, selects Wi-Fi
# backend, and enables Bluetooth/CUPS/Avahi services.
# Preconditions: commons + drivers core sourced; `systemctl`, `curl`, and
# NetworkManager/iwd available.
# Postconditions: services enabled, regulatory domain optionally set.

# DRIVERS_DIR=location of drivers helper scripts.
DRIVERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installation/commons/common.sh
source "$DRIVERS_DIR/../commons/common.sh"
# shellcheck source=installation/drivers/core.sh
source "$DRIVERS_DIR/core.sh"

##################################################################
# ARCHENEMY_DRIVERS_CONFIGURE_NETWORKING
# Installs and enables iwd plus ancillary networking tweaks so the
# desktop has Wi-Fi immediately after first boot.
##################################################################
archenemy_drivers_configure_networking() {
  log_info "Configuring networking services..."
  local wifi_backend="${ARCHENEMY_NETWORK_WIFI_BACKEND:-iwd}"
  local nm_conf_dir="/etc/NetworkManager/conf.d"
  local nm_conf_file="$nm_conf_dir/archenemy.conf"

  if [[ "$wifi_backend" == "iwd" ]]; then
    log_info "Using iwd as the NetworkManager Wi-Fi backend..."
    _enable_service "iwd.service"
    run_cmd sudo install -d -m 755 "$nm_conf_dir"
    run_cmd sudo tee "$nm_conf_file" >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF
  else
    log_info "Using NetworkManager's default Wi-Fi backend (wpa_supplicant)..."
    if [[ -f "$nm_conf_file" ]]; then
      run_cmd sudo rm -f "$nm_conf_file"
    fi
    if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
      run_cmd sudo systemctl disable iwd.service >/dev/null 2>&1 || true
    else
      run_cmd sudo systemctl disable --now iwd.service >/dev/null 2>&1 || true
    fi
  fi

  _enable_service "NetworkManager.service" "--now"
  run_cmd sudo systemctl disable systemd-networkd-wait-online.service
  run_cmd sudo systemctl mask systemd-networkd-wait-online.service
  local country_code=""
  if command -v curl >/dev/null 2>&1; then
    country_code=$(curl -fs --max-time 3 ipinfo.io/country || true)
  fi
  if [[ -n "$country_code" ]]; then
    log_info "Setting wireless regulatory domain to $country_code"
    run_cmd sudo tee /etc/conf.d/wireless-regdom >/dev/null <<<"WIRELESS_REGDOM=\"$country_code\""
    run_cmd sudo iw reg set "$country_code"
  else
    log_info "Unable to detect wireless regulatory domain (ipinfo query skipped or failed)."
  fi
}

##################################################################
# ARCHENEMY_DRIVERS_CONFIGURE_PERIPHERALS
# Boots peripheral daemons (Bluetooth, CUPS, Avahi) and disables USB
# autosuspend to avoid flaky input devices.
##################################################################
archenemy_drivers_configure_peripherals() {
  log_info "Configuring peripherals (Bluetooth, Printers, USB)..."
  _enable_service "bluetooth.service"
  _enable_service "cups.service"
  _enable_service "avahi-daemon.service"
  log_info "Disabling USB autosuspend to prevent input issues..."
  run_cmd sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf >/dev/null <<<"options usbcore autosuspend=-1"
}
