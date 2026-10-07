#!/usr/bin/env python3
"""Sound for the new-game opening (scripts/opening_exterior.gd) — procedurally made, CC0, like the rest of assets/audio.
Mono 22050 Hz 16-bit PCM WAV.

  hum.wav    — 8 s of the city's low air under the picture: a few soft sine partials with slow swells, NO noise (owner round 36f: the old
               noise-band "wind" read as loud static as the building pans); loops exactly (every partial and swell fits the 8 s).
  siren.wav  — 7 s of a siren a long way off across the city: two slow wails, rolled off hard, with an echo; fades in and out.
  swell.wav  — 5 s of a low dark swell for the title: a minor drone that rises, and a soft boom as it lands.

Run:  python3 tools/gen_opening_audio.py   (needs numpy)   ->  assets/audio/opening/
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "opening")
RNG = np.random.default_rng(3510)


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())
    print("wrote", os.path.relpath(path), "(%.1fs)" % (len(x) / SR))


def lowpass(x, cutoff):
    a = float(np.exp(-2.0 * np.pi * cutoff / SR))
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def loop_seam(x, fade):
    n = int(fade * SR)
    head, tail = x[:n].copy(), x[-n:]
    t = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * t + tail * (1 - t)
    return x


def hum():
    n = int(8.0 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # pure tones on whole cycles per 8 s, so the loop point is silent-seamless; each breathes on its own slow swell (also whole cycles)
    for f, g, swell_hz, ph in ((55.0, 1.0, 0.125, 0.0), (82.5, 0.55, 0.25, 1.3), (110.0, 0.32, 0.125, 2.4), (165.0, 0.14, 0.375, 0.7)):
        x += g * np.sin(2 * np.pi * f * t + ph) * (0.72 + 0.28 * np.sin(2 * np.pi * swell_hz * t + ph))
    return 0.5 * x / np.max(np.abs(x))


def siren():
    n = int(7.0 * SR)
    t = np.arange(n) / SR
    sweep = 620 + 330 * (0.5 - 0.5 * np.cos(2 * np.pi * t / 3.0))         # a slow wail up and down
    phase = 2 * np.pi * np.cumsum(sweep) / SR
    tone = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)
    env = np.minimum(1.0, t / 1.4) * np.minimum(1.0, (7.0 - t) / 1.6)
    x = lowpass(tone * env, 1100)
    for delay, g in ((0.33, 0.45), (0.71, 0.28), (1.2, 0.16)):         # the city's echo
        d = int(delay * SR)
        x[d:] += g * x[:-d].copy()
    return 0.30 * x / np.max(np.abs(x))


def swell():
    n = int(5.0 * SR)
    t = np.arange(n) / SR
    env = (1 - np.exp(-t * 1.1)) * np.exp(-np.maximum(0, t - 3.4) * 1.6)
    x = np.zeros(n)
    for f, g in ((55.0, 1.0), (82.4, 0.6), (98.0, 0.5), (110.0, 0.3), (130.8, 0.22)):   # A minor-ish drone
        x += g * (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2 * f * t + 0.7))
    x *= env * (0.85 + 0.15 * np.sin(2 * np.pi * t * 0.9))
    boom = np.sin(2 * np.pi * (46.0 - 10.0 * np.minimum(t, 1.0)) * t) * np.exp(-t * 2.2) * (t < 2.5)
    x += 1.4 * boom * np.minimum(1.0, t / 0.02)
    return 0.7 * x / np.max(np.abs(x))


if __name__ == "__main__":
    write("hum.wav", hum())
    write("siren.wav", siren())
    write("swell.wav", swell())
