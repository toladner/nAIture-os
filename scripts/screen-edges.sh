#!/usr/bin/env bash
# Quiet the screen corners.
#
#   --restore   put KWin's own corner behaviour back
#
# Two corners do something by default or by our doing, and both fire on a shove
# of the pointer rather than a click, which is easy to trigger by accident when
# the island's controls live down there:
#
#   bottom-right  [ElectricBorders] BottomRight — naiture briefly put show
#                 desktop here, because the island's sliver cannot quite reach
#                 the corner. Clicking the sliver is the affordance instead.
#   top-left      KWin's Overview effect claims this corner out of the box
#                 ([Effect-overview] BorderActivate). 9 is ElectricNone in
#                 KWin's ElectricBorder enum (kwin/src/effect/globals.h).
set -euo pipefail

ELECTRIC_NONE=9

if [[ "${1:-}" == "--restore" ]]; then
  kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight --delete
  kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate --delete
  kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivateAll --delete
  echo "  screen corners -> KWin's defaults"
else
  kwriteconfig6 --file kwinrc --group ElectricBorders --key BottomRight None
  kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivate "$ELECTRIC_NONE"
  kwriteconfig6 --file kwinrc --group Effect-overview --key BorderActivateAll "$ELECTRIC_NONE"
  echo "  screen corners -> nothing happens there"
fi

if command -v qdbus-qt6 >/dev/null 2>&1; then
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
fi
