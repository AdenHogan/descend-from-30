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
   `time_of_day` derived from it; palette/tint hook per scene)
2. Time-skip transition: on character end (death or exit), advance run,
   reshuffle spawn seeds (except storied-room flag, reserved), apply
   door-decay pass, roll fires
3. Door-decay pass: seeded per (master_seed, run) — converts a fraction of
   locked→open/barricaded, adds breaches. Tuning table per run
4. Balcony column seed in generation + balcony descent (spec above, DECIDED)
5. Fire hazard objects: blocking volumes + visuals; floors flagged
   fire-affected at skip time
6. Enemy-type spawn tables per (floor band × run) — data-driven so new types
   slot in as art arrives
7. Descent boon on successful exit (design TBD)
8. Character stats system (own design doc first)

Out of scope here: storied/quest rooms (own doc), stealth/listen phase 2,
night lighting implementation detail.
