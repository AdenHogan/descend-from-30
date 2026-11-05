# Balance audit — the owner's full 30 → lobby playtest (2026-11-04)

**Why this exists.** The owner finished a full descent and reported: "it was too damn easy" — stamina comes back by standing still and no stamina item was ever needed, hurt
twice in the whole building, almost no item used beyond the starting kit, Lv3 / Lv4 weapons are overpowered and toolboxes keep them going for ever, and never once
needed a barricaded flat or a breach room. They sent `slot_1_save.json` + `slot_1_profile.cfg`. This note is what the save PROVES, what it cannot, the diagnosis, and a
proposed package. **Nothing in the game was changed by this audit** — every number below is a decision for the owner.

**Re-run it on any save:** `godot --headless res://tools/save_audit.tscn -- --save=/abs/path/slot_N_save.json` (`tools/save_audit.gd` — loads the save into the real game
code inside the test sandbox, re-derives the building from the master seed, prints what the building held against what was met, and what the kit does).

## What the save is
Vivianne (the Neighbour: endurance, 15 % quieter, sprints 12 % slower), **run 1**, saved in the **lobby** (floor 0) at full health, stamina 22 %. No permanent perks
(`perks=[]`, 106 Valour) — so none of the ease is meta-progression. Five run perks (one offer of three at floors 25 / 20 / 15 / 10 / 5): Steady Nerves (+12 % head,
+10 % body), Steady Aim (+8 % head), Deep Pockets, Pack Mule (a 7th slot, −25 % max stamina), Deep Breaths (+50 % stamina regen). Run time about 1 h 50 (the profile's playtime
counter at the start of the run vs now).

## What the building held, against what was met (measured)
| | held | met |
|---|---|---|
| Corridor dead, floors 29-1 | **71** (mean 2.45 a floor, one floor with 10, one with 0) + 12 on stairwells | essentially all: 89 corridor-side kills on record against 71 + 12 stairwell + the hallway and lobby (floors 30 / 0: 7) |
| Dead in the 145 flats | 282 (open flats 69, shut 92, locked 24, barricaded 35, **breached 62**) | 49 kills in flats |
| Flats **originally** open | 40 | **28 entered** |
| Flats originally shut but forceable | 46 | **0 entered** (not one door forced) |
| Flats originally locked / barricaded-locked | 21 / 8 | 1 / 1 (the two keys: 2903, 402 — both held a resident) |
| Flats originally barricaded-forceable | 18 | **0** |
| **Breach rooms** | **12 (62 dead — 5.2 a flat against 1.6 in the others)** | **0** |
| Items found vs left | 64 taken; **96 of the 341 searched nodes still hold an item** | 3 guns, 4 toolboxes, 5 crowbars, 4 extinguishers, 3 bandages, 6 ice packs, a bat, a cricket bat… left on the shelves |
| Medical at the lobby | 3 first aid kits + 3 bandages in the bag, never needed (+ ~15 more lying on floors) | — |
| Bag | 7 slots, 6 used | — |

So the owner is exactly right about the risky content: **the building never asked for it.** 40 open doors (28 % of flats) supplied everything; the 105 shut / locked / barricaded
/ breached flats were skipped without cost, and a breach room pays nothing more than any other flat (round 44).

## What the kit does against the dead (arithmetic from the code, `tools/save_audit.gd` prints it)
* **A standard zombie has 1-8 hit points by floor** (`int(lerp(7, 1, (f-1)/29))` ± 1): 1-2 at floor 29, 2-4 at 20, 3-5 at 15, 4-6 at 10, 6-8 at 1. It walks at **40 px/s**, notices at 100 px, bites from ~30.
* **The Lv3 aluminium bat deals 5** (3 base + Reinforced +1 + tuning "Weight" +1) with **65 px reach** and a 0.8 s swing → **one swing kills a standard on every floor above ~10**
  (worst-case HP ≤ 5 down to floor 15), two below. It reaches more than twice as far as the zombie bites, so at 40 px/s the player gets about a second of free swing: the dead
  essentially never land the first blow. That, not luck, is why "hurt twice" over **139 kills**.
* **Mended (`X_mend`) — "a killing blow doesn't wear it", chance 100 %, per_tier 0.** With one-swing kills nearly every swing is a killing blow, so the bat only wears on swings that do NOT kill. The bat in the bag is at **21 uses** (a fresh one has 15; Reinforced + the level raise the ceiling) after a 139-kill descent — though the kills were shared with whatever else the
  player carried and dropped on the way (the floors hold a hammer, a bat, two knives and two guns the player put down), so this is consistent with the bat barely wearing, not proof of it. A Toolbox (3 uses, restores a weapon to full) is then a luxury, and
  4 more were left on the shelves.
* **The Lv4 gun cannot miss.** Close-range base is head 0.25 / body 0.60; the run perks add head +0.20 / body +0.10, the gun's own perks (Reinforced + Aim Assist + Sights) head +0.23 / body +0.23, and the code clamps `body` to `1 − head`.
  Result: close **68 % head (instant kill) + 32 % body = 100 % hit**; mid (120-250 px) 51 + 49 = **100 %**; far 45 + 55 = **100 %**. Through-and-Through hits the one behind. Additive stacking with no ceiling is the cause.
* **Stamina is not a constraint.** Regen is 10 / s after a 0.8 s pause, × 1.72 here (Deep Breaths × the character) = **a full bar in 4.3 s**; sprint drain × 0.8 gives 6.5 s of sprint on the 75-point bar; a bat swing (26) is paid back in 1.5 s.
  A fight is 1-3 swings, so the bar is back before the next dead body.
* **Health is not a constraint** for the same reason (6 stages, a bite is one; healing items restore 2 / 3 stages and the player carried six spare).

## Diagnosis (ranked by how much each one removes the pressure)
1. **Kill speed vs dead HP / reach / speed** — a one-swing kill with a first strike makes every fight a non-event. (HP curve, bat reach, zombie speed + wind-up.)
2. **Nothing wears** — Mended at 100 %, +15 % durability a level, a 3-use full-repair toolbox on every other shelf: the weapon economy that stopped the descent bot at floor ~18 ("kill capacity",
   docs/BOT_RUNS.md) is simply absent for a player with a Lv3 weapon.
3. **The gun's hit chance is uncapped** (additive perks) — 100 % at every range.
4. **Corridor density is low** (mean 2.45 a floor; 71 in the whole building) and every group is one lane long, so there is nothing to attrit stamina, ammo or health.
5. **Supply exceeds need**: about half the searched nodes held something (64 taken + 96 still holding), 7 slots with one empty, six healing items spare and ~25 more left on shelves and floors, crowbars / toolboxes / extinguishers everywhere.
6. **All the dangerous content is optional and unrewarded** (breach rooms, barricades, locks): the open flats were enough, so the risk was never taken. This is a design gap, not only a number.
7. **Stamina regen has no cost to use it** (stand back and it returns) — a symptom of 1-4, but also cheap to make mean something.

## Proposed package (a first cut — numbers are the owner's call, each is one constant or one table row)
**A. The dead (fixes 1, 4):**
 * HP curve `lerp(7, 1)` → roughly `lerp(10, 3)` ± 1 (top floors 3-5, bottom 8-11). With a 5-damage bat that is 1-2 swings at the top and 2-3 at the bottom; a base bat (3) needs 2-4.
 * Standard speed 40 → 55-60 px/s, bite wind-up 0.8 → ~0.55 s, detection 100 → 130; **bat reach 65 → ~50** so the dead can win the first exchange. (Knife 32 already sits at the bite's range.)
 * Corridor density: keep the opening floors capped (29-27, already), but lift the mean to ~4-5 and let the lower floors carry real packs (6-9), seeded as now, with the same type mix.
**B. Wear (fixes 2):** Mended → a **chance** (30 % + 5 % a tier, like its siblings), not 100 %; Toolbox 3 uses → 2, each restoring 50 % of the maximum instead of "full"; fewer toolboxes in the pools (4 left on shelves in 30 flats).
**C. The gun (fixes 3):** a per-range ceiling on the TOTAL hit chance (e.g. close 0.90, mid 0.70, far 0.45) and the head share capped (0.35), applied after all perks. The perks then buy a smaller gap to the ceiling, not a guarantee.
**D. Supply (fixes 5):** medical frequency −35 %, crowbar / extinguisher / toolbox rarer, first aid 3 states → 2, bandage 2 → 1; consider 5 base slots (7 is the cap, not the default — already true) and leave Pack Mule as it is.
**E. Make risk pay (fixes 6):** breach rooms hold the building's **best cache** (a guaranteed upgraded weapon or scrap bundle, key to a sealed flat) and a Valour bounty for the leader; barricaded flats ×1.5 loot weight; **open flats are the ransacked ones** (loot chance ×0.7, "someone fled through here"); one run need (a fuse, a crowbar for a cabinet) that only behind-the-door flats can supply.
**F. Stamina (fixes 7):** regen delay 0.8 → ~1.6 s and the rate 10 → ~7 / s base, so the recovery rewards a retreat instead of a half-second pause; an empty bar costs a longer lockout (3 s). Do this AFTER A, or it only punishes the player for the wrong reason.

## What the save cannot tell us (so nothing below is claimed from it)
* **When** anything was used or how many times the player was hit — the save is a snapshot. "Hurt twice" fits the evidence (full health, six healing items spare) but is the owner's count, not mine.
* Whether the player **forced** a door that is now OPEN — re-rolling the doors from the seed answers it for shut / barricaded flats (they would be saved as OPEN, and 28 of 40 originally-open flats are the entered ones; the 2 other entered flats were keys).
* **One run, one character** (Vivianne) on **one seed**. The cast changes the numbers (the Super meets 20 % more dead; the Tenant is cheaper to swing), and later runs raise the type mix and add bosses (none in run 1).
* Whether the same player on runs 2 and 3 would find it easy too — those are tougher by design (door decay, heavier types, bosses, fire). The earlier session in the profile died at floors 27 / 22 / 22, so runs 2-3 are not necessarily soft.

## Next
Pick the targets first (what should a skilled player's odds of reaching the lobby on run 1 be? how many healing items should a descent really consume?), then change A-F behind one
difficulty table, re-run `tools/save_audit.tscn` on this seed and the descent bot (`docs/BOT_RUNS.md`) before and after so the effect is measured, not felt.

## Changed since (owner's first reply, 2026-11-04)
The owner added, on top of the save: the aluminium bat ended with **damage over time** (hit once, step back, the enemy dies) and Mended, and "the gun always had plentiful bullets and one-shot everything" — and, from the same playtest, "except for the bullets I never needed to buy anything" in the shop. First cuts, each one constant or one table row (package A, C and the rest of B are still undecided):
* **Bullets are not sold.** The always-there bundle (`get_merchant_stock`, `BULLET_BUY_PRICE`, `BULLET_STOCK_RANGE`) is gone; its slot went back to the ordinary wares (3-4 commons as before); a save that still holds one drops it on load. He still BUYS bullets (2 a round) — not asked, not changed.
* **Toolbox: 1 use** (was 3) **and half as common** — node pool weight 1 → 0.5 in the kitchen, study and dining room; a maintenance node holds one 18 % of the time (was 36 %; the Fuse / Scrap / Notes shares are unchanged, the room is emptier by the difference). A resident's pocket still holds one 1 time in 30 of a 0-2 item roll (a whole-number draw, left alone). **Its shop price (130) is unchanged** — one charge for 130 is dear; say if it should drop.
* **Bullets found in the world −15 %**: the bundle (`LootUI.AMMO_BUNDLE_WEIGHTS`) averages 4.74 rounds, was 5.58. It is the lever every found bundle shares (nodes AND the gun-paired finds), so how often bullets turn up did not change. NOT changed: bullets in the dead's pockets, a resident's / survivor's gifts, the tutorial's fixed bundles, a corridor boss's loot pick.
* **Cash found +20 %** (`WorldState.cash_found`, x1.2): a bundle rolled at a pickup (node, body, zombie — 5-15 → 6-18) and a Big Zombie's / boss's money. Gifts, quest pay and the shop's prices are not scaled.
* **Scrap outside burnt flats +10 %**: an ordinary bag 6-14 → 7-15 (mean 10 → 11); the chance (7 %) and the burnt flat's bag (14-30) are unchanged. Salvage at the bench is a different faucet and was not touched.
* **Shop variety**: `SHOP_COMMON` went from 7 wares to 13 — an Empty Bottle, Clothes, a Screwdriver, a Molotov, a Torch and a Crowbar join the everyday finds (prices = what `ITEM_VALUE` already said, so what he PAYS for those did not move). The quality / legendary bands are unchanged. Measured in `merchant_smoke_test._test_shop_variety`.
Still to decide: the Mended 100 % free killing blow, the damage-over-time mods, the gun's hit-chance ceiling (package B / C) — the owner's own account says the bat and the gun were the problem, which the numbers above only touch through supply.

## Changed since (owner's second and third replies, 2026-11-04)
After the supply cuts above the owner asked for the weapon loop itself to be closed, and for encounters to bite harder. What now stands:
* **The bench no longer mends and no longer hands out free points.** A level-up raises the durability CEILING (+15 % a level) but leaves the weapon exactly as worn as it was; the Tune tab and its points are gone, the stats (Weight, Edge, Reach, Handling, Balance, Temper / Sights, Magazine, Oiled, Hand-loaded) are ranks in the ordinary pick of two, paid in scrap like everything else; a **REPAIR** tab mends a worn weapon for scrap (30 x (1 + 0.15 x (level - 1)) x the share worn, +8 for a damaged gun, min 4). Detail and the save rules: `SCRAP_UPGRADES.md` "Round 49m". Price numbers are first guesses (`WeaponUpgrades.REPAIR_*`).
* **Every melee enemy reaches 8 px further**: standard 30 -> 38, long-arm 62 -> 70, crawler 60 -> 68, big 55 -> 63 (the crawler's and the big's DESIGNED ranges were below their body-contact floors, so the real before-numbers are the floors). The player's own reach is untouched (knife 32 from the body's edge = 42 from its centre, so even the weakest weapon still out-reaches a standard's bite by 4 px; a hammer 65). A stationary player is now bitten from 15 px before contact. `NPC_AI.md` "Reach and followers".
* **The dead that are chasing you may follow you into a flat** (not always: 50 / 60 / 70 % per chaser by run, at most two). `NPC_AI.md` "Reach and followers".
Not touched: Mended (the free killing blow), the damage-over-time mods, the gun's hit-chance ceiling, the dead's HP / speed / density (package A/C of this doc). **Not measured:** how much harder the building plays with the +8 px and the followers (no bot sweep has been run on this tree) - treat the figures as dials, not as results.

## Changed since (owner's fourth reply, 2026-11-04: the first five floors are a ramp)
*"We don't need to change the data on the tutorial or even the first five levels of descent… incrementally increase so it doesn't go from easy to deathly difficult in the space of one floor… by the time a player reaches floor 25 shit has gotten tough."* Everything above that is a **difficulty cut** is now a RAMP over floors 29 → 25 (`WorldState.descent_ramp`: 0 on floor 30 and 29, .25 / .5 / .75 on 28 / 27 / 26, 1 from floor 25 down; ONE function, a pure function of the floor):
* **ramped** — the enemies' +8 px reach (standard 30 → 38, the others likewise), the dead following into flats (none on 30 / 29, then up to 50-70 %), found bullets (the 5.58-round table slides to the 4.74 one), the toolbox (pool weight 1 → .5, charges 3 → 2 → 1 [3 on floors 30-28, 2 on 27-26, 1 from 25], a maintenance node's share .36 → .18);
* **not ramped, deliberately** — the workbench rework (the first bench is floor 27 and its first step is the plain Reinforce), the merchant (no bullets; the first lift is floor 25), shop variety, cash +20 %, scrap +10 % (supply, not difficulty);
* the tutorial-lunge fix and the other bug fixes of rounds 49m stay: they are not difficulty.
Bot A/B and the sweep: `docs/bot_runs/round49n_sweep.md`. The bug list: `docs/BUG_LEDGER.md`.
