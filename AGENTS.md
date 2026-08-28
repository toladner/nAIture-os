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

## Things that will trip you up

**`sudo` may have no TTY.** In non-interactive shells `sudo` fails with "a
terminal is required to read the password". Use `pkexec <command>` where a
polkit agent is running, or ask the user to run it in a real terminal. Nothing
in this repo needs root, so this only matters for installing prerequisites.

**Interactive logins can't be driven.** `gh auth login` and similar need a real
terminal. Ask the user; driving them over a pty gets the process killed.

**plasmashell drops Panel geometry set from its scripting API.** On Plasma 6.6,
`evaluateScript` accepts `panel.height`, `.floating`, `.lengthMode` and silently
does not persist them, and it always returns an empty string, so you cannot tell
success from the return value. Panel *creation* and *removal* do persist.
`scripts/panel-style.sh` therefore writes `thickness`, `panelLengthMode`,
`panelOpacity`, `floating` and `alignment` into
`[Containments][N][General]` of `plasma-org.kde.plasma.desktop-appletsrc` and
restarts the shell. Do not "fix" this back to the scripting API.

**Panel changes need the shell restarted.** plasmashell caches containment
config and rewrites the file on exit, so editing the config without restarting
gets your edit overwritten.

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
