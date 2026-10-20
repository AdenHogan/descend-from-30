# FURNITURE AS ASSETS — rooms that are laid from a seed

**Status: BUILT v1 for BEDROOMS (owner round 47, 2026-10-20).** Every other room type is still a baked module; the same pipeline is
how they will be converted ("start with bedrooms and work from there").

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
tools/art/furn_bedroom.py   shared + adult pieces      furn_bedroom_b.py teen   _c.py sick   _d.py refuge   _e.py kid
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
* **Other room types** — kitchen, bathroom, study, living room, dining room. The logic table already names them (`cooking`, `wet`, `toilet`, `dining`, `tv`…), and many pieces list
  other rooms (lamps, pictures, rugs, plants, clocks, mirrors, chests, bookcases, armchairs, backpacks, boxes) — those are the first things the next room type reuses.
* **Per-piece loot** (a nightstand holding pills, a toy chest holding toys) — loot is still by room type.

## Numbers (so far)

77 pieces, 571 sprites; 5 shells; 5 recipes. 1000 planned rooms in the test: 0 rule violations, 0 fallbacks; planning costs ~16 ms a room on average (cached per flat+slot,
shared by the live room and its pan backdrop).
