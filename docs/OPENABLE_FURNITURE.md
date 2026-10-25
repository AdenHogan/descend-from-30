# Openable furniture — searched things change (owner round 34)

> "In This War of Mine, when you search a piece of furniture, many pieces of furniture change appearance when you're
> done. The drawer opens, for example, or a door swings open. Let's focus on the tutorial floor first… if we can get it
> working visually we can roll out to more modules."

**BUILT v1 (10 openings on the base modules) + 7 on other variants (owner round 45) + round 45c: 60 specific animations, a reaction on EVERY node, played at the press (see "Round 45c" / "Round 45d" below).** The module art is one baked picture, so an opened look is a **patch**
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

## Openings on the other variants (owner round 45: "more furniture items need to open up when interacted with")
Seven drawers, each read off the finished art and checked in `docs/art_reference/open_furniture.png`: bedroom B's desk pedestal
(`anchor_bedroom_desk_drawer`), bedroom C's bedside chest (`anchor_bedroom_pill_cabinet`), dining B's sideboard lower drawer
(`anchor_right_lowerdrawers`), dining C's sideboard upper drawer (`anchor_right_upperdrawers`), kitchen C's pine-dresser drawer
(`anchor_kitchen_dresser_drawer`), living D's china-cabinet drawer (`anchor_living_cabinet_cupboard`), study B's desk drawer
(`anchor_study_desk_drawer`). **Tried and dropped:** bedroom E's small wardrobe door — it stands at the room's right edge, so a
hinged door swung to the camera covers the other door and the cavity never shows (the "edge limit" above); it needs a design
decision (sliding doors? open from the other side?) before it is worth baking. Pieces on the balcony STRIP (dining B / C's
cabinets at the left) are not in the main art PNG, so `openables.py` cannot read them yet.

## Rolling out
Add an entry to `OPENINGS` (rect of the front, kind, depth / angle, contents) — nothing else; the variants B-E and the nodes
that sit on open shelves / cushions / sacks are still static. Candidates: bathroom cabinet, bedside tables in other variants,
toilet lid, laundry sack, sofa cushions. Not built: a drawer / door sound (the doors' `doorOpen` set would do), a tween for the
open frame's light, openings that survive a breach "nest" overlay being drawn over them (the overlay draws above).


## Round 45c — nodes react the moment you press interact (owner)
> "More things should move when a node is scavenged. Also the movement animations should happen when the player presses interact to begin the
> scavenge of the node, not after… Every node, if it makes logical sense, should have an animation: search a table and a glass falls over, search
> the oven and the oven door opens, search a computer and the static or screen turns off."

- **When:** `Interactable.on_search_begin()` (from `loot_ui.open`) — at the press. It notes `WorldState.opened_anchors` (saved; "apt:anchor"), plays the
  node's `Open_<anchor>` patch (`open_furniture.play`) or, with none, the generic reaction. `is_anchor_opened` = pressed OR searched, so a search
  walked away from leaves the drawer open and an old save (searched only) still shows its drawers open. `loot_ui._reveal_item`'s old call stays as a
  no-op safety.
- **Generic reaction (all 205 nodes, `node_reaction.gd`):** dust / lint / paper specks (`dust_puff.gd`) + a positional sound by MATERIAL, read from the
  anchor's name (`MATERIALS`: paper, cloth, metal, ceramic; else wood). Sounds are generated (`tools/gen_node_audio.py`).
- **Specific kinds** (`openables.py`; each has a sound in `NodeReaction.KIND_SOUNDS`): `drawer`, `door_h`, `door_drop` as before; **`lid`** (top squashes
  then the underside stands over the back edge — hamper, box, record player, pizza box; `inside` / `under` / `items`), **`topple`** (a small standing
  thing tips about its bottom corner, 90° over `f^1.6`), **`shift`** (a small thing slid / knocked: dx, dy, deg, hump), **`screen_off`** (4 frames: the
  picture squashes to a bright band, a line, a dot, dead glass with a sheen; the live static / TV / blink under it stops — `module_anim.screen_off`).
  `topple` / `shift` find the object with `object_mask`: `fg=[colours]` (best against a busy backdrop) or `bg=[points|colours]`; the object is
  FOUND on the run-1 art and its pixels TAKEN from the run's own look (the aged colours differ), the pixels it leaves are filled from the backdrop along
  the row (`fill_vacated`), and rotation is sampled with four sub-pixel taps so 1-px sticks survive a tilt. **Gotcha:** a `bg` sample point that lands
  ON the object makes the mask empty (the first dining-trolley bottle did nothing) — prefer `fg`; and check every spec on a contact strip.
- **Placement rule (test):** drawers / doors sit ON their node's furniture (patch ±6 px); tipping things, screens and lids sit within 30 px sideways of the
  node of the piece they belong to (a glass on its table, a TV over its sofa — the sofa's node turns the TV off: "you find the remote").
- **Coverage:** `51 / 205`. By module: kitchens (ovens B/C/E, microwave, pizza box, cup, jars), bathrooms (vanity, cabinet, hamper, champagne), bedrooms
  (3 wardrobes, trolley bottle, block tower, CRT, boxes), dining (trolley, vase, candelabra, party hat, record-player lid, clock case), living (coffee-table
  mug, tea set, 2 TVs), studies (lamp, brush jar, CRT, monitor). Everything else: generic reaction.
- **Not done:** beds' pillows / sofa cushions / toilets' lids (ambiguous in the art) / bookcases' books (the colour mask failed on busy shelves); real
  particles with weight; a tilt-and-rest for the chairs.

## Round 45d — more to interact with when you search (owner: "add more interact features to searching nodes")
- **Swing and rock** — `shift` gained `path` (an explicit `(dx, dy, deg)` for every frame; the last is where it rests) and `pivot` (`top` for something hung
  from a rail, `bottom` for something stood on the floor, else `center`): the clothes on bedroom D's rail and bathroom C's towel sway, study D's red tool chest (was a jerrycan)
  rattles; a teddy bear (bedroom E) topples off its bed, a china cabinet's glass door (living D) swings, a crate lid (study D) lifts, a bag (kitchen E) falls
  over, a can rolls. **60 specific animations** now (51 + 9; tried and dropped: kitchen C's pine-dresser door — the diamond-pattern front warps to noise).
  Specs live in `OPENINGS_45D` (the 45c ones in `OPENINGS_45C`) — keep one entry per art, the later dict replaces by anchor.
- **A sound of its own** (`NodeReaction.SPECIAL`, by anchor name; `not` excludes — toilet ROLLS, a sink CUPBOARD): toilets / thrones a ceramic lid + the
  cistern trickling, sinks / basins / taps / tubs / showers a tap squeak and running water, a piano a hand on the keys, the grandfather clock tick-tock + chime,
  a radio / handset tuning static, the microwave three beeps, the fridge a seal letting go, the printer a whir and feed, a record player / record shelf a needle
  dragged, a beanbag letting out its air, sofas / armchairs / mattresses creaking springs, a rocking horse / toy chest squeaking, a wheelchair / trolley
  rattling on its wheels (19 new generated files, `tools/gen_node_audio.py`). In place of the material sound on a generic node (`puff` says whether the dust
  stays); `also` means it plays alongside a SPECIFIC animation (the microwave opens AND beeps, the clock's door opens AND it chimes, the radio's screen
  dies AND it hisses). 57 nodes have one.
- **Something small bolts out** (`scripts/node_critter.gd`, `NodeReaction.critter_for` / `startle`): about `CRITTER_CHANCE` 14% of the nodes that could hide
  one — a RAT from piles / bags / boxes / bedding, a ROACH from damp and food places, a MOTH from a wardrobe or a clothes rail — let one out on the first
  press: it freezes a beat, then runs away from the player across the floor (rat, roach) or flutters up (moth), a squeak, gone in ~1.5 s. Decoration only:
  a plain Node2D, no body, no group, drawn in code. Seeded per (game, flat, node, run) so a re-entry never replays it. A test that counts what a press
  produces must use a node whose NAME can't hide one (the generic-reaction test uses `bath_left`).
- **Checked in the real engine** (xvfb, a scratch scene that rendered a module at game zoom and played a reaction): kitchen B's larder jar tips, its oven
  drops, the rat runs. The rest are contact strips + headless tests.

## Round 48k — `unroll` (the toilet roll)

A planned piece may open with the kind **`unroll`**: the toilet's `opens={'kind': 'unroll', 'frames': 4, 'anchor': 'toilet_rolls'}` redraws the whole piece per frame with `p['open']` 0..1 driving how much paper hangs
(`BR.toilet_roll(..., sheet=0.3 + 0.7 * open)`), exactly like a drawer. Pressing interact on `anchor_bathroom_toilet_rolls` plays the frames (`open_furniture.play`), with `NodeReaction.KIND_SOUNDS["unroll"]`
(`unroll_0.wav`: the spindle ticking as it slows, the sheet rasping off, a tear); the longer sheet is the rest state afterwards. `NodeReaction.material_for` calls a `toilet_roll` node paper (the toilet's special
cistern sound still excludes it). Only the three toilets that hang a roll (white / avocado / pink) have the node. Tested by `open_furniture_test._test_toilet_roll` (the drawn paper grows frame by frame).
