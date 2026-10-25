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

  — and the SPECIAL sounds a few kinds of node make (scripts/node_reaction.gd `SPECIAL`, keyed on the anchor's name):
  tap_N     — a tap squeaks open and water runs (sinks, basins, taps, tubs, showers)
  cistern_0 — a ceramic lid scraped off and the cistern trickling (toilets)
  piano_N   — a hand falls on the keys (a few uneven notes)
  clock_0   — a tick, a tock, a soft chime
  static_0  — a radio / handset: a burst of tuning static
  beep_0    — a microwave, three beeps
  spring_N  — bed / sofa springs creaking
  squeak_N  — a toy or a rubber thing squeaking
  roll_N    — small wheels rattling (a trolley, a wheelchair)
  fridge_0  — a seal letting go and the motor catching
  printer_0 — a whir and a paper feed
  needle_0  — a stylus dragged across a record
  pffft_0   — a beanbag letting out its air
  unroll_0  — a toilet roll spun by a pull: the axle ticking as it slows, the sheet rasping off, a tear (round 48k: the searched roll unrolls)

Run:  python3 tools/gen_node_audio.py   (needs numpy)   ->  assets/audio/room/
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402  (shared clean-audio DSP: pink noise, steep ceilings, soft limiting — round 46)

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "room")

# How far up each sound may reach (Hz). Round 46: the noise-built ones used to run to the top of the spectrum (40-50 % of their energy above
# 6 kHz = "static"); they are now pink noise under a steep ceiling picked for what the thing is. Anything not listed gets 7 kHz.
CEILING = {"rustle": 4200, "paper": 3800, "tin": 6500, "scrape": 3200, "tap": 4600, "cistern": 4800, "static": 3400, "roll": 3200,
           "fridge": 4200, "printer": 4200, "needle": 4600, "pffft": 2800, "spring": 4000, "fall": 6000, "unroll": 3800}


def _write(name, x):
    os.makedirs(OUT, exist_ok=True)
    hi = CEILING.get(name.rsplit("_", 1)[0], 7000)
    audiolib.write_wav(os.path.join(OUT, name), audiolib.polish(x, SR, hi=hi, peak=0.5), SR)


def _pn(r, n):
    """Pink noise of n samples from rng `r` (never white: the top octave is where static lives)."""
    return audiolib.pink(n, r)


def _wob(r, n, fc):
    """A slow random wobble in [-1, 1] (noise low-passed at `fc` Hz) — how running water's level moves; a sine reads as a motor."""
    x = audiolib.lp(r.normal(0, 1, n), SR, fc, order=2)
    return x / max(1e-9, float(np.abs(x).max()))


def _lp(x, k):
    """Low-pass; `k` is the old one-pole coefficient (kept so the call sites read as before), mapped to the equivalent cutoff, now 12 dB/oct."""
    fc = -np.log(1.0 - min(max(k, 1e-4), 0.99)) * SR / (2.0 * np.pi)
    return audiolib.lp(x, SR, fc, order=2)


def _hp(x, k=0.95):
    fc = -np.log(min(max(k, 0.01), 0.9999)) * SR / (2.0 * np.pi)
    return audiolib.hp(x, SR, fc, order=2)


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
    noise = _hp(_lp(_pn(r, n), 0.55), 0.9)
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
    crisp = _lp(x, 0.3)                                                   # the crinkle's edge, rolled off (~2.5 kHz)
    swell = audiolib.lp(np.abs(x), SR, 60, order=2)                       # where the crinkling is happening ...
    body = _bp(_pn(r, n), 220, 1800) * swell / max(1e-9, float(swell.max())) * 0.5     # ... carries a soft pink body, so it is a rustle, not a tick-train
    x = crisp / max(1e-9, float(np.abs(crisp).max())) + body
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
    noise = _lp(_pn(r, n), 0.12)
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
    knock = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03) * 0.8 + _lp(_pn(r, n), 0.4) * np.exp(-t / 0.012) * 0.5
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


def _env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / d)


def _bp(x, lo, hi):
    return audiolib.bp(x, SR, lo, hi, order=2)


def tap(seed):
    r = np.random.default_rng(seed + 300)
    n = int(SR * 0.75)
    t = np.arange(n) / SR
    sq = np.sin(2 * np.pi * np.cumsum(900 + 700 * np.clip(t / 0.05, 0, 1)) / SR) * np.exp(-t / 0.03) * 0.5     # the handle squeaks
    flow = _bp(_pn(r, n), 450, 3800) * (0.7 + 0.3 * _wob(r, n, 20)) * np.clip((t - 0.04) / 0.12, 0, 1)
    flow *= np.exp(-np.clip(t - 0.45, 0, None) / 0.12)
    return _fade(_norm(sq + flow * 0.8, 0.55), 10)


def cistern(seed):
    r = np.random.default_rng(seed + 340)
    n = int(SR * 0.8)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, f in enumerate((2300, 3100)):
        on = int(k * 0.05 * SR)
        tt = t[: n - on]
        x[on:] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.05) * (0.7 - 0.2 * k)
    drag = _lp(_pn(r, n), 0.2) * np.exp(-((t - 0.12) / 0.07) ** 2) * 0.5
    trickle = _bp(_pn(r, n), 700, 2600) * np.clip((t - 0.25) / 0.2, 0, 1) * np.exp(-np.clip(t - 0.4, 0, None) / 0.2) * 0.35
    return _fade(_norm(x + drag + trickle, 0.55), 8)


def piano(seed):
    r = np.random.default_rng(seed + 380)
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(int(r.integers(2, 4))):
        f = 110.0 * 2 ** (int(r.choice([0, 3, 5, 7, 10, 12, 15])) / 12.0) * float(r.choice([1, 2]))
        on = int(r.uniform(0.0, 0.12) * SR) + int(k * 0.03 * SR)
        tt = t[: n - on]
        x[on:] += (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * 2.01 * f * tt) + 0.25 * np.sin(2 * np.pi * 3.02 * f * tt)) * np.exp(-tt / 0.35) * 0.5
    return _fade(_norm(x, 0.55), 6)


def clock(_seed):
    n = int(SR * 1.2)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, (on, f) in enumerate(((0.0, 1500), (0.32, 1250))):
        i = int(on * SR)
        tt = t[: n - i]
        x[i:] += np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.012) * 0.8
    i = int(0.62 * SR)
    tt = t[: n - i]
    x[i:] += (np.sin(2 * np.pi * 523 * tt) + 0.4 * np.sin(2 * np.pi * 1318 * tt) + 0.2 * np.sin(2 * np.pi * 2093 * tt)) * np.exp(-tt / 0.28) * 0.5
    return _fade(_norm(x, 0.55), 8)


def static(_seed):
    r = np.random.default_rng(7)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    hiss = _bp(_pn(r, n), 600, 5000) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * np.exp(-t / 0.3)
    whistle = np.sin(2 * np.pi * np.cumsum(500 + 1800 * np.clip(t / 0.4, 0, 1) ** 2) / SR) * np.exp(-t / 0.25) * 0.18
    return _fade(_norm(hiss + whistle, 0.5), 6)


def beep(_seed):
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(3):
        i = int(k * 0.2 * SR)
        L = int(0.09 * SR)
        x[i:i + L] += np.sin(2 * np.pi * 2000 * np.arange(L) / SR) * np.minimum(np.arange(L) / 60.0, 1.0) * np.minimum((L - np.arange(L)) / 60.0, 1.0) * 0.6
    return _fade(_norm(x, 0.45), 4)


def spring(seed):
    r = np.random.default_rng(seed + 420)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(int(r.integers(3, 5))):
        on = r.uniform(0.0, 0.3)
        d = r.uniform(0.07, 0.14)
        f0 = r.uniform(180, 320)
        tt = np.clip(t - on, 0, None)
        x += np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.35 * np.clip((t - on) / d, 0, 1)) + 25 * np.sin(2 * np.pi * 30 * t)) / SR) * np.where(t >= on, np.exp(-tt / d), 0) * 0.45
    return _fade(_norm(x + _lp(_pn(r, n), 0.3) * 0.08, 0.5), 8)


def squeak(seed):
    r = np.random.default_rng(seed + 460)
    n = int(SR * 0.34)
    t = np.arange(n) / SR
    f = (900 + 500 * r.random()) * (1 + 0.5 * np.clip(t / 0.12, 0, 1)) * (1 + 0.04 * np.sin(2 * np.pi * 40 * t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * _env(n, 0.01, 0.12) + 0.3 * np.sin(2 * np.pi * np.cumsum(2 * f) / SR) * _env(n, 0.01, 0.08)
    return _fade(_norm(x, 0.5), 6)


def roll(seed):
    r = np.random.default_rng(seed + 500)
    n = int(SR * 0.65)
    t = np.arange(n) / SR
    rumble = _lp(_pn(r, n), 0.08) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)) * np.exp(-t / 0.4)
    x = rumble * 0.9
    for k in range(int(r.integers(5, 9))):
        i = int(r.uniform(0.02, 0.5) * SR)
        L = int(0.012 * SR)
        x[i:i + L] += r.normal(0, 1, L) * np.exp(-np.arange(L) / 40.0) * 0.5
    return _fade(_norm(x, 0.5), 10)


def fridge(_seed):
    r = np.random.default_rng(11)
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    thunk = np.sin(2 * np.pi * 85 * t) * np.exp(-t / 0.05) * 0.9
    seal = _bp(_pn(r, n), 1500, 6000) * np.exp(-np.clip(t - 0.03, 0, None) / 0.08) * (t > 0.03) * 0.3
    hum = np.sin(2 * np.pi * 100 * t) * np.clip((t - 0.3) / 0.15, 0, 1) * np.exp(-np.clip(t - 0.45, 0, None) / 0.2) * 0.15
    return _fade(_norm(thunk + seal + hum, 0.55), 6)


def printer(_seed):
    r = np.random.default_rng(13)
    n = int(SR * 0.8)
    t = np.arange(n) / SR
    saw = ((t * 140) % 1.0 * 2 - 1) * 0.25
    mot = _lp(saw, 0.15) * np.clip(t / 0.05, 0, 1) * np.exp(-np.clip(t - 0.4, 0, None) / 0.12)
    feed = _bp(_pn(r, n), 1200, 4800) * (0.5 + 0.5 * np.sin(2 * np.pi * 38 * t)) * np.clip((t - 0.05) / 0.05, 0, 1) * np.exp(-np.clip(t - 0.45, 0, None) / 0.12) * 0.35
    return _fade(_norm(mot + feed, 0.5), 8)


def needle(_seed):
    r = np.random.default_rng(17)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    crackle = np.zeros(n)
    for _ in range(90):
        i = int(r.uniform(0.0, 0.5) * SR)
        L = int(r.integers(6, 30))
        crackle[i:i + L] += r.normal(0, 1, L) * np.exp(-np.arange(L) / 6.0) * r.uniform(0.1, 0.7)
    drag = _lp(_pn(r, n), 0.22) * np.exp(-((t - 0.12) / 0.09) ** 2) * 0.7
    thump = np.sin(2 * np.pi * 70 * np.clip(t - 0.3, 0, None)) * np.exp(-np.clip(t - 0.3, 0, None) / 0.04) * (t >= 0.3) * 0.5
    return _fade(_norm(crackle + drag + thump, 0.5), 6)


def pffft(_seed):
    r = np.random.default_rng(19)
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    k = 0.45 * np.exp(-t / 0.15) + 0.05
    y = np.zeros(n)
    p = 0.0
    nz = _pn(r, n)
    for i in range(n):
        p += k[i] * (nz[i] - p)
        y[i] = p
    return _fade(_norm(y * np.exp(-t / 0.2), 0.5), 12)


def unroll(_seed):
    r = np.random.default_rng(4801)
    n = int(SR * 0.74)
    t = np.arange(n) / SR
    x = np.zeros(n)
    tt, period = 0.0, 0.016                                                 # the roll turning on its spindle: ticks that slow as the pull stops
    while tt < 0.5:
        i = int(tt * SR)
        L = int(0.006 * SR)
        x[i:i + L] += r.normal(0, 1, L) * np.exp(-np.arange(L) / 18.0) * 0.45
        tt += period
        period *= 1.075
    swell = np.exp(-((t - 0.2) / 0.18) ** 2)                                # the paper rasping off while it is pulled
    body = _bp(_pn(r, n), 300, 2600) * swell
    j, L = int(0.54 * SR), int(0.05 * SR)                                    # the tear
    x[j:j + L] += _hp(_lp(r.normal(0, 1, L), 0.4), 0.9) * np.exp(-np.arange(L) / (L * 0.25)) * 0.7
    return _fade(_norm(_lp(x, 0.4) * 0.9 + body * 0.9, 0.55))


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
    for k in range(2):
        _write("tap_%d.wav" % k, tap(k))
        _write("spring_%d.wav" % k, spring(k))
        _write("squeak_%d.wav" % k, squeak(k))
        _write("roll_%d.wav" % k, roll(k))
    for k in range(3):
        _write("piano_%d.wav" % k, piano(k))
    _write("cistern_0.wav", cistern(0))
    _write("clock_0.wav", clock(0))
    _write("static_0.wav", static(0))
    _write("beep_0.wav", beep(0))
    _write("fridge_0.wav", fridge(0))
    _write("printer_0.wav", printer(0))
    _write("needle_0.wav", needle(0))
    _write("pffft_0.wav", pffft(0))
    _write("unroll_0.wav", unroll(0))
    print("wrote", len(os.listdir(OUT)), "files to", os.path.relpath(OUT))


if __name__ == "__main__":
    main()
