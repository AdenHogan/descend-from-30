#!/usr/bin/env python3
"""Sounds for searching a node (owner round 45c: "the movement animations should happen when the player presses interact to begin the
scavenge… search a table and a glass falls over, search the oven and the door opens… these details make the world more alive").
scripts/node_reaction.gd plays one of these, quietly and positionally, the moment a search BEGINS. Procedurally made here — CC0.
Mono 22050 Hz 16-bit WAV, a few variants of each, deterministic.

  rustle_N  — cloth: a clothes pile, a bed, a cushion, a bag turned over (bands of soft filtered noise, a few swells)
  paper_N   — paper: books, files, maps, boxes (a crinkle of tiny clicks)
  clink_N   — ceramic / glass: cups, tea things, bottles, a basin (two or three short rings)
  tin_N     — metal: tins, a bucket, a trolley, a tool chest (a rattle of damped ringing noise)
  scrape_N  — a drawer pulled out on its runners (a low rubbing sweep and a soft stop)
  switch_0  — a screen going off (a relay click and a fading whine)
  fall_N    — something tipping over and rolling a little (a knock, then a rolling rattle that slows)

Run:  python3 tools/gen_node_audio.py   (needs numpy)   ->  assets/audio/room/
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "room")


def _write(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())


def _lp(x, k):
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p += k * (v - p)
        y[i] = p
    return y


def _hp(x, k=0.95):
    y = np.zeros_like(x)
    px = py = 0.0
    for i, v in enumerate(x):
        py = k * (py + v - px)
        px = v
        y[i] = py
    return y


def _norm(x, peak=0.7):
    m = float(np.abs(x).max())
    return x * (peak / m) if m > 1e-9 else x


def _fade(x, ms=18):
    n = int(SR * ms / 1000.0)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def rustle(seed):
    r = np.random.default_rng(seed)
    n = int(SR * r.uniform(0.42, 0.6))
    t = np.arange(n) / SR
    noise = _hp(_lp(r.normal(0, 1, n), 0.55), 0.9)
    env = np.zeros(n)
    for _ in range(int(r.integers(3, 6))):
        c = r.uniform(0.04, t[-1] - 0.06)
        w = r.uniform(0.03, 0.09)
        env += r.uniform(0.4, 1.0) * np.exp(-((t - c) / w) ** 2)
    return _fade(_norm(noise * env, 0.6))


def paper(seed):
    r = np.random.default_rng(seed + 50)
    n = int(SR * r.uniform(0.4, 0.55))
    t = np.arange(n) / SR
    x = np.zeros(n)
    for _ in range(int(r.integers(26, 44))):
        i = int(r.beta(1.4, 2.2) * (n - 80))
        L = int(r.integers(8, 40))
        x[i:i + L] += r.normal(0, 1, L) * np.exp(-np.arange(L) / (L * 0.3)) * r.uniform(0.2, 1.0)
    x = _hp(x, 0.9)
    return _fade(_norm(x * np.exp(-t / 0.3), 0.6))


def clink(seed):
    r = np.random.default_rng(seed + 90)
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(int(r.integers(2, 4))):
        on = int((0.0 if k == 0 else r.uniform(0.03, 0.2)) * SR)
        f = float(r.uniform(1800, 5200))
        d = float(r.uniform(0.04, 0.12))
        tt = t[: n - on]
        x[on:] += (0.8 - 0.2 * k) * (np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * f * 2.76 * tt)) * np.exp(-tt / d)
    return _fade(_norm(x, 0.6), 6)


def tin(seed):
    r = np.random.default_rng(seed + 130)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(int(r.integers(2, 5))):
        on = int(r.uniform(0.0, 0.3) * SR)
        f = float(r.uniform(500, 2400))
        d = float(r.uniform(0.05, 0.14))
        L = n - on
        burst = r.normal(0, 1, L)
        x[on:] += burst * np.exp(-t[:L] / 0.01) * 0.6 + np.sin(2 * np.pi * f * t[:L]) * np.exp(-t[:L] / d) * 0.7
    return _fade(_norm(x, 0.6), 6)


def scrape(seed):
    r = np.random.default_rng(seed + 170)
    n = int(SR * 0.42)
    t = np.arange(n) / SR
    noise = _lp(r.normal(0, 1, n), 0.12)
    sweep = np.clip(t / 0.28, 0, 1) ** 0.7
    env = sweep * np.where(t < 0.3, 1.0, np.exp(-(t - 0.3) / 0.03))
    rub = noise * env * (0.65 + 0.35 * np.sin(2 * np.pi * (7 + 5 * r.random()) * t))
    thud_t = np.clip(t - 0.3, 0, None)
    thud = np.sin(2 * np.pi * 85 * thud_t) * np.exp(-thud_t / 0.035) * (t >= 0.3) * 0.7
    return _fade(_norm(rub + thud, 0.6), 8)


def switch_off(_seed):
    n = int(SR * 0.5)
    t = np.arange(n) / SR
    click = np.zeros(n)
    click[:6] = [1, -0.9, 0.6, -0.4, 0.2, -0.1]
    ring = np.sin(2 * np.pi * 1800 * t) * np.exp(-t / 0.006) * 0.4
    f = 2600 * np.exp(-t / 0.09) + 300
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.11) * 0.28
    return _fade(_norm(click + ring + whine, 0.6), 4)


def fall(seed):
    r = np.random.default_rng(seed + 210)
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    knock = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03) * 0.8 + _lp(r.normal(0, 1, n), 0.4) * np.exp(-t / 0.012) * 0.5
    roll = np.zeros(n)
    for k in range(int(r.integers(5, 8))):
        on = 0.06 + 0.08 * k ** 1.25
        i = int(on * SR)
        if i >= n - 200:
            break
        L = int(SR * 0.05)
        ping = np.sin(2 * np.pi * r.uniform(900, 2200) * np.arange(L) / SR) * np.exp(-np.arange(L) / (L * 0.3))
        roll[i:i + L] += ping * (0.5 - 0.05 * k)
    return _fade(_norm(knock + roll, 0.6), 6)


def main():
    for k in range(3):
        _write("rustle_%d.wav" % k, rustle(k))
        _write("paper_%d.wav" % k, paper(k))
        _write("clink_%d.wav" % k, clink(k))
        _write("tin_%d.wav" % k, tin(k))
        _write("fall_%d.wav" % k, fall(k))
    for k in range(2):
        _write("scrape_%d.wav" % k, scrape(k))
    _write("switch_0.wav", switch_off(0))
    print("wrote", len(os.listdir(OUT)), "files to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
