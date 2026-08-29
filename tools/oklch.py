"""OKLCH -> sRGB. The naiture design is authored in oklch(); every other
format in this repo (Plasma .colors, Konsole, GTK, SVG) needs sRGB."""
import math


def oklch_to_srgb(L, C, H):
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)

    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3

    r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def gamma(u):
        u = 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)
        return 12.92 * u if u <= 0.0031308 else 1.055 * u ** (1 / 2.4) - 0.055

    return tuple(round(gamma(c) * 255) for c in (r, g, bl))


def hexof(L, C, H):
    return "#%02x%02x%02x" % oklch_to_srgb(L, C, H)


def rgbstr(L, C, H):
    return ",".join(str(c) for c in oklch_to_srgb(L, C, H))


if __name__ == "__main__":
    import sys
    for arg in sys.argv[1:]:
        L, C, H = (float(x) for x in arg.split(","))
        print(f"oklch({L} {C} {H})  {hexof(L, C, H)}  rgb({rgbstr(L, C, H)})")


def srgb_to_oklch(r, g, b):
    """The inverse, for deriving a mark or a gradient from a colour that was
    chosen as sRGB — an accent picked in System Settings, say."""
    def ungamma(u):
        u /= 255.0
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4

    r, g, b = ungamma(r), ungamma(g), ungamma(b)

    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)

    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def hexto_oklch(s):
    s = s.lstrip("#")
    return srgb_to_oklch(int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
