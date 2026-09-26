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
Study + dining can hold the BALCONY — since owner round 14 a DOORWAY in the back wall onto a loggia
(`tools/art/balcony.py`, `assets/rooms/balcony{,_r2,_r3}.png`; x 8..92, lintel 16, sill on the seam at
100 — `scripts/balcony_geo.gd`, docs/Y_PLANES.md §1). That strip only has things the balcony may hide
(radiator, file boxes / sideboard), and the `Art` sprite comes BEFORE the `Balcony` node so the balcony
draws over it (checked by `apartment_window_test`). Preview: `balcony_runs.png`.

**Rules every module script enforces** (it refuses to write the PNG otherwise):
1. The runtime window boxes are bare wall (`check_window_boxes`).
2. The two columns the side walls are painted from (x 3 and W-4, wall rows) are bare wall
   (`check_edge_columns`) — else a partition face wears the furniture (a wardrobe at the edge striped
   the bedroom's side wall).
3. The FLOOR is drawn in PERSPECTIVE: the floor function is wrapped in `@persp` (pixlib) and drawn
   FLAT — a pattern repeating every 32px (`floor_is_periodic`), rows taller toward the viewer — then
   each floor row is remapped toward the module centre, `PERSP_K` (0.55) of full convergence, so tile
   and board seams recede instead of running straight down (owner round 14: a checker read as
   "standing on glass"). Full strength sheared the tiles at a module's edge into diagonal stripes.
   Exported ALONE (`save_floor_strip`) as `<name>_floor.png` (as the art shows it) and
   `<name>_floor_ext.png` (the same floor `FLOOR_EXT_M` 96px past each edge).

**Floors at a doorway (owner round 14 — "the head didn't move, the perspective of the floor moved")**:
between two rooms the floors meet on a FIXED line, the module edge, under a static wooden SADDLE; each
room's floor runs to its own edge. **Round 18: the doorway itself is STATIC** ("this wall boundary moving
left and right when passing through it… immersion breaking… keep a static boundary"): a door frame drawn
straight on at the join (`module_walls._door_frame` — the wall over the door in section, a head casing,
a timber jamb with a stop and a plinth, the saddle on across the floor). Nothing between two rooms moves
with the camera. Only at the two END walls does the room's floor run on to the wall's live base line
(`_floor_wedge`, painted from `_floor_ext.png`).

**Module walls (`scripts/module_walls.gd`, built by `room._build_modules`):** (round 18: the partitions
between modules are now the static door frames above; what follows describes the END walls) the two end
walls (the entrance end gets a doorway, dark beyond) are drawn LIVE in perspective from the camera (horizon y 224, the ceiling),
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
player to scale) — the LOCKED room template: `python3 tools/gen_module_blueprint.py` → `docs/blueprints/`
(checked by the gate; regenerate after any module change). Node overlays land in `nodes/<name>_nodes.png` here (gold = front, blue = back
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
off the side-wall sample columns; the floor grime is identical in the floor exports, so the end-wall
wedges match. `room.apply_run_art(module, run)` swaps the textures (Art + StripArt); nodes
never move. Previews: `runs/<name>_runs.png` (morning / afternoon / night).

**SET-BACK FURNITURE HAS DEPTH (owner round 14 — "the drawers, chests, wardrobes, bookshelves, they
look so flat against the back wall. It just looks like a picture… there needs to be reality and weight
to things even in pixel form")**: every piece standing against the back wall is drawn through
`pixlib.setback(c, fn, depth, top, x_range, rake, forward)`. The piece is drawn as before (its front
face) on its own layer, brought FORWARD `depth` px, and its silhouette is EXTRUDED back to the wall
toward the room's vanishing point (the horizon is the ceiling, y 0; a module's vanishing point is its
centre, x 160 — the perspective module_walls draws the partitions in). So a chest shows its lit TOP
and the side facing the middle of the room (a right-facing side darker, a left-facing one lighter);
plinths, cornices and legs carry through because the EDGE pixels are what get extruded (their colour
taken from just inside the outline, then the new silhouette re-outlined). Its back lands on the seam.
Things standing ON a piece (lamps, photos, vases, a kettle) are above `top` and simply come forward
with it. Nodes on a piece move with it (finish_module shifts every anchor that sits on a set-back
piece's pixels); lamps drawn on it too (the light offset). `forward` stands a loose thing further out
first (a box of tins in front of a counter that came forward); `rake` < TOP_RAKE (1.8) keeps a tall
piece's top face off a window box. Depths used: shelves 3-4, chests / cabinets 5, fridges / dressers
5-6, counter runs 7 (true rake 1.0, so worktops stay below the window boxes). A piece near a window box
moved 3 px outward so its new side panel stays clear (its nodes moved with it).

**ROUND 15 — MORE DEPTH, AND FIXTURES IN TRUE PERSPECTIVE (owner: "I am still seeing items flat against
the wall. This toilet looks like it is painted onto the background")**:
- Every `setback` depth is multiplied by `pixlib.DEPTH_GAIN` (1.6, capped at `DEPTH_MAX` 11 incl.
  `forward` — 11 keeps the step-up stand zone, rows 102-114, clear): shelves 3 → 5, chests 4-5 → 6-8,
  counters 7 → 11. The depths written in the scripts are the ORIGINAL values. If the gained depth would
  rake a top into a window box or a side-wall sample column, setback backs off one px at a time
  (never below the written depth), so the checks can't fail because of the gain.
- Fixtures whose SHAPE matters are drawn in true perspective instead of extruded: `pixlib.pp(x, y, d)`
  brings a wall-coord point d px out from the wall (scale (100+d)/100 about x 160, y 0), `pbox` draws
  a box between two depths (front, lit top, the side facing the middle, outline) and `pellipse` a
  flat ellipse at a height (a seat, a basin rim, a stool top). Built this way: every TOILET (cistern
  box, seat + lid or open bowl from above, the bowl down to its foot), every BASIN (the rim and the
  bowl seen from above, on a pedestal or brackets), the built-in BATHS (`bathroom.bath_box`: we look
  over the rim into the tub — the curtained one's curtain hangs at its FRONT edge), the shower tray,
  the roll-top baths' openings, the child's TOY CHEST (lid up, toys inside). Fixture functions take the
  on-screen x the old flat art used (`bathroom._wall_x`), so nodes stay on them.
- Radiators stand off the wall (setback 2 → 3).

**ROUND 16 — BEDS, SMALL THINGS, BATHROOM LEFTOVERS (owner: "do the beds and small items… little
things that just look off")**:
- BEDS: every bed is `furn.persp_bed` — built in wall coordinates like `pbox`: the headboard and
  footboard are boards running back to the wall (the face turned to the room's middle shows; an iron
  bedstead's posts, rails and spindles recede the same way), the mattress top narrows toward the wall,
  the pillow lies on it and the duvet covers the rest and drapes over the front edge. `low=True` = a
  mattress on the floor. Rooms add their own things (stars, quilt patches, a teddy) on top.
- SMALL THINGS: `furn.tin` (a cylinder — lit left, shaded right, a label, its lid or open top seen from
  above), `furn.bin_bag` (a lumpy tied sack with plastic shine — never extruded; `setback(depth=0,
  forward=…)` just brings a soft thing forward), pizza boxes as stacked `pbox` slabs with the top one
  open, the camping lantern with cage + cap, the camp table's top seen from above.
- The GUITAR has guitar proportions (wide lower bout, clear waist, round upper bout, hole above the
  waist, bridge, pickguard, a radial sunburst, a long neck to a slotted headstock) on an A-frame stand.
- BATHROOMS: the mop bucket stands out from the wall (rim, water, the mop sunk in it, handle leant on
  the wall); toilet rolls are rolls on holders (`toilet_roll`) or a stack of cylinders
  (`standing_rolls`); towels hang folded over their bars (`hung_towel`); curtains hang in real folds
  (`pleated_curtain` — rings, scalloped top, lit crests, swinging hem; a tight period = bunched) and
  the wet-room curtain hangs INTO its tub so the bath's front shows; the washing machine's load is
  drawn IN FRONT of it after its set-back (`machine_laundry` — `setback` now returns the depth it
  used): a shirt in the drum, a sleeve over the lip, a heap on the floor.
- Audit: `FLAT_REPORT=1 python3 tools/art/build_all.py` prints, per module, column runs where
  something stands on the seam with nothing in front of it (a piece with no depth). Table tops and
  the edges of side panels trip it too — read the flagged spots, don't chase zero.

**ROUND 17 — CURTAINS, WALLS THAT SAY SOMETHING, EVERY ROOM CHECKED (owner: "the shower curtains
bottoms would usually be inside the bathtub… the wall decorations and photos look meaningless and
lacking context… the papers with red lines… look weird like conspiracy boards"; "the pizza boxes on
the floor… too many… the bins are flat on the wall… clipping… more coverage across all images")**:
- CURTAINS keep their full length and hang INTO the tub: the hem is drawn before the tub's front (A, E)
  or ends at its rim (D, whose rail is back up near the ceiling — `RAIL` 14). The corner a hand pulled
  aside shows the tiled wall in the curtain's shadow, not a black hole.
- WALL PIECES WITH A STORY (`furn.py`): every paper says something readable in the 3x5 capitals and
  every picture has someone in it. `note` (lines, a last line ending "!" is red), `sticky`, `calendar`
  (EVERY flat's calendar is crossed off up to 12 MAY and stops — the day it happened — with a day
  ringed that never came), `photo` (people: skin, hair, clothes, height), `portrait` (an oil sitter —
  man / woman / girl / old — with a face, collar and hair), `landscape` (hills, or a sea with a boat),
  `newspaper` (headline you can read), `missing_poster` (tear-off tabs, two taken), `text_spray`
  (sprayed capitals that drip). FONT3 gained B F J Q X Z, digits and punctuation. The red-string
  boards are gone: study A is a family corkboard, study B a desk board (TAX DUE!, PAY, CALL, BACK MON),
  study D an evacuation street map (US ringed, the way to SAFE in red, the bridge crossed out) and a
  STAY INSIDE notice, kitchen E a front page + the stores list + DONT OPEN DOOR!. Blank frames got
  sitters: living D's two ovals are silhouette cameos of a couple, dining A a wedding photo, dining C
  three generations in oils (hers slashed), study C the old man whose books they were, study E a
  half-painted portrait on the easel (the other half still pencil), a boat study and a watercolour
  pinned up, the colours tried out on the wall (the confetti of paint flicks is gone); the fridge has
  a school photo and a child's drawing; bedroom B's scrawl is an EXAM sticky, bedroom E's height chart
  has ages and MIA, bedroom D an EVACUATE front page, a MISSING poster and NO FOOD sprayed.
- LOGIC + CLIPPING pass over all 30: kitchen D's corner is two closed pizza boxes (a grease ring) and
  two slumped bin bags (`bin_bag` has a rounded bottom now); kitchen C's butler sink is a `pbox` on
  piers with its curtain; kitchen A's tea towel hangs checked over its hook; kitchen E's paper bundles
  are newsprint tied with brown twine (white slabs with a red string read as pizza boxes); study A's
  papers lie on the rug (they hung off the desk like a sticker); study B's bin is a round
  `waste_basket` with paper in it; study D's aerial lead runs up beside the map, not across the notice;
  dining A's dresser has 2px stiles (setback samples 2px in for its side face — at 1px it picked up
  the plates as white dashes); dining B's serving hatch opens on the dim kitchen beyond; dining D's
  mattress LEANS (top on the wall, foot on the floor, striped ticking, buttons, its side and top) in
  front of leaning planks, and the flipped table's legs run back toward the wall; dining E's balloons
  are tied to the chair backs; bathroom D's mould is soft blooms (`mould_bloom`) and a pipe weeps rust.

**ROUND 18 — BATHROOMS BROUGHT FORWARD, A STATIC DOORWAY (owner: "the clothes rack is just randomly in
the foreground… the bathroom scene looks a bit more compact… we shouldn't always be needing to move up
to a secondary plane to scavenge… the shower curtain looks higher than the top of the curtain rail…
the bottom of the curtain itself should be going into the bathtub… this wall boundary moving left and
right… keep a static boundary")**:
- STAND-AT FIXTURES COME FORWARD (the rule is in docs/blueprints/README.md): every bathroom fixture is a
  real solid (`tools/art/solid3d.py` — lathe slices for round things, rounded-rectangle slices for a
  roll-top bath, drawn into a layer and outlined once) reaching 16–20 px out: `toilet3d` (cistern on the
  wall, the pan and its oval seat coming 20 out), `basin3d` (on a pedestal or iron brackets, placed by
  its WALL x so the mirror hangs over its tap), `bath3d` (a built-in bath, its front 20 out, the inside
  seen over the rim), `clawfoot3d` (a free-standing roll-top on claw feet out in the room), `vanity3d`,
  `washstand3d`, `washing_machine3d`, `laundry_basket3d`. Their nodes are FRONT nodes: bathrooms B, C, D
  have no step-up at all; A keeps the shower (you step into it), E the linen cupboard.
- CURTAINS hang from a RAIL you can see (`shower_rail`: a chrome rod over the tub at depth 11, returning
  to the wall at both ends, a ceiling stay) — the curtain starts just under it, and `curtain_in_tub`
  hangs it INSIDE the tub; `bath_front` then re-draws the end rims, the front rim and the front face,
  so the hem goes down behind the front rim. Bath A has no curtain now. Bathroom D's wall pipe (it read
  as the rail) is gone; mould everywhere is `mould_bloom`, never a rectangle of dither.
- SITUATIONAL FOREGROUND: D's clothes airer is gone — a laundry basket stands by the machine instead;
  mats lie flat in front of their baths; the champagne bucket stands by the gold tub.
- THE DOORWAY BETWEEN TWO ROOMS IS STATIC (`module_walls._door_frame`, see "Floors at a doorway").
- Also: kitchen D's sink holds washing-up that reads (plates on edge, a saucepan, a mug) instead of
  coloured ovals; kitchen E's cat food tins are a stack + a couple + one on its side (nine in a row read
  as a pattern); bedroom A's missing picture has its dust line, nail and snapped string, and its peeling
  paper shows the plaster under a curling flap. NO RECTANGLES OF DITHER for stains: damp is
  `furn.water_stain` (filled, irregular, a tide line, a run), spills are `furn.floor_stain`.

**ROUND 19 — LOOK OVER GEOMETRY (owner: "the washing machine and the piano… look like big blocky
cubes… the image of what they are appears smaller… the cistern on that gold toilet looks massive, like
an air conditioner… items on top of dressers are 2D shapes and very close to the front edge… the inside
of the fridge looks flat")**: keep the new sizes, but make the object's identity FILL the shape.
- THINGS ON TOP of a set-back piece (anything drawn above its `top`) now come forward only to the MIDDLE
  of the top surface (`pixlib.setback`: half the shift; their lights and nodes move with them), get a lit
  left / shaded right edge (`_on_top_volume`) and cast a small shadow back across the top
  (`_on_top_shadow`). The extrusion's outline colour comes from the piece's own EDGE (it once picked a
  jar's shadow from inside an open fridge and outlined the fridge in red).
- `furn.chest` tops are a two-row lit slab overhanging the carcass, so every sideboard / dresser top
  reads as polished wood instead of a dark block.
- WASHING MACHINE: less deep, a control panel (soap drawer, display, dial), a porthole ~80% of the face
  (chrome bezel, seal, the drum and its holes), a shaded side, the door open on its hinge.
- CISTERNS (`bathroom.cistern3d`): rounded, narrower than the seat, an overhanging lid; the gold one
  has a moulded panel with a crown.
- PIANO (`living_room_variants.piano3d`): a true upright — the keybed projects with the keys on it (black
  keys in 2s and 3s), cheeks, legs + toes, pedals, panelled front, music desk, fallboard.
- The china cabinet (cornice, glazed doors, china on shelves, drawer, bun feet), bathroom B's vanity
  (upstand, overhanging worktop, plinth recess, panelled / open doors), a stool with a radio and a
  wicker hamper (both were boxes), study D's folded CAMP BED (tubes, canvas, folded X legs, a strapped
  sleeping roll — it read as a locker), dining B's turntable, dining C's silver tea set
  (`furn.silver`: teapot, sugar bowl, coffee pot, cup), dining E's boombox and paper cups.
- The OPEN FRIDGE (kitchen D) has a cavity (the lit inner wall, a darker back wall, glass shelves seen
  from above, the light) and TELLS SOMETHING (owner: "all of this can be active storytelling"): food
  spread at different depths, a milk carton knocked over on the bottom shelf, milk pooled on the glass
  and DRIPPING live onto the fridge floor, over the sill and into a puddle on the lino; the door bins
  hold eggs, ketchup and mustard, juice and brown sauce.
- LIVE DETAILS: `pixlib.anim(x, y, kind, …)` marks a small animated detail in the art (moves with a
  set-back piece like a light); `modscene` writes it into the module scene as an `Anims` child running
  `scripts/module_anim.gd` (kind `drip`: a drop swells, falls, splashes, on a period seeded by its
  position so no two drip in step). The hook for more storytelling details.
- SPREAD THINGS ALONG A TOP (owner: "items seem to be more predominant on the right side"): a sideboard
  under a window slot keeps its LOW things (cups, a fruit bowl, a plate) under the window and the tall
  ones clear of it — never everything bunched at one end.

**ROUND 20 — STORY OVER STILL LIFE (owner: "a broken cup and a puddle of coffee says way more than four
generic cups in a row… the clothes inside the drum… look like the blue material is floating over empty
space")**: a surface shows what HAPPENED on it, not a set of objects on display.
- DINING C: the tea tray pushed askew, the teapot's lid off and lying on the tray, one cup still on its
  saucer with a spoon, sugar spilt round its bowl — the other cup lies on its side in its own coffee,
  which runs to the edge, down the sideboard and DRIPS live onto a puddle where its twin lies smashed
  (shards + the snapped-off handle). The dinner table: one plate still served, one shoved back empty,
  cutlery put down, a wine glass on its side with the wine running off the edge and DRIPPING, a candle
  knocked out of the candelabra onto the runner, another guttered to a stub.
- The washing machine's wash (bathroom D, `bathroom.machine_laundry3d`) SLUMPS in the bottom of the drum:
  it fills the drum up to a lumpy line, follows the drum's curve (darker where it presses on the steel),
  casts a shadow on the drum above it, a red sock in the load, and a sleeve hauled out over the seal.
- LIVE DETAILS now have five kinds (`pixlib.anim(x, y, kind, fall, color, w, h)` → `module_anim.gd`):
  `drip`, `drop` (slow — an IV), `blink` (a w×h LED / cursor), `static` (a w×h screen of TV snow with a
  rolling bar), `spin` (a glint round a w×h record). A detail drawn ON a set-back piece's top moves with
  it like a light. In the rooms: living C's CRT left on (snow), bedroom B's CRT at a prompt (cursor),
  bedroom C's IV still dripping, study B's letter left mid-sentence (cursor), study D's radio still
  listening (LED), dining B's record still turning, kitchen A's tap dripping into the dirty water,
  bathroom D's basin tap dripping, plus the milk (kitchen D), coffee and wine (dining C).

**RUN LOOKS, round 14**: the afternoon / night decals were redrawn — damp is a FILLED water stain with
a tide line, an inner ring and runs weeping down (it was a dotted outline); torn wallpaper is a ragged
patch to the plaster with the paper's torn core along its edge and a curled corner (it was a floating
white strip); blood is the corridor's own decals (`assets/corridor/decals/`: handprints, spatter, claw
marks — not the smears or slide, which read as a snake / a red pillar in a room), laid only on bare
wall; holes to the lath are a dark cavity, a thin lath line or two, a broken rim and cracks.

**LIVING ROOM pass (round 14)**: C's guitar is upright on a floor stand at full size (it was squeezed
under window R) and swapped places with the beanbag; C's posters are a readable LIVE gig poster and a
torn sunset holiday poster; B's water streak (read as a cord) is a stain from the ceiling; D's sofa
has a regular rose print (random dots read as spatter) and the tea table a teapot + cup and saucer;
leaning books are drawn crisp (`furn.leaning_book` — slanted rows of exact width, a shadowed spine
edge, a page edge) in living A and the study bookcase. KITCHEN pass: worktops, fridges, larder, dresser,
wall units with depth; E's carrier bags have loop handles (they read as garlic) and its toppled stack
fans out as newspapers (it read as planks).

**BEDROOM / BATHROOM / STUDY / DINING passes (round 14)**: depth on every set-back piece; bedroom B's
desk is symmetric (a pedestal each end, the CRT centred — "the monitor goes over the right side… no
symmetry") and its posters are readable (`furn.poster_gig` / `poster_film` / `poster_map` /
`poster_game`, text in the 3x5 `furn.text3`); the child's room (bedroom E) has more toys, each where a
toy is put away (a wall shelf of blocks / a bunny / a car, a block tower by the dollhouse, a ball by the
wardrobe, a rag doll on the bed) and at NIGHT heavier blood (small handprints at a child's height, the
duvet soaked, spatter on the dollhouse, a drag trail and small footprints) drawn from `chair3d.RUN`;
bathroom E's tall frosted cabinet ("looks like a door") is a chest-height linen cupboard; study A's
desk faces the room with the chair behind it, so we see its panelled FRONT (its drawers face the chair).

**LAMPS (owner round 14 — "lamps… some will be on with real lighting in evening and night scenes.
Flickering, cutting out, turning back on, especially in the night scenes. Not always… lighting can't
match room to room… having light sources in apartments including ceiling lights is important")**:
every one of the 30 variants carries at least one fixture, drawn UNLIT by the `furn.py` helpers —
`table_lamp` (on a chest / sideboard / bedside), `desk_lamp`, `floor_lamp`, `lantern` (battery),
`pendant` (plain or dome shade), `bare_bulb` (a flex from the ceiling), `flush_light`, `tube_light`,
plus a few bespoke ones (living-A chest lamp, bedroom-B lava lamp, bathroom-C chandelier, dining-D
lantern on the strip). Each helper calls `pixlib.light(x, y, kind)` at the BULB, and `finish_module`
writes those into the module scene as a `Lights` container of `Node2D` markers (`metadata/kind`,
`metadata/balcony_strip` for strip furniture) — NOT `Marker2D`, because `room.gd` takes every
Marker2D child of a module for a scavenge node. At runtime `scripts/apartment_lights.gd` (one per
module, added by `room._build_modules`, live rooms + the balcony-pan backdrop) decides per flat:
- **the morning** (run 1) is daylight — nothing on;
- **power**: a flat has mains power 72% of afternoons / 62% of nights (seeded per flat + run); a
  BLAZE / CHARRED flat never; a battery lantern ignores it;
- **each fixture** in a powered flat is on 55% (afternoon) / 70% (night), seeded per flat + slot +
  fixture + run — so no two flats light alike, and re-entry is stable;
- **behaviour**: steady / flicker / cutout (on 2.5-9 s → DARK 0.4-3.5 s → stutters back on), mix
  62/22/16 in the afternoon and 30/32/38 at night; a tube's flicker is a fluorescent BLINK, a
  lantern gutters but never cuts out;
- a lit fixture is a real PointLight2D (a round pool for a lamp on furniture, the corridor lamps'
  downward cone for a ceiling light) + a small additive glow on the shade. Energies sit in the
  corridor lamps' budget (round 0.70 / 1.20, cone 0.85 / 1.50 afternoon / night).
Tuning is all tables at the top of `apartment_lights.gd`. The blueprints mark each fixture (a pale
sun at the bulb). Locked by `apartment_lamp_test`. The LOOK (pool sizes, flicker feel) needs an
in-editor check.

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
   shows **in the tutorial only** (owner round 14: "the movement up feels a little clunky with that
   arrow… keep and use the arrow in the tutorial, but remove it from active game"); **W** (or clicking one of its nodes — it walks there first) steps the player UP to feet 339
   (~15px in front of the furniture's base — at 328 they looked like they stood ON it), scaled by the
   room's perspective (≈0.89). Up there only that spot's nodes are in reach (Tab /
   wheel / click picks between them), no walking-line node is, and there's no left/right movement;
   the game never sends you down — **S** steps back (a click on open floor steps down first, then
   walks). Set-back nodes are NOT searchable from the walking line any more. A save made up there
   loads on the walking line (`player.lane_position`). Enemies still reach you up there (a step
   back, not a hiding place). Not built yet: enemies standing on the back plane. Locked by
   `back_plane_test`.
