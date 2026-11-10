# Characters — stats & traits (v1, built)

A playthrough casts **3 of the 4** characters, one per run (morning / afternoon / night), in a
seeded random order (`WorldState.run_cast()`). Each character now **plays differently**: their
traits are a modifier source in the SAME stat fold as upgrades (`base × ∏mult + Σadd`), so
upgrades stack on top and nothing is ever written directly into a stat.

**Single source of truth:** `WorldState.CHARACTER_TRAITS` (world_state.gd). Each entry holds
`mods` (same shape as `UPGRADE_POOL`), `flags` (qualitative skills), and the player-facing
`tagline` / `perks` / `flaws` the journal's Story tab shows. **Keep `perks`/`flaws` in step with
`mods`** — what the journal promises must be exactly what the game applies.

## Roster

| id | Name (owner-set: Joe, Vivianne, Alex, Amina) | Identity | Strengths | Weakness |
|---|---|---|---|---|
| `blond_man` | Joe (the Tenant) | Steady all-rounder | **Two shoves from a full bar, where everyone else gets one** (`push_charges` +1, on every floor from 30 — round 49r); melee −15% stamina | none — the baseline |
| `blond_woman` | Vivianne (the Neighbour) | Endurance + quiet | Sprint drain −20%; stamina regen +15%; 15% quieter | Sprints 12% slower |
| `bald_man` | Alex (the Super) | Knows the building by sound | Hears the **EXACT** enemy count at doors + down the stairwell; listens 25% faster; melee −10% stamina | Unlucky: ~20% more enemies per floor |
| `dark_woman` | Amina (the Nurse) | Lucky hands, shaky aim | Scavenge spots hold something +8% more often; rare finds likelier, junk rarer | −15% gun hit chance |

**Stories (owner round 37):** each character also opens their run on their own cue and carries a personal quest — Joe is
always the tutorial character; Alex hears a scream and finds Mr Hale on 29; Vivianne chases her black cat; Amina is hungry
and locked out. See docs/CHARACTER_STORIES.md.

## The owner's brief → what was built

- **White male (blond_man)** — "all-rounder, two more pushes from the stamina bar, less melee
  drain" → built as asked. His push edge was a ×0.70 push cost (3 pushes into 5); since owner rounds 49q / 49r a shove needs a FULL bar and wipes it, on every floor (docs/STEALTH_SPACES.md §8), so his edge is the second charge — two shoves from a full bar — and the cost multiplier is gone. The Brawler perk gives another character that second charge.
- **White female (blond_woman)** — "slightly less stamina drain, slower run speed" → built as
  asked (sprint drain + regen), plus **quieter movement** (Claude's addition, to give her a
  distinct stealth identity: slow-but-enduring-and-quiet). Only the SPRINT is slower, not walking.
- **Black male (bald_man)** — "improved hearing: exact enemy counts in apartments / downstairs;
  less melee drain; more enemy spawns (less luck)" → built. His melee perk is smaller (−10%) than
  the Tenant's (−15%) so the two don't overlap. Exact hearing re-voices the (already truthful)
  listen report as a number; a BREACH room keeps its "something big" read, since its count is a
  stand-in. Extra enemies: counts are small ints, so ×1.2 uses **seeded fractional rounding**
  (2 × 1.2 = 2.4 → 3 on 40% of floors) — deterministic per (floor, run), so the spawner, a
  stair-pan backdrop and the listen report all agree. Corridors + lobby only (apartments unchanged).
- **Indian female (dark_woman)** — "more desirable items (luck), more missed gun shots" → built.
  Luck reweights each scavenge pool by item `rarity` (1 rare … 4 junk) via
  `LUCK_RARITY_WEIGHT` {1: ×1.6, 2: ×1.2, 3: ×1.0, 4: ×0.55}; pool contents only, so draws stay
  seeded/deterministic. Plus the existing `scavenge_bonus` (+8% find rate).

## New stats added for this (all via the fold)

`melee_cost`, `sprint_speed`, `enemy_count` (mult) and `loot_luck` (add) (`push_cost` was one until round 49r: the shove's cost is now the bar over `push_charges`) — getters
`get_melee_cost_mult` / `get_sprint_speed_mult` / `get_enemy_count_mult`
/ `get_loot_luck`. They're also usable by future UPGRADES (e.g. a "Lucky" boon = `loot_luck`).

## Testing note

`new_game()` rolls a random master seed, so **any test meets any character**. A test asserting
a trait-affected value or line must be trait-aware (see `listen_noise_test`), or pin a character
by searching seeds for `run_character(1) == id` (see `character_stats_test._play_as`).

## Next (owner's plan)

1. ~~Upgrade benches~~ — BUILT (docs/SCRAP_UPGRADES.md).
2. ~~In-run temporary + permanent upgrades~~ — BUILT v1 as a proposal (docs/PROGRESSION.md).
