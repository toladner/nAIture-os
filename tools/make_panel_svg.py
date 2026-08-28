#!/usr/bin/env python3
"""Generate the naiture panel background.

Plasma draws a panel from a 9-slice SVG: four corners kept at their natural
size, four edges stretched, and a centre that fills the rest. Each slice is a
separate element identified by id. This writes the three variants Plasma looks
for — the default and `translucent/` (the design's glass film over the
wallpaper) and `opaque/` (what it becomes behind a maximised window).

The design's island is flush with the screen edge and rounded only along its
top, so the bottom corners here are square on purpose.
"""
import argparse
import os

TILE = 16          # corner size, also the top corner radius
GAP = 4            # keeps slices from bleeding into each other
COLS = [0, TILE + GAP, 2 * (TILE + GAP)]
ROWS = COLS
W = COLS[2] + TILE
H = ROWS[2] + TILE

VARIANTS = {
    # name:        (fill,      fill opacity, hairline opacity)
    "translucent": ("#f0f8f0", 0.12, 0.18),
    "opaque":      ("#0a120d", 0.96, 0.14),
}


def rect(eid, x, y, fill, opacity):
    return (f'  <rect id="{eid}" x="{x}" y="{y}" width="{TILE}" height="{TILE}" '
            f'fill="{fill}" fill-opacity="{opacity}" />')


def corner(eid, x, y, fill, opacity, side):
    """A quarter disc: the filled part of a rounded corner."""
    r = TILE
    if side == "topleft":
        d = f"M {x},{y+r} A {r},{r} 0 0 1 {x+r},{y} L {x+r},{y+r} Z"
    else:  # topright
        d = f"M {x},{y} A {r},{r} 0 0 1 {x+r},{y+r} L {x},{y+r} Z"
    return (f'  <path id="{eid}" d="{d}" fill="{fill}" fill-opacity="{opacity}" />')


def hairline(x, y, opacity, side):
    """The design's 1px rule along the top edge, following the curve."""
    r = TILE
    if side == "top":
        d = f"M {x},{y+0.5} L {x+TILE},{y+0.5}"
    elif side == "topleft":
        d = f"M {x+0.5},{y+r} A {r-0.5},{r-0.5} 0 0 1 {x+r},{y+0.5}"
    else:
        d = f"M {x},{y+0.5} A {r-0.5},{r-0.5} 0 0 1 {x+r-0.5},{y+r}"
    return (f'  <path d="{d}" fill="none" stroke="#ffffff" '
            f'stroke-opacity="{opacity}" stroke-width="1" />')


def build(fill, opacity, hair):
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
         f'viewBox="0 0 {W} {H}" version="1.1">',
         '  <title>naiture panel background</title>']

    # corners — top two rounded, bottom two square so the island sits flush
    o.append(corner("topleft",  COLS[0], ROWS[0], fill, opacity, "topleft"))
    o.append(rect("top",        COLS[1], ROWS[0], fill, opacity))
    o.append(corner("topright", COLS[2], ROWS[0], fill, opacity, "topright"))

    o.append(rect("left",   COLS[0], ROWS[1], fill, opacity))
    o.append(rect("center", COLS[1], ROWS[1], fill, opacity))
    o.append(rect("right",  COLS[2], ROWS[1], fill, opacity))

    o.append(rect("bottomleft",  COLS[0], ROWS[2], fill, opacity))
    o.append(rect("bottom",      COLS[1], ROWS[2], fill, opacity))
    o.append(rect("bottomright", COLS[2], ROWS[2], fill, opacity))

    o.append(hairline(COLS[0], ROWS[0], hair, "topleft"))
    o.append(hairline(COLS[1], ROWS[0], hair, "top"))
    o.append(hairline(COLS[2], ROWS[0], hair, "topright"))

    # Content margins: keep applets clear of the rounded top and the edges.
    for eid, x, y, w, h in (
        ("hint-top-margin",    COLS[1], ROWS[0], TILE, 2),
        ("hint-bottom-margin", COLS[1], ROWS[2], TILE, 1),
        ("hint-left-margin",   COLS[0], ROWS[1], 2, TILE),
        ("hint-right-margin",  COLS[2], ROWS[1], 2, TILE),
    ):
        o.append(f'  <rect id="{eid}" x="{x}" y="{y}" width="{w}" height="{h}" '
                 f'fill="none" />')

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
