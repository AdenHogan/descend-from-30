#!/usr/bin/env python3
"""HUD PORTRAITS in the SPRITES' OWN LANGUAGE (owner: "Try 1" = a large bust built the way the game's characters are built; the placeholder busts and my five other attempts were rejected).

The same primitives as the sprites (`people.Cel`: ellipses with the one palette rule `people.tones`, hard little feature marks, a slightly-darkened rim), drawn on the same design grid
(46 x 58 design pixels) at 6 px a design pixel = 276 x 348, padded to the HUD's 281 x 351. A big soft head, a small pale face whose features are a few hand-placed design pixels (two dark
eyes with a glint, a brow, a nose bump on the profile, a short mouth), an ear, hair as a few rounded masses, an oversized garment — the same people as the sprites, close up, facing right.
Every health stage is built from the same marks, so the last stage is drawn to the same standard as the first.

    python3 tools/art/portrait_sprite.py joe /path/out.png
"""
import sys

from PIL import Image

import creatures as C
import people as P

K = 6.0


def person(name):
    return next(q for q in P.PLAYERS if q['name'] == name)


def pale(t, amt):
    """The sprites' tone family drained toward a sick grey-green by `amt`."""
    if amt <= 0.0:
        return t
    sick = (150, 156, 140)
    return {k: P._mix(v[:3], sick, amt) + (255,) for k, v in t.items()}


RED = (170, 28, 38, 255)
RED_D = (104, 14, 28, 255)
BRUISE = (112, 70, 128, 255)
BRUISE_Y = (150, 128, 84, 255)
GAUZE = (238, 232, 218, 255)
GAUZE_D = (196, 186, 170, 255)


def joe(stage=1):
    p = person('joe')
    pallor = (0.0, 0.0, 0.06, 0.16, 0.30, 0.46)[stage - 1]
    skin = pale(P.tones(p['skin'], 0.84, 1.07, mute=0.0), pallor)
    hair = P.tones(p['hair'], 0.74, 1.24)
    coat = P.tones(p['coat'])
    tee = P.tones(p.get('open', 'b8bcc0'))
    c = P.Cel()
    flat_d = {k: skin['d'] for k in skin}
    # ---- the garment: a broad soft jumper, a ribbed collar over a grey tee
    c.ell(23, 60, 25, 17, coat, keep=lambda x, y: y >= 42.5)
    c.ell(24, 44.5, 8.2, 5.2, coat, keep=lambda x, y: y >= 41.0)                     # the collar
    c.ell(24.4, 44.6, 5.6, 3.6, tee, flat=True, keep=lambda x, y: y >= 41.5)         # the tee inside it
    # ---- the neck, and the head's back mass of hair
    c.ell(24, 39.5, 4.4, 6.5, skin, flat=True)
    c.ell(24.5, 40.5, 4.4, 4.0, flat_d, flat=True, keep=lambda x, y: y > 38.6)       # the shadow under the jaw
    c.ell(20.5, 21.5, 14.5, 15.8, hair)
    # ---- the face: a pale oval, the nose a small bump on the profile, an ear
    c.ell(36.9, 30.7, 1.7, 2.0, skin, flat=True)                                    # the nose
    c.ell(25.8, 26.8, 11.6, 12.9, skin, flat=True)
    c.ell(25.8, 26.8, 11.6, 12.9, flat_d, flat=True, keep=lambda x, y: (x > 35.0) or (y > 38.8 and x > 24.5))
    c.ell(22.5, 19.8, 3.4, 1.5, {k: skin['l'] for k in skin}, flat=True)             # a light on the brow
    c.ell(16.3, 28.0, 2.3, 3.3, skin, flat=True)
    c.put(16, 27, skin['d'])
    c.put(16, 29, skin['d'])
    # ---- the hair over it: a cap, a swept fringe that comes lower on the right, locks on top, a sideburn
    c.ell(24.0, 17.6, 14.2, 11.2, hair, keep=lambda x, y: y < 18.4 + 0.42 * (x - 19.0) if x > 19.0 else y < 18.4)
    c.ell(21.0, 10.0, 7.0, 4.2, hair)
    c.ell(29.5, 11.0, 6.4, 4.0, hair)
    c.ell(16.8, 18.5, 3.6, 8.5, hair)
    c.ell(33.0, 15.5, 4.2, 3.4, hair, keep=lambda x, y: y < 20.0)
    # ---- the features, by stage: eyes open (a glint) -> tired -> shut; brows from level to worried; the mouth from closed to open
    eye = (26, 18, 34, 255)
    ink = hair['dd']
    for ex in (24, 31):
        if stage == 6:
            c.rect(ex, 27, ex + 1, 27, eye)                                           # shut
        elif stage == 5:
            c.rect(ex, 27, ex + 1, 28, eye)                                           # half-lidded
        else:
            c.rect(ex, 26, ex + 1, 28, eye)
            c.put(ex, 26, (250, 248, 244, 255))
    brow_lift = 0 if stage == 1 else 1
    c.rect(23, 24, 26, 24, ink)
    c.rect(30, 24, 33, 24, ink)
    if stage >= 2:
        c.put(23, 24 - brow_lift + 1, ink)                                             # the inner ends rise: worried
        c.put(33, 25, ink)
    else:
        c.put(33, 25, ink)
    c.put(37, 32, skin['dd'])
    lip = (196, 118, 108, 255)
    if stage >= 5:
        c.rect(30, 35, 33, 37, (88, 30, 44, 255))                                    # the mouth hangs open
        c.rect(31, 35, 32, 35, (232, 224, 208, 255))
    else:
        c.rect(30, 35, 33, 35, (120, 56, 64, 255))
        c.rect(31, 36, 32, 36, lip)
    for (sx, sy) in ((24, 38), (27, 39), (30, 38), (33, 37), (22, 36), (26, 41)):
        c.put(sx, sy, skin['d'])
    if stage <= 2:
        c.put(23, 31, (232, 150, 140, 255))                                              # a flush on the cheek
        c.put(30, 31, (222, 140, 130, 255))
    # ---- the wounds: flat, chunky design-pixel marks in the same language, so the last stage is drawn to the same standard as the first
    if stage >= 2:                                                                       # a scratch across the cheek, a drop of sweat
        for i in range(4):
            c.put(30 + i, 30 + i, RED)
        c.put(20, 20, (200, 226, 240, 255))
        c.put(20, 21, (160, 196, 224, 255))
    if stage >= 3:                                                                       # a bruise round the near eye, a split lip, a cut on the brow
        for (bx, by) in ((22, 29), (23, 29), (24, 29), (25, 29), (22, 30), (23, 30), (24, 30), (21, 28), (26, 29), (23, 31)):
            c.put(bx, by, BRUISE if (bx + by) % 3 else BRUISE_Y)
        c.put(31, 36, RED)
        c.put(32, 37, RED)
        c.put(32, 38, RED_D)
        c.rect(27, 23, 29, 23, RED)
    if stage >= 4:                                                                       # a bandage across the forehead, a blood trail down the temple
        for dx in range(0, 11):
            c.rect(20 + dx, 19 + dx // 6, 20 + dx, 21 + dx // 6, GAUZE if dx % 4 else GAUZE_D)
        c.rect(26, 19, 28, 21, RED)
        for y in range(22, 31):
            c.put(34, y, RED if y % 3 else RED_D)
    if stage >= 5:                                                                       # the bandage soaked; blood at the mouth and down the chin and the jumper
        for dx in range(5, 12):
            c.rect(20 + dx, 19 + dx // 6, 20 + dx, 21 + dx // 6, RED if dx % 2 else RED_D)
        for y in range(36, 44):
            c.put(31, y, RED if y % 2 else RED_D)
            c.put(33, y, RED_D)
        for (bx, by) in ((14, 52), (30, 50), (36, 54), (20, 56), (28, 57)):
            c.put(bx, by, RED)
            c.put(bx + 1, by, RED_D)
    if stage >= 6:                                                                       # more: runs from the bandage down the face and the neck
        for x in (23, 29, 36):
            for y in range(24, 37 + (x % 5)):
                c.put(x, y, RED if (x + y) % 2 else RED_D)
        for (bx, by) in ((18, 50), (24, 53), (32, 52), (38, 56), (26, 58), (12, 55)):
            c.rect(bx, by, bx + 1, by + 1, RED_D)
    P._outline(c, (40, 24, 44), 0.55)
    return c


if __name__ == '__main__':
    who = sys.argv[1] if len(sys.argv) > 1 else 'joe'
    out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/portrait_sprite.png'
    with C.at_scale(K):
        c = globals()[who](1)
        canvas = Image.new('RGBA', (281, 351), (0, 0, 0, 0))
        canvas.alpha_composite(c.im, (2, 1))
    bg = Image.new('RGBA', canvas.size, (58, 58, 68, 255))
    bg.alpha_composite(canvas)
    bg.save(out)
    print('wrote', out)
