#!/usr/bin/env python3
"""Generate the naiture task-button background.

The design's switcher tiles are rounded rectangles (radius 11) that carry their
state in how bright the fill and the hairline are — a barely-there tile when the
app is closed, brighter when open, brightest when focused. Plasma expresses the
same states as prefixed 9-slice sets inside one SVG.

The focused tile also gets an accent bar along its top edge, the same marker
Plasma puts on an applet whose popup is open, so the active window and the open
quick-settings sheet are flagged the same way.

Two things this file has to get right, both explained in tools/nineslice.py:
every slice is a `<g id="...">`, because KSvg renders slices by id and ignores
anything else; and accent colours are never written in literally. Elements
painted `currentColor` and classed `ColorScheme-*` are recoloured by KSvg from
the running colour scheme, so the bar follows whatever accent is set — see
scripts/accent.sh — and this SVG never has to be regenerated to change it.
"""
import argparse
import os

from nineslice import (fill_path, fill_rect, group, hints, quarter_disc,
                       quarter_hairline, stroke)

TILE = 11          # corner size, also the radius
GAP = 3
BAR = 3            # the accent bar on the focused tile

SETS = {
    # prefix:      (fill,      fill opacity, stroke opacity, accent bar class)
    "normal":      ("#ffffff", 0.04, 0.08, None),
    "minimized":   ("#ffffff", 0.06, 0.10, None),
    "hover":       ("#ffffff", 0.14, 0.18, None),
    "focus":       ("#ffffff", 0.20, 0.26, "ColorScheme-Highlight"),
    "attention":   ("#ffffff", 0.22, 0.40, "ColorScheme-NeutralText"),
}

# Fallbacks, replaced wholesale by KSvg with the running colour scheme's values.
SCHEME_DEFAULTS = {
    "ColorScheme-Highlight": "#decc60",
    "ColorScheme-NeutralText": "#6abfd9",
}

BLOCK = 3 * TILE + 2 * GAP + GAP * 2   # one 3x3 set plus breathing room


def bar_corner(x, y, corner, cls):
    """The accent bar's share of a rounded corner slice.

    The corner slice is the full radius, so a plain rectangle would spill
    outside the curve. The bar is bounded by the same arc the tile is: at the
    bar's lower edge the arc has come `inset` in from the tile's straight edge.
    """
    r = TILE
    inset = (r * r - (r - BAR) ** 2) ** 0.5
    left = corner.endswith("left")
    ix = x + r if left else x
    ex = ix - inset if left else ix + inset
    sweep = 0 if left else 1
    d = (f"M {ix},{y} A {r},{r} 0 0 {sweep} {ex:.3f},{y + BAR} "
         f"L {ix},{y + BAR} Z")
    return f'<path d="{d}" fill="currentColor" class="{cls}" />'


def build_set(prefix, ox, fill, opacity, hair, accent):
    cols = [ox, ox + TILE + GAP, ox + 2 * (TILE + GAP)]
    rows = [0, TILE + GAP, 2 * (TILE + GAP)]
    out = []

    def rect(x, y):
        return fill_rect(x, y, TILE, TILE, fill, opacity)

    def corner(eid, x, y, which):
        parts = [fill_path(quarter_disc(x, y, TILE, which), fill, opacity),
                 quarter_hairline(x, y, TILE, which, hair)]
        if accent and which.startswith("top"):
            parts.append(bar_corner(x, y, which, accent))
        return group(f"{prefix}-{eid}", parts)

    out += corner("topleft", cols[0], rows[0], "topleft")
    top = [rect(cols[1], rows[0]),
           stroke(f"M {cols[1]},{rows[0] + 0.5} L {cols[1] + TILE},{rows[0] + 0.5}", hair)]
    if accent:
        top.append(f'<rect x="{cols[1]}" y="{rows[0]}" width="{TILE}" '
                   f'height="{BAR}" fill="currentColor" class="{accent}" />')
    out += group(f"{prefix}-top", top)
    out += corner("topright", cols[2], rows[0], "topright")

    out += group(f"{prefix}-left", [
        rect(cols[0], rows[1]),
        stroke(f"M {cols[0] + 0.5},{rows[1]} L {cols[0] + 0.5},{rows[1] + TILE}", hair),
    ])
    out += group(f"{prefix}-center", [rect(cols[1], rows[1])])
    out += group(f"{prefix}-right", [
        rect(cols[2], rows[1]),
        stroke(f"M {cols[2] + TILE - 0.5},{rows[1]} L {cols[2] + TILE - 0.5},{rows[1] + TILE}", hair),
    ])

    out += corner("bottomleft", cols[0], rows[2], "bottomleft")
    out += group(f"{prefix}-bottom", [
        rect(cols[1], rows[2]),
        stroke(f"M {cols[1]},{rows[2] + TILE - 0.5} L {cols[1] + TILE},{rows[2] + TILE - 0.5}", hair),
    ])
    out += corner("bottomright", cols[2], rows[2], "bottomright")

    out += hints(f"{prefix}-", cols, rows, TILE, (2, 2, 2, 2))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", "--theme-dir", required=True)
    args = ap.parse_args()

    width = BLOCK * len(SETS)
    height = 3 * TILE + 2 * GAP
    body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}" version="1.1">',
            '  <title>naiture task buttons</title>',
            '  <style type="text/css" id="current-color-scheme">']
    for cls, value in SCHEME_DEFAULTS.items():
        body.append(f"    .{cls} {{ color: {value}; }}")
    body.append("  </style>")
    for i, (prefix, (fill, opacity, hair, accent)) in enumerate(SETS.items()):
        body += build_set(prefix, i * BLOCK + GAP, fill, opacity, hair, accent)
    body.append("</svg>")

    path = os.path.join(args.theme_dir, "widgets", "tasks.svg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("\n".join(body) + "\n")
    print(path)


if __name__ == "__main__":
    main()
