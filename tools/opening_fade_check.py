#!/usr/bin/env python3
"""The opening's title must FADE IN CLEAN (owner round 48n: "it seems to flash black first before the text appears properly").

A headless test cannot see a render, so this renders it: for each run it captures the opening at three moments while the lettering is fading in, twice —
once with the title and once with the title hidden (`tools/opening_capture.tscn --hidetitle=1`, the same timeline) — rebuilds what a PURE cream fade-in
would look like at screen size (the lettering layer, box-filtered like the GPU's mipmaps, at the fade's alpha, over the plain frame), and compares the real
frame inside the lettering that is solid at screen size.  A negative deviation is something DARK laid under the cream (the first build's shadow made the
words read black while they faded: -98 luminance on the morning run).

    python3 tools/opening_fade_check.py            # runs 1 2 3 (needs xvfb-run + godot; ~2 min); exit 1 on a failure
    python3 tools/opening_fade_check.py --runs=1 --keep=/tmp/fadeframes

Not in tools/run_all_tests.sh (it needs a display).  Fails when the mean deviation is below -4 or more than 10 % of the solid letter pixels are more than 8 darker.
"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
LAYER = os.path.join(ROOT, 'assets', 'logo', 'logo_layer_text_dark.png')
TIMES = (11.9, 12.2, 12.5)                    # the lettering is ~24 %, ~63 %, ~95 % up
SCALE, CX, CY = 0.25, 576.0, 195.0            # opening_exterior.LOGO_SCALE / LOGO_CENTRE
TEXT_RISE = 10.0
MEAN_FLOOR, DARK_SHARE_MAX = -4.0, 10.0


def read_const(name):
    src = open(os.path.join(ROOT, 'scripts', 'opening_exterior.gd')).read()
    for line in src.splitlines():
        if line.startswith('const %s ' % name):
            return float(line.split(':=')[1].split('#')[0].strip())
    raise SystemExit('no const %s in opening_exterior.gd' % name)


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def capture(out, run, hide):
    cmd = ['xvfb-run', '-a', '-s', '-screen 0 1152x648x24', 'godot', '--rendering-driver', 'opengl3', 'res://tools/opening_capture.tscn', '--',
           '--out=%s' % out, '--run=%d' % run, '--seed=5', '--times=%s' % ','.join(str(t) for t in TIMES)] + (['--hidetitle=1'] if hide else [])
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out_text = r.stdout + r.stderr
    if 'SCRIPT ERROR' in out_text or 'Parse Error' in out_text:
        raise SystemExit(out_text)


def main():
    runs = [1, 2, 3]
    keep = None
    for a in sys.argv[1:]:
        if a.startswith('--runs='):
            runs = [int(x) for x in a[7:].split(',')]
        elif a.startswith('--keep='):
            keep = a[7:]
    t_in = read_const('T_FADE_IN') + read_const('T_STILL') + read_const('T_PAN') * read_const('T_TITLE_AT')
    t_text = read_const('T_TEXT_FADE')
    im = Image.open(LAYER).convert('RGBA')
    a = np.asarray(im).astype(float)
    pre = a.copy()
    pre[..., :3] *= a[..., 3:4] / 255.0
    w, h = int(im.width * SCALE), int(im.height * SCALE)
    small = np.stack([np.asarray(Image.fromarray(pre[..., c].astype(np.float32), 'F').resize((w, h), Image.BOX)) for c in range(4)], axis=-1)
    alpha = small[..., 3] / 255.0
    rgb_pre = small[..., :3]
    ys0, xs0 = np.nonzero(alpha > 0.97)
    bad = 0
    work = keep or tempfile.mkdtemp(prefix='opening_fade_')
    for run in runs:
        d_with, d_without = os.path.join(work, 'with_%d' % run), os.path.join(work, 'without_%d' % run)
        capture(d_with, run, False)
        capture(d_without, run, True)
        for t in TIMES:
            A = np.asarray(Image.open('%s/open_%d_%05.1f.png' % (d_with, run, t)).convert('RGB')).astype(float)
            B = np.asarray(Image.open('%s/open_%d_%05.1f.png' % (d_without, run, t)).convert('RGB')).astype(float)
            wa = ease((t - t_in) / t_text)
            x0, y0 = int(round(CX - w / 2)), int(round(CY + TEXT_RISE * (1 - wa) - h / 2))
            sx, sy = xs0 + x0, ys0 + y0
            ok = (sx >= 0) & (sx < 1152) & (sy >= 0) & (sy < 648)
            ys, xs, sx, sy = ys0[ok], xs0[ok], sx[ok], sy[ok]
            expect = B[sy, sx] * (1 - wa * alpha[ys, xs][:, None]) + wa * rgb_pre[ys, xs]
            lum = lambda c: 0.2126 * c[:, 0] + 0.7152 * c[:, 1] + 0.0722 * c[:, 2]
            dev = lum(A[sy, sx]) - lum(expect)
            mean, dark = float(dev.mean()), float((dev < -8).mean() * 100)
            ok_row = mean >= MEAN_FLOOR and dark <= DARK_SHARE_MAX
            bad += 0 if ok_row else 1
            print('%s run %d t=%4.1f (lettering %3.0f%% up): deviation from a pure cream fade-in mean %+6.1f, %4.1f%% of solid letter px > 8 darker' % ('ok  ' if ok_row else 'FAIL', run, t, wa * 100, mean, dark))
    print('opening fade: %s' % ('CLEAN' if bad == 0 else '%d moment(s) show something dark under the fading letters' % bad))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
