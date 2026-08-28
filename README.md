# naiture

A KDE Plasma 6 theme built from the *naiture* design canvas — an AI-first
desktop concept of teal dusk over a moss field, glass windows and floating
islands instead of a taskbar.

Built and tested on **Fedora 44, Plasma 6.6.4, Wayland**.

![the naiture wallpaper](wallpapers/naiture/contents/screenshot.png)

## What it changes

| Piece | What you get |
|---|---|
| Colour scheme | `Naiture` — near-black moss surfaces, sky-blue accent, moss/gold/ember semantics |
| Plasma theme | `naiture` — same palette for the shell, with background-contrast at the design's `saturate(170%)` |
| Wallpaper | Generated from the design's own gradient, glows, mist band and 44-blade grass field, at your screen's resolution |
| Panels | Floating, fit-to-content, 50px islands with adaptive translucency |
| Windows | 22px rounded corners via Klassy, blur + background contrast, no app icon and no window buttons as in the design. Window bodies are still opaque — see below. |
| Fonts | Archivo for the UI, JetBrains Mono for anything fixed-width |
| Konsole | `Naiture` profile and colour scheme, 82% opacity with blur |

## Install

One command, no root:

```bash
curl -fsSL https://raw.githubusercontent.com/toladner/nAIture-os/main/bootstrap.sh | bash
```

Add `bash -s -- --islands` to get the two-island panel layout as well.

If you would rather read the script before running it — reasonable — do it in
two steps:

```bash
git clone https://github.com/toladner/nAIture-os.git
cd nAIture-os
./scripts/preflight.sh    # what's missing, and the command to get it
./install.sh
./verify.sh               # exits 0 only if everything applied
```

The first run snapshots `kdeglobals`, `kwinrc`, `plasmarc`, `konsolerc`,
`breezerc` and the panel config into `~/.config/naiture/backup` before touching
anything. Re-running never overwrites that snapshot.

Applying the panel geometry restarts `plasmashell` — your windows are not
affected, the panel just blinks.

### Options

| Flag | Effect |
|---|---|
| `--islands` | Replace the panel layout with the design's two bottom islands: a centred switcher (launcher + tasks) and a right-hand time island (tray + clock). Destructive to your current panel layout — the backup has the original. |
| `--no-fonts` | Skip downloading Archivo / JetBrains Mono |
| `--no-apply` | Write everything, change nothing in the running session |
| `--size WxH` | Render the wallpaper at a specific size instead of your screen's |

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

## The palette

Everything derives from `palette/naiture.json`, which keeps the design's
original OKLCH values alongside the sRGB the config formats need.
`tools/oklch.py` does the conversion.

| Role | OKLCH | sRGB |
|---|---|---|
| sky (accent) | `0.76 0.09 220` | `#6abfd9` |
| sky bright | `0.80 0.09 220` | `#77cce6` |
| moss (positive) | `0.72 0.13 152` | `#5ebc7b` |
| gold (neutral) | `0.84 0.13 100` | `#decc60` |
| ember (negative) | `0.70 0.16 25` | `#f2716a` |
| window surface | — | `#0d1811` |
| view surface | — | `#081109` |
| text | — | `#f2f7f2` |

## Regenerating the wallpaper

```bash
python3 tools/make_wallpaper.py -o out.png -W 3440 -H 1440
```

Needs Pillow. The blade field comes from the same `sin`-hash the design uses, so
the silhouette is identical at every size. `--no-blades` and `--no-grid` give you
a plain gradient.

## What this does not do

* **Window corners need Klassy.** Nothing in stock Plasma clips a window to a
  radius. `install.sh` configures [Klassy](https://github.com/paulmcauley/klassy)
  when it is present and falls back to borderless Breeze when it is not. On
  Fedora it comes from a COPR, and it needs a Plasma of the same major version
  as your desktop:

  ```bash
  sudo dnf copr enable -y major-tom/klassy && sudo dnf install -y klassy
  ```

* **The dock's hover fade.** The design's switcher is nearly transparent at rest
  and solidifies on hover. Plasma panels have no hover opacity, so the island
  sits at the resting film all the time.
* **Window bodies are not glass yet.** The design's windows are
  `rgba(13,24,17,0.70)` throughout. The body is painted by the widget style, and
  Breeze paints it opaque; KWin's translucency effect only touches inactive
  windows. Konsole is translucent because its own profile sets it. Closing this
  properly needs a Kvantum theme authored in the naiture palette.

* **GTK apps.** Firefox, GNOME apps and Flatpaks keep their own theme.

* **No window buttons.** The design has none, so neither does this. Close a
  window with Alt+F4, or right-click its titlebar. To get them back:
  `kwriteconfig6 --file kwinrc --group org.kde.kdecoration3 --key ButtonsOnRight IAX`
* **Login and boot.** SDDM, the Plasma splash and GRUB are untouched.

## Layout

```
bootstrap.sh       one-command install: clone, preflight, install, verify
install.sh         the installer
uninstall.sh       restore the pre-naiture snapshot
verify.sh          assert the theme is applied
AGENTS.md          how to drive this repo from an AI agent
color-schemes/     Plasma colour scheme
desktoptheme/      Plasma shell theme (colours + contrast effect)
wallpapers/        KPackage wallpaper, pre-rendered at three sizes
konsole/           Konsole colour scheme and profile
fonts/             per-user font installer
tools/             OKLCH conversion, wallpaper renderer
scripts/           preflight check, panel styling, the islands layout
design/            the source design canvas, extracted from the artifact
palette/           the design tokens, OKLCH + sRGB
```

## Credit

Design: the *naiture* canvas made in Claude Design.
Typefaces: [Archivo](https://fonts.google.com/specimen/Archivo) and
[JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono), both SIL OFL.
