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

## The two applets

`plasmoids/org.naiture.quicksettings` is the time pill and the design's
quick-settings sheet — Wi-Fi, Bluetooth, sound, do not disturb, aeroplane mode,
night light, and volume and brightness sliders, each driving the real thing
through the same APIs Plasma's own applets use. It exists because Plasma's
system tray always shows an expander chevron beside the clock when anything is
hidden, and its popup is Plasma's list rather than the design's sheet.

Its popup takes the design's width and padding but not its 20px radius. On
Plasma 6.7 the popup **window** paints its own background: the theme's
`dialogs/background.svg` is not consulted for an applet popup (replacing that
file with a solid magenta proves it), and
`Plasmoid.backgroundHints: NoBackground` does not stop it either. Drawing a
rounded rectangle inside only puts fake corners in a square box, which is what
it looked like. The shape, the shadow and the base colour come from the popup
and the colour scheme.

`plasmoids/org.naiture.showdesktop` is the sliver at the screen's corner that
peeks at the desktop. It is a separate applet on purpose: Plasma draws its
"this applet's popup is open" accent bar across the whole applet, so folding the
sliver into the clock would stretch that bar past the time.

A panel applet's **size hints belong on the `PlasmoidItem`, not on the
representation**, and an applet with no popup shows its `fullRepresentation`
inline. Get either wrong and the panel silently reserves its own default width —
about 40px — and draws nothing in it. Plasma's own panel spacer is the model.

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
