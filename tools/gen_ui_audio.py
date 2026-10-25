#!/usr/bin/env python3
"""Sounds for the paper menus (owner round 48j: the merchant / workbench / loot screens become the LEDGER — "the appropriate amount of UX design… lighting, sound effects… good, clean,
connected, and strong… we don't want it to look like AI slop").

Every one is a thing that really happens on a desk, made the way that thing sounds — nothing synthesised to "sound like a UI": pink noise under a steep ceiling (never white: the top octave
is where hiss lives — docs/AUDIO.md), a few damped resonances, soft attacks. scripts/ledger.gd plays them. Mono 22050 Hz 16-bit WAV, deterministic, CC0.

  sheet_N   — a sheet of paper laid down on a wooden desk: a breath of air under it, then the soft flat settle           (a menu opening)
  page_N    — a page flicked over                                                                                          (a tab changing)
  tick_N    — the tip of a pencil tapped on the page                                                                       (a choice under the pointer)
  stamp_N   — a rubber stamp pressed down on a pad then on paper: a low thud, the pad's wet slap, ink squeezing out        (a thing taken / sold)
  pen_N     — a pen writing a short word: a few scratchy strokes                                                           (an entry being written)
  tape_0    — a strip of sticky tape pulled off the roll                                                                   (a slip being lifted / a card dismissed)
  notes_N   — banknotes counted off with a thumb                                                                           (notes paid)
  deny_0    — two knuckle raps on the desk                                                                                 (no — can't afford / won't fit)

Run:  python3 tools/gen_ui_audio.py   (needs numpy)   ->  assets/audio/ui/
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "ui")

CEILING = {"sheet": 3600, "page": 4200, "tick": 3400, "stamp": 3600, "pen": 4600, "tape": 4200, "notes": 4600, "deny": 2400}
PEAK = {"sheet": 0.42, "page": 0.36, "tick": 0.28, "stamp": 0.5, "pen": 0.30, "tape": 0.34, "notes": 0.34, "deny": 0.46}


def _write(name, x):
    os.makedirs(OUT, exist_ok=True)
    key = name.rsplit("_", 1)[0]
    audiolib.write_wav(os.path.join(OUT, name + ".wav"), audiolib.polish(x, SR, hi=CEILING.get(key, 4000), peak=PEAK.get(key, 0.4)), SR)


def _t(n):
    return np.arange(n) / float(SR)


def _noise(r, n, lo, hi):
    """Pink noise band-limited to lo..hi Hz."""
    return audiolib.bp(audiolib.pink(n, r), SR, lo, hi)


def _env(n, attack_ms, decay_ms):
    t = _t(n) * 1000.0
    a = np.clip(t / max(attack_ms, 0.1), 0.0, 1.0)
    return a * np.exp(-t / max(decay_ms, 0.1))


def _place(buf, x, at_s):
    i = int(at_s * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i]


def sheet(k):
    r = np.random.default_rng(100 + k)
    n = int(0.46 * SR)
    out = np.zeros(n)
    air_n = int(0.20 * SR)
    swell = np.sin(np.linspace(0, np.pi, air_n)) ** 2
    _place(out, _noise(r, air_n, 350, 2600) * swell * 0.55, 0.0)                         # the air pushed out from under the sheet
    tap_n = int(0.13 * SR)
    tap = audiolib.lp(audiolib.pink(tap_n, r), SR, 900) * _env(tap_n, 2.0, 26.0)       # the flat settle on the wood
    tap += np.sin(2 * np.pi * (150.0 - 40.0 * k) * _t(tap_n)) * _env(tap_n, 1.0, 30.0) * 0.5
    _place(out, tap * 1.1, 0.17)
    return out


def page(k):
    r = np.random.default_rng(200 + k)
    n = int(0.26 * SR)
    t = np.linspace(0, 1, n)
    flick = _noise(r, n, 1200, 4200) * (np.sin(np.pi * t) ** 1.5)
    crackle = np.zeros(n)
    for _ in range(9):
        i = int(r.uniform(0.08, 0.9) * n)
        m = int(0.004 * SR)
        crackle[i:i + m] += audiolib.pink(m, r) * np.hanning(m) * r.uniform(0.3, 0.8)
    return flick * 0.6 + crackle


def tick(k):
    r = np.random.default_rng(300 + k)
    n = int(0.06 * SR)
    f = (780.0, 910.0, 690.0)[k % 3]
    wood = np.sin(2 * np.pi * f * _t(n)) * _env(n, 0.4, 7.0)                            # the page over the desk gives the tip a hollow note
    tip = audiolib.lp(audiolib.pink(n, r), SR, 3200) * _env(n, 0.3, 4.0)
    return wood * 0.5 + tip * 0.9


def stamp(k):
    r = np.random.default_rng(400 + k)
    n = int(0.55 * SR)
    out = np.zeros(n)
    m = int(0.28 * SR)
    f = np.linspace(105.0 - 12 * k, 52.0, m)                                              # the handle's thud: a body dropping in pitch
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * _env(m, 1.2, 70.0)
    _place(out, thud * 1.0, 0.0)
    pad_n = int(0.05 * SR)
    pad = audiolib.lp(audiolib.pink(pad_n, r), SR, 1500) * _env(pad_n, 0.6, 9.0)         # the pad's wet slap
    _place(out, pad * 0.9, 0.004)
    sq_n = int(0.16 * SR)
    sq = _noise(r, sq_n, 700, 2600) * _env(sq_n, 6.0, 55.0)                               # ink squeezing out round the edges
    _place(out, sq * 0.22, 0.012)
    return out


def pen(k):
    r = np.random.default_rng(500 + k)
    n = int((0.62 + 0.1 * k) * SR)
    out = np.zeros(n)
    t = 0.04
    for s in range(4 + k):                                                                 # a few short strokes, each gated and a little different
        ln = r.uniform(0.07, 0.13)
        m = int(ln * SR)
        x = _noise(r, m, 1500, 4600)
        wob = 0.65 + 0.35 * np.sin(2 * np.pi * r.uniform(7, 15) * _t(m) + r.uniform(0, 6))
        x = x * wob * (np.sin(np.linspace(0, np.pi, m)) ** 0.8) * r.uniform(0.5, 1.0)
        _place(out, x, t)
        t += ln + r.uniform(0.02, 0.07)
        if t > n / SR - 0.1:
            break
    return out


def tape():
    r = np.random.default_rng(600)
    n = int(0.50 * SR)
    t = _t(n)
    stick = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (58.0 + 30.0 * t / t[-1]) * t))        # stick-slip: the adhesive letting go in a chatter that quickens
    x = _noise(r, n, 900, 4200) * stick * (np.sin(np.pi * np.linspace(0, 1, n)) ** 0.7)
    return x


def notes(k):
    r = np.random.default_rng(700 + k)
    n = int(0.78 * SR)
    out = np.zeros(n)
    t = 0.02
    gap = 0.075
    for _ in range(10 + 3 * k):                                                            # a thumb flicking the notes one off the next, a little faster each time
        m = int(0.02 * SR)
        x = _noise(r, m, 2200, 4600) * _env(m, 0.5, 6.0) * r.uniform(0.6, 1.0)
        _place(out, x, t)
        t += gap
        gap = max(0.038, gap * 0.93)
        if t > n / SR - 0.06:
            break
    return out


def deny():
    r = np.random.default_rng(800)
    n = int(0.42 * SR)
    out = np.zeros(n)
    for at, f in ((0.0, 190.0), (0.17, 175.0)):                                            # two knocks on a wooden desk, the second a little duller
        m = int(0.14 * SR)
        body = np.sin(2 * np.pi * f * _t(m)) * _env(m, 0.8, 38.0)
        click = audiolib.lp(audiolib.pink(m, r), SR, 800) * _env(m, 0.4, 9.0)
        _place(out, body * 0.9 + click * 0.8, at)
    return out


def main():
    for k in range(2):
        _write("sheet_%d" % k, sheet(k))
        _write("page_%d" % k, page(k))
        _write("pen_%d" % k, pen(k))
        _write("notes_%d" % k, notes(k))
        _write("stamp_%d" % k, stamp(k))
    for k in range(3):
        _write("tick_%d" % k, tick(k))
    _write("tape_0", tape())
    _write("deny_0", deny())
    print("wrote %d sounds to %s" % (len(os.listdir(OUT)), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
