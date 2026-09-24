# Room-module art mockups

Pixel-art mockups for the six apartment modules (320 x 144, native 1:1, nearest filtering), drawn by
code so they're regenerable and exactly on the module geometry:

- `tools/art/pixlib.py` — the tiny drawing kit (+ the module constants: wall/floor seam y 100,
  room floor line 128 / feet 129, the two runtime window boxes to keep clear).
- `tools/art/<module>.py` — one script per module. Run `python3 tools/art/living_room.py` →
  `assets/rooms/living_room.png` (the in-game texture) + `living_room_x4.png` here (a 4x preview).

Rules each module follows (docs/ART_REQUIREMENTS.md): flat / neutrally lit (the engine lights it),
soft contact shadows only; every scavenge anchor (`Marker2D` in the module scene) sits ON a piece of
furniture; nothing in the runtime window boxes L (50..94, 10..66) / R (226..270, 10..66) — the wallpaper band;
furniture bases in front of the seam, never below the floor line 128.

The module scene shows the art as an `Art` Sprite2D over the old ColorRect; the ColorRect's Label is
hidden but KEPT (room.gd reads its text for the room type).

**Walking lane (owner round 9):** furniture sits BACK from the player's feet line (129) — bases at
~112-116, leaving a clear strip of floor in front, so the player never looks like they're standing
in the front of the couch/table/chair. Every script asserts the runtime window boxes are bare wall
(`pixlib.check_window_boxes`) and refuses to write the PNG otherwise.

Status: living room v2 (owner feedback round 9: taller coffee table, everything pulled back off the
walking line; the armchair was dropped (the owner: "problematic") for a painted CHEST OF DRAWERS on
the right — a second set-back scavenge spot for the future upper plane; the stray floor box went).
Style VARIANTS to compare: `python3 tools/art/living_room_variants.py` → `assets/rooms/living_room_
{b,c,d}.png` (B mid-century, C run-down, D parlour) + the side-by-side `living_room_variants.png`
here (A-D). Not wired into the game yet (step 3 below).
Bedroom, kitchen, bathroom, study, dining room: to do in the same style once the look is signed off.

**Module walls (`scripts/module_walls.gd`, built by `room._build_modules`):** the partitions between
the three modules (with a doorway over the walking lane) and the two end walls (the entrance end
gets the same doorway, dark beyond) are drawn LIVE in perspective from the camera (horizon y 190),
so the face you see is always the one turned toward you and flips as you walk through — never a
painted, half-the-time-inverted wall. Each face samples its OWN module's art at the edge column, so
wallpaper, rail and skirting continue round the corner for any module or variant with no wiring.
Visual only (no collision). Locked by `apartment_window_test`.

**Room shell (`scripts/room_shell.gd`):** the old stone-block tiles round the flat are HIDDEN and
replaced by a clean building CROSS-SECTION cut at the same front plane as the partitions: a
ceiling slab across the whole flat (the flat above's floorboards on top, a plaster ceiling edge
underneath), solid end-wall sections that turn that edge down each side, and a framed FRONT DOOR
in the entrance end wall (architrave, threshold, dark corridor beyond). Beyond each end wall's
back corner the room's floor is extended in perspective to the wall's foot. The camera reaches
32px past the old tile bounds so the door and end cuts are in shot. The slab covers module rows
0..9, so the art's own crown moulding is hidden — future modules needn't draw one. Geometry in
docs/Y_PLANES.md §1.

## Agreed plan (owner round 9) — in this order, not started beyond step 1

1. Settle the module's design + look (the living room is the example).
2. Move the scavenge nodes (`Marker2D`s) onto the furniture as drawn. **Living room DONE** (owner
   round 9): bookshelf middle shelf (26,71) + the gap in its bottom row (35,86), the sofa's left
   cushion under the throw (114,103) + the slashed right cushion (149,101), the coffee-table top
   (214,98), the chest of drawers' open drawer (275,95). Anchor NAMES are unchanged (loot is seeded
   and saved by name — `anchor_right_chair` now sits on the drawers).
3. Build ~5 VARIANTS per module (different furniture / arrangement / decay) so a room type never
   looks the same twice — seeded per apartment like the layouts.
4. A second, deeper **scavenge Y plane**: pressing E on a node set back in the room (the bookshelf)
   walks the player UP into the scene to it, searches, and steps back down to the walking line —
   purely visual, not a movement plane. Enemies could stand on that upper plane and come down to
   attack. (Reuses the balcony-plane / door approach-walk machinery.)
