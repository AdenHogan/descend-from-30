# DF30 — Three-Run Arc & Time Skip Overview

> Converted from `DF30__THREERUN_ARC.docx`.
> **Status:** agreed design, pre-implementation. Covers: run structure,
> time-of-day skip, escalation levers, world decay, fires, balcony descent,
> fresh-character state, victory conditions.

## The Arc

- **One gameplay experience = ALL THREE runs, not one.**
- Always three runs per session — a run ends when its character exits the
  lobby OR dies.
- Either ending triggers the time skip; the next character starts at
  Apartment 3001.
- Session ends when all three character stories have concluded.

**Time skip (uniform, decided):**

| Run | Time of day |
|---|---|
| 1 | MORNING |
| 2 | AFTERNOON |
| 3 | NIGHT (hardest) |

Skip length does not vary with how far the previous character got — the
fiction is fixed time-of-day; the difficulty curve is authored, not emergent.

**Victory & the exit:**
- Reaching the lobby and exiting ends that character's story — success, not
  game end.
- A successful exit grants the next character a **DESCENT BOON**. Content pool
  TBD — candidate scale: a weapon, no stamina drain for ten floors, an extra
  health state ("SUPER HEALTHY"). Compounding for double-escape: still open.
- A character who exits takes their notes and inventory OUT of the building —
  no corpse, nothing to recover. **DELIBERATE:** escaping is the selfish
  outcome; dying reachable is the generous one. (See `STORE_DESIGN.md` —
  corpse recovery.)

## Sectional Identity (a design PILLAR)

The building should feel different by SECTION as well as by run — two axes of
identity that compound:

- **Down the building = more grotesque.** The infection has spread WORST to the
  lower floors, so as the player descends the world gets sicker and more decayed
  and the enemy make-up shifts. Floor 30 is near-clean; floor 1 / the lobby is the
  rotten heart of it.
- **Across the runs = worse everywhere** (morning → afternoon → night), the time
  skip layered on top.
- **Narrative will reinforce this in due course** (story beats tied to sections),
  and eventually **per-section GROTESQUE ART** (environment + enemy art that
  degrades as you go down).

**Built so far (v1):**
- **Real lighting + descent dimming** (`WorldState.ambient_color` /
  `apply_time_tint`, `scripts/floor_lighting.gd`): the old flat sickly-green "filter"
  was replaced with actual 2D lighting. The world CanvasModulate is now the AMBIENT
  DARKNESS that real lights punch through (morning bright, afternoon golden, NIGHT
  genuinely dark), and the DESCENT dims it further — the lower/sicker building has more
  dead ceiling lamps and less ambient, for tension + sectional identity. Ceiling
  PointLight2D lamps (some flickering, some dead — more dead deeper/later, seeded per
  floor/run), fire as a real orange light source (`fire_field`), and a faint player aura
  do the actual lighting. Lighting is **intrinsic** — it is always on and varies by scene
  and run (no toggle). Covered by `lighting_test` + `run_arc_test`. (Still a placeholder
  for eventual per-section grotesque ART, but now a lit atmosphere, not a tint.)
- **Enemy sectional flavour** (see escalation table below): LOW = melee swarm
  (crawler/big), MID = long-arm bruisers, HIGH = ranged spitters; the spitter inverts
  to favour the top so descending genuinely changes the threat.
- **Deeper = tougher** already: zombie HP scales up toward the lower floors
  (`_set_hp_from_floor`).

**Still to come:** per-section grotesque art (environment + new enemy TYPES — art-
gated); story/narrative section beats; possibly finer sections than the current 3
bands, and per-section behavioural intensity (aggression) once it can be playtested.

## Escalation Levers (Runs 2/3)

**Enemy VARIETY, not density:**
- Apartment population stays realistic — no cramming eight bodies into a flat
  because the run number went up. Hordes (breach rooms) are the exception and
  already exempt.
- New enemy types beyond zombie standard + Big Zombie (art-gated, future):
  - Run 1: rarer types appear only on very LOW floors
  - Runs 2/3: those types become frequent on UPPER floors too — the building's
    infestation migrates upward as time passes
- Long-term: not just zombies — other monster types as art allows.

**Spawn reshuffle:**
- Time skip re-rolls enemy spawn positions (building shift), EXCEPT storied
  rooms.
- Storied/quest rooms have their own persistent rules — future implementation,
  own doc.

**Loot depletion (mostly automatic):**
- World state persists: anchors emptied by earlier characters stay empty.
- Character 1 cannot open every door (locks/keys), so runs 2/3 inherit a
  partially looted building, not a stripped one.

**Door decay & access shift:**
- Runs 2/3 see MORE barricaded and breached rooms.
- Some previously LOCKED doors become open or barricaded — narrative
  fighting/attacks happened during the skip. Room access CHANGES across
  morning/afternoon/night; the map you learned is not the map you return to.

**Merchant:**
- Boon:trade-off ratio worsens per run — the night merchant offers nastier
  bargains (see `STORE_DESIGN.md`).

**Night (run 3) note:**
- Time-of-day implies lighting/visibility as a difficulty axis (dark floors,
  flashlight relevance). Scope TBD — flagged, not designed.

## Fires (New Hazard, To Add)

- Fires may break out on certain floors during time skips.
- Block access to rooms or whole corridor sections.
- Together with strong barricades, fires create floors that CANNOT be
  descended by stairs — forcing the balcony route.

## Balcony Descent (New Traversal, To Add)

**Mechanic:** rope/clothes used from a balcony to descend to the balcony
directly below.

**Purpose:** alternate descent when stairs are blocked (fire, barricade);
also a scavenger's shortcut trade-off.

**ARCHITECTURE REQUIREMENT — BALCONY COLUMN CONTINUITY:**
- Any apartment with a balcony room in slot N must have the SAME balcony room
  state in slot N of the apartment directly below (2603 slot 2 balcony →
  2503 slot 2 balcony).
- This is a **generation-order constraint**: balconies must be planned as a
  per-building COLUMN SEED decided before individual apartments roll their
  modules — apartments conform to the column plan, not the other way round.
- Must be built into procedural generation BEFORE more content assumes rooms
  seed independently; retrofitting vertical constraints later is misery.

**Descent mechanics (decided):**
- Rope is an existing scavengeable item and works alone. Clothes work too:
  THREE clothes items (separate slots) combine from inventory into a
  clothes-rope.
- At a balcony with rope/clothes-rope: send it down, climb to the balcony
  below. Costs stamina. LOW stamina = the player falls mid-slide and takes
  injury.
- The target apartment may contain enemies — listen mode applies before
  committing.
- Door state from the INSIDE: a locked door unlocks from within (never a soft
  block). A barricaded door is dismantled from the inside — needs a dismantle
  animation (art task).
- NO ROPE: the player can still jump. Serious injury guaranteed UNLESS
  mitigated by character stats (e.g. athletics — see character stats system)
  or fall-related upgrades.
- STAIRWELL JUMPING: same jump option at stairwells (escape
  fires/barricades/approaching enemies) — same injury rules.
- TABLED (liked, later): landing on an enemy group below cushions the fall
  and crushes them; listen mode turns "how many do I hear down there" into a
  real jump/don't-jump read.

## Fresh Character State

Starts with:
- Persistent upgrades (see `STORE_DESIGN.md`)
- Wallet unlock if earned (balance 0)
- Pre-provided character stats — the three characters differ statistically.
  System to introduce later, own design pass.
- Nothing else: no items, no notes.

Floor 30 after run 1:
- Tutorial is FIRST-RUN-ONLY. From run 2, Floor 30 is plain procedural
  seeding like every other floor (believed mostly in place already).
- Apartment 3001 is NEVER accessible, any run.
- Runs 2/3 inherit whatever state character 1 left: searched anchors, opened
  doors, corpses, world drops.

## Implementation Notes (rough order, post-merchant)

1. Run/time-of-day state in WorldState (`current_run` already exists; add
   `time_of_day` derived from it; palette/tint hook per scene) — **BUILT (v1)**.
   `WorldState.advance_run()` bumps `current_run` (cap 3, returns true when the
   arc is over), wipes the PER-RUN character (inventory, health, stamina, wallet
   BALANCE, follower, upgrade offers) and KEEPS the cross-run rewards (upgrades,
   wallet UNLOCK) + the decayed world (same `master_seed`). `time_of_day()` →
   Morning/Afternoon/Night; `apply_time_tint()` sets each world scene's ambient
   DARKNESS via a `CanvasModulate` (world only — never the HUD) that the real lights
   punch through — see "Real lighting + descent dimming" above.
2. Time-skip transition: on character end (death or exit), advance run,
   reshuffle spawn seeds (except storied-room flag, reserved), apply
   door-decay pass, roll fires — **BUILT (v1)**. Both endpoints wired:
   `lobby_exit.gd` (exit) and `game.gd::game_over` (death) set the finishing
   character's outcome, call `advance_run()`, and — unless the arc is over —
   `Transition.to_run_shift(hallway, next_run)` (a slow fade-to-black title card
   animating the time-of-day word + subtitle, then the new Floor 30). Death is no
   longer a session-end mid-arc; only the THIRD character concluding ends it
   (`game_over.tscn` now shows the three fates + a win/lose headline). Enemy
   positions reshuffle via a `current_run` salt in `building_floors._spawn_zombies`;
   fires climb automatically off `current_run`. Storied-room reserve: not yet.
3. Door-decay pass: seeded per (master_seed, run) — converts a fraction of
   locked→open/barricaded, adds breaches. Tuning table per run —
   `mutate_door_states_for_new_run()` exists and is now CALLED by `advance_run`
   (decays the doors the player left in place). Per-run tuning table: future.
4. Balcony column seed in generation + balcony descent (spec above, DECIDED)
5. Fire hazard objects: blocking volumes + visuals; floors flagged
   fire-affected at skip time
6. Enemy-type spawn tables per (floor band × run) — data-driven so new types
   slot in as art arrives — **BUILT (v1, mix only)**. `WorldState.HEAVY_CHANCE`
   is a 3×3 table [band][run] (bands LOW 1-10 / MID 11-20 / HIGH 21-29) giving the
   per-slot chance a corridor spawn is a HEAVY; `enemy_type_for(floor, spawn_key)`
   rolls it deterministically (backdrop == live, stable on re-entry, re-rolls per
   run). `building_floors._spawn_zombies` maps the result to a scene. Today the only
   heavy is the **Big Zombie** (settles at origin **374**, feet on 419 — its own
   line, not the standard's 370; `BIG_ZOMBIE_SETTLED_Y`); new art-gated types slot
   into the same table. Faithful to the migration model: heavies rare + LOW-floor
   only in the morning, reaching MID by afternoon, common even up HIGH at night.
   Density stays with `get_floor_zombie_count` (mix, not count — no cramming).
   **Three new types added** (Crawler / Long Arm / Spitter — art in `assets/Enemies/`),
   each with its own `*_CHANCE` table alongside `HEAVY_CHANCE` and its own scene/script
   (reskins of the standard AI; the Spitter adds a real ranged projectile).
   **Spread tuned for VARIETY + section flavour**: runs 2/3 carry more new enemies up the
   building; no type dominates; LOW reads as a melee swarm, MID as long-arm bruisers, HIGH
   at night as a ranged/spitter threat (the spitter inverts and favours the top). Run 1
   unchanged. **Corridor bosses (runs 2/3)**: a floor may hold ONE roaming tougher Big
   Zombie (`is_corridor_boss`) — NO key (guards nothing) but a fatter money bundle + one
   good-loot item (`BOSS_LOOT_POOL`); per (floor,run) via `floor_has_boss`.
   **Crawler redefined**: SLOW + fragile but DOUBLE-damage bite, and the run-1 swarm
   (~3:1 standards, whole building); a push on it becomes a KICK-STUN (can't be shoved
   back). Aim/hitbox verified height-independent (melee + gun target the on-plane origin),
   so low crawlers connect. Covered by `enemy_variety_test`. Still open: distinct AI per
   type beyond the reskin; a low/impale melee *feel*; a boss silhouette; storied rooms.
7. Descent boon on successful exit (design TBD)
8. Character stats system (own design doc first)

Out of scope here: storied/quest rooms (own doc), stealth/listen phase 2,
night lighting implementation detail.
