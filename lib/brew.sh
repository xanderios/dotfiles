#!/bin/sh
# Homebrew installation and helper functions

setup_homebrew() {
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

  # Export for other scripts
  export BREW_BIN
  BREW_OK=1
  if [ -z "$BREW_BIN" ]; then BREW_OK=0; fi
  export BREW_OK

  if [ "$BREW_OK" -eq 1 ]; then
    BREW_PREFIX="$("$BREW_BIN" --prefix)"
    export BREW_PREFIX
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
  else
    warn "Homebrew not available; brew installs will be skipped."
    add_item NOTES "Homebrew not available; skipped brew-dependent actions"
  fi
}

brew_update() {
  if [ "$BREW_OK" -ne 1 ]; then
    return 0
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
}

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

brew_cleanup() {
  if [ "$BREW_OK" -ne 1 ]; then
    return 0
  fi

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
}
