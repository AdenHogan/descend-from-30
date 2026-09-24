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
walking line, the blue chair replaced with a leather wingback turned three-quarters toward the room).
Bedroom, kitchen, bathroom, study, dining room: to do in the same style once the look is signed off.

## Agreed plan (owner round 9) — in this order, not started beyond step 1

1. Settle the module's design + look (the living room is the example).
2. Move the scavenge nodes (`Marker2D`s) onto the furniture as drawn. **Today the living room's
   nodes still sit at their OLD spots** (e.g. the sofa nodes at y 114 now fall on the sofa's front,
   the coffee-table node at 122 below the table) — deliberately left until the look is agreed.
3. Build ~5 VARIANTS per module (different furniture / arrangement / decay) so a room type never
   looks the same twice — seeded per apartment like the layouts.
4. A second, deeper **scavenge Y plane**: pressing E on a node set back in the room (the bookshelf)
   walks the player UP into the scene to it, searches, and steps back down to the walking line —
   purely visual, not a movement plane. Enemies could stand on that upper plane and come down to
   attack. (Reuses the balcony-plane / door approach-walk machinery.)
