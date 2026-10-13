# Descent bot — round-43 sweep summary (seeds 424242, 101-115)

Generated: \`tools/bot_sweep.sh\` then \`python3 tools/bot_summary.py <dir>\`. Groups: **fighter** = the brief (16 seeds x up to 3 characters, \`--keep-going\`, crowbar handed to the bot at a barricade); **runner** = sprint-for-the-stairs style (8 seeds x 3); **strict** = the kit exactly as given, NO crowbar (\`--no-crowbar\`, 12 seeds x 1 character). All on the real game, speed 8, no god mode. The characters are NOT the same across groups (the cast is seeded).

## fighter — 16 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 16 | 15 / 18 / 18.5 / 24 | 0 | 15 | 1 | 159 | 23 |
| 2 | 15 | 16 / 19 / 19.5 / 24 | 0 | 15 | 0 | 155 | 20 |
| 3 | 15 | 15 / 22 / 21.1 / 25 | 0 | 15 | 0 | 101 | 16 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 16 / 16 | 16 / 16 | 15 / 16 | 1 / 16 | 0 / 16 | 0 / 16 | 0 / 16 | 0 / 16 |
| 2 | 15 / 15 | 15 / 15 | 12 / 15 | 0 / 15 | 0 / 15 | 0 / 15 | 0 / 15 | 0 / 15 |
| 3 | 15 / 15 | 15 / 15 | 7 / 15 | 1 / 15 | 0 / 15 | 0 / 15 | 0 / 15 | 0 / 15 |

Deaths by floor: 2×f25, 6×f24, 3×f23, 1×f22, 8×f20, 7×f19, 9×f18, 7×f17, 1×f16, 1×f15

What stood near at death: standard ×11; crawler,standard ×9; (none close) ×4; big,standard ×3; boss ×3; crawler ×2; spitter ×2; big ×1; boss,standard ×1; big,crawler,standard ×1; boss,longarm,standard ×1; crawler,longarm ×1; spitter,standard ×1; crawler,longarm,standard ×1; big,crawler,spitter ×1; boss,spitter,standard ×1; crawler,spitter,standard ×1; big,spitter,standard ×1

Time alive before death: median 144 s, range 65–250 s

Barricaded stairwells met: 77 across 46 character-runs (1.7 per run); 29 runs ended within 3 floors below their last one.

Kit wear (over 46 character-runs): first hammer broke by floor 24 (median, 40 runs); both hammers broke by floor 20 (29 runs); gun empty by floor 22 (43 runs).

Stage-hits absorbed per character-run: median 11 (min 2, max 13); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×46, f20 ×34, f15 ×2; upgrade picks taken: 50.

Upgrades taken: Field Medic ×6; Soft Soles ×4; Second Wind ×4; Ghost ×4; Deep Breaths ×4; Marathoner ×4; Strong Arm ×3; Tinkerer ×2; Sprinter's Legs ×2; Crushing Blows ×2; Fleet ×2; Trigger Discipline ×2; Keen Ear ×2; Quick Recovery ×2; Sticky Fingers ×1; Iron Lungs ×1; Deep Pockets ×1; Marksman ×1; Loadbearer ×1; Pack Mule ×1; Extended Mag ×1

Boons taken: B_adrenaline ×10; B_lungs ×8; B_rage ×8; B_breath ×7; B_second_wind ×7; B_brawler ×4; B_light ×4; B_steady ×1; B_senses ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f18 3.1/entry (19 entries, 9 deaths); f19 2.8/entry (26 entries, 7 deaths); f20 2.4/entry (34 entries, 8 deaths); f17 2.0/entry (10 entries, 7 deaths); f16 1.7/entry (3 entries, 1 deaths); f23 1.4/entry (38 entries, 3 deaths); f24 1.2/entry (44 entries, 6 deaths); f21 0.9/entry (34 entries, 0 deaths)

## runner — 8 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 8 | 15 / 18 / 18.6 / 24 | 0 | 7 | 1 | 160 | 24 |
| 2 | 7 | 13 / 22 / 20.3 / 25 | 0 | 7 | 0 | 95 | 19 |
| 3 | 7 | 20 / 24 / 23.4 / 25 | 0 | 7 | 0 | 75 | 18 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 8 / 8 | 8 / 8 | 6 / 8 | 1 / 8 | 0 / 8 | 0 / 8 | 0 / 8 | 0 / 8 |
| 2 | 7 / 7 | 7 / 7 | 3 / 7 | 2 / 7 | 0 / 7 | 0 / 7 | 0 / 7 | 0 / 7 |
| 3 | 7 / 7 | 7 / 7 | 1 / 7 | 0 / 7 | 0 / 7 | 0 / 7 | 0 / 7 | 0 / 7 |

Deaths by floor: 3×f25, 7×f24, 2×f22, 2×f20, 2×f18, 2×f17, 1×f16, 1×f14, 1×f13

What stood near at death: standard ×5; crawler,standard ×2; (none close) ×2; crawler ×1; boss,standard ×1; spitter,standard ×1; crawler,longarm,standard ×1; boss,crawler,longarm,standard ×1; big,longarm,standard ×1; boss,crawler ×1; big ×1; spitter ×1; boss ×1; boss,crawler,longarm ×1; big,longarm,spitter,standard ×1

Time alive before death: median 95 s, range 61–199 s

Barricaded stairwells met: 29 across 22 character-runs (1.3 per run); 11 runs ended within 3 floors below their last one.

Kit wear (over 22 character-runs): first hammer broke by floor 24 (median, 18 runs); both hammers broke by floor 20 (9 runs); gun empty by floor 24 (21 runs).

Stage-hits absorbed per character-run: median 11 (min 10, max 13); first aids used: median 2. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×22, f20 ×10, f15 ×3; upgrade picks taken: 15.

Upgrades taken: Second Wind ×3; Deep Breaths ×3; Marathoner ×2; Quick Recovery ×1; Strong Arm ×1; Ghost ×1; Crushing Blows ×1; Field Medic ×1; Fleet ×1; Deep Pockets ×1

Boons taken: B_adrenaline ×4; B_second_wind ×4; B_breath ×2; B_rage ×2; B_lungs ×2; B_steady ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f17 3.7/entry (6 entries, 2 deaths); f16 3.5/entry (4 entries, 1 deaths); f24 3.1/entry (19 entries, 7 deaths); f15 3.0/entry (3 entries, 0 deaths); f25 1.9/entry (22 entries, 3 deaths); f18 1.6/entry (8 entries, 2 deaths); f22 1.6/entry (12 entries, 2 deaths); f20 1.2/entry (10 entries, 2 deaths)

## strict — 12 playthroughs

| run | n | deepest floor: min / median / mean / max | reached lobby | died | stuck/timeout | median time (s) | median kills |
|---|---|---|---|---|---|---|---|
| 1 | 12 | 18 / 25 / 24.8 / 29 | 0 | 1 | 11 | 188 | 11 |

Reach curve (characters that got AT LEAST as deep as each floor; 30 = everyone):

| run | floor ≤29 | floor ≤25 | floor ≤20 | floor ≤15 | floor ≤10 | floor ≤5 | floor ≤1 | lobby |
|---|---|---|---|---|---|---|---|---|
| 1 | 12 / 12 | 7 / 12 | 1 / 12 | 0 / 12 | 0 / 12 | 0 / 12 | 0 / 12 | 0 / 12 |

Deaths by floor: 1×f18

What stood near at death: crawler,standard ×1

Time alive before death: median 145 s, range 145–145 s

Barricaded stairwells met: 0 across 12 character-runs (0.0 per run); 0 runs ended within 3 floors below their last one.

Kit wear (over 12 character-runs): first hammer broke by floor 25 (median, 7 runs); both hammers broke by floor 23 (1 runs); gun empty by floor 22 (1 runs).

Stage-hits absorbed per character-run: median 0 (min 0, max 11); first aids used: median 0. (Health is five stages and a first aid restores three, so a character that spends both kits and dies has absorbed 11.)

Merchant floors entered: f25 ×7, f20 ×1; upgrade picks taken: 8.

Upgrades taken: Marathoner ×3; Deep Breaths ×2; Fleet ×1; Tinkerer ×1; Ghost ×1

Boons taken: B_adrenaline ×3; B_breath ×2; B_rage ×1; B_lungs ×1; B_second_wind ×1

Hardest floors (stage-hits per entry, floors entered ≥3 times): f27 0.2/entry (10 entries, 0 deaths); f26 0.1/entry (7 entries, 0 deaths); f25 0.1/entry (7 entries, 0 deaths); f28 0.1/entry (11 entries, 0 deaths); f29 0.1/entry (12 entries, 0 deaths); f30 0.0/entry (12 entries, 0 deaths); f24 0.0/entry (4 entries, 0 deaths); f23 0.0/entry (4 entries, 0 deaths)

