#!/bin/bash
# systemd helpers abstract differences between chroot and live installs when
# enabling units. Keeps service management centralized for consistency.
# Preconditions: `systemctl` must be available; env.sh should define
# ARCHENEMY_CHROOT_INSTALL.
# Postconditions: requested units are enabled with the provided extra args.

if [[ "${ARCHENEMY_COMMONS_SYSTEMD_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMONS_SYSTEMD_SOURCED=true

_enable_service() {
  local unit="$1"
  shift || true
  local extra_args=("$@")

  if [[ "$ARCHENEMY_CHROOT_INSTALL" == true ]]; then
    run_cmd sudo env SYSTEMD_OFFLINE=1 systemctl --system --offline enable "$unit"
    return
  fi

  if [[ ${#extra_args[@]} -gt 0 ]]; then
    sudo systemctl enable "${extra_args[@]}" "$unit"
  else
    sudo systemctl enable "$unit"
  fi
}
