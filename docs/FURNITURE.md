# FURNITURE AS ASSETS — rooms that are laid from a seed

**Status: BUILT v1 for EVERY room type — bedrooms (owner round 47, 2026-10-20), kitchens (47e), living rooms (47f), dining rooms, studies and bathrooms (47g).** Only the story rooms (breached / burnt / one of the dead / the tutorial's flats, and the gun cabinet's living room) are still baked modules; the same pipeline is
how they are being converted ("start with bedrooms and work from there" → "expand to other module types too").

> The owner: *"converting all art furniture and objects into their own assets like what you've done with the posters and wall art — that a
> seed can natively place in procedural items, so even two versions of a bedroom module A will have variance. This would be big, but it does
> allow for more accurate items and furniture that will have their own shape and presence. They won't be flat objects any more. Start with
> bedrooms… just because an item is currently in a bedroom doesn't mean it can't also be in another apartment room. That means some rule and
> logic needs to be in place — we do not ever need to have a bed in a kitchen. So intelligent design needs to apply here."*

## What changed

Until now a room module was ONE baked picture (`tools/art/<room>*.py` → `assets/rooms/<name>.png`): wall + floor + every piece of furniture at fixed
coordinates. Thirty such pictures, so a bedroom was one of five rooms, always the same.

Now a bedroom in an ordinary flat is two things:

* a **SHELL** — the bare room: wallpaper / plaster, damp, skirting, the floor in perspective, the run-2 / run-3 looks, and nothing standing in it
  (`tools/art/furn_shells.py` → `assets/rooms/bedroom_shell_{a..e}.png`, `scenes/Room_Shells/*.tscn`);
* **PIECES** — every piece of furniture / object is its **own sprite** with a record of what it is (`tools/art/furn_bedroom*.py` →
  `assets/furniture/*.png` + `data/furniture.json`), laid into the shell at runtime by a **seeded planner** (`scripts/furniture_planner.gd`),
  built into nodes by `scripts/room_furniture.gd`.

The old five bedrooms A–E are five **styles** of one room type: `adult` (A), `teen` (B), `sick` (C), `bedsit` (D — was `refuge`, round 47i), `kid` (E). A style is a recipe
plus a shell; every flat's bedroom is one style (seeded, weighted) and **no two are the same room** — in a 40-seed sample every style gave 36+
different layouts.

## The logic — "no bed in a kitchen"

Every rule is data, and `FurniturePlanner.validate()` re-checks any plan against all of it (`tests/furniture_test.gd` runs that over 1000 seeded
rooms and proves each rule FAILS on a plan that breaks it):

| Rule | Where it lives |
|---|---|
| A piece lists the **rooms** it suits (`rooms {room: weight}`) and the **styles** it suits (`styles {style: weight}`); the planner only draws from a room's own pool. A cot is the child's room, an iron bedstead the sick room, a drip stand never the child's. | each piece's `@piece(...)` |
| A **tag** table says which tags may be in which rooms (`TAG_ROOMS`: `sleeping` → bedroom only, `cooking` → kitchen, `toilet` → bathroom, `books` → bedroom/study/living room…). **Registration refuses** a piece that breaks it (`furn_bedroom.py` was stopped three times while I wrote it: a book pile in a dining room, a mattress in a living room, a wheelchair…), and the planner **re-checks it at plan time** (a bed mis-registered for a kitchen is still refused). | `furnlib.TAG_ROOMS` → `data/furniture.json "rules"` |
| The **wall line is exclusive** (a bed is never in front of a dresser, two wardrobes never overlap), nothing leaves the module (x 4..315), a piece appears at most its **limit** times. | planner `_fits` / `validate_state` |
| Nothing tall stands in front of the room's **window** (the module's actual window side, `WorldState.apartment_window_side`, is passed in; only that box is blocked). | `ctx.window` |
| Everything on the floor lies **behind the walking lane** (feet ≤ row 122) and nothing standing / lying on the floor is in a step-up spot's **stand zone** (the player is drawn over everything baked, so a body there would be walked over — owner rounds 36i / 36k / 45b). The stand zones come from the planned pieces' own back-plane nodes. | planner |
| Things on a surface (a lamp, a glass, a jewellery box) stand on a **slot** a piece declares; hung things (pictures, posters) hang clear of every piece and the window; clutter lies **near** what it belongs to (`near` tags: clothes by the bed or the wardrobe, toys by the toy chest); a rug lies on open floor, never half under the bed; a pendant's flex never hangs through a picture. | planner |
| A piece may **need company**: a desk wants its chair (placed beside it, clear of the desk's own step-up spot) or the desk is not placed at all (`needs`). | `desk_crt` |
| A room always has enough to search: ≥ `min_front` scavenge nodes reachable from the walking lane (node y ≥ 66, not a back-plane node) — the old per-module rule. | recipe |
| A plan that cannot be made in 48 attempts falls back to the recipe's **hand-set layout** (valid for either window side — tested). It is the rare exception (< 5 % in the test; 0 in 1000). | recipe `fallback` |

## Perspective — pieces lean, per bucket

The rooms are drawn as if looking into a box with one vanishing point at the module's ceiling (160, 0): a set-back piece shows the face turned to the
middle. A sprite cannot know where it will stand, so every leaning piece is **rendered once per LEAN BUCKET** (`furnlib.LEAN_X` = 36, 72, 116, 160, 204,
248, 284 — the module x of its centre; 160 = straight on, no side face) and the planner uses the sprite whose bucket is nearest to where the piece
stands. Pieces too wide for the edge buckets (a bed) simply have no sprite there. The look matches the baked rooms (`pixlib.setback` is reused, without its
window back-off). **`furnlib.LEAN_MODE = 'none'`** renders everything straight-on (one switch) — the owner's call between the options in
`docs/ROOM_DEPTH_AND_PROPS.md` still stands; this does not pre-empt it.

## Pipeline

```
tools/art/furnlib.py        the kit: @piece(...) registry, the sprite renderer (lean buckets, open states), the logic table
tools/art/furn_bedroom.py   shared + adult pieces      furn_bedroom_b.py teen   _c.py sick   _e.py kid     (the first-pass pieces that have NOT been redrawn yet — see "Art pass" below)
tools/art/propkit.py        shaded primitives (sphere / cylinder / frustum / slab, tone ramps, selective outline, contact shadow) — what makes a small thing look round
tools/art/bedding.py + furn_beds.py   every bed: covers drawn IN PERSPECTIVE (pattern mapped back onto the mattress plane), pillows, folds, throws, mattress + sleeping bag
tools/art/furn_props.py, furn_props2.py, furn_more.py   the small things (lamps, clock, books, suitcase… shoes, clothes, rug, backpack, crates, boxes, plants, bedside table)
tools/art/furn_seats.py     the chairs + rocking horse as little 3D models (chair3d.py renders them)     furn_medical.py  drip stand, wheelchair (3D), trolley
tools/art/furn_dollhouse.py, furn_wardrobes.py   the dolls' house; the wardrobes + pill cabinet
tools/art/furn_rooms.py     the recipes (shape of each style) + the rules export
tools/art/shells.py, furn_shells.py   the bare rooms
tools/art/furn_build.py     writes assets/furniture/*.png (+ open/ strips), data/furniture.json, docs/art_reference/furniture/pieces.png (+ pieces_2.png… — a sheet is paged under 30000 px, Godot downsizes anything taller than 32768)     [--check = the gate]
tools/art/furn_compose.py, furn_preview.py   Python composer: plan JSON → contact sheet (review)
scripts/furniture_planner.gd   THE PLANNER (pure function of seed): plan(room, style, seed, {window}) → items / anchors / lights / anims
scripts/room_furniture.gd      builds a plan into a module: Sprite2Ds, Marker2D scavenge nodes (back_plane meta), Lights, Anims, Open_<anchor> overlays
scripts/room.gd                furniture_plan_for / baked_scene_for / _build_modules — chooses planned vs baked
tools/furniture_dump.tscn      godot --headless res://tools/furniture_dump.tscn -- --room=bedroom --style=teen --n=24 --out=plans.json  (rule violations, fallback rate)
tests/furniture_test.tscn      the 74th suite
```

Regenerate after any change: `python3 tools/art/furn_build.py` (and `furn_shells.py` for a shell), then `godot --headless --import`. Review: dump plans, then
`python3 tools/art/furn_preview.py plans.json sheet.png --cols 2 --scale 2 --nodes --window` (yellow box = the window, circles = scavenge nodes: blue = step-up, gold = lane).

A piece record (`data/furniture.json items.<id>`): `plane` (wall / front / decor / rug / floor / top / ceiling), `rooms`, `styles`, `tags`, `w`, `lean`, `bucketed`,
`near`, `needs`, `limit`, `wall_y` (decor), `feet` (the y range it may stand at), `opens`, and per **variant** the sprites (`file`, `bx`, `rx`/`ry` = the reference
point R — the front-left corner at the feet row — and `l,r,t,b` = the drawn extent around R), `anchors` (scavenge nodes, relative to R; `head_rel` = measured from a bed's head
end), `lights`, `slots` (surfaces things stand on: `kinds` it takes), `anims`, `params`. Add a piece = one `@piece` function; it needs no other edit.

## Scavenge nodes, loot, lights, openings

* A piece's nodes become `anchor_<room>_<name>` Marker2Ds (a bed keeps the legacy `anchor_bed_pillow` / `anchor_floor_underbed`), `back_plane` for set-back pieces — `room.gd`'s
  loot dealing, back-plane spots and node reactions work unchanged (they were never tied to names; loot is by room type).
* Lights are `Lights/lamp_N` markers read by `apartment_lights.gd` (a table lamp, a lava lamp, a battery lantern, a pendant — on or off by seed and run).
* A piece that opens when searched (nightstand / chest drawer, wardrobe door) carries a strip (`assets/furniture/open/`) and gets the same `Open_<anchor>` node the baked rooms use.
* Furniture is the same in all three runs (the seed excludes the run: it is a physical feature of the flat); the run only tints it (`RoomFurniture.RUN_TINT`).

## What is NOT planned yet (honest list)

* **Story rooms stay baked.** A breached flat, a burnt one, the room that holds one of the dead (and the tutorial's flats) keep the OLD baked module — their stories (nest
  overlays, burnt looks, the scripted tutorial nodes) are drawn into that art. To keep the wallpaper / floor / character stable when a flat turns into one in a later run, the
  baked module shown is **the old module of the same style** (`room.baked_scene_for`, recipe `legacy`). Two consequences that remain: the furniture *arrangement* changes in that
  room, and its scavenge nodes have different names, so a room looted in run 1 as a planned room and breached in run 2 is **fresh** again (loot depletion is keyed by node name).
  The proper fix is to lay story rooms from planned pieces too: nest overlays per shell with their body rects handed to the planner as obstacles, and a runtime burn shader for the
  furniture. Not started.
* **Run looks for furniture** are a tint only (the shells carry the damp / cracks). Grime, blood and breakage as per-piece variants are future work.
* **No overgrowth** in planned bedrooms (growth maps are baked per module); no live CRT cursor (the desk's computer is static).
* **Other room types** — all six room types are planned now (rounds 47e-47g); what remains baked is the story rooms. The logic table already names them (`cooking`, `wet`, `toilet`, `dining`, `tv`…), and many pieces list
  other rooms (lamps, pictures, rugs, plants, clocks, mirrors, chests, bookcases, armchairs, backpacks, boxes) — those are the first things the next room type reuses.
* **Per-piece loot** (a nightstand holding pills, a toy chest holding toys) — loot is still by room type.

## Art pass 1 (owner round 47b — "bad, bad mspaint… more depth and detail… let's iterate")

The first-pass pieces were flat colour fills. What changed, and the method (so the next pass does the same):

* **A kit for volume** (`propkit.py`): spheres, cylinders and cones are lit by their own surface normal (a 5-tone ramp, light from the upper left), glossy things get a specular dash, every
  object is drawn on a scratch layer and given a **selective outline** (the darkened colour of what it surrounds, never plain black), and stands in a soft contact shadow.
* **Beds** (`bedding.py`): the cover's pattern (stripe, band, check, plaid, quilt stitching, stars, dots, patchwork) is drawn by mapping each pixel of the mattress top back to its place on the bed
  (the inverse of `pixlib.pp`), so it converges like everything else and is regular whatever the lean. Tucked / rolled edges, a turned-down sheet, creases, a lump over the feet, a front drape with folds
  and piping, a knitted throw with fringe, a plump pillow with a dent and a pillowcase border; a floor mattress is ticking with tufts and stains, with a real sleeping bag (baffles, zip, lining) on it.
  `furn.persp_bed` gained an optional `bedding=` hook (default None — the baked rooms are byte-identical). **There is no box under any bed any more**: the dark gap under the frame is what the
  `underbed` node searches. Variants are `<head>_<cover>` (`l_sage`, `r_plum`…).
* **Chairs and the horse are 3D** (`furn_seats.py`, `furn_medical.py`): `chair3d` renders a small model turned by a yaw, so a chair / child's chair / rocking horse / wheelchair has depth from any angle.
  The **beanbag is gone**; a wooden chair (ladder or spindle back, a cardigan sometimes thrown over it, at most one a room), a child's chair (painted) and a **rocking horse** (white, grey, brown — and a
  bloodied one in one variant of four) took its place. A new `vanity` slot kind keeps jewellery boxes, scent bottles and hairbrushes on dressing tables and chests of drawers (never a bookcase).
* **Redrawn**: all 12 things that stand on a surface; shoes, trainers, slippers, clothes, the rug, the backpack, the bedside crate, cardboard boxes, the ghost of a picture; the armchair (3D);
  the dolls' house (two storeys open at the front, four papered rooms with tiny furniture, one dark with a doll in it, a shingled roof and a brick chimney); the wardrobes (cornice, raised panels, escutcheons,
  a mirrored one with a gilt frame and a cracked variant, the child's with a scalloped pelmet and a stencilled star / moon) and the pill cabinet; the drip stand (cut to scale), the trolley, the
  plants, the bedside table, the crates with a camping stove.
* **Still first-pass (flat)**: the `bed_*` frames' headboards are still the legacy boards (the covers, pillows and frame outline are redone; a finial / spindle pass on the headboards is the one item left — `furn.persp_bed`'s defaults are shared with the baked rooms, so it needs a post-draw hook, not an edit to the default).
  Everything else on the first-pass list was redone in **art pass 2** below.
* Checks added: `furniture_test` — no bed variant is a "box" variant, every bed keeps a node to search, the beanbag is gone, the chairs / horse exist, and the vanity rule (mutation-checked: the host test fails
  if it is narrowed to chests only). **Test gotcha learned**: a SCRIPT ERROR inside a test function aborts it and the scene still prints "ALL PASSED" — only `tools/run_all_tests.sh` (which scans for it) is
  trustworthy; when running a suite by hand grep for `SCRIPT ERROR` too.

## Art pass 2 (owner round 47c — "Redo all still on the list that need upgrading")

Same kit, same method, one new file per family (the old definitions were cut out of `furn_bedroom*.py`; `furn_build.py` imports the new files):

* `furn_case.py` — **bookcase_low** (a crown, a dark back, thick boards with a shadow under each, books of every height with gilt bands and title dashes, one leaning, a pile lying flat, an ornament, bracket feet),
  **chest_drawers** (now 46×41: a lipped top, three raised-panel drawers with bail pulls and horizontal grain, a keyhole, bracket feet; the top drawer still pulls out on a search),
  **dressing_table** (a swivel mirror on turned posts with a thumbscrew each, a bevelled frame, glass with a dithered reflected-floor edge, a doily, two drawers, turned legs; new variant `dark_cracked`).
  `furn_wardrobes._mirror_glass` lost its checkerboard (a transparency-grid look at 6×) — a two-row dithered edge then a plain darker band; the mirrored wardrobe gets the same glass.
* `furn_kids.py` — **toy_chest** (still true perspective, bucketed: a lid thrown back with a stencilled star, planked front, iron corner brackets with rivets, a brass lock plate, a teddy, a block, a ball and a doll's stocking
  heaped inside, clipped at the front rim), **toy_shelf** (a painted board on little brackets, three lettered blocks, a plush bunny, a toy car), **block_tower** (lettered shaded blocks, a roof block), **ball** (a shaded rubber ball
  with a curved white band; limit 1 a room now), **rag_doll** (yarn hair, button eyes, an apron, striped stockings), **height_chart** (a paper tape of notches, pencilled marks fading with age, a name tab).
* `furn_floor.py` — **laundry_basket** (a woven wicker frustum with a loop handle each side, clothes heaped over the rim, a sleeve down the front), **clothes_rail** (a chrome frame on castors; garments — shirt, dress, coat, jumper,
  trousers — each lit, creased and outlined against the next; variants `a` / `b` hang different sets), **floor_stain** (an irregular tide-line with a darker rim, translucent so the boards show through).
* `furn_walls.py` — **frame_family** (oak moulding, mat, glint, three figures at the sea), **photo_wedding** (a sepia portrait in an oval mat, 29×33: veil, white dress, dark suit), **sampler_home** (cross-stitched HOME, flowers, a heart),
  **mirror_wall** (an arched frame, a gilt inner line, foxed silvering, a crest and cord; gilt and dark), **clock_wall** (a shaded rim, twelve marks, stopped hands), **wall_shelf** (a board on iron braces; books + a vase, or a plant + a photo
  + books), (**tally_marks** and **spray_nofood** were drawn here and removed in round 47i — see "Round 47i"), and the three **ceiling lights**
  (a flush glass bowl, a pendant on a twisted flex with a rose and a trimmed cone, a ribbed paper lantern).
* `furn_desk.py` — the teen's **desk_crt** body (a lit pine top over a dark kneehole with a pencil drawer, a pedestal of two raised-panel drawers each side with brass knobs, a plinth, a sticker); the CRT is still placed by its `post` hook.
* `furn_props.py` — **jewel_box**: the lid is now thrown back at an angle (narrowing toward the hinge) with a quilted lining and a little oval mirror — it no longer reads as a small TV.
* Checked: every redrawn piece at 8–10× next to its old self and in composed rooms (`bedroom_<style>.png`, 6 plans per style, 0 rule violations / 0 fallbacks); the scan reports 10 egregious findings, none of them
  a flat piece any more (a wasted bed sprite at the right-most bucket, three one-pixel specks, three few-colour marks on a wall).
* **Not done / owner's call:** the bed headboards (above); the LOOK in the editor at game zoom; the wedding portrait's faces are tiny (a 20×19 px window).


### Round 47d — covers, toys and clocks (owner: "the blanket on beds now appears too flat and even shiny; ragdoll, toy chest and blocks still need work; clocks look too flat")

* **Bed covers are matte cloth now** (`bedding.py`): the top is shaded from a HEIGHT FIELD (`Cloth`: a few long wrinkle ridges, a slumped hollow, a lump over the feet) lit from the upper left, quantised into the tone ramp with
  an ORDERED DITHER between neighbouring tones (`tone()`), capped so it never reaches the bright end of the ramp (that was the satin look), with a woven-thread grain and dull flecks; the front drape's folds are continuous (lit on the
  left of each fold, shaded on the right) instead of hard tone steps, the pale piping line is mixed into the cloth, and the mattress's own bright edge line is covered. Pillows use the same matte tone.
* `furn_toys.py` (replaces those three pieces in `furn_kids.py`): **toy_chest** (two shades of plank, grain, a label plate with TOYS stencilled on it, paint chipped back to the wood, a hasp, a heart sticker and star on the lid, a teddy's arm over
  the rim, toys heaped high), **block_tower** (3 variants — a tower with a roof and a knocked-over block / a bridge with a cylinder / a scatter with a cylinder on its side; real 3D wooden blocks with letters, numbers and animals), **rag_doll**
  (2 colourways: yarn braids with ribbons, button eyes, stitched smile, apron, one arm up, striped stockings).
* `furn_clocks.py`: **clock_wall** (a torus-shaded bezel, recessed face with the bezel's shadow on it, ticks, hands with shadows, a glass reflection, a wall shadow, a nail; brass / white / black), **clock_regulator** (a walnut Vienna regulator
  with a pendulum and weights) and **clock_cuckoo** (a chalet clock with the bird out and pine-cone weights). 80 pieces, 730 sprites.

### Round 47e — KITCHENS are planned rooms (owner: "expand to other module types too. Might as well do a big pass to fix the items while we have usage")

* **Five styles = the old five kitchens** (`kitchen/classic` A sage, `retro` B yellow + checker, `country` C brick range + terracotta, `student` D white units + camping table, `hoarder` E cream + stacks), five shells
  (`kitchen_shell_{a..e}`, `furn_shells.py` `kshell_*`, run looks + floor + floor_ext like the bedroom ones, `scenes/Room_Shells/kitchen_shell_*.tscn`). A story kitchen (breached / burnt / one of the dead) stays baked on the
  old module of the same style (recipe `legacy` 0..4), exactly as bedrooms do.
* **Pieces** (`furn_kitchen.py`, `furn_kitchen_small.py`; ~50 new, 120 pieces / 1334 sprites in all): a **worktop system** — `unit_base` (two-door / drawers / open-shelf-with-bucket), `unit_sink`, `unit_cooker` — drawn as real
  carcasses with a door finish per style (`FIN`: sage shaker, yellow retro, white, pine, cream; slab doors, handles, plinth, a worktop slab with a lit front edge), a tall fridge (cream / mint / white / white with its door open, magnets
  and a note), a larder, a brick **range recess** with a range cooker and copper pots (nodes: oven, pots), a Welsh dresser, a butler sink with a drainer, five tables (cloth / dinette with steel chairs / pine / camping / trestle).
  On the worktops (`on=('worktop',)` / `('appliance',)`, slot dy −31): a kettle, toaster, bread bin, canisters, a chopping board + knife block, utensil jar, a bowl of fruit, a tea set, a microwave, a radio, pans and a stockpot, a dish rack,
  stacked tins; on the floor: a mop bucket, bin bags, a recycling box, cardboard boxes (tins / bottles), a pet bowl, a gas bottle, newspaper bundles; on the wall: wall cupboards (`above=('unit',)`), spice / jar shelves, tea towels,
  a calendar, a pegboard, a clock (shared), notes; ceiling: strip light / pendant / bare bulb.
* **Planner additions** (all data-driven, all re-checked by `validate`): a recipe's **`run`** — a FLUSH run of units along the back wall (`count`, `must` tags such as `cold` / `cooking` / `wet`, an x window, `sides` = may run
  from the right) filled left→right so units touch; a recipe's centre may be **`anywhere`** (a table is not tied to a spot); a decor piece may declare **`above`** (a wall cupboard hangs only over a unit, never in the open); a variant
  may carry **`for: [styles]`** so a piece's finish belongs to a style (a sage unit never turns up in the retro kitchen). New logic: `cooking` is a kitchen-only tag, `wet` is kitchen + bathroom, `food` is kitchen + dining + living room (`TAG_ROOMS`; registration refuses a piece that breaks it); the window rule
  (nothing may reach above y 68 inside the window's box) is what keeps units, cookers and sinks to the walls beside the window.
* **Numbers:** 80 plans per style, 0 rule violations, 0 fallbacks; the five fallback layouts are each asserted valid with the window on the left AND the right. `furniture_test` now plans bedrooms AND kitchens (`PLANNED` / `UNPLANNED`
  room lists — a room moves to PLANNED when it is converted) and re-checks that no kitchen holds a bed.
* **Not done:** a few kitchen pieces are first-pass (the sink's inset basin is a flat steel strip; cooker rings / pans are small; the dresser's plates are tiny); kitchen D's dripping fridge (a live detail in the old art) is
  not carried over; the LOOK needs the owner's eye at game zoom.

### Round 47f — LIVING ROOMS are planned rooms (owner: "expand to other module types too")

* **Five styles = the old five living rooms**: `cosy` (A: green stripes + wainscot, gold sofa, red armchair), `mid` (B: teal, teak, a TV on a sideboard), `squat` (C: grey concrete, the wall TV, the pallet table, milk-crate shelves),
  `parlour` (D: rose paper, piano, china cabinet, floral sofa) and `lodge` (E: green + boarding, a hearth). Shells `living_shell_{a..e}`; the old `*_decor` (pictures, clocks, cameos, antlers) is gone from the walls — those are pieces now.
* **THE GUN CABINET'S living room is never planned** (`room._is_cabinet_room`, from `WorldState.gun_cabinet_slot`): the cabinet, its glass, its key and its looted looks are drawn into the baked `living_room_e`, so that one flat keeps it. The planned
  **lodge** style therefore has `legacy = -1` — a story lodge falls back to the hash's baked living room (never the cabinet's) — and `furniture_test._test_living` proves no other flat's baked living room is the cabinet module.
* **Pieces** (~25 new; 142 pieces / 1569 sprites): `sofa` + `loveseat` (3D models built from `chair3d` — arms, back, three seat cushions, turned feet — in 14 fabrics each tied to its style: gold / rust / olive, orange / mustard / avocado, a slashed grey or denim one,
  floral / green velvet / burgundy, oxblood / tan leather / tartan), `armchair` (the existing 3D one + red / brown / teal, tied to styles by `for`), `coffee_table` (walnut with a magazine shelf / teak kidney / pallet on cinder blocks / round mahogany tea table / strapped trunk),
  `pouf`, `sideboard` (teak / walnut / cream / oak — one door swings open), `tv_crt` (stands ON a sideboard; live snow, goes dark when searched) and `tv_wall` (the struck-TV live detail), `shelving_open` (mid-century), `crate_cubes`, `piano_upright`,
  `china_cabinet` (a door opens), `fireplace` (stone or brick, a grate, logs, embers; its mantel is a surface), `lamp_floor`, `side_table`, `magazines`, `ashtray_pack`, `guitar_stand`, `rug_large` (maroon / shag gold / green / blue / tartan), `log_basket`, `stag_head`,
  `cameos`, `print_hunting`. `furn_styles.py` adds the living styles to the shared bedroom pieces (a bookcase, a chest of drawers, clocks, plants, pictures, posters…) after they are registered.
* **Planner additions:** a `needs` may be `optional` and a CENTRE piece now asks for its needs (the sofa wants its coffee table, never at the cost of the sofa); a `flank` may be a front piece (an armchair flush beside the sofa); a floor piece's `lap` says how many rows it may overlap
  a body's drawn rect (a coffee table over the front of the sofa: 22; everything else 6); a rug's `under` tags let it lie under the sofa group, centred on it (`_rug_ok` skips those bodies). All carried by the piece records (`lap`, `under`).
* **Tests:** `furniture_test` PLANNED gains `living_room` (200 plans a style break no rule, 0 fallbacks, the fallbacks are valid for both window sides, real flats are built), `_test_living` (every room has a sofa, a coffee table only with a sofa, a CRT TV only on something, the lodge
  has its hearth, the parlour its piano or china cabinet, the cabinet's living room is never planned and no other flat shows it, a baked living room is the old module of its style).
* **Not done:** the old room's openings for living-room furniture (drawers / doors that open in the baked art) exist only for the pieces whose record has `opens`; sofa cushions / bookcases have no animation; per-run grime beyond the shell tint; the LOOK at game zoom needs the owner's eye
  (captured under xvfb: a lodge with its brick hearth reads well).

### Round 47g — DINING ROOMS, STUDIES AND BATHROOMS (owner: "expand to other module types too")

193 pieces / 1919 sprites, 30 recipes, 30 shells (`dining_shell_*`, `study_shell_*`, `bath_shell_*`). Every flat's room is planned now, except a story room (breached / burnt / holding the dead / the tutorial's flats) and the gun cabinet's living room.

* **Dining rooms** (family / diner / formal / barricade / party = the old A-E; `furn_dining.py`): `table_dining` is ONE piece that carries its chairs standing behind it (a lace-clothed family table with spindle chairs, a round sixties tulip table with two moulded chairs, a long bare
  mahogany table, a confetti birthday table with small chairs, or — for the barricade — one tipped on its edge), `clock_grandfather`, `trolley_drinks`, `portraits_row`, `planks_wall`, the party kit (`banner_party`, `balloons`, `gifts_pile`, `cake_party`, `party_hats`, `boombox`) and table things
  (`candelabra`, `vase_flowers`, `place_settings`, `bottles_row`, `record_player`); the sideboard / china cabinet / Welsh dresser are shared with the living room and kitchen.
* **Studies** (den / office / library / radio / studio; `furn_study.py`): `desk_study` carries its chair (a mahogany partners desk + leather chair, a grey steel desk + office chair, a walnut writing desk, a steel trestle, a painter's bench), `filing_cabinet` (the top drawer pulls out),
  `bookcase_tall`, `noticeboard`, `map_street`, `printer_stand`, `easel`, `canvases_leaning`, `paint_shelf`, `sketches_wall`, `waste_bin`, and desk things (`lamp_banker`, `typewriter`, `globe`, `papers_pile`, `computer_crt`, `radio_gear`).
* **BALCONY slots** (study and dining are the only types a balcony can take): the shell scene carries the same `Balcony` node the baked modules have (`tools/art/shells.py`), `room.furniture_plan_for` passes `blocked: [FurniturePlanner.balcony_box()]` (x 4..96, the box the old
  baked art kept its StripArt furniture out of) on a balcony slot (`side == ""`), so nothing stands, lies or hangs in the doorway — the rug and the ceiling light are exempt. The plan cache key already separated a no-window slot.
* **Bathrooms** (tub / avocado / gilded / wetroom / pink; `furn_bathroom.py`): the fixtures are the old bathroom's own 3D solids (`tools/art/bathroom.py` + `solid3d.py`: toilets, basins, the vanity and washstand, the clawfoot / gold / panelled / curtained / tiled baths, the walk-in shower, the
  washing machine, hampers, mop bucket, stool + radio, linen cupboard, mirrors, chandelier) lifted into BUCKETED front / floor pieces — they draw at the bucket's x on the module canvas and register the feet row the old art used, so they keep their perspective. The shower rail's ceiling stay
  stops at row 6 (`_Stay`: a planned piece may not reach above `TOP_MIN_Y` 5). The linen cupboard's right door swings open when searched (`opens`, door_h) — the only openable in a bathroom.
* **Planner additions:** `wall.planes` (a bathroom's fixtures are `["wall","front"]`), a decor piece's `above` may be a front piece, and a recipe's `wall.want` — tags TRIED (`WANT_TRIES` 4 spots) once the `must` tags stand, never a reason to fail the room (the wetroom's `must` is toilet + washing machine, its basin is a
  `want`; tub / avocado / pink `want` a linen cupboard). The wetroom is the squalid one: with the bath's 97 px curtain, the 70 px toilet and the washer, a right-hand window leaves 221 px, so its basin is often missing.
* **Data corrections found on the way:** a fallback layout may only use pieces its style allows (`light_bulb` / `ceiling_pendant` are not allowed in a barricade / party dining room or a studio — the three fallbacks use `ceiling_flush`; `light_tube` now lists `wetroom`); the old pill cabinet is a dark walnut cabinet and now stands only in the avocado and wetroom bathrooms.
* **Tests:** `furniture_test` PLANNED = all six room types (UNPLANNED is empty); `_test_balcony` (400 balcony-slot plans: nothing in the doorway box, the fallbacks valid there too), `_test_balcony_flats` (real flats on a balcony slot show the doors and keep the box clear), `_test_bathroom` (toilet, basin — except the wetroom —,
  the bath, the wetroom's washing machine), `_check_baked_is_style_module` (a story room is the old module of the planned style, for dining / study / bathroom).
* **Not done:** the LOOK at game zoom (checked as contact sheets and engine captures under xvfb only); bathrooms have only one openable; per-run grime beyond the shell's tint.

### Round 47h — COLOUR HARMONY, PAIRED PICTURES AND THE BALCONY PLANTS (owner: "make sure furnishings and decorations aren't too garish against modules… this bathroom is a bit too pink with the tiling and also the bathtub… the picture of the ship and the picture of the flowers aren't the same size, one flower is not in the pot… the plant pots on the balcony are all over the balcony, I'm concerned the player will clip into them")

* **Colour harmony.** `tools/art/colour_audit.py` composes every plan of a `furniture_dump` file onto its shell (the morning look: the loudest) and measures per room the VIVID share (saturation >= 0.60, value >= 0.50), the biggest share
  of one hue family, and which large pieces BLEND into the wall / floor behind them (same hue, saturation and lightness) or CLASH with it. What it found, and what was done (palettes live in the module art, so the baked story rooms and the planned
  shells change together — `build_all.py` → `furn_shells.py` → `openables.py` → `burnt.py` → `gen_module_blueprint.py` were re-run):
  * **Pink bathroom (E)**: pink fixtures on pink tile was a monochrome room. Now the classic fifties pairing — pink toilet / basin / tub on soft MINT tile with grey-green grout, black trim, the b/w floor (`bathroom.E_TILE`, `E_GROUT`,
    `E_TUB_GROUT`; the tub's body is `PINK`, no longer the tile colour). Pink is ~15 % of the room instead of ~45 %.
  * **Avocado bathroom (B)**: the orange lino was saturation 0.68 over the whole floor — now an earthy sand / umber (`B_LINO_*`), so the avocado suite is the one bright thing. **Country kitchen (C)**: the terracotta quarry tiles were 0.65 — muted.
    **Dining B (diner)**: the orange parquet softened. **Teen bedroom (B)**: blue on blue on blue (53 % of its colour in one hue) — the carpet is a warm taupe, the teal wall's complement.
  * **A colourway that vanishes into its wall is not used there** (`tools/art/furn_palette.py` `AVOID`, written into the variant's params as `not`): rose armchairs in the rose parlour, teal armchairs in the teal living room, the olive sofa / loveseat under the
    green wallpaper, the green filing cabinet in the green den, the mauve oblong rug on the mauve adult carpet, the cream sideboard in the cream party room. `FurniturePlanner.variant_ok` (the `for` list AND the `not` list) is read by `_vid` / `_any_variant_for` and re-checked
    by `validate_state`. `python3 tools/art/colour_audit.py --avoid` lists the candidates (large pieces only, the browns of wood and leather exempt, only where another variant exists).
  * **The gate** runs `colour_audit.py --check`: no shell wall / floor with saturation x value over 0.36 (before: 0.49 / 0.40 / 0.39), and no un-avoided blending variant. `furniture_test._test_palette` (olive sofa never in a cosy room over 120 rooms, a forced one is refused).
  * The rules of thumb used: a room has ONE dominant hue at most ~45 % of its coloured area, its main hue gets a complementary or neutral partner, large surfaces are muted (accent = small + saturated), a big piece contrasts with its wall in hue OR lightness.
    The audit tool prints the numbers per style; the LOOK is still the owner's call (contact sheets + xvfb captures only).
* **Paired pictures.** `sketches_wall` (the studio's two pinned drawings) was a 15 x 14 boat beside a 15 x 17 tulip sheet whose outer stems stood beside the vase: now two 15 x 17 sheets pinned at the same height, every stem inside the vase's mouth
  (`furniture_test._test_paired_pictures` — mutation-checked against the old sprite). **The newspaper front page** (`wallart.draw_newspaper` — REMOVED in round 47i with the EVACUATE / OUTBREAK notices it drew): with a strap line the
  photo is only 4 rows tall and the skyline towers ran up over "GO NORTH" / "STAY IN" — kept inside the photo now. All 46 wall-hung pieces were audited at 5x (`FURN_ALL=1 FURN_PREVIEW=… furn_build.py --only <decor ids>`); nothing else broke the rules.
* **Balcony plants.** A balcony's pots stood with their feet on module row 96, one row IN FRONT of the lane the player (and an enemy) stands on out there (row 95) — and the player is drawn over the art, so they walked through them; two 33-35 px
  ferns could fill the whole floor. Now (`room_growth.gd`): every pot / shrub's foot is on row 90 (`BAL_FLOOR_Y`, `BAL_LANE_GAP` 3 behind the lane, so whoever walks out is nearer than the pot and draws over it, as past a planter), pots are at most 30 px wide (`BAL_MAX_POT_W`;
  the ferns stay indoors, `BAL_POTS` / `BAL_DEAD_POTS`), and the vine from the lintel is the one short vine (`BAL_LINTEL_VINES` = `hang_3`, hung from row 17 so its foot is on row 46, above a head — which tops out near row 48, measured on a capture). `growth_test._test_balcony_lane` sweeps
  60 seeds x 3 runs x 3 floors (foot rows, widths, the two sides never meeting, the vine's foot) — mutation-checked with the old row.

* **Names (consistency rule, CLAUDE.md "Consistency and logic").** The armchair's turn variants were `l` / `r` (35 degrees) and `L` / `R` (58) — files that differ only by case, which overwrite each other on Windows / macOS (14 armchair colourways were affected). They are `l35 r35 l58 r58`
  now, and `furn_build.py` refuses any two sprite names that differ only by case; a repo-wide check found no other collision.

### Round 47i — THE ART MATCHES THE CONTEXT: A SUDDEN EVENT, HAPPENING NOW (owner: "we don't want anything related to outbreaks, so no newspapers etc saying evacuate or go north. This event is happening brand new so preparedness is not a thing… make sure that we have matching visuals to the context")
The rule (GDD §1, `tools/art/context_audit.py`): the art shows **reaction** (panic, blood, a barricade of furniture made in a hurry, HELP sheets, boards nailed up today) and **ordinary life interrupted** — never **preparation** (stockpiles, go-bags, supply lists, a survivors' radio room, a safe-zone map), **authority** (evacuation / curfew / quarantine notices, rescue marks, news headlines) or **elapsed time** (tally marks, MISSING posters, "NO FOOD"). The gate fails if a drawn word, a piece / variant / note, a sprite or decal name matches the banned list (`BANNED`; every row has a sample the selftest proves it matches, so a typo cannot let an idea through).
**Removed pieces (14):** `newspaper_evacuate`, `poster_outbreak`, `map_evac`, `missing_lucy`, `spray_nofood`, `tally_marks`, `note_stores`, `note_door`, `frame_ghost` ("taken when they left"), `planks_wall`, `crates_ammo`, `jerrycans`, `crates_stove`, `lantern_battery`; and the helpers that drew them (`wallart.draw_newspaper`, `draw_missing`, `draw_emergency_notice`, `biohazard`, `furn.newspaper` / `missing_poster` / `lantern`).
**Styles renamed to what they are:** bedroom `refuge` → **`bedsit`** (a young renter's room: a mattress on the floor, crates for a bedside, a clothes rail, a rucksack, moving boxes, a gig poster, a film one-sheet, the landlord's RENT DUE FRI! note), dining `barricade` → **`houseshare`** (a bare pine table, three chairs from three sets — new table variant `shared` replaces the tipped one — bin bags, a pizza box, moving boxes, a clock and a calendar). The `radio` study keeps its name: it is now a **hobbyist's** radio room (`radio_gear` is an amateur station; the new `map_street` is a town map with coloured pins where the owner has made contact with someone). The hoarder kitchen's notes are `note_cat_food` and `note_bills`. Plans: 60 each of bedsit / houseshare / radio / hoarder / squat → 0 rule breaks, 0 fallbacks.
**Baked modules** (story rooms still use them): bedroom D (a poster, a film one-sheet, a rent note; the crates carry paperbacks and a mug, no stove / lantern / cans), kitchen E (cat food, gas bill, calendar, ring the vet), dining D (a hurried barricade stays — it is *reaction* — but the tins and the camping lantern are a dropped handbag now; node `anchor_dining_lantern` → `anchor_dining_handbag`), study D (the SAFE route map, emergency notice, tinned-food rack, ammo crate + gas mask, jerrycans and army camp bed became a pinned town map, a framed certificate, a rack of component boxes, a cardboard box with headphones, a red tool chest + computer tower, a bookshelf; nodes `study_tins` → `study_parts`, `study_gas_mask` → `study_headphones`, `study_crates` → `study_boxes` (its lid animation follows), `study_map_table` → `study_log_table`).
**Corridor paper** (`wallart.CORRIDOR_PAPER`): `notice_evac` → `notice_fire_exit` (the standard sign), `notice_curfew` → `notice_parcels`, `notice_dont_open` → `notice_heating`, `notice_quarantine` → `notice_wet_paint`, `poster_missing` → `poster_lessons`; the corridor horror kind `door_x` (the rescue teams' search mark) → `door_scratch` (claw gouges through the paint — same slot in the table, so every seeded corridor keeps its draw order). The notices no longer escalate with the run: it is the same ordinary paper on every floor and every day.
**Kept on purpose (reaction, not preparation — say if you disagree):** blood and scrawls in the corridors (HELP, GET OUT, DONT GO DOWN, THEY HEAR YOU, NO WAY OUT, STAY QUIET), the opening exterior's HELP / SOS sheets, boarded windows and furniture-barricaded doors (people reacting through the day), breach rooms, the bloodied rocking horse (round 47b, owner's pick), the calendar that stops on the 12th (it is *today*), the hurried barricade in dining D, ordinary stacks of old newspapers (no headline).
**Not changed — for the owner:** quest 005 *The Prepper* (a man stocked for exactly this) and `STORE_DESIGN.md`'s "Outbreak is contained to the building" fiction line sit against the rule; the item descriptions and every authored line in `data/npc_dialogue.json` / `CharacterStory` were not audited (they are the owner's words).

## Numbers (so far)

142 pieces, 1569 sprites; 15 shells; 15 recipes (5 bedroom + 5 kitchen + 5 living room). (Round 47: 80 pieces / 730 sprites / 5 shells / 5 recipes.) 1000 planned rooms in the test: 0 rule violations, 0 fallbacks; planning costs ~16 ms a room on average (cached per flat+slot,
shared by the live room and its pan backdrop).
