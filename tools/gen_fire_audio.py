"""Generates the Molotov / fire one-shots + loop (assets/audio/fire/*.wav). CC0 — made for this project.

  molotov_whoosh_N.wav  the thrown bottle cutting the air: a band-passed noise swell whose centre rises then falls, with the
                        rag's flutter (a few quick crackle ticks) riding it — 0.55 s
  molotov_ignite.wav    the burst: glass has already gone, this is the FWOOMP — a low thump (a sine falling 95 -> 38 Hz), a
                        roaring noise swell that blooms and tails off, and the first crackles of the fire catching — 1.5 s
  flame_catch.wav       a body catching: a short, higher whoomph + a couple of crackles — 0.55 s
  fire_loop.wav         the burning patch: a low steady rumble, a thin hiss, and random pops / crackles; SEAMLESS (the tail is
                        cross-faded into the head) — 4.0 s
  fire_douse.wav        an extinguisher beating a fire out: a hard hiss that decays, with a few late steam ticks — 1.1 s
Mono 16-bit 44.1 kHz, deterministic.
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio', 'fire')


def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], btype='band')
    return lfilter(b, a, x)


def lp(x, f):
    b, a = butter(2, f / (SR / 2), btype='low')
    return lfilter(b, a, x)


def hp(x, f):
    b, a = butter(2, f / (SR / 2), btype='high')
    return lfilter(b, a, x)


def swept_noise(rng, n, f0, f1, fmid_t, q=1.6):
    """Noise through a band-pass whose centre glides f0 -> f1 -> f0 (peak at fmid_t of the length), block by block."""
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    block = 512
    for i0 in range(0, n, block):
        k = i0 / n
        w = 1.0 - abs(k - fmid_t) / max(fmid_t, 1 - fmid_t)
        c = f0 + (f1 - f0) * max(0.0, w)
        seg = noise[max(0, i0 - 64): i0 + block]
        y = bp(seg, c / q, min(c * q, SR / 2 - 100))
        out[i0: i0 + block] = y[-len(noise[i0: i0 + block]):]
    return out


def crackles(rng, n, count, t0=0.0, t1=1.0, amp=0.5, lo=1500, hi=7000):
    out = np.zeros(n)
    for _ in range(count):
        i0 = int((t0 + rng.random() * (t1 - t0)) * (n - 400))
        ln = int(rng.integers(30, 220))
        tick = bp(rng.normal(0, 1, ln + 40), float(rng.uniform(lo, hi * 0.6)), float(rng.uniform(hi * 0.7, hi)))[20: 20 + ln]
        tick *= np.exp(-np.arange(ln) / (ln * float(rng.uniform(0.18, 0.4))))
        out[i0: i0 + ln] += tick * amp * float(rng.uniform(0.35, 1.0))
    return out


def norm(x, peak=0.9, fade=0.02):
    x = np.tanh(x * 1.05)
    x = x / max(1e-6, np.abs(x).max()) * peak
    f = int(SR * fade)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def whoosh(seed):
    rng = np.random.default_rng(seed)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / 0.55, 0, 1)) ** 1.6
    body = swept_noise(rng, n, 500, 2300, 0.42) * env
    flutter = crackles(rng, n, int(rng.integers(7, 11)), 0.1, 0.9, 0.35) * env
    return norm(body * 0.9 + flutter, 0.8)


def ignite(seed=77):
    rng = np.random.default_rng(seed)
    n = int(SR * 1.5)
    t = np.arange(n) / SR
    # the thump
    f = 38 + 57 * np.exp(-t / 0.07)
    ph = 2 * np.pi * np.cumsum(f) / SR
    thump = np.sin(ph) * np.exp(-t / 0.16) * 1.2
    # the bloom: noise roaring up fast, tailing off
    env = (1 - np.exp(-t / 0.045)) * np.exp(-t / 0.5)
    roar = lp(rng.normal(0, 1, n), 1400) * env * 1.4
    air = swept_noise(rng, n, 300, 1800, 0.12) * np.exp(-t / 0.35) * 0.8
    crack = crackles(rng, n, 26, 0.04, 0.95, 0.5) * np.exp(-t / 0.9)
    return norm(thump + roar + air + crack, 0.92, 0.03)


def catch(seed=91):
    rng = np.random.default_rng(seed)
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    env = (1 - np.exp(-t / 0.03)) * np.exp(-t / 0.18)
    body = swept_noise(rng, n, 600, 2600, 0.1) * env
    thump = np.sin(2 * np.pi * np.cumsum(55 + 40 * np.exp(-t / 0.05)) / SR) * np.exp(-t / 0.09) * 0.7
    return norm(body + thump + crackles(rng, n, 6, 0.05, 0.9, 0.4) * np.exp(-t / 0.3), 0.8)


def fire_loop(seed=5, secs=4.0):
    rng = np.random.default_rng(seed)
    n = int(SR * secs)
    t = np.arange(n) / SR
    rumble = lp(rng.normal(0, 1, n), 220) * (0.9 + 0.25 * np.sin(2 * np.pi * 0.7 * t) * np.sin(2 * np.pi * 0.37 * t + 1.0))
    hiss = hp(lp(rng.normal(0, 1, n), 5200), 1800) * 0.18 * (0.8 + 0.3 * np.sin(2 * np.pi * 1.3 * t))
    pops = crackles(rng, n, int(secs * 15), 0.0, 1.0, 0.7)
    sparks = crackles(rng, n, int(secs * 6), 0.0, 1.0, 0.45, 3500, 9500)
    x = rumble * 1.1 + hiss + pops + sparks
    # seamless: cross-fade the last 0.35 s into the first 0.35 s
    c = int(SR * 0.35)
    ramp = np.linspace(0, 1, c)
    head = x[:c] * ramp + x[-c:] * (1 - ramp)
    x = np.concatenate([head, x[c:-c]])
    x = np.tanh(x * 0.9)
    return (x / np.abs(x).max() * 0.8 * 32767).astype(np.int16)


def douse(seed=33):
    rng = np.random.default_rng(seed)
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    env = (1 - np.exp(-t / 0.04)) * np.exp(-t / 0.42)
    hiss = hp(lp(rng.normal(0, 1, n), 9000), 1500) * env * 1.2
    steam = crackles(rng, n, 9, 0.2, 0.95, 0.3, 2500, 8000) * np.exp(-t / 0.5)
    return norm(hiss + steam, 0.8, 0.05)


def write(name, data):
    os.makedirs(OUT, exist_ok=True)
    if data.dtype != np.int16:
        data = (data * 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print('wrote', path)


def main():
    for k in range(3):
        write('molotov_whoosh_%d.wav' % k, whoosh(401 + k * 29))
    write('molotov_ignite.wav', ignite())
    write('flame_catch.wav', catch())
    write('fire_loop.wav', fire_loop())
    write('fire_douse.wav', douse())


if __name__ == '__main__':
    main()
