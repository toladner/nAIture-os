# Using naiture

Everything the README is too short for.

## Flags

| Flag | Effect |
|---|---|
| `--islands` | Replace the panel layout with the design's two bottom islands: a centred switcher (launcher + tasks) and a right-hand time island (tray + clock). Destructive to your current panel layout — the backup has the original. |
| `--no-fonts` | Skip downloading Archivo / JetBrains Mono |
| `--no-apply` | Write everything, change nothing in the running session |
| `--size WxH` | Render the wallpaper at a specific size instead of your screen's |

Applying the panel geometry restarts `plasmashell` — your windows are not
affected, the panel just blinks.

## Checking it worked

```bash
./verify.sh          # human-readable
./verify.sh --json   # {"ok": bool, "checks": {...}}, exit 1 on any failure
```

## Uninstall

```bash
./uninstall.sh            # also removes the fonts
./uninstall.sh --keep-fonts
```

This restores the snapshot taken at first install. The panel *layout* is not
rebuilt automatically — if you used `--islands`, the uninstaller prints the two
commands that put your old panels back.

## The accent

One command moves every accented thing on the desktop — applications, the
window decoration, the shell, the focused task's bar, and the mark itself:

```bash
./scripts/accent.sh              # the gold naiture ships
./scripts/accent.sh sky          # the design's own reading
./scripts/accent.sh '#decc60'    # or a literal
```

## The palette

Everything derives from `palette/naiture.json`, which keeps the design's
original OKLCH values alongside the sRGB the config formats need.
`tools/oklch.py` does the conversion.

| Role | OKLCH | sRGB |
|---|---|---|
| gold (accent as shipped) | `0.84 0.13 100` | `#decc60` |
| sky (the design's accent) | `0.76 0.09 220` | `#6abfd9` |
| moss (positive) | `0.72 0.13 152` | `#5ebc7b` |
| ember (negative) | `0.70 0.16 25` | `#f2716a` |
| window surface | — | `#0d1811` |
| view surface | — | `#081109` |
| text | — | `#f2f7f2` |

## Regenerating the artwork

```bash
python3 tools/make_wallpaper.py -o out.png -W 3440 -H 1440
python3 tools/make_scene.py -o scenes/ -n 12 --contact-sheet sheet.jpg
```

Both need Pillow. The wallpaper's blade field comes from the same `sin`-hash
the design uses, so the silhouette is identical at every size; `--no-blades`
and `--no-grid` give a plain gradient.

`make_scene.py` renders the views the console's tabs look out on — the same
world, from other windows of the house. A scene is seeded by its number, so
scene 5 is the same picture every time it is drawn, which is why the console
can throw them away at logout and get them back identically at the next login.

## What this deliberately does not do

* **Window corners need Klassy.** Nothing in stock Plasma clips a window to a
  radius. `install.sh` configures [Klassy](https://github.com/paulmcauley/klassy)
  when it is present and falls back to borderless Breeze when it is not. On
  Fedora it comes from a COPR, and it needs a Plasma of the same major version
  as your desktop:

  ```bash
  sudo dnf copr enable -y major-tom/klassy && sudo dnf install -y klassy
  ```

* **Window bodies are opaque.** The design's are `rgba(13,24,17,0.70)`. Forcing
  it was tried and dropped: KWin fades the whole window, text included, rather
  than just the background, and overlapping windows became hard to read.
  `scripts/window-glass.sh` is kept for anyone who wants it and is not run by
  the installer:

  ```bash
  ./scripts/window-glass.sh          # translucent windows
  ./scripts/window-glass.sh --off    # back to opaque
  ```

  The console gets its depth a different way — a painted view rather than
  transparency — so that it looks the same over the desktop and over another
  window. See CONTRIBUTING.md.

* **Tabs cannot share the titlebar's line.** Konsole draws no client-side
  decoration, so the window's buttons stay on the titlebar and the tabs sit
  directly beneath it. The menu does make it up there, as the decoration's
  application-menu button.

* **GTK apps.** Firefox, GNOME apps and Flatpaks keep their own theme.

* **Only a close button.** The design has no window controls at all; this keeps
  a single small close X, which shows nothing but its glyph until hovered and
  then takes the ember tint. To get minimise and maximise back:

  ```bash
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration3 --key ButtonsOnRight IAX
  ```

* **Login and boot.** SDDM, the Plasma splash and GRUB are untouched.

## Layout

```
bootstrap.sh       one-command install: clone, preflight, install, verify
install.sh         the installer
uninstall.sh       restore the pre-naiture snapshot
verify.sh          assert the theme is applied
AGENTS.md          how to drive this repo from an AI agent
CONTRIBUTING.md    the design principles, and how to work on this safely
color-schemes/     Plasma colour scheme
desktoptheme/      Plasma shell theme (colours + contrast effect)
wallpapers/        KPackage wallpaper, pre-rendered at three sizes
konsole/           the console's colour scheme, profiles and view helper
plasmoids/         the dock, the quick-settings pill, the show-desktop sliver
kwin/              the KWin script that fades the centre island
fonts/             per-user font installer
tools/             OKLCH conversion, wallpaper and scene renderers
scripts/           preflight, panel styling, the islands, the console window
design/            the source design canvas, extracted from the artifact
palette/           the design tokens, OKLCH + sRGB
```
