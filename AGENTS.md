# Instructions for an agent installing naiture

This repo themes a **live KDE Plasma 6 desktop**. Running the installer changes
the machine the user is sitting in front of. Read this before acting.

## Install

```bash
./scripts/preflight.sh          # required tools present? exits 1 if not
./install.sh                    # or: ./install.sh --islands
./verify.sh --json              # exits 0 only if everything applied
```

From nothing, in one command:

```bash
curl -fsSL https://raw.githubusercontent.com/toladner/nAIture-os/main/bootstrap.sh | bash
```

`bootstrap.sh` clones to `~/.local/share/nAIture-os`, runs preflight, installs,
and verifies. It passes its arguments through, so `bash -s -- --islands` works.

Everything is non-interactive and idempotent. Nothing needs root.

## Flags

| Flag | Effect |
|---|---|
| `--islands` | **Destructive to the panel layout.** Deletes all panels and builds the design's two: a centred launcher+tasks island and a right-hand tray+clock island. Ask the user before using it. |
| `--no-fonts` | Skip the ~1.1 MB font download |
| `--no-apply` | Write assets and config, leave the running session alone |
| `--size WxH` | Wallpaper size; defaults to the detected screen |

## Verifying

`./verify.sh --json` prints `{"ok": bool, "checks": {name: {state, detail}}}`
and exits non-zero if any check is `fail`. Use it to confirm rather than
assuming the install worked. `state` is `ok`, `warn` (not counted as failure) or
`fail`.

Do **not** verify by screenshot without a reason to. If you do need one, check
`loginctl show-session <id> -p LockedHint` first — a locked session screenshots
the lock screen, not the desktop, which looks like a failed install but is not.

## Rolling back

```bash
./uninstall.sh                  # add --keep-fonts to keep the typefaces
```

The first install snapshots `kdeglobals`, `kwinrc`, `plasmarc`, `konsolerc`,
`breezerc` and the panel config to `~/.config/naiture/backup`, and records which
of those did not exist so uninstall can delete rather than restore them.
Re-running install never overwrites that snapshot. The panel *layout* is not
rebuilt automatically; uninstall prints the two commands that do it.

## Window corners need Klassy

Nothing in stock Plasma clips a window to a radius.
`scripts/window-decoration.sh` configures Klassy when it is installed and falls
back to borderless Breeze when it is not, so the installer is safe either way.

On Fedora, Klassy comes from the `major-tom/klassy` COPR and is built against a
specific Plasma major version — installing a Klassy newer than the running
desktop pulls in a **full Plasma upgrade** as dependencies. Check
`plasmashell --version` against the Klassy build before installing, and tell the
user what the transaction will actually do.

**Klassy splits its settings across config groups.** Not one `[Windeco]`
section: `[Windeco]` (corner radius, button shape, icon style),
`[TitleBarOpacity]` (titlebar opacity and its Override flags),
`[TitleBarSpacing]` (title alignment, titlebar margins), `[ButtonColors]`
(icon/background colours and opacities), `[ButtonBehaviour]` (the Show*
visibility keys), `[ButtonSizing]` (button spacing), `[WindowOutlineStyle]`.
A key written to the wrong group is accepted and silently ignored. The
authoritative mapping is `libbreezecommon/breezesettingsdata.kcfg` in the
Klassy source — read it rather than guessing:

```bash
curl -fsSL https://raw.githubusercontent.com/paulmcauley/klassy/master/libbreezecommon/breezesettingsdata.kcfg
```

Entries written as `Name$(NameActive)` expand to `NameActive` / `NameInactive`.

**Write Klassy settings with `kwriteconfig6 --notify`.** Klassy reloads through
`KConfigWatcher`, which only fires for writes carrying KDE's change
notification. Without `--notify` the file ends up correct and the decoration
never re-reads it, which is indistinguishable from the setting having no effect
— and `qdbus-qt6 org.kde.KWin /KWin reconfigure` does **not** cover it, though
it does apply the plugin/border keys in `kwinrc`. This cost hours: with the
right groups and the right values, nothing rendered until the writes were
notified.

**Klassy reads `~/.config/klassy/klassyrc`.** Not `~/.config/klassyrc` — that
path is accepted and silently ignored, which looks exactly like the corner
radius having no effect. Confirm what KWin actually loaded with
`qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.supportInformation | grep -A3 Decoration`
before concluding anything about the settings. `RoundAllCornersWhenNoBorders`
must be true or a borderless window keeps square corners.

**Never run a package transaction as a child of a tool call.** A timeout or a
session teardown kills it mid-write and leaves duplicate, half-installed
packages — recoverable only with `dnf remove --duplicates`. Detach it:

```bash
pkexec bash -c 'setsid nohup dnf install -y <pkg> > /tmp/log 2>&1 < /dev/null &'
```

then poll the log. Match the real process (`pgrep -f 'dnf install'`); `pgrep -x
dnf` does not match and will report success while the transaction is still
running.

## The accent is one setting

`./scripts/accent.sh [role|#hex]` is the only place a colour is chosen; it
defaults to the design's gold. It writes **two** things, and writing one without
the other leaves half the desktop the old colour:

* `kdeglobals [General] AccentColor` — applications and the window decoration
* the Naiture colour scheme **and the desktop theme's own `colors` file** —
  plasmashell resolves `Kirigami.Theme.highlightColor` from the desktop theme's
  copy, not from kdeglobals, so the quick-settings sheet, the focused task's bar
  and Plasma's applet indicator all read that one.

Nothing else may hard-code an accent. In SVGs, paint `fill="currentColor"` with
`class="ColorScheme-Highlight"` and ship a `<style id="current-color-scheme">`
block; KSvg swaps that block for the running scheme's colours. In QML, read
`Kirigami.Theme.highlightColor`.

## KSvg renders slices by id — anything unnamed is invisible

A 9-slice SVG is drawn one element at a time, looked up by id. A hairline or an
accent bar written as a *sibling* of the slice it belongs to is simply never
drawn, with no warning. Every slice in `tools/make_*_svg.py` is therefore a
`<g id="…">` holding its fill, its share of the hairline and anything else that
belongs to it — see `tools/nineslice.py`.

The `hint-*-margin` elements are the frame's content inset, and they also cap
how large a corner is drawn: a 2px hint on a 20px radius rounds the corner off
to 2px. Keep the hints at least as large as the radius.

`plasmashell` and KWin both cache theme SVGs. After changing one:

```bash
rm -f ~/.cache/plasma_theme_*.kcache
rm -rf ~/.cache/plasmashell ~/.cache/ksvg-elements
systemctl --user restart plasma-plasmashell
```

## The islands

`scripts/panel-style.sh` writes panel geometry, and the keys are split across
two groups of `plasmashellrc` — `[PlasmaViews][Panel <id>]` for alignment,
floating, `panelOpacity`, `panelLengthMode` and `panelVisibility`, but
`[PlasmaViews][Panel <id>][Defaults]` for `thickness`. `PanelView::setThickness`
reads thickness from the Defaults group and never looks at the parent, so a
thickness in the obvious place is silently ignored.

`panelVisibility=3` (WindowsGoBelow) is what lets a maximised window run the
full height of the screen underneath the islands.

The **system tray is a nested containment**, so its settings live in
`[Containments][C][Applets][A][General]`, not the `[Configuration][General]`
every ordinary applet uses. Plasma writing its own `extraItems`/`knownItems`
there is the proof. Application tray icons are StatusNotifierItems, hidden by
their own id rather than a plugin id — ask
`org.kde.StatusNotifierWatcher` for the running ones rather than guessing.

Task icon size follows from the panel background's margins: the task manager
sizes its icon to the height it is given. Change `MARGIN` in
`tools/make_panel_svg.py`, not the applet.

## KWin scripts

`kwin/naiture-dock` fades the centre island, because Plasma has no hover state
for a panel. Three things to know:

* A **declarative** script reaches the workspace through the `Workspace`
  singleton of `org.kde.kwin` and enumerates with the `windows` property; a
  **plain-javascript** script gets a lowercase `workspace` and `windowList()`.
  Each spelling is undefined in the other flavour.
* Panels are layer-shell surfaces but do appear in the window list as `dock`
  windows owned by plasmashell, and their `opacity` is writable.
* KWin's QML engine caches a component **by URL for the life of the process**
  and never re-reads the file, so re-installing in the same session keeps
  running the old code. `scripts/dock-proximity.sh` works around it by loading
  the repo copy for the current session; a fresh login uses the installed one.

## The three applets

`plasmoids/org.naiture.quicksettings` is the time pill and the design's
quick-settings sheet — Wi-Fi, Bluetooth, sound, do not disturb, aeroplane mode,
night light, and volume and brightness sliders, each driving the real thing
through the same APIs Plasma's own applets use. It exists because Plasma's
system tray always shows an expander chevron beside the clock when anything is
hidden, and its popup is Plasma's list rather than the design's sheet.

Its sheet is **not** Plasma's applet popup. On 6.7 that window paints an opaque
background of its own: the theme's `dialogs/background.svg` is never consulted
for it (swap that file for solid magenta and nothing changes), and
`Plasmoid.backgroundHints: NoBackground` does not stop it either, so a rounded
rectangle drawn inside only puts fake corners in a square box. A
`PlasmaCore.Dialog` does honour `NoBackground`, so the sheet lives in one and
`Plasmoid.expanded` is never used. Three things follow:

* The dialog sizes itself from `mainItem`'s **implicit** size and assigns the
  real one back, so the item must not set its own width and height — and the
  content inside must not be anchored to it either, or the implicit height is a
  loop and the dialog comes out at its default 400x300.
* `compactRepresentationItem` is null for an applet that never sets
  `Plasmoid.expanded`, so the dialog's `visualParent` is the applet itself.
* Plasma's "this applet is open" accent bar rides on `Plasmoid.expanded`, so
  the pill draws that bar itself.

**The island cannot reach the screen's corner.** Plasma insets an applet from
the panel edge by the theme background's `hint-*-margin` *plus* about 8px of its
own — paint an applet solid and read off where it ends — and no theme setting
reaches the remainder. `tools/make_panel_svg.py` therefore keeps `SIDE_MARGIN`
as small as the rounded corner allows. Applets are **not clipped**, though, so a
child may be given a negative margin to reach back out to the island's edge —
that is how the clock's accent bar sits on the island's top rather than 7px
inside it.

`scripts/screen-edges.sh` quiets both screen corners, because an action that
fires on a shove of the pointer is easy to trigger by accident with the island's
controls down there.

`plasmoids/org.naiture.dock` replaces Plasma's task manager, for three reasons
that are all unreachable from outside it:

* The icon greys on hover. `taskmanager/qml/Task.qml` binds
  `Kirigami.Icon.active` to `highlighted`, which is plain `containsMouse`, and
  Kirigami feeds that into its icon shader as a hardcoded `0.7` highlight
  (`kirigami/src/primitives/icon.cpp`). `taskHoverEffect` gates only the frame
  behind the icon. No config, theme or SVG reaches the uniform.
* Icons cannot grow under the pointer — each is sized to the panel with no
  scale to animate.
* The active marker is a 9-slice frame swapped per tile, so it can only blink
  in and out. It cannot travel between tiles, nor leave one to sit on the
  island's edge.

Everything else still comes from Plasma: `org.kde.taskmanager` is the public QML
module behind Plasma's own task manager, so the window list, the filtering and
every request are its code. What this applet owns is only how a task looks and
moves.

Hovering shows live thumbnails rather than the app's name. On Wayland there is
no window pixmap to borrow: a thumbnail is a screencast, requested per window
through `TaskManager.ScreencastingRequest` and rendered by
`PipeWire.PipeWireSourceItem` — the pair Plasma's own tooltip uses
(`taskmanager/qml/PipeWireThumbnail.qml`). The requests exist only while the
preview is up.

Grouping is on, so a tile can stand for several windows; a group parent's
`WinIdList` carries every one of them, and each gets its own thumbnail. Clicking
one raises that window: a group's windows are *children* of its row, so it is
`makeModelIndex(row, child)` for one of several and `makeModelIndex(row)` for a
lone window.

Hovering a thumbnail brings that window forward on the desktop — Windows' peek
— through KWin's HighlightWindow effect, the same call Plasma's own task
manager makes for its tooltips: `highlightWindows` on
`/org/kde/KWin/HighlightWindow` with the windows to raise, or an empty list to
let go. Every path that closes the preview has to let go, or the desktop stays
dimmed around a window nobody is pointing at.

The preview lags the pointer on the way out — a short hide timer that the
preview's own hover cancels — because a thumbnail you cannot walk onto cannot be
clicked. Its size is worked out on the applet rather than from the card inside
it, for the same reason the quick-settings sheet's is: the dialog reads
`mainItem`'s implicit size early and keeps what it first gets.

An icon lifts from its own baseline, so its resting size is chosen *backwards*
from the room available — the island's content height plus what is left of the
margin once the marker and a little daylight are taken out. Size the icon to the
content height instead and it climbs into the marker on hover.

`plasmoids/org.naiture.showdesktop` is the sliver at the screen's corner that
peeks at the desktop. It is a separate applet on purpose: Plasma draws its
"this applet's popup is open" accent bar across the whole applet, so folding the
sliver into the clock would stretch that bar past the time.

A panel applet's **size hints belong on the `PlasmoidItem`, not on the
representation**, and an applet that shows itself inline uses
`fullRepresentation`. Get either wrong and Plasma answers with its own default:
size hints in the wrong place reserve about 40px and draw nothing in it, and a
`compactRepresentation` with no `fullRepresentation` to collapse from is
replaced by a placeholder icon that does nothing when clicked. Both applets here
are inline; Plasma's own panel spacer is the model.

## Things that will trip you up

**`sudo` may have no TTY.** In non-interactive shells `sudo` fails with "a
terminal is required to read the password". Use `pkexec <command>` where a
polkit agent is running, or ask the user to run it in a real terminal. Nothing
in this repo needs root, so this only matters for installing prerequisites.

**Interactive logins can't be driven.** `gh auth login` and similar need a real
terminal. Ask the user; driving them over a pty gets the process killed.

**Panel geometry is not in the applets file.** This is the single easiest thing
to get wrong here. `plasma-org.kde.plasma.desktop-appletsrc` holds a panel's
applets and its `location`; `thickness`, `alignment`, `panelLengthMode`,
`panelOpacity` and `floating` live in **`~/.config/plasmashellrc`** under
`[PlasmaViews][Panel <id>]`. Writing them into the containment does nothing at
all, silently.

**plasmashell rewrites its config on exit**, so it must be *stopped* while those
keys are written — restarting afterwards is not enough, the old values come
back. `scripts/panel-style.sh` does stop / write / start in that order.

**The scripting API only half-works for panels.** `evaluateScript` persists
panel creation, removal and `location`, and `floating`; `height`, `lengthMode`,
`alignment` and `opacityMode` are accepted and silently dropped. It always
returns an empty string, so the return value tells you nothing. Applet config
written through `widgetById(...).writeConfig()` also did not stick — write it
into the applets file instead, while the shell is stopped.

**Testing safely.** Point `XDG_CONFIG_HOME` and `XDG_DATA_HOME` at a temp
directory and pass `--no-apply`; that exercises the whole installer without
touching the live session:

```bash
XDG_CONFIG_HOME=/tmp/t/config XDG_DATA_HOME=/tmp/t/data ./install.sh --no-apply --no-fonts
```

## Where things are

`palette/naiture.json` holds the design tokens in OKLCH with sRGB alongside;
`tools/oklch.py` converts. If you change a colour, change it there first, then
propagate to `color-schemes/Naiture.colors`, `desktoptheme/naiture/colors` and
`konsole/Naiture.colorscheme`, which all carry sRGB triples.
`docs/design-mapping.md` traces every design token to the setting it became.
