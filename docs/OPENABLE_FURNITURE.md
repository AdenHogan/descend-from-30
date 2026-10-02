# Openable furniture — searched things change (owner round 34)

> "In This War of Mine, when you search a piece of furniture, many pieces of furniture change appearance when you're
> done. The drawer opens, for example, or a door swings open. Let's focus on the tutorial floor first… if we can get it
> working visually we can roll out to more modules."

**BUILT v1 (10 openings on the base modules).** The module art is one baked picture, so an opened look is a **patch**
laid over it once the node on that furniture is searched.

## Pipeline (`tools/art/openables.py`)
1. Reads the finished `assets/rooms/<art>[_r2|_r3].png` — so a patch always matches the aged art it sits on.
2. Draws the furniture opening in **true perspective**: the room is drawn from the ceiling line over x 160, so a point `E` px
   nearer the camera lands at `(160 + (X-160)s, Y s)`, `s = (BASE+E)/BASE` (`P()`; same map as `pixlib.pp`). Each moving part
   (a drawer front, a hinged door, the oven's drop-down door) is a flat rectangle moved through that map and warped by the
   homography of its four projected corners (`warp()`, nearest-neighbour, pixel art). A drawer also shows its open top and the
   side that faces the room's middle; a door reveals a cavity (`fill_cavity`: lit fridge with shelves + food, dark cupboard,
   oven with racks).
3. Writes `assets/rooms/open/<art>__<anchor>[_r2|_r3].png` (3 frames side by side; the last is the rest state) and
   `open_meta.json` (`{art: {anchor: {x, y, w, h, frames}}}`). Only CHANGED pixels are opaque.
- **Edge limit:** a hinged door's free edge moves toward the camera and so AWAY from the room's middle: a fridge at the left
  edge can only swing ~33° before it would leave the module (it is edge-on to the camera at ~37° anyway). Pick the door /
  drawer that stays inside (the sideboard opens its LEFT door).
- `python3 tools/art/build_all.py` first, then `python3 tools/art/openables.py [--preview]` (writes
  `docs/art_reference/open_furniture.png`, closed vs open for each). The gate runs `openables.py --check`.

## Runtime
`scripts/open_furniture.gd` (a `Sprite2D`, group `open_furniture`): `attach(module, apartment, run)` (called from
`room._build_modules`, live + balcony backdrop) adds one per anchor listed for that module's art, right above `Art` and below
the orbs; hidden until `WorldState.is_anchor_searched`. `loot_ui._reveal_item` → `on_searched` plays the frames (0.085 s each)
once; a re-entry / load shows the rest state. A module with no entry attaches nothing. Nothing is saved (it is a view of
`searched_anchors`). Run 2/3 use their own sheets (fall back to the run-1 sheet).

## Openings (base / variant-A art)
living_room: dresser top drawer (`anchor_right_chair`) · bedroom: nightstand drawer (`anchor_bedside`), wardrobe drawer
(`anchor_wall_right_lower`), under-bed drawer (`anchor_floor_underbed`) · study: desk drawer (`anchor_study_desk_drawer`),
filing drawer (`anchor_study_filing`) · kitchen: fridge (`anchor_centre_fridge`), oven (`anchor_centre_oven`) · dining_room:
sideboard drawer (`anchor_right_upperdrawers`) + door (`anchor_right_lowerdrawers`).
The tutorial flats (3002-3005) use the base modules, so these are what the first run shows.

## Rolling out
Add an entry to `OPENINGS` (rect of the front, kind, depth / angle, contents) — nothing else; the variants B-E and the nodes
that sit on open shelves / cushions / sacks are still static. Candidates: bathroom cabinet, bedside tables in other variants,
toilet lid, laundry sack, sofa cushions. Not built: a drawer / door sound (the doors' `doorOpen` set would do), a tween for the
open frame's light, openings that survive a breach "nest" overlay being drawn over them (the overlay draws above).
