# Motion — ambient animation (owner round 26)

Owner: "we need to also look at motion. The idea of animations for certain items like the dripping milk
or flowers moving in the wind etc." Motion is what makes a still room read as a *place*. Rules of the
house: it costs gameplay nothing (never a collider, never blocks a click), it follows the building's
decay the way the lamps do (more, and worse, deeper and later), it is seeded per floor/room so it is
stable and no two things move in step, and it stays pixel art (whole-pixel steps, no smeared resampling).

## What already moves

| Where | What | How |
|---|---|---|
| Rooms | milk drip, IV drop, blinking LEDs/cursors, TV snow, the turning record, the struck TV, flies over the dead | `pixlib.anim` → a module scene's `Anims` → `scripts/module_anim.gd` (kinds `drip drop blink static spin flies tv`) |
| Rooms | lamps steady / flickering / cutting out, window light beams, night rain + lightning + thunder | `apartment_lights.gd`, `window_beam.gd`, `apartment_storm.gd` |
| Corridors | sconces steady / flicker / blink / dead / smashed, fire (sprites + soft smoke), door swing, barricade boards ripping off, lift doors | `floor_lighting.gd`, `fire_field.gd`, `door.gd`, `barricade_boards.gd` |
| UI | scavenge-node orbs bob, noise pings, stair pans, listen vignette | `interactable.gd`, `listen_overlay.gd`, `stair_pan.gd` |

## Built this round

* **Plants sway in the wind** (`scripts/sway.gd`). One canvas_item shader leans a sprite's upper part
  side to side, pinned at its foot, in **whole-texel steps** (so it stays crisp pixel art). Every standing
  corridor plant — floor planter, plant on a stand, dead planter — gets it (`corridor_decals.add_to`,
  live *and* pan backdrop). The texture is re-made with 4 transparent columns each side so a leaning frond
  isn't cut off, and the sprite moves left by the same 4 — where it stands doesn't change by a pixel. The
  wind rises through the day (`WIND_BY_RUN` 0.6 / 1.0 / 1.7: a morning draught, an afternoon wind, the night
  storm); the phase is seeded per plant so none move together. Knocked-over plants don't move (they're
  down). Per-sprite `ShaderMaterial` because GL Compatibility has no per-instance uniforms.
* **The EXIT sign follows the decay** (`scripts/exit_sign_fx.gd`). Steady on healthy floors, **stutters**
  on failing ones (three quick dropouts once a period), **dead** on the worst — a dark face over the baked
  sign and its small green light gone. One seeded roll per *floor* against a threshold that only rises with
  depth and run, so a sign that died in the morning is still dead at night. The sign carries a tight green
  `PointLight2D` — at night it is one of the few things still glowing.
* **The quick wheel and health ring** are motion too: the ring unfolds, the low-health pips pulse like a
  heartbeat (real time, so the beat holds while the wheel slows the game).

## Roadmap — what's next, cheapest first

Each needs art split out of the baked module/corridor PNGs (a moving thing can't live inside a still
image), except where noted.

1. **Flowers in a vase, potted plants and ferns in rooms** (dining C's tulips, the study's flowers in a
   jug, living A's fern and E's rubber plant, `furn.potted_plant`). Draw the plant as its own sprite in the
   art script (a `pixlib.anim(..., kind="sway", sprite=…)` variant), leave it out of the baked art, and let
   `module_anim.gd` place it with `Sway.apply`. The shader is done; this is art-pipeline work.
2. **Hanging things swing**: pendant lamps, the chandelier, hung towels/clothes, balloons tied to chairs
   (round 17). A `swing` kind — a pendulum about the fixture's top, damped, kicked when something loud
   happens nearby (a gunshot, a can) so the room *reacts*. The lamp's light rides with it.
3. **Curtains at windows** — a live sprite over each apartment wall window (`apartment_window.gd` already
   owns the window and its light beam): breathes with the wind, billows at night, torn/half-down later.
   This one is new art, not a split.
4. **Balcony**: washing line and clothes flapping, plants, a loose shutter. Same `Sway`, more wind.
5. **Corridor**: dripping pipes on the institutional floors (reuse `drip`, seeded at the baked pipe joints),
   a sparking smashed sconce (a spark burst every few seconds), notices whose corners flutter in a draught,
   litter that skitters along the floor on the worst nights, a door left ajar that creeps.
6. **Steam/vapour**: a cup of tea still steaming (dining C), a kettle, a bath — soft particles like the smoke.
7. **Characters**: idle breathing / a weight shift for the player and the merchant (art-dependent).

Sound pairs with most of these (a creak with the swinging lamp, a flutter with the curtain) — see
`module_anim.SOUNDS` for the distance-faded loop pattern.

## Testing

`tests/motion_test.gd`: the sway keeps every pixel where it was (only the added columns are new), the
plants stand exactly where the planner put them, knocked-over plants don't sway, the wind rises with the
run, and the exit sign never gets better through the day. The *look* (sway amplitude, the sign's stutter)
needs an in-editor / `tools/scene_capture.tscn` look — it can't be judged headless.


## Round 34 — sway rules (owner: "no reason whatsoever that it should be swaying… we just want some leaves, or cloths, or
things that might drape… and the pixel jump shouldn't be so extreme")
Only leafy / draping things move (`Sway.GROWTH` kinds hang / tuft / flower / fern / potted, `KINDS` plant_tall / plant_stand);
dead / dry / creeper / shrub / roots / moss / fungus are `pin: none` (still). The shear is whole-texel but capped (`MAX_STAND`
1.45 → at most ONE texel on a standing plant, `MAX_HANG` 2.45 on a hanging vine) and driven by slow GUSTS (`gust_at`: calm
most of the time, a breath now and then) instead of a constant wobble. Rooms: a houseplant needs a full-height clear wall run,
so none stands in front of furniture. Locked by `motion_test._test_gusts` + `growth_test`.
