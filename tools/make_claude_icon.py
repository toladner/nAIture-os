#!/usr/bin/env python3
"""The icon a Claude Code console carries.

Claude Code ships no icon on Linux — the CLI is one binary and no image files —
so there is nothing to copy and this draws the mark instead: the radiating
burst, in Claude's own clay orange.

It is a reconstruction, not the official asset. If you have the real file, drop
it in as icons/claude.svg and scripts/claude-console.sh will install that
instead of this.
"""
import math
import os
import sys

# Claude's clay orange.
COLOUR = "#d97757"

SIZE = 64.0
CENTRE = SIZE / 2

# The burst is deliberately uneven: the rays differ in length and are not
# quite evenly spaced, which is what stops it reading as a sunburst clipart.
# Each entry is (angle in degrees, length as a fraction of the radius).
RAYS = [
    (90.0, 1.00), (118.0, 0.72), (147.0, 0.94), (176.0, 0.66),
    (205.0, 0.90), (233.0, 0.70), (262.0, 1.00), (291.0, 0.68),
    (320.0, 0.92), (349.0, 0.74), (18.0, 0.88), (48.0, 0.70),
]

OUTER = SIZE / 2 - 3        # room for the widest ray's cap
WIDTH = 0.088 * OUTER       # half-width of a ray at its cap


def ray_path(angle_deg, length):
    """One ray: a point at the centre opening into a round-capped stroke."""
    a = math.radians(angle_deg)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux                      # unit normal

    r = OUTER * length
    cap = r - WIDTH                       # centre of the cap's semicircle

    def pt(along, across):
        return (CENTRE + ux * along + px * across,
                CENTRE + uy * along + py * across)

    inner = pt(0, 0)
    left = pt(cap, -WIDTH)
    right = pt(cap, WIDTH)

    return (f"M {inner[0]:.3f},{inner[1]:.3f} "
            f"L {left[0]:.3f},{left[1]:.3f} "
            f"A {WIDTH:.3f},{WIDTH:.3f} 0 0 1 {right[0]:.3f},{right[1]:.3f} Z")


def svg(colour=COLOUR):
    paths = "\n".join(f'  <path d="{ray_path(a, l)}"/>' for a, l in RAYS)
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE:.0f}" height="{SIZE:.0f}"
     viewBox="0 0 {SIZE:.0f} {SIZE:.0f}">
  <g fill="{colour}">
{paths}
  </g>
</svg>
"""


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out", nargs="*", default=["icons/naiture-claude.svg"])
    ap.add_argument("-c", "--colour", default=COLOUR)
    args = ap.parse_args()

    body = svg(args.colour)
    for out in args.out:
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        with open(out, "w") as f:
            f.write(body)
        print(f"{out}  {args.colour}  {len(RAYS)} rays")
