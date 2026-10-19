#!/usr/bin/env python3
"""Generate night-storm ambience for apartment windows: a couple of thunder
rumbles and a seamless rain loop. Generated here (CC0-equivalent). Mono 22050 Hz, 16-bit PCM WAV.
The thunder is pure stdlib; the rain loop (round 46) uses tools/audiolib.py (numpy + scipy) — the old loop was white noise through a
one-pole high-pass, ~half its energy above 6 kHz: a constant TV-static hiss under every night flat.

Run:  python3 tools/gen_storm_audio.py
Writes into assets/audio/ambience/.
"""
import math
import os
import random
import struct
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")


def _write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s)) * 32767.0)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", os.path.relpath(path), "(%.1fs)" % (len(samples) / SR))


def _brown(n, rng, damp=0.02):
    """Brown-ish noise (integrated white, gently leaked) — the body of a rumble."""
    out = []
    v = 0.0
    for _ in range(n):
        v += rng.uniform(-1.0, 1.0)
        v -= v * damp          # leak so it doesn't wander off
        out.append(v)
    m = max(1e-6, max(abs(x) for x in out))
    return [x / m for x in out]


def thunder(seed, dur=3.6, rolls=3):
    """A low rumble that rolls in a couple of waves, with a distant crack up top."""
    rng = random.Random(seed)
    n = int(SR * dur)
    body = _brown(n, rng, damp=0.008)
    out = [0.0] * n
    # A few overlapping rumble "rolls", each with its own soft attack + long decay.
    for r in range(rolls):
        start = int(rng.uniform(0.0, 0.45) * SR) + r * int(0.35 * SR)
        peak = rng.uniform(0.55, 1.0) * (1.0 - 0.18 * r)
        atk = int(rng.uniform(0.04, 0.12) * SR)
        dec = int(rng.uniform(1.1, 1.9) * SR)
        for i in range(atk + dec):
            idx = start + i
            if idx >= n:
                break
            if i < atk:
                env = i / max(1, atk)
            else:
                env = math.exp(-(i - atk) / max(1.0, dec * 0.4))
            out[idx] += body[idx] * env * peak
    # A faint high crackle near the front (the sharp part of a distant strike).
    crack_at = int(rng.uniform(0.0, 0.25) * SR)
    for i in range(int(0.25 * SR)):
        idx = crack_at + i
        if idx >= n:
            break
        env = math.exp(-i / (0.05 * SR))
        out[idx] += rng.uniform(-1.0, 1.0) * env * 0.18
    m = max(1e-6, max(abs(x) for x in out))
    return [0.9 * x / m for x in out]


def rain_loop(seed, dur=6.0):
    """Rain heard through a window and a roof, and NOT a hiss: a soft wash of PINK noise (250 Hz - 4.2 kHz, nothing above), the patter of single drops
    (short damped pings, each its own pitch and loudness) and a low drum of water on the roof. It is PERIODIC by construction (the wash is built in the
    frequency domain, the drops wrap round the end, every swell is a whole number of cycles per loop), so there is no seam and no tick."""
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    wash = audiolib.periodic_noise(n, rng, SR, lo=250.0, hi=4200.0, tilt=0.75)
    roof = audiolib.periodic_noise(n, rng, SR, lo=70.0, hi=420.0, tilt=0.4)
    drops = np.zeros(n)
    for _ in range(int(dur * 70)):                                      # ~70 drops a second
        i = int(rng.integers(0, n))
        f = float(rng.uniform(1100.0, 3300.0))
        L = int(SR * float(rng.uniform(0.004, 0.011)))
        tt = np.arange(L) / SR
        ping = np.sin(2 * np.pi * f * tt) * np.exp(-tt / (L / SR * 0.35)) * float(rng.beta(1.2, 4.0))
        idx = (i + np.arange(L)) % n                                    # wraps, so the loop point is not a seam
        drops[idx] += ping
    swell = 1.0 + 0.10 * np.sin(2 * np.pi * 1.0 * t / dur + 0.4) + 0.06 * np.sin(2 * np.pi * 3.0 * t / dur + 1.9)
    x = (wash * 0.62 + roof * 0.30 + drops * 2.2) * swell
    x = audiolib.soft(x / np.abs(x).max(), 1.2)
    x *= 0.07 / audiolib.rms(x)                                         # about -23 dBFS RMS: a bed, not a wall (the old loop was -17)
    return list(x)


if __name__ == "__main__":
    _write("thunder_1.wav", thunder(101))
    _write("thunder_2.wav", thunder(202))
    _write("rain_loop.wav", rain_loop(303))
