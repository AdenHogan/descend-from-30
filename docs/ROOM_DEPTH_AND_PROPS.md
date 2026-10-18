# Room depth, openable furniture and physical props — the plan (owner round 45)

**Status: PROPOSAL + what is built. Nothing below the "Built" lines changes the art yet — the perspective question needs the
owner's eye on mocks first (the orb mocks worked well that way).**

The owner's playtest, verbatim: *"The art at the back has a bad perspective at times… the gun cabinet is a more 3D object that
reaches out leftward, meanwhile the window next to it is facing front. Likewise in between is the wall boundary and on the left is
furniture that reaches outward to the right… I don't want flat against the backwall… improvements do need to be made to the
appearance of 3D presenting furniture."* and *"More furniture items need to open up when interacted with, and more of the items
you've created for the world design could be real in-world physical items with weight and gravity that react if hit or struck or
knocked over."*

## 1. Why the perspective reads wrong (measured, not guessed)

- Every room MODULE (320×144) is drawn from its OWN camera: one vanishing point at the ceiling line over the module's middle
  (`pixlib.VP_X` 160, `setback` / `pp` / `persp`). A set-back piece is extruded TOWARD that point, so it shows the face turned to the
  middle of ITS module: a piece in the left half shows its right face, a piece in the right half its left face.
- Extrusion grows with the distance from the VP (`setback_depth`, `DEPTH_GAIN` 1.6, cap `DEPTH_MAX` 11), so it is largest at the
  module EDGES — exactly where two modules meet. At a seam the left room's last piece leans left and the right room's first piece
  leans right (a V), with the static doorway frame between them. A flat window beside a strongly leaning cabinet is the same
  disagreement within one module: the window is drawn on the wall plane, the cabinet is extruded.
- The floor is warped by the same per-module map (`persp`, `PERSP_K` 0.55), so floor lines kink at the seam as well.

## 2. Options (cheapest first)

| | What changes | Cost | Risk |
|---|---|---|---|
| **A. Calm the seams** | Cap the extrusion by distance to the nearest SEAM (not just `DEPTH_MAX`), keep 16-24 px either side of every seam / doorway free of leaning pieces, give windows a shallow reveal (frame depth) so they agree with their neighbours. Regenerate all 30. | small: pipeline constants + a check in `finish_module` | low; looks only change near seams |
| **B. One VP per FLAT** | All three modules extrude toward the flat's middle, so neighbours lean the same way across a seam. Outer modules lean a lot more (cap it). | medium: `pp`/`setback`/`persp`/`openables.P` take a flat-relative VP; every module regenerated | medium: the floor wedge, doorway frames and `module_walls` all assume the per-module VP |
| **C. Oblique (no VP)** | Depth recedes up and to one side at a fixed angle everywhere; no convergence, so no seams to disagree. Floors stop converging. | large: redraw floors, setback, every opening | high; the biggest visual change |

**Recommendation:** do A now, then render B and C on two modules (living room E — the cabinet next to a window — and a seam between
two others) as mocks for the owner to judge, exactly like the scavenge-node sheet. Don't pick C blind.

## 3. Openable furniture

**Built (round 34):** `tools/art/openables.py` bakes 10 openings (drawers pulled out, a fridge door swung, the oven dropped, a
cupboard door) from the FINISHED art in true perspective; `scripts/open_furniture.gd` plays them when a node is searched. They exist
only on the five BASE (variant A) modules, which the tutorial flats use; the other 25 variants have none.

**To do:** `OPENINGS` is a hand-written table `{art: {anchor: spec}}` — one rect (the furniture's front, in module art px) and a kind
(`drawer` / `door_h` / `door_drop`) per opening. Adding the other variants is data + a look at each: roughly 2-3 per variant, ~60
entries. Some furniture is already DRAWN open (kitchen D's fridge, kitchen B's base unit) and needs nothing. The gate already runs
`openables.py --check` (deterministic output) and `open_furniture_test` checks attachment, so it is safe to extend in batches.

## 4. Physical props (things with weight that react)

**Built:** thrown cans / bottles / Molotovs are `RigidBody2D`s (`thrown_can.gd`: layer-1 mask, bounce, noise on impact), and dropped
items fly, bounce and settle (`world_drop.toss`). The world's furniture and clutter are BAKED into the module art, so they cannot move.

**Proposal — "loose clutter":** a handful of small things per flat and corridor (cans, bottles, shoes, a mug, a book, a bin lid) become
real nodes:
1. The art script draws the room WITHOUT them and registers `(kind, x, y)` per variant (like `anchors`; a new `props.json` beside
   `nest_meta.json`), so the picture and the physics never double up.
2. `loose_prop.gd` (`RigidBody2D`, the can's physics material): sleeps when at rest, wakes when the player's walk / shove / swing, a
   zombie, a thrown can or a gunshot reaches it; each kind has a mass and an impact sound (a can clatters, a bottle SMASHES like the
   thrown one, a shoe thuds); a clatter is a small noise (`emit_noise`) — stealth gets a real cost for stomping through clutter.
3. Rest positions persist like `world_drop` (a `rested` record keyed per flat + prop), so a kicked tin stays where it landed.
4. Limits: ≤ 6 awake bodies per scene, nothing on the back plane, never blocks the player (collision with the PLAYER off; they only
   react to impulses), and every prop sleeps within a few seconds so a flat costs nothing at rest.
Larger furniture (a toppled chair, a lamp on a table) could follow the same path later. This needs the owner's call on which things
become props and how loud they should be before any art is changed.

## 5. Built this round (related)

- Corpses no longer slide up 6 px after landing (the rise is spread over the fall) — `corpse_depth.gd`.
- (Round 45c, REMOVED in 45b) A corpse went BEHIND floor pieces that stood nearer than it, via `_near*.png` masks and a `corpse_depth.gd` shader — superseded by the walking-line rule below, which keeps every piece off the lane.
- **THE WALKING-LINE RULE (round 45b).** The player and every enemy draw over all baked art, so nothing may stand or lie on the lane (row 129): a registered floor piece is wholly
  behind it (lowest row <= 122) or wholly in front (highest row >= 131, drawn over the actors as `<art>_over.png`, `room._add_over_art`, so the player walks behind it); anything straddling is refused by the
  art tool (`pixlib._lane_violations`, first look and every run look). A breach flat's dropped objects (`nest.py` `OBJECT_BASE_MAX` 122) follow it. The earlier attempt — drawing the toppled chair over the
  player — put it on the player's legs ("it looks like the player is clipping through"); the chair, two more toppled chairs and the torn gift box moved behind the line instead. The corpse-clip masks of round 45c are gone (nothing can be nearer than a body now).
- **The process from here** (owner: "this will take time to iterate from. It's a process"): (1) the rule above keeps NEW art honest; (2) the next step for small clutter (cans, bottles, shoes, a mug, a book) is the loose-prop system in §4 — kickable `RigidBody2D`s with a clatter —
  because a thing you can push or knock over has presence that a baked picture cannot; (3) the furniture-perspective options A / B / C (§2) still wait for the owner's pick on mocks; (4) each pass: render the real flat under xvfb at game zoom, look, then fix.
  Gotcha: regenerate art, then `godot --headless --import` BEFORE capturing, and delete a removed asset's `.import` with it (`pixlib._remove_asset`).
