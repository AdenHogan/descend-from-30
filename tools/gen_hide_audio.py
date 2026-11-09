#!/usr/bin/env python3
"""The sounds of hiding (owner round 49q: "the heartbeat... I just mean the sounds of a heartbeat. It's the player's heart beating, like taking a deep breath and waiting...
heartbeat sound, deep, tense").

  breath_in.wav       - one slow, deep breath drawn in (about 1.5 s): what the player does as they slip in, and keep still
  breath_out.wav      - the breath let go (about 1.0 s): as they come out
  heartbeat_deep.wav  - a SEAMLESS loop of a slow, deep heart: "lub-dub" at about 54 beats a minute, low and close (nothing above ~500 Hz - it is felt more than heard)

Procedural and CC0, mono 22050 Hz 16-bit, deterministic.  Run:  python3 tools/gen_hide_audio.py   (needs numpy + scipy)  ->  assets/audio/stealth/

The heart is built from low sine thumps (a "lub" at 52 Hz, a softer "dub" at 64 Hz 0.31 s later) with a quick pitch drop and an exponential decay, a little chest "knock" of
band-limited noise on the attack, and a soft room (a short dark reverb); the loop is four beats whose last decay runs out before the end, so it repeats with no tick.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "stealth")
BPM = 54.0


def _thump(n, f0, f1, decay, amp):
    """One low thump: a sine whose pitch falls from f0 to f1 as it dies away."""
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 28.0)
    phase = 2.0 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t / decay) * np.minimum(1.0, t / 0.006)
    return amp * np.sin(phase) * env


def _knock(n, rng, amp):
    """The chest's soft knock on the attack: a few ms of low-passed noise."""
    t = np.arange(n) / SR
    x = audiolib.lp(rng.normal(0, 1, n), SR, 220.0, order=2)
    return amp * x * np.exp(-t / 0.022) * np.minimum(1.0, t / 0.003)


def heartbeat():
    rng = np.random.default_rng(4901)
    period = 60.0 / BPM
    beats = 4
    n = int(SR * period * beats)
    out = np.zeros(n)
    for b in range(beats):
        t0 = int(SR * period * b)
        vary = 1.0 + 0.06 * rng.normal()                         # no two beats exactly alike
        lub = _thump(int(SR * 0.7), 58.0, 44.0, 0.13, 1.0 * vary)
        lub[:int(SR * 0.12)] += _knock(int(SR * 0.12), rng, 0.55)
        dub = _thump(int(SR * 0.6), 70.0, 52.0, 0.10, 0.62 * vary)
        dub[:int(SR * 0.1)] += _knock(int(SR * 0.1), rng, 0.30)
        for x, at in ((lub, t0), (dub, t0 + int(SR * 0.31))):
            m = min(len(x), n - at)
            out[at:at + m] += x[:m]
    out = audiolib.lp(out, SR, 480.0, order=2)
    # a short dark room so it sits IN the space, not on top of it: wrap the tail so the loop is seamless
    ir = audiolib.schroeder_ir(SR, np.random.default_rng(7), secs=0.9, pre_ms=6.0, bands=((40, 300, 0.9), (300, 900, 0.35), (900, 2000, 0.1)))
    wet = audiolib.reverb_full(out, SR, ir)
    tail = wet[n:]
    wet = wet[:n].copy()
    wet[:len(tail)] += tail                                      # fold the tail back over the head: the loop is seamless
    x = out + 0.35 * wet
    x = x - x.mean()
    return audiolib.normalise(audiolib.soft(x / max(1e-9, np.abs(x).max()), 1.2), 0.62)


def _breath(secs, rise, rng, lo, hi, fall=0.12):
    n = int(SR * secs)
    t = np.arange(n) / SR
    x = audiolib.pink(n, rng)
    x = audiolib.bp(x, SR, lo, hi, order=2)
    swell = np.where(t < secs * rise, (t / (secs * rise)) ** 1.6, np.exp(-(t - secs * rise) / (secs * fall)))
    return x * swell


def breath_in():
    rng = np.random.default_rng(31)
    x = _breath(1.5, 0.82, rng, 260.0, 2300.0, 0.06)
    return audiolib.polish(x, SR, hi=2800.0, lo=120.0, peak=0.5, ms_in=60.0, ms_out=90.0)


def breath_out():
    rng = np.random.default_rng(32)
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    x = audiolib.bp(audiolib.pink(n, rng), SR, 200.0, 1800.0, order=2)
    swell = np.minimum(1.0, t / 0.08) * np.exp(-t / 0.34)
    return audiolib.polish(x * swell, SR, hi=2400.0, lo=110.0, peak=0.42, ms_in=20.0, ms_out=120.0)


def main():
    os.makedirs(OUT, exist_ok=True)
    audiolib.write_wav(os.path.join(OUT, "heartbeat_deep.wav"), heartbeat(), SR)
    audiolib.write_wav(os.path.join(OUT, "breath_in.wav"), breath_in(), SR)
    audiolib.write_wav(os.path.join(OUT, "breath_out.wav"), breath_out(), SR)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
