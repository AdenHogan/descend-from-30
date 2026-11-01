# Module width 320 → 240 (owner round 49h)

**Owner decision (2026-11-01):** "I think it's necessary work. Those mock ups do look better with things less spaced out… even with adding more pieces to existing rooms won't improve the
spaciousness… Most modules really look sparse with too much wasted space. Begin the work, then later we can eyeball and readjust where furniture is… scavenge nodes will need some adjustments
too."  This **unlocks the room-module template** (`docs/blueprints/`, 320 × 144, `MODULE_WIDTH` = 320): a module is now **240 px wide** (−25 %), the height (144), every Y plane and the
scale of everything in it are unchanged.

## The mock-up that decided it
`living_room / cosy / module A`, 60 planned rooms at each width (the real planner, the real sprites, the current shell cropped to the central 240 px): pieces per room 14.6 → 12.2, pieces per
100 px 4.66 → 5.06, longest bare wall stretch 45 → 32 px on average (115 → 79 worst), wall line covered 72 → 74 %. One screen frames ~160 px of height, so it shows ~284 px of width at 16:9
and ~373 px at 21:9: at 320 a module never fits one screen, at 240 it does (the "empty on a big screen" feeling). Feasibility of the planner's recipes at 240 (30 plans a style): all living
styles, dining, study and most bedrooms fit; **retro kitchen and the pink / gilded bathrooms are strained; country kitchen (15/30), avocado bathroom (30/30), wetroom (12/30) and teen
bedroom (6/30) fall back** — those recipes need re-tuning, not just a crop.

## The design: one design canvas, a central frame
Everything the art tools draw still lives on the **320 px design canvas** (vanishing point x 160, the floor / set-back / lean-bucket maths all assume it). A module is the **central 240 columns**
(`PAD` 40 each side): *module x = design x − 40*. The perspective, the lean buckets and the planner's maths stay valid because the frame is symmetric about the vanishing point; the
module's VP is its own centre (120). A piece that stood in the outer 40 px of a baked room is out of the room and has to be moved in or dropped.

* `tools/art/pixlib.py`: `W, H` (design canvas) / `PAD` / `MW` (the module) / `WIN_INSET` / `frame(img)` / `to_module(pts)`. `finish_module` runs every check on the whole design canvas, **then**
  converts to module space (anchors, lights, anims, flat / floor pieces, every image) and every export — art, floor strip + `_floor_ext`, strip / front / over layers, nest overlays,
  growth skylines, baked-object report, run looks, the scene — is written at `MW`. Downstream tools take the width from the image / `pixlib.MW` (never a literal 320).
* **Windows**: a module's wall window is at module x 54 (left) / MW − 54 (right) (the same share of the width as 72 / 320; `WIN_INSET`), i.e. design x 72..116 / 204..248 — the baked rooms must
  keep *those* boxes bare (the existing `check_window_boxes` enforces it from `WIN_L` / `WIN_R`).
* The checks are the to-do list: a room that fails `finish_module` at `DFT_PAD=40 DFT_WIN_INSET=54` lists exactly what is outside the frame (nodes, lights, live details), in a window box, or on
  the edge sample columns.  (`DFT_PAD` is an experiment switch while the change is built; the committed default is flipped once every room passes.)

## Phases (tasks 185-189)
1. **Plumbing, no behaviour change** (done): the frame above with `PAD` 0 — regenerating all 30 modules at PAD 0 leaves every asset byte-identical (checked with `git status` after
   `build_all.py`).
2. **Planned rooms**: shells = the frame of the design shell; planner `MODULE_W` 240, `EDGE_L` 4, `EDGE_R` 235, window inset 54, mirror about 120; recipe x ranges (authored in design space) are
   shifted by `PAD`; the lean bucket is chosen from the distance to the module centre (+ `PAD` back into design space); re-tune the strained styles; `furniture_test` bounds follow.
3. **The 30 baked rooms** (story rooms, the tutorial flats, the gun-cabinet living room, `legacy` fallbacks): per room, move the pieces in the outer 40 px inward or drop them, move the
   anchors / lights / anims with them, keep ≥ 2 FRONT nodes, keep the gun cabinet and the tutorial's nodes; openables (`openables.py` rects shift by `PAD`, `VPX` = 160 − `PAD`), burnt art,
   nest overlays, growth meta and the blueprints regenerate.
4. **Runtime**: `room.gd` `MODULE_WIDTH` 240 (`LEFT_WALL_X` stays 113), `MODULE_WINDOW_INSET` 54, `module_walls.gd` `MODULE_W`, `balcony_pan.gd`, `room_growth.gd` `W`, `resident_npc.gd` /
   `world_state.gd` / `quests.gd` far-end placements, the breach pack and riser spots, balcony centre (`BalconyGeo`), the shell and camera fit; tests; docs (`docs/Y_PLANES.md`,
   `docs/blueprints/README.md`, CLAUDE.md "Scene dimensions"); the full gate.

The flip (changing the committed `PAD`) is **one commit**: assets, scenes, planner, runtime and tests move together, because a flat's rooms must all be one width.

## Not decided / owner's eye
Where each piece ends up in a baked room is a first pass (the owner will eyeball and adjust); the planned rooms' recipes need the same look; scavenge-node positions of baked rooms move with
their pieces and need a play-through; module width could still be tuned (the frame is one constant).

## Where the work stands (updated as it goes)
* **On `main` (pushed):** steps 1 and 2 above — the plumbing, still at 320, no behaviour change (`2c6871f6`, `2c54e073`).
* **The flip is built in a LOCAL git worktree, `/home/user/flip` (branch `flip-240`, never pushed)** so `main` keeps working: constants flipped (`scripts/module_geo.gd` `WIDTH` 240 / `DESIGN_PAD` 40 / `WINDOW_INSET` 54; `tools/art/pixlib.py` `PAD` 40 / `WIN_INSET` 54), shells regenerated at 240, tests that hard-coded 320 read `ModuleGeo`. It lands on `main` as ONE squashed commit when the gate passes. **If the container is fresh that worktree is gone: redo steps from "Planned rooms" below** (the recipe / planner changes are small and listed here).
* **Window inset 54** (the proportional one) after measuring 54 / 60 / 66 on the planned rooms: a bigger inset roughly doubles the styles that cannot be laid (kitchens and bathrooms run fixtures along the wall and the window box is a keep-out), a smaller one starves the baked rooms' end zones (28 / 87 / 27 px of wall where tall furniture may stand, because the baked art keeps BOTH window boxes bare).
* **Planned rooms at 240** (30 plans a style): living, dining, study and bedrooms lay with 0 fallbacks; the wet rooms needed planner / recipe work, all small and measured with `tools/furniture_dump.tscn`:
  * `centre.mirror` (planner): the centre piece's x range is for the left wall and a seeded half of the rooms stand it against the right one; bathrooms use it (a bath against a wall leaves a run for the toilet and basin).
  * a bathroom's centre is `bath|shower` (a walk-in shower is allowed in the avocado / pink styles too).
  * `sill` (a piece flag, planner `_sill_allow`): a basin / vanity / washstand may rise into the bottom of the window box (a basin under a bathroom window), unlike `under_window` it is not required to stand there.
  * country kitchen's run may start further in (`x` 60..190 design).
  * `furniture_dump -- --fallbacks=1` validates every recipe's hand-set fallback with the window on either side (25 broke at 240: they are authored in design coordinates and several stood in the outer 40 px).
  * `furn_build.py --recipes` rewrites only the recipes / module meta of `data/furniture.json` (no sprite is rendered) for quick tuning; a plain run and `--check` stay the truth.

## Update, 2026-11-01 (the baked rooms are fitted; the runtime and the gate are what is left)
* **All 30 baked rooms pass the frame checks** at `PAD` 40 / `WIN_INSET` 54 (nothing in the outer 40 columns, both side-wall sample columns bare, the declared window box bare, a balcony slot's strip bare in the main art, every node inside the frame). Each room declares ONE wall for its window (`finish_module(window='L'|'R')`, written to `assets/rooms/window_sides.json`): kitchens A/C/D/E, living rooms and bedrooms B-E are right-hand, the study and dining rooms (their balcony strip is on the left) left-hand, bathrooms A/D/E left and B/C right. First-pass layouts — the owner's eye comes next. Pieces that did not fit were moved in or dropped (bathroom B lost its mop bucket and hamper, D its laundry basket, E its vanity stool; dining E's table is shorter and has two back chairs and no end chairs).
* **Runtime window side** (`WorldState.window_side_of`, `Room.baked_scene_for`): a flat's window goes on the wall its BAKED module left bare — a planned room uses the side of the baked module it would be as a story room, so a flat's window never changes wall between runs.
* **Balcony layers** are cropped to the 240 module (their content lives in the first ~100 px). **Openables** (`tools/art/openables.py`) now work on the padded design canvas with a per-opening shift table (`openables_shift.json`, the anchor's move between the old and new scenes): 43 of the 54 survive; these 11 were dropped because their piece left the frame or no longer matches (`bedroom` wall_right_lower, `bedroom_c` wardrobe, `bedroom_e` small wardrobe, `kitchen_b` formica table, `kitchen_c` dresser drawer, `kitchen_e` bag table / buried counter / cat tins, `study_d` handset, `dining_room_b` / `_c` right drawers) and their nodes get the generic dust-and-sound reaction. Six more went with nodes that were dropped (`dining_room` trolley, `living_room` right chair, `living_room_d` cabinet cupboard + china cabinet, `study` filing, `study_d` boxes). **Blueprints** (`gen_module_blueprint.py`) draw the 240 module with module-local window boxes.
* **Still to do before the flip lands on main:** the runtime scripts and tests that bake in 320-wide flats (the breach pack's far end, the "nearest body >= 490 px" rule, the tutorial's 3003, quest / resident / hider placements, camera fits), `nest.py` / growth meta / blueprint regeneration order, `furniture_test` on the 240 module, `furn_build.py --check` / `furn_shells.py --check`, the full gate (`SUITE_TIMEOUT=900`), docs (Y_PLANES, blueprints README, CLAUDE.md "Scene dimensions"), and the single squashed commit. The flip lives ONLY in the local worktree `/home/user/flip` (branch `flip-240`, never pushed): a fresh container loses it.

