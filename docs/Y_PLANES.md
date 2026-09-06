# Y-PLANE MAP — the locked floor reference

**This is the single source of truth for every Y plane on a corridor floor.**
All values are in world-space Y (down is +). They are either **read from code
constants** or **measured at runtime** (headless trace of collision bottoms /
sprite geometry) — never eyeballed. Before touching anything that positions or
slices an actor on the vertical axis, read this file. When you change a value in
code, update it here in the same commit.

Reference floor: `scenes/building_floors.tscn` (floors 1–29; the corridor is the
same geometry on every one). Lobby (0) and hallway (30) differ where noted.

Corridor X span: **115 … 1235** (walls outside that).

---

## 1. The one true walking plane (FEET line)

There is exactly ONE line every actor's FEET rest on when standing on the
corridor floor. Measured (collision-bottom of the CollisionShape2D):

| Actor            | origin y (standing) | collision-bottom (FEET) |
|------------------|---------------------|-------------------------|
| Player           | ~386 (spawns 391)   | **419**                 |
| Standard zombie  | **370**             | **419**                 |
| Big zombie       | (uses zombie rig)   | **419**                 |

- **FLOOR_FEET_Y = 419** — the floor line. Anything that should "stand on the
  floor" must have its collision-bottom here, NOT its origin.
- Origin ≠ feet. The offset differs by sprite/rig:
  - standard zombie collision-bottom = `origin + 49` → origin **370** ⇒ feet 419.
  - player collision-bottom = `origin + 33` → origin **386** ⇒ feet 419.
- **Never align two different rigs by their ORIGIN.** Matching origins puts a
  bigger rig's feet lower. Align by FEET (collision-bottom = 419). This is the
  bug that made the stair enemy sit 18px low.
- A static floor collider holds resting zombies at feet=419 (origin 370). A body
  that arrives BELOW the floor gets snapped up when its collision turns on — that
  snap reads as a "rubber-band." Emerge/spawn AT the resting origin to avoid it.

`base_walk_y` on a zombie is its home line; plane-pursuit may aim the origin at
the player, but the floor collider resolves feet back to 419.

---

## 2. Spawn / arrival planes (`building_floors.gd`, `stair_pan.gd` — must match)

| Const                 | value          | meaning                                  |
|-----------------------|----------------|------------------------------------------|
| `SPAWN_LEFT_TOP`      | (148, **391**) | left stair arrival, came from below (up) |
| `SPAWN_LEFT_BOTTOM`   | (188, **391**) | left stair arrival, came from above (dn) |
| `SPAWN_RIGHT_TOP`     | (1201, **391**)| right stair arrival (up)                 |
| `SPAWN_RIGHT_BOTTOM`  | (1162, **391**)| right stair arrival (dn)                 |
| `CORRIDOR_PLANE_Y`    | **391**        | player spawn/walk plane (== SPAWN_*.y)   |
| normal zombie spawn y | **388**        | `_spawn_zombies` seeds origins here      |
| elevator/other spawn  | **388**        | `player.global_position.y = 388` fallback|

Note **391 is the player SPAWN origin, not the feet line.** Do not use 391 to
place a zombie on the floor — use origin 370 (feet 419).

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

Sprites: `HallwayStaircase{Left,Right}` (DOWN, dark shaft) and `Lobby{Left,Right}`
(UP, visible yellow steps). Texture 353×443; left scale ≈ (0.2259, 0.2590),
centred at ≈ (171, 348.6). World box (both arts ≈ identical):

- **Left**:  x [131, 211], y [291, 406], centre x ≈ 171.
- **Right**: mirror about corridor centre (675) → centre x ≈ 1179.
- Art **top edge** y ≈ **291**; art **bottom** y ≈ **406**.
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
| `DOWN_TURN_HEIGHT`    | 72    | dog-leg bend height above the lower floor line   |
| `UP_TURN_HEIGHT`      | 72    | same, ascent                                     |
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

Camera / framing: `FLOOR_BAND_TOP` 243, `FLOOR_BAND_H` 192, `HUD_BAR_H` 120.

---

## 6. Stairwell ENEMY (a standard zombie on the steps)

`building_floors.gd` (placement) + `enemy_zombie_standard.gd` (behaviour). Derives
from §1, NOT the player's spawn plane.

| Const / value             | value                    | meaning                                             |
|---------------------------|--------------------------|-----------------------------------------------------|
| `STAIR_STAND_Y`           | **370**                  | emerge/stand origin → feet on FLOOR_FEET_Y 419      |
| `STAIR_DOWN_CUT_DROP`     | 30 (→ cut_y **400**)     | DOWN-shaft slice line = STAND_Y + this; by-eye knob |
| `STAIR_STEP_CLEARANCE`    | 16                       | over_y = STAND_Y − this = **354** (clear the step)  |
| DOWN rest_y               | cut_y + [28,58] = 428–458| lurk below the plane in the dark shaft              |
| UP rest_y                 | STAND_Y − [30,55] = 315–340 | stand up the visible steps                       |
| `STAIR_BOB_AMP`           | 10                       | idle drift band around rest_y                       |
| `STAIR_ACTIVATE_RANGE`    | 150                      | player X-distance that rouses it                    |
| `STAIR_REACT_MAX`         | 0.7                      | random rouse delay (0..this)                        |
| `STAIR_IDLE_SPEED`        | 9                        | idle shuffle speed                                  |
| `STAIR_RISE_SPEED`        | 24                       | climbing toward over_y                              |
| `STAIR_STEPDOWN_SPEED`    | 18                       | the final step DOWN onto the plane                  |
| `STAIR_DEPTH_SPAN`        | 44                       | how far off-plane counts as "fully in the shaft"    |

Emerge path: rest → **rise to over_y 354** (above the plane, clears the step) →
**stepdown to STAND_Y 370** (feet land on 419) → normal AI. DOWN shaft slices via
the mouth cut (400); UP stairwell is drawn whole (no slice), just depth-scaled.
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

## 8. Other X anchors (for completeness)

| Const/value        | X       | meaning                                    |
|--------------------|---------|--------------------------------------------|
| corridor centre    | ~675    | mirror axis for left/right                 |
| `MAINT_DOOR_X`     | 929     | maintenance door / old wall-extinguisher   |
| `ELEVATOR_X`       | 1029.5  | corridor elevator sprite                   |
| apartment doors    | 316,444,570,696,829 (see `.tscn`) | door art x |

---

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
