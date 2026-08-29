# Working on naiture

This repo themes a **live desktop**. Running the installer changes the machine
you are sitting in front of, so read [AGENTS.md](AGENTS.md) before touching
anything — it is the list of things that silently do nothing, and it is long
because each entry cost somebody an afternoon.

## The design principles

These are what every surface is judged against, and what the next one should be
built from.

**1. The content is the title.** No window says what it is in a bar at the top;
its content already does. A label that repeats the content is chrome.

**2. One band, not a stack.** Everything that is not content shares a single
line at the top of a window — tabs, the menu, the window's own buttons. A
second row of chrome is a failure, not a feature.

**3. The frequent thing is visible; the rest is one press away.** Split, copy,
paste and find have keys already, so they live in a menu. Same rule put the cog
and the power icon behind two glyphs in the start sheet, and each quick setting's
real control panel behind a chevron.

**4. Nothing borrows its look from what is behind it.** Translucency makes a
surface's appearance a function of whatever it happens to land on, which is why
the console looked right over the desktop and wrong over a browser. Paint the
colour in instead. (The islands are the deliberate exception: a panel *is* a
film over the desktop, and its fade is information about what is behind it.)

**5. Every window is a window.** The desktop is a house carried along under
balloons, and each tab looks out of a different side of it — a different sun, a
different green, sometimes a ridge a long way off.

**6. The view is weather, not a picture.** Blurred, low-contrast, no
recognisable edge. You should read it as light in the room and be unable to
describe it after an hour. The moment it competes with the content it is wrong.

**7. A view arrives with its tab.** Nothing waits for scenery. If it cannot be
ready in the time it takes a window to open, it does not ship.

**8. A scene is derived, not drawn.** It comes from the palette plus a seed, so
`accent.sh` moves the weather with everything else, and a future theme is a
different generator behind the same signature — never a folder of images.

**9. One setting chooses the colour.** `scripts/accent.sh` is the only place an
accent is picked. Nothing else may hard-code one: in SVG use
`class="ColorScheme-Highlight"` with a `<style id="current-color-scheme">`
block, and in QML read `Kirigami.Theme.highlightColor`. A surface that marks
"this one" at all times — a tab strip does — should use no accent at all, since
an accent that is always on stops meaning anything.

## Changing a colour

`palette/naiture.json` first, in OKLCH. Then propagate to the files that carry
sRGB triples: `color-schemes/Naiture.colors`, `desktoptheme/naiture/colors` and
`konsole/Naiture.colorscheme`. `tools/oklch.py` does the conversion and
`docs/design-mapping.md` traces every token to the setting it became.

The two colour-scheme files are checked in **gold**, and `scripts/accent.sh`
rewrites them from gold into whatever is asked for — so if you edit them, change
the `SHIPPED` literals in that script in the same breath or the rewrite will
find nothing to replace.

## Testing without wrecking your session

Point the XDG directories at a temp directory and pass `--no-apply`. That
exercises the whole installer and touches nothing live:

```bash
XDG_CONFIG_HOME=/tmp/t/config XDG_DATA_HOME=/tmp/t/data \
  ./install.sh --no-apply --no-fonts
```

`XDG_CONFIG_HOME` is the important half — `scripts/accent.sh` writes
`kdeglobals`, which lives there, so a test that redirects only `XDG_DATA_HOME`
will change the accent on your real desktop.

Then `./verify.sh --json` on the real session, which exits non-zero if anything
is half-applied. Prefer it to a screenshot; if you do need one, check that the
screen is not locked first, or you will photograph the lock screen and conclude
the install failed:

```bash
qdbus-qt6 org.kde.screensaver /ScreenSaver GetActive     # true = locked
```

## Commits

A title that says what changed for the person using the desktop, in a sentence,
not a category prefix — *The island only fades when there is something behind it
to see*. Then a body explaining **why**, and in particular which of the obvious
approaches did not work, because that is the part nobody can recover from the
diff. Commit each piece as it lands rather than in a heap at the end.
