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
BUTTON_REST_OPACITY="${NAITURE_BUTTON_REST:-100}"
BUTTON_REST_OPACITY_INACTIVE="${NAITURE_BUTTON_REST_INACTIVE:-80}"
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
  k Windeco ButtonIconStyle               StyleMaterialCentered
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
  # Icons are titlebar text; only the close button takes a colour, and only
  # under the pointer. No tile or circle behind any of them.
  k ButtonColors ButtonIconColorsActive      TitleBarTextNegativeClose
  k ButtonColors ButtonIconColorsInactive    TitleBarTextNegativeClose
  k ButtonColors CloseButtonIconColorActive  NegativeWhenHoverPress
  k ButtonColors CloseButtonIconColorInactive NegativeWhenHoverPress
  # This one draws a red background behind the close button on hover regardless
  # of the ShowCloseBackground* keys — the "circle" that would not go away.
  k ButtonColors NegativeCloseBackgroundHoverPressActive   false
  k ButtonColors NegativeCloseBackgroundHoverPressInactive false
  # Belt and braces against the hover circle: nothing to draw it with.
  k ButtonColors ButtonBackgroundOpacityActive   0
  k ButtonColors ButtonBackgroundOpacityInactive 0
  # And the real culprit: Klassy paints a titlebar-coloured patch behind any
  # icon it judges low-contrast, which is every coloured glyph on a dark
  # titlebar. That patch is the circle that survives every background setting.
  k ButtonColors OnPoorIconContrastActive               Nothing
  k ButtonColors OnPoorIconContrastInactive             Nothing
  k ButtonColors AdjustBackgroundColorOnPoorContrastActive   false
  k ButtonColors AdjustBackgroundColorOnPoorContrastInactive false

  # The close button behaves differently from the other two, so unlock the pair.
  k ButtonBehaviour LockCloseButtonBehaviour false
  # Unison hovering puts *every* button into the hover state at once, which
  # lights them all up together. Off, so only the one under the pointer reacts.
  k ButtonBehaviour UnisonHovering           false

  for state in Active Inactive; do
    # Close: a faint X is always there, as the anchor you aim at.
    k ButtonBehaviour "ShowCloseIconNormally$state"       true
    # the icon itself carries the state, so no background in any state
    k ButtonBehaviour "ShowCloseBackgroundNormally$state" false
    k ButtonBehaviour "ShowCloseBackgroundOnHover$state"  false
    k ButtonBehaviour "ShowCloseBackgroundOnPress$state"  false
    # Blended into the titlebar colour at rest, true colour only under the
    # pointer — so the group reveals together but just one reads as coloured.
    k ButtonBehaviour "VaryColorBackground$state"         Transparent
    k ButtonBehaviour "VaryColorCloseBackground$state"    Transparent
    k ButtonBehaviour "VaryColorIcon$state"               LeastTitleBarHover
    k ButtonBehaviour "VaryColorCloseIcon$state"          LeastTitleBarHover
    # With unison hovering off there is no group reveal, so all three stay
    # faintly visible at rest and colour individually.
    k ButtonBehaviour "ShowIconNormally$state"            true
    k ButtonBehaviour "ShowIconOnHover$state"             true
    k ButtonBehaviour "ShowIconOnPress$state"             true
    k ButtonBehaviour "ShowBackgroundNormally$state"      false
    k ButtonBehaviour "ShowBackgroundOnHover$state"       false
    k ButtonBehaviour "ShowBackgroundOnPress$state"       false
    # No rings around any of them, in any state.
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
  # No app icon. Minimise and maximise are present but only surface when the
  # pointer nears them; the close X stays faintly visible. Letters are
  # KDecoration button codes: M enu, I minimise, A maximise, X close.
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnLeft ""
  kwriteconfig6 --file kwinrc --group "$g" --key ButtonsOnRight "IAX"
done

command -v qdbus-qt6 >/dev/null 2>&1 && qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
