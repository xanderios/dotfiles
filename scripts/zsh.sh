#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/brew.sh
. "$SCRIPT_DIR/../lib/brew.sh"

info "Installing Zsh extras..."
brew_install_if_missing powerlevel10k

if [ -d "$HOME/.oh-my-zsh" ]; then
  ok "Oh My Zsh already present."
else
  if ask_confirm "Install Oh My Zsh (unattended)?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item NOTES "Would install Oh My Zsh"
    else
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      add_item INSTALLED "Oh My Zsh"
    fi
  else
    add_item SKIPPED "Oh My Zsh"
  fi
fi

P10K_LINE='source "$(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme"'
append_line_if_missing "$P10K_LINE" "$HOME/.zshrc"

ok "Zsh setup complete."
