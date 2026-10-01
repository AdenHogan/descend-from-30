# Y-PLANE MAP — the locked floor reference

**This is the single source of truth for every Y plane on a corridor floor.**
All values are in world-space Y (down is +). They are either **read from code
constants** or **measured at runtime** (headless trace of collision bottoms /
sprite geometry) — never eyeballed. Before touching anything that positions or
slices an actor on the vertical axis, read this file. When you change a value in
code, update it here in the same commit.

Reference floor: `scenes/building_floors.tscn` (floors 1–29; the corridor is the
same geometry on every one). Lobby (0) and hallway (30) differ where noted — but their
TILEMAPS are now the same band as every corridor (Y **243 … 435**, 12 rows, X 115 … 1235):
the hallway's blue filler rows (435 … 483 and the top row) and the lobby's empty top rows
(243 … 275) are gone, so all three stack flush at a pitch of 192 in the stair pan (locked by
`transition_seam_test`). The lobby now has the corridor's end walls too (x ≈ 128 / 1224).

Corridor X span: **115 … 1235** (walls outside that).

---

## 1. The one true walking plane (FEET line)

There is exactly ONE line every actor's FEET rest on when standing on the
corridor floor. Measured (collision-bottom of the CollisionShape2D):

| Actor            | origin y (standing) | collision-bottom (FEET) |
|------------------|---------------------|-------------------------|
| Player           | ~386 (spawns 391)   | **419**                 |
| Standard zombie  | **370**             | **419**                 |
| Big zombie       | **374**             | **419**                 |
| Crawler / Long Arm / Spitter | **374**     | **419**                 |

- **FLOOR_FEET_Y = 419** — the floor line. Anything that should "stand on the
  floor" must have its collision-bottom here, NOT its origin.
- Origin ≠ feet. The offset differs by sprite/rig:
  - standard zombie collision-bottom = `origin + 49` → origin **370** ⇒ feet 419.
  - big zombie collision-bottom = `origin + 45` → origin **374** ⇒ feet 419
    (bigger capsule, DIFFERENT offset from the standard — measured; corridor
    scenery placement uses `building_floors.BIG_ZOMBIE_SETTLED_Y = 374`, never 370).
  - crawler / long-arm / spitter collision-bottom = `origin + 45` → origin **374**
    ⇒ feet 419 (all three sit on the same line as the big; their sprites' feet were
    measured at frame-row 79, scale 3 → offset 45). `building_floors.ENEMY_SETTLED_Y`
    holds the per-type origin (standard 370, every other rig 374) for scenery placement.
    NOTE: the crawler's box was made TALLER (60px, local pos y=15) so a push connects
    into the blank space above its low body — it grew UPWARD only, collision-bottom
    stays at `origin + 45` = 419, so this plane is unchanged.
  - player collision-bottom = `origin + 33` (capsule pos y=2 + half-height 31) → origin
    **386** ⇒ feet 419. The player is SPAWNED at origin 386 on every corridor scene
    (`building_floors.PLAYER_PLANE_Y`, `hallway`, `lobby`, `stair_pan` SPAWN_*), and
    `player._move_locked` pins Y so a crowd can never shove it off. HISTORY: spawns used to
    be 391 (stair) / 388 (door/elevator), which — because the pin freezes the SPAWN Y and
    never lets the floor settle it — left the player resting 2–5px BELOW 419, standing under
    the enemies with its legs poking beneath corpses. Measured + fixed; locked by
    `plane_lock_test` (`_test_player_feet_on_enemy_plane`).
- **DRAWN feet (owner round 33 — "corpse bodies are below the player y plane").** Collision feet are 419 for every rig,
  but the DRAWN feet were not: the player's art ends 1 px ABOVE its collision bottom (drawn 418), the enemy art 2-3 px
  BELOW (drawn 421-422) — so every standing zombie sat 3-4 px under the player and a corpse, all its mass on that bottom
  row, read as lying in FRONT of the floor. `scripts/enemy_feet.gd` (`EnemyFeet.lift_sprite`, called in the standard
  family's and the big's `_ready`) raises each enemy's SPRITE so its lowest Idle pixel sits at collision-bottom − 1 = the
  player's row: **drawn feet 418 in a corridor, 352 in a flat, alive or dead** (the Death frames end on the same row as
  Idle). Collision, origins and every number above are unchanged. Locked by `enemy_variety_test._test_drawn_feet_level`.
- **Never align two different rigs by their ORIGIN.** Matching origins puts a
  bigger rig's feet lower. Align by FEET (collision-bottom = 419). This is the
  bug that made the stair enemy sit 18px low.
- A static floor collider holds resting zombies at feet=419 (origin 370). A body
  that arrives BELOW the floor gets snapped up when its collision turns on — that
  snap reads as a "rubber-band." Emerge/spawn AT the resting origin to avoid it.

`base_walk_y` on a zombie is its home line; plane-pursuit may aim the origin at
the player, but the floor collider resolves feet back to 419.

**Player CORPSE (recoverable body, `player_corpse.gd`)** is placed by the dead character's
**FEET** — `player.feet_position()` (= origin + 33 → **419** in a corridor) — and drawn LYING
ON that line (every shape at local y ≤ 0; its detection circle is lifted to local y −20 so it
overlaps a standing player's capsule). HISTORY: v1 recorded the player's ORIGIN (386), so the
body floated ~27px above the floor. Records now carry `"feet": true`; an older record without
it is grounded on spawn by `WorldState.PLAYER_FEET_OFFSET` (33) so saved bodies are kept, not
lost. Locked by `corpse_recovery_test` (`_test_grounding`).

Apartment interiors (`room.tscn`): module ColorRect is 320×144 at instance y 224, so a
module spans world Y 224..368; the interior floor is Y 352. **Apartment FEET line = 353** (measured: every actor's collision-bottom once settled). Enemies spawn at origin 321 and physics-settle UP onto it — standard → origin **304**, big/crawler → **308**; the player stands at **320**. Anything placed WITHOUT physics (burnt corpses, a recorded body, a floor drop = 353 − REST_LIFT, frozen BalconyPan backdrop scenery) goes straight onto those settled lines (`room.ROOM_FEET_Y` / `ROOM_STD_ORIGIN_Y` / `ROOM_BIG_ORIGIN_Y`) — at 321 they sat ~17px sunk into the floor. (These are ROOM-LOCAL: the room scene's root sits at
(-1,-1), so global = local − 1.) **Breach-nest WALL CRAWLERS** (owner round 21, `enemy_zombie_crawler.
start_on_wall`) hang off the settled 308 line: on the back wall at 308 − 38..52 (body upright, ×0.85
for depth), on the ceiling at 308 − 70..76 (upside down); they drop and land ON 308 and are always
RECORDED at 308, never in the air. Scavenge anchors (Marker2D)
sit at module-local y 76..131 → world **~300..355** (furniture level). WALL WINDOWS
(`apartment_window.gd`, one per non-balcony module, seeded left/right) sit ON THE WALLPAPER
band of the module art: world Y **262** (`room.MODULE_WINDOW_Y`, module-local 38; pane + frame
span local ~10..66, under the crown moulding at 0..5 and above the chair rail at 70). History:
252 (forced gap, read jammed at the ceiling on the flat placeholder) → 284 (local 60 — once the
real module art landed it ran through the chair rail into the panelling and over the furniture,
owner round 9) → 262. Still ABOVE every scavenge node. Module art keeps the window boxes bare
(`tools/art/pixlib.py` WIN_L/WIN_R, checked on every generate). The balcony window light stays
at world Y 210. Per-module blueprints (every room plane, nodes, step-up spots, the player to scale):
`tools/gen_module_blueprint.py` → `docs/blueprints/` (the LOCKED room template; its README has the plane table).

Apartment PERSPECTIVE + SHELL (`module_walls.gd`, `room_shell.gd`, owner round 9): horizon
`VY` **224 = the ceiling line** (was 190: it tipped every wall top down into a heavy slab wedge —
"ceilings too low"); back wall top `TOP` 224, wall/floor seam `SEAM` **324**; depth scale
`s = (floor_y − 224) / 100`, so wall tops stay level on the ceiling and only the floor recedes. The
FRONT cut plane is floor y **360** (s 1.36); the walking lane (feet 353) is s 1.29. Interior
doorways (round 18: a STATIC frame straight on, `module_walls._door_frame`) — the jamb stands on the
floor at y **338** (the back of the opening, the saddle runs on from there), the head casing is
`HEAD_Y` **245..248**, clear of the tallest enemy's drawn top (spitter 257, big 260); the END walls'
lintel is still back-plane rows 0..17 (`DOOR_ROWS` 18, ≈247 at the lane). The FRONT DOOR spans floor
y 338..356. The room CAMERA BAND is **215..375** (`room.ROOM_BAND_TOP` 215 == `balcony_pan`'s copy,
checked): a 9px ceiling slab (215..224, plaster edge at its foot) and 7px of this flat's own floor in
section (368..375, boards on top) — stacked 160 apart in a balcony pan they make one slab. The
camera's horizontal limits are SOLVED so a pinned view shows only `SECTION_SHOW` 5px past each end
wall's cut, and the SOLID end walls + exit trigger sit where the drawn wall meets the floor at the
lane (`room.wall_foot_left/right` ≈ 78.9 / 1107.1 at 1152 wide) — the player stops at the wall they
see (was 112 / 1074, an invisible wall ~33px short). The stone TileMapLayer is hidden (no collision).

Actor DRAWN FEET (measured, `tools/measure_rigs.gd` per frame): player lowest opaque pixel = 352
(collision 353). Big / crawler / long-arm / spitter draw 3px BELOW their collision foot (355). The
standard's lowest rows are near-black boots that vanish on dark floors, so it read a boot higher
than everyone else; its sprite is dropped one art pixel (`offset.y = 1` × scale 3 → soles at 355),
matching the other enemy rigs.

BACK (scavenge) PLANE (`back_plane_spot.gd`): stepping up to set-back furniture puts the player's
FEET at **339** (`room.ROOM_FEET_Y` 353 − `BACK_PLANE_RISE` 14; origin 306) — ~15px IN FRONT of the
furniture's base (324): at 328 the player read as standing ON the bookshelf's bottom (owner round 9).
Sprite scale = the room perspective between the lines, s(339)/s(353) ≈ 0.89. No x movement up there; saves record the walking line.

THE BALCONY (owner round 14 — **`scripts/balcony_geo.gd` is the single source**; the art
`tools/art/balcony.py`, the player, `enemy_plane.gd`, `balcony_pan.gd`, enemy memory and the blueprints
all read it). A balcony is a LOGGIA behind a doorway in the back wall of a study / dining room (module
x 12..88 around the centre x +50), NOT a door drawn over the room:

| world | local | what |
|---:|---:|---|
| 244 | 20 | the doorway's LINTEL (`LINTEL_Y`) |
| 288 | 64 | the HANDRAIL (`RAIL_TOP_Y`) — actors on it are drawn × 0.67 (`RAIL_SCALE`) |
| 310 | 86 | the far edge of the balcony floor, the rail's base (`EDGE_Y`) |
| **319** | 95 | **BALCONY FEET** (`FEET`) — player + enemies out there, drawn × **0.74** (`SCALE` = 95/129) |
| 324 | 100 | the doorway's SILL = the room's wall/floor seam (`THRESHOLD_Y`) |

`RISE` = 353 − 319 = **34** (player origin 320 → 286; standard origin 304 → 270, big 308 → 274).
Half-width **26** either side of the centre. The player's sprite shrinks about its FEET
(`player._set_plane_depth`) so the DRAWN feet stay on 319 (scaling about the origin floated them 9px).
The DESCENT SLICE (`balcony_pan.gd`): hop onto the handrail (origin 255), then the sprite is clipped
from **288** (the upper handrail — they sink behind the railing) down to **404** (160 + the lower
doorway's lintel — they reappear at the top of the lower doorway), drop to the lower handrail (origin
415), hop over it onto the lower balcony (origin 446). The rope is clipped by the same band. (Before
round 14: a placeholder door drawn over the room, feet 328, scale 0.88, slice 272..402.)

---

## 2. Spawn / arrival planes (`building_floors.gd`, `stair_pan.gd` — must match)

| Const                 | value          | meaning                                  |
|-----------------------|----------------|------------------------------------------|
| `SPAWN_LEFT_TOP`      | (148, **386**) | left stair arrival, came from below (up) |
| `SPAWN_LEFT_BOTTOM`   | (188, **386**) | left stair arrival, came from above (dn) |
| `SPAWN_RIGHT_TOP`     | (1201, **386**)| right stair arrival (up)                 |
| `SPAWN_RIGHT_BOTTOM`  | (1162, **386**)| right stair arrival (dn)                 |
| `CORRIDOR_PLANE_Y` / `PLAYER_PLANE_Y` | **386** | player spawn/walk origin (feet 419) |
| zombie seed y         | 388 (KEY only) | the seed's y stays in spawn keys so saved kills match — never a position |
| zombie SPAWN position | **370 / 374**  | each rig's own settled origin (`ENEMY_SETTLED_Y`: standard 370, big/crawler/long-arm/spitter 374) — feet on 419 from FRAME 0 |

(This table read 391/388 until the sweep that re-measured it — those were stale.) **Enemies
spawn STANDING on their line** (corridor, lobby, corridor boss, Floor 30 tutorial zombie, the
listen-ambush spawn): spawning at 388 and waiting for physics to lift them showed them 18px sunk
on any paused/first frame (the owner saw it in the lobby). Locked by
`building_floors_test._test_enemies_stand_on_the_line_frame_zero` (physics paused; every standing
enemy's feet == 419). The player origin 386 is NOT an enemy value — each rig uses its own.

---

## 3. Stair TRIGGERS (the authoritative stair-centre X, y=391)

The player snaps to the trigger X when using stairs, so it is the true "middle
of the staircase" — use it for placement, NOT the art texture centre.

| Trigger                     | position     |
|-----------------------------|--------------|
| `stair_left_down_trigger`   | (148, 391)   |
| `stair_left_up_trigger`     | (188, 391)   |
| `stair_right_down_trigger`  | (1202, 391)  |
| `stair_right_up_trigger`    | (1162, 391)  |

`SHAFT_BLOCK_HALF_WIDTH` = 52 (stairwell.gd) — a zombie within ±52 X of the
trigger counts as "on the steps" for the crossing lock.

---

## 4. Staircase ART boxes (measured from the visible sprite)

Sprites: `HallwayStaircase{Left,Right}` (DOWN: the dark way down + a banister over the open well) and `Lobby{Left,Right}`
(UP, visible yellow steps). Pixel art from `tools/art/stairwell.py`: texture **80×144 at scale 1**, centred at
(171, **334**) / (1179, 334). It fills the WHOLE stair opening, from just under the corridor's lintel down to the
floor (owner round 31e — the corridor art's filler band used to show above a shorter 80×115 sprite):

- **Left**:  x [131, 211], y [**262**, 406], centre x 171.
- **Right**: mirror about corridor centre (675) → centre x 1179.
- Art **top edge** y = **262** (the lintel is 257..261); art **bottom** y = **406**.
- The art is DESIGNED on rows 0..114 = world 291..405 (stairwell.py `EXT` = 29 rows above that); the yellow
  up-steps' top / the stair-back line is design row 40 = world 331 (round 31f: the flight climbs halfway up the opening; the turn heights follow it); the DOWN half-wall's capping-rail top is design
  row 66 = world **357** (`stair_pan.VAULT_RAIL_TOP`; was 76 / 367 until owner round 31h raised the wall).
- **Banister vault** (`stairwell.vault_banister`, `stair_pan._vault`): the banister zone is centred 40px from the
  DOWN trigger toward the corridor (x 188 left / 1162 right) — exactly the floor below's stair-arrival x. The
  player steps up 10, climbs to feet 357 (origin 324) on the half-wall's cap, hops 6 and falls; the slice shader
  hides every pixel in the band `stair_pan.vault_gap` = [357, 262 + one floor] (the cap down to the floor below's
  opening top), so they drop behind the wall and out of the lintel below feet first, landing on origin 386 (+ one floor).
- Owner-confirmed DOWN dark-shaft inner box (fire): centre 146, half-width 26 →
  x [120, 172] (left); right mirror centre 1203. Broader stair zone kept clear
  of corridor fire: x [100, 235] (left) / [1114, 1249] (right).

---

## 5. Stair TRANSITION (player, `stair_pan.gd`) — the slice geometry

All relative to a floor's standing line. DOWN and UP are separate on purpose.

| Const                 | value | role                                             |
|-----------------------|-------|--------------------------------------------------|
| `DOWN_STAIR_APPROACH` | 10    | red line: how far above the stand line stairs start |
| `UP_STAIR_APPROACH`   | 10    | same, ascent                                     |
| `DOWN_TURN_HEIGHT`    | 88    | dog-leg bend height above the lower floor line = the top yellow step (world 331; was 72 before round 31f raised the flight) |
| `UP_TURN_HEIGHT`      | 88    | same, ascent                                     |
| `SHRED_TOP`           | 52    | player sprite extent above origin                |
| `SHRED_BOTTOM`        | 40    | player sprite extent below origin                |
| `DOWN_SHRED_FOOT`     | 20    | cut below the red line (descent feet-first slice)|
| `UP_SHRED_FOOT`       | 14    | cut below the red line (ascent)                  |
| `UP_SHAFT_TOP`        | 44    | above the stand line where the UP opening ends   |
| `DOWN_DEPTH_SCALE`    | 0.82  | sprite scale at the back of the shaft            |
| `UP_DEPTH_SCALE`      | 0.82  | same                                             |
| `STEP_HEIGHT`         | 16    | one stair step (pixels) — the stagger unit       |

These are calibrated for the **48px player sprite**. Do NOT reuse the pixel
offsets (20/14/52/40) verbatim on a differently-sized rig — reuse the SHADER and
the *idea*, but anchor the numbers to that rig's own feet line (see §6).

Camera / framing: `FLOOR_BAND_TOP` 243, `FLOOR_BAND_H` 192, `HUD_BAR_H` **0** (owner round 26c: there is no bottom bar any more — the
floor band fills the whole 648px screen, zoom 648/192 = 3.375 in a corridor; it was 120 / zoom 2.75 while an opaque strip sat at y 528+).
So the collision feet line 419 lands at screen y ≈ 594, and the drawn feet a little higher (sprite framing); below it lies ~50px of
foreground floor (drops and corpses rest ON the 594 line, so keep big HUD panels off it; the small bottom-right notes/scrap text sits there).

---

## 6. Stairwell ENEMY (a standard zombie on the steps)

`building_floors.gd` (placement) + `enemy_zombie_standard.gd` (behaviour). Derives
from §1, NOT the player's spawn plane.

| Const / value             | value                    | meaning                                             |
|---------------------------|--------------------------|-----------------------------------------------------|
| `STAIR_STAND_Y`           | **370**                  | emerge/stand origin → feet on FLOOR_FEET_Y 419      |
| `STAIR_DOWN_CUT_DROP`     | 26 (→ cut_y **396**)     | DOWN-shaft slice line = `STAIR_DOWN_CUT_Y` 396 = the top of the yellow first step (stair art lip) = the player's descent cut; was a by-eye 30 (400), which drew the enemy over the step's face |
| `STAIR_STEP_CLEARANCE`    | 16                       | over_y = STAND_Y − this = **354** (clear the step)  |
| DOWN rest_y               | cut_y + [28,58] = 424–454| lurk below the plane in the dark shaft              |
| UP rest_y                 | `stair_up_rest(i, roll)` = STAND_Y − (roll 30..45 + i×18), never above **292** | stand up the visible steps; clamped so at the top of its bob its FEET stay on the top step (331) — `stair_up_rest_min` = 419 − 88 − 49 + 10 |
| UP top clip               | **262** (`STAIR_OPENING_TOP`) | nothing of an UP-flight enemy draws above the opening's top (the flight runs on behind the wall) — `shaft_top` in the shared slice shader, re-anchored through a pan |
| `STAIR_BOB_AMP`           | 10                       | idle drift band around rest_y                       |
| `STAIR_ACTIVATE_RANGE`    | 150                      | player X-distance that rouses it                    |
| `STAIR_REACT_MAX`         | 0.7                      | random rouse delay (0..this)                        |
| `STAIR_IDLE_SPEED`        | 9                        | idle shuffle speed                                  |
| `STAIR_RISE_SPEED`        | 24                       | climbing toward over_y                              |
| `STAIR_STEPDOWN_SPEED`    | 18                       | the final step DOWN onto the plane                  |
| `STAIR_DEPTH_SPAN`        | 44                       | how far off-plane counts as "fully in the shaft"    |

Emerge path: rest → **rise to over_y 354** (above the plane, clears the step) →
**stepdown to STAND_Y 370** (feet land on 419) → normal AI. DOWN shaft slices via
the mouth cut (396 — the top of the yellow step); UP stairwell is drawn whole (no feet cut), just depth-scaled, but clipped at the opening's top (262). Measured (round 31k, `stair_heights_test`): the player at the turn draws from **270** (under 262); three stacked UP enemies would reach 257 without the clip. The STAIRS signs (262..277) draw on their own layer z 2, in FRONT of every actor.
z 0 while in the shaft (behind the player), z 1 once stepped off.

---

## 7. FIRE planes (`fire_field.gd`, `building_floors.gd`)

| Const              | value             | meaning                                             |
|--------------------|-------------------|-----------------------------------------------------|
| `FIRE_BASE_Y`      | **426**           | floor line the corridor flames rise from (on the feet)|
| `BACK_SEAM_Y`      | 404 (= 426 − 22)  | wall/floor seam; the DEPTH fire bed sits here        |
| `STAIR_BASE_Y`     | **415**           | base of fire INSIDE the down-stairwell box (red line)|
| `CEILING_Y`        | 30                | top of corridor (smoke gathers)                     |
| `BARRICADE_FLOOR_Y`| **418**           | crate-pile prop grounds here (bottom row)           |
| wall extinguisher  | y **360**         | mounted kit prop (`add_world_drop("036",(929,360))`)|

Stair-fire boxes (`set_stair_fire(centre_x, half_w, keep_lo, keep_hi)`):
- left DOWN shaft:  (146, 26, 100, 235)
- right DOWN shaft: (1203, 26, 1114, 1249)

Corridor front fire bed target height ≈ feet-to-waist (26 LIGHT / 34 BLAZE) so it
laps the feet (~419), never buries the legs.

---

## 7b. LIGHTING planes (`floor_lighting.gd`, `fire_field.gd`, `player.gd`)

Real 2D lighting (PointLight2D). These Y's are DECORATIVE (light sources, not
collision planes) but live here so any move is measured, not eyeballed.

| Const / value        | value            | meaning                                          |
|----------------------|------------------|--------------------------------------------------|
| `LIGHT_Y` (lamps)    | **250**          | ceiling-lamp cone APEX (bulb) Y (`floor_lighting.gd`) |
| lamp X span          | 200 → 1150 (×6)  | `X_START`..`X_END`, `COUNT` evenly spaced         |
| cone cookie          | 192×384, apex-centred | downward spotlight; reaches ~`192×scale` px below the bulb |
| `STAIR_WINDOW_*_X`   | 171 / 1179       | stairwell window daylight X (left / right)        |
| `STAIR_WINDOW_Y`     | **300**          | stairwell window daylight Y                        |
| balcony window       | (LEFT_WALL_X + slot·320 + 90, 210) | apartment balcony daylight (`room.gd`) |
| fire light Y         | 392 (= 426 − 34) | fire PointLight2D rides `FIRE_BASE_Y − 34`        |
| player aura offset   | (0, −10)         | aura light offset from the player origin          |

---

## 8. Other X anchors (for completeness)

| Const/value        | X       | meaning                                    |
|--------------------|---------|--------------------------------------------|
| corridor centre    | ~675    | mirror axis for left/right                 |
| `MAINT_DOOR_X`     | 929     | maintenance door / old wall-extinguisher   |
| `ELEVATOR_X`       | 1029.5  | corridor elevator sprite                   |
| apartment doors    | 316,444,570,696,829 (see `.tscn`) | door art x |

---

## 8b. SIGNS (owner round 23, `floor_signs.gd` / `door_plate.gd`)

| What | Y (world) | Notes |
|---|---|---|
| Door number plate | door origin − 20 (≈ 342 on a corridor floor) | about ¾ up the door; x = door − 28 − plate width (left of the door, `door_plate.plate_rect`); barricade boards end ≤ 25 px from the door centre (`barricade_boards.MAX_REACH` 23 + a 2 px ragged end), short of it |
| STAIRS sign | 262 .. 277 | hung from the stair opening's top (259, corridor.py RECESS y 16) |
| FLOOR number | 281 .. 308 (a hanging run-3 sign swings down to ~325) | beside each stairwell, x 246 (left) / 1100 (right); kept clear: world 227..283 / 1065..1119, y 275..325 |
| Lift indicator | 296 .. 305 | over the lift doors (they start ~307), x 1030 |
| Wall sconce | 286 .. 310 (bulb 298) | the floor's light, between the doors: x 380 / 507 / 633 / 762 / 885 (`floor_lighting.SCONCE_X`; lobby `LOBBY_SCONCE_X`) — above floor 30's tutorial wall text (314+) |

The corridor generator keeps these spots free of baked damage (`tools/art/corridor.py SIGNS`) and the
per-floor decals keep off them too (`floor_signs.taken_local`) — keep the three in step.

## 9. FUTURE — placement grid overlay (AGREED, not built)

To end eyeballing for good: on request, generate a **dev grid overlay** so the
owner can read a position off-screen and hand back an exact X/Y (or a numbered
zone) to place an element — no more guessing.

Spec to build when asked:
- `scripts/grid_overlay.gd` — a `CanvasItem` (added to the live world at high z, or
  an autoload toggled per scene) that draws over the corridor in WORLD space.
- **Toggle** on a free dev key (F2 = hazards, F7 = tutorial, F8 = Godot stop — so
  use **F3** or F4; confirm free before wiring).
- **Grid**: fixed cell (default **32×32** world px) spanning the corridor extent —
  X **115 … 1235**, Y **243 … 435** (the solid floor band; extend down to 435+ for
  the feet/fire region if needed). Lines + faint fill.
- **Labels**: every cell shows a **zone number** (row-major, starting 1 at
  top-left) AND the cell's world centre (x,y). Axis rulers along the top/left print
  raw world X and Y every cell so the owner can give either a zone number or a raw
  coordinate. Mark the known planes from this doc (feet 419, stand 370, plane 391,
  art box, stair triggers) as coloured guide lines.
- **Mapping** (locked so a zone always resolves the same): with origin
  `GX0=115, GY0=243`, cell `C=32`, columns `NCOLS=ceil((1235-115)/C)=35`:
  `zone = row*NCOLS + col + 1` (0-indexed row/col, row-major);
  `col=(zone-1)%NCOLS`, `row=(zone-1)/NCOLS`;
  cell centre `x = GX0 + col*C + C/2`, `y = GY0 + row*C + C/2`.
  So "zone N" ⇄ a precise (x,y) with no interpretation. The owner can also just
  read the printed x/y off the ruler.
- Workflow: owner toggles the grid, names a zone (or an x/y, or "feet line at
  zone-column K"), I place the element at the mapped world coordinate. Measured,
  never eyeballed.

Keep this section as the contract; when the owner says "make the grid," build to it.

---

## The rule (why this file exists)

Repeated Y-plane mistakes came from (a) eyeballing instead of measuring, (b)
aligning different-sized rigs by origin instead of feet, and (c) reusing the
player's pixel offsets on the bigger zombie. **Measure (collision-bottom / a
headless trace), align by FEET = 419, and check this table first.** Update this
file whenever a Y constant changes.
