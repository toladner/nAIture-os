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

# Window translucency is handled by scripts/window-glass.sh (a KWin opacity
# rule), not by the widget style. Kvantum could supply both translucency and a
# blur region, but it repaints the whole widget set from its own SVG, so using
# it means authoring a Kvantum theme in the naiture palette first. Until then
# Breeze keeps the colours right.
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
echo "  widgets -> Breeze"
