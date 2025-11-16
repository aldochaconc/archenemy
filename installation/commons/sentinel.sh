#!/bin/bash
# Sentinel helpers track whether the post-install phase still needs to run.
# They install a login hook that prompts the user to rerun the installer until
# the cleanup phase has completed.
# Preconditions: env.sh must have defined ARCHENEMY_DEFAULTS_DIR etc., sudo may
# be required to install profile scripts.
# Postconditions: sentinel files exist (register) or are removed (remove).

if [[ "${ARCHENEMY_COMMONS_SENTINEL_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMONS_SENTINEL_SOURCED=true

# SENTINEL_DEFAULTS_DIR=templates for postinstall profile scripts.
SENTINEL_DEFAULTS_DIR="$ARCHENEMY_DEFAULTS_DIR/sentinel"
# SENTINEL_STATE_DIR=archinstall workspace storing sentinel flag.
SENTINEL_STATE_DIR="$ARCHENEMY_ARCHINSTALL_DIR"
# SENTINEL_FILE=file that signals pending postinstall actions.
SENTINEL_FILE="$SENTINEL_STATE_DIR/postinstall-required"
# SENTINEL_PROFILE_TARGET=/etc/profile.d hook executed on login.
SENTINEL_PROFILE_TARGET="/etc/profile.d/archenemy-postinstall.sh"

_archenemy_render_sentinel_profile() {
  local template="$SENTINEL_DEFAULTS_DIR/postinstall-profile.sh"
  if [[ ! -f "$template" ]]; then
    log_error "Missing sentinel profile template at $template."
    exit 1
  fi
  local tmp
  tmp="$(mktemp)"
  sed -e "s|{{SENTINEL_PATH}}|$SENTINEL_FILE|g" \
      -e "s|{{BOOT_PATH}}|$ARCHENEMY_INSTALL_ROOT/boot.sh|g" \
      "$template" >"$tmp"
  echo "$tmp"
}

archenemy_register_sentinel() {
  log_info "Registering post-install sentinel at $SENTINEL_FILE..."
  run_cmd install -d -m 755 "$SENTINEL_STATE_DIR"
  run_cmd touch "$SENTINEL_FILE"
  run_cmd sudo install -d -m 755 /etc/profile.d
  local rendered
  rendered="$(_archenemy_render_sentinel_profile)"
  run_cmd sudo install -m 644 "$rendered" "$SENTINEL_PROFILE_TARGET"
  rm -f "$rendered"
  log_success "Post-install login prompt installed at $SENTINEL_PROFILE_TARGET."
}

archenemy_remove_sentinel() {
  log_info "Removing post-install sentinel from $SENTINEL_FILE..."
  if [[ -f "$SENTINEL_FILE" ]]; then
    run_cmd rm -f "$SENTINEL_FILE"
  fi
  if [[ -f "$SENTINEL_PROFILE_TARGET" ]]; then
    run_cmd sudo rm -f "$SENTINEL_PROFILE_TARGET"
  fi
  if [[ -d "$SENTINEL_STATE_DIR" && -z "$(ls -A "$SENTINEL_STATE_DIR")" ]]; then
    run_cmd rmdir "$SENTINEL_STATE_DIR"
  fi
  log_success "Post-install prompt assets removed."
}
