"""Generates the zombie SHUFFLE one-shots (assets/audio/zombie/shuffle_*.wav): a dragging, scuffing footfall.

Each is a soft low thud (the heavy foot landing) followed by a band-passed noise SCRAPE (the sole dragging
across the floor) that swells and dies, with a little wet creak on some. Owner round 33: the first cut was "very loud and
scratchy… it even overwhelms the moaning" — so the drag is now a DARK, soft brush (low band, no hard clipping, a slower
swell), the thud carries the step, and the file peaks at 0.45 (rms ~0.08); scripts/enemy_steps.gd also plays it far under the
moans. Checked by enemy_variety_test (peak + a zero-crossing brightness bound). Mono 16-bit 44.1 kHz, deterministic
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
    out += np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.05) * 1.0
    # the drag: noise, band-limited, swelling then dying over ~0.4 s
    sc_start = float(rng.uniform(0.03, 0.08))
    sc_len = float(rng.uniform(0.28, 0.42))
    noise = rng.normal(0, 1, n)
    band = lowpass(lowpass(noise, 0.06), 0.10) - lowpass(noise, 0.008)   # dark: a cloth-on-boards brush, not a rasp
    band /= max(1e-6, np.abs(band).max())
    env = np.zeros(n)
    i0, i1 = int(sc_start * SR), int((sc_start + sc_len) * SR)
    m = i1 - i0
    env[i0:i1] = np.sin(np.pi * np.linspace(0, 1, m)) ** 2.4
    wob = 1.0 + 0.2 * np.sin(2 * np.pi * float(rng.uniform(7, 11)) * t + float(rng.uniform(0, 6)))
    out += band * env * wob * 0.55
    # a wet creak on some
    if rng.random() < 0.5:
        cf = float(rng.uniform(180, 300))
        ce = np.exp(-((t - 0.22) / 0.07) ** 2)
        out += np.sin(2 * np.pi * (cf + 40 * t) * t) * ce * 0.12
    out = lowpass(out, 0.25)                                            # take the last of the edge off
    out /= max(1e-6, np.abs(out).max())
    fade = int(SR * 0.05)
    out[-fade:] *= np.linspace(1, 0, fade)
    return (out * 0.45 * 32767).astype(np.int16)


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
