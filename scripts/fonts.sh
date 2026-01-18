#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/brew.sh
. "$SCRIPT_DIR/../lib/brew.sh"

info "Nerd Fonts installation..."
brew_tap_if_missing homebrew/cask-fonts

FONT_SELECTIONS="$(ask_multi \
  "FiraCode Nerd Font" \
  "JetBrainsMono Nerd Font" \
|| exit $?)"

WANT_FIRA=0
WANT_JB=0
echo "$FONT_SELECTIONS" | grep -Fqx "FiraCode Nerd Font" && WANT_FIRA=1 || true
echo "$FONT_SELECTIONS" | grep -Fqx "JetBrainsMono Nerd Font" && WANT_JB=1 || true

FONTS_INSTALLED_ANY=0

if [ "$WANT_FIRA" -eq 1 ]; then
  brew_cask_install_if_missing font-fira-code-nerd-font
  FONTS_INSTALLED_ANY=1
else
  add_item SKIPPED "font-fira-code-nerd-font"
fi

if [ "$WANT_JB" -eq 1 ]; then
  brew_cask_install_if_missing font-jetbrains-mono-nerd-font
  FONTS_INSTALLED_ANY=1
else
  add_item SKIPPED "font-jetbrains-mono-nerd-font"
fi

if [ "$FONTS_INSTALLED_ANY" -eq 1 ]; then
  add_item NOTES "Restart apps (Terminal/VS Code) to pick up new fonts"
fi

ok "Fonts setup complete."
