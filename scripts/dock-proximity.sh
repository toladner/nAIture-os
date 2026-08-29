#!/usr/bin/env bash
# Install and enable the KWin script that rests the centre island at 20% and
# brings it up to full as the pointer nears it — the design's dock behaviour,
# which Plasma itself has no setting for.
#
#   --off   disable and remove it again
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA/kwin/scripts/naiture-dock"
ID=naiture-dock
SESSION_ID=naiture-dock-session

kwin_script() {
  qdbus-qt6 org.kde.KWin /Scripting "org.kde.kwin.Scripting.$1" "${@:2}" >/dev/null 2>&1 || true
}

if [[ "${1:-}" == "--off" ]]; then
  kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" false
  kwin_script unloadScript "$ID"
  kwin_script unloadScript "$SESSION_ID"
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  rm -rf "$DEST"
  echo "  dock proximity removed"
  exit 0
fi

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -r "$REPO/kwin/naiture-dock" "$DEST"

kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" true

if ! command -v qdbus-qt6 >/dev/null 2>&1; then
  echo "  installed; log out and back in to start it"
  exit 0
fi

# KWin picks up newly enabled scripts on reconfigure, and on Wayland there is no
# restarting it anyway.
qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

# KWin's QML engine caches a component by URL for the life of the process and
# never re-reads the file. A second install in the same session therefore keeps
# running whatever was at that path the first time — so for *this* session run
# the copy in the repo, whose path the engine has not seen, and let the
# installed package take over at the next login.
# The reconfigure above starts the enabled plugin asynchronously; unloading
# before it has actually started leaves it running.
sleep 1
kwin_script unloadScript "$ID"
kwin_script unloadScript "$SESSION_ID"
kwin_script loadDeclarativeScript "$REPO/kwin/naiture-dock/contents/ui/main.qml" "$SESSION_ID"
kwin_script start

echo "  dock rests at 20%, full opacity when the pointer is near"
