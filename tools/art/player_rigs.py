#!/usr/bin/env python3
"""THE FOUR PLAYERS, AS THE GAME'S SPRITES (owner 2026-11-14: "start on the core set"; and, mid-way: "this allows for making those specific contextual hide
positions too, so it's not a generic crouch or something when hiding").

    python3 tools/art/player_rigs.py  ->  assets/players/<joe|vivianne|alex|amina>.png + _frames.tres + players.json

Each player is the people rig (tools/art/people.py) posed for every animation the player script plays. The CORE SET — a swing for each weapon with the weapon
IN HAND (bat / hammer, knife, sword), the shove, the hit, the death — is built for this pass; the walk, run, idle and a REAL crouch (the legs bend: the rig drops
the hips) come from the same poses; the pistol aim and shot too, so a gun is never an empty hand. What the old rig had that these do not yet: stairs, climbing,
kneeling at the pack, the torch pose, throwing, and the CONTEXTUAL HIDES (wardrobe, bath, behind a sofa, flat to the wall — the rig can pose any of them; they
are the next pass). Until then those animation NAMES play the nearest pose (`ALIAS`), so nothing the game asks for is missing.

Every animation keeps the DURATION the old sprite had (frames / speed) so the game's timers and `animation_finished` waits still agree. Cells are 108 x 108,
the body's hips on the cell's centre column and its feet on the bottom row; the game centres the sprite on the player and the cell's bottom edge on the floor.
"""
import json
import math
import os
import re
import sys
from contextlib import contextmanager

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import people as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'players')
DW, DH = 72, 72                                    # the design grid for these (taller and wider than the neighbours': a swing goes over the head)
CELL = (int(DW * P.K), int(DH * P.K))              # 84 x 108


@contextmanager
def canvas():
    old = (P.W, P.H, P.GROUND, P.ANKLE_Y, P.CW, P.CH)
    P.W, P.H = DW, DH
    P.GROUND = DH - 1
    P.ANKLE_Y = P.GROUND - 3
    P.CW, P.CH = int(DW * P.K), int(DH * P.K)
    try:
        yield
    finally:
        P.W, P.H, P.GROUND, P.ANKLE_Y, P.CW, P.CH = old


def lerp(a, b, t):
    return a + (b - a) * t


def keys(table, t):
    """Piecewise-linear value through [(t, value)...] (values numbers or tuples)."""
    for k in range(len(table) - 1):
        (t0, v0), (t1, v1) = table[k], table[k + 1]
        if t <= t1 or k == len(table) - 2:
            u = max(0.0, min(1.0, (t - t0) / float(t1 - t0)))
            if isinstance(v0, tuple):
                return tuple(lerp(a, b, u) for a, b in zip(v0, v1))
            return lerp(v0, v1, u)


# ---- poses: each returns (pose dict, item or None) for frame i of n ---------------------------------------------------------------------------------
def run(i, n):
    ph = i / float(n)
    pose = P.walk_pose(i, n=n, stride=1.5)
    arm = 30.0 * math.cos(2.0 * math.pi * ph)
    pose.update(n_arm=(-arm, 80 + max(0.0, -arm)), f_arm=(arm, 80 + max(0.0, arm)), lean=3.2, nod=0)
    return pose, None


THIGH = P.BONES['thigh']
SHIN = P.BONES['shin']


def _reach(a1, bend):
    """How far below the hip the ankle is, for a thigh at a1 degrees from straight down and a knee bent `bend` degrees back."""
    return THIGH * math.cos(math.radians(a1)) + SHIN * math.cos(math.radians(a1 - bend))


def plant(a1, reach):
    """The knee bend that puts the ankle exactly `reach` below the hip for a thigh at a1: both feet can then stand on the same floor at any thigh angle."""
    lo, hi = 0.0, 170.0
    for _ in range(40):
        mid = (lo + hi) / 2.0
        if _reach(a1, mid) > reach:
            lo = mid
        else:
            hi = mid
    return (a1, (lo + hi) / 2.0)


def idle(i, n):
    """Standing, but not still: the weight settles from one leg to the other, the arms hang a little out of step, the head turns a hair, and it breathes."""
    ph = 2.0 * math.pi * i / float(n)
    pose = P.idle_pose(i)
    sh = math.sin(ph)
    pose.update(n_leg=(3.0 * sh, 3.0 - 2.0 * sh), f_leg=(-3.0 * sh, 3.0 + 2.0 * sh), n_arm=(-4.0 + 3.0 * sh, 8.0 + 2.0 * math.cos(ph)), f_arm=(-2.0 - 3.0 * sh, 10.0),
                lean=0.2 + 0.25 * sh, head_dx=0.4 * math.sin(ph * 0.5))
    return pose, None


def walk(i, n):
    """A walk with weight: the shoulders turn against the hips, the forearm lags the upper arm by a beat, the head rides level."""
    ph = i / float(n)
    pose = P.walk_pose(i, n=n)
    arm = 22.0 * math.cos(2.0 * math.pi * (ph - 0.06))                        # the hand swings a beat behind the foot
    bend = lambda a: 10.0 + max(0.0, a) * 1.1                                   # the elbow folds as the arm comes forward
    pose.update(n_arm=(-arm, bend(arm)), f_arm=(arm, bend(-arm)), twist=1.1 * math.cos(2.0 * math.pi * ph), lean=1.0 + 0.4 * math.cos(4.0 * math.pi * ph))
    return pose, None


def crouch(i, n):
    """A stealth CREEP, not a squat: knees bent about 80 degrees, ONE foot ahead of the other and both on the floor, the back pitched forward, the head and the eyes up,
    the near hand reaching out ahead for balance and the far one held back. It breathes."""
    ph = 2.0 * math.pi * i / float(n)
    reach = 6.7 + 0.12 * math.sin(ph)
    nl, fl = plant(60, reach), plant(26, reach)
    pose = P.idle_pose(0)
    pose.update(n_leg=nl, f_leg=fl, spine=36, lean=0.0, head_dy=-2.0, head_dx=1.8, n_arm=(46, 78), f_arm=(-12, 60), breath=0, n_roll=None, f_roll='toe')
    return pose, None


def crouch_walk(i, n):
    """The creep, moving: a slow heel-toe step, the planted foot taking the weight, the swing foot lifted just clear; the arms stay low and quiet."""
    ph = i / float(n)
    base = crouch(0, n)[0]

    def leg(q, a_mid):
        q %= 1.0
        a1 = a_mid + 20.0 * math.cos(2.0 * math.pi * q)
        lift = 1.5 * math.sin(math.pi * (q - 0.5) / 0.5) if q >= 0.5 else 0.0
        return plant(a1, 6.7 - lift)
    base.update(n_leg=leg(ph, 42), f_leg=leg(ph + 0.5, 42), twist=0.8 * math.cos(2.0 * math.pi * ph), n_roll='heel' if ph % 1.0 < 0.1 else None,
                n_arm=(46 + 6.0 * math.cos(2.0 * math.pi * ph), 78), f_arm=(-12 - 6.0 * math.cos(2.0 * math.pi * ph), 60))
    return base, None


def hide_inside(i, n):
    """In a wardrobe: standing very straight, flat to the back, arms drawn in to the chest, chin down, holding its breath (the breath barely moves)."""
    pose = P.idle_pose(0)
    pose.update(mood='scared', n_arm=(18, 118), f_arm=(10, 124), lean=-0.3, head_dy=1.0, breath=0, n_leg=(2, 4), f_leg=(-1, 4))
    pose['breath'] = 1 if i % n == n // 2 else 0
    return pose, None


def hide_in(i, n):
    """Down in a bath or behind a shower curtain: sat low with the knees drawn up and the arms round them, the head down on them."""
    pose = P.idle_pose(0)
    nl, fl = plant(88, 5.2), plant(76, 5.2)
    pose.update(mood='scared', n_leg=nl, f_leg=fl, spine=18, lean=0.0, head_dy=2.5, head_dx=1.0, n_arm=(70, 100), f_arm=(62, 108), breath=1 if i % 3 == 0 else 0)
    return pose, None


def hide_behind(i, n):
    """Behind a sofa or an armchair: down as low as a crouch goes, the back against the furniture, both hands up on its top edge, the eyes just over it."""
    ph = 2.0 * math.pi * i / float(n)
    pose = P.idle_pose(0)
    nl, fl = plant(72, 5.6), plant(52, 5.6)
    pose.update(mood='wary', n_leg=nl, f_leg=fl, spine=22, lean=0.0, head_dy=-3.0, head_dx=1.4, n_arm=(118, 44), f_arm=(108, 52), breath=0, nod=1 if math.sin(ph) > 0.7 else 0)
    return pose, None


def hide_flat(i, n):
    """Pressed flat against a wall beside a doorway: standing, the back and the heels to the wall, the arms down tight, the head turned toward what might come."""
    pose = P.idle_pose(0)
    pose.update(mood='scared', n_arm=(-6, 4), f_arm=(-8, 4), lean=-0.9, head_dx=1.2, n_leg=(2, 3), f_leg=(0, 3), breath=1 if i % n == n // 2 else 0)
    return pose, None


def hide_dark(i, n):
    """In the dark: down on the floor, folded small — a deep crouch, the knees to the chest and the arms wrapped round them, the face tucked down."""
    pose = P.idle_pose(0)
    nl, fl = plant(98, 4.4), plant(86, 4.4)
    pose.update(mood='scared', n_leg=nl, f_leg=fl, spine=44, lean=0.0, head_dy=2.0, head_dx=0.5, n_arm=(76, 104), f_arm=(66, 110), breath=1 if i % 3 == 0 else 0)
    return pose, None


def _swing(table):
    """A swing from a keyed table: t -> (near shoulder, near elbow, far shoulder, far elbow, item rot, lean, dx, front leg, back leg)."""
    def f(i, n, item):
        t = i / float(n - 1)
        a1, a2, b1, b2, rot, lean, dx, fl, bl = keys(table, t)
        pose = P.idle_pose(0)
        pose.update(n_arm=(a1, a2), f_arm=(b1, b2), lean=lean, dx=dx, n_leg=(fl, 14 if fl > 8 else 4), f_leg=(bl, 4), item_rot=rot, breath=0)
        return pose, item
    return f


# (t, (near shoulder, near elbow, far shoulder, far elbow, item rotation, lean, dx, front-leg angle, back-leg angle))
_BAT = [(0.00, (60, 70, 55, 75, 0, 0.0, 0.0, 4, -4)), (0.18, (150, 40, 140, 50, -60, -1.5, -1.0, 6, -8)), (0.34, (205, 25, 195, 35, -118, -2.5, -1.5, 8, -10)),
        (0.50, (95, 15, 90, 20, 60, 3.5, 2.5, 26, -18)), (0.60, (35, 8, 30, 10, 105, 4.5, 3.5, 28, -20)), (0.80, (30, 30, 30, 30, 40, 2.0, 2.0, 16, -10)),
        (1.00, (60, 70, 55, 75, 0, 0.0, 0.0, 4, -4))]
_SWORD = [(0.00, (60, 70, 50, 80, 0, 0.0, 0.0, 4, -4)), (0.20, (175, 30, 120, 40, -75, -2.0, -1.0, 6, -8)), (0.38, (205, 20, 130, 30, -125, -2.8, -1.5, 8, -10)),
          (0.52, (110, 12, 70, 20, 25, 3.0, 2.5, 24, -16)), (0.64, (60, 6, 40, 10, 100, 4.0, 3.2, 28, -20)), (0.82, (40, 30, 30, 40, 60, 2.0, 1.5, 16, -10)),
          (1.00, (60, 70, 50, 80, 0, 0.0, 0.0, 4, -4))]
_KNIFE = [(0.00, (60, 80, 50, 85, 60, 0.0, 0.0, 4, -4)), (0.25, (35, 100, 40, 95, 40, -1.5, -1.0, 4, -6)), (0.45, (92, 6, 80, 12, 92, 3.5, 3.0, 26, -18)),
          (0.65, (92, 6, 80, 12, 92, 4.0, 3.5, 28, -20)), (0.85, (60, 60, 55, 70, 70, 1.5, 1.0, 14, -8)), (1.00, (60, 80, 50, 85, 60, 0.0, 0.0, 4, -4))]


def shove(i, n):
    t = i / float(n - 1)
    a, b, lean, dx, fl, bl = keys([(0.0, (50, 70, 50, 70, 0.0, 0.0, 4, -4)), (0.25, (30, 100, 30, 100, -2.5, -1.5, 6, -8)), (0.45, (98, 2, 94, 4, 4.5, 3.5, 28, -22)),
                                   (0.65, (98, 2, 94, 4, 4.8, 4.0, 30, -22)), (1.0, (50, 70, 50, 70, 0.0, 0.0, 4, -4))], t) if False else (None,) * 6
    row = keys([(0.0, (50, 70, 50, 70, 0.0, 0.0, 4, -4)), (0.25, (30, 100, 30, 100, -2.5, -1.5, 6, -8)), (0.45, (98, 2, 94, 4, 4.5, 3.5, 28, -22)),
                (0.65, (98, 2, 94, 4, 4.8, 4.0, 30, -22)), (1.0, (50, 70, 50, 70, 0.0, 0.0, 4, -4))], t)
    pose = P.idle_pose(0)
    pose.update(n_arm=(row[0], row[1]), f_arm=(row[2], row[3]), lean=row[4], dx=row[5], n_leg=(row[6], 10 if row[6] > 8 else 4), f_leg=(row[7], 6), breath=0)
    return pose, None


def hurt(i, n):
    pose = P.idle_pose(0)
    k = (0.7, 1.0, 0.8, 0.45)[i % 4]
    pose.update(mood='hurt', lean=-3.0 * k, dx=-3.0 * k, n_arm=(-45 * k, 40), f_arm=(-30 * k, 50), nod=1, n_leg=(10 * k, 8), f_leg=(-8 * k, 4), breath=1)
    return pose, None


def aim(i, n, shot=None):
    """Both arms out, a pistol in the near hand pointing right. `shot` (0..1 through the recoil) kicks the arms and the body."""
    pose = P.idle_pose(0)
    k = 0.0 if shot is None else math.sin(math.pi * min(1.0, shot * 1.6)) * (1.0 - shot * 0.4)
    pose.update(n_arm=(86 + 14 * k, 4), f_arm=(80 + 12 * k, 8), lean=0.5 - 2.5 * k, dx=-1.5 * k, item_rot=-6 * k, mood='calm', breath=0)
    return pose, 'gun'


def aim_walk(i, n):
    pose, item = aim(0, n)
    w = P.walk_pose(i, n=n)
    pose.update(n_leg=w['n_leg'], f_leg=w['f_leg'], n_roll=w.get('n_roll'), f_roll=w.get('f_roll'), hem_swing=w.get('hem_swing', 0.0))
    return pose, item


def aim_run(i, n):
    pose, item = aim(0, n)
    w = P.walk_pose(i, n=n, stride=1.5)
    pose.update(n_leg=w['n_leg'], f_leg=w['f_leg'], lean=2.5, n_roll=w.get('n_roll'), f_roll=w.get('f_roll'), hem_swing=w.get('hem_swing', 0.0))
    return pose, item


def shoot(i, n):
    return aim(0, n, shot=i / float(n - 1) if i else 0.0)


# ---- which pose each animation uses, its frame count; durations are kept from the old sprite ---------------------------------------------------------
SOURCES = {   # key: (builder(i, n, item?) , frames)
    'idle': (idle, 6), 'walk': (walk, 12), 'run': (run, 8), 'crouch_idle': (crouch, 6), 'crouch_walk': (crouch_walk, 8), 'shove': (shove, 10),
    'swing_bat': ('swing', 9, 'hammer', _BAT), 'swing_sword': ('swing', 9, 'sword', _SWORD), 'swing_knife': ('swing', 9, 'knife', _KNIFE),
    'hurt': (hurt, 4), 'death': ('death', 10), 'hide_inside': (hide_inside, 6), 'hide_in': (hide_in, 6), 'hide_behind': (hide_behind, 6), 'hide_flat': (hide_flat, 6),
    'hide_dark': (hide_dark, 6), 'roll': ('roll', 7), 'air_spin': ('roll', 6),
    'gun_idle': (aim, 2), 'gun_walk': (aim_walk, 8), 'gun_run': (aim_run, 8), 'gun_shoot': (shoot, 10),
}
# every animation NAME the game plays -> the source it uses (the old rig had these; names with no pose of their own yet play the nearest)
ALIAS = {
    'idle': 'idle', 'walk': 'walk', 'run': 'run', 'crouch_idle': 'crouch_idle', 'crouch_walk': 'crouch_walk', 'death': 'death', 'hurt': 'hurt',
    'push': 'shove', 'punch_jab': 'shove', 'punch': 'shove', 'punch_cross': 'shove',
    'katana_attack_continuous': 'swing_bat', 'sword_attack': 'swing_sword', 'sword_stab': 'swing_knife',
    'swing_bat': 'swing_bat', 'swing_sword': 'swing_sword', 'swing_knife': 'swing_knife',
    'katana_idle': 'idle', 'sword_idle': 'idle', 'katana_walk': 'walk', 'katana_run': 'run', 'sword_run': 'run', 'grab': 'idle',
    'roll': 'roll', 'air_spin': 'air_spin',
    'hide_inside': 'hide_inside', 'hide_in': 'hide_in', 'hide_behind': 'hide_behind', 'hide_flat': 'hide_flat', 'hide_dark': 'hide_dark',
    'gun_idle': 'gun_idle', 'gun_walk': 'gun_walk', 'gun_run': 'gun_run', 'gun_shoot': 'gun_shoot', 'run_aim': 'gun_walk', 'run_shooting': 'gun_run',
}
OLD_GUN = {'gun_idle': (1, 8.0, True), 'gun_walk': (8, 8.0, True), 'gun_run': (8, 14.0, True), 'gun_shoot': (10, 16.0, False)}


def old_timing():
    """{name: (frames, speed, loop)} of the old player sprite (scenes/player.tscn) + the gun animations the script builds at runtime."""
    s = open(os.path.join(ROOT, 'scenes', 'player.tscn')).read()
    out = {}
    for m in re.finditer(r'\{\s*"frames": \[(.*?)\],\s*"loop": (\w+),\s*"name": &"([^"]+)",\s*"speed": ([\d.]+)', s, re.S):
        out[m.group(3)] = (m.group(1).count('SubResource'), float(m.group(4)), m.group(2) == 'true')
    out.update(OLD_GUN)
    return out


def _render(player, builder, i, n, extra=None):
    pose, item = builder(i, n) if extra is None else builder(i, n, extra)
    im, j = P.draw(player, pose, item=item)
    return im, j


def _centre(im, hip_px):
    """Put the hips on the cell's centre column (so the sprite flips about the body, not about the cell)."""
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(im.width / 2.0 - hip_px)), 0))
    return out


def frames_for(player):
    with canvas():
        hip_px = (P.CX - 0.5) * P.K + P.K * 0.5
        out = {}
        for key, spec in SOURCES.items():
            if spec[0] == 'swing':
                _, n, item, table = spec
                b = _swing(table)
                out[key] = [_centre(P.draw(player, b(i, n, item)[0], item=item)[0], hip_px) for i in range(n)]
            elif spec[0] == 'death':
                out[key] = _death(player, spec[1], hip_px)
            elif spec[0] == 'roll':
                out[key] = _roll(player, spec[1], hip_px)
            else:
                b, n = spec
                out[key] = [_centre(_render(player, b, i, n)[0], hip_px) for i in range(n)]
    return out


def _death(player, n, hip_px):
    """It staggers (the hit pose), the knees go, it falls backward off its feet and lies where it fell, a dark pool spreading."""
    foot = (CELL[0] / 2.0, CELL[1] - 1.0)
    imgs = []
    stages = 4
    for i in range(n):
        t = i / float(n - 1)
        if i < stages:
            u = i / float(stages - 1)
            pose = P.idle_pose(0)
            pose.update(mood='hurt', lean=-2.0 - 2.5 * u, dx=-2.0 - 2.0 * u, n_arm=(-40, 40), f_arm=(-30, 50), nod=1, n_leg=(14 + 18 * u, 20 + 50 * u), f_leg=(-6 + 22 * u, 14 + 60 * u), breath=1)
            im = _centre(P.draw(player, pose)[0], hip_px)
        else:
            u = (i - stages + 1) / float(n - stages)
            e = u * u * (3.0 - 2.0 * u)
            pose = P.idle_pose(0)
            pose.update(mood='hurt', lean=-4.5, dx=-4.0, n_arm=(-40, 40), f_arm=(-30, 50), nod=1, n_leg=(32, 70), f_leg=(16, 74), breath=1)
            base = _centre(P.draw(player, pose)[0], hip_px)
            pad = Image.new('RGBA', (CELL[0], CELL[1] + 40), (0, 0, 0, 0))                # turning about its feet puts half its thickness under the floor line: work on a taller canvas,
            pad.alpha_composite(base)
            rot = _xf(pad, foot, rot=-86.0 * e, sy=1.0 - 0.25 * e)
            lift = int(round(10.0 * e))                                                  # ...then lift the whole body onto the floor
            im = rot.crop((0, lift, CELL[0], CELL[1] + lift))
            im = _shift_x(im, foot, 30.0 * e)                                             # it falls toward the left of its feet; the cell keeps the whole body in
            pool = _pool(foot, (3.0 + 20.0 * u) * P.K)
            both = Image.new('RGBA', im.size, (0, 0, 0, 0))
            both.alpha_composite(pool)
            both.alpha_composite(im)
            im = both
        imgs.append(im)
    return imgs


def _roll(player, n, hip_px):
    """A tuck, turning over once about the middle of the body (the dive off a balcony, the tumble)."""
    base = _centre(P.draw(player, dict(P.idle_pose(0), n_leg=(70, 110), f_leg=(76, 114), spine=40, n_arm=(60, 90), f_arm=(50, 95)))[0], hip_px)
    pivot = (CELL[0] / 2.0, CELL[1] * 0.68)
    out = []
    for i in range(n):
        im = _xf(base, pivot, rot=360.0 * i / float(n), s=0.8)
        shifted = Image.new('RGBA', im.size, (0, 0, 0, 0))
        shifted.alpha_composite(im, (0, int(CELL[1] * 0.68 - CELL[1] * 0.68)))
        out.append(shifted)
    return out


def _xf(im, pivot, rot=0.0, sy=1.0, s=1.0):
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    px, py = pivot

    def inv(x, y):
        dx, dy = x - px, y - py
        qx, qy = ca * dx + sa * dy, -sa * dx + ca * dy
        return px + qx / s, py + qy / (s * sy)
    x0, y0 = inv(0, 0)
    x1, y1 = inv(1, 0)
    x2, y2 = inv(0, 1)
    return im.transform(im.size, Image.AFFINE, (x1 - x0, x2 - x0, x0, y1 - y0, y2 - y0, y0), Image.NEAREST)


def _shift_x(im, foot, dx, dy=0.0):
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(dx)), int(round(dy))) if dy >= 0 else (int(round(dx)), 0))
    if dy < 0:
        out = Image.new('RGBA', im.size, (0, 0, 0, 0))
        out.paste(im, (int(round(dx)), int(round(dy))))
    return out


def _pool(foot, radius):
    from PIL import ImageDraw
    im = Image.new('RGBA', CELL, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fx, fy = foot
    for (col, k) in (((58, 12, 24, 255), 1.0), ((120, 22, 40, 255), 0.76), ((170, 40, 54, 255), 0.42)):
        rx, ry = radius * k, max(1.0, radius * 0.16 * k)
        d.ellipse([fx - rx, fy - ry, fx + rx, fy + ry * 0.5], fill=col)
    return im


# ---- writing ---------------------------------------------------------------------------------------------------------------------------------------------
def write_all():
    os.makedirs(OUT, exist_ok=True)
    old = old_timing()
    meta = {}
    for player in P.PLAYERS:
        name = player['name']
        src = frames_for(player)
        rows = list(src)
        cols = max(len(v) for v in src.values())
        sheet = Image.new('RGBA', (cols * CELL[0], len(rows) * CELL[1]), (0, 0, 0, 0))
        for r, k in enumerate(rows):
            for c, im in enumerate(src[k]):
                sheet.alpha_composite(im, (c * CELL[0], r * CELL[1]))
        sheet.save(os.path.join(OUT, name + '.png'))
        res = ['[gd_resource type="SpriteFrames" format=3]', '', '[ext_resource type="Texture2D" path="res://assets/players/%s.png" id="1_sheet"]' % name, '']
        subs, anims = [], []
        for an, key in ALIAS.items():
            n = len(src[key])
            of, osp, olp = old.get(an, (n, 8.0, True))
            speed = n / (of / osp) if of and osp else 8.0                          # the old DURATION: frames / speed
            if an in ('gun_idle',):
                speed = 4.0
            fl = []
            for c in range(n):
                sid = 'p_%s_%s_%d' % (name, key, c)
                if sid not in [x for x in subs if x.startswith('[sub_resource') and sid in x]:
                    subs += ['[sub_resource type="AtlasTexture" id="%s"]' % sid, 'atlas = ExtResource("1_sheet")',
                             'region = Rect2(%d, %d, %d, %d)' % (c * CELL[0], rows.index(key) * CELL[1], CELL[0], CELL[1]), '']
                fl.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
            loop = False if an in ('death', 'gun_shoot') else olp
            anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.2f\n}' % (', '.join(fl), 'true' if loop else 'false', an, speed))
        res += subs + ['[resource]', 'animations = [%s]' % ', '.join(anims), '']
        with open(os.path.join(OUT, name + '_frames.tres'), 'w') as fh:
            fh.write('\n'.join(res))
        meta[name] = dict(cell=list(CELL), rows={k: [r, len(src[k])] for r, k in enumerate(rows)})
    with open(os.path.join(OUT, 'players.json'), 'w') as fh:
        json.dump(dict(cell=list(CELL), feet_row=CELL[1] - 1, alias=ALIAS, players=meta), fh, indent=1, sort_keys=True)
    return meta


def self_check():
    """Every frame is inside its cell (nothing clipped), stands (the feet are on the bottom row) unless it is a fall / a roll, and every old animation name exists."""
    errs = []
    old = old_timing()
    for an in old:
        if an not in ALIAS:
            errs.append('the game plays "%s" and there is no pose mapped to it' % an)
    for player in P.PLAYERS:
        src = frames_for(player)
        for key, frs in src.items():
            for i, im in enumerate(frs):
                px = im.load()
                if im.getbbox() is None:
                    errs.append('%s %s %d: empty' % (player['name'], key, i))
                    continue
                if any(px[x, 0][3] for x in range(im.width)) or any(px[0, y][3] or px[im.width - 1, y][3] for y in range(im.height)):
                    errs.append('%s %s %d: touches the edge of its cell' % (player['name'], key, i))
    return errs


if __name__ == '__main__':
    errs = self_check()
    write_all()
    print('wrote players to', OUT)
    if errs:
        print('\n'.join(errs[:30]))
        sys.exit(1)
