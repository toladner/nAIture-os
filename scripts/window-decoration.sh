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
# The design's dock rests at 20% and comes up on hover; the close glyph matches.
BUTTON_REST_OPACITY="${NAITURE_BUTTON_REST:-20}"
BUTTON_REST_OPACITY_INACTIVE="${NAITURE_BUTTON_REST_INACTIVE:-12}"

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
    # A neutral hairline, like the design's rgba(255,255,255,0.18) rule. The
    # accent styles make the outline follow the hovered button, which reads as
    # the window flashing a coloured border.
    set_k WindowOutlineStyleActive   WindowOutlineContrast
    set_k WindowOutlineStyleInactive WindowOutlineContrast
    set_k ThinWindowOutlineThickness 1
    set_k TitleAlignment            AlignCenterFullWidth

    # One close button, in the design's language: a small rounded tile whose
    # glyph sits at the same resting opacity as the design's dock (20%), so it
    # is barely there until hovered — then it takes the ember tint the design
    # uses for "release to close".
    set_k ButtonShape                    ShapeSmallRoundedSquare
    set_k ButtonIconStyle                StyleMaterialDynamic
    set_k IconSize                       IconSmallMedium
    set_k ButtonSpacingRight             6
    set_k ButtonIconColorsActive         TitleBarText
    set_k ButtonIconColorsInactive       TitleBarText
    set_k ButtonIconOpacityActive        "$BUTTON_REST_OPACITY"
    set_k ButtonIconOpacityInactive      "$BUTTON_REST_OPACITY_INACTIVE"
    set_k CloseButtonIconColorActive     WhiteWhenHoverPress
    set_k ButtonBackgroundColorsActive   AccentNegativeClose
    set_k ButtonBackgroundColorsInactive AccentNegativeClose
    set_k ButtonBackgroundOpacityActive  90
    # Hovering a button otherwise recolours the whole window outline to match
    # it, which reads as the window flashing a border. Keep the outline neutral
    # and drop the ring around the buttons entirely.
    set_k ColorizeWindowOutlineWithButton false

    # Klassy gives the close button its own visibility keys, separate from the
    # generic ones; setting only the generic pair leaves a solid tile at rest.
    for state in Active Inactive; do
      set_k "ShowOutlineNormally$state"      false
      set_k "ShowOutlineOnHover$state"       false
      set_k "ShowOutlineOnPress$state"       false
      set_k "ShowCloseOutlineNormally$state" false
      set_k "ShowCloseOutlineOnHover$state"  false
      set_k "ShowCloseOutlineOnPress$state"  false
      set_k "ShowCloseBackgroundNormally$state" false
      set_k "ShowCloseBackgroundOnHover$state"  true
      set_k "ShowCloseBackgroundOnPress$state"  true
      set_k "ShowCloseIconNormally$state"       true
      set_k "ShowBackgroundNormally$state"      false
      set_k "ShowBackgroundOnHover$state"       true
    done
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
  # No app icon and no minimise/maximise, as in the design — just the close
  # button. Letters are KDecoration button codes: M enu, I minimise,
  # A maximise, X close.
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnLeft ""
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnRight "X"
done

command -v qdbus-qt6 >/dev/null 2>&1 && qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
