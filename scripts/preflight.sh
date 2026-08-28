#!/usr/bin/env bash
# Check that everything install.sh needs is present. Exits non-zero if a
# required tool is missing, and prints the command that would install it.
#
#   --quiet   only report problems
set -euo pipefail

QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

ok()   { [[ $QUIET -eq 1 ]] || printf '  \033[38;2;94;188;123m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[38;2;242;113;106m✗\033[0m %s\n' "$*" >&2; }
soft() { [[ $QUIET -eq 1 ]] || printf '  \033[38;2;222;204;96m·\033[0m %s\n' "$*"; }

missing_required=()
missing_optional=()

check() { # check <command> <required|optional> <what it is for>
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 — $3"
  elif [[ "$2" == required ]]; then
    bad "$1 is missing — needed for $3"
    missing_required+=("$1")
  else
    soft "$1 is missing — $3 will be skipped"
    missing_optional+=("$1")
  fi
}

check kwriteconfig6 required "writing KDE settings"
check kreadconfig6  required "reading KDE settings"
check plasma-apply-colorscheme  required "applying the colour scheme"
check plasma-apply-desktoptheme required "applying the Plasma theme"
check plasma-apply-wallpaperimage optional "setting the wallpaper"
check qdbus-qt6 optional "the --islands panel layout"
check systemctl optional "restarting plasmashell so panel changes show"
check curl      optional "downloading Archivo and JetBrains Mono"
check python3   optional "rendering the wallpaper at your screen size"
check klassy-settings optional "22px rounded window corners (else borderless Breeze)"
check kvantummanager  optional "reserved for a future naiture Kvantum theme"

if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import PIL' 2>/dev/null; then
    ok "python3-pillow — wallpaper rendering"
  else
    soft "python3-pillow is missing — the bundled 1920x1080 wallpaper will be used"
    missing_optional+=("python3-pillow")
  fi
fi

# Plasma 6 is the only version these config keys are correct for.
if command -v plasmashell >/dev/null 2>&1; then
  ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  major="${ver%%.*}"
  if [[ "${major:-0}" -ge 6 ]]; then
    ok "plasmashell $ver"
  else
    bad "plasmashell $ver — naiture targets Plasma 6"
    missing_required+=("plasmashell>=6")
  fi
else
  bad "plasmashell not found — this is a KDE Plasma theme"
  missing_required+=("plasmashell")
fi

pkgline() {
  if   command -v dnf    >/dev/null 2>&1; then echo "sudo dnf install $*"
  elif command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S $*"
  elif command -v apt    >/dev/null 2>&1; then echo "sudo apt install $*"
  else echo "install: $*"; fi
}

if [[ ${#missing_optional[@]} -gt 0 && $QUIET -eq 0 ]]; then
  echo
  echo "Optional, for the full theme:"
  echo "  $(pkgline "${missing_optional[@]}")"
fi

if [[ ${#missing_required[@]} -gt 0 ]]; then
  echo >&2
  echo "Required tools are missing:" >&2
  echo "  $(pkgline "${missing_required[@]}")" >&2
  exit 1
fi

[[ $QUIET -eq 1 ]] || echo "  ready"
exit 0
