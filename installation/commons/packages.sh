#!/bin/bash
# Package helper collection. Provides thin wrappers around pacman/yay and
# manifest utilities so every module logs installations consistently.
# Preconditions: pacman/yay must be available and configured; manifests should
# contain newline-separated package identifiers.
# Postconditions: requested packages are queried or installed depending on the
# helper used.

if [[ "${ARCHENEMY_COMMONS_PACKAGES_SOURCED:-false}" == true ]]; then
  return 0
fi
ARCHENEMY_COMMONS_PACKAGES_SOURCED=true

_install_pacman_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing pacman packages: $*"
  run_cmd sudo pacman -S --noconfirm --needed "$@"
}

_aur_command_prefix() {
  local aur_user
  aur_user="$(archenemy_get_primary_user)"
  if [[ "$aur_user" == "root" || -z "$aur_user" ]]; then
    aur_user="archenemy-aur"
  fi
  if [[ "$EUID" -eq 0 ]]; then
    if ! id -u "$aur_user" >/dev/null 2>&1; then
      log_error "AUR builder user '$aur_user' not found. Ensure the system module ran first."
      exit 1
    fi
    printf 'sudo\0-H\0-u\0%s' "$aur_user"
  else
    printf ''
  fi
}

_run_as_aur_user() {
  local prefix
  prefix="$(_aur_command_prefix)"
  if [[ -n "$prefix" ]]; then
    # shellcheck disable=SC2206
    IFS=$'\0' read -r -a cmd_prefix <<<"$prefix"
    run_cmd "${cmd_prefix[@]}" "$@"
  else
    run_cmd "$@"
  fi
}

_install_aur_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing AUR packages: $*"
  _run_as_aur_user yay -S --noconfirm --needed "$@"
}

_archenemy_query_packages_with_pacman() {
  local packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return
  run_query_cmd sudo pacman -Sp --needed --print-format '%n %v' "${packages[@]}"
}

_archenemy_query_packages_with_yay() {
  local packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return
  _run_as_aur_user yay -Si "${packages[@]}"
}

_install_packages_from_manifest() {
  local manifest="$1"
  local installer="${2:-pacman}"
  if [[ ! -f "$manifest" ]]; then
    log_warn "Package manifest $manifest not found; skipping."
    return
  fi

  local -a packages=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    packages+=("$pkg")
  done < <(sed -E 's/#.*$//' "$manifest" | awk '{ $1=$1; if (NF) print }' || true)

  if [[ ${#packages[@]} -eq 0 ]]; then
    log_info "Package manifest $manifest is empty; nothing to install."
    return
  fi

  if [[ "$_ARCHENEMY_DRY_RUN" == true ]]; then
    log_info "Dry run active; skipping installation for $manifest"
    return
  fi

  if [[ "$installer" == "aur" ]]; then
    _install_aur_packages "${packages[@]}"
  else
    _install_pacman_packages "${packages[@]}"
  fi
}
