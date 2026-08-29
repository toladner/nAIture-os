#!/usr/bin/env python3
"""Render one view out of the house.

The story naiture tells is that the desktop is a house carried along under a
bunch of balloons, and that every window of it — every tab — looks out on
somewhere slightly different. So a scene is not a picture: it is the same world
tools/make_wallpaper.py draws for the desktop, seen from another window. Same
sky ramp, same glows, same blade field, different sun and different ground.

Three rules the generator is built around, and none of them are negotiable:

  it is weather, not a picture
      A scene sits behind a terminal's text for hours. It has to read as light
      in the room and nothing more, so everything is low-contrast, dark, and
      blurred past the point where any edge survives. If you can describe what
      you saw, it is too loud.

  a seed is a place
      Scene n is the same picture every time it is rendered, on any machine, for
      ever. That is what lets a project keep its own view without anything being
      stored: the pool is rebuilt from scratch each login and comes out
      identical, so the hash of a directory is a stable address.

  it is derived, not drawn
      Every colour comes from the palette by way of OKLCH, so the accent moves
      the weather with it, and a future theme is a different generator behind
      this same signature rather than a folder of images.
"""
import argparse
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_wallpaper as w  # noqa: E402

# The desktop's frame. Geometry is written against it and scaled, exactly as
# the wallpaper does, so the two stay relatives.
DESIGN_W, DESIGN_H = 1600, 1000

# How far the sky is taken down from the desktop's. The wallpaper is looked at;
# a scene is looked *through*, with text on top, so it lives well darker and
# keeps its brightest point below where text stops being comfortable.
DIM = 0.52

# And then a ceiling, because everything above is random and a roll of the dice
# should not be able to produce a scene you cannot read on. CEILING is the
# brightest a scene's 99th-percentile pixel may be, out of 255; anything above
# it is scaled down bodily. Tuning the ranges makes most scenes dark. This makes
# all of them dark.
CEILING = 74


def dimmed(stops, dim, hue_shift, lift):
    """The desktop's sky ramp, darkened and turned a little on the hue wheel."""
    out = []
    for pos, (L, C, H) in stops:
        out.append((pos, (max(0.03, L * dim + lift), C, (H + hue_shift) % 360)))
    return out


def ridge(base, rng, wpx, hpx, sy, horizon):
    """A far-off shoulder of hills, the colour distance makes everything.

    Drawn as a couple of overlapping ellipses and then blurred until only the
    silhouette's weight is left — a ridge you notice as a change of tone at the
    horizon, never as a mountain.
    """
    layer = Image.new("L", (wpx, hpx), 0)
    d = ImageDraw.Draw(layer)
    peaks = rng.randint(2, 4)
    for i in range(peaks):
        cx = rng.uniform(-0.15, 1.15) * wpx
        rw = rng.uniform(0.28, 0.62) * wpx
        rh = rng.uniform(0.10, 0.22) * hpx
        top = horizon - rh
        d.ellipse([cx - rw, top, cx + rw, horizon + rh], fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(max(hpx * 0.035, 3)))
    # Distant air: barely any chroma, and cool against the moss below it.
    tone = w.oklch_to_srgb(rng.uniform(0.24, 0.33), 0.022, rng.uniform(215, 250))
    base.paste(Image.new("RGB", (wpx, hpx), tone),
               (0, 0), layer.point(lambda v: int(v * rng.uniform(0.30, 0.46))))


def render(index, width=800, height=500):
    """Scene `index`, at `width` x `height`. Same index, same picture."""
    rng = random.Random(0x6E61 + index * 7919)
    sx, sy = width / DESIGN_W, height / DESIGN_H

    # Where the sun is, and therefore what everything else is a consequence of.
    sun_x = rng.uniform(-0.30, 1.05)
    sun_y = rng.uniform(-0.42, 0.18)
    sun_hue = rng.uniform(74, 108)          # gold, give or take a season
    sun_strength = rng.uniform(0.18, 0.36)

    # The sky follows the sun: low sun, warmer and lower ramp.
    sky = w.sky(width, height,
                stops=dimmed(w.SKY_STOPS, DIM * rng.uniform(0.84, 1.0),
                             rng.uniform(-14, 12), rng.uniform(-0.02, 0.01)),
                angle=w.SKY_ANGLE + rng.uniform(-5, 5))
    img = sky

    horizon = int(height * rng.uniform(0.58, 0.80))

    if rng.random() < 0.55:
        ridge(img, rng, width, height, sy, horizon)

    # The sun's own glow, wide and soft enough that it is a direction rather
    # than a disc.
    glow_w = int(rng.uniform(0.62, 1.15) * width)
    glow_h = int(rng.uniform(0.70, 1.30) * height)
    w.paste_glow(img, (0.85, 0.11, sun_hue), sun_strength,
                 (int(sun_x * width - glow_w / 2), int(sun_y * height),
                  glow_w, glow_h),
                 rng.uniform(0.55, 0.72), 70 * sy)

    # The ground answering it, from whichever side the sun is not on.
    moss_side = 0.0 if sun_x > 0.5 else 1.0
    moss_w = int(rng.uniform(0.55, 0.95) * width)
    moss_h = int(rng.uniform(0.55, 0.90) * height)
    w.paste_glow(img, (rng.uniform(0.52, 0.66), rng.uniform(0.10, 0.15),
                       rng.uniform(138, 162)),
                 rng.uniform(0.24, 0.38),
                 (int(moss_side * width - moss_w / 2), height - moss_h + int(0.12 * height),
                  moss_w, moss_h),
                 rng.uniform(0.58, 0.70), 80 * sy)

    # Haze on the horizon, most days.
    if rng.random() < 0.75:
        band = int(rng.uniform(0.10, 0.22) * height)
        w.paste_glow(img, (0.86, 0.02, rng.uniform(150, 175)),
                     rng.uniform(0.12, 0.24),
                     (int(-0.06 * width), horizon - band // 2,
                      int(1.12 * width), band),
                     0.72, 34 * sy)

    w.horizon_fade(img, width, height, sy * rng.uniform(0.8, 1.5))

    # Sometimes you are level with the field, sometimes well above it.
    if rng.random() < 0.62:
        w.blades(img, width, height, sx, sy * rng.uniform(0.35, 0.85))

    # And then the whole thing is put out of focus, which is what makes it
    # possible to read text on top of it.
    img = img.filter(ImageFilter.GaussianBlur(max(width / 190, 2.0)))

    # The ceiling. Measured on the 99th percentile rather than the brightest
    # pixel, so one stray highlight cannot drag a whole scene dark.
    hist = img.convert("L").histogram()
    total = sum(hist)
    run, p99 = 0, 255
    for value, count in enumerate(hist):
        run += count
        if run >= total * 0.99:
            p99 = value
            break
    if p99 > CEILING:
        img = img.point(lambda v, k=CEILING / p99: int(v * k))
    return img


def main():
    ap = argparse.ArgumentParser(description="Render a naiture window view.")
    ap.add_argument("-o", "--out", required=True,
                    help="output file, or a directory when --count is given")
    ap.add_argument("-i", "--index", type=int, default=0)
    ap.add_argument("-n", "--count", type=int,
                    help="render indices 0..n-1 into the output directory")
    ap.add_argument("-W", "--width", type=int, default=800)
    ap.add_argument("-H", "--height", type=int, default=500)
    ap.add_argument("--contact-sheet", metavar="FILE",
                    help="also write every scene tiled into one image")
    args = ap.parse_args()

    if args.count is None:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        render(args.index, args.width, args.height).save(args.out, quality=88)
        print(args.out)
        return

    os.makedirs(args.out, exist_ok=True)
    tiles = []
    for i in range(args.count):
        img = render(i, args.width, args.height)
        path = os.path.join(args.out, f"{i:02d}.jpg")
        img.save(path, quality=88)
        tiles.append(img)
        print(path)

    if args.contact_sheet:
        cols = min(4, len(tiles))
        rows = math.ceil(len(tiles) / cols)
        sheet = Image.new("RGB", (cols * args.width, rows * args.height))
        for i, t in enumerate(tiles):
            sheet.paste(t, ((i % cols) * args.width, (i // cols) * args.height))
        sheet.save(args.contact_sheet, quality=88)
        print(args.contact_sheet)


if __name__ == "__main__":
    main()
