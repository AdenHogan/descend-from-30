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

**The title is the logo (round 48n)** — see "The opening's title" at the end: the lettering fades in first, then the bloody handprint behind it.

After it fades to black the run carries on as before: the time card (MORNING / name / subtitle over the handprint) → the character's
line (over their own cue — round 37, docs/CHARACTER_STORIES.md) → the lockout (only Joe and Amina are locked out). A load then drops into the saved scene out of black (the cold open is never replayed on Continue).
A key **hurries** it: during the climb the clock runs 5× (it never cuts); once the title is up (or the climb is over, on the title-less
cut) the next key goes straight to the fade out. If any art is missing, a new game falls back to the old black title screen and a load
simply loads.

## Three looks, one building

| run | light | what has happened to the building and the city |
|---|---|---|
| 1 MORNING | clear sky, a low sun, crows | the calm before it: some broken / boarded windows, lamps on, a few people at their windows, a garden with trees, a small black cat running across it — **no HELP sheet, no smoke, no fire anywhere** (owner round 36f) |
| 2 AFTERNOON | violet → orange dusk, a big low sun | lamps on in the dusk, more glass broken, a SOS sheet too, a wrecked balcony, the doors barricaded with a chair and boards, one body on the lawn, a person running in fear across the garden, two towers burning, a wire sagging low |
| 3 NIGHT | stars, a moon, a blood-orange horizon, **rain + lightning + thunder** | wires down, the doors boarded behind a fridge, a breach blown through the wall at floor 8, the parapet knocked off, bodies and blood across the garden and its path, burnt bushes and fires in the grounds, five towers burning, no crows |

It is the SAME tower in all three: each window's state comes from its own seeded draw and the thresholds only shift up with the run, so a
window broken in the morning is still broken at dusk. (`opening_test` checks 99.5% of the face agrees across runs.)

**Round 36f (owner playtest):** HELP / SOS sheets and ALL fire (the burnt floors, smoke columns, street / tower fires) only from run 2 (`LOOK.helps` 0/2/3, `city_smokes` (0,0) in run 1, `_lay_burning` returns on run 1 — `burn_plan()` stays the fire sim's truth). **Cars** are real silhouettes now (`car_sprite`: sedan / hatch / van — profile polygon, glass, door seams, wheel arches, tyres, bumpers, lamps; states parked / wreck / burnt; one overturned on its roof), three on three separate wheel lines and the street lamp moved to x 270, so nothing clips into a car (the meta lists every car rect and `opening_test` checks none touches another or the lamp). **Windows** each carry their own look from their own seeded rng (glass tint, interior tone, reflection, five curtain styles, five kinds of light — warm / amber lamp pool / cool TV / white / rose — plants, shelves, lamps) — the same in every run. **Survivors**: some LIT windows hold a tiny animated person (`meta.scene.survivors`, drawn by `opening_exterior._Survivors` off the opening's clock: wave / pace / peer / sway; ~2 / 5 / 5 by run). **The city** is built from towers wide enough for their height (never slimmer than 1:4.2), each its own tone, tall ones stepped back. **Sound**: the noise-band wind is GONE (it read as loud static as the building pans) — a noise-free tonal `hum.wav` sits under it; the siren and the title swell are unchanged.

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
`--check` is in the gate. Sounds: `tools/gen_opening_audio.py` → `assets/audio/opening/` (a low tonal hum loop — no noise — a far siren, a dark swell for the
title; CC0, generated); night also uses the storm's thunder. `tools/opening_capture.tscn -- --run=3 --times=1.5,6,12` renders frames.

## Not done / owner's call

A music cue; a "press any key" hint; far shamblers in the street; the roof's detail doesn't change between runs; the windows' lit lamps
don't react to the lightning; each run's wording on the time card is still the placeholder. The LOOK has been checked in-engine under xvfb only.

**Round 36h (owner: "get rid of the road… an apartment community sort of garden with trees… too cold"):** the cars and the road are GONE
(`meta.cars` no longer exists). The foot of the tower is a communal GARDEN (`tools/art/opening.py draw_ground` / `draw_garden_objects`): mown
lawn with bands, a planting bed, a paved path opening toward the viewer, a hedge, flowers, oak / poplar / blossom trees (light from the upper
left, `tree()`), bushes, benches, planters, two lamp posts (x 112 / 176, clear of the doorway). A RUNNER crosses it (`meta.scene.runner`,
`opening_exterior._Runner`, a pure function of `t`): run 1 a small black CAT, run 2 a PERSON running in fear (the other way), run 3 none. Run 3
is the aftermath: 12 body spots with blood pools and dragged trails along the path, burnt bushes, fires. `opening_test` locks no road (no
asphalt grey on row 515), >=5 trees, bodies 0 / >=1 / >=8 by run, the runner kinds.

**Round 36j (owner: "the garden is front facing, the building having geometry looks strange… 2.5D… looming… a little fog in the afternoon… pixel rain, lightning, thunder at night… one tree grows in the path — build a small wall alongside both sides, plants and trees to the correct sides… more detail to the path"):**
- **The building is FLAT now** (no receding side wall, no pavement shadow of a box): a front-on facade with a crisp silhouette (`edge_light`: a dark hairline each side, a pale rim on the sunward edge). `scene_<run>.png` also carries a plain BACK LAWN under it.
- **The garden is its own PLANE** — `garden_<run>.png` (ground, path, walls, trees, bodies, litter; transparent above what stands) at parallax `GARDEN_P` 1.18 vs the building's 1.00 (wires 1.30). At camera 0 the two coincide exactly; on the climb the garden slides away faster, so the tower looms behind it. Its fires and the runner are children of the garden layer (`opening_exterior._decorate_garden`; meta `garden` = fires, runner, trees, bodies, bushes, `path`, `placed`).
- **The path**: setts along both edges, courses of slabs in running bond (each its own tone, a lit top edge, a dark joint, deepening toward the viewer), cracks, weeds in the joints, a worn middle, a drain grating, a cobbled gate threshold, fallen leaves (runs 1-2) / rain puddles (run 3). **Walls** run along both sides (ground rows 12-34): a shaded inner face on the left wall / lit on the right, a capstone ribbon, mortar courses, a shadow across the path from the left wall, piers at each end, wear by run. Rule enforced at BUILD time (`stand()` stops the build): trees, shrubs, planters, the bench and lamps stand on the LAWN, outside the walls — only dropped things and the dead lie on the path (`path_zone`; `opening_test._test_garden_plan` re-checks from the meta). The runner crosses in front of the gate piers (row +42).
- **Fog (afternoon only, `look.fog`)**: `fog_2.png` (behind the garden: a bank on the ground + thin ones up the tower) and `fogf_2.png` (a low veil in front), dithered four-level alpha, drifting sideways (`drift` px/s, two wrapped copies).
- **Night weather**: pixel rain in two depths on the 4 px grid (far dim + near bright) with ripples on the garden while it is on screen, a jagged pixel BOLT (`_Bolt`, re-rolled per strike, beside the tower) with a double flash, then the thunder as before.

## The title — a live hallway INSIDE the building (round 48g)

**Owner:** "I think it is double dipping. When we start a run we see the intro animation of the outside of the building with the pan up and title before the run begins… let's try live
scenes inside the building, hallways looking ominous, blinking lights, bloody walls, enemies shambling, darkness, etc. logo, play settings exit on the left side, cleanly, then press play have
the three profiles display on top of that live scene, so no longer a black screen behind profiles. Then when selecting it then moves to the outside building current transition."
(Round 48e put the logo on the Gemini painting; round 48f replaced the painting with this tower's own night exterior in a `title_mode` — reverted: it repeated the opening.)

So the sequence is: **title** (inside, the dark) → **PLAY** (the same hall, the three profile slots over it) → **pick a slot** (`Game.new_game` / `continue_game`) → **this document's exterior opening**, the pan up the outside.

`scenes/title_screen.tscn`: a dark `Fallback` layer (a title must always come up) → `Hall` (`scripts/title_hall.gd`) → `Profiles` (a CanvasLayer, 2) and `Menu` (the logo + Play / Settings / Exit in the LEFT column over a soft `LeftShade`).
The hall is built from the game's own pieces, never redrawn: floor 22's corridor art for the third night (the faded hotel: damask, a red runner, brass sconces), `CorridorDecals` with `HORROR_BOOST` 0.9
(blood, bullet bursts, handprints, a plain bicycle standing by the lamp…), five numbered doors, `FloorLighting`'s real sconces (seed 11: the three in view alive — one flickers, one is steady, one blinks — the two beyond dead),
a near-black `CanvasModulate`, and three standard dead (the real `enemy_zombie_standard` frames, borrowed from the scene without running its script; a stand / lurching walk / lunge state machine each, `_Dead`).
Live: a fade up from black, **blackouts** (every 9-21 s every lamp cuts out, flashes, cuts again, returns — `FloorLighting.set_power`) and a far moan now and then. **The camera is STILL** (owner round 48h: "we don't need the scene to move… it looks juddery" — a slow drift at whole-pixel steps stutters): it stands at `CAM_X` 566 for good,
and only the lamps, the dead and the fade move. It swaps in its own
seed + run while it builds and puts the player's back (so it is the same every launch whatever state is loaded).

**PLAY** does not change scene: `title_screen._open_profiles` adds `profile_select.tscn` with `embedded = true` to the `Profiles` layer — its backdrop becomes a see-through veil, the menu + logo step aside, and Back / Esc
(`back_requested`) close it with the hall still running. The profile scene on its own is unchanged (opaque; Back reloads the title). `tests/title_test.gd` locks all of it.
**Not done / owner's call:** the look and the moan are checked under xvfb frames only; the hall is one corridor (floor 22) — other sections / floors, a second camera angle, doors that open on a dark flat, dust in the lamp light and a distant door slam are easy additions; the shamblers walk the one lane (there is no depth to a side-on corridor);
the Gemini painting (`assets/Descend From 30 - Placeholder Title Screen.png`) is left in the repo, unreferenced.

## The opening's title — the logo, lettering first, then the hand (round 48n)

**Owner:** "during the opening animation transition up to the top of the building, the game title that appears needs to change to the logo too, no background just the text and hand, fade in text first, then fade in the hand behind it."

`scripts/opening_exterior.gd` no longer draws a pixel-font `Label`. Its `Title` node is a `Control` holding three `Sprite2D`s on ONE canvas (`LOGO_SCALE` 0.25 — 2400 px shown at 600 — centred on `LOGO_CENTRE` (576, 195), linear + mipmapped):
`TitleHand` (`assets/logo/logo_layer_hand_dark.png`, the print) → `TitleShadow` → `TitleText` (`logo_layer_text_dark.png`, the worn lettering with its strikes of blood). The two PNGs are `tools/art/logo.py`'s own layers (`render_layers`): put the second over the first and you have `logo_full_dark.png`
byte for byte (checked), and the gate (`logo.py --check`) holds both current. Nothing is behind the logo — no panel, no vignette on it, no box (`opening_test` checks the title holds only `Sprite2D`s).

**The timeline** (pure functions of `t`, like the rest): the title starts at `t_title_in` (74 % through the climb, as before); `text_alpha` fades the lettering in over `T_TEXT_FADE` 1.1 s (it settles `TEXT_RISE` 10 px); a held beat of `T_HAND_BEAT` 0.2 s with only the words; then
`hand_alpha` brings the print up behind them over `T_HAND_FADE` 1.6 s — all of it up (`t_title_up`) before the camera settles on the roof. The old `title_alpha` is now "how much of the title is up" (= the hand, the last part to land); `title_visible` is the group's own fade to black. A key during the title cuts to the
fade out, as it always did (the title may then be only partly up).

**Legibility:** cream lettering washed into the bright morning sky and its clouds (checked in all three runs), so the lettering casts a soft shadow made from its OWN shape (`SHADOW_SHADER_CODE`: the text texture's mipmaps, level 3 tight + level 5 wide, dark night-tint, dropped `SHADOW_DROP` 3 px). It sits over the hand and under the words, and fades in with the words. It is a shadow, not a background.
The afternoon and night skies read without it. The swell (5 s, peaks ~2.5 s in) still starts with the title, so its peak lands about when the hand does (judged from its envelope, not listened to).

**The menu** (round 48n): Play / Settings / Exit on the title screen are Aldrich too (the logo's DESCEND FROM face), so the menu matches the words rather than the 30.

Locked by `opening_test` (`_test_timeline`: text first, the hand only once the words are up, neither fades back, the beat, all up before the roof; `_test_logo_title`: the three sprites in order, only pictures, the logo's own textures, one canvas, registered at rest, the fade-in in the real node, on screen + centred + the lowest drip clear of the roof's gear;
`_test_overlay_flow`: both layers come fully up in the real cold open, words first), `tutorial_test`, `title_test` (menu font). The LOOK was judged from frames rendered under xvfb in all three runs (a montage of the fade-in included) — the owner's eye on a real monitor is the real test.

