# DF30 — Stairwell Barricades & the Crowbar

> **Status:** agreed design (owner Q&A), v1 implemented. Reintroduces
> rest/building-reset as a live tactical decision and makes noise near
> stairwells matter across floors.

## Terminology (agreed)

Three distinct stairwell hazards — do not conflate them:
- **Barricade** *(built)* — a stairwell blocked with furniture/debris. Not a
  fight: you **pry it open with a Crowbar**.
- **Horde** *(built, v1)* — a stairwell packed with **live enemies** you fight or
  lure through (no crowbar). See "The horde" below.
- **Fire** *(future)* — a spreading blaze. Not built.

A stairwell is at most ONE of these — the barricade seed rolls first, and the
horde only rolls on stairwells the barricade didn't take (`is_stair_horde`
excludes `_stair_barricade_seeded`). (The dead that *muster* at a barricade when
you pry it, or get pulled through by noise, are still just standard zombies — the
barricade draws them, it isn't made of them.)

Some **stairwells** are barricaded — blocked with debris someone wedged in.
Getting through is passable but costly, and it stirs the building on both sides
of the stairs, so where and when you cross is a real decision.

## The rules (as agreed)

1. **Passable, but costly — a Crowbar job.**
   - A barricaded stairwell refuses the crossing **in either direction** (you
     can't slip up past it any more than down through it) until it's levered
     open. With a **Crowbar (035)** the player runs a **channeled pry**
     (`PRY_TIME`, ~6s — long enough that the roused dead can close in). It is
     **loud from the first heave** (`door_work` noise at the stairwell), so the
     **current floor's dead converge on the steps** while you work. Walking off
     the stairwell or taking any other committed action cancels it.
   - Completing the pry **spends the crowbar** (single-use, consumed — see
     below), opens that stairwell **for the rest of the run**, and commits the
     crossing. A clear cue fires — feedback + a player-speech line — because the
     building shift is the whole cost.
   - **Cost = a rest slot.** Crossing triggers the **same building shift a rest
     does** (`WorldState.shift_building` — the world reseeds and the dead
     wander), but is **not billed as rest**: **no stamina heal**, no rest-stat
     bump. It costs **exactly one rest opportunity, wherever you cross**: if a
     rest is banked it's **burned** (`rest_available = false`); if not, the
     **next** merchant-floor rest is **forfeited** (`rest_forfeit_pending`,
     consumed in `on_floor_arrived`). Never both. So you weigh: spend the shift
     here to punch through, or keep the slot to actually rest and heal.
   - **The destination floor is waiting.** Arriving via a pry, that floor's
     whole horde is **milling at the stairwell you tore open**, roused —
     tactical planning required.

2. **Cross-floor noise pull is narrow (anti-cheese).**
   - Only **significant noise** — gunfire and forcing/prying (`>= door_work`
     loudness) — carries between floors. **Running/walking never pulls.**
   - It only carries when the noise is made **near a stairwell**
     (`LEFT/RIGHT_STAIR_ZONE_X`), and it only rouses the dead **seeded near
     that stairwell** on the adjacent floor (`STAIR_PULL_NEAR`). You **cannot**
     vacuum a whole floor up the stairs.
   - When you next arrive at a pulled floor, those stairwell-side dead are
     **milling by the steps**, roused. A **building shift clears** any pending
     pulls (the world rearranged — the situation reset).

3. **The Crowbar is a TOOL, not a weapon.** Tagged `is_tool, is_crowbar`.
   It can't attack, force locks, or de-barricade — its one job is the stairwell
   pry. **No durability; consumed on use** (`single_use`). Findable in rooms
   (spawn pool ~ utility rooms) so one is on hand before you hit a wall.

4. **Standard zombies for now.** The horde is standard zombies in this pass; a
   new enemy type debuts here in its own later pass.

## Under the hood

**Seeding (`world_state.gd`).** `is_stair_blocked(floor)` is seeded per
`(floor, run)` via `hash(str(master_seed) + "stairblock" + floor + run)` at
`STAIR_BLOCK_CHANCE` (0.18) — deterministic and re-entry stable, shifting
between the three runs. **Floor 30 (tutorial) and floor 1 (the last step to the
lobby) are never blocked.** `stair_blocks_cleared` (per-run, string-keyed) marks
a stairwell pried open; `clear_stair_block` sets it, and it short-circuits
`is_stair_blocked`.

**Crossing (`stairwell.gd` + `world_state.gd`).** A choke sits on the staircase
*between* two floors, keyed by the upper floor's down-stair (`_choke_floor()`:
`current` going down, `current+1` going up), so it blocks both directions. The
pry lives in `stairwell.gd` (`_begin_pry`/`_tick_pry`/`_commit_pry`), reusing the
door-force channel pattern. On commit: `consume_crowbar()` then
`cross_blocked_stair(choke_floor, arrival_floor)` → `clear_stair_block` +
`shift_building` (reseed, **no heal**) + the one-slot rest cost (burn
`rest_available`, else set `rest_forfeit_pending` — consumed at the next merchant
floor in `on_floor_arrived`) + set `pending_pry_arrival_floor = arrival_floor`
(`choke-1` descending, `current+1` ascending). The transition is factored into
`_perform_transition()` so the plain and post-pry paths share it.

**The shift is shared.** `WorldState.shift_building()` is the single reseed
(master seed + cached apartment layouts + anchor rolls). `player._reseed_zombies`
(the rest path) delegates to it and adds the stamina heal; the crossing uses it
raw.

**Arrival mustering (`building_floors._spawn_zombies`).**
- **Pried arrival** (`pending_pry_arrival_floor == floor`): the floor's whole
  horde spawns clustered in a band beside the arrival stairwell (per
  `stair_spawn_side`) and every one is roused (`alert_to_noise`). One-shot —
  the flag is consumed.
- **Cross-floor pull** (`has_stair_pull(floor)`): zombies keep their **seeded**
  spots (so kill/memory keys stay stable) and **only** those within
  `STAIR_PULL_NEAR` of the **arrival** stairwell are roused. One-shot —
  `consume_stair_pull`.

**Noise recording (`world_state.emit_noise` → `note_cross_floor_pull`).** Every
loud source funnels through `emit_noise`; the pull gate records
`pending_stair_pulls` for the adjacent playable floors (1–29) only when
`radius >= STAIR_NOISE_PULL_MIN` (door_work) and the noise sits in a stairwell
zone. Cleared on `shift_building`, reset in `new_game`, saved/loaded.

**Persistence.** `stair_blocks_cleared`, `pending_stair_pulls`, and
`rest_forfeit_pending` are per-run and saved/loaded. `pending_pry_arrival_floor` is transient (consumed on arrival
within the same session, never crosses a save) and reset in `new_game`.

## The horde (Hazard 2)

Some stairwells are **packed with live enemies** instead of barricaded. No
crowbar — you **fight them off or lure them away** (a thrown can) before the
steps are yours. It blocks **both directions**, like the barricade, but the
"cost" is the fight itself — **no building shift, no rest slot**.

- **Seeding** (`world_state.gd`): `is_stair_horde(floor)` per `(floor, run)`,
  mutually exclusive with a barricade there; floor 30/1 exempt; F2 horde mode
  forces all. ~15% of the stairwells the barricade didn't take.
- **Manifestation** (`building_floors._spawn_stair_hordes`): a seeded cluster of
  `STAIR_HORDE_MIN..MAX` (4–7) standard zombies spawns in the band in front of a
  horde stairwell, in the `stair_horde` group. Spawned at **both landings** of a
  horde staircase (each floor's side), so it blocks either direction. Stable
  per-floor keys (`"<floor>:horde:<choke>:<i>"`) → **kills persist** (dead ones
  don't respawn on re-entry); memory (`apply_saved_zombie`) applies within a
  floor.
- **Blocking** (`stairwell.gd`): `_use_stairs` refuses the crossing while
  `_horde_blocking()` finds any live zombie within `HORDE_BLOCK_RANGE` (300px) of
  the steps. Kill them → cleared for good (via `killed_zombies`); lure them off
  with a can → the steps free up while they're away (a stealth option).

## Tests

- `tests/stair_block_test` — item flags; seeded blocking (determinism +
  floor-30/1 exemptions); clearing; per-run keying; crowbar has/consume;
  `shift_building`; the full crossing (clears + no-heal + rest-slot + arrival
  flag); the cross-floor pull gate (loud-near-stair pulls both neighbours;
  mid-corridor and running don't; tutorial exempt; consume + shift clear);
  save/load round-trip.
- `tests/building_floors_test` — pried arrival clusters + rouses the horde at
  the arrival stairwell (flag consumed); a cross-floor pull rouses **only**
  near-stairwell zombies; a **horde stairwell spawns a cluster** at each
  stairwell (in the `stair_horde` group, at the ends, none mid-corridor) and no
  barricade props in horde mode. `stair_block_test` also covers horde seeding
  (deterministic, exemptions, barricade/horde mutual exclusivity, dev-mode
  exclusivity).

## Dev tooling

**F2** (`dev_force_hazards`) CYCLES `WorldState.dev_hazard_mode` one hazard at a
time so they never overlap: **off → barricades → hordes → fire → off**. Each
press names the new mode.
- **Barricades** (mode 1): every eligible stairwell is barricaded
  (`is_stair_blocked` reads the mode live). Spawn a Crowbar with **F1** to test
  the pry.
- **Hordes** (mode 2): every eligible stairwell spawns a live-enemy cluster
  (applies to floors you enter while the mode is on). Barricades are suppressed.
- **Fire** (mode 3) is still a **cycle placeholder** — forces nothing yet.

Session-only (reset by `new_game`, not saved); exemptions (floor 30 tutorial,
floor 1 stairs) hold in every mode. When fire is built, wire its effect to its
mode constant.

## Barricade keeper (story groundwork)

A later story beat: some barricades were put up by a **living survivor** still on
the floor who won't let you tear their wall down — a narrative encounter (talk /
threaten / maybe a fight) rather than a plain crowbar job.

**Groundwork only** (`world_state.gd`): `barricade_has_keeper(floor)` — seeded
per `(floor, run)`, true for a fraction (`BARRICADE_KEEPER_CHANCE`) of **active**
barricades (returns false once the barricade is cleared or on the exempt
floors); plus `barricade_keeper_state` (`get`/`set`, persisted per run:
`""`/`met`/`hostile`/`cleared`). **Nothing spawns an NPC or drives dialogue
yet** — this is the deterministic predicate + resolution state the full quest
will hang off.

## Open / later

- **Barricade-keeper NPC + quest** — the encounter, dialogue and fight on top of
  the groundwork above.
- **Fire hazard** — the remaining cycle placeholder.
- **Horde polish** — a **new enemy type** for the horde (its own pass), and
  tuning: count/range, whether the whole floor's ambient zombies should thin on a
  horde floor, and a clearer "the steps are swarmed" cue on approach.
- **Melee** doesn't pull cross-floor (quiet by the noise model). If loud melee
  should pull, add a `door_work`-level emit on the relevant swings.
- **Balcony interplay:** a blocked down-stairwell is exactly the pressure that
  makes the balcony descent (THREE_RUN_ARC) worth the stamina/slip risk — an
  alternate way down when you've no crowbar. Wiring a hint is a follow-up.
- **StairPan:** the seamless-pan path is disabled (fade fallback in use); the
  pry commits through `_perform_transition` which handles both, but the milling
  visual has only been exercised on the fade path.
