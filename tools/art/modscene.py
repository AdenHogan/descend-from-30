"""Writes a room-module scene (scenes/Room_Modules/<name>.tscn) from an art script's own spec, so a
module's furniture and its scavenge nodes are defined in ONE place (the tools/art/<name>.py script).

Scene shape (what scripts/room.gd expects):
  Node2D
    ColorRect (placeholder colour) / Label (HIDDEN — room.gd reads its text for the room type)
    Art        Sprite2D  res://assets/rooms/<name>.png
    StripArt   Sprite2D  res://assets/rooms/<name>_strip.png   (balcony-capable rooms, optional:
               the furniture standing where the balcony doors go; room.gd hides it on a balcony slot)
    Balcony    Node2D    (balcony-capable rooms) holding BalconyArt, a Sprite2D of
               res://assets/rooms/balcony.png (tools/art/balcony.py — the loggia behind the back wall,
               drawn OVER the art; room.gd shows it on a balcony slot and swaps its run looks)
    anchor_*   Marker2D  metadata/back_plane (set back on furniture), metadata/balcony_strip (in the
               balcony strip — room.gd removes it on a balcony slot)
    Lights     Node2D    the light FIXTURES drawn in the art (lamps, ceiling lights): lamp_<n> Node2D
               children at the bulb, metadata/kind (+ metadata/balcony_strip). NOT Marker2D — room.gd
               treats every direct Marker2D child as a scavenge anchor. scripts/apartment_lights.gd
               lights them.
    Anims      Node2D    small LIVE details (a milk drip): anim_<n> Node2D children running
               scripts/module_anim.gd, metadata/kind (+ fall, color).

An existing scene's uid is kept so nothing that references it breaks.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LABELS = {'bedroom': 'Bedroom', 'bathroom': 'Bathroom', 'kitchen': 'Kitchen', 'study': 'Study',
          'living_room': 'Living Room', 'dining_room': 'Dining Room'}
BALCONY_TYPES = ('study', 'dining_room')


def write_scene(name, room_type, anchors, strip=False, lights=(), anims=()):
    """anchors: [(node_name, x, y, flags)] — flags a string containing 'bp' (back plane) and/or
    's' (balcony strip)."""
    path = os.path.join(ROOT, 'scenes', 'Room_Modules', name + '.tscn')
    uid = ''
    if os.path.exists(path):
        m = re.search(r'uid="(uid://[a-z0-9]+)"', open(path).read().split('\n', 1)[0])
        if m:
            uid = ' uid="%s"' % m.group(1)
    names = [a[0] for a in anchors]
    assert len(names) == len(set(names)), 'duplicate anchor names in %s' % name
    for n in names:
        assert n.startswith('anchor_'), n
    out = ['[gd_scene format=3%s]' % uid, '',
           '[ext_resource type="Texture2D" path="res://assets/rooms/%s.png" id="1_art"]' % name]
    if strip:
        out.append('[ext_resource type="Texture2D" path="res://assets/rooms/%s_strip.png" id="2_strip"]' % name)
    if room_type in BALCONY_TYPES:
        out.append('[ext_resource type="Texture2D" path="res://assets/rooms/balcony.png" id="3_balcony"]')
    if anims:
        out.append('[ext_resource type="Script" path="res://scripts/module_anim.gd" id="4_anim"]')
    out += ['', '[node name="Node2D" type="Node2D"]', '',
            '[node name="ColorRect" type="ColorRect" parent="."]',
            'offset_right = 320.0', 'offset_bottom = 144.0', 'color = Color(0.4, 0.4, 0.4, 1)', '',
            '[node name="Label" type="Label" parent="ColorRect"]',
            'layout_mode = 0', 'offset_right = 318.0', 'offset_bottom = 100.0',
            'theme_override_font_sizes/font_size = 32', 'visible = false',
            'text = "%s"' % LABELS[room_type], 'horizontal_alignment = 1', 'vertical_alignment = 1', '',
            '[node name="Art" type="Sprite2D" parent="."]',
            'texture_filter = 1', 'texture = ExtResource("1_art")', 'centered = false', '']
    if strip:
        out += ['[node name="StripArt" type="Sprite2D" parent="."]',
                'texture_filter = 1', 'texture = ExtResource("2_strip")', 'centered = false', '']
    if room_type in BALCONY_TYPES:
        out += ['[node name="Balcony" type="Node2D" parent="."]', '',
                '[node name="BalconyArt" type="Sprite2D" parent="Balcony"]',
                'texture_filter = 1', 'texture = ExtResource("3_balcony")', 'centered = false', '']
    for (n, x, y, flags) in anchors:
        out.append('[node name="%s" type="Marker2D" parent="."]' % n)
        out.append('position = Vector2(%d, %d)' % (x, y))
        if 'bp' in flags:
            out.append('metadata/back_plane = true')
        if 's' in flags.replace('bp', ''):
            out.append('metadata/balcony_strip = true')
        out.append('')
    if lights:
        out += ['[node name="Lights" type="Node2D" parent="."]', '']
        for i, (x, y, kind, flags) in enumerate(lights):
            out.append('[node name="lamp_%d" type="Node2D" parent="Lights"]' % i)
            out.append('position = Vector2(%d, %d)' % (x, y))
            out.append('metadata/kind = "%s"' % kind)
            if 's' in flags:
                out.append('metadata/balcony_strip = true')
            out.append('')
    if anims:
        out += ['[node name="Anims" type="Node2D" parent="."]', '']
        for i, (x, y, kind, fall, col, w, h) in enumerate(anims):
            out.append('[node name="anim_%d" type="Node2D" parent="Anims"]' % i)
            out.append('position = Vector2(%d, %d)' % (x, y))
            out.append('script = ExtResource("4_anim")')
            out.append('metadata/kind = "%s"' % kind)
            out.append('metadata/fall = %d' % fall)
            out.append('metadata/color = "%s"' % col)
            out.append('metadata/w = %d' % w)
            out.append('metadata/h = %d' % h)
            out.append('')
    open(path, 'w').write('\n'.join(out))
    return path
