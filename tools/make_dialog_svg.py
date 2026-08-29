#!/usr/bin/env python3
"""Generate the naiture dialog background.

Every Plasma popup — the quick-settings sheet, Kickoff, tooltips — is drawn from
`dialogs/background.svg` as a 9-slice (libplasma's BackgroundMetrics.qml asks
for exactly that path for an AppletPopup). Without one the theme falls back to
Breeze's, which is colour-scheme aware and so comes out the right colour with
the wrong shape: an 8px radius against a design that asks for 20px.

It is not what the naiture sheets are drawn from — those paint themselves in a
window that paints nothing, see plasmoids/*/contents/ui/Sheet.qml — but every
other Plasma popup on the desktop is drawn from it.

The design's sheet (design/naiture-canvas.dc.html):

    border-radius: 20px;
    background: rgba(13,24,17,0.85);
    border: 1px solid rgba(255,255,255,0.16);
    backdrop-filter: blur(40px) saturate(170%);
    padding: 20px 22px;

The blur is KWin's, granted to any window the theme marks translucent, so it is
the `translucent/` copy of this file that gets it; the `opaque/` copy is what
Plasma reaches for when compositing is off and has to stand on its own.

The padding is declared here rather than inside the plasmoid. KSvg reads the
`hint-*-margin` elements as the frame's content inset *and* draws each corner at
the margin size, so margins smaller than the radius round the corner off to the
margin — which is what a 2px hint did the first time round.
"""
import argparse
import os

from nineslice import (fill_path, fill_rect, group, hints, quarter_disc,
                       quarter_hairline, stroke)

R = 20             # corner size, also the radius
GAP = 4            # keeps slices from bleeding into each other

# The design's own sheet padding. Vertically it matches the radius exactly,
# which is also the smallest inset that lets the corner draw at full size.
MARGIN_Y = 20
MARGIN_X = 22

COLS = [0, R + GAP, 2 * (R + GAP)]
ROWS = COLS
W = COLS[2] + R
H = ROWS[2] + R

VARIANTS = {
    #  name:        (fill,      fill opacity, hairline opacity)
    "translucent": ("#0d1811", 0.94, 0.16),
    "opaque":      ("#0d1811", 1.00, 0.16),
}


def build(fill, opacity, hair):
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" version="1.1">',
         '  <title>naiture dialog background</title>']

    def rect(x, y):
        return fill_rect(x, y, R, R, fill, opacity)

    def corner(eid, cx, cy, which):
        x, y = COLS[cx], ROWS[cy]
        return group(eid, [
            fill_path(quarter_disc(x, y, R, which), fill, opacity),
            quarter_hairline(x, y, R, which, hair),
        ])

    o += corner("topleft", 0, 0, "topleft")
    o += group("top", [
        rect(COLS[1], ROWS[0]),
        stroke(f"M {COLS[1]},{ROWS[0] + 0.5} L {COLS[1] + R},{ROWS[0] + 0.5}", hair),
    ])
    o += corner("topright", 2, 0, "topright")

    o += group("left", [
        rect(COLS[0], ROWS[1]),
        stroke(f"M {COLS[0] + 0.5},{ROWS[1]} L {COLS[0] + 0.5},{ROWS[1] + R}", hair),
    ])
    o += group("center", [rect(COLS[1], ROWS[1])])
    o += group("right", [
        rect(COLS[2], ROWS[1]),
        stroke(f"M {COLS[2] + R - 0.5},{ROWS[1]} L {COLS[2] + R - 0.5},{ROWS[1] + R}", hair),
    ])

    o += corner("bottomleft", 0, 2, "bottomleft")
    o += group("bottom", [
        rect(COLS[1], ROWS[2]),
        stroke(f"M {COLS[1]},{ROWS[2] + R - 0.5} L {COLS[1] + R},{ROWS[2] + R - 0.5}", hair),
    ])
    o += corner("bottomright", 2, 2, "bottomright")

    o += hints("", COLS, ROWS, R, (MARGIN_Y, MARGIN_Y, MARGIN_X, MARGIN_X))
    o.append("</svg>")
    return "\n".join(o) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", "--theme-dir", required=True,
                    help="desktoptheme/naiture directory to write into")
    args = ap.parse_args()

    for name, (fill, opacity, hair) in VARIANTS.items():
        svg = build(fill, opacity, hair)
        for sub in ([name] if name != "translucent" else ["translucent", ""]):
            path = os.path.join(args.theme_dir, sub, "dialogs", "background.svg")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as fh:
                fh.write(svg)
            print(path)


if __name__ == "__main__":
    main()
