#!/usr/bin/env python3
"""Shared DSP for the generated audio (owner round 46: "there's a lot of what feels like static and noise in the audio. It needs cleaning").

WHY the old sounds hissed (measured with tools/audio_audit.py): every noise-based generator used WHITE noise through a one-pole filter (a -6 dB/octave
slope). White noise is equal energy per hertz, so the top octave (6-11 kHz) carried about half of the whole sound — that is "static". A rain loop,
paper, a tap, a radio and a douse were 40-50 % above 6 kHz. The rules every generator follows now, all in here:

  * noise is PINK (-3 dB/oct) or BROWN (-6 dB/oct), never white — noise in nature falls off with pitch;
  * a hard ceiling: a steep (order-4 / 24 dB/oct) zero-phase low-pass, so nothing above `hi` Hz survives to fizz;
  * a DC block + a gentle soft limit (tanh) instead of a clip; every sound fades in / out so nothing clicks;
  * loops are PERIODIC by construction (`periodic_noise` builds the noise in the frequency domain, so the end meets the start exactly) —
    no cross-fade seam, no tick.

Needs numpy + scipy.   Used by tools/gen_*audio.py and tools/gen_music.py.
"""
import wave

import numpy as np
from scipy import signal


# ---------------------------------------------------------------------------------------------------------------- filters
def lp(x, sr, fc, order=4, zero_phase=True):
    """Low-pass at `fc` Hz (Butterworth, `order` x 6 dB/oct). Zero-phase by default (no smear of a transient)."""
    fc = min(float(fc), sr * 0.45)
    sos = signal.butter(order, fc / (sr / 2.0), btype="low", output="sos")
    return signal.sosfiltfilt(sos, x) if zero_phase else signal.sosfilt(sos, x)


def hp(x, sr, fc, order=2, zero_phase=True):
    sos = signal.butter(order, float(fc) / (sr / 2.0), btype="high", output="sos")
    return signal.sosfiltfilt(sos, x) if zero_phase else signal.sosfilt(sos, x)


def bp(x, sr, lo, hi, order=2, zero_phase=True):
    hi = min(float(hi), sr * 0.45)
    sos = signal.butter(order, [float(lo) / (sr / 2.0), hi / (sr / 2.0)], btype="band", output="sos")
    return signal.sosfiltfilt(sos, x) if zero_phase else signal.sosfilt(sos, x)


# ---------------------------------------------------------------------------------------------------------------- noise
def pink(n, rng):
    """Pink noise (-3 dB/oct), unit RMS. Shaped in the frequency domain, so it is exact and fast."""
    return _coloured(n, rng, 0.5)


def brown(n, rng):
    """Brown noise (-6 dB/oct), unit RMS — the body of a rumble."""
    return _coloured(n, rng, 1.0)


def _coloured(n, rng, power):
    spec = np.fft.rfft(rng.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0)
    f[0] = f[1] if len(f) > 1 else 1.0
    spec *= f ** (-power)
    spec[0] = 0.0
    x = np.fft.irfft(spec, n)
    # (1/f over four decades piles nearly all its power into the lowest bins — a slow wander that is a DC offset in a short sound — so the
    #  bottom is rolled off at about 1/1100 of the sample rate: ~20 Hz at 22 kHz. Applied in the time domain, so n need not be a nice length.)
    x = signal.sosfiltfilt(signal.butter(2, 0.0018, btype="high", output="sos"), x) if n > 64 else x
    return x / (np.sqrt((x ** 2).mean()) + 1e-12)


def periodic_noise(n, rng, sr, lo=150.0, hi=5500.0, tilt=0.5, order=4):
    """Band-limited coloured noise that LOOPS EXACTLY: built in the frequency domain, so sample n-1 flows into sample 0 with no seam at all.
    `tilt` = the slope as a power of 1/f (0 white, 0.5 pink, 1 brown). `lo` / `hi` = Butterworth-shaped edges. Unit RMS."""
    spec = np.fft.rfft(rng.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0 / sr)
    ff = np.maximum(f, 1.0)
    mag = ff ** (-tilt)
    mag *= 1.0 / np.sqrt(1.0 + (ff / hi) ** (2 * order))              # the ceiling
    mag *= 1.0 / np.sqrt(1.0 + (lo / ff) ** (2 * 2))                  # the floor (12 dB/oct)
    mag[0] = 0.0
    x = np.fft.irfft(spec * mag, n)
    return x / (np.sqrt((x ** 2).mean()) + 1e-12)


# ---------------------------------------------------------------------------------------------------------------- finishing
def soft(x, drive=1.0):
    """A gentle tanh limiter: unity for small signals, rounds off peaks instead of clipping them flat."""
    return np.tanh(x * drive) / np.tanh(drive) if drive > 0 else x


def fade(x, sr, ms_in=8.0, ms_out=20.0):
    x = x.copy()
    a, b = int(sr * ms_in / 1000.0), int(sr * ms_out / 1000.0)
    if a > 0:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        x[-b:] *= np.linspace(1.0, 0.0, b)
    return x


def polish(x, sr, hi=6500.0, lo=35.0, peak=0.5, ms_in=6.0, ms_out=24.0, drive=1.0, order=4):
    """The last step of every one-shot: DC block, steep ceiling at `hi`, soft limit, fades, normalise to `peak` (linear).
    Pad first so the zero-phase filter has room to ring out, then trim back to the original length."""
    pad = int(sr * 0.05)
    y = np.concatenate([np.zeros(pad), x - x.mean(), np.zeros(pad)])
    y = hp(y, sr, lo, order=2)
    if hi is not None and hi < sr * 0.45:
        y = lp(y, sr, hi, order=order)
    y = y[pad:-pad]
    y = soft(y / max(1e-9, np.abs(y).max()), drive) if drive != 1.0 else y
    y = fade(y, sr, ms_in, ms_out)
    m = float(np.abs(y).max())
    return y * (peak / m) if m > 1e-9 else y


def normalise(x, peak=0.5):
    m = float(np.abs(x).max())
    return x * (peak / m) if m > 1e-9 else x


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


def rms(x):
    return float(np.sqrt((np.asarray(x) ** 2).mean()))


def write_wav(path, x, sr):
    """Mono (1-D) or stereo (n, 2) float -> 16-bit PCM WAV. Clipped to +-1 as a last resort (callers limit first)."""
    x = np.clip(np.asarray(x), -1.0, 1.0)
    ch = 1 if x.ndim == 1 else x.shape[1]
    with wave.open(path, "w") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767.0).astype("<i2").tobytes())


def schroeder_ir(sr, rng, secs=2.8, pre_ms=18.0, bands=((60, 400, 3.4), (400, 2200, 2.0), (2200, 5200, 0.55))):
    """A synthetic dark-hall impulse response: bands of noise (low / mid / a short-lived high) with their own RT60 decay times (seconds to fall 60 dB), so the tail is warm
    and falls into the dark instead of hissing. Returns a mono IR of unit energy."""
    n = int(sr * secs)
    t = np.arange(n) / sr
    ir = np.zeros(n)
    for lo, hi, tau in bands:
        ir += bp(rng.normal(0.0, 1.0, n), sr, lo, hi, order=2, zero_phase=False) * np.exp(-t * 6.9 / tau) * (1.0 if hi < 3000 else 0.45)
    pre = int(sr * pre_ms / 1000.0)
    ir = np.concatenate([np.zeros(pre), ir])[:n]
    ir *= np.minimum(t / 0.012, 1.0)                                  # the first few ms ramp in (no click)
    return ir / np.sqrt((ir ** 2).sum())


def reverb(x, sr, ir):
    """Convolve (n,) with an IR via FFT; returns the wet signal the SAME length as x (the tail is cut — fold it yourself for a loop)."""
    return signal.fftconvolve(x, ir)[: len(x)]


def reverb_full(x, sr, ir):
    """As `reverb` but keeps the whole tail (len(x) + len(ir) - 1), so a loop can fold it back over its head."""
    return signal.fftconvolve(x, ir)
