# Light and depth

**BUILT v1 (round 49s, 2026-11-10).** The owner: *"take a pass at our art… shapes, depth, and most importantly, lighting. I'm not asking
for 2.5D space, but I do want deeper lived in looking space. Improvements to lighting and colour and shape could be the best improvement
we need right now"*; and before it (round 49q): *"dynamic real lighting is so important because so much of our colour palette looks so
lifeless… we need lighting, shadows"*.

The LOOK was judged from engine captures under xvfb only (`docs/art_reference/lighting/`). It has not been seen on the owner's monitor.

## What was wrong (measured from captures first)

- A room's art is authored with flat, even light so the engine's lights can work on it — and nothing in the engine said where the light
  came FROM. Every wall was the same brightness from corner to corner, nothing cast a shadow, furniture read as stickers on wallpaper.
- A flat's window light was the corridor's broad wash (a 205 px radius). At a flat's closer zoom that is the whole screen, so at dusk and
  by night every wall was the same flat grey-blue. Corridors, with their small wall-lamp pools, already looked right at dusk and night.
- Nothing told the eye that the player and the dead touch the floor.

## What there is now

| Layer | Where | What it does | Code |
|---|---|---|---|
| **Shade** | every room (planned and baked), every corridor, floor 30, the lobby | the dark a real room keeps where light does not reach: under the ceiling, in the flat's END corners (less at a partition), along the floor's near edge, and a falling-off away from the room's daylight — so the wall is brightest by the glass. A corridor is dimmer in its middle than by a stairwell window | `RoomDepth.shade_at` / `add_to` / `add_to_corridor` |
| **Seam** | planned rooms (under the furniture) | the wall darkening down to the skirting and the strip of floor against it | `RoomDepth.seam_at` |
| **Cast shadows** | planned rooms; corridor props | every piece against the wall, every picture and everything standing on a surface throws its own silhouette on the wall behind it, AWAY from the light: the window by day, a lit lamp in the room from dusk on (a corridor prop: the nearer stairwell window by day, the nearest wall lamp after). The afternoon's low sun throws them 1.5x as far | `RoomDepth._cast_shadows` / `add_corridor_cast` |
| **Floor shadows** *(round 49t)* | planned rooms | every piece that stands — out in the room (`front` / `floor`: a sofa, a bed, a table, a chair, a plant) or against the wall — lays its own silhouette on the FLOOR from its foot, toward the camera and leaning away from the room's light; over the rugs, under the furniture | `RoomDepth._floor_shadows` |
| **Window light** | flats (wall windows and balcony doors) | by day the same wide wash as before; at dusk a POOL round the glass in the sunset's own colour, by night a smaller pool of moonlight — so a room has a lit side and a dark side | `FloorLighting.make_room_window_light` |
| **Contact shadow** | the player, every enemy type | a low dark ellipse under the feet, on the body's own layer; hidden on a staircase's slice, on a wall or ceiling, lying down, hidden in a wardrobe / bath, on a rope, dead | `GroundShadow` |

Rules they all keep:

- **Not gloom.** The morning stays a bright day: `WorldState`'s staged ambient ramp (0.95 / 0.42 / 0.07) is untouched, the morning window
  light is the old one, and by the window the morning wall is all but unshaded (`room_depth_test` pins it at <= 0.09).
- **Black with alpha, unshaded, in hard bands** (`RoomDepth.BAND`) — no blur, no dither; a lamp never brightens a shadow and the night's
  ambient never dims one twice.
- **Pure functions of the room** (its width, which edges are end walls, where its daylight is, the run) — a pan backdrop and the live
  room agree, nothing is saved, nothing has collision, groups or input.
- **The title screen's hall is left exactly as approved** (no shade, no cast shadows there).

## Dials (all first guesses)

| Dial | Now | In |
|---|---|---|
| how dark under the ceiling / in an end corner / at a partition | 0.38 / 0.34 / 0.15 | `RoomDepth.CEIL_AO`, `CORNER_AO`, `PARTITION_AO` |
| how much dimmer the far side of a room is than the window side (morning / dusk / night) | 0.18 / 0.30 / 0.30 | `RoomDepth.FALLOFF_BY_RUN` |
| a wall piece's shadow: how far, how dark | 4 px + a 7 px penumbra, 0.26 / 0.12 | `RoomDepth.CAST` |
| a flat's window light reach by run (texture scale) | 1.6 / 1.05 / 0.9 | `FloorLighting.ROOM_WINDOW_REACH` |
| … its strength on top of the old numbers | x1.0 / x1.7 / x1.5 | `FloorLighting.ROOM_WINDOW_GAIN` |
| … its colour (day / sunset / moon) | cool white / orange / blue | `FloorLighting.ROOM_WINDOW_CAST` |
| corridor: middle against the window ends | 0.14 / 0.22 / 0.10 | `RoomDepth.HALL_FALLOFF_BY_RUN` |
| the contact shadow's darkness | 0.34 core | `GroundShadow.CORE` |
| a floor shadow: how long (share of the piece's height) and how dark, by plane | front 0.30 / 0.20 · floor 0.30 / 0.18 · wall 0.18 / 0.14, 3..15 rows | `RoomDepth.FLOOR_CAST`, `FLOOR_MIN_LEN`, `FLOOR_MAX_LEN` |
| … how far it leans away from the light / how much longer in the afternoon | 0.9 px a row · x1.35 | `RoomDepth.FLOOR_THROW`, `FLOOR_LEN_BY_RUN` |

## A behaviour change to know about

**A flat at dusk and by night is darker away from its windows than it was** — that is the point (pools of light, dark between), and it
is how corridors already played. The player's own light is unchanged, so what is near them is still seen. If it is too dark to scavenge
by in play, `ROOM_WINDOW_REACH` is the dial.

## Not built

- **Baked rooms** (the tutorial's flats, breach / dead / burnt story rooms, the gun-cabinet lodge) get the shade only: their furniture is
  one picture, so nothing in them casts a shadow. The first rooms a new player sees are therefore the least improved.
- ~~Furniture standing OUT in the room casts no shadow~~ — **built in round 49t** (floor shadows, above). Still true: a piece does not shade the
  piece BEHIND it, and no piece is lit from one side by the room's light (the sprites carry their own fixed upper-left light).
- Shadows do not follow a lamp that flickers or cuts out (they are laid once, when the room is built).
- No light casts a real-time shadow of the player or the dead on a wall.
- Survivors, residents, the merchant and the cat have no contact shadow yet (only the player and the dead).
- The maintenance room and the lift car are not shaded.
- ~~Darkness as a place to hide~~ — **built in round 49t** with a working torch (`docs/TORCH_AND_DARK.md`): the light on a spot is measured from
  these same lights, the dead see less far into the dark, and the dark is a hiding place. That round also made the player's own NIGHT aura a small
  pool (0.36 over 160 px, was 0.62 over 269 px) — it had been lighting the whole screen round the player.

## Tests

`tests/room_depth_test.tscn` (the 84th suite; round 49t added the floor shadows — one per standing piece, from its foot, 3..15 rows, unlit
black, over the rugs and under the furniture, leaning away from the light): the shade's numbers (ceiling, corners, falloff, the morning is not gloom, bands), the
window light by run with the stairwell's unchanged, a real planned flat on runs 1 and 2 (every room shaded and unlit, the draw order,
shadows thrown away from the light), a baked flat (shade only, end corners), a real corridor (two profiles, two shadows under every
standing prop), the title hall untouched, the contact shadow on the player and three enemy types and when it hides.
Mutation-checked: shadows thrown toward the light, the window light left as the corridor's wash, the title hall shaded and the player's
shadow removed each fail it.
