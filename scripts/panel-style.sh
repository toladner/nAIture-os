#!/usr/bin/env bash
# Restyle Plasma panels as naiture islands: 50px, fit to content, adaptive
# translucency, and reserving no screen space so a maximised window runs the
# full height of the display underneath them.
#
# Panel geometry does NOT live with the containment. plasmashell keeps it in
# ~/.config/plasmashellrc; the containment entry in
# plasma-org.kde.plasma.desktop-appletsrc only holds applets and location.
# plasmashell also rewrites plasmashellrc when it exits, so the shell has to be
# stopped while the keys are written, not merely restarted afterwards.
#
# Within plasmashellrc the keys are split across two groups, and putting one in
# the wrong group is accepted and silently ignored. From shell/panelview.cpp:
#
#   [PlasmaViews][Panel <id>]            alignment, floating, panelOpacity,
#                                        panelLengthMode, panelVisibility
#                                        (resolutionIndependentConfig)
#   [PlasmaViews][Panel <id>][Defaults]  thickness, maxLength, minLength
#                                        (configDefaults; setThickness reads
#                                        `configDefaults().readEntry("thickness")`
#                                        and never looks at the parent group)
#
#   --align  ID:VALUE[,ID:VALUE...]   per-panel Qt alignment override
#                                     (1 = left, 132 = centre, 2 = right)
#   --no-restart                      write config only, leave the shell alone
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
APPLETSRC="$CONF/plasma-org.kde.plasma.desktop-appletsrc"

THICKNESS="${NAITURE_PANEL_THICKNESS:-38}"
LENGTH_MODE=1     # 0 fill available, 1 fit content, 2 custom
OPACITY=0         # 0 adaptive, 1 opaque, 2 translucent
VISIBILITY=3      # 0 normal, 1 auto-hide, 2 dodge windows, 3 windows go below
FLOATING=0
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

# The design's quick-settings popup holds everything; nothing lives in the tray
# strip itself. Plasmoid entries are hidden by plugin id.
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

# Application tray icons are StatusNotifierItems, hidden by *their* id rather
# than a plugin id, and which ones exist depends on what is running. Ask the
# watcher rather than shipping a guess. Anything that registers later still
# appears in the strip until this is re-run — a limitation of per-id hiding,
# the system tray has no "hide everything" switch.
mapfile -t _naiture_sni < <(
  qdbus-qt6 org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher.RegisteredStatusNotifierItems 2>/dev/null |
  while read -r service; do
    [[ -n "$service" ]] || continue
    qdbus-qt6 --literal "${service%%/*}" "/${service#*/}" \
      org.freedesktop.DBus.Properties.Get org.kde.StatusNotifierItem Id 2>/dev/null |
      sed -n 's/.*: "\(.*\)"].*/\1/p'
  done
)
for id in "${_naiture_sni[@]}"; do
  [[ -n "$id" ]] && _naiture_tray+=("$id")
done

TRAY_ITEMS=$(IFS=,; echo "${_naiture_tray[*]}")

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

set_default() {
  kwriteconfig6 --file plasmashellrc \
    --group PlasmaViews --group "Panel $1" --group Defaults --key "$2" "$3"
}

for id in "${PANELS[@]}"; do
  align="${ALIGN_MAP[$id]:-$ALIGNMENT}"
  set_key     "$id" panelLengthMode  "$LENGTH_MODE"
  set_key     "$id" panelOpacity     "$OPACITY"
  set_key     "$id" panelVisibility  "$VISIBILITY"
  set_key     "$id" floating         "$FLOATING"
  set_key     "$id" alignment        "$align"
  set_default "$id" thickness        "$THICKNESS"
  echo "  panel $id -> ${THICKNESS}px, flush, fit-to-content, align $align, no reserved space"
done

# A panel whose only applet is the clock is the design's time pill: the time
# alone, 24-hour, no date and no seconds, set in the design's JetBrains Mono at
# the system's own text size.
#
# autoFontAndSize has to go off first. While it is on, DigitalClock.qml sizes
# the time at `3 * Kirigami.Theme.defaultFont.pixelSize` and fits that to the
# panel height, which on a 50px panel is enormous; fontFamily/fontSize/
# fontWeight are read only once it is off.
clock_pill() {
  local cid="$1" aid="$2"
  local set="kwriteconfig6 --file $APPLETSRC --group Containments --group $cid \
    --group Applets --group $aid --group Configuration --group Appearance --key"
  $set showDate false
  $set dateDisplayFormat 2
  $set use24hFormat 2
  $set showSeconds 0
  $set autoFontAndSize false
  $set fontFamily "JetBrains Mono"
  $set fontSize 10
  $set fontWeight 500
  echo "  panel $cid -> clock shows the time only, 10pt JetBrains Mono"
}

# The system tray is a nested *containment*, not an ordinary applet, so its
# KConfigLoader group is the applet group itself and not the [Configuration]
# subgroup everything else uses. Plasma writing its own extraItems/knownItems
# into [Applets][<id>][General] is the proof of where it reads hiddenItems
# from; [Configuration][General] is accepted and silently ignored.
tray_hidden() {
  local cid="$1" aid="$2"
  local set="kwriteconfig6 --file $APPLETSRC --group Containments --group $cid \
    --group Applets --group $aid --group General --key"
  $set showAllItems false
  $set hiddenItems "$TRAY_ITEMS"
  echo "  panel $cid -> ${#_naiture_tray[@]} tray entries moved into the popup"
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
