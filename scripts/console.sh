#!/usr/bin/env bash
# The console's window.
#
#   ./scripts/console.sh            # the whole window
#   ./scripts/console.sh --tabbar   # just redraw the tab bar stylesheet
#
# A naiture window has no chrome that repeats what its content already says.
# There is one band at the top and then there is the thing you opened, and the
# band carries tabs and nothing else: split view, copy, paste and find all have
# keys already, so they live in the menu rather than taking a row of their own.
#
# Konsole gives four of the five pieces from configuration:
#
#   the tab bar       always shown, at the top, drawn by our own .css through
#                     TabBar/TabBarUserStyleSheetFile
#   the toolbar       gone, which is what takes the split/copy/paste/find
#                     buttons with it
#   the tab's name    the directory it is in, not the profile's name, so a tab
#                     says what it is rather than what drew it
#   the view          a wallpaper on the session's colour scheme
#
# The fifth — tabs sharing the line with minimise/maximise/close — needs a
# window the application draws itself, and Konsole draws none. The titlebar
# stays, and since that line is there anyway it keeps its title.
#
# Why VIEWS profiles that differ only in their colour scheme: Session.setProfile
# is the whole of Konsole's runtime API for appearance. There is no way to hand
# a session a scheme, and the scheme is what carries the wallpaper, so a view
# has to be a profile. konsole/naiture-view is what chooses between them, from
# inside each session.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
VIEWS=12

# The tab bar is deliberately accent-free. Everything else in naiture that
# marks "this one" uses the accent, but a tab strip marks one of twelve things
# at all times, and an accent that is always on stops meaning anything. The
# selected tab is a lifted surface and full-strength text instead — which is
# also why nothing here has to be rewritten when the accent changes.
write_tabbar_css() {
  install -d "$DATA/naiture"
  cat > "$DATA/naiture/konsole-tabbar.css" <<'CSS'
/* Written by scripts/console.sh — edit that, not this. */

/* The strip itself is the window's own surface, so the band at the top of a
   console reads as one piece with the titlebar above it rather than as a
   widget sitting on top of the terminal. */
QTabBar {
    background: #0d1410;
    border: 0;
    padding: 0 4px;
    qproperty-drawBase: 0;
}

/* A tab is a shape only when it is the one you are looking at. The rest are
   text on the band — no outlines, no separators, nothing to count. */
QTabBar::tab {
    background: transparent;
    color: rgba(242, 247, 242, 0.72);
    border: 1px solid transparent;
    border-radius: 9px;
    padding: 8px 6px 8px 14px;
    margin: 5px 3px;
    min-width: 11em;
    max-width: 20em;
}

QTabBar::tab:hover {
    background: rgba(240, 248, 240, 0.06);
    color: #f2f7f2;
}

QTabBar::tab:selected {
    background: #18241c;
    border: 1px solid rgba(240, 248, 240, 0.07);
    color: #f2f7f2;
}

QTabBar::tab:selected:hover {
    background: #1b291f;
}

/* Close takes the ember tint the window's own close button has. */
QTabBar::close-button {
    subcontrol-position: right;
    border-radius: 6px;
    margin: 2px 4px 2px 10px;
    padding: 1px;
}

QTabBar::close-button:hover {
    background: rgba(242, 113, 106, 0.24);
}

QTabBar::close-button:pressed {
    background: rgba(242, 113, 106, 0.38);
}

/* The + at the end of the strip, and the arrows that appear once there are
   more tabs than room. Qt draws all three as tool buttons and they come out
   as raised boxes unless they are told otherwise. */
QTabBar QToolButton,
QTabWidget QToolButton {
    background: transparent;
    border: 0;
    border-radius: 8px;
    margin: 5px 2px;
    padding: 2px 5px;
}

QTabBar QToolButton:hover,
QTabWidget QToolButton:hover {
    background: rgba(240, 248, 240, 0.08);
}

QTabBar QToolButton:pressed,
QTabWidget QToolButton:pressed {
    background: rgba(240, 248, 240, 0.13);
}

/* No line between the strip and the terminal under it. */
QTabWidget::pane {
    border: 0;
    background: transparent;
}
CSS
  echo "  tab bar -> $DATA/naiture/konsole-tabbar.css"
}

# The helper and the renderer it calls. A second copy of the helper goes on
# PATH because `konsole -e naiture-view claude ...` is how the dock starts a
# session, and -e is resolved against PATH.
install_runtime() {
  install -Dm755 "$REPO/konsole/naiture-view" "$DATA/naiture/bin/naiture-view"
  install -Dm755 "$REPO/konsole/naiture-view" "$HOME/.local/bin/naiture-view"
  for t in make_scene.py make_wallpaper.py oklch.py; do
    install -Dm644 "$REPO/tools/$t" "$DATA/naiture/tools/$t"
  done
  echo "  helper  -> $DATA/naiture/bin/naiture-view"
}

# One transparent icon, so a tab carries no picture. Konsole takes a tab's icon
# from its profile and there is no setting for "none".
install_blank_icon() {
  install -Dm644 /dev/stdin \
    "$DATA/icons/hicolor/scalable/apps/naiture-blank.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"/>
SVG
}

# VIEWS colour schemes, each naming a picture that does not exist yet, and
# VIEWS profiles, each naming one scheme. The pictures are drawn on demand into
# XDG_RUNTIME_DIR by the helper; a scheme whose wallpaper is missing simply
# draws its background colour, which is why this is safe to install before
# anything has been rendered.
install_views() {
  local scenes="${XDG_RUNTIME_DIR:-/tmp}/naiture/scenes"
  local i n
  for i in $(seq 0 $((VIEWS - 1))); do
    n="$(printf %02d "$i")"

    local scheme="$DATA/konsole/NaitureView$n.colorscheme"
    local profile="$DATA/konsole/naiture-view-$n.profile"

    cp "$REPO/konsole/Naiture.colorscheme" "$scheme"
    cp "$REPO/konsole/Naiture.profile"     "$profile"

    # Every one of these belongs to [General], and appending them would put
    # them under whichever group happens to be last — where Konsole reads the
    # file without complaint and ignores them. kwriteconfig6 places by group.
    kwriteconfig6 --file "$scheme" --group General \
      --key Description "Naiture view $n"
    kwriteconfig6 --file "$scheme" --group General --key Opacity 1
    kwriteconfig6 --file "$scheme" --group General --key Blur false
    kwriteconfig6 --file "$scheme" --group General \
      --key Wallpaper "$scenes/$n.jpg"
    kwriteconfig6 --file "$scheme" --group General --key WallpaperOpacity 0.88
    kwriteconfig6 --file "$scheme" --group General --key FillStyle Crop

    kwriteconfig6 --file "$profile" --group Appearance \
      --key ColorScheme "NaitureView$n"
    dress_profile "$profile" "naiture-view-$n"
  done
  echo "  views   -> $VIEWS profiles, drawn on first use into $scenes"
}

# What every naiture profile has in common: no icon on the tab, a tab named
# after the directory rather than after the profile that drew it, and the
# helper as its command.
dress_profile() { # dress_profile <file> <name>
  local f="$1" name="$2"
  kwriteconfig6 --file "$f" --group General --key Name "$name"
  kwriteconfig6 --file "$f" --group General --key Icon naiture-blank
  kwriteconfig6 --file "$f" --group General --key LocalTabTitleFormat "%d"
  kwriteconfig6 --file "$f" --group General --key RemoteTabTitleFormat "%H"
  kwriteconfig6 --file "$f" --group General \
    --key Command "$DATA/naiture/bin/naiture-view"
}

# The profiles a window actually starts in. They run the helper, which is what
# hands the session over to one of the views above.
dress_base_profiles() {
  local p
  for p in Naiture Claude; do
    [[ -f "$DATA/konsole/$p.profile" ]] && dress_profile "$DATA/konsole/$p.profile" "$p"
  done
}

write_settings() {
  local kw="kwriteconfig6 --file konsolerc"


  $kw --group TabBar --key TabBarVisibility AlwaysShowTabBar
  $kw --group TabBar --key TabBarPosition Top
  $kw --group TabBar --key ExpandTabWidth false
  $kw --group TabBar --key NewTabButton true
  $kw --group TabBar --key SearchTabsButton HideSearchTabsButton
  $kw --group TabBar --key CloseTabButton OnEachTab
  $kw --group TabBar --key CloseTabOnMiddleMouseButton true
  $kw --group TabBar --key TabBarUseUserStyleSheet true
  $kw --group TabBar --key TabBarUserStyleSheetFile \
      "$DATA/naiture/konsole-tabbar.css"

  # No menubar and no toolbar: one band, and the menu behind the hamburger.
  $kw --group KonsoleWindow --key ShowMenuBarByDefault false
  $kw --group KonsoleWindow --key ShowWindowTitleOnTitleBar true
  $kw --group KonsoleWindow --key RemoveWindowTitleBarAndFrame false
  # Konsole has two of them — mainToolBar carries the menu, split view, copy,
  # paste and find; sessionToolbar comes with the session. Both start visible,
  # which is the row this design is trying not to have. KMainWindow reads the
  # visibility from its autosave group, and writes the flat spelling itself
  # when a toolbar is hidden by hand, so both are written here.
  local tb
  for tb in mainToolBar sessionToolbar; do
    $kw --group MainWindow --group "Toolbar $tb" --key Hidden true
    $kw --group "Toolbar $tb" --key Hidden true
  done

  echo "  settings -> konsolerc"
}

case "${1:-}" in
  --tabbar) write_tabbar_css; exit 0 ;;
esac

install -d "$DATA/konsole"
install_runtime
install_blank_icon
write_tabbar_css
install_views
dress_base_profiles
write_settings
echo "  console window -> tabs at the top, a view behind each one"
