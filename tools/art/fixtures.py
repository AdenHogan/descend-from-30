"""The corridor's every-floor FIXTURES, redrawn for clarity (owner round 25: "cleaning art for immersion and
visual clarity" — at true size the lift was a flat grey slab in a black frame, the wall extinguisher a red
block, and the EXIT sign an unlabelled green box).

  Elevator.png (66x88)        -> assets/Elevator.png      brushed-steel doors in a bronze frame. The two
                                 33px halves slide apart in building_floors._board_elevator and merchant.gd,
                                 so the size + the "each half carries its own frame edge" rule stay.
  extinguisher_wall (16x44)   -> assets/corridor/fixtures/extinguisher_wall.png   a wall-mounted unit with
                                 bracket straps, hose, gauge and lever (scripts/world_drop.gd draws it).
  exit_sign(c)                                            a green EXIT sign with the running figure, used by
                                 tools/art/corridor.py in every corridor image.

Run:  python3 tools/art/fixtures.py     (writes the two PNGs + docs/art_reference/fixtures.png)
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, hexc, shade  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


def _n(x, y, salt=0):
    """A cheap deterministic hash in [0, 1)."""
    v = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0


# ------------------------------------------------------------------------------------------ elevator
def elevator():
    W, H = 66, 88
    c = Canvas(W, H)
    frame = hexc('54402c')
    steel = hexc('a3aab0')
    # the FRAME: a bronze surround with a lit inner lip (each half carries its own edge, so it slides intact)
    c.rect(0, 0, W - 1, H - 1, shade(frame, 0.55))                        # the dark reveal behind everything
    c.rect(0, 0, W - 1, 3, frame)                                          # the header
    c.hline(0, W - 1, 0, shade(frame, 1.35))
    c.hline(1, W - 2, 3, shade(frame, 1.6))                                # its lit lower lip
    for x0, x1, lit in ((0, 2, 1.35), (W - 3, W - 1, 0.8)):                # the jambs
        c.rect(x0, 0, x1, H - 1, frame)
        c.vline(x0 if lit > 1 else x1, 0, H - 1, shade(frame, lit))
    c.vline(3, 4, H - 5, shade(frame, 1.5)); c.vline(W - 4, 4, H - 5, shade(frame, 0.65))
    # the two LEAVES: brushed steel, streaked, with a soft diagonal reflection and recessed panels
    for lx0, lx1 in ((4, 31), (34, 61)):
        for y in range(4, H - 4):
            for x in range(lx0, lx1 + 1):
                k = 0.90 + 0.20 * _n(x, 0, 3)                              # vertical brushing: per column
                k += 0.05 * (_n(x, y, 5) - 0.5)                            # a little grain
                d = (x - lx0) + (y - 4) * 0.55                             # a diagonal band of reflected light
                k += 0.13 * max(0.0, 1.0 - abs(d - 20) / 9.0)
                k += 0.05 * max(0.0, 1.0 - abs(d - 46) / 5.0)
                c.put(x, y, shade(steel, k) if k <= 1.0 else shade(steel, k))
        # recessed panels: a dark top/left groove, a lit bottom/right edge
        for (py0, py1) in ((10, 44), (49, 80)):
            px0, px1 = lx0 + 3, lx1 - 3
            c.hline(px0, px1, py0, shade(steel, 0.62)); c.vline(px0, py0, py1, shade(steel, 0.68))
            c.hline(px0, px1, py1, shade(steel, 1.22)); c.vline(px1, py0, py1, shade(steel, 1.15))
        c.vline(lx0, 4, H - 5, shade(steel, 1.2)); c.vline(lx1, 4, H - 5, shade(steel, 0.62))   # the leaf edges
    # the MEETING SEAM: a dark slit down the middle, lit either side
    c.vline(32, 4, H - 5, hexc('0c0c0e')); c.vline(33, 4, H - 5, hexc('0c0c0e'))
    # a door-hanging bar across the top of the leaves, and the sill at the foot
    c.hline(4, 61, 5, shade(steel, 0.55)); c.hline(4, 61, 6, shade(steel, 1.25))
    c.rect(3, H - 5, W - 4, H - 1, hexc('2a2520'))                         # the threshold
    c.hline(3, W - 4, H - 5, shade(hexc('8a8478'), 1.05))                  # its worn brass edge
    for x in range(6, W - 6, 4):
        c.put(x, H - 3, hexc('4a423a'))                                    # the track grooves
    # life on the doors: scuffs at knee height, a dent, a thumbprint smear where a hand pushes
    for (x, y, k) in ((9, 70, 0.72), (10, 70, 0.72), (11, 71, 0.8), (46, 66, 0.74), (47, 67, 0.74), (54, 72, 0.78)):
        c.put(x, y, shade(steel, k))
    c.rect(24, 40, 28, 42, shade(steel, 1.12))
    return c.img


# ------------------------------------------------------------------------------------ extinguisher
def extinguisher():
    W, H = 16, 44
    c = Canvas(W, H)
    red = hexc('c4241c')
    x0, x1 = 3, 12                                                          # the cylinder, 10 wide
    top, bot = 13, 39
    # the wall bracket: two dark straps round it, and a back plate
    c.rect(2, top + 3, 13, top + 5, hexc('2a2a30')); c.rect(2, bot - 7, 13, bot - 5, hexc('2a2a30'))
    c.hline(2, 13, top + 3, hexc('5a5a64')); c.hline(2, 13, bot - 7, hexc('5a5a64'))
    # the body: shaded across (lit from the left), with a domed shoulder
    for y in range(top, bot + 1):
        for x in range(x0, x1 + 1):
            t = (x - x0) / float(x1 - x0)
            k = 1.28 - 0.62 * t if t < 0.22 else (1.0 - 0.55 * (t - 0.22) / 0.78)
            c.put(x, y, shade(red, k))
    for (y, ins) in ((top - 1, 2), (top, 1)):                               # the shoulder
        for x in range(x0 + ins, x1 - ins + 1):
            c.put(x, y, shade(red, 1.15 if x < 7 else 0.85))
    c.hline(x0 + 1, x1 - 1, bot + 1, shade(red, 0.5))                      # the rolled base
    c.hline(x0, x1, bot, shade(red, 0.62))
    # the label: cream, with a flame pictogram and lines of small print
    c.rect(x0 + 1, top + 9, x1 - 1, top + 20, hexc('ece4d2'))
    c.vline(x1 - 1, top + 9, top + 20, hexc('b8b09c'))
    for (fx, fy) in ((6, top + 11), (6, top + 12), (5, top + 13), (6, top + 13), (7, top + 13), (6, top + 14)):
        c.put(fx, fy, hexc('e8781a'))
    c.put(6, top + 11, hexc('f8c030'))
    c.hline(x0 + 2, x1 - 2, top + 16, hexc('7a7468')); c.hline(x0 + 2, x1 - 3, top + 18, hexc('9a9488'))
    # the neck, valve head, lever, gauge
    c.rect(6, top - 3, 9, top - 2, hexc('a8aab0'))
    c.rect(5, top - 6, 10, top - 4, hexc('7a7c84')); c.hline(5, 10, top - 6, hexc('c0c2c8'))
    c.line(5, top - 7, 13, top - 9, hexc('b4b6bc')); c.line(5, top - 6, 13, top - 8, hexc('6a6c74'))   # the lever
    c.rect(2, top - 5, 4, top - 3, hexc('e8e4d8')); c.put(3, top - 4, hexc('3aa04a')); c.put(2, top - 4, hexc('c83a2a'))  # gauge
    # the hose: from the valve, a black loop down the right side to the nozzle clipped by the strap
    for (hx, hy) in ((10, top - 4), (11, top - 3), (12, top - 2), (13, top - 1), (13, top), (14, top + 3),
                     (14, top + 6), (14, top + 9), (14, top + 12), (13, top + 14)):
        c.put(hx, hy, hexc('1c1c20'))
    c.rect(12, top + 14, 14, top + 17, hexc('2a2a30')); c.put(14, top + 17, hexc('5a5a64'))   # the nozzle
    return c.img


# ------------------------------------------------------------------------------------------- exit sign
def exit_sign(c):
    """A green EXIT sign, 13x11 at (860, 40): the white running figure heading for the arrow, lit face."""
    x, y = 860, 40
    c.box(x, y, x + 12, y + 10, hexc('2c7a44'), hexc('143a22'))
    c.hline(x + 1, x + 11, y + 1, hexc('4aa866'))                           # the lit top edge
    fig = (('..#....', '..#....', '.###...', '#.#.#..', '..#....', '.#.#...', '#...#..'))   # 7 rows x 7 cols
    for r, row in enumerate(fig):
        for cx, ch in enumerate(row):
            if ch == '#':
                c.put(x + 2 + cx, y + 2 + r, hexc('f2f6ee'))
    for (dx, dy) in ((9, 5), (10, 5), (10, 4), (10, 6)):                    # the arrow, pointing right
        c.put(x + dx, y + dy, hexc('f2f6ee'))
    c.put(x + 8, y + 5, hexc('f2f6ee'))


def main():
    out = os.path.join(ROOT, 'assets', 'Elevator.png')
    elevator().save(out)
    fx = os.path.join(ROOT, 'assets', 'corridor', 'fixtures')
    os.makedirs(fx, exist_ok=True)
    extinguisher().save(os.path.join(fx, 'extinguisher_wall.png'))
    # a preview: each at 4x on a wall-ish swatch, with the exit sign drawn onto a strip
    pv = Canvas(40, 16)
    pv.rect(0, 0, 39, 15, hexc('40554c'))
    strip = Canvas(80, 60)
    strip.rect(0, 0, 79, 59, hexc('40554c'))
    tmp = Canvas(900, 60)
    exit_sign(tmp)
    sign = tmp.img.crop((858, 38, 875, 53))
    sheet = Image.new('RGBA', (66 * 4 + 16 * 4 + 20 * 4 + 40, 88 * 4), (64, 85, 76, 255))
    sheet.alpha_composite(elevator().resize((66 * 4, 88 * 4), Image.NEAREST), (10, 0))
    sheet.alpha_composite(extinguisher().resize((16 * 4, 44 * 4), Image.NEAREST), (66 * 4 + 24, 40))
    sheet.alpha_composite(sign.resize((sign.width * 4, sign.height * 4), Image.NEAREST), (66 * 4 + 24 + 16 * 4 + 20, 40))
    p = os.path.join(ROOT, 'docs', 'art_reference', 'fixtures.png')
    sheet.save(p)
    print('wrote', out, fx, p)


if __name__ == '__main__':
    main()
