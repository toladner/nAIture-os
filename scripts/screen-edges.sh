#!/usr/bin/env bash
# Give the bottom-right screen corner the show-desktop action.
#
#   --off   put the corner back to doing nothing
#
# The island's show-desktop sliver cannot reach the corner: Plasma insets an
# applet from the panel's edge by the theme's background margin plus about 8px
# of its own, and nothing in a theme reaches that. A KWin screen edge does reach
# it — that is what a screen edge is — so throwing the pointer into the corner
# works even though the last few pixels are not the applet's to claim.
#
# It fires on a deliberate shove into the corner rather than a click; KWin's
# ElectricBorderDelay is the dwell before it counts, and is left at whatever the
# user has set.
set -euo pipefail

if [[ "${1:-}" == "--off" ]]; then
  kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight None
else
  kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight ShowDesktop
fi

if command -v qdbus-qt6 >/dev/null 2>&1; then
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi

if [[ "${1:-}" == "--off" ]]; then
  echo "  bottom-right corner -> nothing"
else
  echo "  bottom-right corner -> show desktop"
fi
