#!/usr/bin/env bash
# Translucent window bodies.
#
# The design's windows are rgba(13,24,17,0.70) — the wallpaper reads through
# them. Nothing in the widget style does that: Breeze paints window backgrounds
# opaque, and KWin's `translucency` effect only acts on inactive windows. What
# does work is a KWin window rule forcing opacity on every window.
#
# Caveat: this makes the whole window translucent, text included, where the
# design fades only the background. KWin also only blurs behind windows that
# register a blur region — Konsole does, most applications do not — so windows
# are clear glass rather than frosted.
set -euo pipefail

RULE_ID="naiture-glass"
ACTIVE="${NAITURE_WINDOW_OPACITY:-85}"
INACTIVE="${NAITURE_WINDOW_OPACITY_INACTIVE:-76}"

set_r() { kwriteconfig6 --file kwinrulesrc --group "$RULE_ID" --key "$1" "$2"; }

set_r Description        "naiture glass"
set_r wmclass            ".*"
set_r wmclassmatch       3          # 3 = regular expression
set_r wmclasscomplete    false
set_r opacityactive      "$ACTIVE"
set_r opacityactiverule  2          # 2 = force
set_r opacityinactive    "$INACTIVE"
set_r opacityinactiverule 2

# Merge into whatever rules already exist rather than replacing them.
existing="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
case ",$existing," in
  *",$RULE_ID,"*) merged="$existing" ;;
  ,,|,) merged="$RULE_ID" ;;
  *)    merged="$existing,$RULE_ID" ;;
esac
count="$(awk -F, '{print NF}' <<< "$merged")"
kwriteconfig6 --file kwinrulesrc --group General --key rules "$merged"
kwriteconfig6 --file kwinrulesrc --group General --key count "$count"

command -v qdbus-qt6 >/dev/null 2>&1 && qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
echo "  windows -> ${ACTIVE}% active / ${INACTIVE}% inactive opacity"
