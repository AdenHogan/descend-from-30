# Stairwell layering — why the descent looks wrong, and what to build

Status: **descent solved with a clip shader ("the shredder") — see below.** An
art overhaul is still wanted for LOOKS (the owner finds the stairwell ugly), but
it is no longer required to make the descent read correctly. Written up so the
next session does not repeat three rounds of wrong fixes.

## The shredder (implemented, stair_pan.gd)

A ShaderMaterial applied to the player sprite during the pan discards every
pixel below `cut_y` (world space). Descending through the stair line feeds the
player through it — feet first, sliced in staggered stages — with no z tricks,
no painted boxes, no tilemap hole. The cut reverses (sweeps down) during the
landing turn on the floor below, reassembling them to full form, and the last
flight is walked visibly. Tunables: STAIR_APPROACH (the red line height),
TURN_HEIGHT (bend height — the old halfway turn was far too high), SHRED_FOOT,
DEPTH_SCALE.

## The question that matters

> Is it physically impossible for the player to move behind the tilemap? Is the
> tilemap the furthest back layer?

**No, and no.** The player can be drawn behind the tilemap trivially —
`player.z_index = -1` does it, because the corridor tilemap sits at `z_index 0`
and actors at `z_index 1` (see CLAUDE.md render layers).

The real problem is different, and it is the thing that wasted three attempts:

> **The corridor tilemap is SOLID across all 70 columns of every row.**
> The stairwell "opening" is painted by `Hallway_Staircase_*.png` / `Lobby_*.png`
> **on top of** the tiles. There is no hole in the tilemap.

So putting the player behind the tilemap does not reveal them inside a
stairwell — it hides them completely, everywhere in the corridor. That is why:

- moving the z-flip **earlier** deleted the visible climb entirely, and
- moving it **later** left the player riding over the front of the scene.

There is no value of `z_index` that fixes this, because there is nothing to be
seen *through*. Colour-matched rectangles drawn over the floor (tried, rejected)
are a visible painted box, not a fix.

## What the descent should look like

Owner's spec, verbatim in intent:

1. player walks up to the stairs
2. player descends **staggered, step by step**, *behind* the scene, sliced away
   bit by bit as the floor edge passes over them
3. player continues down behind the scene to the **middle** of the staircase on
   the floor below
4. player moves **left or right** (depending on building side) — the landing turn
5. player descends the remaining staircase in the new position
6. player arrives, control returns, camera resumes following

Movement is **never diagonal**: vertical → horizontal → vertical. (The code side
of this is already correct — see `stair_pan.gd`; the only direct player position
tweens are the approach (Y) and the landing turn (X), everything else goes
through `_stagger_y`, which is Y-only.)

Screenshot note from the owner: the player currently turns **too high**. The turn
should happen roughly where the stairwell's dark upper section meets the top of
the yellow steps — not up at the window.

## What needs building

The stairwell must become **three layers with a real hole**, not one flat sprite:

| layer | z_index | contents |
|---|---|---|
| **Back** | 0 (or below) | the stairwell interior — the dark shaft and the steps receding away |
| **Player** | 1 | walks *inside* the shaft |
| **Front** | 2 | the near wall / floor edge / banister that the player sinks behind |

And critically:

- **Cut a hole in the tilemap** at each stairwell column so the back layer is
  visible. The tile cells behind the stairwell must be erased, not painted over.
  (`StairPan.strip_junk_rows` already shows the pattern for editing
  `tile_map_data` safely — decode, edit cells, re-encode; do NOT re-pack the
  scene.)
- The **front layer is what does the occluding.** `building_floors.gd` already
  has `_fit_stair_front()`, which cuts a front sprite from whichever staircase
  art is currently visible and positions it automatically — once the art is
  split properly, point it at the real front piece and the code side is done.

## Existing scaffolding that already works

- `_apply_stair_visuals()` — picks the correct art per side and direction
  (Lobby_* = UP, Hallway_Staircase_* = DOWN); covered by `stair_visuals_test`.
- `_fit_stair_front()` — re-cuts the front layer from the visible art at runtime.
- `stair_pan.gd` — the dog-leg path, staggered stepping, camera pan, seamless
  commit. All of this is correct and should be kept.

The only missing piece is **art that has a back and a front, and a tilemap with a
hole for it to show through.**
