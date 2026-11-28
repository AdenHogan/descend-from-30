"""THE DETAIL PASS for the players (owner 2026-11-25: "they still feel sloppy… the low quality of the asset is becoming a problem and needs more details. Not ridiculous and over the top, but things like the face
and eyes, and hair… think about the level of quality in the designs of characters in Dave the Diver, or the variety of colours in the classic 2D side-scrollers like Sonic, Mario, Metroid: we are lacking refinement,
colour and quality").

`polish(im, j, pose, p)` runs on a finished frame of `people.draw` for a person with `hd` set, and works in FINAL pixels (not design pixels): eyes with a lid, an iris and a catch-light, brows, a nose on the
profile, lips, a flush of colour, a lighter strand of hair and a rim of light, laces and a sole on the boots, and a coloured (not black) selective outline round the figure. Colour variety comes from
HUE-SHIFTED shading: shadows lean toward indigo / plum, lights toward warm yellow, so no part of a person is one hue.
"""
import math

import people as P


def _t(c):
    return tuple(int(v) for v in c[:3])


def hue_shift(rgb, toward, t):
    return P._mix(_t(rgb), _t(toward), t)


def polish(im, j, pose, p):
    """Everything is placed RELATIVE TO THE NEAR EYE'S top-left pixel (E): the same rule people.draw uses for the eyes, so the face keeps its registration in every frame."""
    K = P.K
    px = im.load()
    W, H = im.size
    hcx, hcy = j['head']
    hx, hy = hcx - 0.5, hcy - 0.5
    skin = P.tones(p['skin'], 0.84, 1.07, mute=0.0)
    hair = P.tones(p['hair'], 0.74, 1.24)
    f = dict(P.FACE_DEFAULT)
    f.update(p.get('face', {}))
    f.update(P.MOODS.get(pose.get('mood') or 'calm', {}).get('face', {}))
    mood = pose.get('mood') or 'calm'
    blinking = bool(pose.get('blink'))

    def put(x, y, col, only_opaque=True):
        xi, yi = int(x), int(y)
        if 0 <= xi < W and 0 <= yi < H and (px[xi, yi][3] > 0 or not only_opaque):
            px[xi, yi] = _t(col) + (255,)
    ex0, ey = int(round(hx - 1.0)) + f.get('dx', 0), int(round(hy + 1.0)) + f.get('dy', 0)
    ew, eh = f['eye']
    ex1 = ex0 + ew + f['gap']
    Ex, Ey = int(ex0 * K), int(ey * K)                         # the near eye's top-left pixel
    Fx = int(ex1 * K)                                          # the far eye's
    iris = _t(P.rgb(p.get('iris', '5a7a96')))
    eye_dark = (26, 18, 34)
    # ---- the eyes: a taller dark eye (3 x 4), a bold catch-light, the iris colour showing along the bottom, a lash at the outer corner
    for k, X in enumerate((Ex, Fx)):
        if blinking:
            for dx in range(3):
                put(X + dx, Ey + 1, eye_dark)
            continue
        for dx in range(3):
            for dy in range(-1, 3):
                put(X + dx, Ey + dy, eye_dark, only_opaque=False)
        put(X, Ey, (252, 250, 246))                            # the catch-light
        put(X + 1, Ey + 2, iris)
        put(X + 2, Ey + 2, _t(P._mix(iris, (255, 255, 255), 0.3)))
        if k == 0:
            put(X - 1, Ey - 1, eye_dark)                       # the outer lash of the near eye
    # ---- brows: one pixel thick, in the hair's shade, and they MOVE with the mood
    brow = _t(hair['d'])
    lift = {'calm': 0, 'wary': 0, 'scared': 1, 'sad': 1, 'hurt': 1, 'angry': -1}.get(mood, 0)
    for dx in range(-1, 3):
        put(Ex + dx, Ey - 3 - (lift if dx >= 1 else 0) + (1 if (mood == 'angry' and dx >= 1) else 0), brow)
    for dx in range(0, 3):
        put(Fx + dx, Ey - 3 - (lift if dx <= 0 else 0), brow)
    # ---- a nose on the profile, one pixel past the face edge: lit on top, shaded under
    ny = Ey + 3
    xs = [x for x in range(Fx, Fx + 8) if px[min(W - 1, x), ny][3] > 0]
    if xs:
        nx = max(xs) + 1
        put(nx, ny, skin['m'], only_opaque=False)
        put(nx, ny + 1, skin['d'], only_opaque=False)
        put(nx - 1, ny + 1, skin['l'])
    # ---- the mouth: a short dark line with a lighter lip under it (open when frightened)
    lipc = _t(P._mix(skin['d'], (150, 62, 72), 0.6))
    lipl = _t(P._mix(skin['m'], (214, 120, 118), 0.55))
    my = Ey + 5                                                # the mouth: just under the nose, well above the chin
    if mood in ('scared', 'hurt'):
        for dx in range(3):
            put(Fx - 2 + dx, my, (96, 34, 46))
            put(Fx - 2 + dx, my + 1, lipl)
    elif mood in ('sad', 'angry'):
        put(Fx - 2, my + 1, lipc)
        put(Fx - 1, my, lipc)
        put(Fx, my + 1, lipc)
    else:
        for dx in range(3):
            put(Fx - 2 + dx, my, lipc)
        put(Fx - 1, my + 1, lipl)
    # ---- a flush on the cheek, and a soft shade under the cheekbone
    put(Ex + 2, Ey + 4, _t(P._mix(skin['m'], (232, 134, 124), 0.45)))
    put(Ex + 3, Ey + 4, _t(P._mix(skin['m'], (232, 134, 124), 0.30)))
    put(Fx + 1, Ey + 4, _t(P._mix(skin['d'], (214, 110, 110), 0.35)))
    # ---- hair: a warm highlight along the crown (only ON hair pixels), a bright catch, and a shade where the fringe falls on the brow
    hairset = {_t(hair[k]) for k in ('m', 'd', 'l', 'dd')}
    hl = _t(P._mix(hair['l'], p.get('hd', {}).get('sheen', (255, 222, 150)), 0.40 if 'sheen' not in p.get('hd', {}) else 0.55))   # warm on fair hair, a blue-violet sheen on black hair
    for (dx, dy) in ((-6, -6), (-5, -7), (-4, -8), (-3, -8), (-2, -9), (-1, -9), (0, -9)):          # a diagonal streak of light on the upper left of the crown
        xx, yy = Ex + dx + 2, Ey + dy
        if _t(px[xx, yy][:3]) in hairset:
            put(xx, yy, hl)
    for (dx, dy) in ((-4, -8), (-3, -8)):
        xx, yy = Ex + dx + 2, Ey + dy
        if _t(px[xx, yy][:3]) in hairset:
            put(xx, yy, (255, 238, 196))
    for dx in range(-1, 9):
        yy = Ey - 2
        if _t(px[Ex + dx, yy][:3]) == _t(skin['m']):
            put(Ex + dx, yy, skin['d'])                          # the shadow the fringe throws on the forehead


def outline(im, p):
    """A coloured selective outline round the figure (a Sonic / Mario contour, but in a deep shade of the colour it holds, never black)."""
    W, H = im.size
    src = im.copy().load()
    out = im.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3] == 0:
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < W and 0 <= yy < H) or src[xx, yy][3] == 0:
                    edge = True
            if edge:
                r, g, b = src[x, y][:3]
                out[x, y] = P._mix((r, g, b), (28, 14, 40), 0.55) + (255,)


def _tone_map(p):
    """Old tone -> new tone for each region, so a person has VARIETY of hue: shades lean toward indigo / plum / rose, lights toward warm yellow or cool aqua — never just a darker or lighter copy of one colour."""
    swap = {}
    g = P.tones(p['coat'])
    skin = P.tones(p['skin'], 0.84, 1.07, mute=0.0)
    legc = P.tones(p['legs'], 0.78, 1.2)
    sho = P.tones(p['shoes'], 0.66, 1.5, mute=0.0)
    hair = P.tones(p['hair'], 0.74, 1.24)
    hd = p.get('hd', {})

    def shade(c, toward, t):
        return P._mix(_t(c), toward, t) + (255,)
    for k, base in (('coat', g), ('skin', skin), ('legs', legc), ('shoes', sho), ('hair', hair)):
        spec = hd.get(k)
        if not spec:
            continue
        for tone, (toward, t) in spec.items():
            swap[_t(base[tone])] = shade(base[tone], toward, t)
    return swap


def swap_palette(im, p):
    swap = _tone_map(p)
    px = im.load()
    W, H = im.size
    for y in range(H):
        for x in range(W):
            a = px[x, y]
            if a[3] and _t(a) in swap:
                px[x, y] = swap[_t(a)]


def details(im, j, pose, p):
    """Body details in final pixels: the jumper's ribbed hem, laces and a bright toe-cap on the boots."""
    K = P.K
    px = im.load()
    W, H = im.size
    g = P.tones(p['coat'])
    sho = P.tones(p['shoes'], 0.66, 1.5, mute=0.0)
    hipx, hipy = j['hip']
    hem_y = int((hipy + p.get('drop', 1) - 1 + 1) * K) + 1
    for x in range(int((hipx - 5) * K), int((hipx + 6) * K)):
        if 0 <= x < W and 0 <= hem_y < H and _t(px[x, hem_y][:3]) in {_t(g['m']), _t(g['d']), _t(g['l'])} and px[x, hem_y][3]:
            px[x, hem_y] = _t(P._mix(px[x, hem_y][:3], _t(g['dd']), 0.5)) + (255,)       # the hem's rib: a darker line
    for key in ('ankle_n', 'ankle_f'):
        ax, ay = j[key]
        x0, y0 = int(round(ax)) - 2, int(round(ay))
        cx, cy = int((x0 + 1) * K), int((y0 + 1) * K)
        for dx in (1, 2):                                                               # the laces: two light pixels over the boot
            xx, yy = cx + dx, cy - 1
            if 0 <= xx < W and 0 <= yy < H and px[xx, yy][3] and _t(px[xx, yy][:3]) in {_t(sho['m']), _t(sho['d']), _t(sho['l'])}:
                px[xx, yy] = (226, 214, 188, 255)
