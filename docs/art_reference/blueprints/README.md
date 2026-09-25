# Room-module blueprints — behind the scenes

One blueprint per module variant (`<module>_blueprint.png`, 30) and one sheet per room type
(`<type>_sheet.png`, the five variants stacked). Generated — never hand-edit:

    python3 tools/gen_module_blueprint.py            # all 30 + the six sheets
    python3 tools/gen_module_blueprint.py study_b    # one

Regenerate after any module art / node change (`python3 tools/art/build_all.py` first). Everything is
READ: the nodes and their flags from `scenes/Room_Modules/<module>.tscn`, the art and floor strip from
`assets/rooms/`, the player's size measured from its idle sprite (58 px tall, body 28 px). The plane
numbers are the constants at the top of the tool, mirroring `scripts/room.gd`, `module_walls.gd`,
`tools/art/pixlib.py` and `docs/Y_PLANES.md` — change them together.

## The Y planes (module-local y = world y − 224; a module is 320 × 144 at world y 224)

| local | world | plane |
|---:|---:|---|
| 0 | 224 | ceiling / back-wall top (the perspective horizon, `module_walls.VY`) |
| 23 | 247 | interior doorway lintel |
| 10–66 | 234–290 | the two window boxes (L x 50–94, R x 226–270) — kept bare wall |
| 40 | 264 | node line: no scavenge node above it |
| 100 | 324 | wall / floor seam = where SET-BACK furniture stands |
| 104 | 328 | BALCONY plane feet (balcony-capable rooms, on a balcony slot) |
| 102–114 | 326–338 | BACK-PLANE STAND ZONE — must be bare floor at every step-up spot |
| 114–122 | 338–346 | where FRONT furniture's bases sit (sofas, beds, chairs, tables) |
| 115 | 339 | BACK PLANE feet — the player steps up here to search set-back furniture (sprite × 0.89) |
| 128 | 352 | interior floor |
| 129 | 353 | WALKING LANE feet — every actor stands here |
| 136 | 360 | front cut plane |
| 144 | 368 | module bottom |

## Node kinds

- **Front** (gold) — on furniture standing out in the room; searched from the walking lane.
- **Back plane** (blue) — on set-back furniture against the wall. Nodes ≤ 40 px apart share one
  step-up spot, centred on the nodes that spawned. The blueprint draws the spot's STAND ZONE (the
  player's ±13 px body × rows 102–114) blue when clear, **red when a front piece stands there** — the
  art pipeline refuses to export that (`pixlib.check_back_plane_clear`, every run's look).
- **Balcony strip** (green) — study / dining only: furniture + nodes in x 4–96 that are removed on a
  balcony slot.

## Rules the blueprints make visible

- Keep front furniture (fallen chairs too) out of the x-span in front of back-plane nodes.
- Nothing that stands BEHIND a front piece carries a node (the TV rooms' sets carry none).
- Window boxes and the wall-face sample columns (x 3, x 316, magenta) stay bare wall.
- Spread the pieces across the width (one every ~50–60 px) so the nodes spread with them.
