# ROOM-MODULE BLUEPRINTS — the locked template

**LOCKED** (owner round 13c): this folder is THE template for apartment room modules and their
scavenge nodes — for us and for any artist we bring in. It shows exactly where things may be drawn,
where the player stands and steps up, and where the nodes go. Every file here is **generated** from
the real rooms and checked by the pre-commit gate (`tools/run_all_tests.sh` runs
`python3 tools/gen_module_blueprint.py --check`): a room change that isn't reflected here, or a
step-up spot that something blocks, fails the gate. Never hand-edit these images — change the room,
then run `python3 tools/gen_module_blueprint.py`.

## What's here

| file | what it is | use it for |
|---|---|---|
| `template/module_template.png` | the blank module, annotated: every plane, every zone, the player to scale | read first: where things go |
| `template/module_template_balcony.png` | the same for balcony-capable rooms (study, dining room), with the balcony strip | those two room types |
| `template/module_guide_1x.png` | a **320 × 144 transparent guide layer**, pixel-exact | put it on a layer in your editor over your canvas |
| `template/module_guide_balcony_1x.png` | the guide layer with the balcony strip | study / dining room |
| `rooms/<type>/<module>_blueprint.png` | every existing room (30): its art dimmed, planes, nodes, step-up spots checked | worked examples, and a record of each room's node layout |
| `rooms/<type>/<type>_sheet.png` | a room type's five variants on one page | comparing variants |

## The canvas

- A module is exactly **320 × 144 px**, origin top-left. Three sit side by side in an apartment;
  in the world a module sits at `(113 + slot × 320, 224)`, so **world y = local y + 224**.
- One art pixel = one game pixel (native scale, no upscaling). Fully **opaque** — no transparent
  pixels in the room art (they show as grey in game).
- The view is straight on, looking slightly down: depth recedes UP the screen (a table shows a top
  of ~5 px). Light from the top left, simple form shading, no painted light sources or glows — the
  engine adds real light (windows, lamps, fire) on top.
- The player is **58 px tall with a 28 px body** (measured from its sprite); enemies are taller.
  Doorways, furniture and headroom are sized around that.

## The Y planes (module-local; world = local + 224)

| local | world | plane |
|---:|---:|---|
| 0 | 224 | ceiling / back-wall top |
| 23 | 247 | interior doorway lintel |
| 10–66 | 234–290 | the two WINDOW BOXES (L x 50–94, R x 226–270) — **bare wall** |
| 40 | 264 | node line — no scavenge node above it |
| 100 | 324 | wall / floor seam — where SET-BACK furniture stands |
| 104 | 328 | BALCONY plane feet (study / dining, on a balcony slot) |
| 102–114 | 326–338 | STAND ZONE — bare floor in front of every back-plane node |
| 114–122 | 338–346 | FRONT furniture bases (sofas, beds, tables, chairs) |
| 115 | 339 | BACK PLANE feet — the player steps up here (drawn × 0.89) |
| 128 | 352 | interior floor |
| 129 | 353 | WALKING LANE feet — every actor stands here |
| 123–144 | 347–368 | the walking lane — keep clear; only flat things (rugs, stains) |
| 136 | 360 | front cut plane |
| 144 | 368 | module bottom |

## Kept bare (the art pipeline refuses the room otherwise)

- **Window boxes** L (50,10)–(94,66) and R (226,10)–(270,66): plain wall — the game draws a window
  in one of them.
- **Wall-face sample columns** x 3 and x 316, rows 0–99: plain wall — the side walls are painted in
  perspective from these columns.
- **Balcony strip** (study, dining room only) x 4–96: the main art is bare wall and floor there; the
  strip's furniture is delivered as a separate layer, because a balcony door replaces it.
- **Stand zones**: rows 102–114, ±13 px either side of every back-plane step-up spot, bare floor.

## Scavenge nodes

Each node is a point ON a drawn piece of furniture, at y ≥ 40. Three kinds:

- **FRONT** (gold) — on furniture standing out toward the lane; searched from the walking lane.
  **At least 2 per room.**
- **BACK PLANE** (blue) — on SET-BACK furniture against the wall (shelves, dressers, cabinets). The
  player steps up to it (feet 115). Nodes ≤ 40 px apart share one step-up spot, centred on the
  nodes that spawned — so keep **every front piece out of the stand zone** in front of them.
- **BALCONY STRIP** (green) — study / dining room only: on the strip's furniture (x 4–96).

A room typically has **5–8 nodes**; one visit activates only some of them (`room.gd`
ANCHOR_RANGES: 2–5, study and dining 2–4). Name each `anchor_<roomtype>_<thing>` (e.g.
`anchor_study_printer`) — loot is seeded by the name, so names are unique within a room type.

## Layout rules (owner rounds 9–13)

- **Spread it out**: one piece every ~50–60 px across the whole 320, so the nodes spread with it.
  Don't pile the furniture into one end. Leave a lamp or plant out rather than squeeze it in.
- **Loose things never stand alone mid-floor** (bags, boxes, bottles, toys, papers): against the wall
  or with the furniture they belong to (clothes at the foot of the bed, a basket on a table).
- **Seating faces something**: a room with a TV has the set centred on the back wall and the sofa
  facing it from in front, its back to us; without a TV the sofa faces the room and an armchair sits
  across the coffee table from it. Sofas are always drawn straight, full width. Turned armchairs and
  office chairs are built in 3D (`tools/art/chair3d.py`) so the angle is right.
- **Nothing that stands behind a front piece carries a node** — the player couldn't step up to it.
- No throws or blankets draped over sofas; fireplaces and other symmetric pieces are drawn
  mirror-exact.

## What an artist delivers, per room

1. `<type>_<variant>.png` — 320 × 144, opaque, drawn over the guide layer.
2. `<type>_<variant>_floor.png` — the FLOOR ALONE, rows 100–143 (320 × 44), repeating every 32 px
   across (it's tiled where two rooms meet at a doorway).
3. Study / dining only: `<type>_<variant>_strip.png` — 320 × 144, transparent except the strip's
   furniture (x 4–96).
4. A node list: `name, x, y, kind` (front / back / strip), in the room's local pixels.
5. Optional: run-2 / run-3 versions of furniture that changes (a chair knocked over). The run looks
   (damp, cracks, mould, debris) are aged automatically by our pipeline from the run-1 art.

We bring the art in through the room pipeline (`tools/art/`, `pixlib.finish_module`), which checks
every rule above, writes the room scene, and then these blueprints are regenerated. The rest of the
art brief (tone, palette, lighting, naming) is `docs/ART_REQUIREMENTS.md`.
