#!/usr/bin/env python3
"""AUDIO AUDIT — measures every sound in assets/audio for the things that read as "static and noise" (owner round 46).

For each file it prints the facts a listener hears as hiss / grit / harshness, so a cleaning pass works from numbers, not from a guess:

  dur      seconds
  peak     highest sample, dBFS (clipping shows as ~0)
  rms      loudness over the whole file, dBFS
  clip     share of samples at >= 0.99 full scale (a click-train of clipping is grit)
  dc       mean offset (a thump when a sound starts / stops)
  low      share of the energy below 120 Hz (a mix that is nearly all sub is a rumble that vanishes on laptop speakers; music should be < 0.9)
  hf3      share of the energy above 3 kHz (brightness; most of a hiss lives up here, a drone / moan / thump has almost none)
  hf6      share of the energy above 6 kHz (hiss; a clean low drone or a moan has almost none)
  hf10     share of the energy above 10 kHz (the "fizz" a noise source adds)
  flat     spectral flatness 100 Hz-5 kHz, 0 = one tone, 1 = white noise (high = noisy / static)
  floor    the quietest tenth of the file, dB under its loud part (-60 = silence between sounds, -20 = hiss all the time)
  seam     a LOOP's click: the sharpest bend across its join, in units of the sharpest bend the signal ordinarily takes (<= 1 = seamless, > 1.5 = an audible tick)
  hiss     a 0-100 score from the above — what to clean first

Run:  python3 tools/audio_audit.py [dir-or-file ...]     (default: assets/audio)       --json out.json   also writes the numbers
      python3 tools/audio_audit.py --check      the GATE (tools/run_all_tests.sh): exits 1 if any sound breaks the budgets in `violations` — a hiss, a clip,
                                                a DC offset, a click at a loop's join, a mix that is all sub — so the static cannot creep back in
Needs numpy + ffmpeg (decodes .ogg / .wav alike).
"""
import json
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SR = 44100
LOOPS = ("dread_loop", "rain_loop", "tv_static", "hum", "crackle_loop", "fire_loop", "breach_")      # judged for their seam


def load(path):
    """-> (mono float samples at the file's OWN rate, that rate). No resampling: a resampler rings at both ends and shows a fake seam on a loop."""
    sr = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate", "-of", "csv=p=0", path],
                            capture_output=True, check=True).stdout.decode().strip().split()[0])
    ch = int(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels", "-of", "csv=p=0", path],
                            capture_output=True, check=True).stdout.decode().split()[0])
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(out, dtype="<f4").astype(np.float64).reshape(-1, ch)
    return x.mean(axis=1), sr                                           # a plain average of the channels (ffmpeg's own mono mix adds 3 dB to centred sound)


def db(x):
    return 20.0 * np.log10(max(float(x), 1e-9))


def spectrum(x, sr=SR):
    n = 4096
    if len(x) < n:
        x = np.pad(x, (0, n - len(x)))
    win = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    cnt = 0
    for i in range(0, len(x) - n + 1, n // 2):
        acc += np.abs(np.fft.rfft(x[i:i + n] * win)) ** 2
        cnt += 1
    return np.fft.rfftfreq(n, 1.0 / sr), acc / max(cnt, 1)


def analyse(path):
    x, sr = load(path)
    if len(x) < 64:
        return None
    peak = float(np.abs(x).max())
    rms = float(np.sqrt((x ** 2).mean()))
    f, p = spectrum(x, sr)
    tot = float(p.sum()) + 1e-18
    low = float(p[f < 120].sum()) / tot
    hf3 = float(p[f >= 3000].sum()) / tot
    hf6 = float(p[f >= 6000].sum()) / tot
    hf10 = float(p[f >= 10000].sum()) / tot
    band = p[(f >= 100) & (f <= 5000)] + 1e-18
    flat = float(np.exp(np.log(band).mean()) / band.mean())
    win = int(0.05 * sr)
    levels = np.array([np.sqrt((x[i:i + win] ** 2).mean()) for i in range(0, max(len(x) - win, 1), win)]) + 1e-9
    floor = db(np.percentile(levels, 10)) - db(np.percentile(levels, 90))
    seam = 0.0
    name = os.path.basename(path)
    if any(k in name for k in LOOPS):
        k = int(0.004 * sr)
        a, b = x[-k:], x[:k]
        ring = np.concatenate([x[-3:], x[:3]])                          # the join, wrapped: ... x[-3] x[-2] x[-1] | x[0] x[1] x[2] ...
        jump = float(np.abs(np.diff(ring, 2)).max())                    # its biggest second difference (a click is a big bend; a smooth join is not)
        bend = float(np.percentile(np.abs(np.diff(x, 2)), 99.9)) + 1e-9 # the biggest bend the signal ordinarily takes
        seam = jump / bend                                              # <= 1 = seamless, > 1.5 = an audible tick
    clip = float((np.abs(x) >= 0.99).mean())
    dc = float(x.mean())
    # the score: hiss that stays on (flat + hf + a high floor), grit (clipping), ticks (a loop's seam, a DC step)
    noisy = min(1.0, flat * 1.25)                                  # a pure ring or a drone is tonal (flat ~ 0): bright, but not static
    bright = min(1.0, 0.4 + hf3 + 2.0 * hf6 + 4.0 * hf10)
    hiss = 100.0 * noisy * bright * (0.5 + 0.5 * min(1.0, max(0.0, (floor + 60.0) / 40.0)))
    hiss += 400.0 * clip + 12.0 * max(0.0, min(seam, 6.0) - 1.3) + 200.0 * abs(dc)
    return {"file": os.path.relpath(path, ROOT), "name": path.split("audio/")[-1] if "audio/" in path else os.path.basename(path), "dur": len(x) / sr, "peak": db(peak), "rms": db(rms), "clip": clip, "dc": dc, "low": low, "hf3": hf3, "hf6": hf6,
            "hf10": hf10, "flat": flat, "floor": floor, "seam": seam, "hiss": min(hiss, 100.0)}


# Third-party one-shots authored hot (Kenney's footsteps / impacts / door slams decode to +2 dBFS with a flat top): checked against a looser peak budget.
HOT_THIRD_PARTY = ("footsteps/", "impacts/impact", "doors/doorOpen")


def violations(r):
    """The budgets a shipped sound must stay inside. Returns a list of strings (empty = clean)."""
    bad = []
    name = r["name"]
    hot = any(k in name for k in HOT_THIRD_PARTY)
    if hot:
        if r["peak"] > 3.5 or r["clip"] > 0.012:
            bad.append("clips (peak %.1f dB, %.2f%% of samples at full scale)" % (r["peak"], r["clip"] * 100))
    elif r["peak"] > -0.5:
        bad.append("peak %.1f dBFS is over the -0.5 dBFS budget (two of these at once would clip the Master bus)" % r["peak"])
    if abs(r["dc"]) > 0.01:
        bad.append("DC offset %.4f (a thump at the start and end)" % r["dc"])
    if r["hf6"] > 0.20:
        bad.append("%.0f%% of its energy is above 6 kHz (hiss)" % (r["hf6"] * 100))
    if r["hf10"] > 0.03:
        bad.append("%.0f%% of its energy is above 10 kHz (fizz)" % (r["hf10"] * 100))
    if r["hiss"] > 60:
        bad.append("hiss score %.0f > 60 (noisy and bright)" % r["hiss"])
    if any(k in name for k in LOOPS) and r["seam"] > 4.0:
        bad.append("its loop point ticks (seam %.1f > 4)" % r["seam"])
    if name.startswith("music/"):
        if not (-26.0 <= r["rms"] <= -12.0):
            bad.append("music loudness %.1f dBFS RMS is outside -26..-12" % r["rms"])
        if r["low"] > 0.90:
            bad.append("%.0f%% of the music's energy is below 120 Hz (a rumble that vanishes on small speakers)" % (r["low"] * 100))
    return bad


def walk(args):
    for a in args:
        a = os.path.join(ROOT, a) if not os.path.isabs(a) else a
        if os.path.isfile(a):
            yield a
        else:
            for d, _dirs, files in os.walk(a):
                for fn in sorted(files):
                    if fn.endswith((".wav", ".ogg")):
                        yield os.path.join(d, fn)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    jpath = None
    if "--json" in sys.argv:
        jpath = sys.argv[sys.argv.index("--json") + 1]
        args = [a for a in args if a != jpath]
    rows = [r for r in (analyse(p) for p in walk(args or ["assets/audio"])) if r]
    if "--check" in sys.argv:
        failed = 0
        for r in rows:
            for v in violations(r):
                failed += 1
                print("AUDIO: %s — %s" % (r["name"], v))
        print("AUDIO: %d files audited, %d violations" % (len(rows), failed))
        sys.exit(1 if failed else 0)
    rows.sort(key=lambda r: -r["hiss"])
    print("%-46s %5s %6s %6s %6s %7s %5s %5s %5s %5s %5s %6s %5s %4s" % ("file", "dur", "peak", "rms", "clip%", "dc", "low", "hf3", "hf6", "hf10", "flat", "floor", "seam", "HISS"))
    for r in rows:
        print("%-46s %5.1f %6.1f %6.1f %6.2f %7.4f %5.2f %5.2f %5.2f %5.2f %5.2f %6.1f %5.2f %4.0f" % (
            r["name"], r["dur"], r["peak"], r["rms"], r["clip"] * 100, r["dc"], r["low"], r["hf3"], r["hf6"], r["hf10"], r["flat"],
            r["floor"], r["seam"], r["hiss"]))
    if jpath:
        with open(jpath, "w") as fh:
            json.dump(rows, fh, indent=1)


if __name__ == "__main__":
    main()
