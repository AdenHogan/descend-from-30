#!/usr/bin/env python3
"""OUR fire = the PURCHASED craftpix pixel fire (assets/fire-pixel-art-animation-sprites/), cleaned and made to JOIN.

Owner round 29c: "Take the original paid assets, adapt and adjust the top and sides to make them less fractured. I don't
need you to reinvent the fire wheel. We still want pixel art … none of this weird organic liquid fire stuff."  (The drawn-
from-scratch fire of rounds 29/29b was rejected: "oven chips".)  So nothing here designs a flame — every pixel's colour comes
from the purchased frames (black outline, orange body, yellow heart); this tool only:

  * REMOVES what read as fractured: the detached outlined ember blobs that float off the tops (each becomes ONE clean spark
    pixel) and the 1-3 px tendrils / hooks on the flame edges (a morphological opening of the flame body — rounded, not sharp);
  * REBUILDS the 1-px black outline round whatever is left, so every edge is closed — no cut-off sides, no open tops;
  * makes the floor tile a REAL tile (the purchased tile 1 is periodic: its edges meet) and cuts END CAPS for it whose height
    falls away to nothing on a rounded curve (the column's flame is squashed, not chopped — so the tips are kept);
  * hands the same pieces back as: floor CLUMPS (cap-to-cap, 32 px), a RUN KIT (left cap + tile x n + right cap, any width, joined
    exactly), single TONGUES (the 'Flame' + 'Idle' sheets), wall / door-frame / enemy flames.

Frames are drawn by the game at integer 2x (the purchased fire was drawn 1.6-2.7x, which is what the earlier build did; 2x keeps
every fire pixel on the game's own 2-px grid).  Writes assets/fire/*.png + fire_meta.json + docs/art_reference/fire*.png.
Run:  python3 tools/art/fire.py
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'fire-pixel-art-animation-sprites')
OUT = os.path.join(ROOT, 'assets', 'fire')
PREV = os.path.join(ROOT, 'docs', 'art_reference')

SCALE = 2
FPS = 10
FRAMES = 6

BLACK = (0, 0, 0)
ORANGE = (255, 129, 66)
YELLOW = (255, 218, 69)
# labels
EMPTY, LINE, ORNG, YELL = 0, 1, 2, 3


# ------------------------------------------------------------------------------------------------ loading
def load_strip(path, fw, fh):
    im = np.array(Image.open(path).convert('RGBA'))
    n = im.shape[1] // fw
    out = []
    for f in range(n):
        a = im[:fh, f * fw:(f + 1) * fw]
        lab = np.zeros((fh, fw), dtype=np.uint8)
        op = a[..., 3] > 0
        rgb = a[..., :3].astype(int)
        lab[op & (rgb.sum(axis=2) < 60)] = LINE
        lab[op & (np.abs(rgb - np.array(ORANGE)).sum(axis=2) < 40)] = ORNG
        lab[op & (np.abs(rgb - np.array(YELLOW)).sum(axis=2) < 40)] = YELL
        out.append(lab)
    return out


# ------------------------------------------------------------------------------------------------ morphology (numpy only)
def _shift(m, dy, dx):
    out = np.zeros_like(m)
    h, w = m.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = m[yd, xd]
    return out


def erode_plus(m):
    return m & _shift(m, 1, 0) & _shift(m, -1, 0) & _shift(m, 0, 1) & _shift(m, 0, -1)


def dilate_plus(m):
    return m | _shift(m, 1, 0) | _shift(m, -1, 0) | _shift(m, 0, 1) | _shift(m, 0, -1)


def components(m):
    """8-connected components of a bool mask -> list of arrays of (y, x)."""
    seen = np.zeros_like(m)
    h, w = m.shape
    comps = []
    for y in range(h):
        for x in range(w):
            if m[y, x] and not seen[y, x]:
                stack = [(y, x)]
                seen[y, x] = True
                pts = []
                while stack:
                    cy, cx = stack.pop()
                    pts.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                stack.append((ny, nx))
                comps.append(np.array(pts))
    return comps


# ------------------------------------------------------------------------------------------------ cleaning
def clean_body(lab, keep_sparks=True, min_frac=0.12, min_area=14, opening=True, closing=False):
    """labels -> (cleaned FILL labels (ORNG/YELL only, no outline), spark points).
    Detached blobs vanish (their centre is kept as a spark); thin tendrils vanish (opening); nothing is invented."""
    fill = lab >= ORNG
    comps = components(fill)
    sparks = []
    if comps:
        big = max(len(c) for c in comps)
        keep = np.zeros_like(fill)
        for c in comps:
            if len(c) >= max(min_area, min_frac * big):
                keep[c[:, 0], c[:, 1]] = True
            elif keep_sparks:
                sparks.append((int(round(c[:, 0].mean())), int(round(c[:, 1].mean()))))
        fill = keep
    # opening (plus): removes fill features narrower than 3 px — the hooks / spurs — then restores the rest
    opened = (dilate_plus(erode_plus(fill)) & fill) if opening else fill
    if closing:
        # a CLOSING (plus): the 1-2 px black cracks between neighbouring licks fill in, so the carpet reads as one body with a
        # scalloped top instead of a field of separate shards. The yellow heart is never overwritten.
        opened = erode_plus(dilate_plus(opened)) | opened
    # enclosed pin-holes (a ring of body round a gap) fill in: they showed the room through the carpet as dark pits
    bg = ~opened
    reach = np.zeros_like(bg)
    reach[0, :] |= bg[0, :]
    reach[-1, :] |= bg[-1, :]
    reach[:, 0] |= bg[:, 0]
    reach[:, -1] |= bg[:, -1]
    while True:
        grown = (dilate_plus(reach) & bg) | reach
        if (grown == reach).all():
            break
        reach = grown
    opened = opened | (bg & ~reach)
    out = np.where(opened, np.where(lab == YELL, YELL, ORNG), EMPTY).astype(np.uint8)
    return out, sparks


def outline(fill, bottom=True):
    """fill labels -> labels with a rebuilt 1-px outline round the body. bottom=False leaves the body flush to its bottom row."""
    body = fill >= ORNG
    ring = dilate_plus(body) & ~body
    lab = fill.copy()
    lab[ring] = LINE
    if not bottom:
        lab[-1, :][lab[-1, :] == LINE] = EMPTY
    return lab


def pad(lab, top=1, bottom=1, left=1, right=1):
    return np.pad(lab, ((top, bottom), (left, right)), constant_values=EMPTY)


def to_image(lab, dim=1.0):
    h, w = lab.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    pal = {LINE: BLACK, ORNG: ORANGE, YELL: YELLOW}
    for k, col in pal.items():
        c = col if k == LINE or dim >= 1.0 else (int(col[0] * dim), int(col[1] * dim * 0.93), int(col[2] * dim * 0.8))
        out[lab == k] = (*c, 255)
    return Image.fromarray(out, 'RGBA')


# ------------------------------------------------------------------------------------------------ squash (taper without chopping)
def squash(fill, scale_cols, min_h=3, plateau=1.0):
    """Per-column vertical squash of a FILL image (bottom-anchored). scale_cols[x] in [0,1]: 1 = unchanged, 0 = gone. The flame's
    tip is kept (the column is compressed, never cut), so a tapered end is a smaller flame, not a chopped one."""
    h, w = fill.shape
    out = np.zeros_like(fill)
    for x in range(w):
        col = fill[:, x]
        ys = np.where(col >= ORNG)[0]
        if len(ys) == 0:
            continue
        top = ys.min()
        bot = ys.max()
        hs = bot - top + 1
        sc = float(scale_cols[x])
        hd = int(round(hs * sc))
        # where the flame is being tapered, a column shorter than min_h is dropped outright: the end is a small whole flame, not a
        # trailing 1-2 px sliver of base line ("they just stop" — owner round 29c)
        if hd <= 0 or (sc < plateau * 0.999 and hd < min_h):
            continue
        for r in range(hd):
            src = bot - min(hs - 1, int(r * hs / float(hd)))
            out[bot - r, x] = col[src]
    return out


def downsample(fill, d):
    """Integer block downsample of a FILL image (a block is body when at least half of it is; yellow when half of the body in it is):
    the same flame at 1/d size, still pixel art — the outline is rebuilt at 1 px afterwards, so nothing blurs."""
    if d == 1:
        return fill
    h, w = fill.shape
    H, W = h // d, w // d
    out = np.zeros((H, W), dtype=np.uint8)
    for y in range(H):
        for x in range(W):
            blk = fill[y * d:(y + 1) * d, x * d:(x + 1) * d]
            body = int((blk >= ORNG).sum())
            if body * 2 >= d * d:
                out[y, x] = YELL if int((blk == YELL).sum()) * 2 >= body else ORNG
    return out


def drop_specks(fill, taper, min_area=12):
    """After a taper, drop the little separate fragments the squash can strand at an end (a stray lick, a few pixels of base): the
    end of a run is its last WHOLE flame."""
    out = fill.copy()
    for c in components(fill >= ORNG):
        if len(c) < min_area and taper[c[:, 1]].all():      # only inside the taper — never gaps in the body of a run
            out[c[:, 0], c[:, 1]] = EMPTY
    return out


def ragged_pattern(seed, period=32):
    """Per-column depth (0-2 px) the BASE is nibbled up by — periodic over `period`, so tiles and caps agree. Clusters of 2-4
    columns, mostly 1 px, the odd 2 px: a base that wanders instead of a ruled line."""
    rng = np.random.default_rng(seed)
    bo = np.zeros(period, dtype=int)
    x = int(rng.integers(0, 4))
    while x < period:
        wdt = int(rng.integers(2, 5))
        dep = 2 if rng.random() < 0.25 else 1
        for k in range(wdt):
            bo[(x + k) % period] = dep
        x += wdt + int(rng.integers(3, 8))
    return bo


def nibble_base(fill, bo):
    out = fill.copy()
    h, w = fill.shape
    for x in range(w):
        d = int(bo[x % len(bo)])
        if d <= 0:
            continue
        ys = np.where(out[:, x] >= ORNG)[0]
        if len(ys) == 0:
            continue
        bot = ys.max()
        d = min(d, len(ys) - 2)            # a column is never nibbled away: at least 2 px of body stay, so no gap opens in a run
        if d <= 0:
            continue
        out[bot - d + 1:bot + 1, x] = EMPTY
    return out


# ------------------------------------------------------------------------------------------------ the cleaned source pieces
def tile_frames(n):
    return load_strip(os.path.join(SRC, '2 Fire_tiles', '%d.png' % n), 32, 32)


def flame_frames(n):
    return load_strip(os.path.join(SRC, '3 Flame', '%d.png' % n), 32, 32)


def idle_frames():
    return load_strip(os.path.join(SRC, '1 Fire', 'Idle.png'), 64, 64)


def cleaned(frames):
    return [clean_body(f) for f in frames]


def union_box(fills):
    ys, xs = [], []
    for fl in fills:
        yy, xx = np.where(fl >= ORNG)
        if len(yy):
            ys += [yy.min(), yy.max()]
            xs += [xx.min(), xx.max()]
    return min(ys), max(ys), min(xs), max(xs)


def finish_standalone(fills, sparks, flip=False, shift=0, bottom_outline=False):
    """Cleaned fills -> a list of PIL frames, tight to the flame's union box + 1 px margin, outlined all round (the bottom open when
    it stands on a bed). `flip` mirrors it; `shift` rotates the frame order (so variants dance apart)."""
    n = len(fills)
    order = [(i + shift) % n for i in range(n)]
    fills = [fills[i] for i in order]
    sparks = [sparks[i] for i in order]
    y0, y1, x0, x1 = union_box(fills)
    top_room = 0
    for sp in sparks:
        for (sy, sx) in sp:
            top_room = max(top_room, y0 - sy)
    y0 = max(0, y0 - top_room)
    frames = []
    for fl, sp in zip(fills, sparks):
        c = fl[y0:y1 + 1, x0:x1 + 1].copy()
        c = pad(c, top=1, bottom=1, left=1, right=1)
        lab = outline(c, bottom=True)
        for (sy, sx) in sp:
            yy, xx = sy - y0 + 1, sx - x0 + 1
            if 0 < yy < lab.shape[0] - 1 and 0 < xx < lab.shape[1] - 1 and not (dilate_plus(lab != EMPTY))[yy, xx]:
                lab[yy, xx] = ORNG
        if not bottom_outline:
            lab = lab[:-1]                     # stands on a bed: flush, no line under it
        if flip:
            lab = lab[:, ::-1]
        frames.append(to_image(lab))
    return frames


# ------------------------------------------------------------------------------------------------ the tile, caps, clumps
def periodic_tile():
    """Purchased tile 1 is periodic (its edges meet). Clean it IN CONTEXT (three copies side by side) so the seams are cleaned
    like the rest, then keep the middle copy."""
    out = []
    for lab in tile_frames(1):
        strip = np.concatenate([lab, lab, lab], axis=1)
        cl, _ = clean_body(strip, keep_sparks=False, opening=False, closing=True)
        out.append(cl[:, 32:64])
    return out


def run_pieces(stage, roll, shift, seed=1):
    """-> (cap_l, run, cap_r) lists of PIL frames. The flame is squashed (never chopped) to nothing over a LONG, gentle cap — a
    column shorter than 3 px is dropped, so the end is a small whole flame — with JOIN px of exactly the tile's own profile where cap
    meets tile. The base is nibbled up in places (periodic over the tile) so it is never a ruled line."""
    dim = 0.82 if stage == 'back' else 1.0
    JOIN = 8
    tiles = periodic_tile()
    n = len(tiles)
    base = [np.roll(tiles[(i + shift) % n], roll, axis=1) for i in range(n)]
    s = 0.6 if stage == 'light' else 1.0
    W = 32 * 5
    xs = np.arange(W)
    ramp = 32.0 - JOIN
    xl = np.clip(xs / ramp, 0, 1)
    xr = np.clip((W - 1 - xs) / ramp, 0, 1)
    env = (np.minimum(xl, xr) ** 1.15) * s
    bo = ragged_pattern(seed)
    caps_l, runs, caps_r = [], [], []
    for fl in base:
        strip = np.concatenate([fl] * 5, axis=1)
        sq = nibble_base(drop_specks(squash(strip, env, plateau=s), env < s * 0.999), bo)
        lab = outline(pad(sq, top=1, bottom=1, left=0, right=0), bottom=False)[:-1]
        img = to_image(lab, dim)
        caps_l.append(img.crop((0, 0, 32, lab.shape[0])))
        runs.append(img.crop((64, 0, 96, lab.shape[0])))
        caps_r.append(img.crop((128, 0, 160, lab.shape[0])))
    return caps_l, runs, caps_r


def clump(tile_n, x0, width, stage, dim=1.0, shift=0):
    """A floor clump `width` px wide cut from purchased tile `tile_n` at column x0: the flame is squashed to nothing at both ends on
    a rounded curve. Returns PIL frames."""
    frames = tile_frames(tile_n)
    n = len(frames)
    s = 1.0 if stage == 'blaze' else 0.5
    xs = np.arange(width)
    u = (xs + 0.5) / width
    bell = (np.clip(np.sin(np.pi * u), 0, 1) ** 0.9) * s
    out = []
    for i in range(n):
        lab = frames[(i + shift) % n]
        strip = np.concatenate([lab, lab], axis=1)
        win = strip[:, x0:x0 + width]
        cl, _ = clean_body(win, keep_sparks=False, opening=False, closing=True)
        sq = drop_specks(squash(cl, bell, plateau=s), bell < s * 0.999)
        lab2 = outline(pad(sq, top=1, bottom=1, left=1, right=1), bottom=True)
        out.append(to_image(lab2, dim))
    top = min(np.where(np.array(f)[..., 3].any(axis=1))[0][0] for f in out)
    return [f.crop((0, max(0, top - 1), f.width, f.height)) for f in out]


# ------------------------------------------------------------------------------------------------ sheets
SHEETS = {}


def strip(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    s = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * w + (w - f.width) // 2, h - f.height))
    return s, w, h


def add(name, frames, note=''):
    sheet, w, h = strip(frames)
    sheet.save(os.path.join(OUT, name + '.png'))
    SHEETS[name] = {'frame': [w, h], 'frames': len(frames), 'scale': SCALE, 'anchor': 'bottom', 'fps': FPS, 'note': note}


def build():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith('.png') or f.endswith('.json'):
            os.remove(os.path.join(OUT, f))
    # The purchased 'Flame' sheets break apart into fragments on purpose (a flame bursting) — exactly what reads as fractured — so
    # every single flame is the purchased 'Idle' bonfire (whole in all six frames), cleaned, at 1/d size by integer block downsample.
    idle = cleaned(idle_frames())

    def tongue(d, v, bottom_outline=False):
        fills = [downsample(f, d) for f, _ in idle]
        sps = [[(sy // d, sx // d) for (sy, sx) in sp] if d == 1 else [] for _, sp in idle]
        return finish_standalone(fills, sps, flip=(v >= 2), shift=(0, 0, 3)[v - 1], bottom_outline=bottom_outline)

    for v in (1, 2, 3):
        add('bed_front_blaze_%d' % v, clump((1, 3, 1)[v - 1], (0, 0, 16)[v - 1], 32, 'blaze', 1.0, (0, 0, 2)[v - 1]), 'front carpet, BLAZE')
        add('bed_front_light_%d' % v, clump((1, 3, 1)[v - 1], (8, 16, 0)[v - 1], 32, 'light', 1.0, (3, 3, 4)[v - 1]), 'front carpet, LIGHT')
        add('bed_back_blaze_%d' % v, clump((1, 3, 1)[v - 1], (8, 8, 24)[v - 1], 32, 'blaze', 0.82, (1, 1, 3)[v - 1]), 'back seam carpet, BLAZE')
        add('bed_back_light_%d' % v, clump((1, 3, 1)[v - 1], (24, 24, 8)[v - 1], 32, 'light', 0.8, (4, 5, 1)[v - 1]), 'back seam carpet, LIGHT')
        add('tongue_s_%d' % v, tongue(3, v))
        add('tongue_m_%d' % v, tongue(2, v))
        add('tongue_l_%d' % v, tongue(2, (v % 3) + 1))
        add('tongue_xl_%d' % v, tongue(1, v))
        add('wall_%d' % v, tongue(2, v), 'wall flame (stands on a run)')
        add('edge_%d' % v, tongue(3, v), 'door-frame flame')
        add('small_%d' % v, tongue(3, v, bottom_outline=True), 'burning-enemy flame')
        for stage in ('light', 'blaze', 'back'):
            cl, rn, cr = run_pieces(stage, (0, 11, 21)[v - 1], (0, 2, 4)[v - 1], seed=40 + v)
            add('runl_%s_%d' % (stage, v), cl, 'run, left cap (the flame rises out of nothing)')
            add('run_%s_%d' % (stage, v), rn, 'run, middle tile (edges meet — tiles to any width)')
            add('runr_%s_%d' % (stage, v), cr, 'run, right cap (the flame sinks to nothing)')
    add('stair', clump(1, 3, 26, 'blaze', 1.0, 0), 'fire spilling over a step')
    with open(os.path.join(OUT, 'fire_meta.json'), 'w') as f:
        json.dump({'fps': FPS, 'frames': FRAMES, 'scale': SCALE, 'sheets': SHEETS}, f, indent=1, sort_keys=True)


# ------------------------------------------------------------------------------------------------ previews
def _sheet_frame(name, fi):
    sh = Image.open(os.path.join(OUT, name + '.png'))
    fw, fh = SHEETS[name]['frame']
    return sh.crop((fi * fw, 0, fi * fw + fw, fh))


def _compose(rows, bg=(201, 170, 118, 255), gap=8, zoom=2):
    rw = [sum(i.width for i in ims) + gap * len(ims) for ims in rows]
    rh = [max(i.height for i in ims) + gap for ims in rows]
    sheet = Image.new('RGBA', (max(rw), sum(rh)), bg)
    y = 0
    for ims, h in zip(rows, rh):
        x = 0
        for im in ims:
            sheet.alpha_composite(im, (x, y + h - im.height - gap // 2))
            x += im.width + gap
        y += h
    return sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)


def preview():
    names = sorted(SHEETS.keys())
    groups = [[n for n in names if n.startswith(p)] for p in ('bed_front', 'bed_back', 'tongue', 'wall', 'edge', 'small', 'stair')]
    rows = []
    for g in groups:
        ims = []
        for n in g:
            for fi in (0, 3):
                im = _sheet_frame(n, fi)
                ims.append(im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST))
        rows.append(ims)
    os.makedirs(PREV, exist_ok=True)
    sh = _compose(rows)
    sh.save(os.path.join(PREV, 'fire.png'))
    return sh


def assemble_run(stage, v, n, fi):
    pieces = [_sheet_frame('runl_%s_%d' % (stage, v), fi)] + [_sheet_frame('run_%s_%d' % (stage, v), fi)] * n + [_sheet_frame('runr_%s_%d' % (stage, v), fi)]
    w = sum(p.width for p in pieces)
    out = Image.new('RGBA', (w, pieces[0].height), (0, 0, 0, 0))
    x = 0
    for p_ in pieces:
        out.alpha_composite(p_, (x, 0))
        x += p_.width
    return out


def assembly_preview():
    rows = []
    for stage in ('light', 'blaze', 'back'):
        for v in (1, 2, 3):
            ims = []
            for n in (0, 1, 2, 3):
                im = assemble_run(stage, v, n, 0)
                ims.append(im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST))
            rows.append(ims)
    sh = _compose(rows)
    sh.save(os.path.join(PREV, 'fire_extensions.png'))
    return sh


if __name__ == '__main__':
    build()
    s = preview()
    assembly_preview()
    print('wrote', len(SHEETS), 'sheets; preview', s.size)
