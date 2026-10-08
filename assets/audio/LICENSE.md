# Audio asset licenses

- `footsteps/`, `impacts/`, `doors/` — from Kenney's "Impact Sounds" and
  "RPG Audio" packs (https://kenney.nl/assets). **CC0 / public domain.**
- `zombie/moan_*.wav`, `gunshot.wav`, `heartbeat.wav` — procedurally
  synthesized placeholders made for this project. **CC0.** Replace with
  recorded SFX when the real audio pass happens (see docs/SOUND_STEALTH.md
  open tasks).
- `music/dread_loop.ogg` — procedurally composed placeholder background
  loop (32s, Em; drone pads / sub / echoing motif / noise swell) made for
  this project. **CC0.** Replace with a real score later.
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
