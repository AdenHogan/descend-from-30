#!/usr/bin/env python3
"""Compose the art-reference sheets from the frames dumped by gen_sprite_lineup.gd.

Pipeline (dev tool, NOT part of the game):
  1. godot --headless --script res://tools/gen_sprite_lineup.gd   # dumps frames + manifest
  2. python3 tools/compose_sprite_lineup.py                       # lays them out

Needs Pillow (pip install pillow). Output: docs/art_reference/enemy_lineup.png +
player_poses.png — the placeholder rigs at true in-game scale, feet aligned, for
comparison / the artist brief. Re-run whenever the rigs change.
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "docs/art_reference/frames/")
OUT = os.path.join(ROOT, "docs/art_reference/")

BG = (26, 22, 32, 255)        # cool dark, cozy-horror
FLOOR = (60, 52, 66, 255)     # faint baseline
INK = (222, 216, 228, 255)
SUB = (150, 142, 160, 255)
GAP, PAD, LABEL_H, TITLE_H = 46, 40, 34, 54
VIEW = 2                      # on-screen magnification (ratios stay true; real scale in label)

def font(bold, size):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/" + name, size)

f_title, f_label, f_sub = font(True, 26), font(True, 17), font(False, 13)

def load_scaled(entry):
    im = Image.open(D + entry["file"]).convert("RGBA")
    s = float(entry["scale"]) * VIEW
    return im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)

def sheet(entries, title, subtitle, outname, extra=None):
    imgs = [(e["label"], load_scaled(e), e) for e in entries]
    if extra:
        imgs.append(extra)
    maxh = max(im.height for _, im, _ in imgs)
    colw = [max(im.width, f_label.getbbox(lbl)[2]) for lbl, im, _ in imgs]
    W = PAD * 2 + sum(colw) + GAP * (len(imgs) - 1)
    W = max(W, PAD * 2 + f_title.getbbox(title)[2], PAD * 2 + f_sub.getbbox(subtitle)[2])
    baseline = TITLE_H + PAD + maxh
    H = baseline + LABEL_H + PAD // 2
    canvas = Image.new("RGBA", (W, H), BG)
    dr = ImageDraw.Draw(canvas)
    dr.text((PAD, 16), title, font=f_title, fill=INK)
    dr.text((PAD, 46), subtitle, font=f_sub, fill=SUB)
    dr.line([(PAD - 10, baseline + 1), (W - PAD + 10, baseline + 1)], fill=FLOOR, width=2)
    x = PAD
    for i, (lbl, im, e) in enumerate(imgs):
        cx = x + colw[i] // 2
        canvas.alpha_composite(im, (cx - im.width // 2, baseline - im.height))
        lb = f_label.getbbox(lbl)
        dr.text((cx - lb[2] // 2, baseline + 8), lbl, font=f_label, fill=INK)
        if e:
            sc = f"x{e['scale']:g}"
            dr.text((cx - f_sub.getbbox(sc)[2] // 2, baseline + 26), sc, font=f_sub, fill=SUB)
        x += colw[i] + GAP
    canvas.save(OUT + outname)
    print("wrote", OUT + outname, canvas.size)

def main():
    man = json.load(open(D + "manifest.json"))
    pref = load_scaled(man["player"][0])
    sheet(man["enemies"],
          "Descend From 30 — Enemy line-up (placeholder rigs)",
          "True in-game scale, feet aligned to the floor line. Player shown for scale.",
          "enemy_lineup.png",
          extra=("Player (ref)", pref, {"scale": 2.0}))
    sheet(man["player"],
          "Descend From 30 — Player (placeholder rig)",
          "Gun idle · sword idle · crouch · push. True in-game scale, feet aligned.",
          "player_poses.png")

if __name__ == "__main__":
    main()
