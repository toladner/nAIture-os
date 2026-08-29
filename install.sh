#!/usr/bin/env bash
# naiture — retheme KDE Plasma 6 to match the naiture design canvas.
# Installs assets under ~/.local/share, records the settings it is about to
# change, then applies them to the running session.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONF/naiture/backup"

WALLPAPER_W=0
WALLPAPER_H=0
DO_FONTS=1
DO_APPLY=1
DO_ISLANDS=1

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  --keep-panels      keep your current panel layout and only restyle it.
                     By default naiture replaces the panels with the design's
                     two bottom islands: a centred switcher (launcher, tasks,
                     tray) and a right-hand time pill. That is destructive to
                     the existing layout, which the backup preserves.
  --no-fonts         skip downloading Archivo / JetBrains Mono.
  --no-apply         install assets and write config, but do not reload the
                     running session.
  --size WxH         render the wallpaper at this size (default: your screen,
                     falling back to 1920x1080).
  -h, --help         show this.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --islands)      DO_ISLANDS=1 ;;   # kept for compatibility; now the default
    --keep-panels)  DO_ISLANDS=0 ;;
    --no-fonts) DO_FONTS=0 ;;
    --no-apply) DO_APPLY=0 ;;
    --size)     WALLPAPER_W="${2%%x*}"; WALLPAPER_H="${2##*x}"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\033[38;2;106;191;217m::\033[0m %s\n' "$*"; }
warn() { printf '\033[38;2;222;204;96m!!\033[0m %s\n' "$*" >&2; }

need() {
  command -v "$1" >/dev/null 2>&1 || { warn "missing required command: $1"; return 1; }
}

# ---------------------------------------------------------------- backup ----
# Only the first install snapshots the pre-naiture state; re-running must not
# overwrite it with an already-themed config.
backup() {
  if [[ -d "$BACKUP" ]]; then
    say "backup already exists at $BACKUP — keeping the original"
    return
  fi
  mkdir -p "$BACKUP"
  : > "$BACKUP/.absent"
  local f
  for f in kdeglobals kwinrc kwinrulesrc plasmarc konsolerc breezerc plasmashellrc klassy/klassyrc \
           Kvantum/kvantum.kvconfig \
           plasma-org.kde.plasma.desktop-appletsrc; do
    if [[ -f "$CONF/$f" ]]; then
      mkdir -p "$(dirname "$BACKUP/$f")"
      cp -a "$CONF/$f" "$BACKUP/$f"
    else
      # naiture is about to create this file; record that it did not exist so
      # uninstall can remove it rather than leaving a half-themed config behind.
      echo "$f" >> "$BACKUP/.absent"
    fi
  done
  date -Iseconds > "$BACKUP/.taken-at"
  say "backed up current settings to $BACKUP"
}

# ---------------------------------------------------------------- assets ----
install_assets() {
  install -Dm644 "$REPO/color-schemes/Naiture.colors" \
                 "$DATA/color-schemes/Naiture.colors"

  mkdir -p "$DATA/plasma/desktoptheme"
  rm -rf "$DATA/plasma/desktoptheme/naiture"
  cp -a "$REPO/desktoptheme/naiture" "$DATA/plasma/desktoptheme/naiture"
  # The panel background is generated so the glass and opaque variants cannot
  # drift apart; regenerate in place if Python is available.
  if command -v python3 >/dev/null 2>&1; then
    python3 "$REPO/tools/make_panel_svg.py" -d "$DATA/plasma/desktoptheme/naiture" \
      >/dev/null 2>&1 || true
    python3 "$REPO/tools/make_tasks_svg.py" -d "$DATA/plasma/desktoptheme/naiture" \
      >/dev/null 2>&1 || true
    python3 "$REPO/tools/make_dialog_svg.py" -d "$DATA/plasma/desktoptheme/naiture" \
      >/dev/null 2>&1 || true
  fi

  # The mark, wherever an icon theme is asked for it. The Claude console's
  # icon is scripts/claude-console.sh's, because it is fetched rather than
  # shipped.
  install -Dm644 "$REPO/icons/naiture.svg" \
                 "$DATA/icons/hicolor/scalable/apps/naiture.svg"

  # The dock (which carries the mark and the start sheet), the time pill with
  # its quick-settings sheet, and the show-desktop sliver.
  mkdir -p "$DATA/plasma/plasmoids"
  for applet in org.naiture.dock org.naiture.quicksettings org.naiture.showdesktop; do
    rm -rf "$DATA/plasma/plasmoids/$applet"
    cp -a "$REPO/plasmoids/$applet" "$DATA/plasma/plasmoids/$applet"
  done

  mkdir -p "$DATA/wallpapers"
  rm -rf "$DATA/wallpapers/naiture"
  cp -a "$REPO/wallpapers/naiture" "$DATA/wallpapers/naiture"

  install -Dm644 "$REPO/konsole/Naiture.colorscheme" \
                 "$DATA/konsole/Naiture.colorscheme"
  install -Dm644 "$REPO/konsole/Naiture.profile" \
                 "$DATA/konsole/Naiture.profile"

  say "assets installed under $DATA"
}

# Render a wallpaper matching the actual screen if we do not ship that size.
render_wallpaper() {
  local w="$WALLPAPER_W" h="$WALLPAPER_H"
  if [[ "$w" == 0 || "$h" == 0 ]]; then
    if command -v kscreen-doctor >/dev/null 2>&1; then
      local geo
      geo="$(kscreen-doctor -o 2>/dev/null | sed -n 's/.*Geometry:[^0-9]*[0-9]*,[0-9]* \([0-9]*\)x\([0-9]*\).*/\1 \2/p' | head -1)"
      w="${geo%% *}"; h="${geo##* }"
    fi
  fi
  [[ -n "${w:-}" && "${w:-0}" -gt 0 ]] || { w=1920; h=1080; }

  local out="$DATA/wallpapers/naiture/contents/images/${w}x${h}.png"
  if [[ ! -f "$out" ]]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import PIL' 2>/dev/null; then
      say "rendering wallpaper at ${w}x${h}"
      python3 "$REPO/tools/make_wallpaper.py" -o "$out" -W "$w" -H "$h"
    else
      warn "python3 + Pillow not available; using the bundled 1920x1080 image"
      out="$DATA/wallpapers/naiture/contents/images/1920x1080.png"
    fi
  fi
  printf '%s' "$out"
}

# ---------------------------------------------------------------- config ----
# Qt font spec: family,pointSize,pixelSize,styleHint,weight,italic,...
font()  { printf '%s,%s,-1,5,%s,0,0,0,0,0,0,0,0,0,0,1' "$1" "$2" "$3"; }

write_config() {
  local kw=kwriteconfig6

  # Typography — Archivo for UI, JetBrains Mono for anything monospaced.
  $kw --file kdeglobals --group General --key font                 "$(font Archivo 10 400)"
  $kw --file kdeglobals --group General --key menuFont             "$(font Archivo 10 400)"
  $kw --file kdeglobals --group General --key toolBarFont          "$(font Archivo 10 400)"
  $kw --file kdeglobals --group General --key smallestReadableFont "$(font Archivo 8 400)"
  $kw --file kdeglobals --group General --key fixed                "$(font 'JetBrains Mono' 10 400)"
  $kw --file kdeglobals --group WM      --key activeFont           "$(font Archivo 10 600)"

  # Accent — the design's "sky" tint drives selection, focus and highlights.
  $kw --file kdeglobals --group General --key AccentColor "106,191,217"
  $kw --file kdeglobals --group General --key LastUsedCustomAccentColor "106,191,217"
  $kw --file kdeglobals --group General --key accentColorFromWallpaper false
  $kw --file kdeglobals --group Icons   --key Theme breeze-dark

  # Glass. The design is backdrop-filter: blur(40px) saturate(170%); Plasma's
  # blur + background-contrast effects are the native equivalent.
  $kw --file kwinrc --group Plugins --key blurEnabled true
  $kw --file kwinrc --group Plugins --key contrastEnabled true
  $kw --file kwinrc --group Effect-blur --key BlurStrength 12
  $kw --file kwinrc --group Effect-blur --key NoiseStrength 0

  # Window frames are handled by scripts/window-decoration.sh, which picks
  # Klassy (22px rounded glass) or falls back to borderless Breeze.
  $kw --file breezerc --group Common --key OutlineCloseButton true
  $kw --file breezerc --group Common --key ShadowSize ShadowVeryLarge
  $kw --file breezerc --group Common --key ShadowStrength 240
  $kw --file breezerc --group Common --key ShadowColor "0,0,0"
  $kw --file breezerc --group Windeco --key DrawBackgroundGradient false
  $kw --file breezerc --group Windeco --key DrawTitleBarSeparator false
  $kw --file breezerc --group Windeco --key TitleAlignment AlignLeft
  $kw --file breezerc --group Style   --key DockPanelOpacity 60

  # Plasma shell theme.
  $kw --file plasmarc --group Theme --key name naiture

  # Konsole default profile.
  $kw --file konsolerc --group "Desktop Entry" --key DefaultProfile Naiture.profile

  say "settings written"
}

set_wallpaper() {
  local img="$1"
  if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$img" >/dev/null 2>&1 \
      || warn "could not set the wallpaper automatically — pick it from $img"
  fi
}

panel_ids() {
  awk '
    /^\[Containments\]\[[0-9]+\]$/ { cur = $0; gsub(/[^0-9]/, "", cur); next }
    /^\[/ { if ($0 !~ /^\[Containments\]\[[0-9]+\]\[General\]$/) cur = "" }
    /^plugin=org\.kde\.panel$/ { if (cur != "") print cur }
  ' "$CONF/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | sort -n
}

# Rebuild the panel layout as the design's two islands. Creation goes through
# plasmashell's scripting API (the one part of it that persists); geometry is
# applied afterwards from the config.
build_islands() {
  if ! command -v qdbus-qt6 >/dev/null 2>&1; then
    warn "qdbus-qt6 missing — cannot rebuild panels; restyling the existing ones"
    return 1
  fi
  qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    "$(cat "$REPO/scripts/panel-islands.js")" >/dev/null 2>&1

  # The shell needs a moment to persist the new containments.
  local tries=0 ids=()
  while (( tries < 20 )); do
    mapfile -t ids < <(panel_ids)
    (( ${#ids[@]} >= 2 )) && break
    tries=$(( tries + 1 ))
    sleep 0.5
  done

  if (( ${#ids[@]} < 2 )); then
    warn "panel islands were not created (plasmashell scripting refused)"
    return 1
  fi

  # Highest containment id is the one created last — the time island, which
  # hugs the right edge.
  local last="${ids[-1]}"
  bash "$REPO/scripts/panel-style.sh" --align "$last:2"
  return 0
}

apply() {
  say "applying to the running session"
  plasma-apply-colorscheme Naiture   >/dev/null 2>&1 || warn "colour scheme not applied"
  plasma-apply-desktoptheme naiture  >/dev/null 2>&1 || warn "desktop theme not applied"
  set_wallpaper "$1"

  if [[ $DO_ISLANDS -eq 1 ]]; then
    build_islands || bash "$REPO/scripts/panel-style.sh"
  else
    bash "$REPO/scripts/panel-style.sh"
  fi

  bash "$REPO/scripts/accent.sh"
  bash "$REPO/scripts/screen-edges.sh"
  bash "$REPO/scripts/window-decoration.sh"
  bash "$REPO/scripts/widget-style.sh"
  bash "$REPO/scripts/dock-proximity.sh"
  bash "$REPO/scripts/claude-console.sh"

  if command -v qdbus-qt6 >/dev/null 2>&1; then
    qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
  say "done"
}

# ------------------------------------------------------------------ main ----
if [[ -x "$REPO/scripts/preflight.sh" ]]; then
  say "checking prerequisites"
  "$REPO/scripts/preflight.sh" --quiet || exit 1
else
  need kwriteconfig6 || exit 1
fi

backup
install_assets
WALL="$(render_wallpaper)"
write_config

if [[ $DO_FONTS -eq 1 ]]; then
  bash "$REPO/fonts/install-fonts.sh" || warn "font install failed; the theme will fall back to system fonts"
fi

if [[ $DO_APPLY -eq 1 ]]; then
  apply "$WALL"
else
  say "assets and settings in place; log out and back in, or re-run without --no-apply"
fi

cat <<EOF

  naiture is installed.
  wallpaper : $WALL
  restore   : ./uninstall.sh
EOF
