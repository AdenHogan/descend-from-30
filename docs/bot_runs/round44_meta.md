# Round 44b — progression-ceiling experiment (tables)

`python3 tools/bot_sweep.py <dir> --seeds 424242,101-111 --configs none_m3,none_m10,none_m10h,safe_m10h --jobs 4`, then the per-config comparison against `docs/bot_runs/round44_sweep.md`
(`none` and `safe`, same seeds). Configs are defined in `tools/bot_sweep.py`; flags `--perm` and `--hammer-level` in `tools/bot_run.gd`. Reading: `docs/BOT_RUNS.md` "Round 44b".
`bot_summary.py` groups by loot mode, so the four configs below were compared with a small script on the per-run JSON (deepest floor of each character, paired by seed + run); the raw tables follow.

## none — 36 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 36 | 12 / 17 / 17.2 / 24 | 0 | 36 | 0 | 173 | 25 |
| 2 | 36 | 7 / 18 / 18.2 / 26 | 0 | 36 | 0 | 145 | 24 |
| 3 | 36 | 10 / 20 / 20.0 / 26 | 0 | 36 | 0 | 108 | 18 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 36 / 36 | 36 / 36 | 31 / 36 | 10 / 36 | 0 / 36 | 0 / 36 | 0 / 36 | 0 / 36 |
| 2 | 36 / 36 | 35 / 36 | 23 / 36 | 9 / 36 | 1 / 36 | 0 / 36 | 0 / 36 | 0 / 36 |
| 3 | 36 / 36 | 35 / 36 | 20 / 36 | 4 / 36 | 2 / 36 | 0 / 36 | 0 / 36 | 0 / 36 |

Deaths by floor: 2×f26, 4×f25, 6×f24, 8×f23, 5×f22, 9×f21, 10×f20, 6×f19, 15×f18, 10×f17, 10×f16, 8×f15, 4×f14, 4×f13, 3×f12, 1×f11, 2×f10, 1×f7

What stood near at death: standard ×32; crawler,standard ×19; (none close) ×9; spitter,standard ×7; spitter ×6; big,spitter,standard ×4; boss ×4; crawler,longarm,spitter,standard ×3; boss,spitter ×3; big ×3; crawler,spitter,standard ×2; longarm ×2; big,standard ×2; boss,standard ×1; big,crawler,longarm,standard ×1; crawler,longarm,standard ×1; big,crawler,longarm,spitter,standard ×1; big,longarm,spitter ×1; longarm,spitter,standard ×1; boss,longarm ×1; longarm,spitter ×1; boss,longarm,spitter,standard ×1; big,spitter ×1; boss,crawler,standard ×1; big,boss ×1

Time alive before death: median 151 s, range 63–255 s

Barricaded stairwells met: 157 across 108 character-runs (1.5 per run); 38 runs ended within 3 floors below their last one.

Kit wear (over 108 character-runs): first hammer broke by floor 21 (median, 70 runs); both hammers broke by floor 21 (66 runs); gun empty by floor 21 (108 runs).

Stage-hits absorbed per character-run: median 12 (min 10, max 17); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×106, f20 ×74, f15 ×23, f10 ×3; upgrade picks taken: 128.

Upgrades taken: Fleet ×14; Deep Breaths ×12; Efficient Stride ×11; Quick Recovery ×10; Bruiser ×8; Glass Cannon ×6; Keen Ear ×6; Soft Soles ×6; Trigger Discipline ×6; Extended Mag ×5; Steady Aim ×5; Tinkerer ×4; Deep Pockets ×4; Pack Mule ×3; Drum Mag ×3; Fortune's Favour ×3; Rummager ×3; Marksman ×3; Crushing Blows ×3; Iron Lungs ×3; Scavenger ×2; Night Eyes ×2; Loadbearer ×2; Marathoner ×2; Sticky Fingers ×1; Ghost ×1

Boons taken: B_rage ×24; B_adrenaline ×23; B_second_wind ×20; B_lungs ×20; B_breath ×14; B_brawler ×11; B_light ×7; B_senses ×5; B_steady ×4

Hardest floors (stage-hits per entry, floors entered ≥3 times): f18 2.6/entry (58 entries, 15 deaths); f11 2.5/entry (4 entries, 1 deaths); f13 2.4/entry (11 entries, 4 deaths); f15 2.3/entry (23 entries, 8 deaths); f14 2.2/entry (15 entries, 4 deaths); f16 2.1/entry (33 entries, 10 deaths); f17 1.7/entry (43 entries, 10 deaths); f20 1.6/entry (74 entries, 10 deaths)

### none — coverage

Exercised: a scavenge node searched ×8, an item taken from a node ×3, an item left on a node ×3, an item put down for a better one ×1, the fuse box used ×1, a fuse fitted ×1, the workbench opened ×3, a broken item salvaged ×6, a crowbar handed over ×157

**Never exercised in this configuration:** an apartment door entered, a shut door forced open, a locked door forced, a key used on its door, a barricaded door torn open, a breach room entered, a world drop picked up, a set-back node reached, scrap taken from a burnt flat, a maintenance room entered, the elevator powered, the elevator ridden, a weapon upgraded, a weapon tuned, the merchant's shop used, something bought, something sold, the gun reloaded from the bag, something mended with a toolbox, a Molotov thrown

### none — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| SAVE_LOAD_DRIFT | 1 | 1 | run 3 floor 18: floor 18: after save + load these fields differ: stamina (first: 135.0 -> 134.9) |

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

## safe — 12 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 12 | 10 / 20 / 20.4 / 28 | 0 | 12 | 0 | 1422 | 52 |
| 2 | 11 | 17 / 25 / 23.6 / 29 | 0 | 11 | 0 | 970 | 30 |
| 3 | 11 | 20 / 25 / 24.2 / 27 | 0 | 11 | 0 | 686 | 28 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 12 / 12 | 8 / 12 | 7 / 12 | 2 / 12 | 1 / 12 | 0 / 12 | 0 / 12 | 0 / 12 |
| 2 | 11 / 11 | 7 / 11 | 2 / 11 | 0 / 11 | 0 / 11 | 0 / 11 | 0 / 11 | 0 / 11 |
| 3 | 11 / 11 | 6 / 11 | 2 / 11 | 0 / 11 | 0 / 11 | 0 / 11 | 0 / 11 | 0 / 11 |

Deaths by floor: 1×f29, 2×f28, 4×f27, 6×f26, 3×f25, 1×f24, 2×f23, 1×f22, 3×f21, 4×f20, 3×f19, 1×f17, 1×f16, 1×f12, 1×f10

What stood near at death: (none close) ×10; standard ×9; crawler,standard ×6; spitter,standard ×4; big ×2; boss,standard ×1; spitter ×1; crawler,spitter ×1

Time alive before death: median 952 s, range 254–3091 s

Barricaded stairwells met: 24 across 34 character-runs (0.7 per run); 8 runs ended within 3 floors below their last one.

Kit wear (over 34 character-runs): first hammer broke by floor 28 (median, 21 runs); both hammers broke by floor 28 (19 runs); gun empty by floor 26 (17 runs).

Stage-hits absorbed per character-run: median 22 (min 5, max 40); first aids used: median 6. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×21, f20 ×11, f15 ×2, f10 ×1; upgrade picks taken: 19.

Upgrades taken: Quick Recovery ×3; Rummager ×2; Soft Soles ×2; Trigger Discipline ×2; Keen Ear ×1; Marksman ×1; Sticky Fingers ×1; Tinkerer ×1; Steady Aim ×1; Drum Mag ×1; Deep Breaths ×1; Extended Mag ×1; Glass Cannon ×1; Fleet ×1

Boons taken: B_rage ×4; B_adrenaline ×4; B_light ×3; B_steady ×3; B_lungs ×2; B_brawler ×1; B_breath ×1; B_second_wind ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f19 6.3/entry (7 entries, 3 deaths); f21 4.6/entry (14 entries, 3 deaths); f27 4.2/entry (31 entries, 4 deaths); f20 3.7/entry (11 entries, 4 deaths); f26 3.5/entry (27 entries, 6 deaths); f24 3.0/entry (18 entries, 1 deaths); f28 2.9/entry (33 entries, 2 deaths); f23 2.5/entry (17 entries, 2 deaths)

### safe — scavenging

Over 34 character-runs the bot went into **581 apartments** and **54 maintenance rooms** (17.1 flats and 1.6 staff rooms per character).

Per flat: 57 s inside (median; 0–87), 5.4 nodes opened, 3.8 of them held something, 1.2 dead met at most at once; the bot took at least one hit in **104 of 581** (18%).

| run | flats | s inside (median) | nodes opened / flat | items shown / flat | dead met / flat | kills / flat | stage-hits / flat | flats with a hit |
|---|---|---|---|---|---|---|---|---|
| 1 | 231 | 61 | 6.3 | 4.53 | 1.3 | 1.5 | 0.47 | 15% |
| 2 | 167 | 59 | 5.6 | 3.70 | 1.4 | 1.8 | 0.89 | 23% |
| 3 | 183 | 28 | 4.0 | 2.98 | 1.1 | 1.3 | 0.55 | 15% |

By how the door stood: open — 405 flats, 0.68 hits, 1.6 kills, 1.3 dead met; shut (forceable) — 85 flats, 0.62 hits, 1.6 kills, 1.1 dead met; shut (locked) — 68 flats, 0.19 hits, 1.2 kills, 1.0 dead met; ? — 14 flats, 1.29 hits, 1.1 kills, 1.4 dead met; barricaded (locked) — 7 flats, 0.14 hits, 1.1 kills, 0.7 dead met; barricaded (forceable) — 2 flats, 0.00 hits, 0.0 kills, 0.0 dead met

How the flats ended: all searched ×518, ? ×43, left hurt ×16, warned off by a resident ×4

**What the nodes held** (2287 items shown across 3222 nodes opened — 71% of nodes held something):

Scrap Bag ×202 (taken 202); Bullets ×134 (taken 42); Bank Notes ×127 (taken 122); Knife ×112 (taken 16); Canned Food ×102 (taken 9); Hammer ×100 (taken 27); Battery ×90 (taken 10); Flashlight ×88 (taken 8); Fire Extinguisher ×83 (taken 6); Painkillers ×77 (taken 17); Broken Bottle ×76 (taken 0); Bandages ×70 (taken 14); Toolbox ×70 (taken 15); Sword ×65 (taken 16)

Why things were left: bag full ×1308, not worth a slot ×196, did not fit ×62

Finds per flat entered: weapons 0.94 · bullets 0.23 · first aid / bandages / painkillers 0.34 · keys 0.10 · scrap bags 0.35 · cash 0.22 · empty wallets 0.04 · crowbars 0.07 · fuses 0.06

| band | flats | items shown / flat | weapons / flat | bullets / flat | heals / flat |
|---|---|---|---|---|---|
| high 21-29 | 527 | 3.83 | 0.88 | 0.24 | 0.33 |
| mid 11-20 | 53 | 4.98 | 1.51 | 0.08 | 0.45 |
| low 1-10 | 1 | 3.00 | 1.00 | 1.00 | 0.00 |

Doors the bot did NOT go through (653): breach room (avoided) ×158, barricaded ×146, needs a weapon with 3+ uses ×124, locked, no key, nothing to force it ×111, too hurt to go in, nothing to heal with ×92, barricaded, weapon too worn ×22

**Economy per character** (end of the character's life): scrap median 44 (max 792), notes median 48 (max 289); workbench upgrades 22, tunings 27, salvaged 34; shop: 19 visits, 10 things bought, 315 notes spent, 0 sold.

What stopped a weapon going up a level at the bench: “Needs 50 scrap (you have” ×34, “Needs a spare Lv1 bat, c” ×9, “Needs a spare Lv1 Gun to” ×9, “Needs 80 scrap (you have” ×4, “Needs 100 scrap (you hav” ×3, “Needs a spare Lv1 blade ” ×3, “Needs a spare Lv2 Gun to” ×3, “Only a weapon carried th” ×1

### safe — coverage

Exercised: an apartment door entered ×568, a shut door forced open ×87, a locked door forced ×68, a key used on its door ×8, a barricaded door torn open ×10, a scavenge node searched ×3257, an item taken from a node ×721, an item left on a node ×1504, an item put down for a better one ×273, a world drop picked up ×216, a set-back node reached ×1926, scrap taken from a burnt flat ×100, a maintenance room entered ×49, the fuse box used ×8, a fuse fitted ×8, the workbench opened ×51, a weapon upgraded ×22, a weapon tuned ×27, a broken item salvaged ×34, the merchant's shop used ×19, something bought ×10, the gun reloaded from the bag ×19, something mended with a toolbox ×9, a Molotov thrown ×2, a crowbar handed over ×24

**Never exercised in this configuration:** a breach room entered, the elevator powered, the elevator ridden, something sold

### safe — anomalies and engine errors

| kind | occurrences | playthroughs | first example |
|---|---|---|---|
| DOOR_TIMEOUT | 3 | 3 | run 1 floor 23: floor 23 apt 2303: gave up at the door, stage walk, state open (door x=570, near=false) :: atk=false(cd=0.00) dying=false escaping=false pack= lash=false slide=["StaticBody2D@544[-,layer1]"] unjam=0.00 phased=1 x=8 |
| NO_PROGRESS | 2 | 2 | run 1 floor 23: floor 23: nothing changed for 30 s — phase=play scene=corridor shop=none door=2303 stage=walk state=open :: atk=false(cd=0.00) dying=false escaping=false pack= lash=false slide=["StaticBody2D@544[-,layer1]"] unjam= |

The run logs held no engine errors (SCRIPT ERROR / ERROR) beyond the exit-time leak notices.

