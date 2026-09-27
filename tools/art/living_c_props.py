"""Living room C's props, owner round 22:
  wall_tv         — "having that tv be bigger wide and up on wall": a wide flat screen on a bracket,
                    square and symmetric (the old CRT's frame wasn't); its screen is left black for the
                    live 'tv' detail (scripts/module_anim.gd: snow, flashes, a big crack, colour bleed).
  guitar_on_floor — "the guitar is weird on the stand like that. Put it on the floor, give it geometry
                    and blood on it, perhaps it had been used as a weapon".
"""
import math
import random

from pixlib import hexc, shade


def wall_tv(c, x0, y0, w, h):
    """A wide flat TV on a wall bracket: a thin black bezel all round (the same on both sides), a
    sheen along the top, a standby LED under the screen, standing a finger off the wall (its left edge
    and a soft shadow to the right). Returns the screen's top-left."""
    x1, y1 = x0 + w + 3, y0 + h + 3
    for y in range(y0 + 2, y1 + 3):                                   # its shadow on the wall
        c.put(x1 + 1, y, hexc('000000', 60))
        c.put(x1 + 2, y, hexc('000000', 30))
    c.hline(x0 + 2, x1 + 1, y1 + 1, hexc('000000', 60))
    c.vline(x0 - 1, y0 + 1, y1 - 1, hexc('3a3a3e'))                   # its edge, a finger off the wall
    c.box(x0, y0, x1, y1, hexc('161618'), hexc('0a0a0c'))             # the bezel
    c.hline(x0 + 1, x1 - 1, y0 + 1, hexc('2a2a2e'))                    # a sheen along its top
    c.rect(x0 + 2, y0 + 2, x0 + 1 + w, y0 + 1 + h, hexc('060608'))     # the screen
    c.put((x0 + x1) // 2, y1 - 1, hexc('c0453a'))                     # the standby LED
    return x0 + 2, y0 + 2


def guitar_on_floor(c, cx, cy, ang, seed=22, scale=1.35):
    """Lying flat on the floor, seen from above-front: its side (the rim) showing under the top, the
    neck snapped below the headstock and the headstock thrown aside, strings curling off the break,
    blood across the lower bout and pooled on the floor under it. (cx, cy) = the body's middle on the
    floor; `ang` = the neck's heading (radians, 0 = to the right)."""
    OUT, EDGE, MID, CEN = hexc('2a1a10'), hexc('4e2410'), hexc('9c4e24'), hexc('dc9a44')
    SIDE, NECK, BOARD = hexc('3a1a0c'), hexc('6a4424'), hexc('2e2018')
    BL, BL_DK = hexc('6a1010'), hexc('3e0808')
    SQ = 0.5                                         # a flat thing on the floor, seen from above-front
    ca, sa = math.cos(ang), math.sin(ang)
    k = scale

    def half(u):                                     # the body's half-width along its length (u -13..14)
        t = (u + 13.0) / 27.0
        lower = 10.5 * math.sqrt(max(0.0, 1 - ((t - 0.30) / 0.34) ** 2)) if t < 0.64 else 0
        upper = 8.0 * math.sqrt(max(0.0, 1 - ((t - 0.78) / 0.23) ** 2)) if t > 0.52 else 0
        w = max(lower, upper)
        return max(w, 6.6) if 0.54 < t < 0.64 else w

    def to_screen(u, v):                             # (u, v) in guitar units, k px each
        u, v = u * k, v * k
        return int(round(cx + u * ca - v * sa)), int(round(cy + (u * sa + v * ca) * SQ))

    def local(x, y):
        fx, fy = x - cx, (y - cy) / SQ
        return (fx * ca + fy * sa) / k, (-fx * sa + fy * ca) / k

    def inside(u, v):
        return -13 <= u <= 14 and abs(v) <= half(u)
    xs, ys = range(int(cx - 24 * k), int(cx + 25 * k)), range(int(cy - 12 * k), int(cy + 14 * k))
    c.shadow(cx, cy + 3, int(20 * k), 3, 110)
    for (bu, bv, r) in ((-12, -8, 9.0), (-4, -9, 5.5), (-17, 2, 4.5)):    # the blood it lies in, out past it
        px, py = to_screen(bu, bv)
        c.ellipse(px, py + 3, r * k, r * k * 0.34, BL_DK)
        c.ellipse(px - 1, py + 2.5, r * k * 0.72, r * k * 0.22, BL)
    rng0 = random.Random(seed + 1)
    for _i in range(7):                                                   # drops flicked off it
        px, py = to_screen(rng0.uniform(-26, -16), rng0.uniform(-14, 6))
        c.put(px, py + 3, BL)
        if rng0.random() < 0.5:
            c.put(px + 1, py + 3, BL_DK)
    for y in ys:                                                          # its side, 3px deep
        for x in xs:
            if inside(*local(x, y - 4)):
                c.put(x, y, SIDE)
    for y in ys:                                                          # the top, sunburst
        for x in xs:
            u, v = local(x, y)
            if not inside(u, v):
                continue
            d = (((u + 5) / 11.0) ** 2 + (v / 10.0) ** 2) ** 0.5
            col = CEN if d < 0.55 else MID if d < 0.9 else EDGE
            if abs(abs(v) - half(u)) < 0.9:
                col = OUT
            c.put(x, y, col)
    hx, hy = to_screen(4, 0)
    c.ellipse(hx, hy, 2.6 * k, 1.3 * k, hexc('120a06'))                          # the sound hole
    for j in range(-3, 4):                                                # the bridge
        c.put(*to_screen(-7, j), OUT)
    rng = random.Random(seed)
    for _i in range(28):                                                  # blood where it hit
        u, v = rng.uniform(-13, -2), rng.uniform(-8, 8)
        if inside(u, v):
            c.put(*to_screen(u, v), BL if rng.random() < 0.6 else BL_DK)
    for t in range(9):                                                    # a crack through the top there
        c.put(*to_screen(-11 + t, -3 + (t % 3) - 1), hexc('1a0c06'))
    for t in [i * 0.5 for i in range(30)]:                                # the neck, to the break
        for v in (-1, 0, 1):
            for dv in (0.0, 0.4):
                px, py = to_screen(14 + t, v + dv)
                c.put(px, py, BOARD if v == 0 else NECK)
                c.put(px, py + 1, SIDE)
    ex, ey = to_screen(29, 0)
    for j in range(3):                                                    # splinters at the break
        c.put(ex + j, ey - j % 2, hexc('b08a5a'))
    for sv in (-1, 1):                                                    # two strings curling off it
        for t in range(10):
            c.put(*to_screen(29 + t * 0.8, sv * 1.5 + math.sin(t * 0.9) * 2.5), hexc('d9d0bc'))
    hdx, hdy = to_screen(35, -11)                                           # the headstock, thrown aside
    a2 = ang + 0.9
    for t in range(int(8 * k)):
        for v in (-2, -1, 0, 1, 2):
            px = int(round(hdx + t * math.cos(a2) - v * math.sin(a2)))
            py = int(round(hdy + (t * math.sin(a2) + v * math.cos(a2)) * SQ * 1.6))
            c.put(px, py, NECK if abs(v) < 2 else OUT)
    for j in range(3):
        c.put(hdx + 2 * j, hdy - 1, hexc('c8c4b8'))                      # its tuners
    c.put(hdx + 3, hdy + 1, BL)
