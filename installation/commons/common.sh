#!/bin/bash
# Archenemy commons aggregator. Provides a single entry point that sources every
# helper required by the installer (logging, environment, package helpers,
# systemd wrappers, and sentinel utilities).
# Preconditions: must be invoked from bash with access to this directory.
# Postconditions: sourcing scripts may rely on the helper functions and globals
# defined in the sibling files listed below.

# Guard to avoid double-loading helpers during chained `source` calls.
if [[ "${ARCHENEMY_COMMON_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMON_SOURCED=true

# COMMONS_ROOT=absolute path to this directory.
COMMONS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load helper modules in a deterministic order so shellcheck can resolve refs.
# shellcheck source=installation/commons/core.sh
source "$COMMONS_ROOT/core.sh"
# shellcheck source=installation/commons/env.sh
source "$COMMONS_ROOT/env.sh"
# shellcheck source=installation/commons/packages.sh
source "$COMMONS_ROOT/packages.sh"
# shellcheck source=installation/commons/systemd.sh
source "$COMMONS_ROOT/systemd.sh"
# shellcheck source=installation/commons/sentinel.sh
source "$COMMONS_ROOT/sentinel.sh"
