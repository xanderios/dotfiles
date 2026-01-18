#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/brew.sh
. "$SCRIPT_DIR/../lib/brew.sh"

info "Select development tools to install..."

SELECTIONS="$(ask_multi git wget neovim zoxide fzf nvm || exit $?)"

INSTALL_GIT=0
INSTALL_WGET=0
INSTALL_NEOVIM=0
INSTALL_ZOXIDE=0
INSTALL_FZF=0
INSTALL_NVM=0

echo "$SELECTIONS" | grep -Fqx git     && INSTALL_GIT=1 || true
echo "$SELECTIONS" | grep -Fqx wget    && INSTALL_WGET=1 || true
echo "$SELECTIONS" | grep -Fqx neovim  && INSTALL_NEOVIM=1 || true
echo "$SELECTIONS" | grep -Fqx zoxide  && INSTALL_ZOXIDE=1 || true
echo "$SELECTIONS" | grep -Fqx fzf     && INSTALL_FZF=1 || true
echo "$SELECTIONS" | grep -Fqx nvm     && INSTALL_NVM=1 || true

# Install selected tools
[ "$INSTALL_GIT" -eq 1 ] && brew_install_if_missing git || add_item SKIPPED "git"
[ "$INSTALL_WGET" -eq 1 ] && brew_install_if_missing wget || add_item SKIPPED "wget"
[ "$INSTALL_NEOVIM" -eq 1 ] && brew_install_if_missing neovim || add_item SKIPPED "neovim"
[ "$INSTALL_ZOXIDE" -eq 1 ] && brew_install_if_missing zoxide || add_item SKIPPED "zoxide"
[ "$INSTALL_FZF" -eq 1 ] && brew_install_if_missing fzf || add_item SKIPPED "fzf"

if [ "$INSTALL_NVM" -eq 1 ]; then
  info "Installing nvm..."
  brew_install_if_missing nvm
  append_line_if_missing 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  append_line_if_missing '[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"' "$HOME/.zshrc"
  append_line_if_missing '[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"' "$HOME/.zshrc"
  add_item NOTES "nvm configured in ~/.zshrc"
else
  add_item SKIPPED "nvm"
fi

ok "Development tools setup complete."
