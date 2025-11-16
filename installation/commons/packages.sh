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

_install_aur_packages() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  log_info "Installing AUR packages: $*"
  run_cmd yay -S --noconfirm --needed "$@"
}

_archenemy_query_packages_with_pacman() {
  local packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return
  run_query_cmd sudo pacman -Sp --needed --print-format '%n %v' "${packages[@]}"
}

_archenemy_query_packages_with_yay() {
  local packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return
  run_query_cmd yay -Si "${packages[@]}"
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

  if [[ "$installer" == "aur" ]]; then
    _archenemy_query_packages_with_yay "${packages[@]}"
  else
    _archenemy_query_packages_with_pacman "${packages[@]}"
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
