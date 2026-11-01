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
