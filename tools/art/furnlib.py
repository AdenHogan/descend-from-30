"""FURNITURE AS ASSETS — the kit, the registry and the sprite renderer (owner round 47).

The owner: "converting all art furniture and objects into their own assets like what you've done with the posters and wall art, that a seed can
natively place… so even two versions of a bedroom module A will have variance… the purpose is that just because an item is currently in a bedroom
doesn't mean it can't also be in another room — so some rule and logic needs to be in place: we do not ever need a bed in a kitchen."

Until now every room module was ONE baked picture: the furniture was drawn into it at fixed coordinates by that module's own script. Here each piece
of furniture / each object is its OWN sprite with a record of what it is and where it may go; the game puts them in a room at runtime
(scripts/furniture_planner.gd) from a seed. Nothing in this file decides WHERE — it decides what a piece LOOKS like and what it SAYS about itself:

    plane   wall    stands against the back wall (feet ~104-108): wardrobes, dressers, nightstands, desks; their scavenge nodes are BACK-PLANE (step-up)
            front   stands out toward the lane (feet 114-120): beds, chairs, chests; its nodes are FRONT nodes (reached from the walking lane)
            decor   hangs on the wall (pictures, posters, mirrors)           rug  lies flat on the floor (drawn first, walked over)
            floor   a small thing on the floor (clothes, shoes, a box)       top  stands ON a surface (a lamp on a nightstand)
            ceiling a light fitting hung from the ceiling
    rooms   {room type: weight} — THE LOGIC: a piece is only ever placed in a room it lists (a bed lists "bedroom" and nothing else; a kettle will list
            "kitchen"). The planner draws from the room's own pool; tests/furniture_test.gd proves nothing escapes it.
    styles  {style: weight} — what KIND of room within the type (adult / teen / kid / sick / bedsit): a cot is for the child's room, an iron bedstead for the
            sick room, crates for a bedsit. Styles are the five old bedroom variants A-E, now archetypes the planner fills differently every time.
    tags    what it is (sleeping, storage, light, work, toy, clutter…) — the planner's "needs" rules (a desk wants a chair; a lamp wants a surface).

PERSPECTIVE. The rooms are drawn as if looking into a box: every module has one vanishing point at the ceiling over its middle, so a set-back piece shows the face
turned to the middle (pixlib.setback / pp). Pieces that LEAN are therefore rendered once per LEAN BUCKET — the module x of their centre, LEAN_X — and the planner
picks the sprite whose bucket is nearest to where it stands; the centre bucket (160) is the straight-on look with no side face. So a wardrobe at the left edge shows
its right side, one at the right edge its left side, exactly as the baked rooms did — and the same sprite family works at any x. (If the owner picks the "no lean /
fixed oblique" perspective option in docs/ROOM_DEPTH_AND_PROPS.md, it is one switch here: `LEAN_MODE`.)

Run:  python3 tools/art/furn_build.py [--check]       (this file is the library; furn_bedroom.py holds the bedroom pieces)
Out:  assets/furniture/*.png (+ open/ sheets)   data/furniture.json   docs/art_reference/furniture/*.png
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

import pixlib
from pixlib import Canvas, hexc, shade, mix, W, H, SEAM_Y

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SPRITES = os.path.join(ROOT, 'assets', 'furniture')
OPEN_DIR = os.path.join(SPRITES, 'open')
DATA = os.path.join(ROOT, 'data', 'furniture.json')
PREVIEW = os.path.join(ROOT, 'docs', 'art_reference', 'furniture')

# The module x of a piece's CENTRE for each lean bucket (the planner picks the nearest). 160 = the module's vanishing point: straight on, no side face.
LEAN_X = (36, 72, 116, 160, 204, 248, 284)
LEAN_MODE = 'vp'                         # 'vp' = lean toward the module's middle (as the baked rooms); 'none' = every piece straight-on (renders only the centre bucket)

PLANES = ('wall', 'front', 'decor', 'rug', 'floor', 'top', 'ceiling')
STYLES = ('adult', 'teen', 'kid', 'sick', 'bedsit',                       # bedrooms
          'classic', 'retro', 'country', 'student', 'hoarder',               # kitchens
          'cosy', 'mid', 'squat', 'parlour', 'lodge',                        # living rooms
          'formal', 'diner', 'houseshare', 'party', 'family',                 # dining rooms
          'office', 'library', 'radio', 'studio', 'den',                     # studies
          'tub', 'avocado', 'gilded', 'wetroom', 'pink')                     # bathrooms
ROOM_TYPES = ('bedroom', 'bathroom', 'kitchen', 'study', 'living_room', 'dining_room')

import home_kinds as HK            # WHAT EVERY THING IS and the rooms a home could keep it in: tools/art/home_kinds.py
import home_logic as HL            # HOW A HOME KEEPS A THING (floor vs surface, by kind and size): tools/art/home_logic.py — registration refuses a piece that breaks it

# THE LOGIC, as data (owner round 47: "we do not ever need a bed in a kitchen"). A piece carrying one of these TAGS may only list rooms from the set — registration REFUSES a
# piece that breaks it, so a new piece cannot be put somewhere it makes no sense even by accident. The planner only ever draws from the room's own pool, and
# tests/furniture_test.gd re-checks every placement it makes against the same table (data/furniture.json carries it as "rules").
TAG_ROOMS = {
    'sleeping': ('bedroom',),                                  # beds, cots, mattresses
    'wardrobe': ('bedroom',),                                  # clothes storage
    'bedside': ('bedroom',),
    'dressing': ('bedroom', 'bathroom'),
    'toy': ('bedroom', 'living_room'),
    'medical': ('bedroom', 'bathroom', 'living_room'),         # care equipment: wherever somebody is being looked after
    'cooking': ('kitchen',),
    'food': ('kitchen', 'dining_room', 'living_room'),
    'wet': ('bathroom', 'kitchen'),                            # sinks, baths, washing
    'toilet': ('bathroom',),
    'books': ('bedroom', 'study', 'living_room'),
    'work': ('study', 'bedroom'),                              # desks (a teen's room has one)
    'seating_lounge': ('living_room', 'study', 'dining_room', 'bedroom'),
    'dining': ('dining_room', 'kitchen'),
    'tv': ('living_room', 'bedroom'),
    'unit': ('kitchen', 'bathroom'),                           # fitted units that stand edge to edge in a run along the wall
    'cold': ('kitchen',),                                      # fridges / larders
    'hearth': ('living_room', 'kitchen'),
}


class Piece:
    """One piece of furniture / one object. `draw(c, ox, oy, p)` paints it on a transparent canvas with its FRONT-LEFT corner at x = ox and its feet (the last row of the front
    face) at y = oy; `p` is the variant's parameter dict (colourway, which way the head of a bed faces, an open state 0..1…)."""

    def __init__(self, pid, draw, w, h, plane, rooms, styles, tags, variants, depth, lean, bucketed, surface_h, anchors, lights, slots, on, opens, anims,
                 pair, near, wall_y, ceiling_drop, feet, sound, note, limit=None, needs=None, post=None, companion_only=False, above=(), lap=6, under=(), keep=None, kind=None, must_above=False, under_window=False, edge=False):
        self.id, self.draw, self.w, self.h = pid, draw, w, h
        self.plane, self.rooms, self.styles, self.tags = plane, rooms, styles, tags
        self.variants = variants              # {variant id: params}
        self.depth = depth                    # pixlib.setback depth (lean pieces)
        self.lean, self.bucketed = lean, bucketed
        self.surface_h = surface_h            # body height from the feet; anything drawn above stands ON the top (setback `top`)
        self.anchors, self.lights, self.slots, self.on = anchors, lights, slots, on
        self.opens, self.anims = opens, anims
        self.pair, self.near = pair, near
        self.wall_y = wall_y                  # decor: the (min, max) module y of its TOP edge on the wall
        self.ceiling_drop = ceiling_drop
        self.feet = feet                      # the module y of the feet line: (min, max) the planner may use
        self.sound = sound
        self.note = note
        self.above = tuple(above)             # hung things: tags of the pieces it prefers to hang above (wall cupboards over the run)
        self.lap = lap                        # a floor piece may overlap a body's drawn rect by this many rows along its lower edge (a coffee table over the front of the sofa)
        self.under = tuple(under)             # a rug that may lie (part) under bodies with these tags (a living-room rug under the sofa)
        self.must_above = must_above          # a hung piece that is ONLY ever hung over one of its `above` pieces (a bathroom mirror over the basin, wall cupboards over the worktop)
        self.kind = kind                      # what it IS (home_kinds.KINDS): the rooms a home could keep it in are an upper bound on `rooms`
        self.keep = keep                      # a FLOOR piece's reason for standing on a floor (home_logic.FLOOR_KEEPS): 'seat', 'footwear', 'plant' (tall, big pot)…; None for every other plane
        self.edge = edge                      # a small thing that stands toward an END of the surface it is on, not in the middle of it (a globe at the side of a desk)
        self.under_window = under_window      # a piece that belongs UNDER a window (a radiator, a butler sink): where the room has a window it stands under it, never elsewhere
        self.limit = limit                    # at most this many in one room (None = the planner's default for its plane)
        self.companion_only = companion_only  # only ever placed as someone's companion (a desk chair), never on its own
        self.post = post                      # post(c, ox, oy, p, shift): drawn AFTER the set-back lean (things whose own perspective needs the piece's final shift, a CRT on a desk)
        self.needs = needs                    # {'tag': ..., 'dx': [min, max], 'chance': p}: a companion that must stand beside it (a desk wants its chair)


REGISTRY = {}
HOME_VIOLATIONS = []


def recheck_registry():
    """Every rule again on the FINAL registry — `furn_styles.apply()` widens some pieces to more rooms after registration, and a widened piece must still make sense there."""
    for pid, pc in REGISTRY.items():
        for t_ in pc.tags:
            if t_ in TAG_ROOMS:
                for r_ in pc.rooms:
                    if r_ not in TAG_ROOMS[t_] and os.environ.get('HOME_REPORT'):
                        HOME_VIOLATIONS.append('%s: a "%s" piece may not go in a %s (allowed: %s)' % (pid, t_, r_, ', '.join(TAG_ROOMS[t_])))
                        continue
                    assert r_ in TAG_ROOMS[t_], '%s: a "%s" piece may not go in a %s (allowed: %s)' % (pid, t_, r_, ', '.join(TAG_ROOMS[t_]))
        why_ = HL.issue(pc.plane, pc.h, pc.tags, pc.keep, tuple(pc.rooms), pc.kind)
        if why_ and os.environ.get('HOME_REPORT'):
            HOME_VIOLATIONS.append('%s %s' % (pid, why_))
        else:
            assert not why_, '%s %s' % (pid, why_)


def piece(pid, w, h, plane, rooms, styles=None, tags=(), variants=None, depth=0, lean=None, bucketed=None, surface_h=None, anchors=(), lights=(), slots=(),
          on=(), opens=None, anims=(), pair=None, near=(), wall_y=None, ceiling_drop=0, feet=None, sound=None, note='', limit=None, needs=None, post=None, companion_only=False, above=(), lap=6, under=(), keep=None, must_above=False, under_window=False, edge=False):
    """Register a piece (a decorator for its draw function). See Piece. `rooms` {room: weight}; `styles` {style: weight} (None = any style at weight 1)."""
    assert plane in PLANES, plane
    for r_ in rooms:
        assert r_ in ROOM_TYPES, r_
    for t_ in tags:
        if t_ in TAG_ROOMS:
            for r_ in rooms:
                assert r_ in TAG_ROOMS[t_], '%s: a "%s" piece may not go in a %s (allowed: %s)' % (pid, t_, r_, ', '.join(TAG_ROOMS[t_]))
    if styles is not None:
        for s_ in styles:
            assert s_ in STYLES, s_
    assert not must_above or above, '%s: must_above needs an `above` list' % pid
    kind_ = HK.PIECE_KIND.get(pid)
    why_ = HL.issue(plane, h, tuple(tags), keep, tuple(rooms), kind_)
    if why_ and os.environ.get('HOME_REPORT'):                                           # HOME_REPORT=1 lists every violation instead of stopping at the first
        HOME_VIOLATIONS.append('%s %s' % (pid, why_))
    else:
        assert not why_, '%s %s' % (pid, why_)

    def deco(fn):
        assert pid not in REGISTRY, 'duplicate piece ' + pid
        is_lean = (plane == 'wall' and depth > 0) if lean is None else lean
        is_bucketed = is_lean if bucketed is None else bucketed
        REGISTRY[pid] = Piece(pid, fn, w, h, plane, dict(rooms), dict(styles) if styles else None, tuple(tags), variants or {'a': {}}, depth, is_lean, is_bucketed,
                              surface_h if surface_h is not None else h, tuple(anchors), tuple(lights), tuple(slots), tuple(on), opens, tuple(anims), pair, tuple(near),
                              wall_y, ceiling_drop, feet or {'wall': (105, 109), 'front': (114, 120), 'floor': (108, 120), 'rug': (112, 118)}.get(plane, (0, 0)), sound, note, limit, needs, post, companion_only, above, lap, under, keep, kind_, must_above, under_window, edge)
        return fn
    return deco


# --------------------------------------------------------------------------------------------------------------------------- drawing kit
def box3(c, x0, y0, x1, y1, front, top=None, d=4, out=None, hi=None, lo=None, inset=1):
    """A straight-on box with real volume: its FRONT face x0..x1, y0..y1 and a TOP face d rows high above it (a little from above — the back edge `inset` px narrower each
    side so the top reads as receding), a light line along the front's top edge, a shaded bottom row and an outline. No side face (the lean machinery adds those)."""
    out = out or shade(front, 0.45)
    if top is not None and d > 0:
        for k in range(d):
            i = int(round(inset * (k + 1) / float(d)))
            c.hline(x0 + i, x1 - i, y0 - 1 - k, top if k < d - 1 else shade(top, 0.9))
        c.hline(x0 + inset, x1 - inset, y0 - d - 1, out)
        c.put(x0 + (inset), y0 - d, out) if inset else None
    c.rect(x0, y0, x1, y1, front)
    c.hline(x0, x1, y0, hi or shade(front, 1.18))
    c.hline(x0, x1, y1, lo or shade(front, 0.72))
    c.vline(x0, y0, y1, shade(front, 1.06))
    c.vline(x1, y0, y1, shade(front, 0.84))
    c.hline(x0, x1, y1 + 1, out)
    c.vline(x0 - 1, y0, y1 + 1, out)
    c.vline(x1 + 1, y0, y1 + 1, out)


def knob(c, x, y, col=None):
    c.put(x, y, col or hexc('b09456'))


def foot_shadow(c, x0, x1, y, alpha=80, rows=1):
    """A soft contact shadow on the floor under a piece (alpha so it lies on whatever floor the room has)."""
    cx, rx = (x0 + x1) / 2.0, (x1 - x0) / 2.0 + 3
    c.shadow(cx, y + 1, rx, rows + 1, alpha)


def blank():
    return Canvas(bg=(0, 0, 0, 0), seed=11)


# --------------------------------------------------------------------------------------------------------------------------- rendering
def _bbox(img, pad=0):
    a = img.getchannel('A')
    bb = a.getbbox()
    if bb is None:
        return None
    return (max(0, bb[0] - pad), max(0, bb[1] - pad), min(img.width, bb[2] + pad), min(img.height, bb[3] + pad))


def shift_of(pc):
    """How far forward a leaning piece comes (pixlib.setback_depth): its feet move this many rows down from where the front face was drawn."""
    return pixlib.setback_depth(pc.depth) if pc.lean else 0


def on_top_of(pc):
    s = shift_of(pc)
    return s // 2 if s > 1 else s


def _lean(c, fn, depth, top, x_range):
    """pixlib.setback WITHOUT its back-off loop (a piece must come out the same depth at every x — the back-off was for a module's window boxes, which a sprite knows
    nothing about): extrude toward the module's vanishing point, then lay the body forward and the things standing ON it (above `top`) to the middle of the surface."""
    want = pixlib.setback_depth(depth)
    ext, lyr, _opaque = pixlib._setback_render(fn, want, top, x_range, pixlib.VP_X, 1.0, 0)
    shift = want
    on_top = shift // 2 if (top is not None and shift > 1) else shift
    c.img.alpha_composite(ext)
    moved = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    if top is None or on_top == shift:
        moved.paste(lyr, (0, shift), lyr)
    else:
        body, above = lyr.copy(), lyr.copy()
        bp_, ap_ = body.load(), above.load()
        for y in range(H):
            for x in range(W):
                if y < top:
                    bp_[x, y] = (0, 0, 0, 0)
                else:
                    ap_[x, y] = (0, 0, 0, 0)
        moved.paste(body, (0, shift), body)
        pixlib._on_top_volume(above, top)
        moved.paste(above, (0, on_top), above)
        pixlib._on_top_shadow(c, above, top, on_top)
    c.img.alpha_composite(moved)
    c.px = c.img.load()
    pixlib.SETBACKS.clear()
    return shift


def render(pc, params, xk=160, state=0.0):
    """Render one sprite of a piece at bucket x `xk`. Returns (RGBA image, info): info = {w, h, rx, ry (the reference point R — the front-left corner at the feet row — in sprite
    px), l, r, t, b (the sprite's extents relative to R)}."""
    pixlib.LIGHTS.clear()
    pixlib.ANIMS.clear()
    c = blank()
    p = dict(params)
    p['open'] = state
    ox = int(round(xk - pc.w / 2.0)) if (pc.bucketed or pc.lean) else 40
    oy = {'decor': 40, 'rug': 100, 'ceiling': 0, 'floor': 118, 'top': 80, 'front': 114}.get(pc.plane, SEAM_Y - 1)
    if pc.lean:
        _lean(c, lambda l: pc.draw(l, ox, oy, p), pc.depth, oy - pc.surface_h + 1, (ox - 2, ox + pc.w + 1))
    else:
        pc.draw(c, ox, oy, p)
    if pc.post is not None:
        pc.post(c, ox, oy, p, shift_of(pc))
    import furn_finish                                                                    # a finishing pass for pieces built from big flat faces (edge light, banded tone, grain)
    furn_finish.apply(pc.id, c)
    feet = oy + shift_of(pc)
    bb = _bbox(c.img, 1)
    if bb is None:
        raise SystemExit('piece %s drew nothing' % pc.id)
    spr = c.img.crop(bb)
    info = {'w': spr.width, 'h': spr.height, 'rx': ox - bb[0], 'ry': feet - bb[1],
            'l': bb[0] - ox, 'r': bb[2] - 1 - ox, 't': bb[1] - feet, 'b': bb[3] - 1 - feet}
    sp_ = spr.load()
    solid = [y for y in range(spr.height) if any(sp_[x, y][3] >= 200 for x in range(spr.width))]
    info['sb'] = (max(solid) if solid else spr.height - 1) - info['ry']           # the lowest SOLID row relative to R: a thing drawn below its feet row (spilled tablets) or not (a shadow does not count)
    pixlib.LIGHTS.clear()
    pixlib.ANIMS.clear()
    return spr, info


def bucket_of(x_centre):
    best, bd = 0, 1e9
    for k, xk in enumerate(LEAN_X):
        if abs(xk - x_centre) < bd:
            best, bd = k, abs(xk - x_centre)
    return best


def sprite_name(pid, vid, bucket=None):
    return '%s_%s' % (pid, vid) if bucket is None else '%s_%s_b%d' % (pid, vid, bucket)


def _buckets(pc):
    """The lean buckets a piece is rendered for: every one whose centre x lets the whole piece sit inside the module (a 137-px bed centred at x 36 would hang off the canvas —
    it simply has no bucket there, and the planner only ever picks from the list)."""
    if not pc.bucketed:
        return [None]
    if LEAN_MODE == 'none':
        return [3]
    ok = [k for k, xk in enumerate(LEAN_X) if int(round(xk - pc.w / 2.0)) >= 2 and int(round(xk - pc.w / 2.0)) + pc.w <= W - 2]
    return ok or [3]


def _resolve(pc, items, params):
    """A piece's anchors / lights / slots / anims for ONE variant, relative to the piece's FINAL feet row (R): `if` {param: value} keeps an entry only for matching variants (a box
    under the bed only where the variant has one); `head_rel` measures dx from the HEAD end of a bed (mirrored for a head-right variant); a thing on the body moves forward with the
    whole piece, a thing standing ON the top (`top: True`) only to the middle of the surface."""
    s, ot = shift_of(pc), on_top_of(pc)
    out = []
    for a in items:
        cond = a.get('if')
        if cond and any(params.get(k) != v for k, v in cond.items()):
            continue
        d = {k: v for k, v in a.items() if k not in ('if', 'head_rel')}
        if a.get('head_rel') and params.get('head') == 'right':
            d['dx'] = pc.w - 1 - a['dx']
        d['dy'] = a['dy'] + ((ot if a.get('top') else s) - s)
        out.append(d)
    return out


TOP_FACE_MAX = 12          # a lean top face is a few rows deep; the scan for its back edge never climbs further than this
MIN_SUPPORTED_RUN = 8      # a slot is never tightened to fewer columns than the smallest thing that stands on one


def _measure_slot(pc, sl, spr, info):
    """One bucket's reading of a top slot: (dy, bottom_max, dx0, dx1) relative to R, or None when nothing solid lies in its columns."""
    px = spr.load()
    x0, x1 = info['rx'] + sl['dx0'], info['rx'] + sl['dx1']
    cols = range(max(0, x0), min(spr.width - 1, x1) + 1)
    rows = [y for y in range(spr.height) if any(px[x, y][3] >= 200 for x in cols)]
    if not rows:
        return None
    back = min(rows)
    front = None
    if pc.lean:
        front = max(back + 2, info['ry'] - pc.surface_h)                    # the body's top edge: the top face ends one row above it
        r = front - 1
        n = max(1, len(cols))
        if r >= back and sum(1 for x in cols if px[x, r][3] >= 200) * 2 >= n:
            top = r                                                          # climb the contiguous band that ends at the top face
            while top - 1 >= back and front - 1 - (top - 1) < TOP_FACE_MAX and sum(1 for x in cols if px[x, top - 1][3] >= 200) * 2 >= n:
                top -= 1
            back = max(back, top)
    lo = back + 2                                                            # the feet row (contact - 1) is the surface's second row
    if pc.lean:
        dy, bottom_max = lo - info['ry'], max(lo - 1, front - 1) - info['ry']
    else:
        dy = max(info['ry'] + sl['dy'], lo) - info['ry']
        bottom_max = dy - 1
    # the longest unbroken run of columns the contact row has solid under it
    row = min(spr.height - 1, lo)
    best, run0 = (0, 0), None
    for x in list(cols) + [None]:
        if x is not None and px[x, row][3] >= 200:
            if run0 is None:
                run0 = x
        elif run0 is not None:
            end = x if x is not None else cols[-1] + 1
            if end - run0 > best[1] - best[0]:
                best = (run0, end)
            run0 = None
    if best[1] - best[0] >= MIN_SUPPORTED_RUN:
        return dy, bottom_max, best[0] - info['rx'], best[1] - 1 - info['rx']
    return dy, bottom_max, sl['dx0'], sl['dx1']


def _settle_slots(pc, slots, sprs):
    """A top slot's contact rows are MEASURED off the rendered sprites (owner round 48i: "the pills are sort of suspended in the air over this dresser… We can't have floaty
    things. If it's an item it needs to physically be on top of the furniture"; a hand-set `dy` was a guess at the lid's row and was 1-3 rows above it on a bookcase, a Welsh dresser,
    a piano, a wardrobe). `dy` = the BACK-most contact row (relative to R): the row just under the first solid row of the host's top in the slot's columns, so an item's feet land
    ON the surface. `bottom_max` = the lowest row an item's SOLID pixels may reach (the last row of the top face, relative to R): the planner puts a thing anywhere between the two
    (a lean piece's top face is a few rows deep — the room's perspective — and was only ever used at its very back). A flat-topped host (a table, a desk) keeps one contact row,
    never above its surface.
    Three ways the first version still left things in the air (found by `tools/art/support_audit.py`): (1) the FIRST solid row in the slot's columns can be a mirror or a back panel that
    stands up behind the surface with a gap under it (a dressing table), so a lean piece's back edge is the top of the CONTIGUOUS band that ends at the top face (never climbing more
    than TOP_FACE_MAX rows); (2) the slot's columns can run past the surface (a fireplace's mantel is narrower than the slot), so the slot is cut down to the columns the contact
    row really has under it; (3) a lean piece is drawn once per lean bucket and its surface moves between them, while the planner reads ONE slot per variant, so the slot is the
    SAFE reading of all of them: the lowest contact row, the shallowest top face, and only the columns every bucket has support under."""
    out = []
    for sl in slots:
        sl = dict(sl)
        if sl.get('top'):
            reads = [m for m in (_measure_slot(pc, sl, spr, info) for spr, info in sprs) if m is not None]
            if reads:
                sl['dy'] = max(m[0] for m in reads)
                sl['bottom_max'] = max(sl['dy'] - 1, min(m[1] for m in reads))
                lo, hi = max(m[2] for m in reads), min(m[3] for m in reads)
                if hi - lo + 1 >= MIN_SUPPORTED_RUN:
                    sl['dx0'], sl['dx1'] = lo, hi
        out.append(sl)
    return out


def build_piece(pc):
    """Render every variant × bucket (and the open-state strips). Returns (the JSON record, {relative filename: image})."""
    files = {}
    rec = {'plane': pc.plane, 'rooms': pc.rooms, 'styles': pc.styles, 'tags': list(pc.tags), 'w': pc.w, 'h': pc.h, 'lean': pc.lean, 'bucketed': pc.bucketed,
           'variants': {}, 'on': list(pc.on), 'pair': pc.pair, 'near': list(pc.near), 'wall_y': list(pc.wall_y) if pc.wall_y else None,
           'ceiling_drop': pc.ceiling_drop, 'feet': list(pc.feet), 'sound': pc.sound, 'note': pc.note, 'opens': dict(pc.opens) if pc.opens else None,
           'limit': pc.limit, 'needs': pc.needs, 'companion_only': pc.companion_only, 'above': list(pc.above), 'lap': pc.lap, 'under': list(pc.under), 'keep': pc.keep, 'kind': pc.kind, 'must_above': pc.must_above, 'under_window': pc.under_window, 'edge': pc.edge}
    for vid, params in pc.variants.items():
        sprites = []
        first_spr = first_info = None
        measured = []
        for bk in _buckets(pc):
            xk = LEAN_X[bk] if bk is not None else 160
            spr, info = render(pc, params, xk)
            name = sprite_name(pc.id, vid, bk if pc.bucketed else None)
            files[name + '.png'] = spr
            if first_spr is None:
                first_spr, first_info = spr, info
            info['file'] = name
            info['bx'] = xk
            measured.append((spr, info))
            if pc.opens:
                frames = int(pc.opens.get('frames', 3))
                strip = Image.new('RGBA', (spr.width * (frames + 1), spr.height), (0, 0, 0, 0))
                strip.paste(spr, (0, 0))
                for f in range(1, frames + 1):
                    st_spr, st_info = render(pc, params, xk, state=f / float(frames))
                    cell = Image.new('RGBA', spr.size, (0, 0, 0, 0))
                    cell.paste(st_spr, (info['rx'] - st_info['rx'], info['ry'] - st_info['ry']), st_spr)      # anchored on R; an open state may be bigger — it is cropped to the closed box
                    strip.paste(cell, (spr.width * f, 0))
                files['open/' + name + '_open.png'] = strip
                info['open_file'] = name + '_open'
            sprites.append(info)
        slots = _settle_slots(pc, _resolve(pc, pc.slots, params), measured)
        rec['variants'][vid] = {'sprites': sprites, 'anchors': _resolve(pc, pc.anchors, params), 'lights': _resolve(pc, pc.lights, params), 'slots': slots,
                                'anims': _resolve(pc, pc.anims, params), 'params': {k: (list(v) if isinstance(v, (list, tuple)) else v) for k, v in params.items()
                                   if isinstance(v, (str, int, float, bool)) or (isinstance(v, (list, tuple)) and v and all(isinstance(i, str) for i in v))}}
    return rec, files


def write_files(files, out_dir=SPRITES):
    for rel, img in files.items():
        path = os.path.join(out_dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)


def stale_files(wanted, out_dir=SPRITES):
    have = []
    for d, _dirs, fs in os.walk(out_dir):
        for fn in fs:
            if fn.endswith('.png'):
                have.append(os.path.relpath(os.path.join(d, fn), out_dir).replace(os.sep, '/'))
    return sorted(set(have) - set(wanted))


def remove_stale(wanted, out_dir=SPRITES):
    for rel in stale_files(wanted, out_dir):
        pixlib._remove_asset(os.path.join(out_dir, rel))
