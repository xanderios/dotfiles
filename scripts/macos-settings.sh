#!/bin/sh
set -eu

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

info "macOS Settings configuration..."

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

ok "macOS settings complete."
