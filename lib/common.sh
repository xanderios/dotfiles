#!/bin/sh
# Common utilities and UI helpers

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

# --------- summary tracking ----------
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
