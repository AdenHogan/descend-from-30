# DF30 — Player Progression (all tiers)

> **Status: BUILT v1 — a PROPOSAL for the owner to steer.** The owner's brief was "player
> upgrades in runs which are temporary, and then permanent ones which can stack across runs"
> (plus: "track how far they made it — necessary for permanent upgrades and player records").
> Nothing in the older docs specified these two tiers, so this is Claude's v1 design: every
> number and perk lives in ONE data file (`scripts/progression.gd`) so it's cheap to retune or
> rethink. The merchant upgrades (STORE_DESIGN.md, FINAL) were NOT changed. Locked by
> `tests/progression_test`.

## The four tiers — one stat fold

Every tier feeds the SAME modifier fold (base × ∏mult + Σadd, never direct writes;
`WorldState._stat_mods_sources`), so they all stack cleanly and every stat getter sees them.

| Tier | Lasts | Earned | Spent / chosen | Where |
|---|---|---|---|---|
| **Weapon** (workbench) | the weapon | scrap | maintenance-room bench, pick 1 of 2 per level | SCRAP_UPGRADES.md |
| **Merchant upgrades** | the whole 3-run arc | merchant visits (25/20/15/10/5) | pick 1 of 2 before the shop | STORE_DESIGN.md |
| **Run boons** (temporary) | THIS character only | reaching milestone floors | pick 1 of 2 from a HUD badge | below |
| **Legacy** (permanent) | the PROFILE, forever | how deep each character got | ranked perks on the profile screen | below |

## Tier 2 — Run boons (temporary)

- **When:** the FIRST time this character reaches a milestone floor — **27, 22, 17, 12, 7**
  (two floors above each merchant floor, so the descent alternates boon → merchant → boon …).
  Any arrival counts (stairs, elevator, warp).
- **How it's offered:** NOT a forced pause (you may arrive mid-fight or mid-stair-pan). A
  **"★ BOON — choose"** badge appears beside the portrait; click it for a pick-1-of-2 (or Pass).
  Unclaimed boons queue up. `boon_offer_ui.gd`.
- **What:** a punchier pool than the merchant's (they don't last): Adrenaline, Second Wind,
  Rage, Steady Nerves, Holding Breath, Sharp Eye, Big Lungs, Light Feet, Brawler, Heightened
  Senses. Seeded per (playthrough, run, floor) — a reload offers the same pair; never a boon you
  already have.
- **Lifetime:** this character. The time skip (`advance_run`) wipes them; a save keeps them.
- State: `WorldState.run_boons`, `run_milestones_seen`, `pending_boon_floors` (per-run, saved).

## Tier 3 — Legacy (permanent)

- **Earned** when a character's story ends: **1 Legacy per floor below 30** they reached (their
  deepest) **+10 for escaping**. A full escape = 40. Shown on the end card ("+13 Legacy") and
  banked into the **profile** at once (`award_run_legacy`) — it outlives every save and New Game.
- **Spent** on the profile screen's **LEGACY** button (`legacy_ui.gd`): ranked perks that apply
  to every run of every playthrough in that save slot, stacking rank on rank:

  | Perk | Per rank | Ranks | Costs |
  |---|---|---|---|
  | Conditioning | +8 max stamina | 5 | 15 / 25 / 40 / 60 / 85 |
  | Recovery | +8% stamina regen | 3 | 20 / 35 / 55 |
  | Light Tread | −6% movement noise | 3 | 15 / 25 / 40 |
  | Knows Where To Look | +3% scavenge find rate | 3 | 20 / 35 / 55 |
  | Range Practice | +4% body-hit chance | 3 | 20 / 35 / 55 |
  | Muscle Memory | +1 melee damage | 1 | 90 |

- State: `WorldState.legacy_points`, `legacy_ranks` (profile file `[legacy]`, per slot).
- The journal's Story tab lists this run's boons + the Legacy ranks.

## Open questions for the owner

- Should Legacy also unlock things (a starting item, a 4th character, cosmetic records) and not
  just stat ranks? `best_depth` (the all-time record) is already tracked for "player records".
- Is 1 per floor + 10 for escaping the right earn rate? (A full run of three deep characters
  ≈ 60–110 Legacy.)
- Should milestone boons also come from other beats (a boss kill, a fully-looted floor)?
- Should run boons ever carry a drawback (like some merchant upgrades do)?
