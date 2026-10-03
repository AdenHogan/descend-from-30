# The opening

**Owner round 35:** "When a new game begins, I want a nice pixel art exterior image of our building, clouds in the sky, city
scape in the background. Camera pans up the building, then the title of the game, fade to black, then the run information."
**Round 35b:** "Obviously three versions for different run times. Because a player loading a file might be on a run 2 or 3
save file. That exterior can also be used to show more damage and disaster outside."

**BUILT v2.** `scripts/opening_exterior.gd` plays the shot; three things start it:

| when | owner | title | length |
|---|---|---|---|
| a NEW GAME (run 1's cold open) | `intro_overlay` stage `"exterior"` | yes | ~19 s |
| a LATER run's cold open (after a death / an escape) | `intro_overlay` stage `"exterior"` | no | ~13 s |
| a LOAD (Continue) — the save's own run | `Game.continue_game` → `opening_sequence.gd` | yes | ~19 s |

After it fades to black the run carries on as before: the time card (MORNING / name / subtitle over the handprint) → the character's
line → the lockout. A load then drops into the saved scene out of black (the cold open is never replayed on Continue).
A key **hurries** it: during the climb the clock runs 5× (it never cuts); once the title is up (or the climb is over, on the title-less
cut) the next key goes straight to the fade out. If any art is missing, a new game falls back to the old black title screen and a load
simply loads.

## Three looks, one building

| run | light | what has happened to the building and the city |
|---|---|---|
| 1 MORNING | clear sky, a low sun, crows | a few smoke columns, some broken / boarded windows, one HELP sheet, lamps still on |
| 2 AFTERNOON | violet → orange dusk, a big low sun | lamps on in the dusk, more glass broken, a SOS sheet too, a wrecked balcony, the doors barricaded with a chair and boards, an overturned car, bodies in the street, a burning car, two towers burning, a wire sagging low |
| 3 NIGHT | stars, a moon, a blood-orange horizon, **rain + lightning + thunder** | wires down, the doors boarded behind a fridge, a breach blown through the wall at floor 8, the parapet knocked off, three fires in the street, five towers burning, bodies, no crows |

It is the SAME tower in all three: each window's state comes from its own seeded draw and the thresholds only shift up with the run, so a
window broken in the morning is still broken at dusk. (`opening_test` checks 99.5% of the face agrees across runs.)

### The burnt floors are this playthrough's own

They are not baked. `OpeningExterior.burn_plan()` asks the fire sim — `WorldState.fire_intensity(floor)`, the same stages that light the
corridors (an outbreak origin in run 1, climbing a floor and a stage per run: LIGHT → BLAZE → CHARRED) — and lays `burn.png`'s charred
windows and soot streaks on those floors: **LIGHT** 1-2 windows with a thread of smoke, **BLAZE** 3-5 windows with animated flames, a pulsing
glow and smoke, **CHARRED** 6-8 black windows with a last wisp. Which bays is seeded per floor. A fire the player put out for good
(`fire_dealt_with`) leaves the building clean. So a load on run 3 shows exactly the floors you will meet burning.

## The art — `tools/art/opening.py` → `assets/opening/`

Native 288x162 shown at 4x (the 1152x648 screen), as parallax layers the game slides at different rates: `sky_<run>` 0.30,
`far_<run>` 0.50 (pale skyline, a crane, a radio mast), `mid_<run>` 0.75, `scene_<run>` 1.00 (the 30-floor building, entrance, street),
`fore_<run>` 1.30 (pole, wires), `clouds_<run>` (an atlas the game places and drifts), `burn.png` (shared), and `opening_meta_<run>.json`
(layers, cloud placement, smoke points, lit windows, the window grid, beacons, street fires, the look's flags). The `LOOK` table holds each
run's palettes, sun / moon, grade and how much damage it adds. The building's three sections echo the corridors inside it (hotel 21+,
brick 11-20, concrete 1-10) and decay with depth; **floor 30 keeps one warm window** (where you wake).
`python3 tools/art/opening.py --preview` writes `docs/art_reference/opening.png` (one row per run, five camera heights);
`--check` is in the gate. Sounds: `tools/gen_opening_audio.py` → `assets/audio/opening/` (wind loop, a far siren, a dark swell for the
title; CC0, generated); night also uses the storm's thunder. `tools/opening_capture.tscn -- --run=3 --times=1.5,6,12` renders frames.

## Not done / owner's call

A music cue; a "press any key" hint; far shamblers in the street; the roof's detail doesn't change between runs; the windows' lit lamps
don't react to the lightning; each run's wording on the time card is still the placeholder. The LOOK has been checked in-engine under xvfb only.
