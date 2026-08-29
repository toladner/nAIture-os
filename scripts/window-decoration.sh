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
# R - sqrt(R^2/2) for R = WindowCornerRadius, rounded: the inset that puts the
# button's outer corner on the corner arc.
BUTTON_MARGIN="${NAITURE_BUTTON_MARGIN:-6}"

has_klassy() {
  [[ -f /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so ]] ||
  [[ -f /usr/lib/qt6/plugins/org.kde.kdecoration3/org.kde.klassy.so ]]
}

if has_klassy; then
  # Klassy splits its settings across several config groups in
  # ~/.config/klassy/klassyrc — NOT one [Windeco] section. Writing a key into
  # the wrong group is accepted and silently ignored. The mapping below comes
  # from libbreezecommon/breezesettingsdata.kcfg in the Klassy source.
  # --notify is essential: Klassy reloads through KConfigWatcher, which only
  # fires for writes that carry KDE's change notification. Without it the file
  # is correct and the decoration simply never re-reads it — which looks exactly
  # like the setting having no effect. `qdbus ... /KWin reconfigure` does not
  # cover this.
  k() { kwriteconfig6 --notify --file klassy/klassyrc --group "$1" --key "$2" "$3"; }

  # --- frame shape -------------------------------------------------------
  k Windeco WindowCornerRadius            "$RADIUS"
  k Windeco RoundAllCornersWhenNoBorders  true
  k Windeco DrawBackgroundGradient        false
  k Windeco DrawTitleBarSeparator         false
  k Windeco ButtonShape                   ShapeSmallRoundedSquare
  k Windeco ButtonIconStyle               StyleMaterialDynamic
  k Windeco IconSize                      IconSmallMedium
  # hovering a button otherwise recolours the whole window outline
  k Windeco ColorizeWindowOutlineWithButton false

  # --- glass -------------------------------------------------------------
  # The opacity values do nothing unless the Override flags are set.
  k TitleBarOpacity OverrideActiveTitleBarOpacity   true
  k TitleBarOpacity OverrideInactiveTitleBarOpacity true
  k TitleBarOpacity ActiveTitleBarOpacity           "$ACTIVE_OPACITY"
  k TitleBarOpacity InactiveTitleBarOpacity         "$INACTIVE_OPACITY"
  k TitleBarOpacity ApplyOpacityToHeader            true
  k TitleBarOpacity BlurTransparentTitleBars        true
  # a maximised window fills the screen, so its glass would sit on nothing
  k TitleBarOpacity OpaqueMaximizedTitleBars        true

  # --- title and button placement ---------------------------------------
  k TitleBarSpacing TitleAlignment              AlignCenterFullWidth
  # Unlock the pairs first or the second value of each is ignored.
  k TitleBarSpacing LockTitleBarLeftRightMargins false
  k TitleBarSpacing LockTitleBarTopBottomMargins false
  # For a corner of radius R, a button whose outer corner sits on the arc
  # needs an inset of R - sqrt(R^2/2) — about 6 at the design's R=22.
  k TitleBarSpacing TitleBarLeftMargin          "$BUTTON_MARGIN"
  k TitleBarSpacing TitleBarRightMargin         "$BUTTON_MARGIN"
  k TitleBarSpacing TitleBarTopMargin           "$BUTTON_MARGIN"
  k TitleBarSpacing TitleBarBottomMargin        "$BUTTON_MARGIN"
  k ButtonSizing    ButtonSpacingRight          4

  # --- the close button --------------------------------------------------
  # Barely there at rest, like the design's dock; ember tile on hover.
  k ButtonColors ButtonIconOpacityActive     "$BUTTON_REST_OPACITY"
  k ButtonColors ButtonIconOpacityInactive   "$BUTTON_REST_OPACITY_INACTIVE"
  k ButtonColors ButtonIconColorsActive      TitleBarText
  k ButtonColors ButtonIconColorsInactive    TitleBarText
  k ButtonColors CloseButtonIconColorActive  WhiteWhenHoverPress
  k ButtonColors ButtonBackgroundColorsActive   AccentNegativeClose
  k ButtonColors ButtonBackgroundColorsInactive AccentNegativeClose
  k ButtonColors ButtonBackgroundOpacityActive  90

  for state in Active Inactive; do
    k ButtonBehaviour "ShowCloseBackgroundNormally$state" false
    k ButtonBehaviour "ShowCloseBackgroundOnHover$state"  true
    k ButtonBehaviour "ShowCloseBackgroundOnPress$state"  true
    k ButtonBehaviour "ShowCloseIconNormally$state"       true
    k ButtonBehaviour "ShowBackgroundNormally$state"      false
    k ButtonBehaviour "ShowBackgroundOnHover$state"       true
    k ButtonBehaviour "ShowOutlineNormally$state"         false
    k ButtonBehaviour "ShowOutlineOnHover$state"          false
    k ButtonBehaviour "ShowOutlineOnPress$state"          false
    k ButtonBehaviour "ShowCloseOutlineNormally$state"    false
    k ButtonBehaviour "ShowCloseOutlineOnHover$state"     false
    k ButtonBehaviour "ShowCloseOutlineOnPress$state"     false
  done

  # --- outline -----------------------------------------------------------
  k WindowOutlineStyle WindowOutlineStyleActive   WindowOutlineContrast
  k WindowOutlineStyle WindowOutlineStyleInactive WindowOutlineContrast
  k WindowOutlineStyle WindowOutlineThickness     1

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
