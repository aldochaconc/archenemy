#!/bin/bash
# Global installer configuration. Centralizes toggles that every module can
# read (kernel flavor, driver preferences, user overrides, etc.).
# Preconditions: optional environment overrides may be exported by the caller.
# Postconditions: exported variables reflect either the provided override or the
# default documented below.

# Primary desktop user metadata (persisted under /var/lib/archenemy).
export ARCHENEMY_PRIMARY_USER="${ARCHENEMY_PRIMARY_USER:-}"
export ARCHENEMY_PRIMARY_UID="${ARCHENEMY_PRIMARY_UID:-}"
export ARCHENEMY_PRIMARY_GID="${ARCHENEMY_PRIMARY_GID:-}"

# Session defaults
export ARCHENEMY_DEFAULT_SESSION="${ARCHENEMY_DEFAULT_SESSION:-hyprland-uwsm}"
export ARCHENEMY_DEFAULT_SHELL="${ARCHENEMY_DEFAULT_SHELL:-zsh}"

# Networking defaults
export ARCHENEMY_NETWORK_WIFI_BACKEND="${ARCHENEMY_NETWORK_WIFI_BACKEND:-iwd}"

# Optional Git identity overrides
export ARCHENEMY_USER_NAME="${ARCHENEMY_USER_NAME:-}"
export ARCHENEMY_USER_EMAIL="${ARCHENEMY_USER_EMAIL:-}"
