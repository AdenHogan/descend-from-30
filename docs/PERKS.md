# Perk list (generated — do not edit by hand)

Regenerate with `godot --headless res://tools/perk_table.tscn` after changing a perk.
Edit the data in `scripts/world_state.gd` `UPGRADE_POOL` (merchant upgrades) and
`scripts/progression.gd` `RUN_BOONS` (run boons). Columns:

- **Rarity `w`** — how often the merchant offers it (higher = more common; boons are drawn evenly).
- **Desirability `d`** — 1-5, how much a player wants it (5 = coveted). Only matters under
  perk luck (Fortune's Favour): offers tilt toward high-`d` perks (x1.6 per step from 3).
- **Keep forever** — its Descent Valour price to make it permanent.

| Id | Perk | Kind | What it does | Rarity w | Desirability d | Keep forever |
|---|---|---|---|---|---|---|
| `U_stam_s` | Second Wind | Merchant | +15 max stamina | 6 | 2 | 150 |
| `U_stam_m` | Marathoner | Merchant | +30 max stamina | 4 | 3 | 200 |
| `U_stam_l` | Iron Lungs | Merchant | +50 max stamina | 2 | 4 | 350 |
| `U_regen_s` | Quick Recovery | Merchant | +25% stamina regen | 5 | 2 | 200 |
| `U_regen_m` | Deep Breaths | Merchant | +50% stamina regen | 3 | 3 | 275 |
| `U_sprint_s` | Efficient Stride | Merchant | -20% sprint stamina cost | 4 | 2 | 200 |
| `U_sprint_m` | Featherfoot | Merchant | -35% sprint stamina cost | 2 | 3 | 350 |
| `U_slot` | Deep Pockets | Merchant | +1 inventory slot | 7 | 5 | 550 |
| `U_speed_s` | Fleet | Merchant | +10% move speed | 4 | 3 | 200 |
| `U_speed_m` | Sprinter's Legs | Merchant | +18% move speed | 2 | 4 | 350 |
| `U_melee_s` | Strong Arm | Merchant | +1 melee damage | 4 | 3 | 200 |
| `U_melee_m` | Crushing Blows | Merchant | +2 melee damage | 2 | 4 | 350 |
| `U_push` | Bruiser | Merchant | +40% push force | 3 | 2 | 275 |
| `U_head_s` | Steady Aim | Merchant | +8% headshot chance | 4 | 2 | 200 |
| `U_head_m` | Marksman | Merchant | +15% headshot chance | 2 | 4 | 350 |
| `U_acc` | Trigger Discipline | Merchant | +12% hit (body) chance | 3 | 3 | 275 |
| `U_mag_s` | Extended Mag | Merchant | +6 magazine capacity | 3 | 2 | 275 |
| `U_mag_m` | Drum Mag | Merchant | +12 magazine capacity | 1 | 3 | 450 |
| `U_listen` | Keen Ear | Merchant | -30% listen time | 3 | 2 | 275 |
| `U_heal` | Field Medic | Merchant | Healing items restore +1 state | 3 | 4 | 275 |
| `U_scav_s` | Scavenger | Merchant | +8% scavenge find rate | 4 | 3 | 200 |
| `U_scav_m` | Sticky Fingers | Merchant | +15% scavenge find rate | 2 | 4 | 350 |
| `U_quiet_s` | Soft Soles | Merchant | -20% movement noise | 4 | 2 | 200 |
| `U_quiet_m` | Ghost | Merchant | -40% movement noise | 2 | 4 | 350 |
| `U_tinker` | Tinkerer | Merchant | Dismantling at a workbench yields 2.5x the scrap | 3 | 4 | 275 |
| `U_nightvision` | Night Eyes | Merchant | See much further in the dark (matters most at night) | 3 | 4 | 275 |
| `U_fortune` | Fortune's Favour | Merchant | Offers lean toward the perks worth keeping | 3 | 4 | 400 |
| `U_db_slotstam` | Pack Mule | Merchant (drawback) | +1 inventory slot, but -25% max stamina | 2 | 4 | 350 |
| `U_db_glass` | Glass Cannon | Merchant (drawback) | +2 melee damage, but -30% max stamina | 2 | 2 | 250 |
| `U_db_speedquiet` | Reckless Dash | Merchant (drawback) | +20% move speed, but +40% movement noise | 2 | 2 | 250 |
| `U_db_headslow` | Aim Down | Merchant (drawback) | +18% headshot chance, but -20% move speed | 2 | 1 | 250 |
| `U_db_quietweak` | Careful Steps | Merchant (drawback) | -40% movement noise, but -1 melee damage | 2 | 1 | 250 |
| `U_db_scavloud` | Rummager | Merchant (drawback) | +15% scavenge rate, but +30% movement noise | 2 | 2 | 250 |
| `U_db_magstam` | Loadbearer | Merchant (drawback) | +12 magazine capacity, but -20% max stamina | 1 | 2 | 350 |
| `U_db_regenslow` | Adrenaline Junkie | Merchant (drawback) | +50% stamina regen, but -15% move speed | 2 | 2 | 250 |
| `B_adrenaline` | Adrenaline | Run boon | +20% move speed | — | 4 | 250 |
| `B_second_wind` | Catch Your Breath | Run boon | +60% stamina regen | — | 3 | 250 |
| `B_rage` | Rage | Run boon | +2 melee damage | — | 4 | 250 |
| `B_steady` | Steady Nerves | Run boon | +12% headshot, +10% body-hit chance | — | 3 | 250 |
| `B_breath` | Holding Breath | Run boon | -40% movement noise | — | 3 | 250 |
| `B_eye` | Sharp Eye | Run boon | +15% scavenge find rate | — | 3 | 250 |
| `B_lungs` | Big Lungs | Run boon | +40 max stamina | — | 3 | 250 |
| `B_light` | Light Feet | Run boon | -40% sprint stamina cost | — | 3 | 250 |
| `B_brawler` | Brawler | Run boon | Pushes cost 40% less and shove 50% harder | — | 3 | 250 |
| `B_senses` | Heightened Senses | Run boon | -40% listen time | — | 2 | 250 |
