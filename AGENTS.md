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

**Some settings still do not apply from a config edit.** With correct groups and
values that persist in the file, `ButtonIconOpacityActive` and the titlebar
opacity Override flags produced no rendered change after
`qdbus-qt6 org.kde.KWin /KWin reconfigure`. Klassy also rewrites klassyrc itself
(it re-adds `[Global] LookAndFeelSet` immediately after deletion), so it manages
this file rather than merely reading it. For those settings, have the user apply
them once in `klassy-settings` and diff the file to learn what actually changes.

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
