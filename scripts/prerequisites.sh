#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

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
else
  ok "Xcode Command Line Tools already installed"
fi
