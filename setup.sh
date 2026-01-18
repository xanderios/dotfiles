#!/bin/sh
set -eu

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --------- flags ----------
DRY_RUN=0
export DRY_RUN

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1; export DRY_RUN ;;
    *) ;;
  esac
done

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

# --------- summary tracking ----------
INSTALLED=""
SKIPPED=""
NOTES=""
export INSTALLED SKIPPED NOTES

# Source common libraries
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/brew.sh
. "$SCRIPT_DIR/lib/brew.sh"

if [ "$DRY_RUN" -eq 1 ]; then
  warn "DRY-RUN enabled: no installs, no file writes, no network calls, no settings changes."
fi
info "Log file: $LOG_FILE"

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

# --------- select sections ----------
info "Select setup sections to run..."

SECTIONS="$(ask_multi \
  "Prerequisites (Xcode Tools)" \
  "Homebrew" \
  "Development Tools" \
  "Zsh & Oh My Zsh" \
  "Nerd Fonts" \
  "macOS Settings" \
  "Dotfiles" \
|| exit $?)"

RUN_PREREQUISITES=0
RUN_HOMEBREW=0
RUN_DEVTOOLS=0
RUN_ZSH=0
RUN_FONTS=0
RUN_MACOS=0
RUN_DOTFILES=0

echo "$SECTIONS" | grep -Fqx "Prerequisites (Xcode Tools)" && RUN_PREREQUISITES=1 || true
echo "$SECTIONS" | grep -Fqx "Homebrew"                     && RUN_HOMEBREW=1 || true
echo "$SECTIONS" | grep -Fqx "Development Tools"            && RUN_DEVTOOLS=1 || true
echo "$SECTIONS" | grep -Fqx "Zsh & Oh My Zsh"              && RUN_ZSH=1 || true
echo "$SECTIONS" | grep -Fqx "Nerd Fonts"                   && RUN_FONTS=1 || true
echo "$SECTIONS" | grep -Fqx "macOS Settings"               && RUN_MACOS=1 || true
echo "$SECTIONS" | grep -Fqx "Dotfiles"                     && RUN_DOTFILES=1 || true

# --------- prerequisites ----------
if [ "$RUN_PREREQUISITES" -eq 1 ]; then
  sh "$SCRIPT_DIR/scripts/prerequisites.sh"
else
  add_item SKIPPED "Prerequisites"
fi

# --------- Homebrew ----------
if [ "$RUN_HOMEBREW" -eq 1 ]; then
  setup_homebrew
  brew_update
else
  add_item SKIPPED "Homebrew setup"
  # Still need to check if brew exists for other sections
  BREW_BIN=""
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    BREW_BIN="/usr/local/bin/brew"
  fi
  export BREW_BIN
  BREW_OK=1
  if [ -z "$BREW_BIN" ]; then BREW_OK=0; fi
  export BREW_OK
  if [ "$BREW_OK" -eq 1 ]; then
    BREW_PREFIX="$("$BREW_BIN" --prefix)"
    export BREW_PREFIX
  fi
fi

# --------- gum (optional) ----------
if ! has_cmd gum && [ "$BREW_OK" -eq 1 ]; then
  warn "gum not found (checkbox UI)."
  if ask_confirm "Install gum with Homebrew?"; then
    brew_install_if_missing gum
  else
    add_item SKIPPED "gum install"
  fi
fi

# --------- run selected sections ----------
[ "$RUN_DEVTOOLS" -eq 1 ] && sh "$SCRIPT_DIR/scripts/devtools.sh" || add_item SKIPPED "Development Tools"
[ "$RUN_ZSH" -eq 1 ] && sh "$SCRIPT_DIR/scripts/zsh.sh" || add_item SKIPPED "Zsh"
[ "$RUN_FONTS" -eq 1 ] && sh "$SCRIPT_DIR/scripts/fonts.sh" || add_item SKIPPED "Fonts"
[ "$RUN_MACOS" -eq 1 ] && sh "$SCRIPT_DIR/scripts/macos-settings.sh" || add_item SKIPPED "macOS Settings"
[ "$RUN_DOTFILES" -eq 1 ] && sh "$SCRIPT_DIR/scripts/dotfiles.sh" || add_item SKIPPED "Dotfiles"

# --------- optional brew cleanup ----------
if [ "$BREW_OK" -eq 1 ]; then
  brew_cleanup
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
