#!/usr/bin/env python3
"""The game's two music tracks, composed in code (owner round 46: "take a look at our music… there's a lot of what feels like static and noise in
the audio. It needs cleaning. Maybe also create a more pulse pounding track too that fits horror themes for entering breach rooms").

  assets/audio/music/dread_loop.ogg   the exploration bed — 32 s, E minor, 60 BPM, STEREO, seamless. REPLACES the first placeholder (a loud mono wall,
                                       peak -1 dBFS, RMS -13, no dynamics, a tick at the loop point, a noise swell: the "static"). Now: a sub drone, a slow
                                       four-chord pad that never settles (Em9 -> C/E -> Am/E -> F/E: the flat-two over the drone is the dread), sparse FM
                                       bells that ping-pong into a dark hall, a bandpassed wind that breathes. NO white noise anywhere, nothing above ~9 kHz.
  assets/audio/music/breach_loop.ogg  the breach-room track — 16 bars at 140 BPM (27.4 s), seamless, built to POUND: a kick on every beat with a heartbeat
                                       "dub" riding the off-beats from bar 5, a sub bass sidechained to it (it ducks on every hit and swells back: the
                                       pulse you feel), a 16th-note E-minor ostinato with the flat-two (F) and the tritone in it, that opens its filter
                                       across the loop, dissonant string stabs, a screeching high pair from bar 9, a tonal riser through the last two bars
                                       that lands on the boom that starts the loop again. Every hit is a sine / saw — no noise bursts, so it is loud and
                                       tight but never static.

  assets/audio/music/breach_clear_loop.ogg  THE SAME SONG, WON (owner round 48l: "I love the breach room music, that almost techno type music. Keep it on longer and don't switch just
                                       because all enemies are defeated, or if you change it, turn that song into a sort of victory song when the room is clear"). Same 140 BPM,
                                       same 16-bar length and the same kick on every beat (so it can be started at the very beat the pulse is on — `Game` hands the play position
                                       across), but the dissonance is resolved: E minor -> C -> G -> D, a bright pad, a plucked arpeggio, an offbeat chord stab sidechained to the
                                       kick, a bell melody; no flat-two, no tritone, no screech. The arrangement is the SAME in every bar, so it can begin anywhere in the loop.
  assets/audio/music/victory_hit.ogg   the one-shot that lands as the last of them falls: a boom, a clang and a major chord thrown open, in a hall.

Everything is deterministic (seeded) and made from sines and band-limited saws (polyBLEP) — CC0, like the rest of assets/audio. Run:
    python3 tools/gen_music.py [--wav DIR] [--only dread,breach,victory]     (needs numpy + scipy + ffmpeg with libvorbis; --wav also keeps the 16-bit WAVs for inspection)
"""
import os
import subprocess
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "music")


# ------------------------------------------------------------------------------------------------------------------------ synthesis
def m2f(m):
    return 440.0 * 2.0 ** ((m - 69.0) / 12.0)


def tarr(n):
    return np.arange(n) / SR


def saw(freq, n, phase0=0.0):
    """A band-limited saw (polyBLEP), `freq` scalar or per-sample array."""
    d = np.broadcast_to(np.asarray(freq, dtype=float) / SR, (n,)).copy()
    ph = (np.cumsum(d) + phase0) % 1.0
    y = 2.0 * ph - 1.0
    m = ph < d
    tt = ph[m] / d[m]
    y[m] -= tt + tt - tt * tt - 1.0
    m = ph > 1.0 - d
    tt = (ph[m] - 1.0) / d[m]
    y[m] -= tt * tt + tt + tt + 1.0
    return y


def sine(freq, n, phase0=0.0):
    d = np.broadcast_to(np.asarray(freq, dtype=float) / SR, (n,))
    return np.sin(2.0 * np.pi * (np.cumsum(d) + phase0))


def sweep_lp(x, fc, block=512, order=2):
    """A low-pass whose cutoff moves (fc: scalar or per-sample), filtered block by block with the state carried over."""
    out = np.empty_like(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    zi = None
    for i in range(0, len(x), block):
        f = float(min(max(fc[i:i + block].mean(), 40.0), SR * 0.45))
        sos = signal.butter(order, f / (SR / 2.0), output="sos")
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out


def pan(x, p):
    """Mono -> (n, 2), equal-power pan p in [-1, 1]."""
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def put(buf, start, x):
    """Add a mono (n,) or stereo (n, 2) sound into stereo `buf` at sample `start` (clipped to the buffer)."""
    if start >= len(buf) or start + len(x) <= 0:
        return
    s0 = max(0, -start)
    i0 = max(0, start)
    n = min(len(x) - s0, len(buf) - i0)
    if x.ndim == 1:
        buf[i0:i0 + n, 0] += x[s0:s0 + n]
        buf[i0:i0 + n, 1] += x[s0:s0 + n]
    else:
        buf[i0:i0 + n] += x[s0:s0 + n]


def put_mono(arr, start, x):
    """Add a mono sound into the mono array `arr` (the reverb send) at `start`, clipped to it."""
    i0 = max(0, start)
    s0 = i0 - start
    n = min(len(x) - s0, len(arr) - i0)
    if n > 0:
        arr[i0:i0 + n] += x[s0:s0 + n]


def mix_wet(dry, wet, gain):
    """dry + gain * wet, as long as the longer of the two (a reverb tail runs past the end of the dry buffer)."""
    n = max(len(dry), len(wet))
    out = np.zeros((n, 2))
    out[:len(dry)] += dry
    out[:len(wet)] += wet * gain
    return out


def smooth_env(n, a, r):
    """A raised-cosine attack of `a` seconds and release of `r` seconds over n samples (a pad swelling in and out)."""
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na > 0:
        e[:na] = np.sin(np.linspace(0.0, np.pi / 2.0, na)) ** 2
    if nr > 0:
        e[-nr:] *= np.cos(np.linspace(0.0, np.pi / 2.0, nr)) ** 2
    return e


def fm_bell(f, dur, index=2.2, ratio=3.5):
    n = int(dur * SR)
    t = tarr(n)
    mod = np.sin(2.0 * np.pi * f * ratio * t) * index * np.exp(-t / 0.9)
    car = np.sin(2.0 * np.pi * f * t + mod)
    env = np.minimum(t / 0.004, 1.0) * np.exp(-t / (dur * 0.42))
    return car * env


def circ_filter(x, lo, hi, order=4):
    """High-pass at `lo` and low-pass at `hi` as a magnitude shape on the FFT of the WHOLE loop — circular, so it cannot disturb the seam."""
    out = np.empty_like(x)
    for c in range(x.shape[1]):
        spec = np.fft.rfft(x[:, c])
        f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1e-3)
        mag = 1.0 / np.sqrt(1.0 + (lo / f) ** 4) / np.sqrt(1.0 + (f / hi) ** (2 * order))
        out[:, c] = np.fft.irfft(spec * mag, len(x))
    return out


def fold(buf, n):
    """Fold everything past sample n (a reverb tail, a release) back over the start, so the loop is seamless AND the tail is not cut."""
    head = buf[:n].copy()
    rest = buf[n:]
    k = 0
    while k < len(rest):
        seg = rest[k:k + n]
        head[:len(seg)] += seg
        k += n
    return head


def reverb_stereo(send, ir_secs, seed, bands):
    """The mono `send` through a dark hall (a different impulse for left and right, so the tail is wide); returns (len(send) + tail, 2)."""
    irl = audiolib.schroeder_ir(SR, np.random.default_rng(seed), secs=ir_secs, bands=bands)
    irr = audiolib.schroeder_ir(SR, np.random.default_rng(seed + 1), secs=ir_secs, bands=bands)
    return np.stack([audiolib.reverb_full(send, SR, irl), audiolib.reverb_full(send, SR, irr)], axis=1)


def master(x, rms_db, peak_db):
    """Level by loudness with a soft ceiling: `ceiling * tanh(x / ceiling)` is unity for small signals and rounds the few highest peaks (the kick)
    instead of clipping them flat; the gain is trimmed until the loudness lands on `rms_db` WITH the limiting in place."""
    ceiling = 10.0 ** (peak_db / 20.0)
    target = 10.0 ** (rms_db / 20.0)
    g = target / (np.sqrt((x ** 2).mean()) + 1e-12)
    for _ in range(10):
        y = ceiling * np.tanh(x * g / ceiling)
        g *= target / (np.sqrt((y ** 2).mean()) + 1e-12)
    y = ceiling * np.tanh(x * g / ceiling)
    squash = audiolib.db(np.abs(x * g).max()) - audiolib.db(np.abs(y).max())
    print("  master: gain %.1f dB, the limiter takes %.1f dB off the highest peak" % (audiolib.db(g), squash))
    return y


def encode(path, x, wav_dir=None, name=""):
    pcm = np.clip(x, -1.0, 1.0).astype("<f4").tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "5", path],
                   input=pcm, check=True)
    if wav_dir:
        os.makedirs(wav_dir, exist_ok=True)
        import wave
        with wave.open(os.path.join(wav_dir, name + ".wav"), "w") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767.0).astype("<i2").tobytes())
    print("wrote %s  (%.1f s stereo, peak %.1f dB, rms %.1f dB)" % (os.path.relpath(path, ROOT), len(x) / SR, audiolib.db(np.abs(x).max()), audiolib.db(np.sqrt((x ** 2).mean()))))


# ------------------------------------------------------------------------------------------------------------------------ the dread loop
def dread_loop():
    rng = np.random.default_rng(4601)
    N = 32 * SR
    M = N + 7 * SR                                     # the tail room: pad releases + the hall's reverb, folded back over the head
    dry = np.zeros((M, 2))
    send = np.zeros(M)

    # 1. the DRONE — sines snapped to whole cycles per loop so it is periodic by construction; a slow breath of level
    t = tarr(N)
    drone = np.zeros(N)
    for f, g in ((41.2034, 1.0), (82.4069, 0.55), (123.61, 0.16)):
        fs = round(f * 32.0) / 32.0
        drone += g * np.sin(2.0 * np.pi * fs * t + 0.3)
    drone *= 0.78 + 0.22 * np.sin(2.0 * np.pi * t / 16.0 + 1.1) + 0.0 * t
    dry[:N] += pan(drone * 0.30, 0.0)

    # 2. the PAD — four chords of 8 s that never resolve; each note two saws a few cents apart, one in each ear, through a slowly breathing low-pass
    chords = [[52, 55, 59, 66],            # Em9 (no 3rd... the third IS there: G) — the room's home
              [48, 55, 59, 64],            # C(maj7) over the E drone
              [57, 60, 64, 71],            # Am(add9) over the E
              [53, 57, 60, 64]]            # F(maj7) over the E — the flat two against the drone: the dread
    for ci, ch in enumerate(chords):
        start = int(ci * 8.0 * SR) - int(0.4 * SR)
        n = int(11.2 * SR)
        te = tarr(n)
        for ni, m in enumerate(ch):
            for side, cents in ((-1, -7.0), (1, 6.0)):
                f = m2f(m) * 2.0 ** (cents / 1200.0)
                v = saw(f, n, phase0=float(rng.random()))
                v = sweep_lp(v, 420.0 + 200.0 * (0.5 + 0.5 * np.sin(2.0 * np.pi * (te + ni * 1.3 + ci * 2.0) / 16.0)) + m * 3.0)
                v *= smooth_env(n, 2.8, 3.4) * 0.095
                put(dry, start, pan(v, side * 0.7))
                put_mono(send, start, v * 0.5)

    # 3. the BELLS — a sparse, uneven motif: E, B, G, then the F that does not belong, answering itself in the echoes
    motif = [(2.0, 76), (6.9, 71), (11.5, 79), (15.7, 77), (19.4, 71), (24.0, 76), (27.3, 77), (30.2, 74)]
    for k, (when, midi) in enumerate(motif):
        b = fm_bell(m2f(midi), 5.5, index=1.9 + 0.5 * (k % 2)) * 0.125
        b = audiolib.lp(b, SR, 4500.0, order=2, zero_phase=False)
        side = -0.6 if k % 2 == 0 else 0.6
        s0 = int(when * SR)
        put(dry, s0, pan(b, side))
        for j, (dt, g) in enumerate(((0.5, 0.42), (1.0, 0.2), (1.5, 0.09))):        # a ping-pong echo, each repeat darker
            e = audiolib.lp(b, SR, 2600.0 / (1 + j), order=2, zero_phase=False) * g
            put(dry, s0 + int(dt * SR), pan(e, -side if j % 2 == 0 else side))
        put_mono(send, s0, b * 0.9)

    # 4. the WIND — pink noise held between 140 and 900 Hz (a low breath, nothing high enough to be static), swelling twice a loop; periodic noise = no seam
    for side in (-1, 1):
        w = audiolib.periodic_noise(N, rng, SR, lo=140.0, hi=900.0, tilt=0.8)
        swell = (0.5 + 0.5 * np.sin(2.0 * np.pi * (2.0 * t / 32.0) + (1.0 if side < 0 else 2.4))) ** 2
        dry[:N] += pan(w * swell * 0.085, side * 0.8)

    # 5. a distant THUD every eight seconds — felt more than heard
    for k in range(4):
        n = int(1.0 * SR)
        tt = tarr(n)
        th = np.sin(2.0 * np.pi * np.cumsum(38.0 + 22.0 * np.exp(-tt / 0.09)) / SR) * np.exp(-tt / 0.28) * 0.14
        put(dry, int((4.0 + 8.0 * k) * SR), pan(th, 0.0))
        put_mono(send, int((4.0 + 8.0 * k) * SR), th * 0.5)

    wet = reverb_stereo(send, 3.4, 77, ((60, 400, 4.2), (400, 2200, 2.6), (2200, 5200, 0.7)))
    loop = fold(mix_wet(dry, wet, 0.55), N)
    loop = circ_filter(loop, 28.0, 9000.0)
    return master(loop, -20.5, -3.0)


# ------------------------------------------------------------------------------------------------------------------------ the breach loop
def kick(amp=1.0, f0=46.0, drop=165.0, decay=0.15, dur=0.42):
    n = int(dur * SR)
    t = tarr(n)
    ph = 2.0 * np.pi * np.cumsum(f0 + drop * np.exp(-t / 0.018)) / SR
    body = np.tanh(1.7 * np.sin(ph)) * np.exp(-t / decay)
    click = np.sin(2.0 * np.pi * 1700.0 * t) * np.exp(-t / 0.0035) * 0.30       # a tonal tick for definition (never a noise burst)
    x = (body + click) * amp
    x[-int(0.02 * SR):] *= np.linspace(1.0, 0.0, int(0.02 * SR))
    return x


def breach_loop():
    rng = np.random.default_rng(1403)
    bpm = 140
    step = SR * 60 // bpm // 4                          # 4725 samples: a 16th
    bar = 16 * step
    N = 16 * bar
    M = N + 4 * SR
    dry = np.zeros((M, 2))
    send = np.zeros(M)
    duck_env = np.zeros(M)

    def kick_at(s, **kw):
        k = kick(**kw)
        put(dry, s, k)
        d = np.exp(-tarr(int(0.30 * SR)) / 0.11)
        n = min(len(d), M - s)
        duck_env[s:s + n] = np.maximum(duck_env[s:s + n], d[:n] * kw.get("amp", 1.0))

    # roots per bar (MIDI, octave 2): the room's home E, with the F (flat two) and the C / B underneath bringing the tension
    roots = [40, 40, 40, 40, 40, 40, 41, 40, 36, 36, 35, 35, 40, 40, 41, 41]

    # 1. the PULSE — a kick on every beat; from bar 5 a softer heartbeat "dub" rides the off-beat (a gallop); the last two bars double up
    for b in range(16):
        for beat in range(4):
            kick_at(b * bar + beat * 4 * step, amp=1.0 if beat != 0 else 1.1)
            if b >= 4:
                kick_at(b * bar + beat * 4 * step + 2 * step + step // 2, amp=0.42, f0=52.0, drop=120.0, decay=0.09, dur=0.25)
            if b >= 14 and beat in (1, 3):
                kick_at(b * bar + beat * 4 * step + 3 * step, amp=0.5, f0=50.0, drop=110.0, decay=0.08, dur=0.22)
    duck = 1.0 - 0.72 * np.clip(duck_env, 0.0, 1.0)

    # 2. the SUB — a sine (and a quiet triangle an octave up) on each bar's root, sidechained to the kick: it ducks on every hit and swells back
    sub = np.zeros(M)
    for b in range(16):
        f = m2f(roots[b] - 12)                                              # an octave under the ostinato's root
        n = bar + int(0.04 * SR)
        v = sine(f, n) + 0.30 * sine(f * 2.0, n, 0.2) + 0.18 * (2.0 / np.pi) * np.arcsin(np.sin(2.0 * np.pi * np.cumsum(np.full(n, f * 2.0)) / SR))
        v *= smooth_env(n, 0.02, 0.04)
        put_mono(sub, b * bar, v)
    dry += pan(sub * duck * 0.34, 0.0)

    # 3. the OSTINATO — the 16th-note engine. Offsets from the bar's root (semitones); a rest is None. The F (+1) and the tritone (+6) are in it.
    pattern = [0, None, 0, 0, None, 12, 0, None, 3, None, 0, 1, None, 0, 12, 6]
    for b in range(2, 16):                                                   # silent for the first two bars: the kick alone
        prog = min(1.0, max(0.0, (b - 4) / 11.0))                            # the filter opens across the loop
        for s, off in enumerate(pattern):
            if off is None:
                continue
            if b < 4 and s % 4:                                              # bars 3-4: only the downbeat figures, so it creeps in
                continue
            f = m2f(roots[b] + off)
            n = int(step * 0.92)
            te = tarr(n)
            osc = saw(f, n) + 0.9 * saw(f * 2.0 ** (9.0 / 1200.0), n, 0.37)
            dark = audiolib.lp(osc, SR, 520.0 + 380.0 * prog, order=2, zero_phase=False)
            bright = audiolib.lp(osc, SR, 3000.0 + 2200.0 * prog, order=2, zero_phase=False) * np.exp(-te / 0.04)
            note = (dark * 0.8 + bright * 1.5) * np.minimum(te / 0.002, 1.0) * np.exp(-te / 0.11)
            note *= 0.50 * (1.35 if s % 4 == 0 else 1.0)
            note[-int(0.004 * SR):] *= np.linspace(1.0, 0.0, int(0.004 * SR))
            at = b * bar + s * step
            d = duck[at:at + n] if at + n <= M else np.ones(n)
            put(dry, at, pan(note * d, 0.0))

    # 4. the PAD — a low minor cluster that swells under bars 1-8 (E, F, B: the flat two + the fifth), then the strings take over
    for b0, b1 in ((0, 8),):
        n = (b1 - b0) * bar + int(1.5 * SR)
        te = tarr(n)
        for m in (52, 53, 59):
            for side, cents in ((-1, -9.0), (1, 8.0)):
                v = saw(m2f(m) * 2.0 ** (cents / 1200.0), n, float(rng.random()))
                v = sweep_lp(v, 380.0 + 260.0 * (te / te[-1]))
                v *= smooth_env(n, 3.0, 1.4) * 0.085
                put(dry, b0 * bar, pan(v * duck[b0 * bar:b0 * bar + n] if b0 * bar + n <= M else v, side * 0.6))

    # 5. the SCREECH — from bar 9 a high pair (F5 / E5 beating against each other), vibrato, rising a semitone across the last four bars, bowed with a tremolo
    s0 = 8 * bar
    n = 8 * bar + int(0.8 * SR)
    te = tarr(n)
    for side, base in ((-0.65, 77.0), (0.65, 76.0)):
        glide = base + np.clip((te - 4 * bar / SR) / (4 * bar / SR), 0.0, 1.0) * 1.0
        vib = 1.0 + 0.0075 * np.sin(2.0 * np.pi * 5.6 * te + side)
        f = m2f(glide) * vib
        v = sweep_lp(saw(f, n, float(rng.random())), 1900.0 + 600.0 * np.clip(te / (8 * bar / SR), 0, 1))
        trem = 1.0 - 0.35 * np.clip((te - 4 * bar / SR) / 1.0, 0.0, 1.0) * (0.5 + 0.5 * np.sin(2.0 * np.pi * 11.0 * te))
        v *= trem * smooth_env(n, 1.2, 0.9) * 0.16
        put(dry, s0, pan(v, side))
        put_mono(send, s0, v * 0.5)

    # 6. the STABS — a dissonant cluster (E, F, B-flat, B) on the one of bars 9, 11, 13, 15 and a syncopated answer
    cluster = (64, 65, 70, 71)
    for b, hits in ((8, (0, 10)), (10, (0, 10)), (12, (0, 6, 10)), (14, (0, 6, 10, 14))):
        for s in hits:
            n = int(0.30 * SR)
            te = tarr(n)
            for i, m in enumerate(cluster):
                v = saw(m2f(m), n, float(rng.random())) + 0.8 * saw(m2f(m) * 2.0 ** (11.0 / 1200.0), n, float(rng.random()))
                v = audiolib.lp(v, SR, 2400.0, order=2, zero_phase=False) * np.exp(-te / 0.085) * np.minimum(te / 0.003, 1.0) * 0.16
                put(dry, b * bar + s * step, pan(v, -0.5 + i * 0.33))
                put_mono(send, b * bar + s * step, v * 0.7)

    # 7. the BOOM — at the top of the loop and again at bar 9: a falling sine + a low metallic clang (partials in inharmonic ratios, rolled off at 5 kHz)
    for b in (0, 8):
        n = int(2.2 * SR)
        te = tarr(n)
        boom = np.sin(2.0 * np.pi * np.cumsum(34.0 + 52.0 * np.exp(-te / 0.12)) / SR) * np.exp(-te / 0.75) * 0.9
        clang = np.zeros(n)
        for ratio, g, dec in ((1.0, 1.0, 1.0), (2.32, 0.7, 0.8), (4.17, 0.5, 0.55), (6.43, 0.35, 0.4), (9.1, 0.2, 0.3)):
            clang += g * np.sin(2.0 * np.pi * 196.0 * ratio * te) * np.exp(-te / dec)
        clang = audiolib.lp(clang, SR, 5000.0, order=2, zero_phase=False) * np.minimum(te / 0.002, 1.0) * 0.17
        put(dry, b * bar, boom)
        put(dry, b * bar, pan(clang, 0.2))
        put_mono(send, b * bar, clang * 1.2)

    # 8. the RISER — the last two bars: three saws sweeping up, a tremolo that quickens, a swell, cut clean at the loop point where the boom lands
    rs = 14 * bar
    n = 2 * bar
    te = tarr(n)
    prog = te / te[-1]
    f = 110.0 * (2000.0 / 110.0) ** prog
    r = np.zeros(n)
    for cents in (-11.0, 0.0, 12.0):
        r += saw(f * 2.0 ** (cents / 1200.0), n, float(rng.random()))
    r = sweep_lp(r, f * 1.6)
    rate = 5.0 + 14.0 * prog
    r *= (0.55 + 0.45 * np.sin(2.0 * np.pi * np.cumsum(rate) / SR)) * (0.04 + 0.96 * prog ** 2.2) * 0.22
    r[-int(0.03 * SR):] *= np.linspace(1.0, 0.0, int(0.03 * SR))
    put(dry, rs, pan(r, 0.0))
    put_mono(send, rs, r * 0.4)

    wet = reverb_stereo(send, 1.9, 91, ((60, 400, 1.8), (400, 2200, 1.1), (2200, 5200, 0.3)))
    loop = fold(mix_wet(dry, wet, 0.5), N)
    loop = circ_filter(loop, 30.0, 10000.0)
    return master(loop, -15.5, -1.5)


# ------------------------------------------------------------------------------------------------------------------------ the victory loop
def _tri(root, minor):
    """MIDI notes of a triad on `root`: root, third, fifth."""
    return [root, root + (3 if minor else 4), root + 7]


def victory_loop():
    rng = np.random.default_rng(2602)
    bpm = 140
    step = SR * 60 // bpm // 4                          # a 16th: exactly the breach loop's grid
    bar = 16 * step
    N = 16 * bar                                        # the same length as breach_loop, so the two can share a play position
    M = N + 4 * SR
    dry = np.zeros((M, 2))
    send = np.zeros(M)
    duck_env = np.zeros(M)

    def kick_at(s, **kw):
        k = kick(**kw)
        put(dry, s, k)
        d = np.exp(-tarr(int(0.30 * SR)) / 0.11)
        n = min(len(d), M - s)
        duck_env[s:s + n] = np.maximum(duck_env[s:s + n], d[:n] * kw.get("amp", 1.0))

    # E minor -> C -> G -> D, two bars each, twice over the 16 bars: i - VI - III - VII, the way a song turns when it has won
    prog = [(40, True), (36, False), (43, False), (38, False)] * 2          # (root MIDI at octave 2, minor?) per 2 bars
    chord_of_bar = [prog[b // 2] for b in range(16)]

    # 1. the PULSE — the same four-on-the-floor kick, lighter on the 2 and 4; the last beat of every 4th bar fills in 16ths
    for b in range(16):
        for beat in range(4):
            kick_at(b * bar + beat * 4 * step, amp=1.05 if beat == 0 else 0.92)
        if b % 4 == 3:
            for s16 in (13, 14, 15):
                kick_at(b * bar + s16 * step, amp=0.45, f0=52.0, drop=110.0, decay=0.08, dur=0.22)
    duck = 1.0 - 0.70 * np.clip(duck_env, 0.0, 1.0)

    # 2. the SUB — a sine on each bar's root an octave down, sidechained to the kick
    sub = np.zeros(M)
    for b in range(16):
        f = m2f(chord_of_bar[b][0] - 12)
        n = bar + int(0.04 * SR)
        v = sine(f, n) + 0.28 * sine(f * 2.0, n, 0.2)
        v *= smooth_env(n, 0.02, 0.04)
        put_mono(sub, b * bar, v)
    dry += pan(sub * duck * 0.36, 0.0)

    # 3. the OFFBEAT STAB — the "and" of every beat, a chord of saws through a closing filter: the bounce that keeps a techno track moving
    for b in range(16):
        root, minor = chord_of_bar[b]
        notes = [m + 24 for m in _tri(root, minor)] + [root + 36]
        for beat in range(4):
            at = b * bar + beat * 4 * step + 2 * step
            n = int(step * 1.6)
            te = tarr(n)
            for i, m in enumerate(notes):
                v = saw(m2f(m), n, float(rng.random())) + 0.7 * saw(m2f(m) * 2.0 ** (7.0 / 1200.0), n, float(rng.random()))
                v = audiolib.lp(v, SR, 2600.0, order=2, zero_phase=False) * np.exp(-te / 0.07) * np.minimum(te / 0.002, 1.0) * 0.085
                d = duck[at:at + n] if at + n <= M else np.ones(n)
                put(dry, at, pan(v * d, -0.45 + 0.3 * i))

    # 4. the ARPEGGIO — plucked saws, 16ths over the chord tones: up, up, down, up
    arp_pat = [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 1, 2, 3]
    for b in range(16):
        root, minor = chord_of_bar[b]
        tones = [m + 24 for m in _tri(root, minor)] + [root + 36]
        for s16, ti in enumerate(arp_pat):
            if s16 % 4 == 2:                                                 # the offbeat belongs to the stab
                continue
            f = m2f(tones[ti])
            n = int(step * 0.95)
            te = tarr(n)
            osc = saw(f, n) + 0.8 * saw(f * 2.0 ** (8.0 / 1200.0), n, 0.37)
            note = audiolib.lp(osc, SR, 3600.0, order=2, zero_phase=False) * np.exp(-te / 0.085) * np.minimum(te / 0.002, 1.0) * (0.21 if s16 % 4 == 0 else 0.15)
            note[-int(0.004 * SR):] *= np.linspace(1.0, 0.0, int(0.004 * SR))
            at = b * bar + s16 * step
            d = duck[at:at + n] if at + n <= M else np.ones(n)
            put(dry, at, pan(note * d, 0.0))

    # 5. the PAD — a bright triad swelling under every two bars, a saw pair a few cents apart in each ear
    for blk in range(8):
        root, minor = chord_of_bar[blk * 2]
        n = 2 * bar + int(0.9 * SR)
        te = tarr(n)
        for ni, m in enumerate([root + 12] + [x + 12 for x in _tri(root, minor)[1:]] + [root + 24]):
            for side, cents in ((-1, -8.0), (1, 7.0)):
                v = saw(m2f(m) * 2.0 ** (cents / 1200.0), n, float(rng.random()))
                v = sweep_lp(v, 1500.0 + 500.0 * np.sin(np.pi * te / te[-1]))
                v *= smooth_env(n, 0.5, 0.7) * 0.05
                put(dry, blk * 2 * bar, pan(v, side * 0.65))
                put_mono(send, blk * 2 * bar, v * 0.4)

    # 6. the MELODY — a bell on the chord's best notes: a figure that rises, hangs, and answers itself in the second bar of each chord
    for b in range(16):
        root, minor = chord_of_bar[b]
        third = root + (3 if minor else 4)
        figure = [(0, root + 36), (6, root + 31), (10, third + 36)] if b % 2 == 0 else [(2, root + 31), (8, third + 36), (12, root + 43)]      # bar 1 of a chord rises and hangs; bar 2 answers
        for s16, m in figure:
            bl = fm_bell(m2f(m), 2.6, index=1.5) * 0.085
            bl = audiolib.lp(bl, SR, 5200.0, order=2, zero_phase=False)
            at = b * bar + s16 * step
            put(dry, at, pan(bl, 0.4 if (b + s16) % 2 else -0.4))
            for j, (dt, g) in enumerate(((0.43, 0.4), (0.86, 0.18))):          # a dotted-eighth echo, each repeat darker
                e = audiolib.lp(bl, SR, 3200.0 / (1 + j), order=2, zero_phase=False) * g
                put(dry, at + int(dt * SR), pan(e, -0.4 if (b + s16) % 2 else 0.4))
            put_mono(send, at, bl * 0.7)

    # 7. the BOOM at the top of the loop and at bar 9, lighter than the pulse's
    for b in (0, 8):
        n = int(2.0 * SR)
        te = tarr(n)
        boom = np.sin(2.0 * np.pi * np.cumsum(36.0 + 46.0 * np.exp(-te / 0.12)) / SR) * np.exp(-te / 0.6) * 0.6
        put(dry, b * bar, boom)

    wet = reverb_stereo(send, 2.2, 53, ((60, 400, 1.4), (400, 2200, 1.0), (2200, 6000, 0.5)))
    loop = fold(mix_wet(dry, wet, 0.55), N)
    loop = circ_filter(loop, 30.0, 11000.0)
    return master(loop, -16.5, -1.5)


def victory_hit():
    """The last one falls: a boom, a clang and E major thrown open in a hall (2.8 s of hit and a 3 s hall tail; plays once over the hand-over from the pulse to the victory loop)."""
    rng = np.random.default_rng(2603)
    N = int(2.8 * SR)
    M = N + 3 * SR
    dry = np.zeros((M, 2))
    send = np.zeros(M)
    n = int(2.4 * SR)
    te = tarr(n)
    boom = np.sin(2.0 * np.pi * np.cumsum(34.0 + 58.0 * np.exp(-te / 0.12)) / SR) * np.exp(-te / 0.7) * 1.0
    put(dry, 0, boom)
    clang = np.zeros(n)
    for ratio, g, dec in ((1.0, 1.0, 1.0), (2.32, 0.7, 0.8), (4.17, 0.5, 0.55), (6.43, 0.35, 0.4)):
        clang += g * np.sin(2.0 * np.pi * 196.0 * ratio * te) * np.exp(-te / dec)
    clang = audiolib.lp(clang, SR, 5000.0, order=2, zero_phase=False) * np.minimum(te / 0.002, 1.0) * 0.16
    put(dry, 0, pan(clang, 0.2))
    put_mono(send, 0, clang * 1.2)
    for i, m in enumerate((52, 59, 64, 68, 71, 76)):                              # E3 B3 E4 G#4 B4 E5: open, major, certain
        v = saw(m2f(m), n, float(rng.random())) + 0.7 * saw(m2f(m) * 2.0 ** (9.0 / 1200.0), n, float(rng.random()))
        v = audiolib.lp(v, SR, 3400.0, order=2, zero_phase=False) * np.exp(-te / (0.9 - 0.05 * i)) * np.minimum(te / 0.004, 1.0) * 0.1
        put(dry, 0, pan(v, -0.6 + 0.24 * i))
        put_mono(send, 0, v * 0.8)
    wet = reverb_stereo(send, 2.6, 61, ((60, 400, 1.6), (400, 2200, 1.2), (2200, 6000, 0.5)))
    out = mix_wet(dry, wet, 0.6)[:M]
    out = circ_filter(out, 30.0, 11000.0)
    fade = int(0.35 * SR)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None]
    return master(out, -17.0, -1.5)


def main():
    wav_dir = sys.argv[sys.argv.index("--wav") + 1] if "--wav" in sys.argv else None
    only = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else {"dread", "breach", "victory"}
    os.makedirs(OUT, exist_ok=True)
    if "dread" in only:
        encode(os.path.join(OUT, "dread_loop.ogg"), dread_loop(), wav_dir, "dread_loop")
    if "breach" in only:
        encode(os.path.join(OUT, "breach_loop.ogg"), breach_loop(), wav_dir, "breach_loop")
    if "victory" in only:
        encode(os.path.join(OUT, "breach_clear_loop.ogg"), victory_loop(), wav_dir, "breach_clear_loop")
        encode(os.path.join(OUT, "victory_hit.ogg"), victory_hit(), wav_dir, "victory_hit")


if __name__ == "__main__":
    main()
