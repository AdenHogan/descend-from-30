#!/usr/bin/env python3
"""Grid blueprint of a room MODULE: an accurate, to-scale technical diagram showing the
16px tile grid, module size, the interior floor line, every scavenge-node (Marker2D)
position, and the two potential window slots. Gives a clear visual understanding of the
space before art. Reusable for every module — pass a module name.

Data is READ from the module's .tscn (marker names + positions + the ColorRect size), so
the blueprint can never drift from the real scene. Window slots + floor line come from the
constants room.gd uses.

Run:  python3 tools/gen_module_blueprint.py [living_room|bedroom|kitchen|bathroom|study|dining_room]
Writes docs/art_reference/blueprints/<name>_blueprint.png
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
MODULES_DIR = os.path.join(ROOT, "scenes", "Room_Modules")
OUT_DIR = os.path.join(ROOT, "docs", "art_reference", "blueprints")

# --- constants that mirror room.gd / the placement (keep in sync if those change) --------
MODULE_W, MODULE_H = 320, 144          # module box (px); ColorRect size in every module
TILE = 16                              # world tile grid
WINDOW_INSET = 72                      # room.MODULE_WINDOW_INSET
WINDOW_Y_LOCAL = 262 - 224            # room.MODULE_WINDOW_Y(262) - module world-top(224)
FLOOR_Y_LOCAL = 352 - 224             # room._FLOOR_Y(352) world -> module-local
PANE_HW, PANE_HH = 22, 26             # apartment_window pane half-extents
LEFT_WALL_X = 113                      # room.LEFT_WALL_X (world x of module slot 0)

S = 4                                  # px on canvas per module px
MARGIN_L, MARGIN_T, MARGIN_R, MARGIN_B = 96, 140, 392, 116

BG = (18, 21, 28)
GRID_MINOR = (40, 46, 58)
GRID_MAJOR = (60, 68, 84)
INK = (232, 236, 244)
SUB = (150, 158, 172)
OUTLINE = (210, 216, 228)
FLOOR_COL = (224, 170, 92)
ANCHOR_COL = (86, 214, 226)
WINDOW_COL = (240, 196, 96)
BAND_WINDOW = (46, 66, 104, 70)
BAND_FURN = (78, 60, 44, 70)


def _font(bold, size):
    n = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/" + n, size)

F_TITLE = _font(True, 34)
F_SUB = _font(False, 17)
F_LBL = _font(True, 15)
F_SM = _font(False, 13)
F_LEG = _font(False, 15)
F_LEGB = _font(True, 16)


def parse_module(name):
    path = os.path.join(MODULES_DIR, name + ".tscn")
    txt = open(path).read()
    anchors = []
    # [node name="anchor_x" type="Marker2D" ...] \n position = Vector2(a, b)
    for m in re.finditer(r'\[node name="([^"]+)" type="Marker2D"[^\]]*\]\s*\r?\n\s*position = Vector2\(([-\d.]+),\s*([-\d.]+)\)', txt):
        anchors.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return anchors


def mx(x):
    return MARGIN_L + x * S


def my(y):
    return MARGIN_T + y * S


def short(nm):
    return nm.replace("anchor_", "").replace("_", " ")


def build(name):
    anchors = parse_module(name)
    W = MARGIN_L + MODULE_W * S + MARGIN_R
    H = MARGIN_T + MODULE_H * S + MARGIN_B
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img, "RGBA")

    # Title / subtitle
    d.text((MARGIN_L, 34), "%s Module  —  Grid Blueprint" % name.replace("_", " ").title(),
           font=F_TITLE, fill=INK)
    d.text((MARGIN_L, 82),
           "%d × %d px  ·  16px tile grid  ·  local coords, origin (0,0) top-left  ·  "
           "placed in-world at ( %d + slot×%d , 224 )" % (MODULE_W, MODULE_H, LEFT_WALL_X, MODULE_W),
           font=F_SUB, fill=SUB)

    # Bands (drawn first, under the grid): window band (anchor-free) and furniture band.
    anchor_top = min([a[2] for a in anchors]) if anchors else 88
    win_band_bot = min(anchor_top - 6, WINDOW_Y_LOCAL + PANE_HH + 8)
    d.rectangle([mx(0), my(0), mx(MODULE_W), my(win_band_bot)], fill=BAND_WINDOW)
    d.rectangle([mx(0), my(anchor_top - 6), mx(MODULE_W), my(FLOOR_Y_LOCAL)], fill=BAND_FURN)

    # Grid
    for gx in range(0, MODULE_W + 1, TILE):
        col = GRID_MAJOR if gx % (TILE * 4) == 0 else GRID_MINOR
        d.line([mx(gx), my(0), mx(gx), my(MODULE_H)], fill=col, width=1)
    for gy in range(0, MODULE_H + 1, TILE):
        col = GRID_MAJOR if gy % (TILE * 4) == 0 else GRID_MINOR
        d.line([mx(0), my(gy), mx(MODULE_W), my(gy)], fill=col, width=1)

    # Ruler tick labels
    for gx in range(0, MODULE_W + 1, 32):
        d.text((mx(gx) - 9, my(MODULE_H) + 8), str(gx), font=F_SM, fill=SUB)
    for gy in range(0, MODULE_H + 1, 16):
        d.text((MARGIN_L - 34, my(gy) - 7), str(gy), font=F_SM, fill=SUB)

    # Floor line
    fy = my(FLOOR_Y_LOCAL)
    for xseg in range(int(mx(0)), int(mx(MODULE_W)), 16):
        d.line([xseg, fy, xseg + 9, fy], fill=FLOOR_COL, width=3)
    d.text((mx(MODULE_W) - 250, fy + 6), "interior floor  local %d / world 352" % FLOOR_Y_LOCAL,
           font=F_SM, fill=FLOOR_COL)

    # Module outline
    d.rectangle([mx(0), my(0), mx(MODULE_W), my(MODULE_H)], outline=OUTLINE, width=3)

    # Window slots (both potential positions)
    for (wx, tag) in [(WINDOW_INSET, "L"), (MODULE_W - WINDOW_INSET, "R")]:
        rx0, ry0 = mx(wx - PANE_HW), my(WINDOW_Y_LOCAL - PANE_HH)
        rx1, ry1 = mx(wx + PANE_HW), my(WINDOW_Y_LOCAL + PANE_HH)
        d.rectangle([rx0, ry0, rx1, ry1], fill=(240, 196, 96, 40), outline=WINDOW_COL, width=3)
        d.line([(rx0 + rx1) / 2, ry0, (rx0 + rx1) / 2, ry1], fill=WINDOW_COL, width=2)
        d.line([rx0, (ry0 + ry1) / 2, rx1, (ry0 + ry1) / 2], fill=WINDOW_COL, width=2)
        d.text((rx0, ry0 - 20), "WINDOW %s (%d,%d)" % (tag, wx, WINDOW_Y_LOCAL), font=F_LBL, fill=WINDOW_COL)

    # Anchors (scavenge nodes)
    for i, (nm, ax, ay) in enumerate(anchors):
        cx, cy = mx(ax), my(ay)
        r = 7
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ANCHOR_COL, width=3)
        d.line([cx - r - 3, cy, cx + r + 3, cy], fill=ANCHOR_COL, width=1)
        d.line([cx, cy - r - 3, cx, cy + r + 3], fill=ANCHOR_COL, width=1)
        d.text((cx + 11, cy - 16), short(nm), font=F_LBL, fill=ANCHOR_COL)
        d.text((cx + 11, cy + 2), "(%d,%d)" % (ax, ay), font=F_SM, fill=SUB)

    # Dimension arrows
    _dim_h(d, mx(0), mx(MODULE_W), my(0) - 22, "%d px  (%d tiles)" % (MODULE_W, MODULE_W // TILE))
    _dim_v(d, my(0), my(MODULE_H), mx(0) - 60, "%d px (%d tiles)" % (MODULE_H, MODULE_H // TILE))

    # Legend
    _legend(d, W - MARGIN_R + 24, MARGIN_T, anchors)

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, name + "_blueprint.png")
    img.save(out)
    print("wrote", os.path.relpath(out, ROOT), "(%dx%d)" % (W, H))
    return out


def _dim_h(d, x0, x1, y, label):
    d.line([x0, y, x1, y], fill=SUB, width=2)
    d.line([x0, y - 5, x0, y + 5], fill=SUB, width=2)
    d.line([x1, y - 5, x1, y + 5], fill=SUB, width=2)
    tw = d.textlength(label, font=F_SM)
    d.rectangle([(x0 + x1) / 2 - tw / 2 - 5, y - 9, (x0 + x1) / 2 + tw / 2 + 5, y + 9], fill=BG)
    d.text(((x0 + x1) / 2 - tw / 2, y - 7), label, font=F_SM, fill=INK)


def _dim_v(d, y0, y1, x, label):
    d.line([x, y0, x, y1], fill=SUB, width=2)
    d.line([x - 5, y0, x + 5, y0], fill=SUB, width=2)
    d.line([x - 5, y1, x + 5, y1], fill=SUB, width=2)
    img = Image.new("RGBA", (int(d.textlength(label, font=F_SM)) + 6, 20), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((3, 3), label, font=F_SM, fill=INK)
    img = img.rotate(90, expand=True)
    d._image.paste(img, (int(x) - 22, int((y0 + y1) / 2) - img.height // 2), img)


def _legend(d, x, y, anchors):
    d.text((x, y), "LEGEND", font=F_LEGB, fill=INK)
    y += 30
    rows = [
        (GRID_MAJOR, "16 px tile grid (major every 4 tiles)"),
        (OUTLINE, "Module box  320 x 144"),
        (FLOOR_COL, "Interior floor  (local 128 / world 352)"),
        (WINDOW_COL, "Window slot  (44x52 pane)"),
        (ANCHOR_COL, "Scavenge node (Marker2D)"),
    ]
    for col, txt in rows:
        d.rectangle([x, y + 3, x + 16, y + 15], fill=col if len(col) == 3 else col[:3])
        d.text((x + 24, y), txt, font=F_LEG, fill=INK)
        y += 24
    y += 10
    d.text((x, y), "SCAVENGE NODES (%d)" % len(anchors), font=F_LEGB, fill=ANCHOR_COL)
    y += 26
    for nm, ax, ay in anchors:
        d.text((x, y), "• %s" % short(nm), font=F_LEG, fill=INK)
        d.text((x + 250, y), "(%d,%d)" % (ax, ay), font=F_SM, fill=SUB)
        y += 22
    y += 10
    d.text((x, y), "WINDOWS", font=F_LEGB, fill=WINDOW_COL)
    y += 26
    for line in [
        "• Two potential slots: L (%d,%d), R (%d,%d)" % (WINDOW_INSET, WINDOW_Y_LOCAL, MODULE_W - WINDOW_INSET, WINDOW_Y_LOCAL),
        "• One seeded per module today",
        "  (except a balcony module).",
        "• Natural mid-upper-wall height, ABOVE",
        "  the furniture nodes (a node may sit",
        "  under a window — that's fine).",
        "• Art may use one / both / none per",
        "  module design to vary the room look.",
    ]:
        d.text((x, y), line, font=F_LEG, fill=INK if line.startswith("•") else SUB)
        y += 22


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "living_room"
    build(name)
