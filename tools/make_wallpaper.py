#!/usr/bin/env python3
"""Render the naiture desktop backdrop.

Everything here is a transcription of the canvas design's backdrop layers
(design/naiture-canvas.dc.html), which are authored against a 1600x1000 frame.
Geometry is scaled to the requested output size; the blade field is generated
from the same sin-hash the design uses, so the silhouette is identical.
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from oklch import oklch_to_srgb  # noqa: E402

DESIGN_W, DESIGN_H = 1600, 1000

SKY_STOPS = [
    (0.00, (0.52, 0.07, 215)),
    (0.26, (0.40, 0.06, 190)),
    (0.52, (0.32, 0.06, 160)),
    (0.74, (0.24, 0.05, 145)),
    (1.00, (0.18, 0.04, 135)),
]
SKY_ANGLE = 174           # CSS linear-gradient(174deg, ...)
GOLD = (0.85, 0.11, 92)   # top-left sun glow, 0.42 alpha
MOSS = (0.60, 0.13, 150)  # bottom-right field glow, 0.45 alpha
MIST = (0.86, 0.02, 160)  # low haze band, 0.30 alpha
BLADE_DARK = (0.13, 0.035, 140)
BLADE_TIP = (0.20, 0.05, 150)
HORIZON = (0.16, 0.045, 140)  # bottom fade, 0.92 alpha
GRID_ALPHA = 6                # rgba(255,255,255,0.022)
GRID_STEP = 80


def rnd(i, salt):
    """The design's deterministic hash — same blades every render."""
    x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return x - math.floor(x)


def sky(w, h, stops=None, angle=None):
    """linear-gradient(174deg, ...) — a near-vertical ramp, tilted 6deg.

    The stops and the tilt are arguments so that tools/make_scene.py can ask
    for the same ramp under a different sun without copying it.
    """
    stops = SKY_STOPS if stops is None else stops
    angle = SKY_ANGLE if angle is None else angle
    ramp = Image.new("RGB", (1, 1024))
    px = ramp.load()
    for y in range(1024):
        t = y / 1023
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                k = (t - p0) / (p1 - p0)
                # interpolate in OKLCH, as the browser does
                lch = tuple(a + (b - a) * k for a, b in zip(c0, c1))
                px[0, y] = oklch_to_srgb(*lch)
                break

    # Size the ramp to the bounding box of the tilted output rect, so that
    # after rotating back the full 0->1 range lands inside the crop.
    a = math.radians(abs(angle - 180))
    cw = round(w * math.cos(a) + h * math.sin(a))
    ch = round(h * math.cos(a) + w * math.sin(a))
    big = ramp.resize((cw, ch), Image.BICUBIC).rotate(
        angle - 180, resample=Image.BICUBIC, expand=True
    )
    left, top = (big.size[0] - w) // 2, (big.size[1] - h) // 2
    return big.crop((left, top, left + w, top + h)).convert("RGB")


def radial(size, color, alpha, fade_at):
    """radial-gradient(circle, color/alpha, transparent <fade_at>)."""
    w, h = size
    mask = Image.radial_gradient("L").resize((max(w, 1), max(h, 1)), Image.BICUBIC)
    lut = []
    for v in range(256):
        r = v / 255                       # 0 at centre, 1 at edge
        a = 1.0 - r / fade_at if r < fade_at else 0.0
        lut.append(int(round(a * alpha * 255)))
    mask = mask.point(lut)
    layer = Image.new("RGB", (w, h), color)
    return layer, mask


def paste_glow(base, color_lch, alpha, box, fade_at, blur):
    x, y, w, h = box
    if w <= 0 or h <= 0:
        return
    layer, mask = radial((w, h), oklch_to_srgb(*color_lch), alpha, fade_at)
    if blur > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(blur))
    base.paste(layer, (x, y), mask)


def horizon_fade(base, w, h, sy):
    """The 340px bottom scrim that grounds the field."""
    band = int(340 * sy)
    ramp = Image.new("L", (1, band))
    px = ramp.load()
    for y in range(band):
        px[0, y] = int(round((y / max(band - 1, 1)) * 0.92 * 255))
    mask = ramp.resize((w, band), Image.BICUBIC)
    layer = Image.new("RGB", (w, band), oklch_to_srgb(*HORIZON))
    base.paste(layer, (0, h - band), mask)


def blades(base, w, h, sx, sy):
    """44 swaying blades along the bottom edge, drawn at 2x then downsampled."""
    ss = 2
    margin = int(200 * sx * ss)
    lw, lh = w * ss + margin * 2, h * ss
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    tip_rgb = oklch_to_srgb(*BLADE_TIP)
    dark_rgb = oklch_to_srgb(*BLADE_DARK)

    for i in range(44):
        r1, r2, r3 = rnd(i, 1), rnd(i, 2), rnd(i, 3)
        bh = max((46 + r1 * 128) * sy * ss, 4)
        bw = max((2 + r2 * 3.4) * sx * ss, 2)
        left = ((i / 44) * 104 - 2 + (r3 - 0.5) * 2.2) / 100 * w * ss
        lean = (r3 - 0.5) * 9
        dark = 0.42 + r1 * 0.34

        # each blade gets its own canvas so it can pivot about its base
        pad = int(bh * 0.35) + 8
        cw, ch = int(bw) + pad * 2, int(bh)
        shape = Image.new("L", (cw, ch), 0)
        ImageDraw.Draw(shape).rounded_rectangle(
            [pad, 0, pad + bw, ch + bw], radius=bw / 2, fill=255
        )

        # vertical ramp built one pixel wide, then stretched across the blade
        col = Image.new("RGBA", (1, ch))
        cp = col.load()
        for y in range(ch):
            t = y / max(ch - 1, 1)          # 0 at the tip, 1 at the base
            rgb = tuple(int(round(a + (b - a) * t)) for a, b in zip(tip_rgb, dark_rgb))
            cp[0, y] = rgb + (int(round((0.05 + (dark - 0.05) * t) * 255)),)
        grad = col.resize((cw, ch), Image.NEAREST)

        blade = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        blade.paste(grad, (0, 0), shape)
        blade = blade.rotate(-lean, resample=Image.BICUBIC, center=(pad + bw / 2, ch))

        layer.alpha_composite(blade, (int(left) - pad + margin, lh - ch + int(8 * sy * ss)))

    layer = layer.crop((margin, 0, margin + w * ss, lh)).resize((w, h), Image.LANCZOS)
    base.paste(layer, (0, 0), layer)


def grid(base, w, h, sx):
    step = max(int(GRID_STEP * sx), 8)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for x in range(0, w, step):
        d.line([(x, 0), (x, h)], fill=(255, 255, 255, GRID_ALPHA))
    for y in range(0, h, step):
        d.line([(0, y), (w, y)], fill=(255, 255, 255, GRID_ALPHA))
    base.paste(overlay, (0, 0), overlay)


def render(w, h, with_blades=True, with_grid=True):
    sx, sy = w / DESIGN_W, h / DESIGN_H
    img = sky(w, h)

    paste_glow(img, GOLD, 0.42,
               (int(-160 * sx), int(-280 * sy), int(1100 * sx), int(800 * sy)),
               0.62, 70 * sy)
    paste_glow(img, MOSS, 0.45,
               (w - int(720 * sx), h - int(440 * sy), int(900 * sx), int(700 * sy)),
               0.64, 80 * sy)
    paste_glow(img, MIST, 0.30,
               (int(-0.06 * w), h - int(370 * sy), int(1.12 * w), int(160 * sy)),
               0.72, 34 * sy)

    horizon_fade(img, w, h, sy)
    if with_blades:
        blades(img, w, h, sx, sy)
    if with_grid:
        grid(img, w, h, sx)
    return img


def main():
    ap = argparse.ArgumentParser(description="Render the naiture wallpaper.")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("-W", "--width", type=int, default=3840)
    ap.add_argument("-H", "--height", type=int, default=2160)
    ap.add_argument("--no-blades", action="store_true")
    ap.add_argument("--no-grid", action="store_true")
    args = ap.parse_args()

    img = render(args.width, args.height, not args.no_blades, not args.no_grid)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    img.save(args.out, quality=95)
    print(f"{args.out}  {img.size[0]}x{img.size[1]}")


if __name__ == "__main__":
    main()
