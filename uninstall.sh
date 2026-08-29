#!/usr/bin/env bash
# Remove the naiture theme and restore the settings install.sh snapshotted.
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$CONF/naiture/backup"

KEEP_FONTS=0
[[ "${1:-}" == "--keep-fonts" ]] && KEEP_FONTS=1

say()  { printf '\033[38;2;106;191;217m::\033[0m %s\n' "$*"; }
warn() { printf '\033[38;2;222;204;96m!!\033[0m %s\n' "$*" >&2; }

if [[ -d "$BACKUP" ]]; then
  while IFS= read -r f; do
    name="${f#$BACKUP/}"
    [[ "$name" == .* ]] && continue
    mkdir -p "$(dirname "$CONF/$name")"
    cp -a "$f" "$CONF/$name"
  done < <(find "$BACKUP" -type f ! -name '.*')
  say "restored config from $BACKUP (taken $(cat "$BACKUP/.taken-at" 2>/dev/null || echo 'unknown'))"

  # Files naiture created that were not there before it go away entirely —
  # restoring the others would otherwise leave these still pointing at naiture.
  if [[ -f "$BACKUP/.absent" ]]; then
    while read -r name; do
      [[ -n "$name" && -f "$CONF/$name" ]] || continue
      rm -f "$CONF/$name"
      say "removed $name (did not exist before naiture)"
    done < "$BACKUP/.absent"
  fi
else
  warn "no backup at $BACKUP — falling back to Breeze Dark defaults"
  kwriteconfig6 --file plasmarc  --group Theme   --key name breeze-dark
  kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile --delete || true
fi

bash "$(dirname "${BASH_SOURCE[0]}")/scripts/dock-proximity.sh" --off >/dev/null 2>&1 || true
bash "$(dirname "${BASH_SOURCE[0]}")/scripts/screen-edges.sh" --restore >/dev/null 2>&1 || true

rm -f  "$DATA/color-schemes/Naiture.colors"
rm -rf "$DATA/plasma/desktoptheme/naiture"
rm -rf "$DATA/plasma/plasmoids/org.naiture.dock"
rm -rf "$DATA/plasma/plasmoids/org.naiture.quicksettings"
rm -rf "$DATA/plasma/plasmoids/org.naiture.showdesktop"
rm -f  "$DATA/icons/hicolor/scalable/apps/naiture.svg"
rm -f  "$DATA/icons/hicolor/scalable/apps/naiture-claude.svg"
rm -f  "$DATA"/icons/hicolor/*/apps/naiture-claude.png
rm -f  "$DATA/applications/naiture-claude.desktop"
rm -f  "$DATA/konsole/Claude.profile"

rm -rf "$DATA/wallpapers/naiture"
rm -f  "$DATA/konsole/Naiture.colorscheme" "$DATA/konsole/Naiture.profile"

# The console window: the views, the helper that chooses between them, the tab
# bar's stylesheet, and the pictures — which only ever lived in tmpfs.
rm -f  "$DATA"/konsole/NaitureView[0-9][0-9].colorscheme
rm -f  "$DATA"/konsole/naiture-view-[0-9][0-9].profile
rm -f  "$DATA"/konsole/naiture-claude-[0-9][0-9].profile
rm -f  "$DATA/icons/hicolor/scalable/apps/naiture-blank.svg"
rm -f  "$HOME/.local/bin/naiture-view"
rm -rf "$DATA/naiture"
rm -rf "${XDG_RUNTIME_DIR:-/tmp}/naiture/scenes"

# The explorer: our toolbar, the global view properties, and the keys that
# emptied the window of everything but its band.
rm -f  "$DATA/kxmlgui5/dolphin/dolphinui.rc"
rm -rf "$DATA/dolphin/view_properties/global"
for key in ShowStatusBar ShowZoomSlider FilterBar ShowSelectionToggle \
           ShowToolTips AlwaysShowTabBar ShowCloseButtonOnTabs EditableUrl \
           ShowFullPath; do
  kwriteconfig6 --file dolphinrc --group General --key "$key" --delete 2>/dev/null || true
done
for key in ShowOpenTerminal ShowViewMode; do
  kwriteconfig6 --file dolphinrc --group ContextMenu --key "$key" --delete 2>/dev/null || true
done
kwriteconfig6 --file dolphinrc --group MainWindow --group "Toolbar mainToolBar" \
  --key IconText --delete 2>/dev/null || true
kwriteconfig6 --file dolphinrc --group "Toolbar mainToolBar" \
  --key IconText --delete 2>/dev/null || true

# konsolerc keeps the tab bar and the hidden toolbars; the backup restore above
# only covers the file when there was one to begin with.
for key in TabBarVisibility TabBarPosition ExpandTabWidth NewTabButton \
           SearchTabsButton CloseTabButton CloseTabOnMiddleMouseButton \
           TabBarUseUserStyleSheet TabBarUserStyleSheetFile; do
  kwriteconfig6 --file konsolerc --group TabBar --key "$key" --delete 2>/dev/null || true
done
for tb in mainToolBar sessionToolbar; do
  kwriteconfig6 --file konsolerc --group MainWindow --group "Toolbar $tb" \
    --key Hidden --delete 2>/dev/null || true
  kwriteconfig6 --file konsolerc --group "Toolbar $tb" \
    --key Hidden --delete 2>/dev/null || true
done

if [[ $KEEP_FONTS -eq 0 ]]; then
  rm -rf "$DATA/fonts/naiture"
  fc-cache -f >/dev/null 2>&1 || true
  say "removed the naiture fonts (pass --keep-fonts to keep them)"
fi

say "reloading the session"
if [[ -d "$BACKUP" ]]; then
  scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)"
  [[ -n "$scheme" ]] && plasma-apply-colorscheme "$scheme" >/dev/null 2>&1 || true
  theme="$(kreadconfig6 --file plasmarc --group Theme --key name 2>/dev/null || true)"
  [[ -n "$theme" ]] && plasma-apply-desktoptheme "$theme" >/dev/null 2>&1 || true
else
  plasma-apply-colorscheme BreezeDark  >/dev/null 2>&1 || true
  plasma-apply-desktoptheme breeze-dark >/dev/null 2>&1 || true
fi
command -v qdbus-qt6 >/dev/null 2>&1 && qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

cat <<'EOF'

  naiture removed. Panel layout is not rebuilt automatically — if you used
  --islands, restore it with:
      cp ~/.config/naiture/backup/plasma-org.kde.plasma.desktop-appletsrc ~/.config/
      systemctl --user restart plasma-plasmashell
EOF
