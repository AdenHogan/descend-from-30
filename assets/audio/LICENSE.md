# Audio asset licenses

- `footsteps/`, `impacts/`, `doors/` — from Kenney's "Impact Sounds" and
  "RPG Audio" packs (https://kenney.nl/assets). **CC0 / public domain.**
- `zombie/moan_*.wav`, `gunshot.wav`, `heartbeat.wav` — procedurally
  synthesized placeholders made for this project (the moans were low-passed and trimmed to -2.5 dBFS in round 46 by `tools/audio_clean.py`). **CC0.** Replace with
  recorded SFX when the real audio pass happens (see docs/SOUND_STEALTH.md
  open tasks).
- `music/dread_loop.ogg`, `music/breach_loop.ogg` — procedurally composed in code (`tools/gen_music.py`, round 46; sines and band-limited saws, no
  samples): the 32 s exploration bed (Em, 60 BPM, drone / pad / FM bells / wind, stereo, seamless) and the 27 s breach-room track (140 BPM, kick + sidechained
  sub + 16th-note ostinato + dissonant stabs + riser, stereo, seamless) made for this project. **CC0.** Replace with a real score later. (The first
  placeholder `dread_loop.ogg` — a loud mono wall — is in git history before round 46.)
- `ambience/thunder_*.wav`, `ambience/rain_loop.wav` — procedurally
  generated night-storm ambience for apartment windows (rolling thunder +
  a seamless rain loop) made for this project (`tools/gen_storm_audio.py`).
  **CC0.** Replace with recorded storm SFX later.
- `ambience/tv_static.wav`, `ambience/record_stuck.wav` — procedurally generated
  room ambience (a soft TV hiss; ten seconds of a lo-fi jazz record whose needle
  catches, scratches and jumps back) made for this project
  (`tools/gen_room_audio.py`). **CC0.**
- `impacts/glass_smash_*.wav` — procedurally generated glass smashes for thrown bottles (a crack, a
  bright noise burst and a cloud of decaying tinkles; `tools/gen_glass_audio.py`). **CC0.** Replace with
  a recorded smash later.
- `fire/*.wav` — procedurally generated fire audio for the Molotov and burning patches (a rag-in-the-air whoosh, the
  ignition FWOOMP, a body catching, a seamless crackling-fire loop, an extinguisher hiss; `tools/gen_fire_audio.py`). **CC0.**
  Replace with recorded fire later.
- `zombie/shuffle_*.wav` — procedurally generated zombie footfalls (a low thump, a band-passed noise drag,
  a wet creak on some; `tools/gen_zombie_steps.py`), played by `scripts/enemy_steps.gd`. **CC0.** Replace with
  recorded shuffles later.
- `cat/meow_*.wav`, `story/scream_far.wav`, `story/growl.wav` — procedurally generated placeholder cues for the four run openings
  and Vivianne's cat (three meows, a far scream muffled by distance, a stomach growl; source-filter synthesis,
  `tools/gen_story_audio.py`). **CC0.** Replace with recorded sounds later (docs/CHARACTER_STORIES.md).
- `room/*.wav` — procedurally generated sounds for searching a node (cloth rustle, paper crinkle, a ceramic / glass clink, a tin rattle, a drawer scraping out, a screen switching off, something tipping over and rolling; `tools/gen_node_audio.py`), played by `scripts/node_reaction.gd`. **CC0.** Replace with recorded foley later.

- **Round 46 clean-up (`docs/AUDIO.md`):** every generated sound above now comes from generators built on `tools/audiolib.py` (pink noise under a steep ceiling, soft-limited,
  faded); `doors/metalLatch.ogg` and `impacts/knifeSlice*.ogg` (Kenney, CC0) were low-passed at 6 kHz and trimmed to -3 dBFS by `tools/audio_clean.py` (a re-encode; the
  untouched originals are in git history). `tools/audio_audit.py --check` is part of the gate.
