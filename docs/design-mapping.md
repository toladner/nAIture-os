# From canvas to Plasma

How each part of the naiture design canvas is expressed in KDE Plasma 6.
Useful when adjusting the theme: change the design token, then the setting it
maps to.

## Backdrop

| Design | Plasma |
|---|---|
| `linear-gradient(174deg, …)` across five OKLCH stops | interpolated in OKLCH by `tools/make_wallpaper.py`, baked into the wallpaper PNG |
| gold radial glow, `blur(70px)`, 42% | `paste_glow(GOLD, …)` |
| moss radial glow, `blur(80px)`, 45% | `paste_glow(MOSS, …)` |
| mist band, `blur(34px)`, 30% | `paste_glow(MIST, …)` |
| 340px bottom scrim at 92% | `horizon_fade()` |
| 44 swaying blades from a `sin` hash | `blades()` — the same hash, so the silhouette matches exactly |
| 80px hairline grid at 2.2% | `grid()` |

The canvas animates the glows and blades. A wallpaper cannot, so they are baked
at their rest position.

## Windows

| Design | Plasma |
|---|---|
| `rgba(13,24,17,0.7)` body | `Colors:Window BackgroundNormal=13,24,17` — Plasma composites opacity itself |
| `backdrop-filter: blur(40px) saturate(170%)` | `kwinrc` blur effect (strength 12) + background contrast; `saturation=1.7` in the theme's `plasmarc` |
| `1px solid rgba(255,255,255,0.18)` | Breeze's own hairline; borders set to `None` so nothing heavier is drawn |
| `border-radius: 22px` | **not reproducible** with stock Breeze — see the README |
| `0 50px 110px -40px rgba(0,0,0,0.88)` | `breezerc` `ShadowSize=ShadowVeryLarge`, `ShadowStrength=240` |
| focused vs unfocused opacity (0.70 / 0.60) | `Colors:Header` vs `Colors:Header][Inactive` |

## Islands

The design's docks are two rounded, translucent bars pinned to the bottom edge:
a centred switcher and a right-hand clock, both 50px tall, `blur(36px)`,
opaque-dark when a window is maximised behind them.

| Design | Plasma |
|---|---|
| 50px height | `thickness=50` |
| fits its contents | `panelLengthMode=1` |
| lifted off the edge, rounded | `floating=true` |
| translucent, but opaque behind a maximised window | `panelOpacity=0` (adaptive) |
| centred / right | `alignment=132` / `alignment=2` |

These keys live in `[Containments][N][General]` of
`plasma-org.kde.plasma.desktop-appletsrc`. Note that plasmashell's scripting API
exposes the same properties on its `Panel` object but does **not** persist them
on 6.6, which is why `scripts/panel-style.sh` writes the config directly and
restarts the shell. Panel *creation* through the scripting API does work, so
`scripts/panel-islands.js` handles that half of `--islands`.

## Accents

The design uses three tints plus a close-red. They map onto Plasma's semantic
colour roles:

| Design token | Plasma role |
|---|---|
| sky `#6abfd9` | accent, `DecorationFocus`, selection, links |
| moss `#5ebc7b` | `ForegroundPositive` |
| gold `#decc60` | `ForegroundNeutral` |
| ember `#f2716a` | `ForegroundNegative` |

Plasma re-derives the selection background from the accent for contrast, so the
applied value is a slightly darker sky than the token — that is Plasma being
careful about text legibility, not a mismatch.

## Type

`Archivo` at 10pt for everything in the shell and applications, 600 weight for
window titles (the design sets `font-weight: 600` on its title strip),
`JetBrains Mono` at 10pt for fixed-width. Both are variable fonts installed
per-user by `fonts/install-fonts.sh`.
