"""Generates the zombie SHUFFLE one-shots (assets/audio/zombie/shuffle_*.wav): a dragging, scuffing footfall.

Each is a soft low thud (the heavy foot landing) followed by a band-passed noise SCRAPE (the sole dragging
across the floor) that swells and dies, with a little wet creak on some. Mono 16-bit 44.1 kHz, deterministic
per variant. CC0 (made for this project). Played by scripts/enemy_steps.gd.
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio', 'zombie')


def lowpass(x, k):
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p += k * (v - p)
        y[i] = p
    return y


def shuffle(seed):
    rng = np.random.default_rng(seed)
    n = int(SR * 0.62)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # the heavy foot: a low thump
    f0 = float(rng.uniform(62, 88))
    out += np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.045) * 0.9
    # the drag: noise, band-limited, swelling then dying over ~0.4 s
    sc_start = float(rng.uniform(0.03, 0.08))
    sc_len = float(rng.uniform(0.28, 0.42))
    noise = rng.normal(0, 1, n)
    band = lowpass(noise, 0.30) - lowpass(noise, 0.04)
    env = np.zeros(n)
    i0, i1 = int(sc_start * SR), int((sc_start + sc_len) * SR)
    m = i1 - i0
    env[i0:i1] = np.sin(np.pi * np.linspace(0, 1, m)) ** 1.6
    wob = 1.0 + 0.35 * np.sin(2 * np.pi * float(rng.uniform(9, 16)) * t + float(rng.uniform(0, 6)))
    out += band * env * wob * 2.2
    # a wet creak on some
    if rng.random() < 0.5:
        cf = float(rng.uniform(180, 300))
        ce = np.exp(-((t - 0.22) / 0.07) ** 2)
        out += np.sin(2 * np.pi * (cf + 40 * t) * t) * ce * 0.12
    out = np.tanh(out * 0.9)
    out /= max(1e-6, np.abs(out).max())
    fade = int(SR * 0.05)
    out[-fade:] *= np.linspace(1, 0, fade)
    return (out * 0.8 * 32767).astype(np.int16)


def main():
    os.makedirs(OUT, exist_ok=True)
    for i in range(3):
        data = shuffle(900 + i)
        path = os.path.join(OUT, 'shuffle_%d.wav' % (i + 1))
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        print('wrote', path)


if __name__ == '__main__':
    main()
