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
