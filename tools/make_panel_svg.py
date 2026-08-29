#!/usr/bin/env python3
"""Generate the naiture panel background.

Plasma draws a panel from a 9-slice SVG. Each slice is looked up by element id
and rendered on its own, so every slice here is a group holding both its fill
and its share of the design's hairline — see tools/nineslice.py for why a bare
sibling path would never appear.

This writes the three variants Plasma looks for: the default and `translucent/`
(the design's glass film over the wallpaper) and `opaque/` (what it becomes
behind a maximised window).

The design's island is flush with the screen edge and rounded only along its
top, so the bottom corners here are square on purpose.
"""
import argparse
import os

from nineslice import (fill_path, fill_rect, group, hints, quarter_disc,
                       quarter_hairline, stroke)

TILE = 16          # corner size, also the top corner radius
GAP = 4            # keeps slices from bleeding into each other

# Applets are laid out inside the panel background's margins, so the margins are
# what decides how big a task icon gets: the task manager sizes its icon to the
# height it is given (taskmanager/qml/Task.qml sizes the icon to `task.height`).
# The design puts 34px tiles in a 50px dock and pads the dock 8px at the sides;
# the islands here run a little shorter than 50px so they clear the bottom of a
# terminal, and the padding is scaled with them to keep the ratio.
MARGIN = 7

# Sideways the islands want as little as possible: the right-hand one is flush
# with the screen and every pixel of padding is dead space between the last
# control and the edge. Plasma keeps about 8px of its own beyond this, so this
# is only part of the gap.
SIDE_MARGIN = 2

COLS = [0, TILE + GAP, 2 * (TILE + GAP)]
ROWS = COLS
W = COLS[2] + TILE
H = ROWS[2] + TILE

VARIANTS = {
    # name:        (fill,      fill opacity, hairline opacity)
    "translucent": ("#f0f8f0", 0.12, 0.18),
    "opaque":      ("#0a120d", 0.96, 0.14),
}


def build(fill, opacity, hair):
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" version="1.1">',
         '  <title>naiture panel background</title>']

    def rect(x, y):
        return fill_rect(x, y, TILE, TILE, fill, opacity)

    # Top row: rounded, and carrying the design's 1px rule along the edge.
    o += group("topleft", [
        fill_path(quarter_disc(COLS[0], ROWS[0], TILE, "topleft"), fill, opacity),
        quarter_hairline(COLS[0], ROWS[0], TILE, "topleft", hair),
    ])
    o += group("top", [
        rect(COLS[1], ROWS[0]),
        stroke(f"M {COLS[1]},{ROWS[0] + 0.5} L {COLS[1] + TILE},{ROWS[0] + 0.5}", hair),
    ])
    o += group("topright", [
        fill_path(quarter_disc(COLS[2], ROWS[0], TILE, "topright"), fill, opacity),
        quarter_hairline(COLS[2], ROWS[0], TILE, "topright", hair),
    ])

    o += group("left", [rect(COLS[0], ROWS[1])])
    o += group("center", [rect(COLS[1], ROWS[1])])
    o += group("right", [rect(COLS[2], ROWS[1])])

    # Bottom row: square, so the island sits flush against the screen edge.
    o += group("bottomleft", [rect(COLS[0], ROWS[2])])
    o += group("bottom", [rect(COLS[1], ROWS[2])])
    o += group("bottomright", [rect(COLS[2], ROWS[2])])

    o += hints("", COLS, ROWS, TILE, (MARGIN, MARGIN, SIDE_MARGIN, SIDE_MARGIN))
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
            path = os.path.join(args.theme_dir, sub, "widgets", "panel-background.svg")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as fh:
                fh.write(svg)
            print(path)


if __name__ == "__main__":
    main()
