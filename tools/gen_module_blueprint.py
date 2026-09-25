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

LOCKED (owner round 13c — "lock in those blueprints to a blueprint folder that can act as a defining
template structure for our scavenging nodes and rooms … if we use other artists"): docs/blueprints/ is
the room-module TEMPLATE. `--check` (run by tools/run_all_tests.sh) regenerates everything in memory
and fails if a committed blueprint is stale or missing, or any back-plane spot is blocked.

Run:  python3 tools/gen_module_blueprint.py            (everything: templates, 30 rooms, 6 sheets)
      python3 tools/gen_module_blueprint.py study_b    (one room)
      python3 tools/gen_module_blueprint.py --check    (the gate: are the committed files current?)
Out:  docs/blueprints/template/  module_template.png, module_template_balcony.png (blank, annotated),
                                 module_guide_1x.png, module_guide_balcony_1x.png (320x144 guide LAYERS
                                 to draw over — transparent, pixel-exact)
      docs/blueprints/rooms/<type>/<module>_blueprint.png + <type>_sheet.png
"""
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MODULES_DIR = os.path.join(ROOT, "scenes", "Room_Modules")
ROOMS_DIR = os.path.join(ROOT, "assets", "rooms")
OUT_DIR = os.path.join(ROOT, "docs", "blueprints")
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

def anchor_ranges():
    """room.gd ANCHOR_RANGES — how many of a room type's nodes one visit activates (READ, not typed)."""
    txt = open(os.path.join(ROOT, "scripts", "room.gd")).read()
    block = re.search(r"const ANCHOR_RANGES = \{(.*?)\}", txt, re.S).group(1)
    return {m.group(1): (int(m.group(2)), int(m.group(3)))
            for m in re.finditer(r'"(\w+)":\s*\[(\d+),\s*(\d+)\]', block)}


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


def build(name, template=None):
    """A room's blueprint — or, with template='standard'|'balcony', the BLANK annotated template."""
    t = room_type(name) if template is None else ("study" if template == "balcony" else "")
    nodes = parse_nodes(name) if template is None else []
    Wc, Hc = ML + MW * S + MR, MT + MH * S + MB
    img = Image.new("RGB", (Wc, Hc), BG)
    if template is None:
        art = Image.open(os.path.join(ROOMS_DIR, name + ".png")).convert("RGBA")
        strip_p = os.path.join(ROOMS_DIR, name + "_strip.png")
        if os.path.exists(strip_p):
            art.alpha_composite(Image.open(strip_p).convert("RGBA"))
        art = ImageEnhance.Brightness(ImageEnhance.Color(art.convert("RGB")).enhance(0.55)).enhance(0.5)
        img.paste(art.resize((MW * S, MH * S), Image.NEAREST), (ML, MT))
    d = ImageDraw.Draw(img, "RGBA")
    if template is not None:
        d.rectangle([X(0), Y(0), X(MW), Y(SEAM)], fill=(44, 50, 62))            # the back wall
        d.rectangle([X(0), Y(SEAM), X(MW), Y(MH)], fill=(34, 30, 28))           # the floor
        zones = [(0, NODE_MIN_Y, "WALL: pictures, clocks, shelf tops. No nodes up here."),
                 (NODE_MIN_Y, SEAM, "SET-BACK furniture: against the wall, base on y 100 (blue nodes)"),
                 (SEAM + 2, 114, "STAND ZONE: bare floor in front of back-plane nodes (±13 px)"),
                 (114, 123, "FRONT furniture: bases on 114-122 (gold nodes)"),
                 (123, MH, "WALKING LANE: keep clear, only flat things (rugs) below 122")]
        for (y0, y1, txt) in zones:
            d.text((X(100), Y((y0 + y1) / 2.0) - 8), txt, font=F_M, fill=(206, 212, 224))
        _ghost(d, 268, LANE_FEET, 1.0, C_FRONT, "on the lane")
        _ghost(d, 300, BACK_FEET, BACK_SCALE, C_BACK, "stepped up")
        if template == "balcony":
            _ghost(d, 50, BALC_FEET, BACK_SCALE, C_STRIP, "on a balcony")

    title = name if template is None else ("MODULE TEMPLATE — " + ("balcony-capable room (study, dining room)"
                                                                     if template == "balcony" else "any room"))
    d.text((ML, 22), title + ("  —  behind the scenes" if template is None else ""), font=F_T, fill=INK)
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
    if template is None:
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
    if template is not None:
        for line, col in (("NODES (scavenge spots)", INK), ("gold  = FRONT: on front furniture, >= 2", C_FRONT),
                          ("blue  = BACK PLANE: on set-back furniture", C_BACK),
                          ("green = BALCONY STRIP (study / dining)", C_STRIP),
                          ("all at y >= 40, ON something drawn;", SUB), ("~5-8 per room, one piece every 50-60 px;", SUB),
                          ("back-plane nodes <= 40 px apart share", SUB), ("one step-up spot.", SUB)):
            d.text((x, y), line, font=F_B if col == INK else F_M, fill=col)
            y += 22 if col == INK else 17
    else:
        lo, hi = anchor_ranges().get(t, (0, 0))
        d.text((x, y), "NODES  %d  (front %d · back plane %d%s)" % (len(nodes), len(front), len(back),
               (" · strip %d" % len(strip)) if strip else ""), font=F_B, fill=INK)
        y += 20
        d.text((x, y), "a visit activates %d-%d of them (room.gd ANCHOR_RANGES)" % (lo, hi), font=F_M, fill=SUB)
        y += 22
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
    return img


def guide_layer(balcony):
    """A 320 x 144 TRANSPARENT guide layer, pixel-exact at 1x — put it on a layer over (or under) the
    art in any editor: the planes, the kept-bare boxes and columns, the stand-zone band."""
    g = Image.new("RGBA", (MW, MH), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    for (x0, y0, x1, y1) in (WIN_L, WIN_R):
        d.rectangle([x0, y0, x1, y1], fill=(240, 196, 96, 50), outline=(240, 196, 96, 220))
    for ex in EDGE_COLS:
        d.line([ex, 0, ex, SEAM - 1], fill=(214, 110, 214, 220))
    if balcony:
        d.rectangle([STRIP_X[0], 0, STRIP_X[1], MH - 1], outline=(112, 214, 120, 220))
    d.rectangle([0, BP_ROWS[0], MW - 1, BP_ROWS[1]], fill=(96, 168, 255, 40))
    d.rectangle([0, 114, MW - 1, 122], fill=(200, 200, 200, 26))
    for (py, label, world, col, style) in PLANES:
        if py == BALC_FEET and not balcony:
            continue
        yy = min(py, MH - 1)
        for x in range(MW):
            if style == "solid" or (style == "dash" and x % 6 < 4) or (style == "dot" and x % 3 == 0):
                g.putpixel((x, yy), col + (220,))
    return g


def all_modules():
    return sorted(f[:-5] for f in os.listdir(MODULES_DIR) if f.endswith(".tscn"))


def sheet(items):
    w, h = items[0][1].size
    sw, sh = w // 2, h // 2
    out = Image.new("RGB", (sw, sh * len(items)), BG)
    for i, (_, im) in enumerate(sorted(items, key=lambda it: it[0])):
        out.paste(im.resize((sw, sh), Image.LANCZOS), (0, i * sh))
    return out


def everything():
    """{relative path under docs/blueprints: image} — the whole locked folder, in memory."""
    out = {
        "template/module_template.png": build("template", template="standard"),
        "template/module_template_balcony.png": build("template", template="balcony"),
        "template/module_guide_1x.png": guide_layer(False),
        "template/module_guide_balcony_1x.png": guide_layer(True),
    }
    by_type = {}
    for n in all_modules():
        im = build(n)
        t = room_type(n)
        out["rooms/%s/%s_blueprint.png" % (t, n)] = im
        by_type.setdefault(t, []).append((n, im))
    for t, items in by_type.items():
        out["rooms/%s/%s_sheet.png" % (t, t)] = sheet(items)
    return out


def blocked_spots():
    bad = []
    for n in all_modules():
        for grp in spot_centres(parse_nodes(n)):
            cols = blocked_columns(n, min(grp) - BP_HALF_W, max(grp) + BP_HALF_W)
            if cols:
                bad.append((n, grp, cols[:4]))
    return bad


def check():
    """The gate: every committed file matches a fresh render (pixel for pixel), nothing extra, and
    no back-plane spot is blocked. Returns a list of problems."""
    probs = ["%s: back-plane spot %s blocked at columns %s" % b for b in blocked_spots()]
    want = everything()
    for rel, im in want.items():
        p = os.path.join(OUT_DIR, rel)
        if not os.path.exists(p):
            probs.append("missing " + rel)
            continue
        have = Image.open(p)
        mode = "RGBA" if im.mode == "RGBA" else "RGB"
        if have.size != im.size or have.convert(mode).tobytes() != im.convert(mode).tobytes():
            probs.append("stale " + rel)
    for dp, _, files in os.walk(OUT_DIR):
        for f in files:
            if f.endswith(".png"):
                rel = os.path.relpath(os.path.join(dp, f), OUT_DIR)
                if rel not in want:
                    probs.append("not generated (remove it) " + rel)
    return probs


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["--check"]:
        probs = check()
        for pr in probs:
            print("BLUEPRINTS:", pr)
        if probs:
            print("docs/blueprints/ is out of date — run: python3 tools/gen_module_blueprint.py")
            sys.exit(1)
        print("blueprints current (%d files)" % len(everything()))
        sys.exit(0)
    if args:
        for n in args:
            p = os.path.join(OUT_DIR, "rooms", room_type(n), n + "_blueprint.png")
            os.makedirs(os.path.dirname(p), exist_ok=True)
            build(n).save(p)
            print("wrote", os.path.relpath(p, ROOT))
        sys.exit(0)
    files = everything()
    for rel, im in files.items():
        p = os.path.join(OUT_DIR, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)
    print("wrote %d files under %s" % (len(files), os.path.relpath(OUT_DIR, ROOT)))
