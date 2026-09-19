#!/usr/bin/env python3
"""Generate night-storm ambience for apartment windows: a couple of thunder
rumbles and a seamless rain loop. Pure stdlib (matches the project's synth SFX
approach — CC0-equivalent, generated here). Mono 22050 Hz, 16-bit PCM WAV.

Run:  python3 tools/gen_storm_audio.py
Writes into assets/audio/ambience/.
"""
import math
import os
import random
import struct
import wave

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


def rain_loop(seed, dur=4.0):
    """Steady hiss of rain: high-passed white noise, level and seamless so it
    loops without a seam. A slow shimmer gives it life without a detectable period."""
    rng = random.Random(seed)
    n = int(SR * dur)
    # White noise -> simple one-pole high-pass (rain is bright/hissy, not rumbly).
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    hp = [0.0] * n
    prev_in = 0.0
    prev_out = 0.0
    a = 0.85
    for i in range(n):
        hp[i] = a * (prev_out + white[i] - prev_in)
        prev_in = white[i]
        prev_out = hp[i]
    out = []
    for i in range(n):
        # Gentle amplitude shimmer (two slow sines, non-harmonic) so it's not flat.
        sh = 0.82 + 0.10 * math.sin(2 * math.pi * i / SR * 0.7) \
                  + 0.08 * math.sin(2 * math.pi * i / SR * 1.9)
        out.append(hp[i] * 0.34 * sh)
    # Cross-fade the last 40ms into the first so the loop point is seamless.
    xf = int(0.04 * SR)
    for i in range(xf):
        w = i / xf
        out[i] = out[i] * w + out[n - xf + i] * (1.0 - w)
    return out[: n - xf]


if __name__ == "__main__":
    _write("thunder_1.wav", thunder(101))
    _write("thunder_2.wav", thunder(202))
    _write("rain_loop.wav", rain_loop(303))
