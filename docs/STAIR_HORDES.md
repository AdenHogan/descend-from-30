# DF30 — Heavy Stairwell Hordes & the Crowbar

> **Status:** agreed design (owner Q&A), v1 implemented. Reintroduces
> rest/building-reset as a live tactical decision and makes noise near
> stairwells matter across floors.

Some **down-stairwells** are choked wall-to-wall with the dead. This is not a
fight you win — it's a **blockage you pry through with a Crowbar**. Getting
through is passable but costly, and it stirs the building on both sides of the
stairs, so where and when you cross is a real decision.

## The rules (as agreed)

1. **Passable, but costly — a Crowbar job.**
   - A blocked down-stairwell refuses a normal descent. With a **Crowbar (035)**
     the player runs a **channeled pry** (`PRY_TIME`, ~3s). It is **loud from
     the first heave** (`door_work` noise at the stairwell), so the **current
     floor's dead converge on the steps** while you work. Walking off the
     stairwell or taking any other committed action cancels it.
   - Completing the pry **spends the crowbar** (single-use, consumed — see
     below), opens that stairwell **for the rest of the run**, and commits the
     crossing.
   - **Cost = a rest slot.** Crossing triggers the **same building shift a rest
     does** (`WorldState.shift_building` — the world reseeds and the dead
     wander), but is **not billed as rest**: **no stamina heal**, no rest-stat
     bump. It also **forfeits your next rest** (`rest_available = false`). So
     you weigh: spend the shift here to punch through, or save it to actually
     rest and heal.
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

**Crossing (`stairwell.gd` + `world_state.gd`).** The pry lives in
`stairwell.gd` (`_begin_pry`/`_tick_pry`/`_commit_pry`), reusing the door-force
channel pattern. On commit: `consume_crowbar()` then
`cross_blocked_stair(floor)` → `clear_stair_block` + `shift_building`
(reseed, **no heal**) + `rest_available = false` + set
`pending_pry_arrival_floor = floor - 1`. The normal descent transition is
factored into `_perform_transition()` so both the plain and post-pry paths use
it.

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

**Persistence.** `stair_blocks_cleared` and `pending_stair_pulls` are per-run
and saved/loaded. `pending_pry_arrival_floor` is transient (consumed on arrival
within the same session, never crosses a save) and reset in `new_game`.

## Tests

- `tests/stair_block_test` — item flags; seeded blocking (determinism +
  floor-30/1 exemptions); clearing; per-run keying; crowbar has/consume;
  `shift_building`; the full crossing (clears + no-heal + rest-slot + arrival
  flag); the cross-floor pull gate (loud-near-stair pulls both neighbours;
  mid-corridor and running don't; tutorial exempt; consume + shift clear);
  save/load round-trip.
- `tests/building_floors_test` — pried arrival clusters + rouses the horde at
  the arrival stairwell (flag consumed); a cross-floor pull rouses **only**
  near-stairwell zombies (no far-corridor zombie roused; flag consumed).

## Open / later

- **New enemy type** for the horde (agreed: its own later pass).
- **Melee** doesn't pull cross-floor (quiet by the noise model). If loud melee
  should pull, add a `door_work`-level emit on the relevant swings.
- **Balcony interplay:** a blocked down-stairwell is exactly the pressure that
  makes the balcony descent (THREE_RUN_ARC) worth the stamina/slip risk — an
  alternate way down when you've no crowbar. Wiring a hint is a follow-up.
- **StairPan:** the seamless-pan path is disabled (fade fallback in use); the
  pry commits through `_perform_transition` which handles both, but the milling
  visual has only been exercised on the fade path.
