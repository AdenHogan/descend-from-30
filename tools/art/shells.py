"""ROOM SHELLS — the bare room a furniture plan is laid into (owner round 47).

A baked module (pixlib.finish_module) is wall + floor + every piece of furniture in one picture. A SHELL is the same room with NOTHING in it: the wallpaper, its damp and peeling,
the skirting, the carpet or boards in perspective — and the game lays furniture over it at runtime (scripts/furniture_planner.gd, assets/furniture/). It still needs everything a module's
art needs: the floor strip + extension the end walls use (`_floor.png`, `_floor_ext.png`), the run-2 / run-3 looks (damp, cracks, peeled paper, debris), a scene the room code can load
(scenes/Room_Shells/<name>.tscn: an Art sprite, the room-type label, and the metadata that says which plan fills it). No anchors, lights or anims — those come with the furniture.

Run-look floor debris stays IN FRONT of the step-up stand rows (y >= 119): the furniture is not known when the art is baked, and nothing may lie where the player steps up.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image

import pixlib
from pixlib import Canvas, W, H, SEAM_Y, save_floor_strip, floor_is_periodic, run_looks, check_edge_columns

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SHELL_DIR = os.path.join(ROOT, 'scenes', 'Room_Shells')
LABELS = {'bedroom': 'Bedroom', 'bathroom': 'Bathroom', 'kitchen': 'Kitchen', 'study': 'Study', 'living_room': 'Living Room', 'dining_room': 'Dining Room'}
DEBRIS_Y0 = 119


def write_shell_scene(name, room_type, plan):
    import re
    path = os.path.join(SHELL_DIR, name + '.tscn')
    os.makedirs(SHELL_DIR, exist_ok=True)
    uid = ''
    if os.path.exists(path):
        m = re.search(r'uid="(uid://[a-z0-9]+)"', open(path).read().split('\n', 1)[0])
        if m:
            uid = ' uid="%s"' % m.group(1)
    out = ['[gd_scene format=3%s]' % uid, '',
           '[ext_resource type="Texture2D" path="res://assets/rooms/%s.png" id="1_art"]' % name, '',
           '[node name="Node2D" type="Node2D"]', 'metadata/furniture_plan = "%s"' % plan, '',
           '[node name="ColorRect" type="ColorRect" parent="."]', 'offset_right = 320.0', 'offset_bottom = 144.0', 'color = Color(0.4, 0.4, 0.4, 1)', '',
           '[node name="Label" type="Label" parent="ColorRect"]', 'layout_mode = 0', 'offset_right = 318.0', 'offset_bottom = 100.0',
           'theme_override_font_sizes/font_size = 32', 'visible = false', 'text = "%s"' % LABELS[room_type], 'horizontal_alignment = 1', 'vertical_alignment = 1', '',
           '[node name="Art" type="Sprite2D" parent="."]', 'texture_filter = 1', 'texture = ExtResource("1_art")', 'centered = false', '']
    open(path, 'w').write('\n'.join(out))
    return path


def finish_shell(name, room_type, plan, seed, wall_fn, floor_fn, build_fn, check=False):
    """Render + export one shell. wall_fn(c) = the bare wall (with its damp / peeling), floor_fn = the @persp floor, build_fn(c) = wall + floor, nothing standing in it."""
    main = Canvas(seed=seed)
    build_fn(main)
    bare = Canvas(seed=seed)
    wall_fn(bare)
    bare_floor = Canvas(seed=seed)
    wall_fn(bare_floor)
    floor_fn(bare_floor)
    errs = []
    holes = [(x, y) for y in range(H) for x in range(W) if main.img.getpixel((x, y))[3] != 255]
    if holes:
        errs.append('transparent pixels in the shell: %s' % holes[:6])
    if main.img.tobytes() != bare_floor.img.tobytes():
        errs.append('the shell must be exactly wall + floor (nothing standing in it)')
    if check_edge_columns(main.img, bare.img):
        errs.append('something in the side-wall sample columns')
    fl = save_floor_strip(floor_fn, name, ROOT, seed=seed)
    if not floor_is_periodic(fl):
        errs.append('the (flat) floor must repeat every 32px')
    if errs:
        sys.exit(name + ':\n  ' + '\n  '.join(errs))
    if check:
        import io
        b = io.BytesIO()
        main.img.save(b, format='PNG')
        stale = []
        path = os.path.join(ROOT, 'assets', 'rooms', name + '.png')
        if not os.path.exists(path) or open(path, 'rb').read() != b.getvalue():
            stale.append(name + '.png')
        for suffix in ('_r2.png', '_r3.png', '_floor.png', '_floor_ext.png', '_r2_floor_ext.png', '_r3_floor_ext.png'):
            if not os.path.exists(os.path.join(ROOT, 'assets', 'rooms', name + suffix)):
                stale.append(name + suffix)
        if not os.path.exists(os.path.join(SHELL_DIR, name + '.tscn')):
            stale.append(name + '.tscn')
        return stale
    main.img.save(os.path.join(ROOT, 'assets', 'rooms', name + '.png'))
    runs = run_looks(name, ROOT, main.img, main.img, bare.img, bare_floor.img, floor_fn, seed, False, debris_y0=DEBRIS_Y0)
    prev = os.path.join(ROOT, 'docs', 'art_reference', 'furniture')
    os.makedirs(prev, exist_ok=True)
    sheet = Image.new('RGBA', (W * 2 * 3, H * 2), (0, 0, 0, 255))
    for i, im in enumerate((main.img, runs[2], runs[3])):
        sheet.paste(im.resize((W * 2, H * 2), Image.NEAREST), (W * 2 * i, 0))
    sheet.save(os.path.join(prev, name + '_runs.png'))
    write_shell_scene(name, room_type, plan)
    print('wrote shell', name)
    return main.img
