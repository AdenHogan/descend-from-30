## need — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20 / 23 / 23.0 / 25 | 0 | 6 | 0 | 909 | 38 |
| 2 | 6 | 19 / 25 / 23.2 / 26 | 0 | 6 | 0 | 566 | 38 |
| 3 | 6 | 24 / 25 / 25.7 / 30 | 0 | 6 | 0 | 370 | 16 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 6 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 2 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 5 / 6 | 3 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 1×f30, 3×f26, 5×f25, 4×f24, 2×f22, 1×f20, 2×f19

What stood near at death: standard ×7; crawler,standard ×5; spitter,standard ×2; big ×1; big,standard ×1; crawler,spitter,standard ×1; spitter ×1

Time alive before death: median 495 s, range 51–1471 s

Barricaded stairwells met: 10 across 18 character-runs (0.6 per run); 6 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor 28 (median, 9 runs); both hammers broke by floor 28 (9 runs); gun empty by floor 26 (16 runs).

Stage-hits absorbed per character-run: median 20 (min 11, max 24); first aids used: median 5. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×14, f20 ×3; upgrade picks taken: 9.

Upgrades taken: Second Wind ×3; Night Eyes ×1; Brawler ×1; Catch Your Breath ×1; Deep Breaths ×1; Fleet ×1; Big Lungs ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f20 10.7/entry (3 entries, 1 deaths); f22 7.8/entry (5 entries, 2 deaths); f24 5.8/entry (9 entries, 4 deaths); f26 4.1/entry (17 entries, 3 deaths); f25 3.8/entry (14 entries, 5 deaths); f27 2.0/entry (17 entries, 0 deaths); f21 2.0/entry (3 entries, 0 deaths); f23 1.0/entry (5 entries, 0 deaths)

### need — scavenging

Over 18 character-runs the bot went into **292 apartments** and **25 maintenance rooms** (16.2 flats and 1.4 staff rooms per character).

Per flat: 21 s inside (median; 0–69), 3.9 nodes opened, 2.2 of them held something, 1.2 dead met at most at once; the bot took at least one hit in **29 of 292** (10%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 95 | 45 | 6.5 | 3.02 | 1.4 | 1.6 | 0.28 | 9% |
| 2 | 118 | 19 | 3.6 | 2.25 | 1.3 | 1.5 | 0.24 | 11% |
| 3 | 79 | 13 | 1.2 | 1.20 | 0.9 | 0.8 | 0.22 | 7% |

By how the door stood: open — 228 flats, 0.15 hits, 1.3 kills, 1.2 dead met; shut (locked) — 30 flats, 0.07 hits, 1.4 kills, 1.2 dead met; shut (forceable) — 28 flats, 0.29 hits, 1.5 kills, 1.1 dead met; breached — 3 flats, 9.00 hits, 4.3 kills, 4.3 dead met; ? — 2 flats, 0.00 hits, 0.5 kills, 0.5 dead met; barricaded (forceable) — 1 flats, 0.00 hits, 0.0 kills, 0.0 dead met

How the flats ended: all searched ×266, ? ×21, warned off by a resident ×3, left hurt ×2

**What the nodes held** (680 items shown across 1190 nodes opened — 57% of nodes held something):

Scrap Bag ×68 (taken 68); Torch ×50 (taken 1); Battery ×49 (taken 2); Tinned Food ×46 (taken 2); Broken Bottle ×38 (taken 0); Bullets ×37 (taken 30); Bandages ×35 (taken 6); Torn Clothes ×32 (taken 4); Clothes ×29 (taken 2); Bank Notes ×23 (taken 21); Hammer ×23 (taken 7); Ice Pack ×20 (taken 2); Knife ×20 (taken 6); Screwdriver ×19 (taken 0)

Why things were left: bag full ×406, not worth a slot ×72

Finds per flat entered: weapons 0.26 · bullets 0.13 · first aid / bandages / painkillers 0.22 · keys 0.05 · scrap bags 0.23 · cash 0.08 · empty wallets 0.01 · crowbars 0.02 · fuses 0.05

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 290 | 2.32 | 0.26 | 0.13 | 0.21 |
| mid 11-20 | 2 | 3.00 | 0.50 | 0.00 | 1.00 |

Doors the bot did NOT go through (293): needs a weapon with 3+ uses ×96, barricaded ×96, locked, no key, nothing to force it ×65, too hurt to go in, nothing to heal with ×15, barricaded, weapon too worn ×11, breach room, unarmed ×10

**Economy per character** (end of the character's life): scrap median 20 (max 757), notes median 26 (max 188); workbench upgrades 25, tunings 0, salvaged 25; shop: 9 visits, 3 things bought, 80 notes spent, 1 sold.

What stopped a weapon going up a level at the bench: “Need 50 scrap — you have” ×12, “Needs a spare Lv1 Gun.” ×7, “Need 30 scrap — you have” ×6, “Needs a spare Lv1 bat, c” ×2, “Needs a spare Lv1 blade ” ×1

### need — coverage

Exercised: an apartment door entered ×291, a shut door forced open ×29, a locked door forced ×28, a key used on its door ×2, a barricaded door torn open ×1, a breach room entered ×3, a scavenge node searched ×1204, an item taken from a node ×202, an item left on a node ×478, an item put down for a better one ×79, a world drop picked up ×115, a set-back node reached ×546, scrap taken from a burnt flat ×108, a maintenance room entered ×24, the fuse box used ×8, a fuse fitted ×10, the workbench opened ×25, a weapon upgraded ×25, a broken item salvaged ×25, the merchant's shop used ×9, something bought ×3, something sold ×1, the gun reloaded from the bag ×12, a crowbar handed over ×10

**Never exercised in this configuration:** the elevator powered, the elevator ridden, a weapon tuned, something mended with a toolbox, a Molotov thrown

### need — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| DROP_NOT_TAKEN | 2 | 1 | run 3 floor 27: floor 27: pressed [interact] on a 033 drop 3 times and it stayed on the floor (bag 002:1:4/004:1:7/007:3:1/036:1:5/007:1:1/w7/s727/utrue, free slots 0) |
| TAKE_NO_EFFECT | 1 | 1 | run 1 floor 26: floor 26 2604: took 016 from anchor_study_bookcase_lower but nothing in the bag / wallet / scrap changed (free slots 1, bag 004:1/007:2/022:1/036:1) |

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

## need_r0 — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 15 / 20 / 20.0 / 25 | 0 | 6 | 0 | 1145 | 54 |
| 2 | 6 | 15 / 24 / 22.3 / 26 | 0 | 5 | 1 | 759 | 34 |
| 3 | 5 | 19 / 25 / 23.8 / 26 | 0 | 4 | 1 | 542 | 30 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 6 / 6 | 3 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 2 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 5 / 5 | 4 / 5 | 1 / 5 | 0 / 5 | 0 / 5 | 0 / 5 | 0 / 5 | 0 / 5 |

Deaths by floor: 2×f26, 3×f25, 2×f24, 1×f23, 1×f22, 1×f20, 1×f19, 1×f18, 1×f16, 2×f15

What stood near at death: standard ×5; crawler,standard ×4; spitter,standard ×2; crawler ×1; big,spitter,standard ×1; boss ×1; spitter ×1

Time alive before death: median 659 s, range 226–1660 s

Barricaded stairwells met: 12 across 17 character-runs (0.7 per run); 3 runs ended within 3 floors below their last one.

Kit wear (over 17 character-runs): first hammer broke by floor 28 (median, 12 runs); both hammers broke by floor 28 (12 runs); gun empty by floor 25 (15 runs).

Stage-hits absorbed per character-run: median 15 (min 6, max 30); first aids used: median 4. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×15, f20 ×6, f15 ×2; upgrade picks taken: 10.

Upgrades taken: Second Wind ×3; Soft Soles ×2; Brawler ×1; Catch Your Breath ×1; Deep Breaths ×1; Strong Arm ×1; Rage ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f22 5.0/entry (7 entries, 1 deaths); f25 4.0/entry (15 entries, 3 deaths); f19 4.0/entry (5 entries, 1 deaths); f26 3.1/entry (17 entries, 2 deaths); f21 2.5/entry (6 entries, 0 deaths); f16 2.3/entry (3 entries, 1 deaths); f24 2.3/entry (10 entries, 2 deaths); f20 1.8/entry (6 entries, 1 deaths)

### need_r0 — scavenging

Over 17 character-runs the bot went into **335 apartments** and **29 maintenance rooms** (19.7 flats and 1.7 staff rooms per character).

Per flat: 23 s inside (median; 0–69), 4.0 nodes opened, 2.2 of them held something, 1.3 dead met at most at once; the bot took at least one hit in **27 of 335** (8%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 114 | 45 | 6.5 | 3.17 | 1.5 | 1.6 | 0.27 | 8% |
| 2 | 120 | 18 | 3.5 | 2.12 | 1.3 | 1.4 | 0.14 | 7% |
| 3 | 101 | 15 | 1.8 | 1.35 | 1.0 | 1.1 | 0.18 | 7% |

By how the door stood: open — 257 flats, 0.10 hits, 1.3 kills, 1.2 dead met; shut (forceable) — 35 flats, 0.23 hits, 1.5 kills, 1.1 dead met; shut (locked) — 33 flats, 0.12 hits, 1.7 kills, 1.4 dead met; ? — 6 flats, 0.67 hits, 0.5 kills, 1.3 dead met; breached — 3 flats, 8.00 hits, 5.3 kills, 4.7 dead met; barricaded (forceable) — 1 flats, 0.00 hits, 0.0 kills, 0.0 dead met

How the flats ended: all searched ×302, ? ×29, warned off by a resident ×3, left hurt ×1

**What the nodes held** (794 items shown across 1402 nodes opened — 57% of nodes held something):

Scrap Bag ×78 (taken 78); Torch ×62 (taken 3); Battery ×46 (taken 1); Broken Bottle ×46 (taken 0); Bullets ×44 (taken 39); Tinned Food ×41 (taken 1); Bandages ×38 (taken 8); Torn Clothes ×36 (taken 5); Bank Notes ×32 (taken 30); Clothes ×29 (taken 3); Toolbox ×28 (taken 2); Ice Pack ×25 (taken 4); Hammer ×25 (taken 9); Knife ×25 (taken 5)

Why things were left: bag full ×458, not worth a slot ×90

Finds per flat entered: weapons 0.29 · bullets 0.13 · first aid / bandages / painkillers 0.19 · keys 0.07 · scrap bags 0.23 · cash 0.10 · empty wallets 0.01 · crowbars 0.03 · fuses 0.04

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 314 | 2.36 | 0.28 | 0.13 | 0.20 |
| mid 11-20 | 21 | 2.57 | 0.52 | 0.14 | 0.14 |

Doors the bot did NOT go through (374): needs a weapon with 3+ uses ×117, barricaded ×108, locked, no key, nothing to force it ×73, too hurt to go in, nothing to heal with ×44, breach room, unarmed ×19, barricaded, weapon too worn ×13

**Economy per character** (end of the character's life): scrap median 14 (max 757), notes median 43 (max 125); workbench upgrades 32, tunings 0, salvaged 26; shop: 10 visits, 4 things bought, 170 notes spent, 1 sold.

What stopped a weapon going up a level at the bench: “Need 50 scrap — you have” ×15, “Needs a spare Lv1 Gun.” ×13, “Need 30 scrap — you have” ×3, “Needs a spare Lv1 bat, c” ×2, “Needs a spare Lv2 bat, c” ×1

### need_r0 — coverage

Exercised: an apartment door entered ×329, a shut door forced open ×36, a locked door forced ×32, a key used on its door ×1, a barricaded door torn open ×1, a breach room entered ×3, a scavenge node searched ×1417, an item taken from a node ×246, an item left on a node ×548, an item put down for a better one ×99, a world drop picked up ×111, a set-back node reached ×644, scrap taken from a burnt flat ×116, a maintenance room entered ×29, the fuse box used ×5, a fuse fitted ×6, the workbench opened ×29, a weapon upgraded ×32, a broken item salvaged ×26, the merchant's shop used ×10, something bought ×4, something sold ×1, the gun reloaded from the bag ×16, something mended with a toolbox ×4, a Molotov thrown ×1, a crowbar handed over ×12

**Never exercised in this configuration:** the elevator powered, the elevator ridden, a weapon tuned

### need_r0 — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| NO_PROGRESS | 2 | 2 | run 3 floor 25: floor 25: nothing changed for 30 s — phase=play scene=corridor shop=open :: atk=false(cd=0.00) dying=false escaping=false pack=open lash=false slide=["StaticBody2D@544[-,layer1]"] unjam=0.00 phased=0 x=960 y=386 ve |
| SAVE_LOAD_DRIFT | 1 | 1 | run 3 floor 27: floor 27: after save + load these fields differ: stamina (first: 111.9 -> 111.8) |

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

**Characters the bot could not get further** (stuck / out of time):

- need_r0_101 run 3 (Amina) on floor ?: ran out of the 360-minute allowance
- need_r0_102 run 2 (Alex) on floor ?: ran out of the 360-minute allowance

## need_r1 — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20 / 22 / 22.5 / 25 | 0 | 6 | 0 | 1038 | 46 |
| 2 | 6 | 20 / 24 / 23.3 / 26 | 0 | 6 | 0 | 623 | 38 |
| 3 | 6 | 21 / 26 / 25.2 / 27 | 0 | 6 | 0 | 368 | 26 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 6 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 2 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 1×f27, 4×f26, 4×f25, 2×f24, 2×f22, 3×f21, 2×f20

What stood near at death: standard ×5; crawler,standard ×3; spitter ×3; spitter,standard ×2; big,standard ×1; crawler,spitter,standard ×1; longarm,standard ×1; crawler,longarm,standard ×1; boss ×1

Time alive before death: median 605 s, range 259–1516 s

Barricaded stairwells met: 13 across 18 character-runs (0.7 per run); 7 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor 28 (median, 12 runs); both hammers broke by floor 28 (11 runs); gun empty by floor 26 (14 runs).

Stage-hits absorbed per character-run: median 15 (min 11, max 28); first aids used: median 4. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×13, f20 ×2; upgrade picks taken: 9.

Upgrades taken: Second Wind ×3; Night Eyes ×1; Catch Your Breath ×1; Deep Breaths ×1; Adrenaline ×1; Fleet ×1; Big Lungs ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f21 7.0/entry (5 entries, 3 deaths); f22 6.6/entry (7 entries, 2 deaths); f25 5.2/entry (13 entries, 4 deaths); f26 3.4/entry (17 entries, 4 deaths); f27 2.2/entry (18 entries, 1 deaths); f23 2.0/entry (7 entries, 0 deaths); f29 0.4/entry (18 entries, 0 deaths); f28 0.4/entry (18 entries, 0 deaths)

### need_r1 — scavenging

Over 18 character-runs the bot went into **336 apartments** and **26 maintenance rooms** (18.7 flats and 1.4 staff rooms per character).

Per flat: 22 s inside (median; 0–69), 3.9 nodes opened, 2.2 of them held something, 1.2 dead met at most at once; the bot took at least one hit in **30 of 336** (9%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 104 | 45 | 6.6 | 3.08 | 1.4 | 1.5 | 0.15 | 7% |
| 2 | 122 | 20 | 3.5 | 2.25 | 1.3 | 1.5 | 0.35 | 11% |
| 3 | 110 | 13 | 1.7 | 1.31 | 0.9 | 1.0 | 0.12 | 7% |

By how the door stood: open — 250 flats, 0.13 hits, 1.3 kills, 1.2 dead met; shut (forceable) — 43 flats, 0.56 hits, 1.3 kills, 1.1 dead met; shut (locked) — 36 flats, 0.08 hits, 1.5 kills, 1.3 dead met; ? — 4 flats, 0.00 hits, 0.8 kills, 0.8 dead met; breached — 2 flats, 6.00 hits, 1.5 kills, 4.0 dead met; barricaded (forceable) — 1 flats, 0.00 hits, 0.0 kills, 0.0 dead met

How the flats ended: all searched ×305, ? ×28, warned off by a resident ×3

**What the nodes held** (772 items shown across 1347 nodes opened — 57% of nodes held something):

Scrap Bag ×77 (taken 77); Battery ×58 (taken 2); Torch ×51 (taken 3); Tinned Food ×47 (taken 4); Broken Bottle ×45 (taken 0); Bullets ×44 (taken 28); Clothes ×36 (taken 4); Bandages ×36 (taken 10); Torn Clothes ×35 (taken 4); Molotov Cocktail ×26 (taken 4); Bank Notes ×25 (taken 24); Hammer ×25 (taken 9); Ice Pack ×22 (taken 2); Flat Key ×22 (taken 9)

Why things were left: bag full ×445, not worth a slot ×89

Finds per flat entered: weapons 0.25 · bullets 0.13 · first aid / bandages / painkillers 0.19 · keys 0.07 · scrap bags 0.23 · cash 0.07 · empty wallets 0.02 · crowbars 0.03 · fuses 0.06

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 335 | 2.28 | 0.25 | 0.13 | 0.19 |
| mid 11-20 | 1 | 8.00 | 0.00 | 0.00 | 0.00 |

Doors the bot did NOT go through (278): barricaded ×96, needs a weapon with 3+ uses ×82, locked, no key, nothing to force it ×52, too hurt to go in, nothing to heal with ×24, barricaded, weapon too worn ×13, breach room, unarmed ×10, breach room, hurt ×1

**Economy per character** (end of the character's life): scrap median 27 (max 791), notes median 42 (max 113); workbench upgrades 28, tunings 0, salvaged 23; shop: 9 visits, 3 things bought, 160 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Need 30 scrap — you have” ×11, “Need 50 scrap — you have” ×11, “Needs a spare Lv1 Gun.” ×7, “Needs a spare Lv2 bat, c” ×2, “Needs a spare Lv1 bat, c” ×1

### need_r1 — coverage

Exercised: an apartment door entered ×332, a shut door forced open ×44, a locked door forced ×34, a key used on its door ×3, a barricaded door torn open ×1, a breach room entered ×2, a scavenge node searched ×1353, an item taken from a node ×238, an item left on a node ×534, an item put down for a better one ×112, a world drop picked up ×129, a set-back node reached ×635, scrap taken from a burnt flat ×127, a maintenance room entered ×25, the fuse box used ×6, a fuse fitted ×8, the workbench opened ×26, a weapon upgraded ×28, a broken item salvaged ×23, the merchant's shop used ×9, something bought ×3, the gun reloaded from the bag ×12, something mended with a toolbox ×1, a Molotov thrown ×3, a crowbar handed over ×13

**Never exercised in this configuration:** the elevator powered, the elevator ridden, a weapon tuned, something sold

### need_r1 — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| DROP_NOT_TAKEN | 3 | 2 | run 2 floor 26: floor 26: pressed [interact] on a 033 drop 3 times and it stayed on the floor (bag 002:1:0/009:1:1/013:1:8/022:1:1/010:2:2/w45/s9/utrue, free slots 0) |
| ANCHOR_UNREACHABLE | 1 | 1 | run 2 floor 24: floor 24 2405: could not search anchor_kitchen_sink in 40 s (stage , player x=573 y=320, anchor x=534 y=295, in_range=false, scav=false, switching=false, attacking=false, back_spot=true, player_back=false, plane_ok |
| TAKE_NO_EFFECT | 1 | 1 | run 1 floor 24: floor 24 2401: took 016 from anchor_bedroom_crate but nothing in the bag / wallet / scrap changed (free slots 1, bag 004:1/007:3/007:2/022:1) |
| SAVE_LOAD_DRIFT | 1 | 1 | run 3 floor 27: floor 27: after save + load these fields differ: stamina (first: 112.1 -> 112.0) |

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

## none — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 23 / 24 / 24.7 / 26 | 0 | 6 | 0 | 81 | 10 |
| 2 | 6 | 20 / 24 / 23.8 / 26 | 0 | 6 | 0 | 78 | 10 |
| 3 | 6 | 20 / 26 / 24.2 / 26 | 0 | 6 | 0 | 100 | 10 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 4 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 3 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 6×f26, 4×f25, 3×f24, 2×f23, 1×f22, 2×f20

What stood near at death: crawler,standard ×6; standard ×5; spitter ×2; big,longarm,standard ×2; (none close) ×1; longarm,standard ×1; boss,standard ×1

Time alive before death: median 83 s, range 48–182 s

Barricaded stairwells met: 8 across 18 character-runs (0.4 per run); 5 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor — (median, 0 runs); both hammers broke by floor — (0 runs); gun empty by floor 26 (18 runs).

Stage-hits absorbed per character-run: median 11 (min 11, max 11); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×12, f20 ×2; upgrade picks taken: 2.

Upgrades taken: Second Wind ×1; Adrenaline ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f25 4.7/entry (12 entries, 4 deaths); f24 4.1/entry (8 entries, 3 deaths); f26 3.9/entry (18 entries, 6 deaths); f22 3.3/entry (3 entries, 1 deaths); f23 1.8/entry (5 entries, 2 deaths); f28 0.3/entry (18 entries, 0 deaths); f27 0.2/entry (18 entries, 0 deaths); f30 0.0/entry (18 entries, 0 deaths)

### none — coverage

Exercised: a crowbar handed over ×8

**Never exercised in this configuration:** an apartment door entered, a shut door forced open, a locked door forced, a key used on its door, a barricaded door torn open, a breach room entered, a scavenge node searched, an item taken from a node, an item left on a node, an item put down for a better one, a world drop picked up, a set-back node reached, scrap taken from a burnt flat, a maintenance room entered, the fuse box used, a fuse fitted, the elevator powered, the elevator ridden, the workbench opened, a weapon upgraded, a weapon tuned, a broken item salvaged, the merchant's shop used, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### none — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 6 playthroughs.

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

## none_r0 — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 20 / 24 / 23.5 / 26 | 0 | 6 | 0 | 116 | 14 |
| 2 | 6 | 22 / 22 / 23.3 / 26 | 0 | 6 | 0 | 132 | 10 |
| 3 | 6 | 21 / 26 / 25.0 / 27 | 0 | 6 | 0 | 71 | 8 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 3 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 1×f27, 4×f26, 5×f25, 1×f24, 1×f23, 3×f22, 2×f21, 1×f20

What stood near at death: standard ×6; crawler,standard ×4; spitter,standard ×2; crawler ×1; big ×1; big,longarm,standard ×1; spitter ×1; big,spitter ×1; longarm ×1

Time alive before death: median 85 s, range 48–188 s

Barricaded stairwells met: 13 across 18 character-runs (0.7 per run); 7 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor — (median, 0 runs); both hammers broke by floor — (0 runs); gun empty by floor 26 (18 runs).

Stage-hits absorbed per character-run: median 11 (min 11, max 11); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×13, f20 ×1; upgrade picks taken: 4.

Upgrades taken: Second Wind ×2; Night Eyes ×1; Soft Soles ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f21 5.0/entry (3 entries, 2 deaths); f25 4.8/entry (13 entries, 5 deaths); f22 4.0/entry (6 entries, 3 deaths); f26 3.3/entry (17 entries, 4 deaths); f23 1.9/entry (7 entries, 1 deaths); f24 1.2/entry (8 entries, 1 deaths); f27 0.6/entry (18 entries, 1 deaths); f28 0.2/entry (18 entries, 0 deaths)

### none_r0 — coverage

Exercised: a crowbar handed over ×13

**Never exercised in this configuration:** an apartment door entered, a shut door forced open, a locked door forced, a key used on its door, a barricaded door torn open, a breach room entered, a scavenge node searched, an item taken from a node, an item left on a node, an item put down for a better one, a world drop picked up, a set-back node reached, scrap taken from a burnt flat, a maintenance room entered, the fuse box used, a fuse fitted, the elevator powered, the elevator ridden, the workbench opened, a weapon upgraded, a weapon tuned, a broken item salvaged, the merchant's shop used, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### none_r0 — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 6 playthroughs.

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

## none_r1 — 6 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 6 | 22 / 25 / 24.3 / 26 | 0 | 6 | 0 | 77 | 12 |
| 2 | 6 | 20 / 23 / 23.0 / 26 | 0 | 6 | 0 | 132 | 11 |
| 3 | 6 | 21 / 26 / 24.7 / 26 | 0 | 6 | 0 | 75 | 8 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 6 / 6 | 4 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 2 | 6 / 6 | 5 / 6 | 1 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |
| 3 | 6 / 6 | 3 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 | 0 / 6 |

Deaths by floor: 6×f26, 4×f25, 1×f24, 2×f23, 2×f22, 2×f21, 1×f20

What stood near at death: standard ×7; spitter,standard ×3; crawler,standard ×2; crawler ×2; big,longarm,standard ×2; spitter ×1; big,crawler,spitter ×1

Time alive before death: median 82 s, range 54–184 s

Barricaded stairwells met: 10 across 18 character-runs (0.6 per run); 6 runs ended within 3 floors below their last one.

Kit wear (over 18 character-runs): first hammer broke by floor — (median, 0 runs); both hammers broke by floor — (0 runs); gun empty by floor 26 (18 runs).

Stage-hits absorbed per character-run: median 11 (min 10, max 11); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×12, f20 ×1; upgrade picks taken: 3.

Upgrades taken: Second Wind ×1; Night Eyes ×1; Crushing Blows ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f21 4.3/entry (3 entries, 2 deaths); f26 4.2/entry (18 entries, 6 deaths); f25 3.9/entry (12 entries, 4 deaths); f23 3.0/entry (7 entries, 2 deaths); f22 2.8/entry (5 entries, 2 deaths); f24 1.8/entry (8 entries, 1 deaths); f27 0.3/entry (18 entries, 0 deaths); f28 0.2/entry (18 entries, 0 deaths)

### none_r1 — coverage

Exercised: a crowbar handed over ×10

**Never exercised in this configuration:** an apartment door entered, a shut door forced open, a locked door forced, a key used on its door, a barricaded door torn open, a breach room entered, a scavenge node searched, an item taken from a node, an item left on a node, an item put down for a better one, a world drop picked up, a set-back node reached, scrap taken from a burnt flat, a maintenance room entered, the fuse box used, a fuse fitted, the elevator powered, the elevator ridden, the workbench opened, a weapon upgraded, a weapon tuned, a broken item salvaged, the merchant's shop used, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### none_r1 — anomalies and engine errors

No anomaly was raised by the watcher or the bot in 6 playthroughs.

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

