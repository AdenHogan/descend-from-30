# Round 44 coverage runs (`god`) — tables

`python3 tools/bot_summary.py <dir>` over the six complete god playthroughs: `god_424242` (run 1 from floor 30), `god2_424242` and `god2_103` (runs 2 and 3, starting the 2nd character on floor 24),
`god3_424242`, `god3_101`, `god3_102` (run 3 from floor 24). The character cannot be hurt, is handed 3 fuses and 300 notes (`--fuses=3 --notes=300`), loots every door (`--loot=all`), rides the lift, rests and
goes over balconies. These runs say nothing about balance (stage-hits are 0 by construction); they are a walk through the whole building for errors. Not every run used the same bot: `god_424242`,
`god2_424242` and `god3_424242` ran before the fuse-gift fix (their coverage lines show no fuse box), `god3_101` before the lobby-door answer. The reading is in `docs/BOT_RUNS.md` "The coverage runs".

## god — 1 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 1 | 0 / 0 / 0.0 / 0 | 1 | 0 | 0 | 9331 | 324 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |


Barricaded stairwells met: 4 across 1 character-runs (4.0 per run); 0 runs ended within 3 floors below their last one.

Kit wear (over 1 character-runs): first hammer broke by floor 29 (median, 1 runs); both hammers broke by floor 29 (1 runs); gun empty by floor — (0 runs).

Stage-hits absorbed per character-run: median 0 (min 0, max 0); first aids used: median 0. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×1, f20 ×1, f15 ×1, f10 ×1, f5 ×1; upgrade picks taken: 5.

Upgrades taken: Night Eyes ×1; Second Wind ×1; Strong Arm ×1; Deep Pockets ×1; Fleet ×1

Boons taken: B_second_wind ×1; B_lungs ×1; B_steady ×1; B_senses ×1; B_rage ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): 

### god — scavenging

Over 1 character-runs the bot went into **120 apartments** and **10 maintenance rooms** (120.0 flats and 10.0 staff rooms per character).

Per flat: 66 s inside (median; 0–94), 6.6 nodes opened, 4.1 of them held something, 1.7 dead met at most at once; the bot took at least one hit in **0 of 120** (0%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 120 | 66 | 6.6 | 4.12 | 1.7 | 1.8 | 0.00 | 0% |

By how the door stood: open — 42 flats, 0.00 hits, 1.8 kills, 1.4 dead met; shut (forceable) — 23 flats, 0.00 hits, 1.4 kills, 1.3 dead met; shut (locked) — 22 flats, 0.00 hits, 1.5 kills, 1.0 dead met; breached — 15 flats, 0.00 hits, 3.2 kills, 4.9 dead met; barricaded (forceable) — 8 flats, 0.00 hits, 1.6 kills, 1.1 dead met; barricaded (locked) — 6 flats, 0.00 hits, 1.0 kills, 0.5 dead met; balcony — 3 flats, 0.00 hits, 0.3 kills, 0.3 dead met; ? — 1 flats, 0.00 hits, 3.0 kills, 2.0 dead met

How the flats ended: all searched ×114, warned off by a resident ×3, left by the balcony ×3

**What the nodes held** (510 items shown across 813 nodes opened — 63% of nodes held something):

Scrap Bag ×57 (taken 57); Knife ×40 (taken 1); Hammer ×24 (taken 0); Painkillers ×21 (taken 0); Battery ×20 (taken 0); Bank Notes ×19 (taken 19); Broken Bottle ×18 (taken 0); Canned Food ×17 (taken 1); Cricket Bat ×17 (taken 0); Crowbar ×16 (taken 0); Sword ×15 (taken 2); Flashlight ×15 (taken 0); Fire Extinguisher ×15 (taken 0); Bandages ×15 (taken 0)

Why things were left: bag full ×364, not worth a slot ×55

Finds per flat entered: weapons 1.11 · bullets 0.11 · first aid / bandages / painkillers 0.39 · keys 0.10 · scrap bags 0.47 · cash 0.16 · empty wallets 0.07 · crowbars 0.13 · fuses 0.06

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 28 | 5.21 | 1.68 | 0.18 | 0.43 |
| mid 11-20 | 45 | 3.96 | 0.84 | 0.13 | 0.40 |
| low 1-10 | 47 | 3.96 | 1.02 | 0.04 | 0.36 |

Doors the bot did NOT go through (34): barricaded, weapon too worn ×16, locked, no key, nothing to force it ×11, needs a weapon with 3+ uses ×7

**Economy per character** (end of the character's life): scrap median 0 (max 0), notes median 0 (max 0); workbench upgrades 8, tunings 8, salvaged 14; shop: 5 visits, 0 things bought, 0 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Needs a spare Lv1 bat, c” ×8, “Needs 50 scrap (you have” ×1, “Needs a spare Lv1 Gun to” ×1

### god — coverage

Exercised: an apartment door entered ×116, a shut door forced open ×31, a locked door forced ×29, a barricaded door torn open ×15, a breach room entered ×15, a scavenge node searched ×828, an item taken from a node ×91, an item left on a node ×419, an item put down for a better one ×40, a world drop picked up ×21, a set-back node reached ×481, a maintenance room entered ×9, the workbench opened ×10, a weapon upgraded ×8, a weapon tuned ×8, a broken item salvaged ×14, the merchant's shop used ×5, a crowbar handed over ×4

**Never exercised in this configuration:** a key used on its door, scrap taken from a burnt flat, the fuse box used, a fuse fitted, the elevator powered, the elevator ridden, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### god — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 1 playthroughs.

Engine errors caught by the in-game hook (distinct): 1

- **ENGINE_ERROR/headless** ×3 in 1 playthroughs — `./servers/rendering/dummy/storage/texture_storage.h:106` Parameter "t" is null. (first on floor 24, room.tscn)

## god2 — 2 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 2 | 2 | 0 / 0 / 0.0 / 0 | 2 | 0 | 0 | 7570 | 272 |
| 3 | 2 | 0 / 0 / 0.0 / 0 | 2 | 0 | 0 | 7610 | 310 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| 3 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |


Barricaded stairwells met: 5 across 4 character-runs (1.2 per run); 0 runs ended within 3 floors below their last one.

Kit wear (over 4 character-runs): first hammer broke by floor 27 (median, 4 runs); both hammers broke by floor 27 (4 runs); gun empty by floor 27 (1 runs).

Stage-hits absorbed per character-run: median 0 (min 0, max 0); first aids used: median 0. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×2, f20 ×3, f15 ×4, f10 ×4, f5 ×4; upgrade picks taken: 8.

Upgrades taken: Second Wind ×1; Fleet ×1; Field Medic ×1; Steady Aim ×1; Extended Mag ×1; Soft Soles ×1; Marksman ×1; Bruiser ×1

Boons taken: B_lungs ×3; B_adrenaline ×2; B_breath ×1; B_second_wind ×1; B_light ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f24 0.0/entry (4 entries, 0 deaths); f23 0.0/entry (3 entries, 0 deaths); f22 0.0/entry (3 entries, 0 deaths); f21 0.0/entry (3 entries, 0 deaths); f20 0.0/entry (3 entries, 0 deaths); f19 0.0/entry (4 entries, 0 deaths); f18 0.0/entry (4 entries, 0 deaths); f17 0.0/entry (4 entries, 0 deaths)

### god2 — scavenging

Over 4 character-runs the bot went into **484 apartments** and **37 maintenance rooms** (121.0 flats and 9.2 staff rooms per character).

Per flat: 58 s inside (median; 0–90), 5.2 nodes opened, 3.3 of them held something, 1.9 dead met at most at once; the bot took at least one hit in **0 of 484** (0%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 2 | 195 | 65 | 6.7 | 3.86 | 2.1 | 1.9 | 0.00 | 0% |
| 3 | 289 | 36 | 4.2 | 2.90 | 1.7 | 1.5 | 0.00 | 0% |

By how the door stood: open — 243 flats, 0.00 hits, 1.3 kills, 1.2 dead met; breached — 89 flats, 0.00 hits, 3.1 kills, 4.9 dead met; shut (forceable) — 52 flats, 0.00 hits, 1.6 kills, 1.5 dead met; shut (locked) — 33 flats, 0.00 hits, 1.5 kills, 1.1 dead met; barricaded (forceable) — 28 flats, 0.00 hits, 1.3 kills, 1.3 dead met; barricaded (locked) — 17 flats, 0.00 hits, 1.2 kills, 0.8 dead met; ? — 16 flats, 0.00 hits, 1.4 kills, 1.8 dead met; balcony — 6 flats, 0.00 hits, 1.2 kills, 1.5 dead met

How the flats ended: all searched ×474, left by the balcony ×6, warned off by a resident ×4

**What the nodes held** (1648 items shown across 2594 nodes opened — 64% of nodes held something):

Scrap Bag ×156 (taken 156); Knife ×97 (taken 0); Apartment Key ×85 (taken 2); Flashlight ×76 (taken 0); Hammer ×75 (taken 2); Bank Notes ×66 (taken 66); Canned Food ×64 (taken 0); Bullets ×61 (taken 2); Toolbox ×57 (taken 0); Battery ×57 (taken 0); Painkillers ×56 (taken 0); Torn Clothes ×54 (taken 0); Broken Bottle ×53 (taken 0); Bandages ×51 (taken 1)

Why things were left: bag full ×1226, not worth a slot ×162

Finds per flat entered: weapons 0.76 · bullets 0.13 · first aid / bandages / painkillers 0.29 · keys 0.18 · scrap bags 0.32 · cash 0.14 · empty wallets 0.04 · crowbars 0.10 · fuses 0.06

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 103 | 3.42 | 0.82 | 0.10 | 0.37 |
| mid 11-20 | 192 | 3.45 | 0.80 | 0.10 | 0.27 |
| low 1-10 | 189 | 3.35 | 0.69 | 0.16 | 0.25 |

Doors the bot did NOT go through (94): barricaded, weapon too worn ×32, needs a weapon with 3+ uses ×32, locked, no key, nothing to force it ×21, breach room, unarmed ×9

**Economy per character** (end of the character's life): scrap median 1306 (max 3597), notes median 691 (max 1433); workbench upgrades 29, tunings 30, salvaged 55; shop: 8 visits, 2 things bought, 130 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Needs a spare Lv1 bat, c” ×33, “Needs 50 scrap (you have” ×3, “Needs a spare Lv2 Gun to” ×1

### god2 — coverage

Exercised: an apartment door entered ×462, a shut door forced open ×80, a locked door forced ×49, a key used on its door ×1, a barricaded door torn open ×48, a breach room entered ×89, a scavenge node searched ×2622, an item taken from a node ×260, an item left on a node ×1388, an item put down for a better one ×173, a world drop picked up ×102, a set-back node reached ×1459, scrap taken from a burnt flat ×290, a maintenance room entered ×33, the fuse box used ×1, a fuse fitted ×3, the elevator powered ×1, the elevator ridden ×1, the workbench opened ×35, a weapon upgraded ×29, a weapon tuned ×30, a broken item salvaged ×55, the merchant's shop used ×8, something bought ×2, the gun reloaded from the bag ×2, a crowbar handed over ×5

**Never exercised in this configuration:** something sold, something mended with a toolbox, a Molotov thrown

### god2 — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 2 playthroughs.

Engine errors caught by the in-game hook (distinct): 1

- **ENGINE_ERROR/headless** ×6 in 2 playthroughs — `./servers/rendering/dummy/storage/texture_storage.h:106` Parameter "t" is null. (first on floor 13, room.tscn)

## god3 — 3 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 3 | 3 | 0 / 0 / 0.0 / 0 | 3 | 0 | 0 | 7850 | 262 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 3 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 | 3 / 3 |


Barricaded stairwells met: 7 across 3 character-runs (2.3 per run); 0 runs ended within 3 floors below their last one.

Kit wear (over 3 character-runs): first hammer broke by floor 24 (median, 3 runs); both hammers broke by floor 23 (3 runs); gun empty by floor 24 (1 runs).

Stage-hits absorbed per character-run: median 0 (min 0, max 0); first aids used: median 0. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f20 ×2, f15 ×3, f10 ×3, f5 ×3; upgrade picks taken: 6.

Upgrades taken: Ghost ×2; Marksman ×1; Sprinter's Legs ×1; Field Medic ×1; Fleet ×1

Boons taken: B_adrenaline ×2; B_lungs ×2; B_steady ×1; B_second_wind ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f24 0.0/entry (3 entries, 0 deaths); f23 0.0/entry (3 entries, 0 deaths); f22 0.0/entry (3 entries, 0 deaths); f17 0.0/entry (3 entries, 0 deaths); f16 0.0/entry (3 entries, 0 deaths); f15 0.0/entry (3 entries, 0 deaths); f14 0.0/entry (3 entries, 0 deaths); f13 0.0/entry (3 entries, 0 deaths)

### god3 — scavenging

Over 3 character-runs the bot went into **325 apartments** and **25 maintenance rooms** (108.3 flats and 8.3 staff rooms per character).

Per flat: 64 s inside (median; 0–104), 6.0 nodes opened, 3.1 of them held something, 2.2 dead met at most at once; the bot took at least one hit in **0 of 325** (0%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 3 | 325 | 64 | 6.0 | 3.09 | 2.2 | 1.8 | 0.00 | 0% |

By how the door stood: open — 98 flats, 0.00 hits, 1.3 kills, 1.3 dead met; breached — 86 flats, 0.00 hits, 2.7 kills, 4.4 dead met; shut (forceable) — 38 flats, 0.00 hits, 1.7 kills, 1.4 dead met; shut (locked) — 35 flats, 0.00 hits, 1.6 kills, 1.5 dead met; barricaded (forceable) — 25 flats, 0.00 hits, 1.3 kills, 1.2 dead met; barricaded (locked) — 24 flats, 0.00 hits, 1.6 kills, 1.3 dead met; ? — 10 flats, 0.00 hits, 0.8 kills, 1.7 dead met; balcony — 9 flats, 0.00 hits, 1.0 kills, 2.2 dead met

How the flats ended: all searched ×316, left by the balcony ×9

**What the nodes held** (1046 items shown across 1985 nodes opened — 53% of nodes held something):

Scrap Bag ×145 (taken 145); Knife ×67 (taken 2); Bank Notes ×66 (taken 66); Hammer ×45 (taken 0); Flashlight ×44 (taken 0); Toolbox ×42 (taken 0); Canned Food ×40 (taken 0); Bandages ×39 (taken 0); Battery ×36 (taken 0); Apartment Key ×36 (taken 1); Cricket Bat ×33 (taken 0); Painkillers ×33 (taken 0); Bullets ×32 (taken 0); Sword ×27 (taken 0)

Why things were left: bag full ×747, not worth a slot ×67

Finds per flat entered: weapons 0.75 · bullets 0.10 · first aid / bandages / painkillers 0.29 · keys 0.11 · scrap bags 0.45 · cash 0.20 · empty wallets 0.04 · crowbars 0.08 · fuses 0.06

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 51 | 2.76 | 0.61 | 0.02 | 0.29 |
| mid 11-20 | 133 | 3.42 | 0.80 | 0.08 | 0.29 |
| low 1-10 | 141 | 3.19 | 0.74 | 0.14 | 0.29 |

Doors the bot did NOT go through (74): barricaded, weapon too worn ×42, locked, no key, nothing to force it ×16, needs a weapon with 3+ uses ×15, breach room, unarmed ×1

**Economy per character** (end of the character's life): scrap median 2813 (max 3344), notes median 1661 (max 1746); workbench upgrades 19, tunings 19, salvaged 59; shop: 6 visits, 0 things bought, 0 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Needs a spare Lv1 bat, c” ×21, “Needs 50 scrap (you have” ×2, “Needs a spare Lv1 blade ” ×1

### god3 — coverage

Exercised: an apartment door entered ×306, a shut door forced open ×63, a locked door forced ×59, a barricaded door torn open ×53, a breach room entered ×86, a scavenge node searched ×1993, an item taken from a node ×232, an item left on a node ×814, an item put down for a better one ×121, a world drop picked up ×73, a set-back node reached ×1128, scrap taken from a burnt flat ×288, a maintenance room entered ×22, the fuse box used ×1, a fuse fitted ×3, the elevator powered ×1, the elevator ridden ×1, the workbench opened ×23, a weapon upgraded ×19, a weapon tuned ×19, a broken item salvaged ×59, the merchant's shop used ×6, a crowbar handed over ×7

**Never exercised in this configuration:** a key used on its door, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### god3 — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 3 playthroughs.

Engine errors caught by the in-game hook (distinct): 1

- **ENGINE_ERROR/headless** ×9 in 3 playthroughs — `./servers/rendering/dummy/storage/texture_storage.h:106` Parameter "t" is null. (first on floor 23, room.tscn)

