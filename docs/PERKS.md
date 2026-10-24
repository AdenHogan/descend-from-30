# Perk list (generated — do not edit by hand)

Regenerate with `godot --headless res://tools/perk_table.tscn` after changing a perk.
Edit the data in `scripts/world_state.gd` `UPGRADE_POOL` (the merchant's own upgrades) and
`scripts/progression.gd` `RUN_BOONS` (the former run boons, now in the same offer). Columns:

- **Rarity `w`** — how often the merchant offers it (higher = more common; the former boons all weigh 3).
- **Desirability `d`** — 1-5, how much a player wants it (5 = coveted). Only matters under
  perk luck (Fortune's Favour): offers tilt toward high-`d` perks (x1.6 per step from 3).
- **Keep forever** — its Descent Valour price to make it permanent.

| Id | Perk | Kind | What it does | Rarity w | Desirability d | Keep forever |
|---|---|---|---|---|---|---|
| `U_stam_s` | Second Wind | Upgrade | +15 max stamina | 6 | 2 | 150 |
| `U_stam_m` | Marathoner | Upgrade | +30 max stamina | 4 | 3 | 200 |
| `U_stam_l` | Iron Lungs | Upgrade | +50 max stamina | 2 | 4 | 350 |
| `U_regen_s` | Quick Recovery | Upgrade | +25% stamina regen | 5 | 2 | 200 |
| `U_regen_m` | Deep Breaths | Upgrade | +50% stamina regen | 3 | 3 | 275 |
| `U_sprint_s` | Efficient Stride | Upgrade | -20% sprint stamina cost | 4 | 2 | 200 |
| `U_sprint_m` | Featherfoot | Upgrade | -35% sprint stamina cost | 2 | 3 | 350 |
| `U_slot` | Deep Pockets | Upgrade | +1 inventory slot | 7 | 5 | 550 |
| `U_speed_s` | Fleet | Upgrade | +10% move speed | 4 | 3 | 200 |
| `U_speed_m` | Sprinter's Legs | Upgrade | +18% move speed | 2 | 4 | 350 |
| `U_melee_s` | Strong Arm | Upgrade | +1 melee damage | 4 | 3 | 200 |
| `U_melee_m` | Crushing Blows | Upgrade | +2 melee damage | 2 | 4 | 350 |
| `U_push` | Bruiser | Upgrade | +40% push force | 3 | 2 | 275 |
| `U_head_s` | Steady Aim | Upgrade | +8% headshot chance | 4 | 2 | 200 |
| `U_head_m` | Marksman | Upgrade | +15% headshot chance | 2 | 4 | 350 |
| `U_acc` | Trigger Discipline | Upgrade | +12% hit (body) chance | 3 | 3 | 275 |
| `U_mag_s` | Extended Mag | Upgrade | +6 magazine capacity | 3 | 2 | 275 |
| `U_mag_m` | Drum Mag | Upgrade | +12 magazine capacity | 1 | 3 | 450 |
| `U_listen` | Keen Ear | Upgrade | -30% listen time | 3 | 2 | 275 |
| `U_heal` | Field Medic | Upgrade | Healing items restore +1 state | 3 | 4 | 275 |
| `U_scav_s` | Scavenger | Upgrade | +8% scavenge find rate | 4 | 3 | 200 |
| `U_scav_m` | Sticky Fingers | Upgrade | +15% scavenge find rate | 2 | 4 | 350 |
| `U_quiet_s` | Soft Soles | Upgrade | -20% movement noise | 4 | 2 | 200 |
| `U_quiet_m` | Ghost | Upgrade | -40% movement noise | 2 | 4 | 350 |
| `U_tinker` | Tinkerer | Upgrade | Dismantling at a workbench yields 2.5x the scrap | 3 | 4 | 275 |
| `U_nightvision` | Night Eyes | Upgrade | See much further in the dark (matters most at night) | 3 | 4 | 275 |
| `U_fortune` | Fortune's Favour | Upgrade | Offers lean toward the perks worth keeping | 1 | 4 | 400 |
| `U_db_slotstam` | Pack Mule | Upgrade (drawback) | +1 inventory slot, but -25% max stamina | 2 | 4 | 350 |
| `U_db_glass` | Glass Cannon | Upgrade (drawback) | +2 melee damage, but -30% max stamina | 2 | 2 | 250 |
| `U_db_speedquiet` | Reckless Dash | Upgrade (drawback) | +20% move speed, but +40% movement noise | 2 | 2 | 250 |
| `U_db_headslow` | Aim Down | Upgrade (drawback) | +18% headshot chance, but -20% move speed | 2 | 1 | 250 |
| `U_db_quietweak` | Careful Steps | Upgrade (drawback) | -40% movement noise, but -1 melee damage | 2 | 1 | 250 |
| `U_db_scavloud` | Rummager | Upgrade (drawback) | +15% scavenge rate, but +30% movement noise | 2 | 2 | 250 |
| `U_db_magstam` | Loadbearer | Upgrade (drawback) | +12 magazine capacity, but -20% max stamina | 1 | 2 | 350 |
| `U_db_regenslow` | Adrenaline Junkie | Upgrade (drawback) | +50% stamina regen, but -15% move speed | 2 | 2 | 250 |
| `B_adrenaline` | Adrenaline | Upgrade (once a run boon) | +20% move speed | 3 | 4 | 250 |
| `B_second_wind` | Catch Your Breath | Upgrade (once a run boon) | +60% stamina regen | 3 | 3 | 250 |
| `B_rage` | Rage | Upgrade (once a run boon) | +2 melee damage | 3 | 4 | 250 |
| `B_steady` | Steady Nerves | Upgrade (once a run boon) | +12% headshot, +10% body-hit chance | 3 | 3 | 250 |
| `B_breath` | Holding Breath | Upgrade (once a run boon) | -40% movement noise | 3 | 3 | 250 |
| `B_eye` | Sharp Eye | Upgrade (once a run boon) | +15% scavenge find rate | 3 | 3 | 250 |
| `B_lungs` | Big Lungs | Upgrade (once a run boon) | +40 max stamina | 3 | 3 | 250 |
| `B_light` | Light Feet | Upgrade (once a run boon) | -40% sprint stamina cost | 3 | 3 | 250 |
| `B_brawler` | Brawler | Upgrade (once a run boon) | Pushes cost 40% less and shove 50% harder | 3 | 3 | 250 |
| `B_senses` | Heightened Senses | Upgrade (once a run boon) | -40% listen time | 3 | 2 | 250 |
