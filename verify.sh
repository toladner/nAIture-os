#!/usr/bin/env bash
# Check that naiture is actually applied. Exits 0 if everything is in place,
# 1 otherwise — so an agent can confirm the install rather than assume it.
#
#   --json    machine-readable output
set -uo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLETSRC="$CONF/plasma-org.kde.plasma.desktop-appletsrc"

JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

declare -a NAMES=() STATES=() DETAILS=()
FAILED=0

record() { # record <name> <ok|fail|warn> <detail>
  NAMES+=("$1"); STATES+=("$2"); DETAILS+=("$3")
  [[ "$2" == fail ]] && FAILED=1
  return 0
}

# --- colour scheme ---
scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
[[ "$scheme" == "Naiture" ]] \
  && record colour_scheme ok "Naiture" \
  || record colour_scheme fail "expected Naiture, found '${scheme:-unset}'"

# The accent must survive; Plasma re-derives selection from it.
accent="$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
[[ "$accent" == "106,191,217" ]] \
  && record accent ok "$accent" \
  || record accent fail "expected 106,191,217, found '${accent:-unset}'"

# --- plasma theme ---
theme="$(kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null)"
[[ "$theme" == "naiture" ]] \
  && record plasma_theme ok naiture \
  || record plasma_theme fail "expected naiture, found '${theme:-unset}'"

# --- fonts ---
# Collected first: `grep -q` exits early, which under `pipefail` would make the
# pipeline itself look like a failure.
families="$(fc-list : family 2>/dev/null | tr ',' '\n' | sort -u)"
if grep -qx 'Archivo' <<< "$families" && grep -qx 'JetBrains Mono' <<< "$families"; then
  record fonts ok "Archivo + JetBrains Mono installed"
else
  record fonts fail "Archivo and/or JetBrains Mono not found by fontconfig"
fi
uifont="$(kreadconfig6 --file kdeglobals --group General --key font 2>/dev/null)"
[[ "$uifont" == Archivo,* ]] \
  && record ui_font ok "${uifont%%,*}" \
  || record ui_font fail "expected Archivo, found '${uifont:-unset}'"

# --- wallpaper ---
img="$(grep -m1 '^Image=' "$APPLETSRC" 2>/dev/null | cut -d= -f2-)"
case "$img" in
  *"/wallpapers/naiture/"*) record wallpaper ok "${img##*/}" ;;
  "") record wallpaper fail "no wallpaper set" ;;
  *)  record wallpaper fail "not a naiture wallpaper: $img" ;;
esac

# --- kwin glass ---
blur="$(kreadconfig6 --file kwinrc --group Plugins --key blurEnabled 2>/dev/null)"
[[ "$blur" == "true" ]] \
  && record kwin_blur ok enabled \
  || record kwin_blur fail "blurEnabled=${blur:-unset}"

# --- panels ---
mapfile -t panels < <(
  awk '
    /^\[Containments\]\[[0-9]+\]$/ { cur = $0; gsub(/[^0-9]/, "", cur); next }
    /^\[/ { if ($0 !~ /^\[Containments\]\[[0-9]+\]\[General\]$/) cur = "" }
    /^plugin=org\.kde\.panel$/ { if (cur != "") print cur }
  ' "$APPLETSRC" 2>/dev/null | sort -n
)
if [[ ${#panels[@]} -eq 0 ]]; then
  record panels fail "no panels found"
else
  # Geometry lives in plasmashellrc, not with the containment.
  styled=0
  for id in "${panels[@]}"; do
    t="$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key thickness 2>/dev/null)"
    f="$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key floating 2>/dev/null)"
    l="$(kreadconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key panelLengthMode 2>/dev/null)"
    # The design's islands are flush with the edge (floating off) and rounded
    # by the theme's panel-background.svg, not by Plasma's floating mode.
    [[ "$t" == "50" && "$f" == "0" && "$l" == "1" ]] && styled=$(( styled + 1 ))
  done
  if [[ $styled -eq ${#panels[@]} ]]; then
    record panels ok "${#panels[@]} panel(s), all 50px, flush, fit-to-content"
  else
    record panels fail "$styled of ${#panels[@]} panel(s) styled (see plasmashellrc)"
  fi
fi

# --- window decoration ---
deco="$(kreadconfig6 --file kwinrc --group org.kde.kdecoration3 --key library 2>/dev/null)"
if [[ "$deco" == "org.kde.klassy" ]]; then
  radius="$(kreadconfig6 --file klassy/klassyrc --group Common --key WindowCornerRadius 2>/dev/null)"
  if [[ "$radius" == "22" ]]; then
    record windows ok "Klassy, 22px corners"
  else
    record windows warn "Klassy, corner radius ${radius:-unset} (design is 22)"
  fi
else
  record windows warn "no Klassy — windows have square corners (install it for the design's 22px)"
fi

# --- widget style ---
style="$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle 2>/dev/null)"
if [[ "$style" == "kvantum" ]]; then
  kvtheme="$(kreadconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme 2>/dev/null)"
  [[ "$kvtheme" == "Naiture" ]] \
    && record widgets ok "Kvantum/Naiture, translucent bodies" \
    || record widgets warn "Kvantum active but theme is '${kvtheme:-unset}'"
else
  record widgets warn "widget style '${style:-unset}' — window bodies are opaque; install kvantum"
fi

# --- konsole ---
kprofile="$(kreadconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>/dev/null)"
[[ "$kprofile" == "Naiture.profile" ]] \
  && record konsole ok "Naiture.profile" \
  || record konsole warn "default profile is '${kprofile:-unset}'"

# --- assets on disk ---
for path in "$DATA/color-schemes/Naiture.colors" \
            "$DATA/plasma/desktoptheme/naiture/metadata.json" \
            "$DATA/wallpapers/naiture/metadata.json" \
            "$DATA/konsole/Naiture.colorscheme"; do
  [[ -e "$path" ]] || record assets fail "missing $path"
done
[[ " ${NAMES[*]} " == *" assets "* ]] || record assets ok "all installed"

# --- backup, so rollback is possible ---
if [[ -f "$CONF/naiture/backup/.taken-at" ]]; then
  record backup ok "taken $(cat "$CONF/naiture/backup/.taken-at")"
else
  record backup warn "no backup — uninstall.sh will fall back to Breeze Dark"
fi

# --- output ---
if [[ $JSON -eq 1 ]]; then
  printf '{\n  "ok": %s,\n  "checks": {\n' "$([[ $FAILED -eq 0 ]] && echo true || echo false)"
  for i in "${!NAMES[@]}"; do
    sep=","; [[ $i -eq $(( ${#NAMES[@]} - 1 )) ]] && sep=""
    printf '    "%s": { "state": "%s", "detail": "%s" }%s\n' \
      "${NAMES[$i]}" "${STATES[$i]}" "${DETAILS[$i]//\"/\\\"}" "$sep"
  done
  printf '  }\n}\n'
else
  for i in "${!NAMES[@]}"; do
    case "${STATES[$i]}" in
      ok)   printf '  \033[38;2;94;188;123m✓\033[0m %-16s %s\n' "${NAMES[$i]}" "${DETAILS[$i]}" ;;
      warn) printf '  \033[38;2;222;204;96m·\033[0m %-16s %s\n' "${NAMES[$i]}" "${DETAILS[$i]}" ;;
      *)    printf '  \033[38;2;242;113;106m✗\033[0m %-16s %s\n' "${NAMES[$i]}" "${DETAILS[$i]}" ;;
    esac
  done
  echo
  [[ $FAILED -eq 0 ]] && echo "  naiture is applied." || echo "  naiture is NOT fully applied."
fi

exit $FAILED
