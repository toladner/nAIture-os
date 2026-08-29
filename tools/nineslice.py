"""Shared 9-slice helpers for the naiture Plasma theme.

Plasma draws a panel, a dialog or a task button from a 9-slice SVG: four corners
kept at their natural size, four edges stretched, and a centre that fills the
rest. KSvg finds each piece **by element id** and renders that element alone —
so anything in the file without an id is never drawn at all. A hairline written
as a sibling `<path>` silently disappears, which is why every piece here is a
`<g id="...">` holding its fill, its share of the hairline and anything else
that belongs to that slice.

KSvg also takes its content margins from the `hint-*-margin` elements when they
are present, and draws each corner at (left width x top height). Keeping the
hint rectangles the same size as the corner slices is therefore what makes a
corner render at its full radius rather than shrinking to the margin.
"""

CORNER_IDS = ("topleft", "topright", "bottomleft", "bottomright")


def quarter_disc(x, y, r, corner):
    """The filled part of a rounded corner, as a path `d`.

    The arc is centred on the slice's inner corner — the one facing the middle
    of the 9-slice — so the curve bulges away from the frame's outside edge.
    """
    left = corner.endswith("left")
    top = corner.startswith("top")
    ix = x + r if left else x
    iy = y + r if top else y
    sx, sy = (x if left else x + r), iy
    ex, ey = ix, (y if top else y + r)
    sweep = 1 if left == top else 0
    return f"M {sx},{sy} A {r},{r} 0 0 {sweep} {ex},{ey} L {ix},{iy} Z"


def quarter_hairline(x, y, r, corner, opacity, width=1):
    """The 1px rule following a rounded corner, inset by half a stroke."""
    inner = r - width / 2
    left = corner.endswith("left")
    top = corner.startswith("top")
    ix = x + r if left else x
    iy = y + r if top else y
    sx = x + width / 2 if left else x + r - width / 2
    ey = y + width / 2 if top else y + r - width / 2
    sweep = 1 if left == top else 0
    d = f"M {sx},{iy} A {inner},{inner} 0 0 {sweep} {ix},{ey}"
    return stroke(d, opacity, width)


def stroke(d, opacity, width=1):
    return (f'<path d="{d}" fill="none" stroke="#ffffff" '
            f'stroke-opacity="{opacity}" stroke-width="{width}" />')


def fill_path(d, colour, opacity):
    return f'<path d="{d}" fill="{colour}" fill-opacity="{opacity}" />'


def fill_rect(x, y, w, h, colour, opacity):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" '
            f'fill="{colour}" fill-opacity="{opacity}" />')


def group(eid, children, indent="  "):
    """Wrap a slice's parts under the id KSvg looks the slice up by."""
    out = [f'{indent}<g id="{eid}">']
    out += [f"{indent}  {child}" for child in children]
    out.append(f"{indent}</g>")
    return out


def hints(prefix, cols, rows, size, margins):
    """The four `hint-*-margin` rectangles, as KSvg reads content insets."""
    top, bottom, left, right = margins
    return [
        f'  <rect id="{prefix}hint-top-margin" x="{cols[1]}" y="{rows[0]}" '
        f'width="{size}" height="{top}" fill="none" />',
        f'  <rect id="{prefix}hint-bottom-margin" x="{cols[1]}" '
        f'y="{rows[2] + size - bottom}" width="{size}" height="{bottom}" fill="none" />',
        f'  <rect id="{prefix}hint-left-margin" x="{cols[0]}" y="{rows[1]}" '
        f'width="{left}" height="{size}" fill="none" />',
        f'  <rect id="{prefix}hint-right-margin" x="{cols[2] + size - right}" '
        f'y="{rows[1]}" width="{right}" height="{size}" fill="none" />',
    ]
