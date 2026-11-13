"""THE PLAYERS' HEADS AND TORSOS, PLACED BY HAND (owner 2026-11-13: "still not liking the clothing designs on the torsos especially. And the faces are
looking low quality. Hair has no style seemingly. It just looks plain like Lego toy soldiers still").

A formula can pose a limb; it cannot give a face a look or a head of hair a style. So for the four players the head and the torso are drawn the
way the opening's cat and crows were — every pixel placed on a grid, at the drawn size — and the rig (tools/art/people.py) carries them: the head
rides the head joint, the torso hangs from the shoulder line, the arms and legs are still bones. Letters are tones:

    o the line      s t u  skin / its shadow / its light      h i j  hair / shadow / shine      e w b  eye: dark, white, the iris      m mouth
    c cheek         A B C  the main cloth / shadow / light    D E    a second cloth / shadow    G k    metal, dark detail            others per person
"""
INK = (26, 14, 34, 255)


def _pal(skin, hair, iris, cloth, extra=None):
    def tri(h, dk=0.72, lt=1.18, cool=True):
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        d = (int(r * dk * (0.94 if cool else 1.0)), int(g * dk * 0.9), min(255, int(b * dk * 1.08)))
        l = (min(255, int(r * lt + 8)), min(255, int(g * lt + 6)), min(255, int(b * lt)))
        return (r, g, b, 255), d + (255,), l + (255,)
    p = {'o': INK, 'e': (30, 18, 36, 255), 'w': (250, 248, 240, 255), 'm': (150, 52, 60, 255)}
    p['s'], p['t'], p['u'] = tri(skin, 0.80, 1.10)
    p['h'], p['i'], p['j'] = tri(hair, 0.66, 1.30)
    p['b'] = tri(iris)[0]
    p['c'] = tuple(int(a * 0.72 + b_ * 0.28) for a, b_ in zip(p['s'][:3], (240, 96, 110))) + (255,)
    p['A'], p['B'], p['C'] = tri(cloth[0])
    if len(cloth) > 1:
        p['D'], p['E'], _ = tri(cloth[1], 0.80)
    for k, v in (extra or {}).items():
        p[k] = tri(v)[0]
    return p


HEADS = {
    # Joe: a blond quiff brushed up and over at the front, short at the sides; blue eyes, a straight mouth
    'joe': dict(anchor=(10, 10), rows=[
        '..........ooooo......',
        '.......ooojjjjjoo....',
        '.....oojjjjjjjjhhoo..',
        '....ojjjjhhhhjjjjhho.',
        '...ojjhhhhhhhhhjjjho.',
        '..ojhhhhhhhhhhhhhjho.',
        '..ohhhhiihhhhhhhhho..',
        '.oihhiissssssshhho...',
        '.oihiisssssssssssho..',
        '.oiiissssssssssssso..',
        '.oiitssooosssoooso...',
        '.ootusswwesssswweso..',
        '..otusswbesssswbeso..',
        '..ottsssssssssssuso..',
        '...otsscsssssssscso..',
        '...otsssssmmmmssso...',
        '....ottsssssssssso...',
        '.....otttsssssoo.....',
        '......oootttoo.......',
        '.........ooo.........',
    ]),
    # Vivianne: golden hair swept across the brow, tied high with a pink band, the tail hanging behind; big blue eyes, a pink mouth
    'vivianne': dict(anchor=(15, 10), rows=[
        '.............ooooo........',
        '..........ooojjjjjoo......',
        '...oo....ojjjjhhhhjjoo....',
        '..ojjo..ojjjhhhhhhhjjho...',
        '.ojjhhoPPhhhhhhhjjjjhhho..',
        '.ojhhhoPPhhhhjjjjjhhhhho..',
        '.ojhhhioohhjjjhhssshhhho..',
        '.oihhhio.ohhhhsssssshhho..',
        '.oihhhio.oihhsssssssssho..',
        '..oihhio.oihssssssssssso..',
        '..oihhio.oihssooossooosso.',
        '..oiihio..oisswweswwesso..',
        '...oihio..oitswbeswbessuo.',
        '...oiio...ootswbeswbesso..',
        '....oo.....otccssssscso...',
        '...........otssssmmssso...',
        '............otsssssssso...',
        '.............ottssssoo....',
        '..............oottoo......',
        '................oo........',
    ]),
    # Alex: hair cropped close with a clean line across the brow, an open face, a smile that shows his teeth
    'alex': dict(anchor=(10, 10), rows=[
        '.......ooooooo.......',
        '.....oohhhhhhhoo.....',
        '....ohhhjjhhhhhho....',
        '...ohhhhhhhhhhhhho...',
        '..oihhhhhhhhhhhhhho..',
        '..oihhhhhhhhhhhhhho..',
        '..oiihsssssssssshho..',
        '.oiissssssssssssso...',
        '.oitsssssssssssssso..',
        '.oitssoooossoooosso..',
        '.ootusswwesssswweso..',
        '..otusswbesssswbeso..',
        '..otsssssssssssuuso..',
        '..ottsssssssssssso...',
        '...otssmwwwwmssso....',
        '...ottssmmmmsssso....',
        '....ottsssssssoo.....',
        '.....oottttsoo.......',
        '.......ooooo.........',
    ]),
    # Amina: black hair parted in the middle and worn long, past the jaw on the near side; a red dot at the brow, a gold earring
    'amina': dict(anchor=(10, 10), rows=[
        '.......oooooooo.......',
        '.....oohhhhhhhhoo.....',
        '....ohhhjjhhhhhhho....',
        '...ohhhjjhhhhhhhhho...',
        '..ohhhhhhhhhsshhhhho..',
        '..ohhhhhhhssssshhhho..',
        '.oihhhhhsssssssshhho..',
        '.oihhhhssssssrssshho..',
        '.oihhhsssssssssssho...',
        '.oihhhssooosssoooho...',
        '.oihhisswwessswweso...',
        '.oihhitswbessswbesuo..',
        '.oihhitsssssssssso....',
        '.oihhgtccsssssscso....',
        '.oihhiotsssmmmsso.....',
        '.oihhi.otsssssso......',
        '.oihhi..ottsssoo......',
        '.oihho...oottoo.......',
        '..oiho.....oo.........',
        '..oio.................',
    ]),
}

TORSOS = {
    # Joe: a red checked shirt hanging open over a white tee
    'joe': [
        '.....oooooooo.....',
        '...ooBACDDDDCAoo..',
        '..oBAAACDDDDCAAAo.',
        '.oBAAkACEDDDCAkAAo',
        '.oBkkkkCEDDDCkkkko',
        '.oBAAkACEDDDCAkAAo',
        '.oBAAkACEDDDCAkAAo',
        '.oBAAkACEDDDCAkAAo',
        '.oBkkkkCEDDDCkkkko',
        '.oBAAkACEDDDCAkAo.',
        '.oBAAkACEDDDCAkAo.',
        '..oBAkACEDDDCAkAo.',
        '..oBkkkCEDDDCkkko.',
        '..oBAkACEDDDCAkAo.',
        '..oBAkACEDDDCAkAo.',
        '..oBAkACEDDDCAkAo.',
        '..oBkkkCEDDDCkkko.',
        '..oBAkACEDDDCAkAo.',
        '..oBAkACEDDDCAkAo.',
        '..oBAkACEEEECAkAo.',
        '..oBkkkCoooooCkko.',
        '..oBBAAo.....oAAo.',
        '...oooo.......oo..',
    ],
    # Vivianne: a coral track top, white across the shoulders, zipped to the neck, nipped at the waist, a dark band at the hem
    'vivianne': [
        '....oooooooo....',
        '..ooDDDDDDDDoo..',
        '.oEDDDDDDkDDDDo.',
        '.oEDDDDDDkDDDDDo',
        '.oBAAAAAAkAAACCo',
        '.oBAAAAAAkAAACCo',
        '.oBAAAAAAkAAACCo',
        '.oBAAAAAAkAAACo.',
        '..oBAAAAAkAACCo.',
        '..oBAAAAAkAACo..',
        '..oBAAAAAkAACo..',
        '...oBAAAAkAAo...',
        '...oBAAAAkAAo...',
        '...oBAAAAkAACo..',
        '..oBAAAAAkAACo..',
        '..oBAAAAAkAAACo.',
        '..oBAAAAAkAAACo.',
        '..oBAAAAAkAAACo.',
        '..oBBAAAAkAAACo.',
        '..oHHHHHHHHHHHo.',
        '..oHHHHHHHHHHHo.',
        '...ooooooooooo..',
    ],
    # Alex: navy dungarees over a pale tee — straps, brass buckles, a name patch on the bib, a leather tool belt with a pouch at the hip
    'alex': [
        '.....oooooooo.....',
        '...ooDDAADDAADoo..',
        '..oEDDDAADDAADDDo.',
        '.oEDDDDAADDAADDDDo',
        '.oEDDDDGADDAGDDDDo',
        '.oEDDBAAAAAAAACDDo',
        '.oEDDBAAAAAAAACDDo',
        '.oEDDBAAPPPAAACDDo',
        '.oEDDBAAPPPAAACDo.',
        '.oEDDBAAAAAAAACDo.',
        '..oEDBAAAAAAAACDo.',
        '..oBBBAAAAAAAACCo.',
        '..oBAAAAAAAAAAACo.',
        '..oBAAAAAAAAAAACo.',
        '..oBAAAAAAkAAAACo.',
        '..oLLLLLLLGGLLLLo.',
        '..oLLLLLLLGGLLLLo.',
        '..oMMMBAAAkAAAACo.',
        '..oMMMBAAAkAAAACo.',
        '..oMMMBAAAkAAAACo.',
        '..ooooBAAAkAAAACo.',
        '.....ooooooooooo..',
    ],
    # Amina: a mustard cardigan with dark buttons, open over a magenta top with a scooped neck; a gold pendant
    'amina': [
        '....oooooooo....',
        '..ooACssssCAoo..',
        '.oBAACDssDCAAAo.',
        '.oBAACDDGDCAAAAo',
        '.oBAACDDDDCAAAAo',
        '.oBAACEDDDCAkAAo',
        '.oBAACEDDDCAAAAo',
        '.oBAACEDDDCAAAo.',
        '..oBACEDDDCAkAo.',
        '..oBACEDDDCAAo..',
        '..oBACEDDDCAAo..',
        '...oBCEDDDCAo...',
        '...oBCEDDDCkAo..',
        '..oBACEDDDCAAo..',
        '..oBACEDDDCAAAo.',
        '..oBACEDDDCAkAo.',
        '..oBACEDDDCAAAo.',
        '..oBACEEEECAAAo.',
        '..oBAACooooAAAo.',
        '..oBBBBo..oBBBo.',
        '...oooo....ooo..',
    ],
}

PALETTES = {
    'joe': _pal('f0d0b4', 'e8c050', '4a8ad8', ('c8443a', 'f0ece2'), {'k': '6a1c1e', 'G': 'f0ece2'}),
    'vivianne': _pal('f6dcc8', 'f2c64e', '3a9ae0', ('f0685a', 'f6f2ea'), {'k': 'c8c4bc', 'H': '2a2a36', 'P': 'f0509a'}),
    'alex': _pal('7a4e34', '1c1418', '3a2416', ('2c4c86', 'cfd4dc'), {'G': 'f0c84a', 'P': 'f6f2ea', 'L': '7a4a26', 'M': 'e0a83a', 'k': '18305a'}),
    'amina': _pal('c08a5e', '1e141a', '4a2e1c', ('e0a82e', 'd0346e'), {'G': 'ffd84a', 'k': '6a4a12', 'r': 'd0282e', 'g': 'ffd84a'}),
}
PALETTES['amina']['m'] = (168, 60, 70, 255)
PALETTES['vivianne']['m'] = (224, 84, 110, 255)


def paste(cel, rows, palette, x0, y0, blink=False):
    """Lay a grid onto the drawn image with its top-left at (x0, y0). `blink` shuts the eyes: the upper eye rows go to skin, the lowest to a lash line."""
    w = max(len(r) for r in rows)
    eye_rows = [i for i, r in enumerate(rows) if any(ch in r for ch in 'wb')]
    for y, row in enumerate(rows):
        row = row.ljust(w, '.')
        for x, ch in enumerate(row):
            if ch == '.':
                continue
            if blink and y in eye_rows and ch in 'wbe':
                ch = 'e' if y == eye_rows[-1] else 's'
            cel.raw(x0 + x, y0 + y, palette[ch])
