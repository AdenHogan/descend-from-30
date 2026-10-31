# Round 49f bot sweep (2026-10-31) — the new loot pools, two-room flats, dead-count scaling

12 playthroughs = 36 characters: seeds 101–106 × policies `need` and `safe`, 3 jobs at a time, built from the tree at `0ab33e37` (before the two fixes below)
(new loot pools from round 49f, two-room flats mixed in at 30 %, the dead scaled to the flat's length). Tool: `tools/bot_sweep.py` +
`tools/bot_summary.py`. **A small sample** (6 seeds per policy): read the medians as "no collapse, no lift", not as measurements — the
round 45 sweep had 12 seeds a policy.

What it found (all of it from the anomaly table below, the rest is balance):

* `open_furniture.gd:137 _stop_live_screens` — `call_group` on a null tree when a flat re-entered with a switched-off screen whose
  `refresh()` ran before the node was in the tree (3 playthroughs). **Fixed** (waits for `tree_entered`; `open_furniture_test._test_screen_off_before_the_tree`).
* `DOOR_TIMEOUT` / `NO_PROGRESS` — 12 occurrences in 5 playthroughs (floors 24–26): the player pinned for 30–75 s between a solid zombie and a defender's
  endless performative fight. The `slide=["StaticBody2D…"]` in the line is just the floor. The stall trace showed the player shuffling
  ±0.58 px a frame, which beat the anti-stuck net's per-frame "moved < 0.5 px" test every other frame, so `_stuck_time` never grew and the
  net never fired. **Fixed**: `player._update_unjam` now measures NET progress against a reference x (`UNJAM_PROGRESS` 3 px); the
  round-44 "open, found not fixed" pin is this. `softlock_test._test_jitter_pin` (mutation-checked: the old threshold fails it).
* `TAKE_NO_EFFECT` ×1 and `DROP_NOT_TAKEN` ×1: one each, NOT investigated.

Balance read-out: depth is not worse than round 45 (`need` medians 22/22/23 vs 25/28/26 there, but 6 seeds against 12 and the loot has
since been rebalanced on purpose: fewer guns, more bullets), weapons 0.31 a flat, bullets 0.12 a flat in the high band, 8 % of flats cost a hit, 6 breach flats entered
in 317. The summary tool does not split two-room flats from three-room ones, so there are NO two-room-specific numbers.

## need — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20 / 22 / 23.2 / 27 | 0 | 6 | 0 | 805 | 28 |
| 2 | 6 | 16 / 22 / 21.0 / 25 | 0 | 6 | 0 | 867 | 37 |
| 3 | 6 | 21 / 23 / 23.0 / 25 | 0 | 6 | 0 | 513 | 33 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 6 / 6 | 3 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 6 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 1×f27, 4×f25, 5×f23, 2×f22, 2×f21, 2×f20, 1×f19, 1×f16

What stood near at death: standard ×6; spitter,standard ×4; crawler,standard ×1; crawler ×1; big,longarm,spitter,standard ×1; big,crawler,standard ×1; boss,crawler,longarm,spitter,standard ×1; big,longarm,spitter ×1; big,longarm,standard ×1; longarm,standard ×1

Time alive before death: median 762 s, range 406–1748 s

Barricaded stairwells met: 10 across 18 character-runs (0.6 per run); 3 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor 28 (median, 10 runs); both hammers broke by floor 28 (10 runs); gun empty by floor 26 (16 runs).

Stage-hits absorbed per character-run: median 16 (min 12, max 24); first aids used: median 5. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×17, f20 ×4; upgrade picks taken: 11.

Upgrades taken: Rage ×3; Adrenaline ×2; Bruiser ×1; Featherfoot ×1; Marathoner ×1; Deep Breaths ×1; Strong Arm ×1; Sprinter's Legs ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f20 7.5/entry (4 entries, 2 deaths); f22 5.5/entry (8 entries, 2 deaths); f23 3.5/entry (13 entries, 5 deaths); f27 2.6/entry (18 entries, 1 deaths); f21 2.5/entry (6 entries, 2 deaths); f24 2.4/entry (13 entries, 0 deaths); f25 2.1/entry (17 entries, 4 deaths); f26 2.1/entry (17 entries, 0 deaths)

### need — scavenging

Over 18 character-runs the bot went into **317 apartments** and **31 maintenance rooms** (17.6 flats and 1.7 staff rooms per character).

Per flat: 34 s inside (median; 0–86), 3.8 nodes opened, 2.4 of them held something, 1.2 dead met at most at once; the bot took at least one hit in **24 of 317** (8%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 73 | 49 | 5.7 | 2.74 | 1.5 | 1.5 | 0.15 | 8% |
| 2 | 120 | 36 | 4.0 | 2.65 | 1.3 | 1.4 | 0.20 | 7% |
| 3 | 124 | 20 | 2.6 | 1.87 | 1.0 | 1.3 | 0.15 | 7% |

By how the door stood: open — 232 flats, 0.05 hits, 1.2 kills, 1.1 dead met; shut (locked) — 36 flats, 0.11 hits, 1.9 kills, 1.4 dead met; shut (forceable) — 35 flats, 0.37 hits, 1.6 kills, 1.3 dead met; ? — 6 flats, 0.00 hits, 1.5 kills, 1.3 dead met; breached — 6 flats, 4.00 hits, 2.8 kills, 2.7 dead met; barricaded (forceable) — 2 flats, 0.00 hits, 0.5 kills, 0.5 dead met

How the flats ended: all searched ×276, ? ×38, left hurt ×2, warned off by a resident ×1

**What the nodes held** (797 items shown across 1282 nodes opened — 62% of nodes held something):

Scrap Bag ×91 (taken 91); Battery ×57 (taken 3); Tinned Food ×54 (taken 6); Torch ×44 (taken 1); Bank Notes ×42 (taken 42); Bullets ×39 (taken 29); Clothes ×38 (taken 2); Torn Clothes ×34 (taken 2); Painkillers ×28 (taken 7); Molotov Cocktail ×27 (taken 4); Broken Bottle ×27 (taken 0); Knife ×27 (taken 4); Toolbox ×22 (taken 2); Hammer ×22 (taken 8)

Why things were left: bag full ×439, not worth a slot ×86

Finds per flat entered: weapons 0.31 · bullets 0.12 · first aid / bandages / painkillers 0.17 · keys 0.05 · scrap bags 0.29 · cash 0.13 · empty wallets 0.03 · crowbars 0.03 · fuses 0.07

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 303 | 2.49 | 0.31 | 0.12 | 0.17 |
| mid 11-20 | 14 | 3.07 | 0.36 | 0.14 | 0.29 |

Doors the bot did NOT go through (400): needs a weapon with 3+ uses ×129, barricaded ×110, locked, no key, nothing to force it ×86, too hurt to go in, nothing to heal with ×41, breach room, unarmed ×20, barricaded, weapon too worn ×13, breach room, hurt ×1

**Economy per character** (end of the character's life): scrap median 34 (max 369), notes median 29 (max 109); workbench upgrades 30, tunings 10, salvaged 26; shop: 11 visits, 5 things bought, 235 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Need 50 scrap — you have” ×12, “Need 30 scrap — you have” ×11, “Needs a spare Lv1 Gun.” ×6, “Needs a spare Lv1 bat, c” ×3, “Need 80 scrap — you have” ×1, “Needs a spare Lv2 bat, c” ×1

### need — coverage

Exercised: an apartment door entered ×311, a shut door forced open ×37, a locked door forced ×34, a key used on its door ×2, a barricaded door torn open ×3, a breach room entered ×6, a scavenge node searched ×1292, an item taken from a node ×272, an item left on a node ×525, an item put down for a better one ×114, a world drop picked up ×127, a set-back node reached ×828, scrap taken from a burnt flat ×72, a maintenance room entered ×31, the fuse box used ×6, a fuse fitted ×9, the elevator powered ×1, the workbench opened ×30, a weapon upgraded ×30, a weapon tuned ×10, a broken item salvaged ×26, the merchant's shop used ×11, something bought ×5, the gun reloaded from the bag ×14, something mended with a toolbox ×2, a crowbar handed over ×10

**Never exercised in this configuration:** the elevator ridden, something sold, a Molotov thrown

### need — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| DOOR_TIMEOUT | 4 | 2 | run 1 floor 26: floor 26 apt 2601: gave up at the door, stage walk, state open (door x=829, near=false) :: atk=false(cd=-0.00) dying=false escaping=false pack= lash=false slide=["StaticBody2D@544[-,layer1]"] unjam=0.00 phased=1 x= |
| ENGINE_ERROR_GAME | 3 | 3 | run 3 floor 28: scene/main/node.h:549 in get_tree(): Parameter "data.tree" is null. |
| SCRIPT_ERROR_GAME | 3 | 3 | run 3 floor 28: res://scripts/open_furniture.gd:137 in _stop_live_screens(): Cannot call method 'call_group' on a null value. |
| TAKE_NO_EFFECT | 1 | 1 | run 1 floor 24: floor 24 2404: took 016 from anchor_study_filing_cabinet but nothing in the bag / wallet / scrap changed (free slots 1, bag 004:1/007:1/022:1/033:24) |
| NO_PROGRESS | 1 | 1 | run 2 floor 24: floor 24: nothing changed for 30 s — phase=play scene=corridor shop=none door=MAINT24 stage=walk state=open :: atk=false(cd=0.00) dying=false escaping=false pack= lash=false slide=["CharacterBody2D@459[enemy_zombie |
| DROP_NOT_TAKEN | 1 | 1 | run 3 floor 23: floor 23: pressed [interact] on a 006 drop 3 times and it stayed on the floor (bag 007:2:1/002:1:7/022:1:1/022:1:1/w68/s227/utrue, free slots 1) |

Engine errors caught by the in-game hook (distinct): 2

- **ENGINE_ERROR/game** ×4 in 3 playthroughs — `scene/main/node.h:549` Parameter "data.tree" is null. (first on floor 28, room.tscn)
- **SCRIPT_ERROR/game** ×4 in 3 playthroughs — `res://scripts/open_furniture.gd:137` Cannot call method 'call_group' on a null value. (first on floor 28, room.tscn)

Engine findings in the run logs (excluding the exit-time leak notices): 2 distinct

- ×4 in 3 runs — `ERROR: Parameter "data.tree" is null.` at: get_tree (scene/main/node.h:549)
- ×4 in 3 runs — `SCRIPT ERROR: Cannot call method 'call_group' on a null value.` at: _stop_live_screens (res://scripts/open_furniture.gd:137)

## safe — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20 / 22 / 23.2 / 27 | 0 | 6 | 0 | 803 | 32 |
| 2 | 6 | 11 / 23 / 21.2 / 25 | 0 | 6 | 0 | 869 | 31 |
| 3 | 6 | 9 / 16 / 16.3 / 25 | 0 | 6 | 0 | 1156 | 52 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 6 / 6 | 2 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 6 / 6 | 4 / 6 | 2 / 6 | 2 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 1×f27, 4×f25, 3×f23, 2×f22, 1×f21, 2×f20, 1×f17, 1×f16, 1×f11, 1×f10, 1×f9

What stood near at death: standard ×7; spitter,standard ×2; crawler,standard ×1; big,crawler,longarm,standard ×1; big,longarm,spitter,standard ×1; big,crawler,standard ×1; spitter ×1; boss,crawler,longarm,spitter,standard ×1; big,spitter ×1; crawler ×1; boss,standard ×1

Time alive before death: median 869 s, range 295–3150 s

Barricaded stairwells met: 11 across 18 character-runs (0.6 per run); 4 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor 27 (median, 12 runs); both hammers broke by floor 27 (12 runs); gun empty by floor 26 (16 runs).

Stage-hits absorbed per character-run: median 16 (min 14, max 42); first aids used: median 5. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×16, f20 ×7, f15 ×2, f10 ×2; upgrade picks taken: 14.

Upgrades taken: Rage ×3; Deep Breaths ×2; Bruiser ×1; Featherfoot ×1; Deep Pockets ×1; Night Eyes ×1; Soft Soles ×1; Marathoner ×1; Adrenaline ×1; Quick Recovery ×1; Efficient Stride ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f25 4.4/entry (16 entries, 4 deaths); f11 4.0/entry (3 entries, 1 deaths); f22 3.8/entry (9 entries, 2 deaths); f19 3.5/entry (4 entries, 0 deaths); f23 3.2/entry (12 entries, 3 deaths); f20 3.0/entry (7 entries, 2 deaths); f18 2.5/entry (4 entries, 0 deaths); f21 2.1/entry (8 entries, 1 deaths)

### safe — scavenging

Over 18 character-runs the bot went into **355 apartments** and **43 maintenance rooms** (19.7 flats and 2.4 staff rooms per character).

Per flat: 42 s inside (median; 0–86), 4.2 nodes opened, 2.4 of them held something, 1.2 dead met at most at once; the bot took at least one hit in **25 of 355** (7%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 73 | 50 | 5.7 | 2.75 | 1.5 | 1.6 | 0.21 | 9% |
| 2 | 101 | 41 | 4.1 | 2.72 | 1.3 | 1.5 | 0.10 | 5% |
| 3 | 181 | 24 | 3.6 | 2.17 | 1.0 | 1.2 | 0.10 | 6% |

By how the door stood: open — 253 flats, 0.08 hits, 1.3 kills, 1.2 dead met; shut (forceable) — 50 flats, 0.44 hits, 1.7 kills, 1.3 dead met; shut (locked) — 42 flats, 0.02 hits, 1.9 kills, 1.4 dead met; ? — 7 flats, 0.00 hits, 0.7 kills, 0.6 dead met; barricaded (forceable) — 2 flats, 0.00 hits, 0.5 kills, 0.5 dead met; barricaded (locked) — 1 flats, 0.00 hits, 0.0 kills, 0.0 dead met

How the flats ended: all searched ×315, ? ×39, warned off by a resident ×1

**What the nodes held** (932 items shown across 1559 nodes opened — 60% of nodes held something):

Scrap Bag ×105 (taken 105); Battery ×57 (taken 1); Tinned Food ×55 (taken 5); Bullets ×51 (taken 32); Bank Notes ×51 (taken 51); Knife ×45 (taken 10); Torch ×40 (taken 2); Molotov Cocktail ×39 (taken 6); Clothes ×36 (taken 1); Fuse ×33 (taken 14); Broken Bottle ×32 (taken 0); Torn Clothes ×30 (taken 5); Toolbox ×30 (taken 8); Painkillers ×28 (taken 12)

Why things were left: bag full ×507, not worth a slot ×90

Finds per flat entered: weapons 0.39 · bullets 0.14 · first aid / bandages / painkillers 0.19 · keys 0.06 · scrap bags 0.30 · cash 0.14 · empty wallets 0.03 · crowbars 0.04 · fuses 0.09

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 284 | 2.56 | 0.33 | 0.14 | 0.18 |
| mid 11-20 | 66 | 2.82 | 0.70 | 0.12 | 0.23 |
| low 1-10 | 5 | 3.80 | 0.20 | 0.40 | 0.60 |

Doors the bot did NOT go through (459): needs a weapon with 3+ uses ×131, barricaded ×129, locked, no key, nothing to force it ×106, breach room (avoided) ×52, too hurt to go in, nothing to heal with ×28, barricaded, weapon too worn ×13

**Economy per character** (end of the character's life): scrap median 28 (max 342), notes median 42 (max 322); workbench upgrades 36, tunings 10, salvaged 20; shop: 14 visits, 8 things bought, 375 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Need 50 scrap — you have” ×21, “Need 30 scrap — you have” ×20, “Needs a spare Lv1 Gun.” ×12, “Needs a spare Lv1 bat, c” ×9

### safe — coverage

Exercised: an apartment door entered ×348, a shut door forced open ×52, a locked door forced ×41, a key used on its door ×2, a barricaded door torn open ×4, a scavenge node searched ×1567, an item taken from a node ×335, an item left on a node ×597, an item put down for a better one ×122, a world drop picked up ×144, a set-back node reached ×1021, scrap taken from a burnt flat ×82, a maintenance room entered ×39, the fuse box used ×10, a fuse fitted ×13, the elevator powered ×3, the workbench opened ×42, a weapon upgraded ×36, a weapon tuned ×10, a broken item salvaged ×20, the merchant's shop used ×14, something bought ×8, the gun reloaded from the bag ×21, something mended with a toolbox ×6, a Molotov thrown ×1, a crowbar handed over ×11

**Never exercised in this configuration:** a breach room entered, the elevator ridden, something sold

### safe — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| DOOR_TIMEOUT | 5 | 3 | run 1 floor 26: floor 26 apt 2601: gave up at the door, stage walk, state open (door x=829, near=false) :: atk=false(cd=-0.00) dying=false escaping=false pack= lash=false slide=["StaticBody2D@544[-,layer1]"] unjam=0.00 phased=1 x= |
| ENGINE_ERROR_GAME | 3 | 3 | run 3 floor 28: scene/main/node.h:549 in get_tree(): Parameter "data.tree" is null. |
| SCRIPT_ERROR_GAME | 3 | 3 | run 3 floor 28: res://scripts/open_furniture.gd:137 in _stop_live_screens(): Cannot call method 'call_group' on a null value. |
| NO_PROGRESS | 2 | 2 | run 2 floor 25: floor 25: nothing changed for 30 s — phase=play scene=corridor shop=done door=2503 stage=walk state=open :: atk=false(cd=0.00) dying=false escaping=false pack= lash=false slide=["StaticBody2D@544[-,layer1]"] unjam= |

Engine errors caught by the in-game hook (distinct): 2

- **ENGINE_ERROR/game** ×4 in 3 playthroughs — `scene/main/node.h:549` Parameter "data.tree" is null. (first on floor 28, room.tscn)
- **SCRIPT_ERROR/game** ×4 in 3 playthroughs — `res://scripts/open_furniture.gd:137` Cannot call method 'call_group' on a null value. (first on floor 28, room.tscn)

Engine findings in the run logs (excluding the exit-time leak notices): 2 distinct

- ×4 in 3 runs — `ERROR: Parameter "data.tree" is null.` at: get_tree (scene/main/node.h:549)
- ×4 in 3 runs — `SCRIPT ERROR: Cannot call method 'call_group' on a null value.` at: _stop_live_screens (res://scripts/open_furniture.gd:137)



## Replay of the pinned seeds (2026-10-31, after the anti-stuck fix)

The owner asked for the seeds that pinned to be replayed ("we cannot have any stuck issues or soft locks"). Seeds 101, 102 and 104 x `need` / `safe` (6 playthroughs, 18 characters), built from `54e44995`.

**Replay 1 (the build with the net-progress fix, no bot changes): it still pinned** — `need_101` and `safe_101` at floor 26 flat 2601 (`DOOR_TIMEOUT`, 75 s) and `need_102` at floor 25 flat 2503 (`NO_PROGRESS` + `DOOR_TIMEOUT`, 166 s). So the earlier "fixed" claim for those seeds was wrong.

**The 2503 pin, from its `[stall]` trace, was the BOT, not the game**: the keys alternated `move_right` / `move_left` on EVERY physics frame (x 1024.98 <-> 1022.48, `real_v` +-150, `stuck=30.10`, `phased=2`). Unarmed (`gun(0)`, no hammer), the bot's `_brawl` walks toward the stairs (right) while the looter walks toward the door (left, flat 2503); a zombie standing on the player is "ahead" from one side of it and "behind" from the other, so the two controllers took turns every frame. The game was doing its part — the net had phased the player through both bodies — and a person holding one key would have walked on. (The earlier round-49f note that the pin was depenetration jitter of +-0.58 px was a different sample; this one is control thrash.) The 2601 stall lines carry no per-frame trace (only `NO_PROGRESS` prints one), so they are consistent with the same thrash (`unjam` 0.07 / 0.33 with the keys held, a crawler and a defender's fight overlapping the player) **but that is not proven**.

**Bot changes** (`tools/bot_run.gd`, `tools/bot_loot.gd`): a THRASH BREAKER in `_walk` (8 reversals inside 1 s: hold the way last asked for 1.5 s, event `THRASH`), and a `[pin]` line once a second after 15 s of walking to one door (`diag(p)`; silent before, so a run that never gets stuck takes the path it always took).

**Replay 2 (with those changes): 0 `DOOR_TIMEOUT`, 0 `NO_PROGRESS`, 0 `THRASH` events, 0 engine findings in all 6 logs.** `need_101` / `safe_101` / `need_102` all passed the flats that pinned before. **What that does and does not show:** the bots are real-time and chaotic (a traced run, with `--trace` printing, took a different path and never reached 2601 at all), so a clean replay is absence of evidence, not a proof; and since no THRASH fired the breaker was not what cleared them. The game itself was not changed for these pins.

**Other anomalies in replay 2** (each seen, none a pin, none investigated today): `TAKE_NO_EFFECT` x2 (a 016 taken from a filing cabinet / a crate with nothing changing in the bag, one free slot), `DROP_NOT_TAKEN` x3 (three presses of [interact] on a 033 / 007 floor drop with a free slot and it stayed — a survivor offering [Talk] holds the press (`claim_interact_for_talk`), which would explain it, but that was not checked).
