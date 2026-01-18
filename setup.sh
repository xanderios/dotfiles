#!/bin/sh
set -eu

OS="$(uname -s)"

# --------- UI helpers ----------
BLUE="$(printf '\033[34m')"
YELLOW="$(printf '\033[33m')"
GREEN="$(printf '\033[32m')"
RED="$(printf '\033[31m')"
RESET="$(printf '\033[0m')"

# --------- utility functions ----------
info()  { printf "%s%s%s\n" "$BLUE" "$*" "$RESET"; }
warn()  { printf "%s%s%s\n" "$YELLOW" "$*" "$RESET"; }
ok()    { printf "%s%s%s\n" "$GREEN" "$*" "$RESET"; }
err()   { printf "%s%s%s\n" "$RED" "$*" "$RESET"; }

confirm() {
  # usage: confirm "Question?"  (returns 0 for yes, 1 for no)
  printf "%s (y/n) " "$1"
  # -n/-s not POSIX; keep simple and portable
  read ans || true
  case "${ans:-}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

append_line_if_missing() {
  # usage: append_line_if_missing "line" "file"
  line="$1"
  file="$2"
  dir="$(dirname "$file")"
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$file" ] || : > "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf "%s\n" "$line" >> "$file"
}

ensure_symlink() {
  # usage: ensure_symlink /path/to/source /path/to/dest
  src="$1"
  dst="$2"

  if [ -L "$dst" ]; then
    # if already correct, do nothing
    if [ "$(readlink "$dst")" = "$src" ]; then
      ok "Symlink ok: $dst -> $src"
      return 0
    fi
    warn "Updating symlink: $dst"
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    # back up existing file/dir only once
    backup="${dst}.bak"
    if [ ! -e "$backup" ]; then
      warn "Backing up existing: $dst -> $backup"
      mv "$dst" "$backup"
    else
      warn "Existing $dst and backup already exists; leaving $dst untouched."
      return 0
    fi
  fi

  ln -s "$src" "$dst"
  ok "Linked: $dst -> $src"
}

# --------- start ----------
# if ! confirm "Run setup on $OS?"; then
#   warn "Setup cancelled by user."
#   exit 0
# fi
if has_cmd gum; then
	if gum confirm "Run setup on $OS?"; then
		:
	else
		warn "Setup cancelled by user."
		exit 0
	fi
else
	if confirm "Run setup on $OS?"; then
		:
	else
		warn "Setup cancelled by user."
		exit 0
	fi
fi

info "Running setup for $OS..."

if [ "$OS" != "Darwin" ]; then
  err "This version is macOS-first. Exiting."
  exit 1
fi

# --------- macOS: prerequisites ----------
info "Checking prerequisites..."

if ! has_cmd curl; then
  err "curl is required but not found. Install Xcode Command Line Tools or curl first."
  exit 1
fi

# Install Xcode Command Line Tools if needed (idempotent)
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found."
  if confirm "Install Xcode Command Line Tools now?"; then
    xcode-select --install || true
    warn "If a GUI prompt appeared, complete it, then re-run this script."
    exit 0
  else
    err "Cannot proceed without Command Line Tools."
    exit 1
  fi
fi

# --------- Homebrew ----------
BREW_BIN=""
if [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN="/opt/homebrew/bin/brew"   # Apple Silicon
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN="/usr/local/bin/brew"      # Intel
fi

if [ -z "$BREW_BIN" ]; then
  warn "Homebrew not found."
  if confirm "Install Homebrew?"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    err "Homebrew is required for the rest of this script."
    exit 1
  fi

  # Re-detect after install
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN="/usr/local/bin/brew"
  fi

	if [ -z "$BREW_BIN" ]; then
		err "Homebrew installation not found after install. Exiting."
		exit 1
	fi
fi

# Ensure brew is on PATH for current process + future shells (idempotent)
BREW_PREFIX="$("$BREW_BIN" --prefix)"
SHELLENV_LINE="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""

# Add to both common macOS shell startup files safely
append_line_if_missing "$SHELLENV_LINE" "$HOME/.zprofile"
append_line_if_missing "$SHELLENV_LINE" "$HOME/.profile"

# Apply for current run
# shellcheck disable=SC1090
eval "$("$BREW_BIN" shellenv)"

ok "Homebrew ready: $(brew --version | head -n 1)"

if confirm "Run 'brew update' + 'brew upgrade'?"; then
  info "Updating Homebrew..."
  brew update
  brew upgrade || true
else
  warn "Skipping brew update/upgrade."
fi

brew_install_if_missing() {
  pkg="$1"
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "Already installed: $pkg"
  else
    info "Installing: $pkg"
    brew install "$pkg"
  fi
}

brew_tap_if_missing() {
  tap="$1"
  if brew tap | grep -Fxq "$tap"; then
    ok "Tap exists: $tap"
  else
    info "Tapping: $tap"
    brew tap "$tap"
  fi
}

# --------- package choices (gum) ----------
info "Select what to install (checkboxes)."

# Ensure gum exists (optional install)
if ! has_cmd gum; then
  warn "gum not found (needed for checkbox UI)."
  if confirm "Install gum with Homebrew?"; then
    brew_install_if_missing gum
  else
    warn "Falling back to y/n prompts."
  fi
fi

INSTALL_DEVTOOLS=0
INSTALL_ZSH=0
INSTALL_ZOXIDE=0
INSTALL_FZF=0
INSTALL_NVM=0

if has_cmd gum; then
  # Use short keys only to avoid fragile string matching.
  # gum prints selected items, one per line
  SELECTIONS="$(gum choose --no-limit \
    devtools \
    zsh \
    zoxide \
    fzf \
    nvm \
  || true)"

  echo "$SELECTIONS" | grep -Fqx devtools && INSTALL_DEVTOOLS=1 || true
  echo "$SELECTIONS" | grep -Fqx zsh      && INSTALL_ZSH=1 || true
  echo "$SELECTIONS" | grep -Fqx zoxide   && INSTALL_ZOXIDE=1 || true
  echo "$SELECTIONS" | grep -Fqx fzf      && INSTALL_FZF=1 || true
  echo "$SELECTIONS" | grep -Fqx nvm      && INSTALL_NVM=1 || true

  # Show what the keys mean (after selection, so UI stays clean)
  info "Selected keys:"
  printf "  devtools  - git, wget, neovim\n"
  printf "  zsh       - oh-my-zsh, powerlevel10k\n"
  printf "  zoxide    - faster cd\n"
  printf "  fzf       - fuzzy finder\n"
  printf "  nvm       - Node Version Manager\n"
else
  if confirm "Install CLI dev tools (git, wget, neovim)?"; then INSTALL_DEVTOOLS=1; fi
  if confirm "Install Zsh extras (Oh My Zsh, powerlevel10k)?"; then INSTALL_ZSH=1; fi
  if confirm "Install zoxide (faster cd)?"; then INSTALL_ZOXIDE=1; fi
  if confirm "Install fzf (fuzzy finder)?"; then INSTALL_FZF=1; fi
  if confirm "Install nvm (Node Version Manager)?"; then INSTALL_NVM=1; fi
fi

# --------- installs ----------
if [ "$INSTALL_DEVTOOLS" -eq 1 ]; then
  info "Installing CLI dev tools..."
  brew_install_if_missing git
  brew_install_if_missing wget
  brew_install_if_missing neovim
fi

if [ "$INSTALL_ZSH" -eq 1 ]; then
  info "Installing Zsh extras..."
  brew_install_if_missing powerlevel10k

  if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "Oh My Zsh already present."
  else
    if confirm "Install Oh My Zsh (unattended)?"; then
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      ok "Oh My Zsh installed."
    else
      warn "Skipping Oh My Zsh."
    fi
  fi

  P10K_LINE='source "$(brew --prefix)/opt/powerlevel10k/powerlevel10k.zsh-theme"'
  append_line_if_missing "$P10K_LINE" "$HOME/.zshrc"
fi

if [ "$INSTALL_ZOXIDE" -eq 1 ]; then
  info "Installing zoxide..."
  brew_install_if_missing zoxide
fi

if [ "$INSTALL_FZF" -eq 1 ]; then
  info "Installing fzf..."
  brew_install_if_missing fzf
fi

if [ "$INSTALL_NVM" -eq 1 ]; then
  info "Installing nvm..."
  brew_install_if_missing nvm
  # shell setup (idempotent)
  append_line_if_missing 'export NVM_DIR="$HOME/.nvm"' "$HOME/.zshrc"
  append_line_if_missing '[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"' "$HOME/.zshrc"
  append_line_if_missing '[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"' "$HOME/.zshrc"
fi

# --------- dotfiles ----------
DOTFILES_REPO_URL="https://github.com/xanderios/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

INSTALL_DOTFILES=0
if has_cmd gum; then
  if gum confirm "Clone/update dotfiles and (optionally) create symlinks?"; then
    INSTALL_DOTFILES=1
  fi
else
  if confirm "Clone/update dotfiles and (optionally) create symlinks?"; then
    INSTALL_DOTFILES=1
  fi
fi

if [ "$INSTALL_DOTFILES" -eq 1 ]; then
  info "Setting up dotfiles..."

  if [ -d "$DOTFILES_DIR/.git" ]; then
    ok "Dotfiles repo already exists at $DOTFILES_DIR"
    if has_cmd gum; then
      if gum confirm "Pull latest changes?"; then
        (cd "$DOTFILES_DIR" && git pull --ff-only) || warn "Could not pull (check network/branch)."
      fi
    else
      if confirm "Pull latest changes?"; then
        (cd "$DOTFILES_DIR" && git pull --ff-only) || warn "Could not pull (check network/branch)."
      fi
    fi
  else
    if [ -e "$DOTFILES_DIR" ] && [ ! -d "$DOTFILES_DIR" ]; then
      err "$DOTFILES_DIR exists and is not a directory. Fix it and re-run."
      exit 1
    fi
    info "Cloning dotfiles..."
    git clone "$DOTFILES_REPO_URL" "$DOTFILES_DIR"
  fi

  # Optional symlink dialog
  LINK_EDITORCONFIG=0
  LINK_GITCONFIG=0
  LINK_ZSHRC=0
  LINK_ZPROFILE=0
  LINK_P10K=0

  if has_cmd gum; then
    info "Select dotfiles to symlink (optional)..."
    LINK_SELECTIONS="$(gum choose --no-limit \
      .editorconfig \
      .gitconfig \
      .zshrc \
      .zprofile \
      .p10k.zsh \
    || true)"

    echo "$LINK_SELECTIONS" | grep -Fqx .editorconfig && LINK_EDITORCONFIG=1 || true
    echo "$LINK_SELECTIONS" | grep -Fqx .gitconfig    && LINK_GITCONFIG=1 || true
    echo "$LINK_SELECTIONS" | grep -Fqx .zshrc        && LINK_ZSHRC=1 || true
    echo "$LINK_SELECTIONS" | grep -Fqx .zprofile     && LINK_ZPROFILE=1 || true
    echo "$LINK_SELECTIONS" | grep -Fqx .p10k.zsh     && LINK_P10K=1 || true
  else
    if confirm "Symlink .editorconfig?"; then LINK_EDITORCONFIG=1; fi
    if confirm "Symlink .gitconfig?"; then LINK_GITCONFIG=1; fi
    if confirm "Symlink .zshrc?"; then LINK_ZSHRC=1; fi
    if confirm "Symlink .zprofile?"; then LINK_ZPROFILE=1; fi
    if confirm "Symlink .p10k.zsh?"; then LINK_P10K=1; fi
  fi

  # Adjust these paths to match your repo layout for macOS.
  [ "$LINK_EDITORCONFIG" -eq 1 ] && ensure_symlink "$DOTFILES_DIR/macos/.editorconfig" "$HOME/.editorconfig"
  [ "$LINK_GITCONFIG"    -eq 1 ] && ensure_symlink "$DOTFILES_DIR/macos/.gitconfig"    "$HOME/.gitconfig"

  # These were under wsl/ in your comment; keep as-is until you create macOS-specific equivalents.
  [ "$LINK_ZSHRC"    -eq 1 ] && ensure_symlink "$DOTFILES_DIR/macos/wsl/.zshrc"    "$HOME/.zshrc"
  [ "$LINK_ZPROFILE" -eq 1 ] && ensure_symlink "$DOTFILES_DIR/macos/wsl/.zprofile" "$HOME/.zprofile"
  [ "$LINK_P10K"     -eq 1 ] && ensure_symlink "$DOTFILES_DIR/macos/wsl/.p10k.zsh" "$HOME/.p10k.zsh"

  ok "Dotfiles step complete."
fi

info "macOS setup complete."
