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

# The selected tab carries the accent on its bottom edge — the same edge the
# dock's marker rides, under the thing it marks rather than over it.
#
# It cannot travel between tabs the way the dock's does. That marker is ours,
# in QML, and it animates its own x; this is Konsole's QTabBar dressed in a Qt
# style sheet, and a style sheet has no animation in it. Marking the selected
# tab is the whole of what is reachable without owning the widget.
#
# The colour is written in rather than named, because a style sheet cannot ask
# the colour scheme for anything — so this is the one place in the theme where
# an accent is baked into a file, and scripts/accent.sh calls back here
# (`--tabbar`) whenever it changes so the two cannot drift.
write_tabbar_css() {
  install -d "$DATA/naiture"

  # kdeglobals holds it as "r,g,b"; the palette's gold is the fallback for a
  # desktop where the accent has not been written yet.
  local accent
  accent="$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
  [[ "$accent" =~ ^[0-9]+,[0-9]+,[0-9]+$ ]] || accent="222,204,96"

  # Half-strength against the strip, for the bar a hovered tab shows. Blended
  # here rather than written as rgba(), because the bar is a border colour and
  # a translucent border would let the tab's own background through it.
  local accent_dim
  accent_dim="$(IFS=,; set -- $accent
    printf 'rgb(%d, %d, %d)' $(( ($1 + 13) / 2 )) $(( ($2 + 20) / 2 )) $(( ($3 + 16) / 2 )))"
  accent="rgb(${accent//,/, })"
  # The style sheet is written verbatim and the colours put in afterwards. An
  # unquoted heredoc would expand it, and a style sheet is exactly the kind of
  # text that has $ and backticks in it — a backtick in a comment here silently
  # ran as a command and ate the words around it.
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
/* Every state carries the same 2px border and differs only in what colour the
   bottom edge of it is. Qt draws a rounded border box as one shape, and giving
   one side a different *width* from the others makes it fall back to filling
   the whole shape in the border colour — which is a tab gone entirely accent.
   So the width never changes; only the colour does. */
QTabBar::tab {
    background: transparent;
    color: rgba(242, 247, 242, 0.72);
    border: 2px solid transparent;
    border-radius: 9px;
    padding: 8px 6px 8px 14px;
    margin: 5px 3px;
    min-width: 11em;
    max-width: 20em;
}

QTabBar::tab:hover {
    background: rgba(240, 248, 240, 0.06);
    border-bottom-color: __ACCENT_DIM__;
    color: #f2f7f2;
}

QTabBar::tab:selected {
    background: #18241c;
    border-bottom-color: __ACCENT__;
    /* Qt draws a border along the radius, so a 9px bottom corner would bend
       the bar into a smile. Nearly square down there keeps it a bar. */
    border-bottom-left-radius: 2px;
    border-bottom-right-radius: 2px;
    color: #f2f7f2;
}

QTabBar::tab:selected:hover {
    background: #1b291f;
}

/* Close is the window's own close button in miniature: the glyph and nothing
   else, faint until the pointer is on it. */
/* The tab's close button cannot be restyled from here, and both ways in were
   tried: `image:` on the close-button subcontrol does nothing because Konsole
   builds its own button rather than using QTabBar's, and `qproperty-icon` on
   that button is overwritten when Konsole sets the icon in code afterwards. So
   the x stays Breeze's filled circle. tab-close-*.svg are installed and unused
   for now; they are what the button would wear if it were ours.

   The + is further out still: Konsole hangs it off the *QTabWidget* with
   setCornerWidget, top-left, and this style sheet is on the QTabBar, so no
   selector here can see it at all. It cannot be moved to the right of the tabs
   or redrawn as a plain +. */
QTabBar::close-button {
    subcontrol-position: right;
    margin: 2px 4px 2px 10px;
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

  sed -i -e "s|__ACCENT_DIM__|$accent_dim|g" \
         -e "s|__ACCENT__|$accent|g" \
         -e "s|__DATA__|$DATA|g" \
         "$DATA/naiture/konsole-tabbar.css"
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

# The tab's close glyph, at rest and under the pointer. A style sheet can set a
# subcontrol's image but not its opacity, and Breeze's own close icon comes in
# at full strength — so the two states are shipped as two files. This is the
# window's own close button: nothing but the glyph, faint until you are on it,
# and then the ember the decoration uses.
install_close_glyphs() {
  # Qt's SVG renderer is SVG Tiny: it does not parse rgba() in a stroke, and a
  # glyph written that way renders as nothing at all. Opacity is its own
  # attribute here for that reason.
  local f colour alpha
  for f in rest hot; do
    if [[ "$f" == hot ]]; then colour="#f2716a"; alpha="1"
    else                       colour="#f2f7f2"; alpha="0.42"; fi
    install -Dm644 /dev/stdin "$DATA/naiture/tab-close-$f.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
  <path d="M4.6 4.6 L11.4 11.4 M11.4 4.6 L4.6 11.4"
        stroke="$colour" stroke-opacity="$alpha" stroke-width="1.6"
        stroke-linecap="round" fill="none"/>
</svg>
SVG
  done
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

    # The same view under Claude's mark. A tab carries no icon by default —
    # twelve identical terminal glyphs say nothing — but an AI task is a
    # different kind of thing from a shell, and that is worth one icon. The two
    # families share this view's colour scheme, so only the profile doubles.
    local claude="$DATA/konsole/naiture-claude-$n.profile"
    cp "$REPO/konsole/Naiture.profile" "$claude"
    kwriteconfig6 --file "$claude" --group Appearance \
      --key ColorScheme "NaitureView$n"
    dress_profile "$claude" "naiture-claude-$n" naiture-claude
  done
  echo "  views   -> $VIEWS views x2 (plain and Claude), drawn on first use into $scenes"
}

# What every naiture profile has in common: no icon on the tab, a tab named
# after the directory rather than after the profile that drew it, and the
# helper as its command.
dress_profile() { # dress_profile <file> <name> [icon]
  local f="$1" name="$2" icon="${3:-naiture-blank}"
  kwriteconfig6 --file "$f" --group General --key Name "$name"
  kwriteconfig6 --file "$f" --group General --key Icon "$icon"
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
install_close_glyphs
write_tabbar_css
install_views
dress_base_profiles
write_settings
echo "  console window -> tabs at the top, a view behind each one"
