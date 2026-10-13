# Descent bot runs (owner round 43)

> "Send a bot run down through the building. Give the bot two hammers, one gun with eight bullets preloaded, and two first aid kits.
> See how far it gets and allow it to pick upgrades if it makes the various five-floor increments. If it makes it to the lobby, make
> notes for analysis and evaluation and continue with run 2 and 3."

**Status: BUILT (tools only — no game rule was changed to make it work).** `tools/bot_run.tscn` plays the real game headless;
`tools/bot_sweep.sh` runs it over many seeds; `tools/bot_summary.py` turns a folder of its reports into the tables below.

## Headline

**The briefed kit does not reach the lobby.** Across the sweep — 80 character-descents on 16 seeds (`fighter`, the brief), 8 seeds (`runner`) and 12 seeds
(`strict`, no crowbar) — **none reached the lobby, and none got below floor 13**. The brief's rule ("if it makes it to the lobby, … continue with run 2
and 3") therefore never triggered; runs 2 and 3 below are `--keep-going` data, not the continuation the brief describes.

| as briefed (`fighter`, crowbar handed over at a barricade) | run 1 | run 2 | run 3 |
|---|---|---|---|
| characters | 16 | 15 | 15 |
| deepest floor, min / median / mean / max | 15 / **18** / 18.5 / 24 | 16 / **19** / 19.5 / 24 | 15 / **22** / 21.1 / 25 |
| reached floor 20 | 15 / 16 | 12 / 15 | 7 / 15 |
| reached floor 15 | 1 / 16 | 0 / 15 | 1 / 15 |
| reached the lobby | 0 | 0 | 0 |
| median time alive | 159 s | 155 s | 101 s |

* **The primary seed (424242), run 1:** Alex died on floor 20 after 135 s. (Earlier shake-down runs of the very same seed ended on floors 16–26 — one seed is
  noise of about ±5 floors, because the game's real-time-driven code (attack buffer, timers) runs a little differently from run to run at 8× speed. The sweep, not a
  single run, is the evidence. Full per-character table: `docs/bot_runs/round43_by_seed.md`; the full summary: `docs/bot_runs/round43_sweep.md`.)
* **Merchants reached:** floor 25 by 46 / 46 fighter characters, floor 20 by 34 / 46, floor 15 by 2 / 46, floors 10 and 5 never. Upgrades taken: 50, boons: 50
  (Field Medic, Second Wind, Ghost, Deep Breaths, Marathoner…; Adrenaline / Lungs / Rage / Breath boons).
* **The strict kit (no crowbar): 11 of 12 stopped at the first barricaded stairwell** — on floor 29, 28, 27 (×3), 25 (×3), 23, 22, 21 — most of them with the
  kit barely worn (five stopped on floors 27–29 with the gun still full and a hammer at 3–8 durability, the other untouched at 10). One died on floor 18 having met none. A barricade needs a crowbar, the kit has none, and there
  is no other way past (the banister refuses a barricaded well too).
* **The runner style** (sprint, fight only what blocks): same wall — run 1 median floor 18, runs 2 / 3 median 22 / 24 (7 characters each, so thin) — but its deaths bunch at
  floors 24–25 (10 of 22), the arrival floors of the first crowbar crossings, where it lands spent among the mustered dead.

## Analysis

1. **The kit is worth about ten floors of fighting, and the building gets steeper at the same moment.** The first hammer is gone by floor 24 (median), both by floor 20,
   the gun is empty by floor 22 (~17 swings, ~8 shots, ~4 shoves per character). Stage-hits taken per floor entered, fighter group: **0.38 on floors 29–25, 1.3 on 24–20,
   2.65 on 19–15** — a seven-fold climb over fifteen floors. 31 of the 45 fighter deaths are on floors 17–20 and another 11 on 23–25. An unarmed bot with
   a half-spent health budget meets 2–3 stage-hits a floor and lasts two or three floors.
2. **The health budget is fixed at 11 stage-hits** (five stages + two first aids × three), and every character dies at 11 (min 2, max 13: a rest or a pry
   moves it a little). So *depth = how slowly the 11 are spent*; the upgrades the bot took (Field Medic is the one that matters most — a bigger heal) are worth a
   few floors, not a different regime.
3. **Later characters did a little better, not worse** (median 18 → 19 → 22) although the building decays: the merchant upgrades accumulate across the three
   characters (1.8 active at run 1's end, 2.5, 3.2 on average) and some runs inherit haven floors (below). The cast does not explain it (Joe 19, Alex 20, Amina 18.5, Vivianne 18
   median over the fighter group). I have not isolated which of the two it is.
4. **Barricades are the main structural wall.** A fighter meets 1.7 per character (77 in 46), roughly one staircase in six, as designed (18 %). Every pry costs ~16 s of heaving, a rest slot, and
   an arrival with stamina at the exhausted floor in the middle of the mustered dead. 29 of 46 fighter characters ended within three floors below one (63 %); chance alone gives ~45 %
   (1 − 0.82³), so that is a modest excess, not proof the arrival is lethal. The strict group is the clean evidence: without a crowbar, the first barricade ends the descent by
   floor ~25 almost every time. **Where crowbars come from (scavenging, merchant stock) was not measured here.**
5. **Havens appeared on their own.** The bot never talks to anyone, but killing two of the dead near a fighting defender registers a haven (round 42). 14 of 24 playthroughs
   (`fighter` + `runner`, run 2/3 data) produced at least one haven floor (mean 0.9 distinct floors, max 4), 39 of 748 floor visits were haven floors. Runs that inherited a haven did *not* go
   deeper (median 20 vs 23, n = 26 vs 18) — because the bot only ever earned them on floors 19–28 (mostly 22–27), the floors that were already easy (0.4–1.3 stage-hits), while the damage is on 15–20. **Havens
   only help where the player fights deep enough to earn them there;** a bot that dies at 18 never earns the ones that would matter.
6. **What kills:** a plain standard zombie stood within 400 px at 31 of the 45 fighter deaths (crawlers at 16, spitters 7, bigs 7, bosses 6, long-arms 3, nobody near at 4) and is the biggest named source of stage-hits (244 of 505), crawlers next (65), bigs 30 and bosses 29 — and 117
   hits came from "fire / ranged / other" (a spit, a flame, or the one that was already out of sight). No new enemy type dominates; it is attrition, not a wall.
7. **Pace:** median 11 s per floor, ~13 s mean — a straight walk of the corridor is ~7 s, so most of a floor is the one or two fights.

## Caveats (read before quoting any number)

* **The bot does not scavenge, loot, trade, rest, throw, craft or use the banister**, so every number is a floor for a careful human, whose kit grows as they descend. It says how far
  *a fixed kit* goes, not how far *a player* goes. A scavenging bot (or a human playtest of the same seeds) is the missing half.
* It has perfect knowledge of the zombies on its plane within a screen and reacts every physics tick; it never mis-clicks and never panics. Its fight rules are mine (`_fight` / `_pick_threat`), tuned on
  ~10 shake-down runs; a better rule set would go deeper. The fighter and runner styles bracket it, they do not bound it.
* **Speed 8 changes the game slightly:** code that reads real time (`Time.get_ticks_msec`: the attack buffer, a few prompt guards) runs 8× fast. Runs of one seed differ (see the primary seed above). I did not run a
  speed-1 comparison.
* **Two characters ended `stuck` on floor 15** with no weapon left: `fighter_110` had a stair enemy holding the crossing (the bot neither makes a noise to draw it up nor vaults the half-wall); `runner_107`'s cause I did
  not diagnose. 2 of 80.
* The crowbar is a liberty the brief did not give: fighter / runner numbers include it (1.7 per character). The strict group is what the brief says without it.
* Health is stages: "hits" in every table are stage drops. Kills count any dead body the bot saw fall (fire kills included), so kills ≠ swings.
* Runs 2 / 3 carry the earlier characters' merchant upgrades and the world's decay (fire, door states, more bosses); the kit is reset, the upgrades are not. The characters differ per seed.

## Suggestions (mine — the balance calls are the owner's)

1. Decide what the design intends the *kit alone* to buy. Measured: ~10 floors of fighting and a ~11-hit health budget against 2–3 hits a floor from floor 19. Reaching the lobby on that rate needs
   (extrapolating the measured 2.65 / floor to the 14 floors below 15, which I did not measure) **at least ~5× the briefed health budget** — i.e. the scavenging loop has to supply most of the descent. Before changing any number, measure what a
   careful scavenger actually finds per floor (hammers, first aids, bullets, crowbars): that is the bot to build next.
2. **The crowbar is the only key to 18 % of the stairs.** The strict group says: with no crowbar in hand the descent ends at the first barricade (floors 21–29). Check that a crowbar is reliably findable above floor 21
   (spawn weight in `Items.json`, merchant stock) or give barricades a crowbar-free cost (a loud, slow hand-clear, a banister that works on a barricade at a price).
3. **The steepest band is floors 20–15** (1.3 → 2.65 stage-hits per floor, 31 of 45 fighter deaths on 17–20). If the aim is a smooth curve, that is where a haven, a merchant or a rest would buy the most; as it stands the
   merchants are on 25 / 20 / 15 / 10 / 5 and the bot saw floor 15 in 2 of 46 descents, 10 and 5 never.
4. Havens are cheap to earn for a fighting player but pay out on easy floors (point 5). If they are meant to flatten the hard floors, the aid rule could weight depth.
5. Next measurements worth having: the same sweep with a *scavenging* bot; a speed-1 spot check of the speed-8 distortion; havens per human descent.


## How to run it

```
godot --headless res://tools/bot_run.tscn -- --seed=424242 --speed=8 --out=/tmp/bot.md [--style=fighter|runner] [--runs=3]
      [--keep-going] [--no-crowbar] [--start-floor=N] [--start-run=N] [--opener] [--trace]
tools/bot_sweep.sh <outdir> <group> "<seeds>" [bot args...]      # one godot at a time; files land as <group>_<seed>.{md,json,log}
python3 tools/bot_summary.py <outdir>                            # one comparison section per group
```

Game time, not wall time: `--speed=8` raises `physics_ticks_per_second` AND `time_scale` together (every step is still 1/60 s of game), so a
playthrough takes 1–2 minutes of wall time. It runs in the test sandbox (`res://tools/` → `WorldState.data_dir()`), never the owner's saves.
The report is rewritten after every character, so a cut-off sweep keeps what it had. `--trace` prints the bot's state every 2 s plus a
5 s heartbeat (scene / pause / transition / run) — the first thing to turn on when a run stalls.

## What the bot is

* **The kit, exactly as briefed:** two Hammers (002, durability 10 each), one Gun (004) with 8 rounds loaded, two First Aid Kits (007).
  Five slots, nothing else. New game on a chosen seed, `packless_rule` and `story_rule` off (the descent is what is being measured), the
  tutorial skipped, survivors ON (`survivor_rule`, like a real New Game), no god mode.
* **It plays through the player's own controls** — held `move_left/right` and `sprint`, the attack action pushed as an input event, the push
  action, `use_item` for a first aid, `HUD.select_slot`, the stairwell's own `request_auto_descend` (the touch STAIRS button's path), the
  merchant's own `_open_shop`. It sees what a player sees (one screen of corridor each way) and knows what a player knows (which side the
  down stairs are on, from the sign).
* **It does NOT** scavenge, loot, open a door, talk to a survivor, throw anything, craft, use the banister, or rest. It has what it was given
  plus what the merchant offers. That makes every number below a **floor for a careful human** (who finds weapons, kits and bullets), not a
  prediction of one.
* **Styles.** `fighter` (the default, and the brief): fights what is in its way or coming for it, waits for a charging dead body so the first
  swing is its own, shoves when two are on it, kites (walks off, they are slower) when out of wind, uses the gun on the ones that hurt (Big,
  Spitter, a boss), or when winded/cornered, heals at Wounded-or-worse (Dying always) once nothing is within reach. `runner`: sprints for the
  stairs and fights only what blocks it or is already on it.
* **The merchant (floors 25 / 20 / 15 / 10 / 5):** walks to the lift, opens the shop, takes the upgrade and the boon by a fixed score table
  (`UPGRADE_SCORE` / `BOON_SCORE` in the script: survival first — Heal, Melee, Stamina, Regen, Quiet, Speed — and never a drawback unless it is
  the better of two). It buys nothing and sells nothing.
* **The one liberty — the crowbar.** A barricaded stairwell (18% of staircases) can only be crossed with a Crowbar (035), which the bot could
  never have found (it does not scavenge). So **at the moment it stands at a barricaded stairwell it is handed one** (outside the five slots, logged
  as `CROWBAR` in the event log) and the real pry follows: ~6 s of loud heaving, the building shifts, a rest slot is lost, it arrives spent
  (stamina to the floor) with the arrival floor's dead mustered at the steps. `--no-crowbar` takes the liberty away: the bot is then stuck at the
  first barricade, which is the "strict reading of the brief" result (see below).
* **The lobby and runs 2/3:** at the lobby it clears the door's neighbourhood, steps to the exit and presses interact (no weapon is stored at
  the door, nothing is scrapped), and the game's own end-of-run flow takes it into the next character. A death does the same. By the brief a
  run-1 death STOPS the experiment; `--keep-going` plays on so a sweep gets data for all three characters.

## What it measures

Per character: deepest floor, time alive, kills (by type), stage-hits taken and by whom, first aids used, swings / shots / shoves, the kit
at every floor (hammer durability, rounds), stamina low-point per floor, barricades met, upgrades and boons taken, and for a death the last
seven seconds (hp word, stamina, who stood within 260 px). **"Hits" are health stages, not hit points:** health is five stages and a first aid
restores three, so a character that spends both kits and dies has always absorbed exactly 11 — the interesting number is *when*, not how many.

## What running it found in the game

1. **A real stairwell bug (fixed, `scripts/stairwell.gd`, locked by `stair_block_test._test_one_crossing_at_a_time`).** After a crowbar pry the
   stairwell's touch-walk flag (`touch_auto`) could still be armed; its arrival tick then took the now-cleared stairs a SECOND time while the
   pry's fade was still running. `Transition.to_scene` ignores a second call while busy, but `current_floor` was already stepped down — so the
   floor counter jumped a floor ahead of the floor that loaded (28 → 26; floor 27 never existed). `_use_stairs` now refuses while a transition
   or pan is running, and starting a pry disarms the walk. Mutation-checked: without the fix the new check fails.
2. **A hammer-less, wind-less character dies in the "dying" countdown with nowhere to go** — that is the game working as designed (a first aid is the
   only way out of Dying), noted because it is the commonest death shape (see the analysis).
3. Nothing else broke: no script errors across the whole sweep, and the cold open's pausing lockout lines for Joe / Amina (which stalled the first
   sweep until the bot learned to press through them) are a reminder that **a pausing line needs a press to continue** — fine for a player, a
   trap for any future automated driver.
