# Enemy kinds and how they move (round 49v — BUILT v1; the LOOK and the FEEL unseen by the owner in play)

Owner, 2026-11-17: "ideally we want them moving differently, each enemy type", the crawler as "the blob… pulsates, undulates, moves along the floor toward the player",
and the old bug-like crawler as "a flying enemy that hovers, moves close, moves up and down making melee hard, but gunplay can take it down, otherwise the player
needs to crouch under to pass, and run away". Then, of a first jelly with eyes: "too cute… we need horror, no face, no discernible features, something pulsating,
blisters popping, pink almost flesh-like blobbiness, as it grimly grossly moves toward the player."

| kind | script | the thing | how it moves (the art and the AI) |
|---|---|---|---|
| standard | `enemy_zombie_standard.gd` | the husk | upright shamble |
| crawler | `enemy_zombie_crawler.gd` | **the blob** — a low heap of wet pink lobes, no face, no front | the heap flows: a wave runs through it, it humps forward; lobes swell and sink out of step; blisters rise, burst and spit; the old pounce / wall-nest rules are unchanged |
| flyer | `enemy_zombie_flyer.gd` (NEW) | the fuzz — matted lilac fur, no legs, no eyes, a mouth | hangs at head height, bobs, is kicked about by random twitches, lurches in surges; inside 190 px it stops, SCREAMS (maw open), then SPINS at you and bites where it lands; see below |
| big | `enemy_zombie_big.gd` | the bulk | heavy four-legged lumber |
| longarm | `enemy_zombie_longarm.gd` | the reach | tall, on four long arms |
| spitter | `enemy_zombie_spitter.gd` | the heap | stands and spits |

## The flyer

- Height `HOVER_BASE` 44 px ± `HOVER_AMP` 16 px on a bob of `HOVER_RATE` 2.3 rad/s, plus TWITCHES (a random kick every 0.25-0.9 s that decays) and a sideways wobble, so its height and position are never the same twice.
  The SPRITE is lifted and thrown about; the collision box stays on the floor, because every feet measurement reads it (`EnemyFeet`, the shadow, the plane checks).
- **SURGES**: `SPEED` is rewritten every frame (0.25-1.75 x 56), so it lurches in bursts and stalls.
- **THE DIVE**: inside `DIVE_RANGE` 190 px (and outside its bite reach) it stops and SCREAMS for 0.7 s (the tell: the Attack frames, a pitched-down moan), then spins at you at 340 px/s for 0.55 s
  (the sprite whirls 20 rad/s) and bites where it lands. 3.4 s cooldown; a hit, a shove or death ends it.
- **Melee**: `can_be_meleed()` is true only while it is at or below `MELEE_MAX_H` 50 px. `player._do_melee_attack` skips a target that answers false. A bullet always lands.
- **Its bite**: a standing player is always in reach; a crouching one (or a rolling one — the roll sets `is_crouching`) is bitten only while it is below `CROUCH_STRIKE_H` 38 px.
- **Passing**: solid to a standing player, passable (a collision exception) to a crouching one — crouch and go under.
- Fragile (40 % of a standard's health), senses from 220 px.
- **Where**: corridors only. `WorldState.enemy_type_for` turns `FLYER_SHARE` (0.4) of the crawler slots into `zombie_flyer` (seeded, so a pan backdrop and its live commit agree). Breach rooms,
  revenants and the like still lay blobs (`room.gd` maps `crawler`).

## Not done / owner's call

- No playtest: the bob rate, the heights, the 0.4 share and the speed are first guesses.
- The collision box is on the floor, so a standing player is stopped by an invisible block under the flyer when it is high; the alternative is raising the box (every feet measurement would then need a flyer exception).
- Art is placeholder. The blob's Hit / Attack / Death are derived from the same drawing (squash, drive forward, slump and spread).

## The dive roll (player; owner 2026-11-17 — BUILT v1, the FEEL unplayed)

"A forward roll when running and press crouch… it rolls the player lower so they dive under things. Fully wipes out the stamina bar, just like a push would… roll past an enemy
without taking damage, but it's not a big distance, so if they mis-roll they could end up in a pack of enemies or too close to another enemy with no stamina. Risk v reward."

- **Input**: sprint held + a direction held + the crouch key (`crouch_toggle`). Anything less and the key just toggles the crouch. Not in scavenge stance, hiding, mid-swing / shove / hit, on a balcony or in a cutscene.
- **Cost**: the same as a shove — `WorldState.push_cost()` (a full bar for a one-charge character) and `push_recovery_delay()` before stamina starts back; it needs `push_min_stamina()` to begin. A roll noise as loud as a run.
- **Distance / time**: `ROLL_DISTANCE` 118 px in `ROLL_TIME` 0.46 s, committed (no steering, no stopping), the sheet's 7-frame `roll` stretched to fit.
- **Nothing lands**: `_begin_hit` refuses while `is_rolling`; no swing, shot or shove from inside it. The dead within reach become passable for the whole roll (`_roll_pass_through`; an enemy's `_try_resolidify` waits while the player rolls),
  and firm up again once you are clear — end a roll INSIDE a pack and you are stood among them with an empty bar.
- **Low**: the roll sets `is_crouching`, so a flyer's bite passes over you and the flyer lets you through; the roll ends standing.
- Placeholder: the `roll` frames are the people rig's tuck (`tools/art/player_rigs.py`); no roll sound, no dust, no HUD hint yet. `tests/roll_test` covers the rules.
