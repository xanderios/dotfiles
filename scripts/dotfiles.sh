#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

DOTFILES_REPO_URL="https://github.com/xanderios/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

info "Setting up dotfiles..."

if [ -d "$DOTFILES_DIR/.git" ]; then
  ok "Dotfiles repo already exists at $DOTFILES_DIR"
  if ask_confirm "Pull latest changes?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item NOTES "Would git pull dotfiles"
    else
      (cd "$DOTFILES_DIR" && git pull --ff-only) || warn "Could not pull (check network/branch)."
      add_item NOTES "Dotfiles updated (git pull)"
    fi
  else
    add_item SKIPPED "Dotfiles git pull"
  fi
else
  if [ -e "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR" ]; then
    err "$DOTFILES_DIR exists and is not a directory. Fix it and re-run."
    exit 1
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    add_item NOTES "Would git clone dotfiles to $DOTFILES_DIR"
  else
    info "Cloning dotfiles..."
    run_cmd git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
    add_item NOTES "Dotfiles cloned"
  fi
fi

# Select symlinks (only selected items will be previewed)
info "Select dotfiles to symlink (optional)..."
LINK_SELECTIONS="$(ask_multi .editorconfig .gitconfig .zshrc .zprofile .p10k.zsh || exit $?)"

# Build selected list
WANT_EDITOR=0
WANT_GIT=0
WANT_ZSHRC=0
WANT_ZPROFILE=0
WANT_P10K=0

echo "$LINK_SELECTIONS" | grep -Fqx .editorconfig && WANT_EDITOR=1 || true
echo "$LINK_SELECTIONS" | grep -Fqx .gitconfig    && WANT_GIT=1 || true
echo "$LINK_SELECTIONS" | grep -Fqx .zshrc        && WANT_ZSHRC=1 || true
echo "$LINK_SELECTIONS" | grep -Fqx .zprofile     && WANT_ZPROFILE=1 || true
echo "$LINK_SELECTIONS" | grep -Fqx .p10k.zsh     && WANT_P10K=1 || true

# Map repo paths (your current layout)
SRC_EDITOR="$DOTFILES_DIR/.editorconfig"
SRC_GIT="$DOTFILES_DIR/.gitconfig"
SRC_ZSHRC="$DOTFILES_DIR/macos/.zshrc"
SRC_ZPROFILE="$DOTFILES_DIR/macos/.zprofile"
SRC_P10K="$DOTFILES_DIR/macos/.p10k.zsh"

# Preview (only selected)
PREVIEW=""
preview_line() {
  src="$1"; dst="$2"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    PREVIEW="$PREVIEW
OK: $dst -> $src (already)"
    return 0
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    b="${dst}.bak"
    if [ -e "$b" ]; then
      PREVIEW="$PREVIEW
SKIP: $dst exists and $b exists (would not overwrite)"
    else
      PREVIEW="$PREVIEW
PLAN: backup $dst -> $b; link $dst -> $src"
    fi
    return 0
  fi

  if [ -L "$dst" ]; then
    PREVIEW="$PREVIEW
PLAN: update symlink $dst -> $src"
    return 0
  fi

  PREVIEW="$PREVIEW
PLAN: link $dst -> $src"
}

if [ "$WANT_EDITOR" -eq 1 ]; then preview_line "$SRC_EDITOR" "$HOME/.editorconfig"; fi
if [ "$WANT_GIT" -eq 1 ]; then preview_line "$SRC_GIT" "$HOME/.gitconfig"; fi
if [ "$WANT_ZSHRC" -eq 1 ]; then preview_line "$SRC_ZSHRC" "$HOME/.zshrc"; fi
if [ "$WANT_ZPROFILE" -eq 1 ]; then preview_line "$SRC_ZPROFILE" "$HOME/.zprofile"; fi
if [ "$WANT_P10K" -eq 1 ]; then preview_line "$SRC_P10K" "$HOME/.p10k.zsh"; fi

if [ -n "$PREVIEW" ]; then
  info "Symlink preview (selected items only):"
  # Trim leading newline
  printf "%s\n" "$(printf "%s" "$PREVIEW" | sed '1{/^$/d;}')"

  if ask_confirm "Apply these symlinks now?"; then
    [ "$WANT_EDITOR" -eq 1 ] && ensure_symlink "$SRC_EDITOR" "$HOME/.editorconfig"
    [ "$WANT_GIT" -eq 1 ] && ensure_symlink "$SRC_GIT" "$HOME/.gitconfig"
    [ "$WANT_ZSHRC" -eq 1 ] && ensure_symlink "$SRC_ZSHRC" "$HOME/.zshrc"
    [ "$WANT_ZPROFILE" -eq 1 ] && ensure_symlink "$SRC_ZPROFILE" "$HOME/.zprofile"
    [ "$WANT_P10K" -eq 1 ] && ensure_symlink "$SRC_P10K" "$HOME/.p10k.zsh"
    add_item NOTES "Dotfiles symlinks applied (selected)"
  else
    add_item SKIPPED "Dotfiles symlinks"
  fi
else
  add_item SKIPPED "Dotfiles symlinks (none selected)"
fi

ok "Dotfiles step complete."
