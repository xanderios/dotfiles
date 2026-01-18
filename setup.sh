#!/bin/sh
set -eu

OS="$(uname -s)"

# --------- flags ----------
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) ;;
  esac
done

# --------- UI helpers ----------
info()  { printf "\033[34m%s\033[0m\n" "$*"; }
warn()  { printf "\033[33m%s\033[0m\n" "$*"; }
ok()    { printf "\033[32m%s\033[0m\n" "$*"; }
err()   { printf "\033[31m%s\033[0m\n" "$*"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

confirm() {
  printf "%s (y/n) " "$1"
  read ans || true
  case "${ans:-}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# --------- logging (tee to ~/.setup/logs/) ----------
LOG_DIR="$HOME/.setup/logs"
LOG_FILE=""
TEE_PID=""
LOG_PIPE=""

setup_logging() {
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"

  # Named pipe tee (POSIX-friendly)
  LOG_PIPE="$LOG_DIR/.setup.pipe.$$"
  rm -f "$LOG_PIPE"
  mkfifo "$LOG_PIPE"
  tee -a "$LOG_FILE" < "$LOG_PIPE" &
  TEE_PID="$!"

  # Redirect all output to pipe (tee consumes it)
  exec >"$LOG_PIPE" 2>&1
}

cleanup_logging() {
  # Best-effort cleanup
  [ -n "${LOG_PIPE:-}" ] && rm -f "$LOG_PIPE" 2>/dev/null || true
  [ -n "${TEE_PID:-}" ] && kill "$TEE_PID" 2>/dev/null || true
}

setup_logging
trap 'cleanup_logging' EXIT INT TERM

if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN enabled: no installs, no file writes, no network calls, no settings changes."
fi
info "Log file: $LOG_FILE"

# --------- summary tracking ----------
INSTALLED=""
SKIPPED=""
NOTES=""

add_item() {
  # usage: add_item VAR "text"
  var="$1"
  text="$2"

  # Read current value
  eval "current=\${$var-}"

  # Escape backslashes and double-quotes so we can safely eval-assign
  esc() { printf "%s" "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

  if [ -z "${current:-}" ]; then
    eval "$var=\"$(esc "$text")\""
  else
    eval "$var=\"$(esc "$current")\n$(esc "$text")\""
  fi
}

# --------- wrappers ----------
run_cmd() {
  # usage: run_cmd cmd arg...
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "[dry-run] "
    i=1
    for a in "$@"; do
      if [ $i -eq 1 ]; then printf "%s" "$a"; else printf " %s" "$a"; fi
      i=$((i+1))
    done
    printf "\n"
    return 0
  fi
  "$@"
}

run_sh() {
  # usage: run_sh "string command"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "[dry-run] %s\n" "$1"
    return 0
  fi
  sh -c "$1"
}

ask_confirm() {
  # usage: ask_confirm "Question?"
  if has_cmd gum; then
    gum confirm "$1"
  else
    confirm "$1"
  fi
}

ask_multi() {
  # usage: ask_multi key1 key2 key3 ...  -> prints selected keys, one per line
  if has_cmd gum; then
    gum choose --no-limit "$@"
    rc=$?
    # Exit code 130 means user pressed Ctrl+C (SIGINT)
    if [ $rc -eq 130 ]; then
      exit 130
    fi
    return 0
  fi

  # Fallback: ask per option; print selected keys one per line
  for key in "$@"; do
    if confirm "Select '$key'?"; then
      printf "%s\n" "$key"
    fi
  done
}

append_line_if_missing() {
  line="$1"
  file="$2"
  dir="$(dirname "$file")"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "[dry-run] ensure line in %s: %s\n" "$file" "$line"
    return 0
  fi

  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$file" ] || : > "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf "%s\n" "$line" >> "$file"
}

ensure_symlink() {
  src="$1"
  dst="$2"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf "[dry-run] symlink %s -> %s\n" "$dst" "$src"
    return 0
  fi

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      ok "Symlink ok: $dst -> $src"
      return 0
    fi
    warn "Updating symlink: $dst"
    rm -f "$dst"
  elif [ -e "$dst" ]; then
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
if ! ask_confirm "Run setup on $OS?"; then
  warn "Setup cancelled by user."
  add_item SKIPPED "User cancelled at start"
  exit 0
fi

info "Running setup for $OS..."

if [ "$OS" != "Darwin" ]; then
  err "This version is macOS-first. Exiting."
  exit 1
fi

# --------- prerequisites ----------
info "Checking prerequisites..."

if ! has_cmd curl; then
  err "curl is required but not found. Install Xcode Command Line Tools or curl first."
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found."
  if ask_confirm "Install Xcode Command Line Tools now?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item NOTES "Would install Xcode Command Line Tools (xcode-select --install)"
      ok "Dry-run: skipping Xcode tools install."
    else
      xcode-select --install || true
      warn "If a GUI prompt appeared, complete it, then re-run this script."
      add_item NOTES "Xcode Command Line Tools install started; complete GUI prompt then re-run"
      exit 0
    fi
  else
    err "Cannot proceed without Command Line Tools."
    exit 1
  fi
fi

# --------- Homebrew ----------
BREW_BIN=""
if [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN="/opt/homebrew/bin/brew"
elif [ -x /usr/local/bin/brew ]; then
  BREW_BIN="/usr/local/bin/brew"
fi

if [ -z "$BREW_BIN" ]; then
  warn "Homebrew not found."
  if ask_confirm "Install Homebrew?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item NOTES "Would install Homebrew"
      ok "Dry-run: skipping Homebrew install."
      add_item SKIPPED "Homebrew install (dry-run)"
      # Cannot proceed meaningfully without brew in dry-run (but keep going to show plan)
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [ -x /opt/homebrew/bin/brew ]; then
        BREW_BIN="/opt/homebrew/bin/brew"
      elif [ -x /usr/local/bin/brew ]; then
        BREW_BIN="/usr/local/bin/brew"
      fi
      if [ -z "$BREW_BIN" ]; then
        err "Homebrew installation not found after install. Exiting."
        exit 1
      fi
      add_item INSTALLED "Homebrew"
    fi
  else
    err "Homebrew is required for the rest of this script."
    exit 1
  fi
fi

# If still no brew (dry-run case), skip brew-dependent steps but still plan
BREW_OK=1
if [ -z "$BREW_BIN" ]; then BREW_OK=0; fi

if [ "$BREW_OK" -eq 1 ]; then
  BREW_PREFIX="$("$BREW_BIN" --prefix)"
  SHELLENV_LINE="eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\""

  append_line_if_missing "$SHELLENV_LINE" "$HOME/.zprofile"
  append_line_if_missing "$SHELLENV_LINE" "$HOME/.profile"

  if [ "$DRY_RUN" -eq 0 ]; then
    # shellcheck disable=SC1090
    eval "$("$BREW_BIN" shellenv)"
    ok "Homebrew ready: $(brew --version | head -n 1)"
  else
    add_item NOTES "Would eval brew shellenv for current shell"
  fi

  if ask_confirm "Run 'brew update' + 'brew upgrade'?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item SKIPPED "brew update/upgrade (dry-run)"
    else
      info "Updating Homebrew..."
      brew update
      brew upgrade || true
      add_item NOTES "Homebrew updated/upgraded"
    fi
  else
    add_item SKIPPED "brew update/upgrade"
  fi
else
  warn "Homebrew not available; brew installs will be skipped."
  add_item NOTES "Homebrew not available; skipped brew-dependent actions"
fi

brew_install_if_missing() {
  pkg="$1"
  if [ "$BREW_OK" -ne 1 ]; then
    add_item SKIPPED "brew install $pkg (brew unavailable)"
    return 0
  fi
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    ok "Already installed: $pkg"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    add_item NOTES "Would install formula: $pkg"
    return 0
  fi
  info "Installing: $pkg"
  brew install "$pkg"
  add_item INSTALLED "formula: $pkg"
}

brew_cask_install_if_missing() {
  cask="$1"
  if [ "$BREW_OK" -ne 1 ]; then
    add_item SKIPPED "brew install --cask $cask (brew unavailable)"
    return 0
  fi
  if brew list --cask "$cask" >/dev/null 2>&1; then
    ok "Already installed: $cask"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    add_item NOTES "Would install cask: $cask"
    return 0
  fi
  info "Installing cask: $cask"
  brew install --cask "$cask"
  add_item INSTALLED "cask: $cask"
}

brew_tap_if_missing() {
  tap="$1"
  if [ "$BREW_OK" -ne 1 ]; then
    add_item SKIPPED "brew tap $tap (brew unavailable)"
    return 0
  fi
  if brew tap | grep -Fxq "$tap"; then
    ok "Tap exists: $tap"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    add_item NOTES "Would tap: $tap"
    return 0
  fi
  info "Tapping: $tap"
  brew tap "$tap"
  add_item NOTES "Tapped: $tap"
}

# --------- gum (optional) ----------
if ! has_cmd gum; then
  warn "gum not found (checkbox UI)."
  if ask_confirm "Install gum with Homebrew?"; then
    brew_install_if_missing gum
  else
    add_item SKIPPED "gum install"
  fi
fi

# --------- package choices ----------
info "Select what to install (checkboxes)."

INSTALL_DEVTOOLS=0
INSTALL_ZSH=0
INSTALL_ZOXIDE=0
INSTALL_FZF=0
INSTALL_NVM=0

SELECTIONS="$(ask_multi devtools zsh zoxide fzf nvm || exit $?)"
echo "$SELECTIONS" | grep -Fqx devtools && INSTALL_DEVTOOLS=1 || true
echo "$SELECTIONS" | grep -Fqx zsh      && INSTALL_ZSH=1 || true
echo "$SELECTIONS" | grep -Fqx zoxide   && INSTALL_ZOXIDE=1 || true
echo "$SELECTIONS" | grep -Fqx fzf      && INSTALL_FZF=1 || true
echo "$SELECTIONS" | grep -Fqx nvm      && INSTALL_NVM=1 || true

# --------- installs ----------
if [ "$INSTALL_DEVTOOLS" -eq 1 ]; then
  info "Installing CLI dev tools..."
  brew_install_if_missing git
  brew_install_if_missing wget
  brew_install_if_missing neovim
else
  add_item SKIPPED "CLI dev tools"
fi

if [ "$INSTALL_ZOXIDE" -eq 1 ]; then
  info "Installing zoxide..."
  brew_install_if_missing zoxide
else
  add_item SKIPPED "zoxide"
fi

if [ "$INSTALL_FZF" -eq 1 ]; then
  info "Installing fzf..."
  brew_install_if_missing fzf
else
  add_item SKIPPED "fzf"
fi

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

if [ "$INSTALL_ZSH" -eq 1 ]; then
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
else
  add_item SKIPPED "Zsh extras"
fi

# --------- Fonts ----------
info "Fonts (optional)..."

INSTALL_FONTS=0
if ask_confirm "Install Nerd Fonts?"; then
  INSTALL_FONTS=1
else
  add_item SKIPPED "Fonts"
fi

FONTS_INSTALLED_ANY=0
if [ "$INSTALL_FONTS" -eq 1 ]; then
  brew_tap_if_missing homebrew/cask-fonts

  # Friendly labels (mapped internally)
  FONT_SELECTIONS="$(ask_multi \
    "FiraCode Nerd Font" \
    "JetBrainsMono Nerd Font" \
  || exit $?)"

  WANT_FIRA=0
  WANT_JB=0
  echo "$FONT_SELECTIONS" | grep -Fqx "FiraCode Nerd Font" && WANT_FIRA=1 || true
  echo "$FONT_SELECTIONS" | grep -Fqx "JetBrainsMono Nerd Font" && WANT_JB=1 || true

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
fi

# --------- macOS Settings ----------
info "macOS Settings (optional)..."

APPLY_SETTINGS=0
if ask_confirm "Apply macOS settings now?"; then
  APPLY_SETTINGS=1
else
  add_item SKIPPED "macOS settings"
fi

NEED_RESTART_FINDER=0

defaults_write_if_needed() {
  # usage: defaults_write_if_needed domain key type value
  domain="$1"; key="$2"; type="$3"; value="$4"

  current=""
  if defaults read "$domain" "$key" >/dev/null 2>&1; then
    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
  fi

  # crude compare; good enough for these values
  if [ "${current:-}" = "$value" ]; then
    ok "Setting ok: $domain $key = $value"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    add_item NOTES "Would set: $domain $key = $value"
    return 0
  fi

  run_cmd defaults write "$domain" "$key" "$type" "$value"
  add_item NOTES "Set: $domain $key = $value"
}

if [ "$APPLY_SETTINGS" -eq 1 ]; then
  # Appearance
  if ask_confirm "Settings: Appearance (Dark Mode)?"; then
    if has_cmd osascript; then
      if [ "$DRY_RUN" -eq 1 ]; then
        add_item NOTES "Would enable Dark Mode"
      else
        run_sh 'osascript -e '\''tell application "System Events" to tell appearance preferences to set dark mode to true'\'''
        add_item NOTES "Enabled Dark Mode"
      fi
    else
      add_item NOTES "Could not set Dark Mode (osascript not found)"
    fi
  else
    add_item SKIPPED "Settings: Dark Mode"
  fi

  # Finder (show extensions + always show hidden files)
  if ask_confirm "Settings: Finder (show extensions + show hidden files)?"; then
    # show extensions (global)
    defaults_write_if_needed -g AppleShowAllExtensions -bool true || true
    # show hidden files (Finder)
    defaults_write_if_needed com.apple.finder AppleShowAllFiles -bool true || true
    NEED_RESTART_FINDER=1
  else
    add_item SKIPPED "Settings: Finder"
  fi

  # Keyboard repeat
  if ask_confirm "Settings: Keyboard (KeyRepeat=3, InitialKeyRepeat=10)?"; then
    defaults_write_if_needed -g KeyRepeat -int 3 || true
    defaults_write_if_needed -g InitialKeyRepeat -int 10 || true
  else
    add_item SKIPPED "Settings: Keyboard repeat"
  fi

  # Restart services (ask)
  if [ "$NEED_RESTART_FINDER" -eq 1 ]; then
    if ask_confirm "Restart Finder now for settings to apply?"; then
      if [ "$DRY_RUN" -eq 1 ]; then
        add_item NOTES "Would restart Finder"
      else
        run_cmd killall Finder || true
        add_item NOTES "Restarted Finder"
      fi
    else
      add_item NOTES "Finder restart skipped; changes may require restarting Finder"
    fi
  fi
fi

# --------- dotfiles ----------
DOTFILES_REPO_URL="https://github.com/xanderios/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

INSTALL_DOTFILES=0
if ask_confirm "Clone/update dotfiles and (optionally) create symlinks?"; then
  INSTALL_DOTFILES=1
else
  add_item SKIPPED "Dotfiles"
fi

if [ "$INSTALL_DOTFILES" -eq 1 ]; then
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
  SRC_EDITOR="$DOTFILES_DIR/macos/.editorconfig"
  SRC_GIT="$DOTFILES_DIR/macos/.gitconfig"
  SRC_ZSHRC="$DOTFILES_DIR/macos/wsl/.zshrc"
  SRC_ZPROFILE="$DOTFILES_DIR/macos/wsl/.zprofile"
  SRC_P10K="$DOTFILES_DIR/macos/wsl/.p10k.zsh"

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
fi

# --------- optional brew cleanup ----------
if [ "$BREW_OK" -eq 1 ]; then
  if ask_confirm "Run 'brew cleanup'?"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      add_item SKIPPED "brew cleanup (dry-run)"
    else
      brew cleanup || true
      add_item NOTES "brew cleanup completed"
    fi
  else
    add_item SKIPPED "brew cleanup"
  fi
fi

# --------- summary ----------
info "Summary"
printf "\nInstalled:\n"
if [ -n "$INSTALLED" ]; then printf "%b\n" "$INSTALLED"; else printf "(none)\n"; fi

printf "\nSkipped:\n"
if [ -n "$SKIPPED" ]; then printf "%b\n" "$SKIPPED"; else printf "(none)\n"; fi

printf "\nNotes / follow-ups:\n"
if [ -n "$NOTES" ]; then printf "%b\n" "$NOTES"; else printf "(none)\n"; fi

ok "macOS setup complete."
