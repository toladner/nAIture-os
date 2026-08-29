#!/usr/bin/env bash
# The console a Claude Code session opens in.
#
# It is Konsole — nothing else here is worth replacing — but it is meant to be
# its own thing in the dock rather than a fourth terminal window. On Wayland a
# window's icon comes from the desktop file its application declares, and
# Konsole declares Konsole's; `konsole --desktopfile <name>` overrides that at
# launch, which gives the window its own app id, its own icon and its own tile.
#
# So this installs three small things and no window rule:
#
#   a Konsole profile     "Claude", the Naiture look under its own name, so the
#                         console can be restyled without touching the others
#   an icon               naiture-claude
#   a desktop entry       naiture-claude.desktop, which the icon hangs off and
#                         which puts "Claude" in the application list
#
# A KWin rule forcing `desktopfile` looks like it should do the same job and
# does not: the rule matches (a skiptaskbar written beside it fires) but the
# desktop file is not re-read from it, so the window keeps Konsole's icon.
#
# Claude Code ships no icon on Linux — the CLI is one binary with no image
# files in it — so the icon is fetched from claude.ai at install time rather
# than vendored here, which keeps someone else's artwork out of the repository
# and picks up whatever the current one is. Without a network, or without
# ImageMagick to resize it, tools/make_claude_icon.py draws a stand-in.
#
# Drop your own at icons/claude.png or icons/claude.svg and that wins over
# both.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"

install -Dm644 "$REPO/konsole/Claude.profile" "$DATA/konsole/Claude.profile"
# The icon claude.ai serves is a plate: the burst centred on cream, with a
# margin and a shadow line under it. A desktop icon wants the mark alone, edge
# to edge, on nothing — so the plate is taken off here rather than shipped as
# it comes.
#
# The mark is one flat colour on one flat ground, which is what makes this
# safe: match the mark's colour to build a mask, throw away every blob too
# small to be the mark (the shadow line), and repaint at full opacity so no
# cream survives in the anti-aliased edge. Trimming last is what removes the
# margin.
strip_plate() { # strip_plate <in.png> <out.png>; non-zero if it did not work
  local in="$1" out="$2" w h burst ground area
  w="$(magick "$in" -format '%w' info:)"
  h="$(magick "$in" -format '%h' info:)"
  [[ "${w:-0}" -ge 64 ]] || return 1

  # The burst is in the middle; the ground is beside it, inside the plate.
  burst="$(magick "$in" -format "%[pixel:p{$((w / 2)),$((h / 2))}]" info:)"
  ground="$(magick "$in" -format "%[pixel:p{$((w * 8 / 100)),$((h / 2))}]" info:)"
  area=$(( w * h / 40 ))

  magick "$in" -background "$ground" -alpha remove -alpha off \
    -fuzz 30% -fill white -opaque "$burst" \
    -fuzz 0 -fill black +opaque white -colorspace gray \
    -define connected-components:area-threshold="$area" \
    -define connected-components:mean-color=true -connected-components 8 \
    "$out.mask.png" 2>/dev/null || return 1

  magick -size "${w}x${h}" "xc:$burst" "$out.mask.png" -alpha off \
    -compose CopyOpacity -composite -trim +repage "$out.cut.png" 2>/dev/null || return 1

  local cw ch side
  cw="$(magick "$out.cut.png" -format '%w' info:)"
  ch="$(magick "$out.cut.png" -format '%h' info:)"
  # If the mask caught everything or nothing, the plate is not what we think.
  [[ "${cw:-0}" -ge 32 && "$cw" -lt "$w" ]] || { rm -f "$out".*.png; return 1; }

  side=$(( cw > ch ? cw : ch ))
  magick "$out.cut.png" -background none -gravity center \
    -extent "${side}x${side}" "$out" 2>/dev/null || return 1
  rm -f "$out.mask.png" "$out.cut.png"
}

install_icon() {
  local name=naiture-claude
  local sizes=(16 22 24 32 48 64 128 256)
  local src="" tmp=""

  # Yours, if you have put one there.
  for own in "$REPO/icons/claude.svg" "$REPO/icons/claude.png"; do
    [[ -f "$own" ]] && { src="$own"; break; }
  done

  if [[ -z "$src" ]] && command -v curl >/dev/null 2>&1 \
     && command -v magick >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    if curl -sSLf --max-time 15 -o "$tmp/plate.png" \
         https://claude.ai/images/claude_app_icon.png 2>/dev/null \
       && [[ -s "$tmp/plate.png" ]]; then
      if strip_plate "$tmp/plate.png" "$tmp/mark.png"; then
        src="$tmp/mark.png"
      else
        src="$tmp/plate.png"
      fi
    fi
  fi

  if [[ -n "$src" && "$src" == *.png ]] && command -v magick >/dev/null 2>&1; then
    # A themed icon is found by exact size, so one file per size it is. The
    # scalable copy goes, or it outranks these.
    rm -f "$DATA/icons/hicolor/scalable/apps/$name.svg"
    for s in "${sizes[@]}"; do
      mkdir -p "$DATA/icons/hicolor/${s}x${s}/apps"
      magick "$src" -background none -resize "${s}x${s}" \
        "$DATA/icons/hicolor/${s}x${s}/apps/$name.png"
    done
    [[ -n "$tmp" ]] && rm -rf "$tmp"
    echo "  icon    -> Claude's own, plate removed, ${#sizes[@]} sizes"
    return
  fi

  if [[ -n "$src" && "$src" == *.svg ]]; then
    install -Dm644 "$src" "$DATA/icons/hicolor/scalable/apps/$name.svg"
    echo "  icon    -> $src"
    return
  fi

  python3 "$REPO/tools/make_claude_icon.py" \
    "$DATA/icons/hicolor/scalable/apps/$name.svg" >/dev/null
  echo "  icon    -> drawn stand-in (claude.ai unreachable, or no ImageMagick)"
}

install_icon

install -Dm644 /dev/stdin "$DATA/applications/naiture-claude.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Claude
GenericName=Claude Code session
Comment=A Claude Code session in its own console
Icon=naiture-claude
Exec=konsole --desktopfile naiture-claude --profile Claude -e $CLAUDE_BIN
Terminal=false
Categories=Development;Utility;
StartupNotify=true
EOF

update-desktop-database "$DATA/applications" >/dev/null 2>&1 || true
gtk-update-icon-cache -qtf "$DATA/icons/hicolor" >/dev/null 2>&1 || true

# An earlier naiture wrote a KWin rule for this and it never worked; take it
# back out rather than leaving it to match windows forever.
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/kwinrulesrc" ]]; then
  list="$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)"
  if [[ ",$list," == *",naiture-claude,"* ]]; then
    # kwriteconfig6 --delete-group leaves the group behind here, so take the
    # stanza out of the file directly.
    sed -i '/^\[naiture-claude\]$/,/^$/d' \
      "${XDG_CONFIG_HOME:-$HOME/.config}/kwinrulesrc"
    list="$(sed 's/naiture-claude,\{0,1\}//; s/,$//' <<<"$list")"
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$list"
    kwriteconfig6 --file kwinrulesrc --group General --key count \
      "$([[ -z "$list" ]] && echo 0 || awk -F, '{print NF}' <<<"$list")"
    command -v qdbus-qt6 >/dev/null 2>&1 && \
      qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
fi

echo "  Claude console -> profile and desktop entry installed"
