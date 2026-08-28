#!/usr/bin/env bash
# Restyle Plasma panels as naiture islands: floating, fit to content, 50px,
# adaptive translucency.
#
# plasmashell's scripting API can create and remove panels on Plasma 6.6 but
# does not persist geometry properties, so geometry is written straight to the
# containment config and the shell is restarted to pick it up.
#
#   --align  ID:VALUE[,ID:VALUE...]   per-panel Qt alignment override
#                                     (1 = left, 132 = centre, 2 = right)
#   --no-restart                      write config only
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
APPLETSRC="$CONF/plasma-org.kde.plasma.desktop-appletsrc"

THICKNESS="${NAITURE_PANEL_THICKNESS:-50}"
LENGTH_MODE=1     # fit content
OPACITY=0         # adaptive
FLOATING=true
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

# Containment ids whose plugin is org.kde.panel.
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

set_key() {
  kwriteconfig6 --file "$APPLETSRC" \
    --group Containments --group "$1" --group General --key "$2" "$3"
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

if [[ $RESTART -eq 1 ]]; then
  if systemctl --user is-active --quiet plasma-plasmashell.service; then
    systemctl --user restart plasma-plasmashell.service
    echo "  plasmashell restarted"
  else
    echo "  log out and back in for the panel change to show"
  fi
fi
