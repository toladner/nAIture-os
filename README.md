# naiture

A KDE Plasma 6 theme. Teal dusk over a moss field, floating islands instead of
a taskbar, and windows that look out on the weather.

Built and tested on **Fedora 44, Plasma 6.7, Wayland**. Nothing needs root.

![the naiture wallpaper](wallpapers/naiture/contents/screenshot.png)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/toladner/nAIture-os/main/bootstrap.sh | bash
```

Add `bash -s -- --islands` to replace the panel layout with the design's two
bottom islands. Or, to read the scripts first — reasonable:

```bash
git clone https://github.com/toladner/nAIture-os.git && cd nAIture-os
./scripts/preflight.sh    # what's missing, and the command to get it
./install.sh
./verify.sh               # exits 0 only if everything applied
```

The first run snapshots your Plasma config to `~/.config/naiture/backup` before
touching anything, and `./uninstall.sh` puts it back.

## What you get

* A generated wallpaper at your screen's resolution — gradient, glows, mist and
  a 44-blade grass field, all from the design's own maths
* Two floating islands: a launcher with live window previews and a start sheet,
  and a time pill with a quick-settings sheet
* Rounded, borderless windows (via [Klassy](https://github.com/paulmcauley/klassy))
  with the menu on the titlebar and no controls but close
* A console whose tabs are the only chrome, each looking out on its own view
* Archivo and JetBrains Mono, and one accent colour that moves everything:
  `./scripts/accent.sh gold`

## More

| | |
|---|---|
| [docs/using.md](docs/using.md) | flags, verifying, the palette, what it deliberately does not do |
| [CONTRIBUTING.md](CONTRIBUTING.md) | the design principles, and how to work on this safely |
| [docs/design-mapping.md](docs/design-mapping.md) | every design token, and the setting it became |
| [AGENTS.md](AGENTS.md) | everything an agent needs to drive this repo |

Design: the *naiture* canvas, made in Claude Design.
Typefaces: [Archivo](https://fonts.google.com/specimen/Archivo) and
[JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono), both SIL OFL.
