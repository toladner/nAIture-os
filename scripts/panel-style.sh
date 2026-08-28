#!/usr/bin/env bash
# Restyle Plasma panels as naiture islands: floating, fit to content, 50px,
# adaptive translucency.
#
# Panel geometry does NOT live with the containment. plasmashell keeps it in
# ~/.config/plasmashellrc under [PlasmaViews][Panel <id>]; the containment entry
# in plasma-org.kde.plasma.desktop-appletsrc only holds applets and location.
# plasmashell also rewrites plasmashellrc when it exits, so the shell has to be
# stopped while the keys are written, not merely restarted afterwards.
#
#   --align  ID:VALUE[,ID:VALUE...]   per-panel Qt alignment override
#                                     (1 = left, 132 = centre, 2 = right)
#   --no-restart                      write config only, leave the shell alone
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
APPLETSRC="$CONF/plasma-org.kde.plasma.desktop-appletsrc"

THICKNESS="${NAITURE_PANEL_THICKNESS:-50}"
LENGTH_MODE=1     # 0 fill available, 1 fit content, 2 custom
OPACITY=0         # 0 adaptive, 1 opaque, 2 translucent
FLOATING=1
ALIGNMENT=132     # Qt::AlignCenter
RESTART=1
declare -A ALIGN_MAP=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --align)
      IFS=',' read -ra pairs <<< "$2"
      for pair in "${pairs[@]}"; do ALIGN_MAP["${pair%%:*}"]="${pair##*:}"; done
      shift ;;
    --no-restart) RESTART=0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

[[ -f "$APPLETSRC" ]] || { echo "no panel config at $APPLETSRC" >&2; exit 1; }

# Panel ids come from the containments; geometry goes elsewhere.
mapfile -t PANELS < <(
  awk '
    /^\[Containments\]\[[0-9]+\]$/ { cur = $0; gsub(/[^0-9]/, "", cur); next }
    /^\[/ { if ($0 !~ /^\[Containments\]\[[0-9]+\]\[General\]$/) cur = "" }
    /^plugin=org\.kde\.panel$/ { if (cur != "") print cur }
  ' "$APPLETSRC" | sort -n
)

if [[ ${#PANELS[@]} -eq 0 ]]; then
  echo "  no panels found — nothing to restyle"
  exit 0
fi

SHELL_WAS_RUNNING=0
if [[ $RESTART -eq 1 ]] && systemctl --user is-active --quiet plasma-plasmashell.service; then
  SHELL_WAS_RUNNING=1
  systemctl --user stop plasma-plasmashell.service
  # give it a moment to finish flushing its config
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    systemctl --user is-active --quiet plasma-plasmashell.service || break
    sleep 0.3
  done
fi

set_key() {
  kwriteconfig6 --file plasmashellrc \
    --group PlasmaViews --group "Panel $1" --key "$2" "$3"
}

for id in "${PANELS[@]}"; do
  align="${ALIGN_MAP[$id]:-$ALIGNMENT}"
  set_key "$id" thickness       "$THICKNESS"
  set_key "$id" panelLengthMode "$LENGTH_MODE"
  set_key "$id" panelOpacity    "$OPACITY"
  set_key "$id" floating        "$FLOATING"
  set_key "$id" alignment       "$align"
  echo "  panel $id -> ${THICKNESS}px, floating, fit-to-content, align $align"
done

# A panel whose only applet is the clock is the design's time pill: show the
# time alone, 24-hour, no date and no seconds.
clock_pill() {
  local cid="$1" aid="$2"
  local set="kwriteconfig6 --file $APPLETSRC --group Containments --group $cid \
    --group Applets --group $aid --group Configuration --group Appearance --key"
  $set showDate false
  $set dateDisplayFormat 2
  $set use24hFormat 2
  $set showSeconds 0
  echo "  panel $cid -> clock shows the time only"
}

# Every tray icon hidden, so the pill shows the time and the quick-settings
# popup is one click away — the design's time island.
_naiture_tray=(
  org.kde.kdeconnect
  org.kde.kscreen
  org.kde.plasma.battery
  org.kde.plasma.bluetooth
  org.kde.plasma.brightness
  org.kde.plasma.cameraindicator
  org.kde.plasma.clipboard
  org.kde.plasma.devicenotifier
  org.kde.plasma.keyboardindicator
  org.kde.plasma.keyboardlayout
  org.kde.plasma.manage-inputmethod
  org.kde.plasma.mediacontroller
  org.kde.plasma.networkmanagement
  org.kde.plasma.notifications
  org.kde.plasma.printmanager
  org.kde.plasma.vault
  org.kde.plasma.volume
  org.kde.plasma.weather
)
TRAY_ITEMS=$(IFS=,; echo "${_naiture_tray[*]}")

tray_hidden() {
  local cid="$1" aid="$2"
  local set="kwriteconfig6 --file $APPLETSRC --group Containments --group $cid \
    --group Applets --group $aid --group Configuration --group General --key"
  $set showAllItems false
  $set hiddenItems "$TRAY_ITEMS"
  echo "  panel $cid -> tray icons hidden, quick settings in the popup"
}

for id in "${PANELS[@]}"; do
  mapfile -t applets < <(
    awk -v id="$id" '
      $0 ~ "^\\[Containments\\]\\["id"\\]\\[Applets\\]\\[[0-9]+\\]$" {
        a = $0; gsub(/[^0-9]/, " ", a); split(a, f, " "); cur = f[2]; next
      }
      /^\[/ { if ($0 !~ /Configuration/) cur = "" }
      /^plugin=org\.kde\.plasma\./ { if (cur != "") print cur "=" substr($0, 8) }
    ' "$APPLETSRC"
  )
  for entry in "${applets[@]}"; do
    case "${entry#*=}" in
      org.kde.plasma.digitalclock) clock_pill  "$id" "${entry%%=*}" ;;
      org.kde.plasma.systemtray)   tray_hidden "$id" "${entry%%=*}" ;;
    esac
  done
done

if [[ $SHELL_WAS_RUNNING -eq 1 ]]; then
  systemctl --user start plasma-plasmashell.service
  echo "  plasmashell restarted"
elif [[ $RESTART -eq 1 ]]; then
  echo "  log out and back in for the panel change to show"
fi
