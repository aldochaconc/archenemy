sudo pacman -S --noconfirm --needed zsh zsh-completions

rm -rf "$HOME/.oh-my-zsh"
mkdir -p "$HOME/.config/zsh"

# Add "some" support for zsh
for zsh_file in "$OMARCHY_PATH"/default/zsh/*.zsh; do
  cp "$zsh_file" "$HOME/.config/zsh/"
done
cp "$OMARCHY_PATH/default/zshrc" "$HOME/.zshrc"
sudo chsh -s /bin/zsh "$USER"
