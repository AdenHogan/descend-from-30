# Audio — how it is made, what "clean" means, the two music tracks

> **BUILT v1 (round 46).** The owner: *"There's a lot of what feels like static and noise in the audio. It needs cleaning. Maybe also create a more pulse
> pounding track too that fits horror themes for entering breach rooms."* Everything here is generated in code (CC0, `assets/audio/LICENSE.md`) except the
> Kenney footsteps / impacts / door slams. **None of it could be listened to in the cloud session — it was judged with numbers and spectrograms; the owner's
> ear is the real test** (see "What needs an ear").

## Why it hissed (measured, `tools/audio_audit.py`)

* **White noise through a one-pole filter.** White noise is equal energy per hertz, so the top octaves carried about half of each sound: the old rain loop,
  paper, taps, the radio, rustling, the extinguisher and the glass smashes were **40-56 % above 6 kHz and up to 23 % above 10 kHz** — that is "static". Nature's
  noise falls with pitch (pink, -3 dB/octave); the generators now use pink / brown noise under a steep (24 dB/oct) ceiling picked for what the thing is.
* **Everything was hot.** Zombie moans sat at **-0.2 dBFS** (RMS -10), three Kenney one-shots decoded to **+0.6…+3.7 dBFS**; a crowd's moans, a gunshot and a
  door slam at once summed past full scale on the Master bus and hard-**clipped** — a crackle on top of everything. There was no limiter anywhere.
* **The music was a loud mono wall** — peak -1 dBFS, RMS -13 dB, no dynamics (the quietest tenth only 6 dB under the loudest), a tick at the loop point, a noise
  swell. It had no generator in the repo.
* The rain loop was a constant -17 dB RMS white hiss under every night flat, with a cross-fade seam.

## The pipeline

| File | Does |
|---|---|
| `tools/audiolib.py` | the shared DSP (numpy + scipy): `pink` / `brown` noise with a ~20 Hz floor (no DC wander), `periodic_noise` (a band-limited noise that **loops exactly** — built in the frequency domain, so the end meets the start with no seam), zero-phase `lp` / `hp` / `bp`, `polish` (DC block + steep ceiling + soft limit + fades + level — the last step of every one-shot), `schroeder_ir` + FFT `reverb` (a dark hall: low / mid / short-lived high bands each with its own decay) |
| `tools/gen_node_audio.py`, `gen_storm_audio.py`, `gen_fire_audio.py`, `gen_glass_audio.py` | the generators, all moved onto `audiolib` (paper, rustle, tap, radio, roll, printer, needle, cistern, fridge, beanbag… got a per-sound **ceiling**: `CEILING` in gen_node_audio; rain is a pink wash + single drops + a roof drum; the fire loop is a roar *under* its crackle, levelled by loudness; the douse is a pink hiss over a soft low body; glass pings stop at 6.2 kHz and everything at 9 kHz) |
| `tools/audio_clean.py` | the files **no generator can remake**: the four moans (steep 3.6 kHz ceiling, peak -2.5 dB) and three bright Kenney one-shots (a latch, two knife slices: 6 kHz ceiling, peak -3 dB). **Idempotent** — a file already inside its budget is skipped. The originals are in git history (the commit before round 46). |
| `tools/gen_music.py` | the two music tracks (below), encoded to Ogg Vorbis |
| `tools/audio_audit.py` | the measuring tool and the **gate**: `python3 tools/audio_audit.py` prints peak / RMS / clip / DC / share of energy below 120 Hz and above 3 / 6 / 10 kHz / spectral flatness / loop-seam / a 0-100 hiss score for every file under `assets/audio`; `--check` fails on a budget (see `violations`: peak, DC, > 20 % above 6 kHz, > 3 % above 10 kHz, hiss > 60, a ticking loop point, music out of -26…-12 dB RMS or > 90 % sub). `tools/run_all_tests.sh` runs it ("audio quality"). **It decodes at the file's own sample rate** — a resampler rings at both ends of a file and shows a fake seam. |
| `Game._ensure_master_limiter` | an `AudioEffectLimiter` on Master (ceiling -1 dB, threshold -4 dB): summed peaks round off instead of clipping |

Before → after (the audit's own numbers; the whole old set fails the gate with 59 violations, the new set with none):

| sound | energy > 6 kHz | peak | RMS |
|---|---|---|---|
| rain loop | 49 % → 0 % | -7.8 → -12.2 dBFS | -16.8 → -23.1 |
| paper / tap / radio / rustle | 22-49 % → 0 % | | |
| extinguisher douse | 43 % → 0 % | | |
| glass smash | 52-56 % (23 % > 10 kHz) → 3-15 % (0 % > 10 kHz) | | |
| zombie moans | 0 % | -0.2 → -2.5 | -10 → -12.8 |
| latch / knife slices (Kenney) | 31-40 % → 2-4 % | +0.6…+3.7 → -3…-4 | |

Regenerate: `python3 tools/gen_node_audio.py && python3 tools/gen_storm_audio.py && python3 tools/gen_fire_audio.py && python3 tools/gen_glass_audio.py && python3 tools/audio_clean.py && python3 tools/gen_music.py`
(the thunder is unchanged — its generator is pure stdlib and was already clean). **Run `godot --headless --import` after regenerating** or the engine keeps the old imported stream.

## The music — `tools/gen_music.py` (sines + band-limited saws, no noise bursts; stereo 44.1 kHz; both loops seamless)

**`dread_loop.ogg` — the exploration bed (replaces the first placeholder).** 32 s, E minor, 60 BPM. A sub drone (sines snapped to whole cycles per loop so it is periodic by
construction), a slow four-chord pad that never settles — Em9 → C/E → Am/E → **F/E**, the flat-two over the drone being the dread — each note two saws a few cents apart,
one per ear, through a breathing low-pass; eight FM bells in an uneven motif (E B G **F** B E F D) with a darkening ping-pong echo into a dark-hall reverb; a pink-noise wind held
between 140 and 900 Hz; a distant thud every 8 s. Peak -8 dBFS, RMS -20.5, nothing above ~9 kHz, nothing to tick at the join (the tail of every release and the reverb is
**folded back over the head**, and the final EQ is circular).

**`breach_loop.ogg` — the breach-room track.** 16 bars at **140 BPM** (27.4 s). **A kick on every beat** (a falling sine with a tonal — not noise — tick) with a **heartbeat "dub"**
riding the off-beats from bar 5 and doubling up in the last two bars; a **sub bass sidechained to the kick** (it ducks on every hit and swells back — the pulse you feel); a
**16th-note E-minor ostinato** from bar 3 whose filter opens across the loop, with the **F (flat two)** and the **tritone** in the pattern; **dissonant string stabs** (E F B♭ B)
from bar 9; a **screeching high pair** (F5 against E5, vibrato, creeping up a semitone, a bowed tremolo in the last four bars); two **booms with a low metallic clang** (bars 1 and 9);
a **tonal riser** through the last two bars that lands on the boom that starts the loop again. Peak -3.5 dBFS, RMS -15.5 (about 6 dB hotter than the bed — it is meant to be felt).
The mix was rebalanced after the first render measured 99 % of its energy under 500 Hz (the ostinato / stabs / screech were ~25 dB too quiet); the gate keeps music under 90 % sub.

**`breach_clear_loop.ogg` + `victory_hit.ogg` — the same song, won (owner round 48l: *"I love the breach room music, that almost techno type music. Keep it on longer and don't switch just because all enemies
are defeated, or if you change it, turn that song into a sort of victory song when the room is clear"*).** Same **140 BPM, 16 bars, 27.43 s** and the **same four-on-the-floor kick** (lighter on 2 and 4, a 16th
fill into every fourth bar), so it can start on the very beat the pulse is on; but the dissonance is **resolved** — E minor → C → G → D, two bars each, twice over (i – VI – III – VII: the way a song turns when it has
won): a sub on each root sidechained to the kick, an **offbeat chord stab** (the techno bounce), a **plucked arpeggio** in 16ths, a bright pad swelling under each chord, a **bell melody** that rises and answers itself with a
dotted-eighth echo, two lighter booms. No flat-two, no tritone, no screech. The arrangement is the same in every bar, so it can begin anywhere in the loop. `victory_hit.ogg` is the one-shot that lands as the last
one falls — a boom, a clang and E major thrown open in a hall (5.8 s with its tail). Both are generated (`tools/gen_music.py --only victory`); the one-shot is named `victory_hit` so the audit judges it as a one-shot
(its tail is not a loop point). The gate's loop-seam / loudness / sub checks pass on both.

### How it plays — `Game` music moods

`scripts/game.gd`: a **Music bus** under Master, three loop players (`music_player` = the bed, `breach_player` = the pulse, `clear_player` = the won song) and a one-shot (`clear_hit_player`). A scene **claims** a mood
(`Game.music_claim(node, "breach")`) and releases it (`music_release(node)`); the newest claim wins, none = calm. A claim whose node is freed or out of the tree is dropped by `Game`
itself, so a scene change, a death or a quit **can never leave the pulse stuck on**. Cross-fades run on **real time** (not game time) and keep running through the pause menu: the pulse is **0.25 s in** (its first boom and beat land as the door opens), the bed **0.6 s out** to make room; each hands back slowly — **3.2 s** (`in` / `out` per mood in `MUSIC_MOODS`; tension drains). The bed is only **ducked** while the pulse plays (it keeps its place); the pulse starts from its first beat on each entry and stops
when it is silent. Levels: bed -10 dB, pulse -9 dB, won song -9 dB, hit -7 dB (`MUSIC_MOODS` / `CLEAR_HIT_DB`; the owner's dial).
**The pulse family (round 48l):** `breach` and `breach_clear` carry `"family": "pulse"` — one song in two states. Moving between them is a **hand-over**, not a fade through silence: the incoming loop starts at the very
beat the outgoing one is on (`_play_in_step` → `step_position`: the sibling's playback position, wrapped to the new loop's length), the two cross in `PULSE_HANDOVER` 0.45 s (both the rising and the falling), and
going from the fight to the win (`breach` → `breach_clear`, and only that) fires `victory_hit.ogg` once. Players start before any is stopped on a frame, so a sibling that falls silent on the very frame its twin
comes in is still found playing. Going back to the bed is as slow as ever (3.2 s each way).

`scripts/room.gd`: a live breach flat claims **breach** as the room is built (`_begin_breach_music`, only if something hostile is alive in it or an entrant is still due), and — polled every 0.5 s —
once the last of the dead in THAT flat is down and nobody is still due through the torn-out door (`breach_threat_alive`: the pack, its leader, a wall crawler, an entrant already in) it turns its claim to
**breach_clear** (the won song, with its hit). The won song then **stays on for `BREACH_WON_HOLD` 82 s — three turns of the loop** — before draining back to the bed (the old rule dropped the music half a second after
the last kill); someone arriving again (a late entrant, a riser) flips it straight back to the fight (`_breach_music_phase` `""` / `"fight"` / `"won"`). Leaving the flat ends it at once (`_exit_tree` releases).
Not played: a breach flat that **burned** (its pack burned with it), the pan backdrop, ordinary flats.

Locked by `tests/music_test.gd` (the limiter is exactly one and never stacks, the Music bus, both streams load / loop, claims — newest wins, a double claim is one, release, freed node, node out of the
tree, unknown mood refused, released **while paused**, the pulse restarts at its first beat — the hand-over: the won loop is a sibling of the pulse and the same length, it starts beside the pulse (`last_step_from`; a headless player has no real playback
position, so the wiring and the pure `step_position` are what is checked), one hit per win and none for a flip back to the fight, the pulse hand-over is fast and the way to the bed slow, a won claimant alone starts from the top
— and a real breach flat: claimed on entry, kept while the dead stand, **turned to the won song when they are gone, still on half the hold later, flipped back to the fight by a late arrival and won again, handed back
to the bed after the hold**, never stuck after the room is freed mid-fight, an ordinary flat stays on the bed); **mutation-checked** (no claim in the room, a claim check that ignores freed nodes, no limiter, no win hit,
no in-step start, a slow hand-over, and the old release-when-clear rule each fail it).

## What needs an ear (owner)

* Whether the breach track *feels* like pounding horror — tempo (140), how hard the kick / sub sit, the screech's pitch, the riser. The dials are all at the top of `breach_loop()` / `dread_loop()`.
* **The won song and its hit have not been LISTENED to** — judged by numbers and spectra only (RMS -16.5 / peak -4.4 dB, the gate's seam / sub checks pass): whether it reads as *victory* and still the same song, the 82 s hold, the hit's weight. Dials: `BREACH_WON_HOLD` (room.gd), `PULSE_HANDOVER` / `CLEAR_HIT_DB` / `MUSIC_MOODS` (game.gd), the progression + melody at the top of `victory_loop()`.
* The levels: `MUSIC_MOODS` (bed -10 dB, pulse -9 dB), the rain (`apartment_storm.gd`, -10 dB on a loop that is now 6 dB quieter), the moans (now 2.3 dB lower — `enemy_zombie_*` still play them at 0 / -2 dB).
* The cleaned sounds (paper, taps, the radio, the douse, glass): still crisp enough, or now dull? Each ceiling is one number in `CEILING` / `audio_clean.JOBS`.
* **Not changed:** the Kenney footsteps / impacts / door slams (their baked flat tops are not undoable — the Master limiter handles the sum), the thunder, the heartbeat, the meows / scream / growl, the siren, the TV hum, the record.
  Their audit numbers are clean; if one still grates it is a taste call, not a measurement.
* A true-peak / loudness (LUFS) pass and per-bus volume sliders in Settings are not built.
