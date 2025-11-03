# Install AUR packages using yay
if omarchy-pkg-aur-accessible; then
  echo "Installing AUR packages..."
  mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-aur.packages" | grep -v '^$')
  if [[ ${#packages[@]} -gt 0 ]]; then
    yay -S --noconfirm --needed "${packages[@]}"
  fi
else
  echo "AUR is unavailable, skipping AUR packages installation"
fi
