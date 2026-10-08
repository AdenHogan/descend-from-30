"""Generates the CHARACTER-OPENING sounds (owner round 37; docs/CHARACTER_STORIES.md) — all CC0, made for this project, PLACEHOLDERS the
owner may replace with recorded ones (keep the file names):

    assets/audio/cat/meow_1..3.wav     Vivianne's cat: a "mee-ow" — a pitch glide through a vowel glide (ee -> ow), three voices
    assets/audio/story/scream_far.wav  Alex hears a scream from the stairwell: a raw rising cry, low-passed + echoed so it comes from far off
    assets/audio/story/growl.wav       Amina's empty stomach: a low gurgling rumble

A small source-filter voice: a glottal-ish pulse source at a gliding pitch run through three time-varying resonators (the formants),
plus breath noise. Mono 16-bit 44.1 kHz, deterministic per file.
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lowpass(x, k):
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p += k * (v - p)
        y[i] = p
    return y


def resonate(x, freq, bw):
    """A two-pole resonator whose centre `freq` (per sample) and bandwidth change over time."""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    for i in range(len(x)):
        r = np.exp(-np.pi * bw[i] / SR)
        a1 = -2.0 * r * np.cos(2.0 * np.pi * freq[i] / SR)
        a2 = r * r
        v = (1.0 - r) * x[i] - a1 * y1 - a2 * y2
        y2, y1 = y1, v
        y[i] = v
    return y


def interp(t, keys):
    """Piecewise-linear value of keys [(time_fraction, value), ...] at fractions t."""
    ks = [k for k, _ in keys]
    vs = [v for _, v in keys]
    return np.interp(t, ks, vs)


def voice(dur, f0, formants, bw, noise=0.05, rng=None, jitter=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    u = t / dur
    pitch = f0(u)
    if jitter:
        pitch = pitch * (1.0 + jitter * lowpass(rng.normal(0, 1, n), 0.01) * 12.0)
    ph = np.cumsum(2 * np.pi * pitch / SR)
    src = ((ph / np.pi) % 2.0) - 1.0                     # a saw: every harmonic, falling off as the resonators shape it
    src = src - lowpass(src, 0.4) * 0.5
    src += noise * rng.normal(0, 1, n)
    out = np.zeros(n)
    for (fk, g), b in zip(formants, bw):
        out += g * resonate(src, interp(u, fk), np.full(n, float(b)))
    return out, u


def write(path, data, peak=0.6):
    data = data / max(1e-6, np.abs(data).max()) * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())
    print('wrote', os.path.relpath(path, ROOT))


def env(u, a, d, hold_to):
    """Attack to `a`, hold until `hold_to`, decay by 1."""
    e = np.clip(u / a, 0, 1) * (1 - np.clip((u - hold_to) / max(1e-6, 1 - hold_to), 0, 1)) ** d
    return e


def meow(seed, pitch_mul, dur):
    rng = np.random.default_rng(seed)

    def f0(u):
        glide = 0.55 * np.sin(np.pi * np.clip(u, 0, 1) ** 0.7)
        return pitch_mul * (470 + 420 * glide) * (1.0 + 0.012 * np.sin(2 * np.pi * 6.0 * u * dur))
    formants = [([(0, 430), (0.32, 780), (0.65, 880), (1, 620)], 1.0),          # F1: ee -> ow
                ([(0, 2700), (0.3, 2000), (0.65, 1350), (1, 1150)], 0.8),       # F2
                ([(0, 3400), (0.5, 3000), (1, 2700)], 0.35)]
    out, u = voice(dur, f0, formants, (90, 140, 220), noise=0.04, rng=rng, jitter=0.004)
    out *= env(u, 0.07, 1.4, 0.55) * (0.75 + 0.25 * np.sin(np.pi * u))
    return out


def scream_far(seed=7):
    rng = np.random.default_rng(seed)
    dur = 1.7

    def f0(u):
        return 430 + 560 * np.clip(u / 0.28, 0, 1) ** 0.8 - 220 * np.clip((u - 0.6) / 0.4, 0, 1) ** 1.5 + 22 * np.sin(2 * np.pi * 7.5 * u * dur)
    formants = [([(0, 700), (0.3, 900), (1, 760)], 1.0),
                ([(0, 1200), (0.3, 1400), (1, 1100)], 0.9),
                ([(0, 2700), (1, 2500)], 0.5)]
    out, u = voice(dur, f0, formants, (110, 150, 250), noise=0.35, rng=rng, jitter=0.01)
    out *= env(u, 0.05, 1.2, 0.5)
    out = lowpass(lowpass(out, 0.16), 0.2)                                # far off: the top is gone
    pad = np.concatenate([out, np.zeros(SR)])
    echo = np.zeros_like(pad)
    for delay, amp in ((0.21, 0.42), (0.43, 0.22), (0.7, 0.1)):         # the stairwell's echo
        d = int(delay * SR)
        echo[d:] += pad[:-d] * amp
    return lowpass(pad + echo, 0.3)


def growl(seed=3):
    rng = np.random.default_rng(seed)
    dur = 1.9
    n = int(SR * dur)
    t = np.arange(n) / SR
    u = t / dur
    noise = lowpass(lowpass(rng.normal(0, 1, n), 0.05), 0.07) - lowpass(rng.normal(0, 1, n), 0.004)
    noise /= max(1e-6, np.abs(noise).max())
    am = 0.5 + 0.5 * np.sin(2 * np.pi * (5.0 + 3.0 * u) * t + 1.0)
    f = interp(u, [(0, 120), (0.35, 85), (0.6, 100), (1, 62)])
    ph = np.cumsum(2 * np.pi * (f + 14 * np.sin(2 * np.pi * 9 * t)) / SR)
    tone = np.sin(ph) + 0.4 * np.sin(2 * ph)
    pops = np.zeros(n)
    for k in range(7):                                                    # little wet gurgles
        c = int(rng.uniform(0.1, 0.9) * n)
        w = int(rng.uniform(0.02, 0.05) * SR)
        if c + w < n:
            pops[c:c + w] += np.sin(np.linspace(0, np.pi, w)) * rng.uniform(0.2, 0.5) * np.sin(2 * np.pi * rng.uniform(140, 260) * np.arange(w) / SR)
    e = np.minimum(1.0, u / 0.1) * np.minimum(1.0, (1 - u) / 0.25)
    out = (0.8 * noise * am + 0.5 * tone * (0.4 + 0.6 * am) + pops) * e
    return lowpass(out, 0.3)


def main():
    cat = os.path.join(ROOT, 'assets', 'audio', 'cat')
    for i, (mul, dur) in enumerate(((1.0, 0.62), (1.25, 0.46), (0.82, 0.78))):
        write(os.path.join(cat, 'meow_%d.wav' % (i + 1)), meow(40 + i, mul, dur), 0.55)
    story = os.path.join(ROOT, 'assets', 'audio', 'story')
    write(os.path.join(story, 'scream_far.wav'), scream_far(), 0.5)
    write(os.path.join(story, 'growl.wav'), growl(), 0.55)


if __name__ == '__main__':
    main()
