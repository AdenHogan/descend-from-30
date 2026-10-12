# NPC balance — what was measured, what was fixed, what is still the owner's call (round 40)

> **Round 41 acted on most of this page** (owner decisions): survivors are now *theatre* — melee and gun alike deal and take no real damage
> and never run out of rounds, so "melee immortal / gun useless / Johnny dies on 37% of floors" are settled by design, not by numbers (see
> NPC_AI "Theatre"); Johnny's 10 + 20 stay but are **paid in instalments on a ledger that lasts all three runs**, and he is on floors **10–20**
> (QUESTS "010"); people who can really die are only the **rescues** (NPC_AI "Rescues"). The bullet supply below (≈0.6 a flat; 10 ≈ 17 flats,
> 20 more ≈ 34) is still the right yardstick for what the ledger asks of a playthrough: ≈ 51 flats' worth over three runs. The fights /
> survival tables are history. Also round 41: the opening floors 29–27 are **capped in headcount** (`WorldState.OPENING_COUNT_CAP` 2 / 2 / 3
> dead, `OPENING_STAIR_CAP` 0 / 0 / 1; the phone-playtest probe that prompted it is described in the round-41 entry of CLAUDE.md).

> Re-measure any time: `godot --headless res://tools/npc_balance_report.tscn -- --only=quests,census,loot,fights,floors,johnny,waiter --trials=10`
> (`--speed=8` is the default: physics runs 8× real time with the per-step delta unchanged, so the whole report takes ~10 minutes.)
> All numbers below are from the real scenes and rules, standard dead unless said, floors ~12 (3-5 hp each) unless said. The tool is the
> source of truth; this page is the reading of one run.

## Verdict in four lines
- **Half damage works as specced** (derived from the player's own tables; `survivor_ai_test` pins the maths) — but **melee survivors are effectively immortal** against ordinary dead, and **gun survivors are nearly useless**.
- **Johnny's ask (10 bullets, then 20 more) is out of reach with the current bullet supply** — about 17 apartments' worth for the first ten, 50 for all thirty.
- **Three bugs found and fixed** (quest sites missing in ~1 playthrough in 9; the Talk key also driving a door/lift; zombies stuck "investigating" an unreachable spot) **plus one soft failure** (the quest giver dead before he could be met on ~37% of real floors).
- The dead's new brain and the waiter behave; nothing in the soak (17 populated floors × 40 s, 6 flats × 30 s, a roaming player who walks, swings, talks) broke.

## 1. The numbers

### Fights (a defender, hp 8, at its post; the dead idle 190-280 px away, inside its 250 px leash; 10 trials a cell)
| defender | vs 1 | vs 2 | vs 3 | hp lost | note |
|---|---|---|---|---|---|
| knife | win 100% | win 100% | win 100% (26 s) | **0** | |
| sword | win 100% | win 100% | win 100% (32 s) | **0** | 70% win vs three 6-8 hp dead (43 s) |
| hammer (bat) | win 100% (5 s) | win 100% | win 100% (12 s) | **0** | also beats a Big Zombie (16 s) |
| gun, 6 rounds | win 60% | **0%, dies** | **0%, dies** | dies | 6 rounds × ~56% × 1 damage ≈ 3.4 damage in all |

Why melee never loses a point: every landed hit puts the dead one in its 0.5 s hurt state ("can't attack"), and a survivor's swings come faster than that. It is the same stun the player enjoys, but a survivor **never misses** (the player's misses grow 5% → 10% against hurt enemies).

Why the gun loses: an ally's body shot is half of 2 = **1** (the rule), so 3-5 hp dead need 4-8 hits, i.e. 8-14 shots at 52-60%. It has 6.

### On the real floors (natural dead, player passive on the arrival stair, 60 s)
Melee defenders **survive 76-86%** and finish at 93-96% hp; guns (run 3) **survive 42%** and empty the gun in 3 of 7. A defender is met on ~**29% of floors** (8.2 per descent run 1, 5.7 run 2, 3.0 run 3; waiters 4.3 / 2.7 / 1.6).

### Johnny (hp 10, gun, 6 rounds) on his real floor, 90 s
**Alive 63% (19/30)**; emptied his gun 47%; at the stairs 64%, beside a door 63%. Against bare fights: 70% survive one dead, 40% two, 10% three or four. His shots carry 900 px and **draw the floor to him** (4 dead spread over the corridor: 2.8 beside him at the peak; a hammer defender draws 1.0).

### Waiter (at the lift, 150 s, five dead about)
Alive in 3/3 trials, 15 knocks each; only **1** dead one ever gathers near the lift (its 300 px bang reaches x ≥ 684). Not a magnet in practice.

### Bullets (the real apartments, 240 flats a run)
**0.58 / 0.56 / 0.65 bullets per apartment** (runs 1/2/3); **84% of flats have none**; best flat 8-19. Bullets are 2-3% of finds in four of six room types, **0 in kitchens and bathrooms**, bundles of 2-8 (mean 3.85); the merchant doesn't sell them; zombies don't drop them. Johnny wants **10 ≈ 17 flats**, then **20 more ≈ 34 flats** — and 20 at once is three of five slots (8 a slot).

### Quest placement (400 seeds)
Before the fix: Johnny present in 89.8%, Ethel in 87.8% (the ±3-floor fire clearance ruled out a whole band). After: every seed has both (`quest_test`, 160 seeds, mutation-checked: the old rule loses 30 of 320).

## 2. Fixed in this pass
| # | what | how it was found | fix |
|---|---|---|---|
| 1 | Quests silently absent in ~1 playthrough in 9 | the placement census | `Quests.site` relaxes the fire clearance 3 → 2 → 1 floors instead of giving up |
| 2 | **E to talk also took the door / lift behind the survivor** (a defender posts 56 px from a door; a waiter stands 45 px from the lift, which has an 80 px ride range once powered) — a scene change mid-sentence | reading the E-pollers | a survivor offering Talk holds the press (`WorldState.claim_interact_for_talk`; every scene-changing poller already asks `TutorialManager.interact_guarded()`, which includes it) |
| 3 | A zombie told to investigate an unreachable spot (past the corridor end, behind a wall) pushed at the wall for ever | the code (mutation: it was still `investigate` at x 1214 at the end) | a time limit = the walk + 3 s (`EnemyMind.INVESTIGATE_SLACK`) |
| 4 | Johnny (and Ethel) killable before the player ever met them — the quest lost unoffered | `johnny` on real floors: dead on 37% | `Quests.protects`: until the first conversation the dead can wound a giver, never finish them (data opt-out `protected_until_met`) |
| 5 | Test flake: floor 12 burns for 12.5% of seeds and scorched the dead the survivor/mind tests were counting | a full-gate failure of `enemy_variety_test` traced to survivors, then a second flake in `survivor_ai_test` | tests build on a fire-free floor of the same parity; random placement gated by `WorldState.survivor_rule` |

## 3. Not changed — suggestions, most valuable first
1. **Make Johnny's price payable in instalments.** Keep the owner's 10 / 20 but let the player hand over what they have, the debt carrying across the three runs (Johnny stays; the heirloom forge already works this way). Removes the three-slot problem and turns "17 flats" into "over a session". Pair it with one of:
   - a small **bullet faucet** (merchant stock 016 at ~12 notes each; zombies at 1-2% in the loot pool; or a stash in Johnny's floor band), or
   - lowering the ask to ~6 / ~12.
2. **Give gun survivors a fighting chance.** Either 10-16 rounds (`SurvivorPlan.AMMO_MIN/MAX`, Johnny's `ammo` in `quests.json`), or a fallback so an emptied gun is not a death sentence (hold the butt, or **leave the floor by the stairs**). As it stands 0.5-0.7 per descent are guaranteed casualties that also pull the floor onto themselves.
3. **Give melee survivors a miss chance** (say 15%) and/or fewer hp (6). Today they are untouchable against 1-3 ordinary dead, so "a survivor in trouble you can help" almost never happens; the stun-lock does the rest.
4. **A survivor's gunshot as a pull on the whole floor is thematically right but costs the survivor.** If Johnny stays a gun guy, give him the protection (done) *and* more rounds, or have him fire only at the nearest dead.
5. **Stealth.** The dead now go to a noise's *source* and only chase what they see (100 px). Walking away from the source is much safer than before. Worth a playtest; if it feels too forgiving, give the *searching* state a wider sight (~160 px) rather than restoring the omniscient chase.
6. **Quest buttons are mouse/touch only** (no gamepad/keyboard focus) and small on a phone: give them a 44 px minimum height and focus order.
7. **Survivors don't feel fire or molotovs** (they aren't in the fire/blast groups) — safe for quests, odd for the fantasy.
8. **An unarmed defender cornered swings for 0 damage** and makes noise (120 px) each time; it should cower instead.
9. **Ethel is a run-1-only quest**: if she isn't met in run 1 the couple have turned by run 2. Fine as a design, but say so in the journal (a "she won't be here for long" line) so the player isn't surprised.
10. **Idle dead outside a defender's 250 px leash are never engaged** (it only watches) — good, but it means a defender never clears a floor on its own, which supports the player-takes-initiative rule; keep.

## 4. Verification debt
The tells, the speech bubbles, the pacing of a fight and the choice buttons were checked headless only. The soak test (`npc_soak_test`, 70th suite) asserts invariants (finite positions, named behaviours, the player never held), not feel. Its checks on a *busy* floor can pass without the give-up rule (an investigating zombie is soon overtaken by newer news), so the rule is proven by an **isolated run**: one zombie alone, a still player at the far end, a noise 250 px beyond the east / west wall — it must walk to the wall, press on it, and give up inside the rule's time. Mutation-checked (disabling the budget fails two checks, with the zombie still pressed at x 138 / 1214 after 12 s).
