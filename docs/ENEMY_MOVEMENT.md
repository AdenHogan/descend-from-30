# Enemy kinds and how they move (round 49v — BUILT v1; the LOOK and the FEEL unseen by the owner in play)

Owner, 2026-11-17: "ideally we want them moving differently, each enemy type", the crawler as "the blob… pulsates, undulates, moves along the floor toward the player",
and the old bug-like crawler as "a flying enemy that hovers, moves close, moves up and down making melee hard, but gunplay can take it down, otherwise the player
needs to crouch under to pass, and run away". Then, of a first jelly with eyes: "too cute… we need horror, no face, no discernible features, something pulsating,
blisters popping, pink almost flesh-like blobbiness, as it grimly grossly moves toward the player."

| kind | script | the thing | how it moves (the art and the AI) |
|---|---|---|---|
| standard | `enemy_zombie_standard.gd` | the husk | upright shamble |
| crawler | `enemy_zombie_crawler.gd` | **the blob** — a low heap of wet pink lobes, no face, no front | the heap flows: a wave runs through it, it humps forward; lobes swell and sink out of step; blisters rise, burst and spit; the old pounce / wall-nest rules are unchanged |
| flyer | `enemy_zombie_flyer.gd` (NEW) | the louse (the old crawler drawing) | hangs at head height and BOBS; see below |
| big | `enemy_zombie_big.gd` | the bulk | heavy four-legged lumber |
| longarm | `enemy_zombie_longarm.gd` | the reach | tall, on four long arms |
| spitter | `enemy_zombie_spitter.gd` | the heap | stands and spits |

## The flyer

- Height `HOVER_BASE` 40 px ± `HOVER_AMP` 16 px on a bob of `HOVER_RATE` 2.3 rad/s. The SPRITE is lifted (`animated_sprite.position.y`); the collision box stays on the floor, because
  every feet-line measurement reads it (`EnemyFeet`, the shadow, the plane checks).
- **Melee**: `can_be_meleed()` is true only while it is at or below `MELEE_MAX_H` 46 px (the low half of the bob). `player._do_melee_attack` skips a target that answers false. A bullet always lands.
- **Its bite**: a standing player is always in reach; a crouching one is bitten only while it is below `CROUCH_STRIKE_H` 34 px.
- **Passing**: solid to a standing player, passable (a collision exception) to a crouching one — crouch and go under.
- Fragile (40 % of a standard's health), quick (58 vs 40), senses from 200 px.
- **Where**: corridors only. `WorldState.enemy_type_for` turns `FLYER_SHARE` (0.4) of the crawler slots into `zombie_flyer` (seeded, so a pan backdrop and its live commit agree). Breach rooms,
  revenants and the like still lay blobs (`room.gd` maps `crawler`).

## Not done / owner's call

- No playtest: the bob rate, the heights, the 0.4 share and the speed are first guesses.
- The collision box is on the floor, so a standing player is stopped by an invisible block under the flyer when it is high; the alternative is raising the box (every feet measurement would then need a flyer exception).
- Art is placeholder. The blob's Hit / Attack / Death are derived from the same drawing (squash, drive forward, slump and spread).
