#!/usr/bin/env bash
# Install the two typefaces the naiture design uses, per-user (no root).
# Both are variable fonts from the upstream Google Fonts repository.
set -euo pipefail

DEST="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/naiture"
BASE="https://raw.githubusercontent.com/google/fonts/main/ofl"

FILES=(
  "archivo/Archivo%5Bwdth,wght%5D.ttf|Archivo[wdth,wght].ttf"
  "archivo/Archivo-Italic%5Bwdth,wght%5D.ttf|Archivo-Italic[wdth,wght].ttf"
  "jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf|JetBrainsMono[wght].ttf"
  "jetbrainsmono/JetBrainsMono-Italic%5Bwght%5D.ttf|JetBrainsMono-Italic[wght].ttf"
)

mkdir -p "$DEST"
for entry in "${FILES[@]}"; do
  url="${entry%%|*}"; name="${entry##*|}"
  printf '  %-36s' "$name"
  if curl -fsSL --retry 4 --retry-delay 2 --retry-all-errors --connect-timeout 15 \
       "$BASE/$url" -o "$DEST/$name"; then
    echo "ok"
  else
    echo "FAILED"; rm -f "$DEST/$name"; exit 1
  fi
done

# Licences travel with the fonts.
curl -fsSL --retry 3 --retry-all-errors "$BASE/archivo/OFL.txt" -o "$DEST/OFL-Archivo.txt" || true
curl -fsSL --retry 3 --retry-all-errors "$BASE/jetbrainsmono/OFL.txt" -o "$DEST/OFL-JetBrainsMono.txt" || true

fc-cache -f "$DEST" >/dev/null
echo "Fonts installed to $DEST"
