#!/usr/bin/env python3
"""Generate the naiture task-button background.

The design's switcher tiles are 34x34 rounded rectangles (radius 11) that carry
their state in how bright the fill and the hairline are — a barely-there tile
when the app is closed, brighter when open, brightest when focused. Plasma
expresses the same states as prefixed 9-slice sets inside one SVG.
"""
import argparse
import os

TILE = 11          # corner size, also the radius
GAP = 3
SETS = {
    # prefix:      (fill,      fill opacity, stroke opacity)
    "normal":      ("#ffffff", 0.04, 0.08),
    "minimized":   ("#ffffff", 0.06, 0.10),
    "hover":       ("#ffffff", 0.14, 0.18),
    "focus":       ("#ffffff", 0.20, 0.26),
    "attention":   ("#decc60", 0.22, 0.40),
}
BLOCK = 3 * TILE + 2 * GAP + GAP * 2   # one 3x3 set plus breathing room


def quarter(x, y, which):
    """The filled part of one rounded corner."""
    r = TILE
    if which == "topleft":
        return f"M {x},{y+r} A {r},{r} 0 0 1 {x+r},{y} L {x+r},{y+r} Z"
    if which == "topright":
        return f"M {x},{y} A {r},{r} 0 0 1 {x+r},{y+r} L {x},{y+r} Z"
    if which == "bottomleft":
        return f"M {x},{y} L {x+r},{y} L {x+r},{y+r} A {r},{r} 0 0 1 {x},{y} Z"
    return f"M {x},{y} L {x+r},{y} A {r},{r} 0 0 1 {x},{y+r} Z"


def build_set(prefix, ox, fill, opacity, stroke):
    cols = [ox, ox + TILE + GAP, ox + 2 * (TILE + GAP)]
    rows = [0, TILE + GAP, 2 * (TILE + GAP)]
    out = []

    def r(eid, x, y):
        out.append(f'  <rect id="{prefix}-{eid}" x="{x}" y="{y}" '
                   f'width="{TILE}" height="{TILE}" fill="{fill}" '
                   f'fill-opacity="{opacity}" />')

    def c(eid, x, y, which):
        out.append(f'  <path id="{prefix}-{eid}" d="{quarter(x, y, which)}" '
                   f'fill="{fill}" fill-opacity="{opacity}" />')

    c("topleft", cols[0], rows[0], "topleft")
    r("top", cols[1], rows[0])
    c("topright", cols[2], rows[0], "topright")
    r("left", cols[0], rows[1])
    r("center", cols[1], rows[1])
    r("right", cols[2], rows[1])
    c("bottomleft", cols[0], rows[2], "bottomleft")
    r("bottom", cols[1], rows[2])
    c("bottomright", cols[2], rows[2], "bottomright")

    # the design's 1px hairline around each tile
    rr = TILE - 0.5
    out.append(f'  <path d="M {cols[0]+0.5},{rows[0]+TILE} '
               f'A {rr},{rr} 0 0 1 {cols[0]+TILE},{rows[0]+0.5}" fill="none" '
               f'stroke="#ffffff" stroke-opacity="{stroke}" stroke-width="1" />')
    out.append(f'  <path d="M {cols[1]},{rows[0]+0.5} L {cols[1]+TILE},{rows[0]+0.5}" '
               f'fill="none" stroke="#ffffff" stroke-opacity="{stroke}" stroke-width="1" />')
    out.append(f'  <path d="M {cols[1]},{rows[2]+TILE-0.5} L {cols[1]+TILE},{rows[2]+TILE-0.5}" '
               f'fill="none" stroke="#ffffff" stroke-opacity="{stroke}" stroke-width="1" />')

    for eid, x, y, w, h in (
        (f"{prefix}-hint-top-margin", cols[1], rows[0], TILE, 2),
        (f"{prefix}-hint-bottom-margin", cols[1], rows[2] + TILE - 2, TILE, 2),
        (f"{prefix}-hint-left-margin", cols[0], rows[1], 2, TILE),
        (f"{prefix}-hint-right-margin", cols[2] + TILE - 2, rows[1], 2, TILE),
    ):
        out.append(f'  <rect id="{eid}" x="{x}" y="{y}" width="{w}" height="{h}" fill="none" />')
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-d", "--theme-dir", required=True)
    args = ap.parse_args()

    width = BLOCK * len(SETS)
    height = 3 * TILE + 2 * GAP
    body = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" '
            f'height="{height}" viewBox="0 0 {width} {height}" version="1.1">',
            '  <title>naiture task buttons</title>']
    for i, (prefix, (fill, opacity, stroke)) in enumerate(SETS.items()):
        body += build_set(prefix, i * BLOCK + GAP, fill, opacity, stroke)
    body.append("</svg>")

    path = os.path.join(args.theme_dir, "widgets", "tasks.svg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write("\n".join(body) + "\n")
    print(path)


if __name__ == "__main__":
    main()
