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

## Variants + the one pipeline (owner round 10)

Every module script now goes through `pixlib.finish_module(name, room_type, seed, bare, floor,
build, anchors, strip_fn=None)`, which renders, CHECKS and exports one variant AND writes its scene
(`tools/art/modscene.py`) — the furniture and its nodes are defined together in the art script, so
they can't drift. It refuses to write anything unless: the window boxes + side-wall sample columns
are bare, the floor repeats every 32px, every node sits ON something drawn (not bare wall/floor),
below the window line (y >= 40), and there are >= 2 FRONT nodes (reachable from the walking line —
owner: "you're putting a lot of stuff farther back… keep certain things down and closer to the
main Y plane"), and no FRONT piece stands where the player would step up to a BACK-PLANE spot
(`check_back_plane_clear`, run on every run's look — owner round 13b: "wherever you're placing these
higher up furnitures, y planes will need to be developed to allow the player to move up and
scavenge"). The spot stands the player (±10px) at the centre of each cluster of 'bp' nodes (<= 40px
apart, room.gd BACK_SPOT_CLUSTER), feet at local y 116; a column that isn't bare floor through rows
102..114 there is a front piece in the way (rugs start lower, set-back shadows stop higher). So: keep
front furniture (sofas, chairs, tables — fallen ones too) out of the x-span in front of set-back
nodes, and put no node on something that stands BEHIND a front piece (the TV-room sets carry none).
Behind-the-scenes blueprints (every Y plane, nodes by kind, step-up spots + stand zones, the
player to scale): `python3 tools/gen_module_blueprint.py` → `../blueprints/`. Node overlays land in `nodes/<name>_nodes.png` here (gold = front, blue = back
plane, green = balcony strip).

**Variants**: `scenes/Room_Modules/<type>_<v>.tscn` (+ `assets/rooms/<type>_<v>.png`), registered
in `room.MODULE_VARIANTS`; `WorldState.module_variant_index(apt, slot, type, n)` picks one per
(apartment, slot) — seeded, NOT per run (the furniture stays; the runs change its condition). Each
variant carries its own nodes under names no other room type uses (`anchor_<type>_<thing>`).

**Balcony strip** (study / dining): the balcony doors cover x 4..96. That strip of the MAIN art
must be bare wall + floor (checked); furniture there goes in `strip_fn` → `<name>_strip.png`, a
`StripArt` sprite, and its nodes are flagged `metadata/balcony_strip`. On a balcony slot
`room._apply_balcony_strip` hides the strip art and removes those nodes; without a balcony the
room gets the use of that space.

**All 30 variants BUILT (round 10) — 5 per room type** (overview: `all_variants.png` here; rebuild
everything with `python3 tools/art/build_all.py`, deterministic — an unchanged script re-writes
byte-identical PNGs). Scripts: `<type>.py` = variant a, `<type>_variants.py` = b-d (bathroom keeps all
four in `bathroom.py`); shared pieces in `tools/art/furn.py` (chest, shelves, table, chairs, boxes,
posters, rugs, lamps, walls + tiling floors).
- living room: a green sofa + coffee table + armchair (a conversation group) / b teak mid-century
  (the TV on a sideboard against the back wall, the sofa facing it from in front, back to us, the
  armchair turned to it) / c run-down flat (the same, a CRT on crates; pallet table, guitar,
  beanbag) / d grandmother's parlour (piano, chintz sofa, china cabinet).
- bedroom: a dressing table + wardrobe / b teenager's (desk + CRT, beanbag, bed on the right) /
  c sick room (iron bedstead, drip, wheelchair, med trolley) / d squat (mattress on the floor,
  clothes rail, backpack, crates).
- kitchen: a counter run + a table pulled out / b 60s galley (yellow units, formica dinette) /
  c farmhouse (range in a brick recess, butler sink, pine table + bench) / d student wreck (open
  fridge, dishes, microwave, camping table, pizza boxes).
- bathroom: a SHORT roll-top on claw feet (the owner's "horse trough" fix) / b 70s avocado
  (panelled bath) / c gilded (gold tub + throne, chandelier) / d wet room (curtained tub, washer,
  clothes horse).
- study: desk pulled out into the room / b 90s home office (a 3D office chair swivelled at an angle; a
  printout hanging from the printer and two printed sheets slid onto the floor at its stand) / c library (two bookcases + ladder,
  wingback, globe) / d prepper's radio room.
- dining room: table + side-on chair + drinks trolley / b 70s round table + serving hatch /
  c formal (grandfather clock, candelabra) / d barricaded (the table flipped on its side).
- 5th variants (e): living room hunting lodge (gun cabinet, a SYMMETRIC stone fireplace with a log
  basket and poker stand on the hearth, chesterfield, bear-skin rug) / bedroom a child's room (dollhouse, rocking horse, toy chest) / kitchen the
  hoarder (newspaper stacks, bags, cat tins) / bathroom pink 50s suite / study artist's studio
  (canvases, an easel with a smeared portrait, a trestle table) / dining room an abandoned birthday
  party (bunting, cake, party hats, unopened presents in the strip).
Study + dining variants each put their own furniture in the balcony strip (see above).

**PLACEMENT RULE (owner round 11 — "things strangely placed on the floor in the middle of nowhere…
be reasonable rather than silly")**: a LOOSE thing (a bag, basket, bucket, box, pile of books or
papers, tins, a dropped tool) never stands alone out on the floor. It goes against the wall, or
right beside / under / on the furniture it belongs with (clothes at the foot of the bed, a toy chest
at the bed's end, a trolley pulled up to the bed, a basket ON the table, tins against the counter,
a hammer at the foot of the barricade). Only real furniture that people stand out in a room — tables,
chairs, beds, sofas, easels, clothes rails / airers, a rocking horse — goes out toward the lane, and
that's what carries the FRONT nodes (two nodes on one table is fine). Move a piece as a unit with
`furn.moved(c, fn, dx, dy)` (it keeps its shadow).
Round 12 (owner: box files stacked on the study floor — "they should be stored in a small shelf";
"people don't have [globes] in homes anymore"): files go in `furn.file_shelf`, loose books on
`furn.side_cabinet` via `furn.book_stack`, newspapers in `furn.magazine_rack`. No globes.

**ARMCHAIRS AT AN ANGLE (owner round 12 — "you can draw them from the front and the side but not
from an angle")**: never hand-draw a turned armchair. `tools/art/chair3d.py` BUILDS the chair (seat
base, cushion, rolled arms, a low club or tall back, legs) in 3D, turns it by `yaw` and renders it
with the rooms' view (depth recedes up the screen), a z-buffer, flat top-left light snapped to a
5-tone ramp and pixel outlines: `C3.armchair(c, cx, base_y, yaw, {'fab','fab_lt','wood'}, style)`.
0 = facing us, ±30..40 = three-quarters, 90 = side-on. Preview of every angle:
`armchair_angles.png`. Studies B and C use it, and four living rooms: A (oxblood club chair at the
rug's end, turned to the sofa), B (mustard, watching the TV), D (sage wingback at the rug's end), E
(tan leather wingback by the lamp, turned to the fire) — each with an `anchor_living_armchair` front
node. C (the bare student flat) has none. **Yaw sign (round 12 fix — "consistently the wrong way
round")**: +yaw turns the chair's FRONT to screen-LEFT, −yaw to screen-RIGHT (`_rot` negates it);
it used to be backwards, so every chair faced away from its sofa/TV/fire.
**Per-run chair states** (owner: "for run 2 and run 3 … sometimes a version where the chair is
knocked back and blood stains on it"; round 13: "on its back, knocked over, rather than precariously
balancing"): `armchair(..., plan={run: 'ok'|'blood'|'tipped'|'side'}, key=...)`.
`tipped` = knocked flat ON ITS BACK (underside + legs toward us, a few degrees askew); `side` = rolled
onto an arm (the seat opening shows); both throw the seat cushion onto the floor beside it, sit on
their own footprint shadow and pool blood on the floor. BLOOD IS PLACED IN 3D: every rendered pixel
remembers where it is on the UPRIGHT chair (`render` returns `sbuf`), and the stain is noisy blobs on
the seat, up the back cushion and over the seat's front edge in that space — so it follows the
chair's angle whatever way it lies (round 13: a screen-space ellipse stayed horizontal on a fallen
chair). On its back the seat faces away from us, so a splash goes over the bare underside too, with
drips down it. `blood` = the same stain on the standing chair + drips + drops on the floor (heavier on
run 3). No WINGS (round 13: "bulked out areas … don't need to be there") — `style='wing'` is now the
tall-backed chair, `'club'` the low one. The module script passes
`finish_module(per_run=lambda r: setattr(C3, 'RUN', r))`, which REBUILDS the module per run so the
`_r2`/`_r3` looks carry the changed chair (and re-checks every node is still on drawn pixels).
Plans: living A {2 blood, 3 tipped}, B {3 tipped}, D {2 side, 3 side}, E {2 blood, 3 blood};
study B {3 side}, C {2 blood, 3 tipped}. Seeded by `key` + run, so it's stable.
The OFFICE CHAIR does the same (round 13b — "a computer chair that has been knocked over too"):
`C3.office_chair_at(c, cx, base_y, yaw, pal, plan={run: 'ok'|'down'|'down_blood'}, key)` — on its side,
base and casters sticking out; study B {2 down, 3 down_blood}.

**SEAT THE ROOM SENSIBLY (owner round 13 — "if a room has a TV then the furniture should be facing
it … if there is no TV it's weird a sofa would be facing forward and the armchair facing away")**:
- A room WITH A TV (round 13b, the owner picked "watch from behind" from mockups — a turned sofa
  "looks smaller than desired … strange"): the set stands CENTRED against the back wall on a stand
  tall enough that the stand's top shows over the sofa (else the set reads as perched on the sofa's
  back), and the STRAIGHT full-width sofa faces it with its back to us (`sofa_back` in
  living_room_variants.py — the front view's silhouette: back panel between lower arms, piping,
  seams, skirt, legs). The armchair sits to one side turned toward the set (B: yaw 110). Living B,
  C. (`chair3d` can still build turned sofas / TVs — `sofa_model`, `console_tv`, `crt_on_crates`,
  drawn with `draw_model` + `screen_detail` — but don't turn a sofa.) `office_chair()` is 3D too.
- A room WITHOUT one: the sofa faces the room and the armchair sits across the coffee table from it,
  turned back toward the sofa (a conversation group — living A), or turned to the fire (E).
- EVEN SPACING (round 13b — "good even spacing across the modules is essential for our scavenge
  nodes"; the right ends had piled up): one piece every ~50-60px across the whole 320, so the nodes
  spread the width. Living A: bookshelf | sofa | coffee table | armchair | drawers. D: piano |
  armchair | tea table | sofa | china cabinet. E: gun cabinet | armchair turned to the fire | the
  fireplace in the MIDDLE under the antlers (basket + poker on its hearth) | sofa. Study B: strip
  shelves | desk + office chair | printer stand | armchair + side table | a bin in the corner. Drop a
  lamp / plant rather than squeeze it in. Sofas stay STRAIGHT (round 13b: a turned sofa "looks
  smaller than desired … strange").
- No throws / blankets over sofas ("looks like a blanket or a bulletproof vest… unclean and weird"), no
  peeling wallpaper strips in the run-1 look (the run looks add the damage), and a fireplace is
  drawn mirror-symmetric (E is pixel-exact about x 128 apart from the clock hand).

**The runs (owner round 10 — "their run 2 and 3 looks as things get a bit more dilapidated and then
more so")**: every variant also gets `<name>_r2` / `_r3` textures (+ their own `_floor.png` and
`_strip.png`), GENERATED from its own layers by `pixlib.run_looks` inside `finish_module`, so any new
variant gets them for free. Afternoon: walls a shade darker, a couple of damp blooms (organic outlines
with a broken tide line — never clean circles), cracks, a peeled strip, a smear of blood, periodic floor
grime + a little debris. Night: darker again, more damp, cracks and peeling, holes knocked through to
the lath, black mould along the top, grime up the lower wall, a handprint, stains + plaster debris
everywhere. Decals land only on visible bare wall/floor (behind the furniture, never on it) and stay
off the side-wall sample columns; the floor grime is 32px-periodic and identical in the floor export,
so doorway wedges match. `room.apply_run_art(module, run)` swaps the textures (Art + StripArt); nodes
never move. Previews: `runs/<name>_runs.png` (morning / afternoon / night).

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
