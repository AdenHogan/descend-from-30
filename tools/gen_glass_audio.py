"""Generates the glass-smash one-shots for thrown bottles (assets/audio/impacts/glass_smash_*.wav).

A smash is three layers: a sharp broadband CRACK at the impact, a short bright NOISE burst (the pane-like
body of the sound), and a cloud of TINKLES — dozens of high sine pings at random onsets, each decaying fast —
which is the glass pieces landing. Mono 16-bit 44.1 kHz, deterministic per variant. CC0 (made for this project).
"""
import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'audio', 'impacts')


def highpass(x, k=0.97):
    y = np.zeros_like(x)
    prev_x = prev_y = 0.0
    for i, v in enumerate(x):
        prev_y = k * (prev_y + v - prev_x)
        prev_x = v
        y[i] = prev_y
    return y


def smash(seed):
    rng = np.random.default_rng(seed)
    n = int(SR * 1.15)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # the crack: a few ms of hard noise
    c = int(SR * 0.012)
    out[:c] += rng.normal(0, 1, c) * np.exp(-np.arange(c) / (c * 0.35)) * 1.0
    # the body: bright noise that dies over ~0.3 s, brighter at the start
    body = highpass(rng.normal(0, 1, n), 0.93) * np.exp(-t / 0.085) * 0.55
    out += body
    # the tinkles: glass pieces pinging and skittering
    for _ in range(int(rng.integers(34, 52))):
        onset = float(rng.beta(1.2, 3.0)) * 0.85
        f = float(rng.uniform(2200, 8800))
        dec = float(rng.uniform(0.012, 0.055))
        amp = float(rng.uniform(0.10, 0.34)) * (1.0 - onset * 0.6)
        i0 = int(onset * SR)
        tt = t[: n - i0]
        ping = np.sin(2 * np.pi * f * tt) * np.exp(-tt / dec)
        ping += 0.4 * np.sin(2 * np.pi * f * 2.43 * tt) * np.exp(-tt / (dec * 0.6))
        out[i0:] += amp * ping
    # a little room: one quiet echo
    e = int(SR * 0.09)
    out[e:] += out[:-e] * 0.18
    out = np.tanh(out * 1.1)
    out /= max(1e-6, np.abs(out).max())
    fade = int(SR * 0.04)
    out[-fade:] *= np.linspace(1, 0, fade)
    return (out * 0.85 * 32767).astype(np.int16)


def main():
    os.makedirs(OUT, exist_ok=True)
    for k in range(3):
        path = os.path.join(OUT, 'glass_smash_%d.wav' % k)
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(smash(1201 + k * 37).tobytes())
        print('wrote', path)


if __name__ == '__main__':
    main()
