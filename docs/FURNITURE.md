# FURNITURE AS ASSETS — rooms that are laid from a seed

**Status: BUILT v1 for BEDROOMS (owner round 47, 2026-10-20) and KITCHENS (round 47e).** Living rooms, dining rooms, studies and bathrooms are still baked modules; the same pipeline is
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

The old five bedrooms A–E are five **styles** of one room type: `adult` (A), `teen` (B), `sick` (C), `refuge` (D), `kid` (E). A style is a recipe
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
tools/art/furn_bedroom.py   shared + adult pieces      furn_bedroom_b.py teen   _c.py sick   _d.py refuge   _e.py kid     (the first-pass pieces that have NOT been redrawn yet — see "Art pass" below)
tools/art/propkit.py        shaded primitives (sphere / cylinder / frustum / slab, tone ramps, selective outline, contact shadow) — what makes a small thing look round
tools/art/bedding.py + furn_beds.py   every bed: covers drawn IN PERSPECTIVE (pattern mapped back onto the mattress plane), pillows, folds, throws, mattress + sleeping bag
tools/art/furn_props.py, furn_props2.py, furn_more.py   the small things (lamps, clock, books, suitcase… shoes, clothes, rug, backpack, crates, boxes, plants, bedside table)
tools/art/furn_seats.py     the chairs + rocking horse as little 3D models (chair3d.py renders them)     furn_medical.py  drip stand, wheelchair (3D), trolley
tools/art/furn_dollhouse.py, furn_wardrobes.py   the dolls' house; the wardrobes + pill cabinet
tools/art/furn_rooms.py     the recipes (shape of each style) + the rules export
tools/art/shells.py, furn_shells.py   the bare rooms
tools/art/furn_build.py     writes assets/furniture/*.png (+ open/ strips), data/furniture.json, docs/art_reference/furniture/pieces.png     [--check = the gate]
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
* **Other room types** — bathroom, study, living room, dining room (the kitchen is done, round 47e). The logic table already names them (`cooking`, `wet`, `toilet`, `dining`, `tv`…), and many pieces list
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
  + books), **tally_marks** (grooves with a pale chipped lip, dust below, two struck-through fives and three singles), **spray_nofood** (a faint overspray halo, wet highlights, a long run ending in a bead), and the three **ceiling lights**
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

## Numbers (so far)

120 pieces, 1334 sprites; 10 shells; 10 recipes (5 bedroom + 5 kitchen). (Round 47: 80 pieces / 730 sprites / 5 shells / 5 recipes.) 1000 planned rooms in the test: 0 rule violations, 0 fallbacks; planning costs ~16 ms a room on average (cached per flat+slot,
shared by the live room and its pan backdrop).
