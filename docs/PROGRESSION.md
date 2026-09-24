# DF30 — Player Progression (all tiers)

> **Status: BUILT.** Run boons (tier 2) are Claude's v1 proposal. The permanent tier (tier 3,
> **Descent Valour**) is the OWNER'S design (it replaced Claude's earlier ranked "Legacy" shop).
> Every number and perk lives in ONE data file (`scripts/progression.gd`) so it's cheap to retune.
> The merchant upgrades (STORE_DESIGN.md, FINAL) were NOT changed, except that a perk kept
> permanently no longer appears in the merchant's offers. Locked by `tests/progression_test`.

## The four tiers — one stat fold

Every tier feeds the SAME modifier fold (base × ∏mult + Σadd, never direct writes;
`WorldState._stat_mods_sources`), so they all stack cleanly and every stat getter sees them.

| Tier | Lasts | Earned | Spent / chosen | Where |
|---|---|---|---|---|
| **Weapon** (workbench) | the weapon | scrap | maintenance-room bench, pick 1 of 2 per level | SCRAP_UPGRADES.md |
| **Merchant upgrades** | the whole 3-run arc | merchant visits (25/20/15/10/5) | pick 1 of 2 before the shop | STORE_DESIGN.md |
| **Run boons** (temporary) | THIS character only | reaching milestone floors | pick 1 of 2 from a HUD badge | below |
| **Descent Valour** (permanent) | the PROFILE, forever | how deep each run got (scored at the session's end) | keep ONE perk found that session; max 10 kept | below |

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

## Tier 3 — Descent Valour (permanent)

The owner's design, verbatim intent: when the **third** character's story ends (escape or death),
the session is scored and the player may keep ONE perk they found along the way — forever.

- **Earning Valour** (`Progression.valour_for_run`, summed over the three runs): each run earns
  by the deepest floor that character reached, weighted toward the bottom, plus a bonus for
  walking out: `d + floor(d² / 60)` where `d` = floors below 30, **+10 if they escaped**.

  | Deepest | Valour |
  |---|---|
  | 25 (5 floors) | 5 |
  | 15 | 18 |
  | 10 | 26 |
  | Lobby (escaped) | 30 + 15 + 10 = **55** |

  Three escapes = 165. **Quests + NPCs count too (owner):** each quest completed that run
  **+8**, each NPC aided **+4** (`VALOUR_PER_QUEST` / `VALOUR_PER_NPC`). Quests aren't built
  yet — the quest system calls `WorldState.note_quest_completed()` / `note_npc_aided()` (per-run
  counts in the chronicle), and the end screen shows them per run. Valour is banked to the
  **profile** at once and can be **saved** across sessions (the player may take nothing).
- **The descent boon** (owner): Valour IS the descent boon, plus an escaping character leaves
  ONE item with the SHOPKEEPER, handed free to the next character after their first shop
  upgrade (floor 25) — see THREE_RUN_ARC.md "Descent boon" (the handoff).
- **The offer** (`WorldState.finish_session`, called at the arc end in `game.gd` / `lobby_exit.gd`):
  up to **3** (`OFFER_COUNT`) perks drawn **uniformly at random — no weighting** — from the perks
  **acquired this session** (`WorldState.session_perks`: every merchant upgrade taken + every run
  boon taken, in any of the three runs; kept across the time skip, saved with the game, cleared by
  New Game). A perk already kept is never offered. So to keep a perk you must farm it that session.
  The offer is stored in the profile until resolved, so quitting on the end screen doesn't lose it
  (it's reachable from the profile screen's LEGACY panel). Scoring is idempotent per playthrough.
- **Buying** (`buy_permanent`): ONE perk per session. Cost by the merchant's rarity weight (w6-7: 30,
  w4-5: 40, w3: 55, w2: 70, w1: 90), drawbacks −20, run boons flat 60; overrides where rarity lies
  about permanent value: **Deep Pockets 110**, Pack Mule 70.
- **Permanent perks** (`WorldState.permanent_perks`, profile `[valour]`) are a source in the stat fold
  for every run of every new game in that save slot — e.g. Deep Pockets kept = every game starts with
  the 6th slot open. A kept perk is **removed from the temporary pools** (merchant offers +
  run-boon offers).
- **Cap 10** (`PERMANENT_CAP`). Buying with a full collection asks which kept perk to **trade out**.
  The LEGACY panel's **Collection** tab also trades perks out (two presses to confirm). Trading out
  refunds **half** its cost (`TRADE_REFUND`).
- **UI**: `legacy_ui.gd` — tabs *Descent offer* / *Collection N/10*. The end-of-session screen
  (`game_over.gd`) lists each run's depth → Valour and the total, then opens the offer; the profile
  screen's **LEGACY N/10** button opens the same panel. The journal lists kept perks.
- Old profiles: an early build's "Legacy" points carry over as Valour (ranks are dropped).

## Interpretations to confirm (owner)

- **3 perks offered** (the brief says three, and later "the two perks available") — `OFFER_COUNT`.
- **Trade-out refund of 50%** — the brief says perks can be "traded out" but not what for.
- **The prices + the Valour curve** above are first-pass numbers; need a playtest.
- The offer is seeded from a true random roll (not the master seed), as "truly random" asked.
- Run boons can be kept permanently too (they count as perks acquired in the session).

## Open questions for the owner

- Should milestone boons also come from other beats (a boss kill, a fully-looted floor)?
- Should run boons ever carry a drawback (like some merchant upgrades do)?
