#!/usr/bin/env python3
"""CLEAN the audio that has no generator of its own (owner round 46: "a lot of what feels like static and noise in the audio").

The generated sounds are rebuilt at their source (tools/gen_*audio.py, all on tools/audiolib.py). What is left are files nobody can regenerate:
three bright Kenney one-shots (a metal latch, two knife slices) and the hand-made zombie moans, which sit at -0.2 dBFS — so loud that two of them at once
hit the ceiling and clip. This pass takes each one the same way:

  * a steep (24 dB/oct), zero-phase low-pass so nothing above the cutoff survives to fizz;
  * a DC block;
  * a peak level with headroom (so a crowd of them cannot clip the Master bus; the Master limiter is the second net);
  * a fade at both ends (no click).

It is IDEMPOTENT: a file already inside its budget (peak and brightness) is left alone, so running it twice changes nothing. The originals are in git
history (the commit before round 46). Run:  python3 tools/audio_clean.py [--dry]      Needs numpy + scipy + ffmpeg.
"""
import os
import subprocess
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")

# file -> (low-pass Hz, peak dBFS). Moans: a voice has nothing useful above ~3.5 kHz but a breathy noise bed. The Kenney blades / latch: bright by
# nature (hf6 0.3-0.4), so a ceiling at 6 kHz keeps the ring / the swish and loses the fizz.
JOBS = {
    "zombie/moan_1.wav": (3600.0, -2.5),
    "zombie/moan_2.wav": (3600.0, -2.5),
    "zombie/moan_3.wav": (3600.0, -2.5),
    "zombie/moan_4.wav": (3600.0, -2.5),
    "doors/metalLatch.ogg": (6000.0, -3.0),
    "impacts/knifeSlice.ogg": (6000.0, -3.0),
    "impacts/knifeSlice2.ogg": (6000.0, -3.0),
}


def read(path):
    """-> (float array shaped (n, ch), sample rate)."""
    if path.endswith(".wav"):
        with wave.open(path) as w:
            sr, ch = w.getframerate(), w.getnchannels()
            raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
        return raw.reshape(-1, ch), sr
    sr = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate", "-of", "csv=p=0", path],
                            capture_output=True, check=True).stdout.decode().split()[0])
    ch = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "csv=p=0", path],
                            capture_output=True, check=True).stdout.decode().split()[0])
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(out, dtype="<f4").astype(np.float64).reshape(-1, ch), sr


def write(path, x, sr):
    if path.endswith(".wav"):
        audiolib.write_wav(path, x[:, 0] if x.shape[1] == 1 else x, sr)
        return
    pcm = np.clip(x, -1.0, 1.0).astype("<f4").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(sr), "-ac", str(x.shape[1]), "-i", "-", "-c:a", "libvorbis", "-q:a", "6", path],
                   input=pcm, check=True)


def hf6(x, sr):
    m = x.mean(axis=1)
    p = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    f = np.fft.rfftfreq(len(m), 1.0 / sr)
    return float(p[f >= 6000].sum() / (p.sum() + 1e-18))


def clean(path, hi, peak_db, dry=False):
    x, sr = read(path)
    peak = float(np.abs(x).max())
    bright = hf6(x, sr)
    ok_peak = peak <= 10 ** ((peak_db + 0.6) / 20.0)
    ok_bright = bright < (0.06 if hi >= 6000.0 else 0.004)      # (a Vorbis re-encode lets a little back in above the cut)
    name = os.path.relpath(path, AUDIO)
    if ok_peak and ok_bright and peak > 0:
        print("  ok     %-28s peak %5.1f dB  hf6 %.3f" % (name, audiolib.db(peak), bright))
        return
    y = np.zeros_like(x)
    for c in range(x.shape[1]):
        y[:, c] = audiolib.polish(x[:, c], sr, hi=hi, lo=25.0, peak=1.0, ms_in=3.0, ms_out=25.0)
    m = float(np.abs(y).max())
    y *= (10 ** (peak_db / 20.0)) / max(m, 1e-9)
    after = hf6(y, sr)
    print("  clean  %-28s peak %5.1f -> %5.1f dB   hf6 %.3f -> %.3f   (low-pass %d Hz)" % (name, audiolib.db(peak), audiolib.db(float(np.abs(y).max())), bright, after, hi))
    if not dry:
        write(path, y, sr)


def main():
    dry = "--dry" in sys.argv
    for rel, (hi, pk) in JOBS.items():
        clean(os.path.join(AUDIO, rel), hi, pk, dry)


if __name__ == "__main__":
    main()
