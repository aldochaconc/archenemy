mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/pacman.packages" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${packages[@]}"
