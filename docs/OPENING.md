# The new-game opening

**Owner round 35:** "When a new game begins, I want a nice pixel art exterior image of our building, clouds in the sky, city
scape in the background. Camera pans up the building, then the title of the game, fade to black, then the run information."

**BUILT v1.** A new game (the first run only — runs 2/3 have no title screen) begins on `scripts/opening_exterior.gd`,
owned by the cold open (`intro_overlay.gd`, stage `"exterior"`):

1. fade in from black onto the **street** at morning — the tower's entrance under its canopy, a wrecked car, a streetlamp, a pole and
   wires with crows, the low sun between towers (1.4 s fade, 0.9 s still);
2. the **climb** (12.5 s, ease in-out): institutional concrete floors 1-10 → brick 11-20 → faded-hotel stone 21-30, past a burnt
   stretch with soot and smoke, a sheet hung out saying HELP, broken / boarded windows, a few lamps still on (one failing), to the
   roof (water tank, stair head, beacon, dish) with crows circling and clouds drifting;
3. the **title** comes up over the sky late in the climb (`T_TITLE_AT` 74%), holds 2.9 s;
4. the whole picture and the title **fade to black** (1.4 s) — and the overlay carries on exactly as before: the time card
   (MORNING / name / subtitle over the handprint) → the character's line → the lockout.

A key **hurries** it: during the climb the clock runs 5× (it never cuts); once the title is up the next key goes straight to the fade
out. `Transition.busy` still holds it back at the start. If any art is missing (`art_present()` / `load_ok`) or
`exterior_enabled = false`, the old black title screen plays instead — an opening must never strand a new game.

## The art — `tools/art/opening.py` → `assets/opening/`

Native 288x162 shown at 4x (the 1152x648 screen), as parallax layers the game slides at different rates (`opening_meta.json`
"layers"): `sky` 0.30 (dithered dawn gradient + sun), `far` 0.50 (pale skyline, a crane, a radio mast), `mid` 0.75 (towers with window
grids), `scene` 1.00 (the 30-floor building + entrance + street), `fore` 1.30 (pole, wires, crows), and a `clouds.png` atlas the game
places and drifts (`"clouds"`: x, y at camera 0, parallax, drift). The building's three sections echo the corridors inside it
(`section(n)` — hotel 21+, brick 11-20, concrete 1-10) and decay with depth; **floor 30 keeps one warm window** (where you wake).
Window smoke points, the lit windows (for flicker), beacons and the lamp are listed in the meta in each layer's own pixels.
`python3 tools/art/opening.py --preview` writes `docs/art_reference/opening.png` (composites at five camera heights);
`--check` is in the gate (stale files fail it). Sounds: `tools/gen_opening_audio.py` → `assets/audio/opening/` (wind loop under the
whole shot, a siren far off mid-climb, a dark swell as the title lands; CC0, generated).

## Not done / owner's call

Run 2/3 openings (afternoon / night exteriors — the layers are all run-1 morning; the city art already has dusk/night looks in
`tools/art/cityscape.py`); a music cue; a "press any key" hint; the street has no zombies in it (a few far shamblers would sell it).
The LOOK has been checked in-engine under xvfb only.
