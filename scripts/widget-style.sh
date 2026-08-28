#!/usr/bin/env bash
# Application window bodies.
#
# Klassy makes the titlebar and toolbar glass, but the body of a window is
# painted by the application's widget style, not the compositor. Breeze paints
# it opaque and KWin's translucency effect only acts on inactive windows, so the
# only way to get the design's rgba(13,24,17,0.70) body across Qt applications
# is a widget style that supports translucency — Kvantum.
#
# Without Kvantum the theme still works; windows are simply opaque.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

if command -v kvantummanager >/dev/null 2>&1; then
  mkdir -p "$CONF/Kvantum/Naiture"
  cp -a "$REPO/kvantum/Naiture/." "$CONF/Kvantum/Naiture/"
  kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme Naiture
  kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
  echo "  widgets -> Kvantum/Naiture, translucent window bodies"
else
  kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
  echo "  widgets -> Breeze (opaque bodies; install kvantum for the design's glass)"
fi
