"""THE STUDY — desks with their chairs, filing cabinets, tall bookcases, the radio room's gear and the painter's studio (owner round 47f: "expand to other module types too… a big pass").

A study is a SHELL plus PIECES laid by the planner, in five STYLES — den (the green-papered den with the mahogany partners desk, the banker's lamp and the cork board), office (the grey
open-plan cubicle: a steel desk, a computer, a printer, a swivel chair), library (the maroon-papered library of two tall bookcases, a portrait, a wing chair and a reading lamp), radio (the
hobbyist's radio room: a trestle table of amateur radio gear, a street map with pins, shelves of boxed parts) and studio (the painter's white-brick studio: canvases leaning, an easel,
a paint-stained table, shelves of tins). A desk carries its chair behind it, like the dining table carries its chairs.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chair3d as C3
import furn as F
import furnlib as FL
import propkit as K
from furnlib import piece
from furn_case import _book
from furn_living2 import FIN_C, _slab_door, INTERIOR, BRASS, BRASS_LT
from pixlib import hexc, shade, mix

STEEL = {'body': hexc('8a929a'), 'lt': hexc('b8c0c8'), 'dk': hexc('5a626a'), 'out': hexc('2a2e34'), 'handle': hexc('d8dce0')}


# ================================================================================================================================ desks
def _desk_variants():
    return {'mahogany': {'kind': 'mahogany', 'for': ['den']}, 'steel': {'kind': 'steel', 'for': ['office']}, 'writing': {'kind': 'writing', 'for': ['library']},
            'trestle': {'kind': 'trestle', 'for': ['radio']}, 'bench': {'kind': 'bench', 'for': ['studio']}}


@piece('desk_study', 68, 40, 'front', rooms={'study': 10}, styles=None, tags=('work', 'storage', 'desk'), variants=_desk_variants(), limit=1, feet=(110, 114),
       slots=({'id': 'top', 'dx0': 6, 'dx1': 62, 'dy': -27, 'top': True, 'kinds': ('desk', 'small', 'lamp')},),
       anchors=({'name': 'desk', 'dx': 34, 'dy': -24, 'top': True}, {'name': 'desk_drawer', 'dx': 12, 'dy': -12}), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'desk_drawer'},
       note='the study\'s desk with its chair behind it: a mahogany partners desk with a green leather top and a swivel leather chair (den), a grey steel desk with a laminate top and an office chair (office), a small walnut writing desk (library), a steel trestle for the transmitters (radio), a long splashed bench (studio)')
def desk_study(c, ox, oy, p):
    k = p['kind']
    x0, x1 = ox + 2, ox + 65
    top, base = oy - 27, oy
    c.shadow((x0 + x1) // 2, base + 1, 36, 2, 100)
    if k == 'mahogany':
        _chair_behind(c, ox + 34, oy - 6, 'wing', hexc('7a3a30'))
        _desk_body(c, x0, x1, top, base, FIN_C['walnut'], leather=hexc('2a5a3e'), drawers=True)
    elif k == 'steel':
        _chair_behind(c, ox + 20, oy - 6, 'office', hexc('2e2e34'))
        _desk_body(c, x0, x1, top, base, STEEL, leather=hexc('d8d4c4'), drawers=True, steel=True)
    elif k == 'writing':
        _chair_behind(c, ox + 34, oy - 6, 'wing', hexc('3e5a4a'))
        _desk_body(c, ox + 8, ox + 59, top + 2, base, FIN_C['oak'], leather=hexc('5a2e2a'), drawers=True)
    elif k == 'trestle':
        steel = STEEL
        c.rect(x0, top + 1, x1, top + 4, hexc('7a7e82'))                                                  # a steel trestle table: a thick plank top on two A-frame legs
        c.hline(x0, x1, top + 1, hexc('b8bcc0'))
        c.hline(x0, x1, top + 4, hexc('3a3e42'))
        for lx in (x0 + 4, x1 - 4):
            c.line(lx, top + 5, lx - 4, base, steel['dk'])
            c.line(lx, top + 5, lx + 4, base, steel['dk'])
            c.line(lx + 1, top + 5, lx - 3, base, steel['body'])
            c.line(lx + 1, top + 5, lx + 5, base, steel['body'])
        c.hline(x0 + 8, x1 - 8, base - 8, steel['dk'])
        c.rect(x0 + 24, base - 7, x0 + 38, base - 1, hexc('9a7a52'))                                       # a cardboard box shoved underneath
        c.hline(x0 + 24, x0 + 38, base - 7, hexc('c8a870'))
    else:                                                                                                  # the painter's bench: planks over trestles, daubed with paint
        wood = hexc('b8b8a8')
        c.rect(x0, top + 2, x1, top + 5, wood)
        c.hline(x0, x1, top + 2, hexc('d8d8c8'))
        c.hline(x0, x1, top + 5, hexc('6a6a5a'))
        for lx in (x0 + 3, x1 - 5):
            c.rect(lx, top + 6, lx + 2, base, hexc('8a8a7a'))
            c.vline(lx, top + 6, base, hexc('b0b0a0'))
        c.hline(x0 + 4, x1 - 4, base - 9, hexc('8a8a7a'))
        rng = random.Random(3)
        for _ in range(26):
            c.put(rng.randint(x0 + 1, x1 - 1), rng.randint(top + 2, top + 4), hexc(rng.choice(('d8483a', '3a7ad8', 'e0b830', '3a9a52', 'a85ac8', 'f0ece0'))))


def _chair_behind(c, cx, by, kind, col):
    if kind == 'office':
        C3.office_chair_at(c, cx, by, 0, {'fab': col, 'metal': hexc('3a3a3d')}, plan={}, key='study_chair', outline=hexc('111114'))
    else:
        pal = {'fab': col, 'fab_lt': shade(col, 1.14), 'wood': hexc('3a2618')}
        C3.armchair(c, cx, by, 0, pal, style='wing')


def _desk_body(c, x0, x1, top, base, f, leather, drawers, steel=False):
    c.rect(x0, top + 4, x1, base, f['out'])
    kx0, kx1 = x0 + 17, x1 - 17                                                                           # the kneehole
    c.rect(kx0, top + 4, kx1, base - 1, shade(f['dk'], 0.5))
    c.hline(kx0, kx1, top + 4, shade(f['dk'], 0.3))
    for (p0, p1) in ((x0 + 1, x0 + 15), (x1 - 15, x1 - 1)):                                              # the two pedestals
        c.rect(p0, top + 4, p1, base - 1, f['body'])
        c.vline(p0, top + 4, base - 1, f['lt'])
        c.vline(p1, top + 4, base - 1, f['dk'])
        n = 3 if not steel else 3
        h = (base - 1 - (top + 5)) // n
        for k in range(n):
            y0 = top + 5 + k * h
            c.rect(p0 + 1, y0, p1 - 1, y0 + h - 2, shade(f['body'], 0.95))
            c.hline(p0 + 1, p1 - 1, y0, f['lt'])
            c.hline(p0 + 1, p1 - 1, y0 + h - 2, f['dk'])
            hx = (p0 + p1) // 2
            c.hline(hx - 2, hx + 1, y0 + h // 2 - 1, f['handle'])
            c.put(hx - 2, y0 + h // 2 - 1, BRASS_LT if not steel else hexc('f0f4f8'))
    c.rect(x0 - 1, top, x1 + 1, top + 3, f['lt'])                                                         # the top
    c.hline(x0 - 1, x1 + 1, top, shade(f['lt'], 1.2))
    c.rect(x0 + 3, top - 1, x1 - 3, top + 2, leather)                                                      # the inset leather / laminate
    c.hline(x0 + 3, x1 - 3, top - 1, shade(leather, 1.3))
    c.hline(x0 - 1, x1 + 1, top + 4, f['out'])
    c.hline(kx0 + 2, kx1 - 2, top + 5, f['dk'])
    c.rect(kx0 + 3, top + 5, kx1 - 3, top + 7, f['body'])                                                  # the pencil drawer
    c.put((kx0 + kx1) // 2, top + 6, BRASS_LT if not steel else hexc('f0f4f8'))


# ================================================================================================================================ things on a desk
@piece('lamp_banker', 14, 20, 'top', rooms={'study': 7}, styles={'den': 8, 'library': 5, 'office': 1}, tags=('light', 'lamp'), on=('lamp', 'desk'), limit=1,
       variants={'green': {'shade': '2e6a46'}, 'amber': {'shade': 'b8742a'}}, lights=({'dx': 7, 'dy': -14, 'kind': 'table', 'top': True},),
       note='a banker\'s lamp: a brass stem and base under a long green glass shade, the light pooling on the leather')
def lamp_banker(c, ox, oy, p):
    shd = hexc(p['shade'])
    K.contact_shadow(c, ox + 7, oy + 0.5, 6, 1.3, 95)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 5, oy - 2, oy - 1, 3.4, BRASS, ry=1.0, gloss=True)
    lc.vline(ox + 5, oy - 12, oy - 2, BRASS)
    lc.vline(ox + 6, oy - 12, oy - 2, shade(BRASS, 0.7))
    for x in range(ox + 1, ox + 13):                                                                      # the long shade
        f = (x - ox - 1) / 11.0
        for y in range(oy - 17 + (1 if x > ox + 9 else 0), oy - 11 + (1 if x > ox + 9 else 0)):
            lc.put(x, y, shade(shd, 0.7 + 0.7 * (1.0 - f)) if y > oy - 16 else shade(shd, 1.4 - 0.5 * f))
    lc.hline(ox + 1, ox + 12, oy - 12, hexc('f8e8a8'))
    L.flush()


@piece('typewriter', 16, 11, 'top', rooms={'study': 5}, styles={'den': 6, 'library': 5, 'radio': 2}, tags=('small', 'work'), on=('desk',), limit=1,
       variants={'black': {'body': '2a2a2e'}, 'green': {'body': '3e5a4a'}},
       note='a manual typewriter with a sheet in the roller: a curved key bank, a round-keyed front, the carriage on top')
def typewriter(c, ox, oy, p):
    body = hexc(p['body'])
    K.contact_shadow(c, ox + 8, oy + 0.5, 8, 1.3, 95)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 6, ox + 15, oy - 1, body, d=3, top=shade(body, 1.3))
    lc.rect(ox + 2, oy - 11, ox + 14, oy - 8, shade(body, 0.8))
    lc.rect(ox + 4, oy - 13, ox + 12, oy - 10, hexc('ece6d4'))                                            # the paper in the roller
    for k in range(4):
        lc.put(ox + 3 + k * 3, oy - 4, hexc('d8d4c4'))
    L.flush()


@piece('globe', 14, 18, 'top', rooms={'study': 5}, styles={'library': 7, 'den': 4}, tags=('small',), on=('desk', 'small'), limit=1,
       variants={'blue': {'sea': '3a5a8a'}, 'old': {'sea': 'b8a060'}},
       note='a globe on a wooden stand: tilted on its brass meridian, blue seas and pale continents (or a yellowed old one)')
def globe(c, ox, oy, p):
    sea = hexc(p['sea'])
    K.contact_shadow(c, ox + 7, oy + 0.5, 6, 1.2, 95)
    L = K.Layer(c)
    lc = L.c
    K.cyl(lc, ox + 7, oy - 3, oy - 1, 3.6, hexc('5a3a26'), ry=1.0)
    lc.vline(ox + 7, oy - 6, oy - 3, hexc('5a3a26'))
    K.sphere(lc, ox + 7, oy - 11, 6.0, 6.0, sea, gloss=True)
    for (dx, dy, r) in ((-2, -2, 2.4), (2, 1, 2.0), (-1, 3, 1.6)):
        K.sphere(lc, ox + 7 + dx, oy - 11 + dy, r, r * 0.8, hexc('c8b880') if p['sea'] == '3a5a8a' else hexc('9a7a3a'))
    lc.line(ox + 2, oy - 14, ox + 11, oy - 6, BRASS)
    L.flush()


@piece('papers_pile', 22, 8, 'top', rooms={'study': 8}, styles=None, tags=('small', 'paper'), on=('desk',), limit=2,
       variants={'tidy': {'n': 5}, 'messy': {'n': 8}},
       note='a pile of papers and a folder: squared off on a tidy desk, slid and fanned on a messy one')
def papers_pile(c, ox, oy, p):
    K.contact_shadow(c, ox + 11, oy + 0.5, 11, 1.3, 90)
    rng = random.Random(p['n'])
    for k in range(p['n']):
        dx = rng.randint(-2, 2) if p['n'] > 5 else 0
        y = oy - 1 - k // 2
        c.rect(ox + 3 + dx + (k % 2), y - 1, ox + 17 + dx + (k % 2), y, hexc('ece6d4') if k % 3 else hexc('d8d0b4'))
        c.hline(ox + 3 + dx + (k % 2), ox + 17 + dx + (k % 2), y - 1, hexc('f8f4e8'))
    c.rect(ox + 4, oy - 5, ox + 12, oy - 3, hexc('c8a050'))
    c.hline(ox + 4, ox + 12, oy - 5, hexc('e8c870'))


@piece('computer_crt', 26, 26, 'top', rooms={'study': 7}, styles={'office': 8, 'radio': 1}, tags=('small', 'work'), on=('desk',), limit=1,
       variants={'beige': {'case': 'd8d0b8'}, 'grey': {'case': '8a8e94'}},
       anims=({'kind': 'static', 'dx': 4, 'dy': -17, 'w': 11, 'h': 9, 'color': '4a9a6a', 'top': True},),
       opens={'kind': 'screen_off', 'frames': 1, 'anchor': 'terminal'}, anchors=({'name': 'terminal', 'dx': 10, 'dy': -10, 'top': True},),
       note='an early desktop computer: a deep CRT monitor with a green phosphor glow, a keyboard in front and the beige base box under it')
def computer_crt(c, ox, oy, p):
    case = hexc(p['case'])
    on = p['open'] <= 0.001
    K.contact_shadow(c, ox + 13, oy + 0.5, 13, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 5, ox + 24, oy - 1, case, d=2, top=shade(case, 1.15))                           # the base box
    K.slab(lc, ox + 3, oy - 20, ox + 18, oy - 6, case, d=3, top=shade(case, 1.2))                          # the monitor
    lc.rect(ox + 5, oy - 18, ox + 16, oy - 9, hexc('15221a') if on else hexc('101414'))
    if on:
        for ty in (oy - 17, oy - 15, oy - 13, oy - 11):
            lc.hline(ox + 6, ox + 6 + (ty % 5) + 3, ty, hexc('5ac48a'))
    lc.hline(ox + 5, ox + 16, oy - 18, shade(hexc('15221a'), 1.6))
    lc.rect(ox + 4, oy - 3, ox + 21, oy - 1, shade(case, 0.88))                                           # the keyboard
    for kx in range(ox + 5, ox + 21, 2):
        lc.put(kx, oy - 3, shade(case, 1.2))
    L.flush()


# ================================================================================================================================ cabinets and shelves
@piece('filing_cabinet', 26, 44, 'wall', rooms={'study': 7}, styles={'den': 6, 'office': 8, 'radio': 3, 'library': 1, 'studio': 2}, tags=('storage', 'files'), depth=5,
       variants={'grey': {'f': 'grey'}, 'green': {'f': 'green'}, 'cream': {'f': 'cream'}},
       slots=({'id': 'top', 'dx0': 3, 'dx1': 22, 'dy': -42, 'top': True, 'kinds': ('small', 'desk')},),
       anchors=({'name': 'filing_cabinet', 'dx': 13, 'dy': -26}, {'name': 'filing_lower', 'dx': 13, 'dy': -10}), opens={'kind': 'drawer', 'frames': 3, 'anchor': 'filing_cabinet'}, feet=(105, 108),
       note='a steel filing cabinet of three drawers with label holders and recessed handles; the top drawer pulls out when searched')
def filing_cabinet(c, ox, oy, p):
    col = {'grey': hexc('8a929a'), 'green': hexc('5a7a62'), 'cream': hexc('d0c8ae')}[p['f']]
    lt, dk, out = shade(col, 1.25), shade(col, 0.68), shade(col, 0.4)
    t = p['open']
    x0, x1 = ox + 1, ox + 24
    top, base = oy - 42, oy
    c.shadow((x0 + x1) // 2, base + 1, 14, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, base, out)
    c.rect(x0, top + 1, x1, base - 1, col)
    c.vline(x0, top + 1, base - 1, lt)
    c.vline(x1, top + 1, base - 1, dk)
    c.hline(x0, x1, top + 1, lt)
    h = 13
    for k in range(3):
        y0 = top + 3 + k * (h + 1)
        off = min(5, int(round(5 * t))) if k == 0 else 0
        if k == 0 and off:
            c.rect(x0 + 1, y0 - 1, x1 - 1, y0 + off, INTERIOR)
            c.rect(x0 + 3, y0 - 1, x1 - 3, y0, hexc('ece6d4'))                                        # papers standing in the open drawer
        c.rect(x0 + 1, y0 + off, x1 - 1, y0 + h - 1 + off, shade(col, 0.96))
        c.hline(x0 + 1, x1 - 1, y0 + off, lt)
        c.hline(x0 + 1, x1 - 1, y0 + h - 1 + off, dk)
        c.rect(x0 + 8, y0 + 2 + off, x0 + 15, y0 + 4 + off, hexc('ece6d4'))                           # the label holder
        c.hline(x0 + 8, x0 + 15, y0 + 2 + off, shade(col, 0.5))
        c.hline(x0 + 7, x0 + 16, y0 + 8 + off, hexc('d8dce0'))                                        # the recessed handle
        c.hline(x0 + 7, x0 + 16, y0 + 9 + off, dk)
    c.rect(x0, base - 2, x1, base - 1, dk)


@piece('bookcase_tall', 36, 74, 'wall', rooms={'study': 8, 'living_room': 3}, styles={'library': 9, 'den': 6, 'studio': 1, 'cosy': 2}, tags=('books', 'storage'), depth=6,
       variants={'mahogany': {'fin': 'walnut', 'seed': 2}, 'oak': {'fin': 'oak', 'seed': 6}, 'ladder': {'fin': 'walnut', 'seed': 4, 'ladder': True}},
       slots=({'id': 'top', 'dx0': 4, 'dx1': 32, 'dy': -72, 'top': True, 'kinds': ('small',)},),
       anchors=({'name': 'bookcase_upper', 'dx': 18, 'dy': -52}, {'name': 'bookcase_lower', 'dx': 18, 'dy': -22}), feet=(105, 108),
       note='a tall library bookcase with a moulded cornice, five shelves of books of every height with a few lying flat and gaps where one was taken, a panelled cupboard base — one with a library ladder on a brass rail')
def bookcase_tall(c, ox, oy, p):
    f = FIN_C[p['fin']]
    rng = random.Random(p['seed'])
    x0, x1 = ox + 1, ox + 34
    top, base = oy - 72, oy
    c.shadow((x0 + x1) // 2, base + 1, 20, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, base - 3, f['out'])
    c.rect(x0 + 2, top + 5, x1 - 2, base - 15, shade(f['dk'], 0.4))
    for (sx0, sx1, lit) in ((x0, x0 + 1, True), (x1 - 1, x1, False)):
        c.rect(sx0, top + 3, sx1, base - 3, f['body'])
        c.vline(sx0, top + 3, base - 3, f['lt'] if lit else f['dk'])
    c.rect(x0 - 2, top, x1 + 2, top + 2, f['lt'])                                                         # the cornice
    c.hline(x0 - 2, x1 + 2, top, shade(f['lt'], 1.25))
    c.hline(x0 - 1, x1 + 1, top + 3, f['body'])
    c.hline(x0 - 1, x1 + 1, top + 4, shade(f['dk'], 0.7))
    shelf_ys = [top + 17 + k * 12 for k in range(5)]
    bays = []
    yb = top + 5
    for sy in shelf_ys:
        bays.append((yb, sy - 1))
        yb = sy + 2
    for (ya, yb2), sy in zip(bays, shelf_ys):
        x = x0 + 3
        bay_h = yb2 - ya + 1
        while x < x1 - 4:
            if rng.random() < 0.08:
                x += rng.randint(1, 3)
                continue
            w = rng.choice((2, 2, 3, 3, 3, 4))
            if x + w > x1 - 2:
                break
            _book(c, x, yb2, w, rng.randint(max(5, bay_h - 5), bay_h - 1), rng.choice(F.BOOKS), rng)
            x += w
        c.rect(x0 + 2, sy, x1 - 2, sy + 1, f['lt'])
        c.hline(x0 + 2, x1 - 2, sy, shade(f['lt'], 1.25))
        c.hline(x0 + 2, x1 - 2, sy + 2, shade(f['dk'], 0.5))
    c.rect(x0 + 1, base - 16, x1 - 1, base - 6, f['body'])                                                # the cupboard base
    c.hline(x0 + 1, x1 - 1, base - 16, f['lt'])
    c.rect(x0 + 4, base - 14, (x0 + x1) // 2 - 1, base - 8, shade(f['body'], 0.9))
    c.rect((x0 + x1) // 2 + 1, base - 14, x1 - 4, base - 8, shade(f['body'], 0.9))
    for hx in ((x0 + x1) // 2 - 3, (x0 + x1) // 2 + 2):
        c.vline(hx, base - 12, base - 10, BRASS)
    c.rect(x0, base - 5, x1, base - 3, f['dk'])
    for lx in (x0 + 1, x1 - 4):
        c.rect(lx, base - 3, lx + 3, base, f['body'])
    if p.get('ladder'):                                                                                   # a library ladder leaning on a brass rail
        c.line(x1 - 6, top + 6, x1 - 2, base - 8, hexc('8a6a46'))
        c.line(x1 - 8, top + 6, x1 - 4, base - 8, hexc('6a4a2e'))
        for k in range(8):
            c.hline(x1 - 7 + k // 2, x1 - 5 + k // 2, top + 12 + k * 7, hexc('8a6a46'))
        c.hline(x0 + 2, x1 - 2, top + 6, BRASS)


# ================================================================================================================================ the notice board
@piece('noticeboard', 40, 28, 'decor', rooms={'study': 8}, styles={'den': 9, 'office': 8, 'radio': 2}, tags=('notice', 'picture'), wall_y=(20, 34), limit=1,
       variants={'home': {'a': 'CALL', 'b': 'MOM', 'c': 'VET'}, 'work': {'a': 'TAX', 'b': 'DUE!', 'c': 'PAY'}},
       note='a cork board pinned over with snapshots and notes in a hand: CALL MOM, VET — or TAX DUE!, PAY, CALL BACK MON')
def noticeboard(c, ox, oy, p):
    c.rect(ox, oy, ox + 39, oy + 27, hexc('5a3e28'))                                                      # the frame
    c.rect(ox + 1, oy + 1, ox + 38, oy + 26, hexc('b08a58'))                                              # the cork
    rng = random.Random(3)
    for _ in range(60):
        c.put(rng.randint(ox + 2, ox + 37), rng.randint(oy + 2, oy + 25), hexc('9a7448') if rng.random() < 0.5 else hexc('c8a070'))
    for (x, y, w, h, col, word) in ((ox + 3, oy + 3, 14, 11, 'f0ece0', p['a']), (ox + 20, oy + 4, 16, 9, 'f4e07a', p['b']), (ox + 5, oy + 16, 12, 8, 'f0a8b8', p['c'])):
        c.rect(x, y, x + w - 1, y + h - 1, hexc(col))
        c.hline(x, x + w - 1, y, shade(hexc(col), 1.1))
        c.put(x + w // 2, y, hexc('d8483a'))                                                              # the pin
        F.text3(c, x + 1, y + 3, word, hexc('3a2a22'))
    c.rect(ox + 22, oy + 16, ox + 34, oy + 24, hexc('9ac4e0'))                                            # a snapshot
    c.rect(ox + 22, oy + 22, ox + 34, oy + 24, hexc('5a8a4a'))
    c.rect(ox + 26, oy + 18, ox + 28, oy + 22, hexc('d8483a'))
    c.put(ox + 28, oy + 17, hexc('e0b898'))


# ================================================================================================================================ the radio room (a hobbyist's)
@piece('radio_gear', 36, 20, 'top', rooms={'study': 8}, styles={'radio': 9}, tags=('small', 'radio'), on=('desk',), limit=1,
       variants={'set': {'k': 0}},
       anchors=({'name': 'radio_set', 'dx': 14, 'dy': -8, 'top': True},), sound=None,
       note='an amateur radio station on the table: a long transmitter with a row of dials and amber lights, a smaller receiver with a speaker grille, a coiled lead and a telescopic aerial')
def radio_gear(c, ox, oy, p):
    K.contact_shadow(c, ox + 18, oy + 0.5, 18, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    K.slab(lc, ox + 1, oy - 9, ox + 26, oy - 1, hexc('3a3e3a'), d=3, top=hexc('5a5e58'))
    lc.rect(ox + 3, oy - 7, ox + 12, oy - 6, hexc('e0a830'))
    for k in range(5):
        K.sphere(lc, ox + 5 + k * 4, oy - 3.5, 1.5, 1.5, hexc('b8bcb8'), gloss=True)
    K.slab(lc, ox + 28, oy - 8, ox + 35, oy - 1, hexc('4a5a44'), d=2, top=hexc('6a7a62'))
    lc.rect(ox + 29, oy - 6, ox + 34, oy - 3, hexc('2a3a28'))
    lc.line(ox + 33, oy - 11, ox + 35, oy - 20, hexc('b8bcc0'))
    lc.vline(ox + 30, oy - 12, oy - 9, hexc('2a2a2a'))
    L.flush()


@piece('map_street', 46, 34, 'decor', rooms={'study': 6}, styles={'radio': 9, 'den': 2, 'office': 1}, tags=('picture', 'notice'), wall_y=(20, 34), limit=1, variants={'pins': {}},
       note='a large street map of the town pinned to the wall: a blue river, a grid of streets, and a scatter of coloured pins where the owner has made contact with someone')
def map_street(c, ox, oy, p):
    c.rect(ox, oy, ox + 45, oy + 33, hexc('e6dcc0'))
    c.rect(ox + 1, oy + 1, ox + 44, oy + 32, hexc('f0e8d0'))
    for x in range(ox + 1, ox + 45, 7):
        c.vline(x, oy + 1, oy + 32, hexc('d0c8a8'))
    for y in range(oy + 1, oy + 33, 7):
        c.hline(ox + 1, ox + 44, y, hexc('d0c8a8'))
    c.line(ox + 20, oy + 1, ox + 32, oy + 14, hexc('6a9ac8'))                                            # the river
    c.line(ox + 21, oy + 1, ox + 33, oy + 14, hexc('6a9ac8'))
    c.line(ox + 32, oy + 14, ox + 36, oy + 32, hexc('6a9ac8'))
    c.line(ox + 33, oy + 14, ox + 37, oy + 32, hexc('6a9ac8'))
    c.rect(ox + 5, oy + 18, ox + 14, oy + 25, hexc('a8c898'))                                            # a park
    for (x, y, col) in ((6, 10, 'c8302a'), (14, 6, '3a6ab0'), (25, 22, 'e0b830'), (38, 8, 'c8302a'), (41, 26, '3a6ab0'), (10, 28, 'e0b830'), (28, 4, '3a9a52')):
        c.put(ox + x, oy + y, hexc(col))                                                                 # a pin: a bright head, a dark shadow
        c.put(ox + x + 1, oy + y + 1, hexc('4a4038'))
    for (x, y) in ((ox, oy), (ox + 45, oy), (ox, oy + 33), (ox + 45, oy + 33)):
        c.put(x, y, hexc('d8483a'))



# ================================================================================================================================ the studio
@piece('easel', 24, 52, 'floor', rooms={'study': 7}, styles={'studio': 9}, tags=('clutter', 'art'), limit=1,
       variants={'portrait': {'k': 'portrait'}, 'seascape': {'k': 'sea'}, 'blank': {'k': 'blank'}},
       anchors=({'name': 'easel', 'dx': 12, 'dy': -26},), feet=(108, 120),
       note='a wooden A-frame easel with a canvas on it — a half-finished portrait, a seascape with a sail, or a blank canvas — and a tray of tubes')
def easel(c, ox, oy, p):
    K.contact_shadow(c, ox + 12, oy + 0.5, 11, 1.4, 95)
    wood, wd = hexc('9a7448'), hexc('5e4430')
    cx = ox + 12
    c.line(cx - 8, oy - 2, cx - 3, oy - 44, wood)                                                         # the front legs and the rear leg
    c.line(cx + 8, oy - 2, cx + 3, oy - 44, wood)
    c.line(cx - 7, oy - 2, cx - 2, oy - 44, wd)
    c.line(cx + 7, oy - 2, cx + 2, oy - 44, wd)
    c.line(cx, oy - 44, cx, oy - 3, hexc('7a5a38'))
    c.rect(cx - 9, oy - 19, cx + 9, oy - 17, wood)                                                         # the shelf the canvas rests on
    c.hline(cx - 9, cx + 9, oy - 19, hexc('c8a070'))
    c.rect(cx - 9, oy - 44, cx + 9, oy - 21, hexc('f0ece0'))                                               # the canvas
    c.hline(cx - 9, cx + 9, oy - 44, hexc('c8c4b4'))
    c.vline(cx + 9, oy - 44, oy - 21, hexc('b0ac9c'))
    k = p['k']
    if k == 'portrait':
        c.rect(cx - 7, oy - 42, cx + 7, oy - 23, hexc('3a4a5a'))
        K.ell(c, cx, oy - 34, 3.2, 4.2, hexc('e0b898'))
        c.rect(cx - 6, oy - 29, cx + 5, oy - 23, hexc('8a2a2a'))
        c.rect(cx - 3, oy - 38, cx + 3, oy - 37, hexc('4a2a1a'))
    elif k == 'sea':
        c.rect(cx - 7, oy - 42, cx + 7, oy - 33, hexc('9ac4e0'))
        c.rect(cx - 7, oy - 32, cx + 7, oy - 23, hexc('2e5a8a'))
        c.poly([(cx, oy - 38), (cx + 4, oy - 31), (cx - 1, oy - 31)], hexc('f4f0e0'))
        c.vline(cx, oy - 38, oy - 30, hexc('3a2a1a'))
    else:
        c.rect(cx - 7, oy - 42, cx - 2, oy - 38, hexc('d8d4c4'))                                          # a few dabs and a pencil grid
        c.hline(cx - 7, cx + 7, oy - 32, hexc('d0ccbc'))
    c.rect(cx - 5, oy - 15, cx - 3, oy - 14, hexc('c8483a'))                                               # tubes on the shelf
    c.rect(cx - 1, oy - 15, cx + 1, oy - 14, hexc('3a7ad8'))
    c.rect(cx + 3, oy - 15, cx + 5, oy - 14, hexc('e0b830'))


@piece('canvases_leaning', 44, 54, 'wall', rooms={'study': 7}, styles={'studio': 9, 'library': 1}, tags=('storage', 'art'), depth=3,
       variants={'stack': {'k': 0}, 'few': {'k': 1}},
       anchors=({'name': 'canvases', 'dx': 20, 'dy': -26},), feet=(105, 108),
       note='a stack of framed and stretched canvases leaning against the wall, backs out, the front one turned round to show a seascape with a sail')
def canvases_leaning(c, ox, oy, p):
    c.shadow(ox + 22, oy + 1, 24, 2, 100)
    layers = [(ox + 2, 46, 52, 'e0d8c0'), (ox + 8, 38, 46, 'd4ccb2'), (ox + 14, 30, 40, 'c8c0a4')] if p['k'] == 0 else [(ox + 4, 36, 44, 'e0d8c0'), (ox + 14, 26, 36, 'd4ccb2')]
    for (x, w, h, col) in layers:
        top = oy - h
        c.rect(x, top, x + w - 1, oy, shade(hexc(col), 0.65))
        c.rect(x + 1, top + 1, x + w - 2, oy - 1, hexc(col))
        c.hline(x + 1, x + w - 2, top + 1, shade(hexc(col), 1.15))
        c.rect(x + 3, top + 4, x + 6, top + 7, shade(hexc(col), 0.8))                                      # the wooden stretcher bars seen from the back
        for k in range(3):
            c.hline(x + 8, x + w - 4, top + 6 + k * 9, shade(hexc(col), 0.85))
    x, w = ox + 20, 22                                                                                      # the front canvas, turned round: a seascape
    c.rect(x, oy - 36, x + w, oy, hexc('3a2e22'))
    c.rect(x + 1, oy - 35, x + w - 1, oy - 1, hexc('9ac4e0'))
    c.rect(x + 1, oy - 20, x + w - 1, oy - 1, hexc('2e5a8a'))
    c.poly([(x + 10, oy - 30), (x + 15, oy - 21), (x + 9, oy - 21)], hexc('f4f0e0'))
    c.vline(x + 10, oy - 30, oy - 20, hexc('3a2a1a'))
    c.rect(x + 1, oy - 15, x + w - 1, oy - 14, hexc('4a7aaa'))


@piece('paint_shelf', 28, 52, 'wall', rooms={'study': 6}, styles={'studio': 9, 'radio': 1}, tags=('storage', 'art', 'books'), depth=5,
       variants={'pine': {'fin': 'oak'}},
       anchors=({'name': 'paint_shelf_upper', 'dx': 14, 'dy': -38}, {'name': 'paint_shelf_lower', 'dx': 14, 'dy': -14}), feet=(105, 108),
       note='a pine shelving unit of paint tins, jars of brushes, bottles of turps and tubes — rows of labelled tins with drips of colour down the sides')
def paint_shelf(c, ox, oy, p):
    f = FIN_C[p['fin']]
    x0, x1 = ox + 1, ox + 26
    top, base = oy - 50, oy
    c.shadow((x0 + x1) // 2, base + 1, 15, 2, 100)
    c.rect(x0 - 1, top, x1 + 1, base, f['out'])
    c.rect(x0, top + 1, x1, base - 1, shade(f['dk'], 0.5))
    for sy in (top + 16, top + 33, base - 3):
        c.rect(x0, sy, x1, sy + 1, f['lt'])
        c.hline(x0, x1, sy + 2, f['dk'])
    c.vline(x0, top + 1, base - 1, f['lt'])
    c.vline(x1, top + 1, base - 1, f['dk'])
    rng = random.Random(2)
    for row, ya in enumerate((top + 16, top + 33, base - 3)):
        x = x0 + 2
        while x < x1 - 6:
            col = hexc(rng.choice(('d8483a', '3a7ad8', 'e0b830', '3a9a52', 'a85ac8', 'f0ece0', 'c8c8c0')))
            w = rng.choice((5, 5, 6))
            h = rng.choice((8, 9, 10)) if row else rng.choice((6, 8))
            c.rect(x, ya - h, x + w - 1, ya - 1, shade(col, 0.8))
            c.rect(x + 1, ya - h, x + w - 1, ya - 1, col)
            c.hline(x, x + w - 1, ya - h, hexc('c8c8c0'))                                                  # the tin's rim
            c.hline(x + 1, x + w - 2, ya - h + 3, hexc('e8e4d0'))                                          # the label
            if rng.random() < 0.5:
                c.vline(x + 1 + rng.randint(0, w - 3), ya - h + 1, ya - h + 4, shade(col, 1.25))        # a drip of colour
            x += w + 1


@piece('printer_stand', 28, 36, 'floor', rooms={'study': 6}, styles={'office': 9}, tags=('clutter', 'work'), limit=1,
       variants={'cream': {'case': 'd8d0b8'}},
       anchors=({'name': 'printer', 'dx': 14, 'dy': -22},), feet=(108, 120),
       note='a printer on a wire stand: a beige dot-matrix with a fan of paper feeding out and a spill of printouts on the floor')
def printer_stand(c, ox, oy, p):
    case = hexc(p['case'])
    K.contact_shadow(c, ox + 14, oy + 0.5, 14, 1.4, 95)
    L = K.Layer(c)
    lc = L.c
    for lx in (ox + 3, ox + 24):
        lc.vline(lx, oy - 22, oy - 1, hexc('8a8e94'))
        lc.vline(lx + 1, oy - 22, oy - 1, hexc('5a5e64'))
    lc.rect(ox + 2, oy - 22, ox + 26, oy - 21, hexc('8a8e94'))
    lc.rect(ox + 2, oy - 12, ox + 26, oy - 11, hexc('8a8e94'))
    K.slab(lc, ox + 4, oy - 31, ox + 24, oy - 23, case, d=3, top=shade(case, 1.2))
    lc.rect(ox + 6, oy - 29, ox + 22, oy - 28, shade(case, 0.7))
    lc.rect(ox + 9, oy - 37, ox + 19, oy - 33, hexc('ece6d4'))                                            # paper standing out of the back
    lc.rect(ox + 8, oy - 24, ox + 20, oy - 15, hexc('f4f0e4'))                                            # a sheet fanning from the front
    for k in range(3):
        lc.hline(ox + 9, ox + 19, oy - 22 + k * 3, hexc('b8b4a4'))
    lc.rect(ox + 5, oy - 4, ox + 13, oy - 2, hexc('ece6d4'))                                              # printouts spilled below
    lc.rect(ox + 15, oy - 3, ox + 22, oy - 1, hexc('d8d4c4'))
    L.flush()


@piece('waste_bin', 14, 16, 'floor', rooms={'study': 6, 'bathroom': 3, 'living_room': 1}, styles={'office': 8, 'den': 4, 'library': 2, 'studio': 3, 'radio': 1}, tags=('clutter', 'rubbish'), limit=1,
       variants={'wire': {'col': '4a4e54', 'wire': True}, 'steel': {'col': '8a9098'}},
       feet=(108, 121), near=('work',), anchors=({'name': 'trashcan', 'dx': 7, 'dy': -8},),
       note='a waste basket: black wire mesh or dented steel, crumpled paper heaped over the rim')
def waste_bin(c, ox, oy, p):
    col = hexc(p['col'])
    K.contact_shadow(c, ox + 7, oy + 0.5, 7, 1.2, 95)
    L = K.Layer(c)
    lc = L.c
    K.frustum(lc, ox + 7, oy - 12, oy - 1, 5.6, 4.4, col, ry_t=1.6, ry_b=1.2, inner=hexc('1a1a1e'), rim=shade(col, 1.3))
    if p.get('wire'):
        for k in range(-4, 5, 2):
            lc.vline(int(ox + 7 + k), oy - 11, oy - 2, shade(col, 0.6))
        lc.hline(ox + 3, ox + 11, oy - 7, shade(col, 0.6))
    for (dx, dy, r) in ((-2, -13, 2.2), (1, -14, 2.4), (3, -12, 2.0)):
        K.sphere(lc, ox + 7 + dx, oy + dy, r, r, hexc('ece6d4'))
    L.flush()


@piece('sketches_wall', 36, 28, 'decor', rooms={'study': 6}, styles={'studio': 9, 'library': 1}, tags=('picture', 'art'), wall_y=(20, 36), limit=1, variants={'sheets': {}},
       note='sheets of paper pinned to the plaster: a line drawing of a sailing boat, a watercolour of tulips in a blue vase, and a row of paint tubes hung below on a string')
def sketches_wall(c, ox, oy, p):
    # TWO SHEETS OF THE SAME SIZE (15 x 17, owner round 47h: "the picture of the ship and the picture of the flowers aren't the same size… one flower is not in the pot"), pinned at the same
    # height; everything drawn on a sheet is inside it. Sheet rows 0..16, columns 0..14 (relative to the sheet's own corner).
    paper, edge = hexc('f4f0e4'), hexc('c8c4b4')
    ink, sea = hexc('3a3a44'), hexc('6a9ac8')
    for sx in (ox + 1, ox + 19):
        c.rect(sx, oy, sx + 14, oy + 16, paper)
        c.hline(sx, sx + 14, oy, edge)
    s = ox + 1                                                                                            # the sailing boat: a mast, a mainsail and a jib, a hull, the water
    c.line(s + 7, oy + 3, s + 7, oy + 10, ink)
    c.poly([(s + 8, oy + 3), (s + 12, oy + 10), (s + 8, oy + 10)], hexc('9ac0e0'))
    c.poly([(s + 6, oy + 5), (s + 3, oy + 10), (s + 6, oy + 10)], hexc('c8dcee'))
    c.hline(s + 3, s + 12, oy + 11, ink)
    c.hline(s + 4, s + 11, oy + 12, ink)
    c.hline(s + 2, s + 12, oy + 14, sea)
    c.hline(s + 4, s + 10, oy + 15, hexc('9ac0e0'))
    s = ox + 19                                                                                           # the tulips: three heads on three stems that all stand inside the vase's mouth
    stems = (s + 4, s + 7, s + 10)
    heads = ((s + 3, oy + 4, 'd8483a'), (s + 6, oy + 2, 'e0b830'), (s + 9, oy + 4, 'd8483a'))               # (left, top, colour): each head 3 wide x 4 tall over its stem
    for (hx, hy, col) in heads:
        c.rect(hx, hy, hx + 2, hy + 3, hexc(col))
        c.put(hx + 1, hy - 1 if col == 'e0b830' else hy, shade(hexc(col), 1.18))
    for k, sx_ in enumerate(stems):
        c.vline(sx_, oy + (6 if k == 1 else 8), oy + 10, hexc('4a8a4a'))
    c.put(s + 5, oy + 9, hexc('4a8a4a'))
    c.put(s + 9, oy + 9, hexc('4a8a4a'))
    c.rect(s + 3, oy + 11, s + 11, oy + 12, hexc('6a9ad8'))                                               # the vase: a rim and a body narrowing to its foot
    c.rect(s + 4, oy + 13, s + 10, oy + 14, hexc('4a7ab8'))
    c.rect(s + 5, oy + 15, s + 9, oy + 15, hexc('3a6aa8'))
    for k, col in enumerate(('d8483a', '3a7ad8', 'e0b830', '3a9a52', 'a85ac8')):                          # tubes hung on a string
        c.rect(ox + 4 + k * 6, oy + 21, ox + 6 + k * 6, oy + 25, hexc(col))
        c.put(ox + 5 + k * 6, oy + 20, hexc('3a3228'))
    c.hline(ox + 3, ox + 32, oy + 19, hexc('6a5a44'))
    for (x, y) in ((ox + 8, oy), (ox + 26, oy)):
        c.put(x, y, hexc('d8483a'))
