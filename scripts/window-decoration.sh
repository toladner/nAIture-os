#!/usr/bin/env bash
# Window frames.
#
# The design's windows are 22px rounded glass. Nothing in stock Plasma clips a
# window to a radius, so this uses Klassy when it is installed and falls back to
# borderless Breeze when it is not. Klassy lives in the major-tom/klassy COPR on
# Fedora and needs a Plasma of the same major version as the desktop.
set -euo pipefail

RADIUS="${NAITURE_WINDOW_RADIUS:-22}"
ACTIVE_OPACITY="${NAITURE_TITLEBAR_ACTIVE:-70}"     # design: rgba(13,24,17,0.70)
INACTIVE_OPACITY="${NAITURE_TITLEBAR_INACTIVE:-60}" # design: rgba(13,24,17,0.60)

has_klassy() {
  [[ -f /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so ]] ||
  [[ -f /usr/lib/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so ]]
}

if has_klassy; then
  # Klassy reads ~/.config/klassy/klassyrc — NOT ~/.config/klassyrc. Writing to
  # the latter is silently ignored, which looks exactly like the radius not
  # working. Keys go under both groups; which one is live varies by version.
  for g in Common Windeco; do
    set_k() { kwriteconfig6 --file klassy/klassyrc --group "$g" --key "$1" "$2"; }
    set_k WindowCornerRadius        "$RADIUS"
    # Without borders Klassy leaves the corners square unless told otherwise,
    # and it wants to own the KWin border size itself.
    set_k RoundAllCornersWhenNoBorders true
    set_k KwinBorderSize            None
    set_k ActiveTitleBarOpacity     "$ACTIVE_OPACITY"
    set_k InactiveTitleBarOpacity   "$INACTIVE_OPACITY"
    set_k ApplyOpacityToHeader      true
    set_k BlurTransparentTitleBars  true
    # A maximised window fills the screen, so its glass would sit on nothing.
    set_k OpaqueMaximizedTitleBars  true
    set_k DrawTitleBarSeparator     false
    set_k DrawBackgroundGradient    false
    set_k ThinWindowOutlineThickness 1
    set_k TitleAlignment            AlignCenterFullWidth
  done
  library=org.kde.klassy
  theme=Klassy
  echo "  windows -> Klassy, ${RADIUS}px corners, translucent titlebars"
else
  library=org.kde.breeze
  theme=Breeze
  echo "  windows -> Breeze (no radius; install klassy for the design's 22px corners)"
fi

for g in org.kde.kdecoration3 org.kde.kdecoration2; do
  kwriteconfig6 --file kwinrc --group "$g" --key library "$library"
  kwriteconfig6 --file kwinrc --group "$g" --key theme "$theme"
  kwriteconfig6 --file kwinrc --group "$g" --key BorderSize None
  kwriteconfig6 --file kwinrc --group "$g" --key BorderSizeAuto false
  # The design's windows carry no app icon in the titlebar — the title sits
  # centred on its own. Letters are KDecoration button codes: M enu, I minimise,
  # A maximise, X close.
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnLeft ""
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnRight "IAX"
done

command -v qdbus-qt6 >/dev/null 2>&1 && qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
