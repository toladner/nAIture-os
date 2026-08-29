#!/usr/bin/env bash
# Set the one accent colour that everything else follows.
#
#   ./scripts/accent.sh              # the design's gold
#   ./scripts/accent.sh sky          # any role named in palette/naiture.json
#   ./scripts/accent.sh '#decc60'    # or a literal
#
# There are two places an accent has to be written, and missing either leaves
# half the desktop the old colour:
#
#   kdeglobals [General] AccentColor
#       what System Settings calls the accent. Applications and the window
#       decoration follow it.
#   the Naiture colour scheme, and the *desktop theme's* copy of it
#       plasmashell resolves Kirigami.Theme.highlightColor from the desktop
#       theme's `colors` file, not from kdeglobals — so the quick-settings
#       sheet, the focused task's bar (classed ColorScheme-Highlight in
#       tasks.svg) and Plasma's own applet indicator all read that file.
#   the mark
#       tools/make_logo_svg.py draws naiture's leaf as two steps along the
#       accent's own hue. A gradient cannot be a ColorScheme-Highlight fill, so
#       the mark is redrawn here rather than recoloured at render time.
#
# Both colour files are rewritten from the repo's originals each time rather
# than edited in place, so running this twice with different roles gives the
# same result as running it once, and nothing accumulates.
#
# The design authored sky as its primary accent; gold is the bolder reading and
# the one naiture ships — the colour files are checked in with it, and this
# script rewrites them from gold into whatever is asked for.
# `./scripts/accent.sh sky` puts the design's own reading back.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
ROLE="${1:-gold}"

read -r HEX RGB < <(python3 - "$REPO" "$ROLE" <<'PY'
import json
import sys

sys.path.insert(0, f"{sys.argv[1]}/tools")
import oklch

palette = json.load(open(f"{sys.argv[1]}/palette/naiture.json"))
role = sys.argv[2]

if role.startswith("#"):
    h = role.lstrip("#")
    print(role, ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4)))
else:
    accents = palette["accent"]
    if role not in accents:
        sys.exit(f"unknown accent role '{role}'; have: {', '.join(accents)}")
    hexv = accents[role]["hex"]
    h = hexv.lstrip("#")
    print(hexv, ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4)))
PY
)

# Rewrite the two colour files from the repo originals, swapping the sky family
# they were authored with for the chosen accent's.
python3 - "$REPO" "$ROLE" "$DATA" <<'PY'
import json
import pathlib
import shutil
import sys

repo, role, data = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, f"{repo}/tools")
import oklch

palette = json.load(open(f"{repo}/palette/naiture.json"))


def lch(role_name):
    L, C, H = (float(v) for v in palette["accent"][role_name]["oklch"].split())
    return L, C, H


if role.startswith("#"):
    # A literal has no OKLCH to shade from, so use it flat for every step and
    # let the scheme's own text colours carry the contrast.
    rgb = tuple(int(role.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    family = {k: "%d,%d,%d" % rgb for k in
              ("base", "bright", "deep")}
    family["fg_active"] = "4,16,20"
    family["fg_inactive"] = "20,52,62"
else:
    L, C, H = lch(role)
    family = {
        # The same spread the design uses between sky, skyBright and skyDeep.
        "base": oklch.rgbstr(L, C, H),
        "bright": oklch.rgbstr(min(L + 0.04, 0.99), C, H),
        "deep": oklch.rgbstr(max(L - 0.14, 0.05), C + 0.02, H),
        # Text that sits on top of the accent.
        "fg_active": oklch.rgbstr(0.20, 0.03, H),
        "fg_inactive": oklch.rgbstr(0.34, 0.04, H),
    }

# What the shipped files carry: the gold family, since that is the accent
# naiture ships. These are the literals every rewrite replaces, so they have to
# be exactly what is checked in — change the colour files and change these in
# the same breath, or `accent.sh sky` finds nothing to swap and leaves gold in
# place.
SHIPPED = {
    "base": "222,204,96",
    "bright": "235,217,110",
    "deep": "181,159,0",
    "fg_active": "25,22,6",
    "fg_inactive": "61,57,32",
}

targets = [
    (f"{repo}/color-schemes/Naiture.colors",
     f"{data}/color-schemes/Naiture.colors"),
    (f"{repo}/desktoptheme/naiture/colors",
     f"{data}/plasma/desktoptheme/naiture/colors"),
]

for src, dst in targets:
    dest = pathlib.Path(dst)
    if not dest.parent.exists():
        continue
    text = pathlib.Path(src).read_text()
    for key, old in SHIPPED.items():
        text = text.replace(old, family[key])
    dest.write_text(text)
    print(f"  {dest}")
PY

# Redraw the mark in the new accent, everywhere a copy of it lives.
MARKS=("$REPO/icons/naiture.svg"
       "$REPO/plasmoids/org.naiture.dock/contents/icons/naiture.svg")
for dir in "$DATA/plasma/plasmoids/org.naiture.dock/contents/icons" \
           "$DATA/icons/hicolor/scalable/apps"; do
  [[ -d "$dir" ]] && MARKS+=("$dir/naiture.svg")
done
python3 "$REPO/tools/make_logo_svg.py" -a "$HEX" "${MARKS[@]}" | sed 's/^/  /'

# The console's tab bar is a Qt style sheet, which cannot ask the colour scheme
# for anything, so its copy of the accent is written into the file. Redraw it
# here or it keeps the colour it was installed with.
kwriteconfig6 --notify --file kdeglobals --group General --key AccentColor "$RGB"
kwriteconfig6 --notify --file kdeglobals --group General --key LastUsedCustomAccentColor "$RGB"

# Plasma only honours a custom accent while it is not taking one from the
# wallpaper.
kwriteconfig6 --notify --file kdeglobals --group General --key accentColorFromWallpaper false

bash "$REPO/scripts/console.sh" --tabbar >/dev/null 2>&1 || true

plasma-apply-colorscheme Naiture  >/dev/null 2>&1 || true
plasma-apply-desktoptheme naiture >/dev/null 2>&1 || true
command -v qdbus-qt6 >/dev/null 2>&1 && \
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

echo "  accent -> $ROLE $HEX ($RGB)"
