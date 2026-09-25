#!/usr/bin/env python3
"""BEHIND-THE-SCENES blueprint of every apartment room MODULE (owner round 13b — "blueprints for how
our modules will look behind the scenes with clear lines for all y planes, and nodes available").

For each module variant: its art (dimmed) under a 16px grid, EVERY Y plane the game uses in a room
(module-local y and world y), the zones the art pipeline keeps bare (window boxes, the side-wall
sample columns, the balcony strip), every scavenge node by kind (front / back plane / balcony strip),
the player to scale on the walking lane, and each BACK-PLANE spot: where the player steps up to, its
stand zone (must be bare floor — blue = clear, red = something stands there) and the player to scale
up there.

Everything is READ, never typed in: nodes (+ their back_plane / balcony_strip flags) from the module
.tscn, the art + floor-only strip from assets/rooms/, the planes from the constants below which
mirror scripts/room.gd, scripts/module_walls.gd, tools/art/pixlib.py and docs/Y_PLANES.md (keep them
in sync — they're the same numbers the game uses), and the player's size MEASURED from its sprite.

Run:  python3 tools/gen_module_blueprint.py            (all 30 modules + one sheet per room type)
      python3 tools/gen_module_blueprint.py study_b    (one)
Out:  docs/art_reference/blueprints/<module>_blueprint.png, <type>_sheet.png, y_planes_key.png
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODULES_DIR = os.path.join(ROOT, "scenes", "Room_Modules")
ROOMS_DIR = os.path.join(ROOT, "assets", "rooms")
OUT_DIR = os.path.join(ROOT, "docs", "art_reference", "blueprints")
TYPES = ["living_room", "bedroom", "kitchen", "bathroom", "study", "dining_room"]
BALCONY_TYPES = ("study", "dining_room")             # tools/art/modscene.py

# --- the room's geometry (module-local y = world y - 224; module box 320 x 144 at world y 224) ------
MW, MH, TILE = 320, 144, 16
WORLD_TOP = 224
WIN_L, WIN_R = (50, 10, 94, 66), (226, 10, 270, 66)  # pixlib.WIN_L / WIN_R (pane + frame, bare wall)
EDGE_COLS = (3, MW - 4)                              # pixlib.EDGE_COLS (module_walls samples the walls)
STRIP_X = (4, 96)                                    # pixlib.BALCONY_BOX
NODE_MIN_Y = 40                                      # pixlib: nodes sit at y >= 40
SEAM = 100                                           # 324 — wall meets floor; set-back furniture's base
LANE_FEET = 353 - WORLD_TOP                          # 129 — room.ROOM_FEET_Y
BACK_FEET = LANE_FEET - 14                           # 115 — room.BACK_PLANE_RISE
BALC_FEET = LANE_FEET - 25                           # 104 — enemy_plane.RISE / player BALCONY_PLANE_RISE
FLOOR_LINE = 352 - WORLD_TOP                         # 128 — room._FLOOR_Y
FRONT_CUT = 360 - WORLD_TOP                          # 136 — module_walls front cut plane
LINTEL = 247 - WORLD_TOP                             # 23  — interior doorway lintel (module_walls DOOR_ROWS)
BP_ROWS = (102, 114)                                 # pixlib.BP_ROWS — the back-plane stand zone
BP_HALF_W = 13                                       # pixlib.BP_HALF_W
BP_CLUSTER = 40                                      # room.BACK_SPOT_CLUSTER
BACK_SCALE = 0.89                                    # s(339)/s(353), docs/Y_PLANES.md

PLANES = [  # (y, label, world, colour, style)
    (0, "ceiling / back-wall top", 224, (150, 158, 172), "solid"),
    (LINTEL, "doorway lintel (interior doors)", 247, (150, 158, 172), "dash"),
    (NODE_MIN_Y, "node line: no scavenge node above", 264, (236, 120, 170), "dash"),
    (SEAM, "wall / floor seam = SET-BACK furniture base", 324, (226, 150, 84), "solid"),
    (BALC_FEET, "BALCONY plane feet (balcony slot)", 328, (112, 214, 120), "dash"),
    (BACK_FEET, "BACK PLANE feet (step up to set-back furniture)", 339, (96, 168, 255), "solid"),
    (FLOOR_LINE, "interior floor", 352, (190, 160, 120), "dot"),
    (LANE_FEET, "WALKING LANE feet (actors stand here)", 353, (255, 214, 64), "solid"),
    (FRONT_CUT, "front cut plane", 360, (150, 158, 172), "dash"),
    (MH, "module bottom", 368, (150, 158, 172), "solid"),
]

C_FRONT, C_BACK, C_STRIP = (255, 196, 48), (96, 168, 255), (112, 214, 120)
BG, INK, SUB = (16, 19, 26), (232, 236, 244), (150, 158, 172)
S = 3
ML, MT, MR, MB = 74, 112, 420, 118


def _font(bold, size):
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/" + ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"), size)


F_T, F_S, F_L, F_M, F_B = _font(True, 28), _font(False, 15), _font(True, 13), _font(False, 12), _font(True, 15)


def player_size():
    """MEASURED from the idle sheet at the in-game scale (x2): (height, body width)."""
    p = os.path.join(ROOT, "assets", "2D-Pixel-Art-Character-Template", "Idle", "Player Idle 48x48.png")
    fr = Image.open(p).convert("RGBA").crop((0, 0, 48, 48))
    bb = fr.getbbox()
    cols = [x for x in range(48) if sum(1 for y in range(48) if fr.getpixel((x, y))[3] > 0) >= 8]
    return (bb[3] - bb[1]) * 2, (cols[-1] - cols[0] + 1) * 2


PLAYER_H, PLAYER_W = player_size()


def parse_nodes(name):
    txt = open(os.path.join(MODULES_DIR, name + ".tscn")).read()
    out = []
    for m in re.finditer(r'\[node name="([^"]+)" type="Marker2D"[^\]]*\]\s*\n\s*position = Vector2\(([-\d.]+),\s*([-\d.]+)\)((?:\s*\n\s*metadata/\w+ = \w+)*)', txt):
        meta = m.group(4)
        out.append({"name": m.group(1), "x": float(m.group(2)), "y": float(m.group(3)),
                    "bp": "back_plane = true" in meta, "strip": "balcony_strip = true" in meta})
    return out


def room_type(name):
    for t in sorted(TYPES, key=len, reverse=True):
        if name == t or name.startswith(t + "_"):
            return t
    return name


def spot_centres(nodes):
    """Every place a back-plane spot can centre: each cluster of bp nodes as spawned (any subset of a
    run of nodes <= BP_CLUSTER apart) — room.gd centres the spot on the nodes that spawned."""
    xs = sorted(n["x"] for n in nodes if n["bp"])
    groups, cur = [], []
    for x in xs:
        if cur and x - cur[-1] > BP_CLUSTER:
            groups.append(cur)
            cur = []
        cur.append(x)
    if cur:
        groups.append(cur)
    return groups


def blocked_columns(name, lo, hi):
    """Columns in [lo, hi] where something stands through the whole stand zone (pixlib's test)."""
    art = Image.open(os.path.join(ROOMS_DIR, name + ".png")).convert("RGBA")
    fl = Image.open(os.path.join(ROOMS_DIR, name + "_floor.png")).convert("RGBA")
    strip_p = os.path.join(ROOMS_DIR, name + "_strip.png")
    if os.path.exists(strip_p):
        st = Image.open(strip_p).convert("RGBA")
        art = art.copy()
        art.alpha_composite(st)
    bad = []
    for x in range(max(0, int(lo)), min(MW - 1, int(hi)) + 1):
        if all(art.getpixel((x, y)) != fl.getpixel((x, y - SEAM)) for y in range(BP_ROWS[0], BP_ROWS[1] + 1)):
            bad.append(x)
    return bad


def X(x):
    return ML + x * S


def Y(y):
    return MT + y * S


def _hline(d, y, col, style, x0=0, x1=MW):
    a, b = X(x0), X(x1)
    if style == "solid":
        d.line([a, Y(y), b, Y(y)], fill=col, width=2)
        return
    step, on = (14, 8) if style == "dash" else (6, 2)
    for xx in range(a, b, step):
        d.line([xx, Y(y), min(xx + on, b), Y(y)], fill=col, width=2)


def _ghost(d, cx, feet, scale, col, label=None):
    h, w = PLAYER_H * scale, PLAYER_W * scale
    top = feet - h
    d.rounded_rectangle([X(cx - w / 2), Y(top), X(cx + w / 2), Y(feet)], radius=int(w * S / 2.4),
                        outline=col, width=2)
    d.ellipse([X(cx - w * 0.28), Y(top + 1), X(cx + w * 0.28), Y(top + w * 0.56 + 1)], outline=col, width=1)
    if label:
        d.text((X(cx) - d.textlength(label, font=F_M) / 2, Y(top) - 16), label, font=F_M, fill=col)


def build(name, out_dir=OUT_DIR):
    t = room_type(name)
    nodes = parse_nodes(name)
    Wc, Hc = ML + MW * S + MR, MT + MH * S + MB
    img = Image.new("RGB", (Wc, Hc), BG)
    art = Image.open(os.path.join(ROOMS_DIR, name + ".png")).convert("RGBA")
    strip_p = os.path.join(ROOMS_DIR, name + "_strip.png")
    if os.path.exists(strip_p):
        art.alpha_composite(Image.open(strip_p).convert("RGBA"))
    art = ImageEnhance.Brightness(ImageEnhance.Color(art.convert("RGB")).enhance(0.55)).enhance(0.5)
    img.paste(art.resize((MW * S, MH * S), Image.NEAREST), (ML, MT))
    d = ImageDraw.Draw(img, "RGBA")

    d.text((ML, 22), "%s  —  behind the scenes" % name, font=F_T, fill=INK)
    d.text((ML, 62), "module 320 x 144 · local (0,0) top-left · world = (113 + slot x 320 + x, 224 + y) · "
                     "player %d px tall, body %d px (measured)" % (PLAYER_H, PLAYER_W), font=F_S, fill=SUB)

    for gx in range(0, MW + 1, TILE):                                  # the tile grid
        d.line([X(gx), Y(0), X(gx), Y(MH)], fill=(255, 255, 255, 34 if gx % 64 else 60), width=1)
    for gy in range(0, MH + 1, TILE):
        d.line([X(0), Y(gy), X(MW), Y(gy)], fill=(255, 255, 255, 34 if gy % 64 else 60), width=1)
    for gx in range(0, MW + 1, 32):
        d.text((X(gx) - 8, Y(MH) + 6), str(gx), font=F_M, fill=SUB)

    # kept-bare zones: window boxes, the wall-face sample columns, the balcony strip
    for (x0, y0, x1, y1), tag in ((WIN_L, "L"), (WIN_R, "R")):
        d.rectangle([X(x0), Y(y0), X(x1 + 1), Y(y1 + 1)], fill=(240, 196, 96, 36), outline=(240, 196, 96), width=2)
        d.text((X(x0) + 4, Y(y0) + 3), "window %s (bare wall)" % tag, font=F_M, fill=(240, 196, 96))
    for ex in EDGE_COLS:
        d.rectangle([X(ex), Y(0), X(ex + 1), Y(SEAM)], fill=(214, 110, 214, 140))
    if t in BALCONY_TYPES:
        x0, x1 = STRIP_X
        for k in range(X(x0) - MH * S, X(x1 + 1), 14):                 # hatching
            d.line([max(k, X(x0)), Y(MH) - max(0, X(x0) - k), min(k + MH * S, X(x1 + 1)),
                    Y(MH) - min(MH * S, X(x1 + 1) - k)], fill=(112, 214, 120, 40), width=2)
        d.rectangle([X(x0), Y(0), X(x1 + 1), Y(MH)], outline=C_STRIP, width=2)
        d.text((X(x0) + 4, Y(MH) - 18), "BALCONY STRIP (its furniture + nodes go on a balcony slot)",
               font=F_M, fill=C_STRIP)

    # every Y plane
    for (py, label, world, col, style) in PLANES:
        if py == BALC_FEET and t not in BALCONY_TYPES:
            continue
        _hline(d, py, col, style)
    # the front-furniture base band (bracket in the margin)
    d.rectangle([X(MW) + 6, Y(114), X(MW) + 12, Y(122)], fill=(200, 200, 200, 120))

    # back-plane spots: stand zone clear/blocked + the player up there
    for grp in spot_centres(nodes):
        lo, hi = min(grp) - BP_HALF_W, max(grp) + BP_HALF_W
        bad = blocked_columns(name, lo, hi)
        col = (230, 70, 70) if bad else C_BACK
        d.rectangle([X(lo), Y(BP_ROWS[0]), X(hi + 1), Y(BP_ROWS[1] + 1)], fill=col + (70,), outline=col, width=2)
        for bx in bad:
            d.line([X(bx), Y(BP_ROWS[0]), X(bx), Y(BP_ROWS[1] + 1)], fill=(255, 90, 90), width=2)
        _ghost(d, (min(grp) + max(grp)) / 2.0, BACK_FEET, BACK_SCALE, col, "step-up spot" + (" BLOCKED" if bad else ""))
    # the player on the walking lane, somewhere clear of the nodes' labels
    lane_x = max(range(24, MW - 24, 4), key=lambda x: min([abs(x - n["x"]) for n in nodes] or [MW]))
    _ghost(d, lane_x, LANE_FEET, 1.0, C_FRONT, "player on the lane")

    # the nodes
    for n in nodes:
        col = C_STRIP if n["strip"] else C_BACK if n["bp"] else C_FRONT
        cx, cy = X(n["x"]), Y(n["y"])
        d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=col, width=3)
        d.line([cx - 10, cy, cx + 10, cy], fill=col, width=1)
        d.line([cx, cy - 10, cx, cy + 10], fill=col, width=1)
        d.text((cx + 10, cy - 15), n["name"].replace("anchor_", ""), font=F_M, fill=col)

    # right margin: the planes, then the nodes
    x = X(MW) + 20
    y = MT - 4
    d.text((x, y), "Y PLANES   local / world", font=F_B, fill=INK)
    y += 24
    for (py, label, world, col, style) in PLANES:
        if py == BALC_FEET and t not in BALCONY_TYPES:
            continue
        d.line([x, y + 8, x + 22, y + 8], fill=col, width=3)
        d.text((x + 30, y), "%3d / %d  %s" % (py, world, label), font=F_M, fill=INK)
        y += 19
    d.text((x + 30, y), "114-122  front furniture bases (grey bracket)", font=F_M, fill=SUB)
    y += 19
    d.text((x + 30, y), "102-114  back-plane STAND ZONE: bare floor", font=F_M, fill=C_BACK)
    y += 30
    front = [n for n in nodes if not n["bp"]]
    back = [n for n in nodes if n["bp"] and not n["strip"]]
    strip = [n for n in nodes if n["strip"]]
    d.text((x, y), "NODES  %d  (front %d · back plane %d%s)" % (len(nodes), len(front), len(back),
           (" · strip %d" % len(strip)) if strip else ""), font=F_B, fill=INK)
    y += 24
    for group, col, tag in ((front, C_FRONT, "front — from the lane"), (back, C_BACK, "back plane — step up"),
                            (strip, C_STRIP, "balcony strip — step up")):
        for n in group:
            d.ellipse([x + 4, y + 3, x + 14, y + 13], outline=col, width=2)
            d.text((x + 22, y), "%s (%d,%d)" % (n["name"].replace("anchor_", ""), n["x"], n["y"]), font=F_M, fill=INK)
            y += 17
        if group:
            d.text((x + 22, y), tag, font=F_M, fill=col)
            y += 21

    # bottom key, two columns
    keys = ((C_FRONT, "front node (reached from the walking lane)"), (C_BACK, "back-plane node / clear stand zone"),
            ((230, 70, 70), "stand zone BLOCKED by a front piece"), (C_STRIP, "balcony-strip node / the strip"),
            ((240, 196, 96), "window box (kept bare wall)"), ((214, 110, 214), "wall-face sample columns x 3 / 316"))
    for i, (col, txt) in enumerate(keys):
        kx, ky = ML + (i // 3) * 470, Y(MH) + 30 + (i % 3) * 18
        d.rectangle([kx, ky + 3, kx + 12, ky + 15], fill=col)
        d.text((kx + 20, ky), txt, font=F_M, fill=INK)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + "_blueprint.png")
    img.save(path)
    return path, img


def all_modules():
    return sorted(f[:-5] for f in os.listdir(MODULES_DIR) if f.endswith(".tscn"))


def sheets(built):
    by_type = {}
    for name, img in built:
        by_type.setdefault(room_type(name), []).append((name, img))
    for t, items in by_type.items():
        items.sort()
        w, h = items[0][1].size
        sw, sh = w // 2, h // 2
        sheet = Image.new("RGB", (sw, sh * len(items)), BG)
        for i, (_, im) in enumerate(items):
            sheet.paste(im.resize((sw, sh), Image.LANCZOS), (0, i * sh))
        sheet.save(os.path.join(OUT_DIR, t + "_sheet.png"))


if __name__ == "__main__":
    names = sys.argv[1:] or all_modules()
    built = []
    for n in names:
        p, im = build(n)
        built.append((n, im))
        print("wrote", os.path.relpath(p, ROOT))
    if not sys.argv[1:]:
        sheets(built)
        print("wrote %d type sheets" % len(TYPES))
