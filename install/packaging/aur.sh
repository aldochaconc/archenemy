# Install AUR packages (no mirror dependency)
# Priority: install directly from AUR using makepkg; optional fallback to yay if available.

set -euo pipefail

AUR_LIST_FILE="$OMARCHY_INSTALL/aur.packages"

if [[ ! -f "$AUR_LIST_FILE" ]]; then
  echo "No AUR list found at $AUR_LIST_FILE; skipping." >&2
  exit 0
fi

# Read packages (skip comments/blank)
mapfile -t packages < <(grep -v '^#' "$AUR_LIST_FILE" | grep -v '^$' || true)
if [[ ${#packages[@]} -eq 0 ]]; then
  echo "AUR package list is empty; nothing to do."
  exit 0
fi

# Ensure prerequisites for building AUR packages
sudo pacman -S --noconfirm --needed base-devel git

# Optional: if yay is available and AUR accessible, you can enable this path
if command -v yay >/dev/null 2>&1; then
  echo "yay detected; attempting install via yay (will fallback to makepkg on failure)."
  if ! yay -S --noconfirm --needed "${packages[@]}"; then
    echo "yay path failed; falling back to makepkg flow." >&2
  else
    exit 0
  fi
fi

# makepkg flow (sequential; safer for resource usage)
BUILDROOT="${TMPDIR:-/tmp}/aur-build-$(id -u)"
mkdir -p "$BUILDROOT"

install_pkg_makepkg() {
  local pkg="$1"
  local dir="$BUILDROOT/$pkg"
  rm -rf "$dir"
  git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "$dir"
  pushd "$dir" >/dev/null
  # --syncdeps to pull required pacman deps; --needed to avoid reinstalls
  makepkg -si --noconfirm --needed --noprogressbar
  popd >/dev/null
}

for p in "${packages[@]}"; do
  echo "[AUR] Installing $p"
  install_pkg_makepkg "$p"
  echo "[AUR] Installed $p"
done

echo "AUR installation step completed."
