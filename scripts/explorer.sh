#!/usr/bin/env bash
# The explorer's window.
#
# The console is a window you look *through*, so it got a view behind its text.
# The explorer is closer to the sheets — start and quick settings — a surface
# you look *at*, so it gets no scenery at all and stays clean behind its rows.
#
# What the sheets settled, applied here:
#
#   the content is the title    the breadcrumb is this window's "Welcome,
#                               Tobias" — the line saying what you are looking
#                               at, sharing its row with the window's actions
#   one band, not a stack       back, forward, up, the breadcrumb and search on
#                               a single row. No status bar, because a sheet has
#                               no footer, and no second row of anything.
#   pinned above recent         Dolphin's Places panel already *is* this —
#                               Places, then Recent, then Devices — so the left
#                               column needs nothing but to be left alone
#   rows, not tiles             details view, which is icon + name + detail:
#                               the same shape as a row in the start sheet
#
# Dolphin gives up more than Konsole did in one way and less in another. Its
# toolbar is authorable — dolphin/dolphinui.rc, and see the comment in it — which
# is the thing Konsole refused. But it has no equivalent of Konsole's
# TabBarUserStyleSheetFile: nothing in Dolphin takes a style sheet, so the
# window's *structure* is ours while its surfaces stay Breeze drawing in the
# Naiture palette. That is the same wall the console's close button hit, and it
# lifts the same way, if the explorer is ever ours.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

# KXmlGui still looks in kxmlgui5 for KF6 applications.
install -Dm644 "$REPO/dolphin/dolphinui.rc" \
               "$DATA/kxmlgui5/dolphin/dolphinui.rc"

kw() { kwriteconfig6 --file dolphinrc "$@"; }

# The band, and nothing under it.
kw --group General --key ShowStatusBar 0
kw --group General --key ShowZoomSlider false
kw --group General --key FilterBar false

# Noise inside the view: the hover checkmarks that offer to select a file, and
# tooltips that repeat what the row already says.
kw --group General --key ShowSelectionToggle false
kw --group General --key ShowToolTips false

# Tabs, always, so the explorer and the console are the same shape even with
# one folder open.
kw --group General --key AlwaysShowTabBar true
kw --group General --key ShowCloseButtonOnTabs true

# A path you read rather than a field you edit; the pencil is still there for
# when you do want to type one.
kw --group General --key EditableUrl false
kw --group General --key ShowFullPath false

# Right-click a folder and get a terminal on it. This is our own service menu
# rather than Dolphin's built-in entry, because Dolphin's is gated three ways —
# the setting, the item being a local directory, and KIO folding the extras into
# an "Actions" submenu once more than four apply — so whether you can see it
# depends on what else the machine has installed. Ours is always top level.
# Dolphin's is turned off so there is one entry rather than two.
# 755, not 644. KDesktopFile::isAuthorizedDesktopFile allows a desktop file
# outside the applications directories only when it is owned by root or carries
# the executable bit — the system's own service menus pass on the first, and
# anything installed into a user's home has to pass on the second. Without it
# the entry appears and clicking it says you are not authorized.
install -Dm755 "$REPO/dolphin/naiture-terminal.desktop" \
               "$DATA/kio/servicemenus/naiture-terminal.desktop"
kw --group ContextMenu --key ShowOpenTerminal false

# How the folder is shown belongs to the folder, so it is on the right-click as
# well as on the band — the band's button is the one you find, the context menu
# is the one you reach for once you know it is there.
kw --group ContextMenu --key ShowViewMode true

# No menubar — the titlebar carries the menu, as it does for every naiture
# window (scripts/window-decoration.sh, ButtonsOnLeft "N").
kw --group MainWindow --key MenuBar Disabled

# Arrows without the words "Back" and "Forward" beside them. A toolbar's icon
# text lives under the toolbar's own group, not the window's.
kw --group MainWindow --group "Toolbar mainToolBar" --key IconText IconOnly
kwriteconfig6 --file dolphinrc --group "Toolbar mainToolBar" --key IconText IconOnly

# Rows rather than tiles, everywhere. GlobalViewProps is on by default, so this
# one file is every folder's view. ViewMode 1 is details (0 icons, 2 columns).
kwriteconfig6 --file "$DATA/dolphin/view_properties/global/.directory" \
  --group Dolphin --key ViewMode 1
kwriteconfig6 --file "$DATA/dolphin/view_properties/global/.directory" \
  --group Dolphin --key Version 4

echo "  explorer -> one band, two columns, rows not tiles"
