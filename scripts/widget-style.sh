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

# NOT YET the design. Kvantum is the only route to a translucent window body,
# but it repaints the whole widget set from its own SVG, so a naiture Kvantum
# theme has to be authored first — copying an existing one repaints every window
# in that theme's colours and still does not switch translucency on. Until that
# theme exists, Breeze keeps the palette right and window bodies opaque.
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Breeze
echo "  widgets -> Breeze (opaque bodies; see docs/design-mapping.md)"
