#!/usr/bin/env python3
"""Room ambience for the live details (owner round 22 — "when getting closer to the TV that is on,
there should be some very mild static, and with the turntable… a small bit of music playing, get
caught, then loop back, constantly getting stuck and repeating maybe ten seconds of sound, with a
clear scratch to repeat"). Procedurally made here — CC0, like the storm ambience. Mono 22050 Hz,
16-bit PCM WAV, each authored to LOOP (scripts/module_anim.gd plays them positionally).

  tv_static.wav     — 3 s of soft television hiss: band-limited noise, a faint mains hum, a slow
                      flutter; the end cross-faded into the start so it loops without a seam.
  record_stuck.wav  — ~10 s of an old record: a lo-fi jazz vamp (electric piano on Cmaj7 - Am7 - Dm7 -
                      G7, a walking bass, brushes, a little melody), crackle and a warm roll-off,
                      then the needle catches — a click and a scratch — and it's back at the start.

Run:  python3 tools/gen_room_audio.py   (needs numpy)   ->  assets/audio/ambience/
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")
RNG = np.random.default_rng(2207)


def _write(name, x):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1.0, 1.0)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())
    print("wrote", os.path.relpath(path), "(%.1fs)" % (len(x) / SR))


def _lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def _loop_seam(x, fade):
    # cross-fade the tail into the head so the loop point is seamless
    n = int(fade * SR)
    head, tail = x[:n].copy(), x[-n:]
    t = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * t + tail * (1 - t)
    return x


def tv_static():
    n = int(3.2 * SR)
    t = np.arange(n) / SR
    white = RNG.uniform(-1, 1, n)
    hiss = white - _lowpass(white, 900)                  # drop the rumble
    hiss = _lowpass(hiss, 6500)                          # and the harshest top
    flutter = 0.8 + 0.2 * np.sin(2 * np.pi * 0.7 * t) * np.sin(2 * np.pi * 0.23 * t)
    hum = 0.04 * np.sin(2 * np.pi * 50 * t) + 0.015 * np.sin(2 * np.pi * 100 * t)
    x = hiss * flutter * 0.55 + hum
    x = _loop_seam(x, 0.2)
    return x / np.max(np.abs(x)) * 0.5


def _note(freq, dur, kind="ep"):
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == "ep":                                     # an electric piano: bell-ish, decaying
        env = np.exp(-t * 2.2) * (1 - np.exp(-t * 180))
        x = (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t * 5)
             + 0.12 * np.sin(2 * np.pi * 3.01 * freq * t) * np.exp(-t * 8))
    elif kind == "bass":
        env = np.exp(-t * 3.0) * (1 - np.exp(-t * 300))
        x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * 2 * freq * t)
    else:                                                # the melody: a soft sine-ish lead
        env = np.minimum(1, t * 30) * np.exp(-t * 1.6)
        x = np.sin(2 * np.pi * freq * t) + 0.2 * np.sin(2 * np.pi * 2 * freq * t + 0.4)
    return x * env


def _add(buf, start, x, gain):
    i = int(start * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i] * gain


def record_stuck():
    beat = 60.0 / 96.0
    bar = 4 * beat
    chords = [  # Cmaj7, Am7, Dm7, G7 (voicings, Hz)
        [261.6, 329.6, 392.0, 493.9],
        [220.0, 261.6, 329.6, 392.0],
        [293.7, 349.2, 440.0, 523.3],
        [196.0, 246.9, 293.7, 349.2],
    ]
    roots = [65.4, 55.0, 73.4, 49.0]
    music_len = 4 * bar                                  # 10 s
    buf = np.zeros(int((music_len + 0.55) * SR))
    for b, (ch, root) in enumerate(zip(chords, roots)):
        t0 = b * bar
        for hit in (0.0, 2.5 * beat):                    # the chord, comped
            for f in ch:
                _add(buf, t0 + hit, _note(f, bar, "ep"), 0.09)
        walk = [root, root * 1.25, root * 1.5, root * 1.333]
        for k, f in enumerate(walk):                     # a walking bass
            _add(buf, t0 + k * beat, _note(f, beat * 1.1, "bass"), 0.32)
        for k in (1, 3):                                 # brushes on 2 and 4
            n = int(0.18 * SR)
            br = RNG.uniform(-1, 1, n)
            br = br - _lowpass(br, 2500)
            _add(buf, t0 + k * beat, br * np.exp(-np.arange(n) / SR * 22), 0.10)
    melody = [(0, 659.3, 1), (1.5, 587.3, 0.5), (2, 523.3, 1.5), (4, 523.3, 1), (5, 493.9, 1),
              (6, 440.0, 2), (8, 440.0, 1), (9, 523.3, 1), (10, 587.3, 1.5), (12, 587.3, 1),
              (13, 493.9, 1), (14, 392.0, 2)]
    for (bt, f, ln) in melody:
        _add(buf, bt * beat, _note(f, ln * beat * 1.4, "lead"), 0.16)
    # an old record: roll off the top, a little wow, crackle
    buf = _lowpass(buf, 3800)
    t = np.arange(len(buf)) / SR
    buf *= 1 + 0.03 * np.sin(2 * np.pi * 0.55 * t)
    crackle = np.zeros(len(buf))
    pops = RNG.integers(0, len(buf), int(music_len * 22))
    crackle[pops] = RNG.uniform(-0.5, 0.5, len(pops))
    crackle = crackle - _lowpass(crackle, 1500)
    hiss = RNG.uniform(-1, 1, len(buf)) * 0.012
    buf += crackle * 0.35 + hiss
    # the needle catches: cut the music just before the end, a sharp click, a short scratch, back
    cut = int(music_len * SR)
    buf[cut:] = 0.0
    fade = int(0.03 * SR)
    buf[cut - fade:cut] *= np.linspace(1, 0.2, fade)
    n = int(0.32 * SR)
    ts = np.arange(n) / SR
    zip_ = RNG.uniform(-1, 1, n)
    zip_ = zip_ - _lowpass(zip_, 1800 + 0 * ts[0])
    sweep = np.sin(2 * np.pi * (900 * ts - 1100 * ts * ts)) * 0.6
    scratch = (zip_ * 0.7 + sweep) * np.exp(-ts * 9) * np.minimum(1, ts * 400)
    _add(buf, music_len, scratch, 0.55)
    buf[cut:cut + 40] += np.linspace(0.9, 0, 40) * np.sign(RNG.uniform(-1, 1, 40))   # the click
    return buf / np.max(np.abs(buf)) * 0.8


if __name__ == "__main__":
    _write("tv_static.wav", tv_static())
    _write("record_stuck.wav", record_stuck())
