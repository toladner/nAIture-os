#!/usr/bin/env python3
"""The naiture mark: a leaf that is also a speech bubble.

design/naiture-canvas.dc.html draws the Start button's glyph as

    border-radius: 50% 50% 50% 3px;
    background: linear-gradient(135deg, oklch(0.88 0.13 105), oklch(0.62 0.14 155));
    transform: rotate(-20deg);

— a circle with one corner left square, tipped over. That single unrounded
corner is the whole idea: read one way it is the tip of a leaf, read the other
it is the tail of a speech bubble. The tilt is what stops it reading as a
button. This script draws it as a path so it survives at any size.

The colour is the accent's, not a brand colour of its own: the mark is a light
and a deep step along the accent's own hue, so `scripts/accent.sh <colour>`
moves it with everything else. That script is the only place a colour is
chosen, and it re-runs this one.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oklch import hexof, hexto_oklch

# The design's default accent, so the tool alone draws the design's mark.
DEFAULT_ACCENT = "#decc60"

# Where the gradient's two ends sit on the accent's hue. Light enough at one
# end to catch the light, deep enough at the other to give the corner weight —
# the design's 135° diagonal, its yellow-to-green swapped for one hue so the
# mark reads as the accent rather than as a second colour.
LIGHT_L, LIGHT_C = 0.93, 0.10
DEEP_L, DEEP_C = 0.74, 0.15

SIDE = 100.0     # the mark's side before rotation; the viewBox is fitted to it
CORNER = 0.086   # the one real corner, as a fraction of the side (the design's)
ROTATE = -20.0   # degrees, CSS sense: negative is anticlockwise on screen
PAD = 3.0        # room for the outer glow


def rotate(p, deg):
    """CSS rotation: y runs downward, so a positive angle turns clockwise."""
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


def outline(side, corner_frac, deg):
    """Three corners rounded to a circle and one left nearly square, tipped by
    `deg`. Returns (segments, sampled points): the arcs are circular, so
    rotating only moves their endpoints — radius and sweep are untouched."""
    h = side / 2.0
    c = side * corner_frac

    # Clockwise from the top, in local coordinates centred on the mark. The
    # top half is one semicircle (both top corners are 50%), the bottom right
    # is a quadrant, and between the bottom and the left side sits the corner.
    steps = [
        ("M", (0, -h)),
        ("A", h, (h, 0)),        # top right quadrant
        ("A", h, (0, h)),        # bottom right quadrant
        ("L", (-h + c, h)),      # along the bottom edge
        ("A", c, (-h, h - c)),   # the corner
        ("L", (-h, 0)),          # up the left edge
        ("A", h, (0, -h)),       # top left quadrant, closing
    ]

    d, samples, here = [], [], None
    for step in steps:
        if step[0] == "A":
            _, r, end = step
            d.append(("A", r, rotate(end, deg)))
            samples += arc_samples(here, end, r, deg)
            here = end
        else:
            kind, end = step
            d.append((kind, rotate(end, deg)))
            samples.append(rotate(end, deg))
            here = end
    return d, samples


def arc_samples(start, end, r, deg, n=48):
    """Points along a clockwise circular arc, for measuring the bounding box."""
    # Two circles of radius r pass through both points; the clockwise-short one
    # has its centre to the left of the direction of travel.
    mx, my = (start[0] + end[0]) / 2.0, (start[1] + end[1]) / 2.0
    dx, dy = end[0] - start[0], end[1] - start[1]
    half = math.hypot(dx, dy) / 2.0
    off = math.sqrt(max(0.0, r * r - half * half)) / (half * 2.0)
    cx, cy = mx - dy * off, my + dx * off
    a0 = math.atan2(start[1] - cy, start[0] - cx)
    a1 = math.atan2(end[1] - cy, end[0] - cx)
    while a1 < a0:
        a1 += 2 * math.pi
    return [rotate((cx + r * math.cos(a0 + (a1 - a0) * i / n),
                    cy + r * math.sin(a0 + (a1 - a0) * i / n)), deg)
            for i in range(n + 1)]


def ramp(accent):
    _, _, hue = hexto_oklch(accent)
    return hexof(LIGHT_L, LIGHT_C, hue), hexof(DEEP_L, DEEP_C, hue)


def svg(accent=DEFAULT_ACCENT):
    light, deep = ramp(accent)
    d, samples = outline(SIDE, CORNER, ROTATE)

    # Fit the viewBox to the tipped mark rather than to the square it came
    # from: the sharp corner reaches further than the circle does, and only in
    # one direction, so a square box around the untipped shape would leave the
    # mark small and off-centre in its own icon.
    xs = [p[0] for p in samples]
    ys = [p[1] for p in samples]
    x0, x1 = min(xs) - PAD, max(xs) + PAD
    y0, y1 = min(ys) - PAD, max(ys) + PAD
    box = max(x1 - x0, y1 - y0)
    ox = -x0 + (box - (x1 - x0)) / 2.0
    oy = -y0 + (box - (y1 - y0)) / 2.0

    def fmt(p):
        return f"{p[0] + ox:.3f},{p[1] + oy:.3f}"

    parts = []
    for step in d:
        if step[0] == "A":
            parts.append(f"A {step[1]:.3f},{step[1]:.3f} 0 0 1 {fmt(step[2])}")
        else:
            parts.append(f"{step[0]} {fmt(step[1])}")
    path = " ".join(parts) + " Z"

    b = f"{box:.3f}"
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{b}" height="{b}" viewBox="0 0 {b} {b}">
  <defs>
    <linearGradient id="leaf" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{light}"/>
      <stop offset="1" stop-color="{deep}"/>
    </linearGradient>
    <radialGradient id="sheen" cx="0.34" cy="0.24" r="0.6">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.5"/>
      <stop offset="0.55" stop-color="#ffffff" stop-opacity="0.09"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <path d="{path}" fill="url(#leaf)"/>
  <path d="{path}" fill="url(#sheen)"/>
</svg>
"""


if __name__ == "__main__":
    import argparse

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out", nargs="*", default=["icons/naiture.svg"],
                    help="where to write the mark; repeatable")
    ap.add_argument("-a", "--accent", default=DEFAULT_ACCENT,
                    help="accent to draw the mark in (#rrggbb)")
    args = ap.parse_args()

    body = svg(args.accent)
    light, deep = ramp(args.accent)
    for out in args.out:
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        with open(out, "w") as f:
            f.write(body)
        print(f"{out}  {light} -> {deep}  tipped {ROTATE}deg")
