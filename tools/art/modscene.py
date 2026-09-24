"""Writes a room-module scene (scenes/Room_Modules/<name>.tscn) from an art script's own spec, so a
module's furniture and its scavenge nodes are defined in ONE place (the tools/art/<name>.py script).

Scene shape (what scripts/room.gd expects):
  Node2D
    ColorRect (placeholder colour) / Label (HIDDEN — room.gd reads its text for the room type)
    Art        Sprite2D  res://assets/rooms/<name>.png
    StripArt   Sprite2D  res://assets/rooms/<name>_strip.png   (balcony-capable rooms, optional:
               the furniture standing where the balcony doors go; room.gd hides it on a balcony slot)
    Balcony    Node2D    (balcony-capable rooms — the placeholder balcony art, drawn OVER the art)
    anchor_*   Marker2D  metadata/back_plane (set back on furniture), metadata/balcony_strip (in the
               balcony strip — room.gd removes it on a balcony slot)

An existing scene's uid is kept so nothing that references it breaks.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LABELS = {'bedroom': 'Bedroom', 'bathroom': 'Bathroom', 'kitchen': 'Kitchen', 'study': 'Study',
          'living_room': 'Living Room', 'dining_room': 'Dining Room'}
BALCONY_TYPES = ('study', 'dining_room')


def write_scene(name, room_type, anchors, strip=False):
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
        out.append(open(os.path.join(HERE, 'balcony_block.tscn.txt')).read().rstrip())
        out.append('')
    for (n, x, y, flags) in anchors:
        out.append('[node name="%s" type="Marker2D" parent="."]' % n)
        out.append('position = Vector2(%d, %d)' % (x, y))
        if 'bp' in flags:
            out.append('metadata/back_plane = true')
        if 's' in flags.replace('bp', ''):
            out.append('metadata/balcony_strip = true')
        out.append('')
    open(path, 'w').write('\n'.join(out))
    return path
