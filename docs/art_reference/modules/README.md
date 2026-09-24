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
**Bedroom + kitchen BUILT (owner round 9)**: `tools/art/bedroom.py` (dressing table + mirror, bedside
+ squat lamp, the bed lengthwise with a draped duvet and a box under it, clothes on the carpet, a
wardrobe with one door ajar) and `tools/art/kitchen.py` (a rounded fridge, the counter run with wall
cupboards over a tiled splashback, the cooker with a pot on the hob, the sink + drainer, bin bags
against the wall, a tea towel + calendar). Nodes on the furniture; set-back ones flagged back_plane
(bedroom: dressing table, bedside, wardrobe top + drawer; kitchen: all of them).
Owner round 10: the duvet now covers the whole mattress top and drapes over the front with an uneven
hem; the kitchen's pedal bin (an "appliance on the floor") became two tied bin bags against the wall.
**Bathroom, study, dining room BUILT (round 10)** — all six basic modules now have art:
- `bathroom.py`: mirrored cabinet hanging open over a pedestal sink, low-cistern toilet, the bath
  lengthwise with a torn curtain (nodes on either end of the rim — front), a laundry bag on the floor
  (front), a corner shower. Grimy paint over tiles; an 8px mosaic floor.
- `study.py`: tall bookcase (upper + lower shelf nodes, one spot), a writing desk with a green lamp
  under a pinned-up board of notes and red string (desk-top node), the leather chair pulled out, a
  rug, papers under the R window, shelves over a filing cabinet (node on the shelves). Green paper
  over dark panelling; parquet.
- `dining_room.py`: the table pulled forward to the lane with a meal abandoned on it (nodes on either
  end of the top — front), ladder-back chairs behind, one knocked over in front, a pendant lamp and a
  scratched-out portrait, a dead plant, a Welsh dresser (drawer + cupboard nodes, one spot). Damask
  over a cream wainscot; dark boards.
Study + dining can hold the BALCONY (it covers x 4..96, y 12..126): that strip only has things the
balcony may hide (radiator, file boxes / sideboard), and the `Art` sprite comes BEFORE the `Balcony`
node so the balcony draws over it (checked by `apartment_window_test`).

**Rules every module script enforces** (it refuses to write the PNG otherwise):
1. The runtime window boxes are bare wall (`check_window_boxes`).
2. The two columns the side walls are painted from (x 3 and W-4, wall rows) are bare wall
   (`check_edge_columns`) — else a partition face wears the furniture (a wardrobe at the edge striped
   the bedroom's side wall).
3. The FLOOR is exported ALONE as `assets/rooms/<name>_floor.png` (`save_floor_strip`) and must repeat
   every 32px (`floor_is_periodic`; the living room's planks predate this and don't).

**Floors at a doorway (`module_walls._floor_wedge`)**: two rooms' floors part along the wall's BASE
LINE in perspective, not the module's vertical edge — the room whose wall face you see has its floor
run on past the edge to that line (a triangle: zero at the seam, widest at the front), tiled from
its floor-only export so nothing standing near the edge smears across; it flips with the camera like
the wall face above. Interior doorways get a wooden threshold along it.

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
   **Nodes are seed-dependent and belong to the variant** (owner round 9): each variant scene
   carries its OWN `Marker2D` nodes on its OWN furniture (a mid-century room with a TV console has a
   TV node, not a chair node). Per apartment, `room.gd` shuffles that module's markers with a seed of
   `master_seed + apartment + room type` and activates `ANCHOR_RANGES[type]` of them (living room
   2-5, clamped to however many the variant has) — so NOT every node spawns, and which ones do
   follows the seed. Two different living rooms therefore show different node sets from their
   different furniture; with the same marker count/order they may happen to pick the same slots —
   either is fine by design. A variant may use NEW node names: the room passes the module's room
   type to the loot lookup (`get_items_for_anchor(name, apt, room_type)`), so a new name gets the
   room's pool (before, only the fixed per-type name list did — a new name held nothing). Locked
   by `loot_test._test_variant_anchor_pools`.
4. **BUILT — the BACK (scavenge) plane** (`scripts/back_plane_spot.gd`): flag a node set back on
   furniture with `metadata/back_plane = true` in its module scene (living room: both bookshelf
   nodes + the drawers). Per room, flagged nodes that SPAWNED this seed group into spots (within
   40px in one module → one spot, e.g. both bookshelf nodes). In scavenge mode near a spot a small ↑
   shows; **W** (or clicking one of its nodes — it walks there first) steps the player UP to feet 339
   (~15px in front of the furniture's base — at 328 they looked like they stood ON it), scaled by the
   room's perspective (≈0.89). Up there only that spot's nodes are in reach (Tab /
   wheel / click picks between them), no walking-line node is, and there's no left/right movement;
   the game never sends you down — **S** steps back (a click on open floor steps down first, then
   walks). Set-back nodes are NOT searchable from the walking line any more. A save made up there
   loads on the walking line (`player.lane_position`). Enemies still reach you up there (a step
   back, not a hiding place). Not built yet: enemies standing on the back plane. Locked by
   `back_plane_test`.
