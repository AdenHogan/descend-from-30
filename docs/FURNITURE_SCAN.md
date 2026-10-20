# FURNITURE SCAN — what looks wrong in the new furniture library (round 47)

Run: `python3 tools/art/furn_scan.py [--sheets DIR]` — read-only: it checks every piece's sprites + record (a node standing in empty air, a slot with nothing under it, clipped sprites, stray
specks, flat shading, missing outline, illegible size, feet off the feet row, lean glitches between buckets, duplicate variants, low contrast against the usual wall) and prints a ranked list.
`--sheets` also writes a 3× review sheet per plane (`docs/art_reference/furniture/scan_<plane>.png`). The automatic pass finds the technical faults; the rest below is from LOOKING at every piece
at 3× and in the composed rooms (`bedroom_<style>.png`). Nothing has been changed yet — this is the backlog.

## Egregious (fix first)

| # | Piece | What is wrong | Suggested fix |
|---|---|---|---|
| 1 | **beanbag** (teen / kid) | A **BUG**: drawn 19 px below its feet row (the port shifted from the wrong base), so its scavenge node floats off the sprite (scan: NODE + FEET) — and the art is a flat 4-colour orange dome, the controller a dark rectangle | fix the offset (`dy = oy − 121`); redraw as a slumped bag with creases, a lit top, a seam, a visible cast shadow |
| 2 | **suitcase** (both colours) | A 2-colour slab with a handle nub — on a wardrobe it reads as a loose plank | corners, a lit top face, two latches, a strap, a sticker |
| 3 | **backpack** | Flat olive blob (3 colours): no straps, pockets or buckles | front pocket, zip line, two straps, a lit top, a dangling cord |
| 4 | **drip_stand** | **Out of scale**: 87 px tall — taller than any wardrobe (78) — and the pole is a 1-px line; the bag and the line are barely visible | cut to ~58 px, a base with castors, a bigger bag with a clear fluid level, the line as a curve |
| 5 | **armchair** | Reads as a **TV set**: the back is a dark inner rectangle in a frame; no depth, no rolled arm tops | padded back with piping and a seam, arms with a lit top face, a visible seat front, a throw |
| 6 | **bed_iron** | The iron frame barely reads (thin slanted strokes, white dots), the quilt is brown mud with scattered tiles | thicker posts with finials, a proper head rail with spindles, a clear patchwork grid on the quilt |
| 7 | **crate_bedside** | A flat tan panel with 3 lines; at the centre bucket it has no top and no depth | a lit top face, rope handles cut-outs, a stencilled mark, a gap to show it is a crate |
| 8 | **clothes_pile** | A flat lens with 3–4 colours: reads as a stain or a hat | an irregular heap, a sleeve and a trouser leg hanging off, folds |
| 9 | **rug_oblong** | A flat trapezoid with five dots — a doormat | a border band, a medallion or stripe pattern, worn corners, a curled edge |
| 10 | **crates_stove** | Cluttered: grey unreadable lumps (cans / candles), a blue block for the stove, the lantern buried | draw the stove as a stove (burner ring, a pot), cans as cans with a label band, candles with flames' glow, spread them out |
| 11 | **wardrobe_small** (kid) | A plain white slab: no panels, no moulding, two yellow handles | door panels, a base plinth, a decal / sticker, the pink pelmet with a lip |
| 12 | **frame_ghost** | A blank grey square with a nail — reads as an unfinished placeholder | the unfaded paper rectangle with a darker wall around it, a snapped string, a few dust marks |
| 13 | **shoes_pair / slippers / trainers / hairbrush / glass_water** | 3–6 px tall: they are 2 dark rectangles, almost invisible at game zoom | make them 30–50 % larger, add a sole line and a highlight; a glass with a water line and a rim |
| 14 | **mattress_floor** (bare) | A plain slab with a dotted edge | a stained ticking pattern, a corner folded up, a pillow dent |
| 15 | **nightstand_wood** (dark) | The top overhang is a dark plate wider than the body — reads as a hat; barely distinct from the wall | a lit top edge, a visible drawer pull, a lower shelf with an item |

## Smaller

* **floor_stain** is nearly invisible; **height_chart** and **tally_marks** are low contrast (dark grey on blue wallpaper) — lift them a step.
* **pill_cabinet**, **boxes_stack**: shading is fine but flat (4–5 colours); the bottles on the cabinet top read as noise.
* **wardrobe_wood / chest_drawers / dressing_table / bookcase_low / bed_wood / bed_pine / bed_kid / desk_crt / wheelchair / rocking_horse / toy_chest / posters / pictures**: read well.
* **bed_wood** at the right-most bucket (`b5`) would run 1 px off the module — the planner never places it there (rect ≥ 315 is refused), so it is a wasted sprite, not a visible fault.
* Scale: the beds (123–137 px) and the wardrobes (78 px) are large against a 56 px player — inherited from the baked rooms, not new; a drip stand is the only outlier.
* The scan's NOEDGE hits on posters / photos are noise (a light paper margin is the design); LOWCON hits (frame_ghost, mirror, toy_chest against the teen wall) are mild.

## What the automatic pass found (111 findings; 17 flagged egregious)

NODE ×1 (beanbag's node in empty air), FEET ×1 (beanbag), CLIP ×16 (every bed_wood variant at the right-most bucket — a sprite the planner never uses), FLAT ×16 (beanbag, rug, clothes pile,
dead plant, backpack, frame ghost, spray, suitcase ×2, wheelchair, crate), LOWCON ×5, NOEDGE ×72 (mostly the paper margins of posters / photos — noise). No SLOT or LIGHT faults, no stray specks,
no duplicate variants: the kit's per-piece checks (a slot sits on a real surface, a light is inside its sprite) hold. So the egregious list above is mostly what the eye found, not the checker —
which is the point of the contact sheets.
