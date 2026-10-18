# Descent bot runs (owner round 43)

> "Send a bot run down through the building. Give the bot two hammers, one gun with eight bullets preloaded, and two first aid kits.
> See how far it gets and allow it to pick upgrades if it makes the various five-floor increments. If it makes it to the lobby, make
> notes for analysis and evaluation and continue with run 2 and 3."

**Status: BUILT.** `tools/bot_run.tscn` plays the real game headless; `tools/bot_sweep.py` runs it over seeds × policies; `tools/bot_summary.py` turns a folder of its reports into the tables.
**Round 43 (below) is the briefed-kit-only bot. Round 44 (the last section) adds scavenging, a watcher and a wide sweep, corrects the "stuck on floor 15" explanation, and found 11 game bugs (fixed, each with a test).**
Round 44 supersedes every sentence below that says the bot "does not scavenge", and the floor-15 caveat.

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

* **(Round 43 bot only — round 44's `need` / `all` / `safe` policies scavenge, trade, mend and throw; none of them crafts, rests, listens or uses the banister.) The briefed-kit bot does not scavenge, loot, trade, rest, throw, craft or use the banister**, so every number is a floor for a careful human, whose kit grows as they descend. It says how far
  *a fixed kit* goes, not how far *a player* goes. A scavenging bot (or a human playtest of the same seeds) is the missing half.
* It has perfect knowledge of the zombies on its plane within a screen and reacts every physics tick; it never mis-clicks and never panics. Its fight rules are mine (`_fight` / `_pick_threat`), tuned on
  ~10 shake-down runs; a better rule set would go deeper. The fighter and runner styles bracket it, they do not bound it.
* **Speed 8 changes the game slightly:** code that reads real time (`Time.get_ticks_msec`: the attack buffer, a few prompt guards) runs 8× fast. Runs of one seed differ (see the primary seed above). I did not run a
  speed-1 comparison.
* **Two characters ended `stuck` on floor 15.** Round 44 explains both (and corrects what this line used to say): the lift and the maintenance door answered ONE [interact] press together — a game bug, fixed; see "Round 44".
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
* **The round-43 policy (`--loot=none`) does NOT** scavenge, loot, open a door, talk to a survivor, throw anything, craft, use the banister, or rest. It has what it was given
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


## Round 44 — the bot scavenges, watches itself and goes wide (owner: "In your caveats you said two characters got stuck in 15. What kind of stuck… test this again, and this time I want the bots to scavenge too. This needs to be a complete test to check for balance and errors/problems. This way we divide and conquer. You check for hard fact and I check for feel")

### What "stuck on floor 15" was — and a correction to round 43

Two round-43 characters ended `stuck` on floor 15. I explained one of them wrongly and did not diagnose the other; **both were the same thing, a game bug and a bot gap together.**
Floor 15 is a merchant floor (the lift, x 1029.5) *and* a maintenance floor (the staff door, x 929); their [interact] reaches overlap for a few pixels (x ≈ 955–990). The bot walks to the lift and presses [interact] the moment the
merchant's prompt shows — inside the overlap — and that ONE press was answered twice: the shop opened *and* the maintenance door walked the player into the staff room. The bot knew nothing of maintenance rooms and stood in there until its
150 s floor clock ran out. (`fighter_110` was **not** "a stair enemy holding the crossing", as this document said above; `runner_107` was the same floor-15 press.) Traced in the engine at t = 20.9 s: the player at x = 963 had both
`MaintenanceDoor.player_nearby` and `Merchant.player_nearby` true, the press landed, the scene became `maintenance.tscn`. **Fixed in the game**: where two reaches overlap the nearer thing answers (`door.gd _other_is_nearer`,
`merchant.gd`; `tests/floor15_test.tscn`). The same overlap exists on every other maintenance floor with the powered lift's `[E] Ride` — fixed the same way (`building_floors.lift_answers_press`).

### What was built

* `tools/bot_loot.gd` — **the looter**. Owns no input of its own: it asks the bot to walk / tap / switch stance, so one set of keys is held. It walks the corridor's doors (nearest first), opens / forces / unlocks them (best melee tool + X; a key
  opens its door; a barricade is torn off board by board), goes in, searches every node through the game's own path (`auto_stance_for_anchor` → `try_interact` → the loot panel), **takes or leaves by worth** (money / scrap / wallet always, a key,
  a gun if it has none, a weapon by the swings it adds, health by what the bag already holds…), **puts the least valuable thing down** when the bag is full, picks up what the dead drop, steps up to set-back furniture the way a click does, leaves,
  and goes on. In maintenance rooms it fits fuses and sits at the workbench (salvages, raises the best weapons as far as the scrap and rules go and records *why* a level was refused, spends tuning points). At the merchant it sells the surplus
  and buys what the kit is short of. Between fights it reloads, mends with a toolbox, throws a Molotov. It fights a resident who has turned on it, leaves one that has only warned it, and steps onto a door a survivor is standing near.
  Policies: `--loot=none` (the round-43 bot), `need` (loot while the bag is short of swings / healing / rounds), `all` (every door), and `--avoid-breach` (never enter a breach room; sweep config `safe`).
* `tools/bot_watch.gd` — **the watcher**. (1) Hooks the engine's own error log (`OS.add_logger`): every `SCRIPT ERROR` / `ERROR` lands in the report with floor, scene, time, who owns the file (bot / game / headless renderer) and the script
  backtrace. (2) ~25 **invariants** twice a game-second: nothing in the bag that cannot be, no negative notes / scrap, health 0–5, stamina in range, floor 0–30, the corridor on screen is the floor the counter says, the player on the plane, no stuck
  pause / fade / loot panel, drops lying where a player can stand, no enemy flood, the **cast of three never changing**, and a **progress watchdog** ("nothing changed for 30 s", with the player's full state and a 240-frame trace).
  (3) Every third floor it **saves and loads and compares ~35 fields**. `ENTER_EXIT_LOOP` catches a flat the game keeps putting the player out of.
* `tools/bot_sweep.py` — seeds × configurations, several at a time, each with its **own `user://`** (`XDG_DATA_HOME`); resumable. `tools/bot_summary.py` — the tables: depth and reach, scavenging (flats, time, hits and kills per flat, by door
  state; what the nodes held and why it was left; finds per flat), the economy (scrap, notes, bench, shop), **coverage** (what was exercised and what never was), **anomalies by kind** and the **engine log**.
* Configs: `none` (briefed kit only, crowbar liberty — the round-43 bot), `need`, `all`, `safe`, and the coverage runs `god` (cannot be hurt; walks the whole building, rides the lift, rests, goes over balconies; 3 fuses and 300 notes as
  gifts so the fuse box, lift and shop get exercised) with `god2` / `god3` starting the 2nd / 3rd character from floor 24 (the decayed building without a three-hour descent). Gifts (`--scrap --fuses --notes --power --unarmed`) change the
  balance and are never used for a balance number.

### What running it found in the game (12 fixes, each with a regression test that fails without it)

| # | what a player would have met | cause | locked by |
|---|---|---|---|
| 1 | a node you searched but did not empty (the item left on the shelf) went dark and could never be searched again when you re-entered the flat, in the same run or a later one | `room.gd` rebuilt it with `set_script`, which does not start `_process`, and skipped `set_process(true)` for every node with a "searched" record | `revisit_test` |
| 2 | the three characters re-dealt after a rest / a pry (a different cast mid-playthrough) | `shift_building()` re-rolls `master_seed`, and the cast was keyed on it → `WorldState.cast_seed`, locked at the first shift | `run_arc_test` |
| 3 | one press at floor 15's lift opened the shop **and** walked you into the staff room (the "stuck" above) | merchant door and maintenance door both answered one [interact] → the nearer answers | `floor15_test` |
| 4 | a dropped item tossed toward an end wall came to rest beyond it (x 64 / 1279), out of reach | `world_drop` toss ignored the walls → stops at them (`WALL_GAP`) | `drop_physics_test` |
| 5 | (headless) the balcony descent never finished | `BalconyPan` awaited `RenderingServer.frame_post_draw`, which never fires without a renderer | `balcony_test` |
| 6 | the same double answer on every other maintenance floor: [E] Ride boarded the lift while the staff door walked you in | powered lift vs maintenance door → nearer answers | `floor15_test._test_powered_lift_overlap` |
| 7 | standing in front of a door a defender guards, [E] gave a greeting over and over and the door never opened | a survivor's `[Talk]` claimed the press even when the door was nearer | `survivor_ai_test._test_talk_claim` |
| 8 | **pinned for good between a zombie and nothing**: the anti-stuck net never phased a body that had re-solidified itself | the zombie takes the player's collision exception off itself (`_try_resolidify`); the net believed it was still phased and never added it again → now re-adds every stuck frame | `softlock_test` (two checks) |
| 9 | **a breach flat you could not enter**: the player came in and was walked straight back out of the front door, every time | a crawler nest spawned over the arrival point; the physics server still held its *spawn* position for the first step, so the player's first `move_and_slide` depenetrated 43 px into the exit trigger → bodies are now spawned clear of the arrival point | `breach_test._test_arrival_clear` |
| 10 | **the third character's escape ended on a black screen**: the end screen sat behind the cover for good | `lobby_exit` awaited `get_tree()` after `change_scene_to_file` (Godot 4.6 swaps at once; the node is already out of the tree) → script error, `Transition.reveal()` never ran → the swap-and-reveal now lives in the `Transition` autoload | `run_bookends_test._test_final_escape_ends_on_the_end_screen` |
| 11 | (my own regression, caught by the sweep) an error line per physics frame while a freed zombie lingered in the player's exception list | a first version of fix 8 asked `get_collision_exceptions()`, which resolves every RID, freed ones included | `softlock_test._test_freed_phased_body_is_quiet` (installs a `Logger`; the gate only scans for SCRIPT ERROR) |
| 12 | a character carrying a max-stamina drawback (Pack Mule −25 %, Glass Cannon −30 %, Loadbearer −20 %) began runs 2/3 with the bar over-full: 100 of 75 until the first drain | `new_game` / `advance_run` reset stamina to a flat 100 before the upgrades fold in → `stamina = get_max_stamina()` after the resets | `run_arc_test._test_stamina_starts_full` |

Fix 11 is worth a sentence: the full gate passed on the version that introduced it, because nothing in the suites left a freed body in the player's exception list *and* a phased neighbour. The sweep's engine-log capture found
it in the first 40 s of the first run. That is the case for the watcher.

### The sweep (hard facts)

48 playthroughs = 144 characters: 12 seeds (424242, 101–111) × four policies, each playing all three characters (`--keep-going`). **No character reached the lobby. No engine error or script error in any of the 48 logs** (the one
class the watcher did catch is fix 11 above, found and fixed before this sweep). Raw tables: `docs/bot_runs/round44_sweep.md`; per-character JSON/logs are in the scratch folder only (regenerate with the commands below).

| policy | what it is | deepest floor, median (run 1 / 2 / 3) | median time alive (s) | stage-hits taken per character | flats entered per character | died inside a flat / staff room |
|---|---|---|---|---|---|---|
| `none` | the briefed kit only, crowbar handed over (the round-43 bot, re-run) | **18 / 20 / 20** | 167 / 132 / 138 | 11.0 | 0 | 0 of 36 |
| `safe` | scavenge while the kit is short; **never enter a breach room** | **22 / 26 / 25** | 1157 / 637 / 469 | 16.2 | 13.4 | 7 of 36 |
| `need` | scavenge while the kit is short (breach rooms allowed when healthy) | 27 / 26 / 27 | 394 / 487 / 428 | 13.6 | 8.5 | 13 of 36 |
| `all` | scavenge every door | 26 / 26 / 27 | 486 / 693 / 458 | 14.2 | 10.4 | 14 of 36 |

(The round-43 numbers reproduce: `none` runs 1/2/3 median 18 / 20 / 20, 25+ floors for 34 of 36, none past floor 11 below. Lower floor = deeper.)

**What the numbers say**

1. **Scavenging does not buy depth for this bot — it costs it, and one rule explains most of it.** `need` / `all` die on floors 29–24 (median 26–27) because they spend the character in the first flats: ~8–10 flats and 6–8 minutes
   against `none`'s 2.5 minutes of straight dive. `safe` is `need` with ONE rule changed (skip breach rooms) and goes **five floors deeper in run 1 and lives three times as long** (median 1157 s vs 394 s).
2. **A breach room costs ~10× the health of any other flat and pays no more.** Breached flats: **4.4–4.7 stage-hits and 3.8–4.4 kills per flat** (all four policies' data: 27 + 28 flats); every other flat: **0.45–0.60 hits, 1.4–1.5 kills**.
   Items shown per flat: 2.5–3.1 in a breach room vs 3.3–3.5 elsewhere. Breach rooms are ~8% of the flats entered and **~45–55% of all the damage taken inside flats**. (The reward that is meant to justify them — the leader's key, and the gun
   cabinet's key — the bot never used: 2 keys used on their doors in 48 playthroughs.) A human who skips them is the `safe` row.
3. **Outside breach rooms scavenging is roughly health-neutral and pays in kit.** A flat costs ~0.5 stage-hits and returns ~0.3 healing items (~0.45 stages) plus **0.8–0.9 weapons, 0.2–0.3 scrap bags, ~0.2 cash, 0.06–0.10 crowbars,
   0.09 fuses** (per flat entered, floors 29–23, run 1–3 mixed). The health budget is not the constraint it was in round 43; the clock and the bag are.
4. **The bag is the binding constraint.** Of the items shown on nodes, **64–71% were left because the bag was full** (`need` 734 of 1038, `all` 909 of 1320, `safe` 1113 of 1745), against 64–160 "not worth a slot" and 16–47 "did not fit" (an ammo bundle must
   fit WHOLLY, so a 6-round stack with 2 free refuses a bundle of 4 and the node keeps it). Five slots, two hammers, a gun, two kits: every found hammer, bat, knife or kit competes with them. Pack Mule and Deep Pockets are the upgrades that move this;
   the bot almost never reached a merchant (floor 25: 13 / 14 / 19 of 36 characters in `need` / `all` / `safe`, 35 in `none`; floor 20: 0 / 0 / 7 / 27; floor 15: 0 / 0 / 0 / 3).
5. **Later characters find less, not more danger.** Per flat entered, run 1 → 2 → 3: nodes opened 6.0 → 5.4 → 2.9, items shown 4.2 → 3.5 → 2.6, seconds inside 63 → 56 → 22, hits 0.59 → 0.62 → 0.34 (`safe`). The persistent loot depletion means a later
   character walks into half-emptied flats on the top floors — they get through them quickly and safely and find little. Whether that is wanted (the building running dry) is the owner's call; it is also why run 2/3 characters of `safe` die at 25–26
   with a kit that grew less than run 1's.
6. **The dive policy (`none`) is still the deepest** because nothing in it spends health on anything but the next staircase: 11.0 stage-hits, dead by floor ~18–20, 1.4 barricades a character (51 in 36 characters) and **14 of 36 died within three floors
   below a barricade**. The scavenging policies meet 0.2–0.5 per character (they die above them): crowbars were 0.06–0.10 per flat, so the first barricade (~floor 21–29) is again the wall for anyone who gets that far.
7. **Where the hits come from.** Stage-hits by source over the 144 characters (the bot files a hit under the nearest dead within 120 px, else `fire` if the player stands in a burning cell, else the nearest dead within 400 px by what it was doing):
   standard zombies 181 / 212 / 222 / 272 (`none` / `need` / `all` / `safe`), **fire 85 / 170 / 175 / 194**, crawlers 47 / 23 / 30 / 32, then spitters (spit from range, 15–25 as `far:spitter:attack`, plus 11–22 up close), bigs, bosses, long-arms.
   **Fire is the second-largest source: 21 % of the hits in the dive, 31–35 % with scavenging (4.7–5.4 stage-hits per character against 2.4 in the dive)** — a looting character spends minutes inside flats, and the bot makes no effort to
   walk round an apartment fire (a human would; in the corridor it sprints through, which the game lets you do unburned). 20–27 of 36 deaths had a standard zombie within 400 px; **5 / 10 / 13 deaths had nothing near** (`all` / `need` / `safe`):
   the dying countdown running out on a character whose last first aid was already spent — the damage was done earlier, the death is the timer.
8. **Merchants.** `safe` reached the floor-25 merchant in 19 characters and floor 20 in 7: 18 upgrade picks, 5 purchases (160 notes), 0 sales; the bag-full rule stopped most buys. `none` reached 25 in 35 and 20 in 27.
9. **Workbench:** 18 upgrades and 19 tunings in `safe`, 33 items salvaged; the commonest refusal was "Needs 50 scrap (you have…)" (22) — the first upgrade level costs 50 and a character earns a median of ~28 by death; "Needs a spare Lv1 bat/Gun" (17) is the other —
   the feed-a-spare rule is the real gate. The characters die long before the economy tool (`tools/economy_report.tscn`'s ~200 scrap a character) matters.

**Anomalies the sweep logged (and what they were)**

| kind | n | what it was |
|---|---|---|
| `TAKE_NO_EFFECT` | 3 of 947 takes (224 `need`, 283 `all`, 440 `safe`) | 2 were a **second key** for a door whose key the bag already held (the game accepts it silently, `add_key_to_inventory`; fixed in the bot's accounting), 1 a take of bandages (006) with a free slot that changed nothing — **not explained**; every other take verified |
| `NO_PROGRESS` / `DOOR_TIMEOUT` / `ANCHOR_UNREACHABLE` / `ROOM_LONG` | 3 stalls in 48 playthroughs | **2 not explained, 1 the bot's own.** In `need_103` (floor 26) and `safe_102` (floor 18) the player stood 30–75 s at a spot in the corridor ~140 px short of a door, `move_right` held, beside **a defender fighting zombies that never die** (survivors are performative: they blink the dead, they do not hurt them, so a fight beside a door goes on for ever). Position constant to 0.01 px, `stuck` timer 0 — the anti-stuck net never fired. A scripted copy of the scene (defender + 3 zombies, one on the player's x) walks through in 0.5 s, so it needs something else; the trace now lists every body touching the player. In `all_424242` (floor 25, flat 2501) the player stood 150 s at x≈613 with no zombie and no survivor and `sprint` held but no move key, failing to click-walk to a set-back node: **not explained**. All three cost the bot 30–150 s, none ended a character |
| `STAMINA_RANGE` | 1 | **stamina 100 of 75** at the start of a later character: `advance_run` / `new_game` reset stamina to 100 before the upgrades fold in, so a character carrying a max-stamina drawback (Pack Mule −25 %, Glass Cannon −30 %, Loadbearer −20 %) started above its maximum until the first drain. **Fixed after the sweep (fix 12)** |
| engine log | 0 | no `ERROR` / `SCRIPT ERROR` in 48 logs |

### The coverage runs (`god`: cannot be hurt, so they say nothing about balance — only whether the building works)

Six playthroughs, **8 characters, every one walked down the whole building to the lobby and out the door** (`god` = run 1 from floor 30; `god2` = runs 2 and 3; `god3` = run 3, the later ones starting from floor 24 so the decayed
building is reached without a three-hour descent; seeds 424242, 101, 102, 103 — tables in `docs/bot_runs/round44_coverage.md`). Between them: **~930 flats and 72 staff rooms entered (108-121 flats a character), ~5,400 nodes
searched, 311 shut or locked doors forced, 116 barricaded doors torn open, 190 breach rooms entered**, 19 merchant visits, the workbench used 56 upgrades / 57 tunings / 128 salvages, and the third character's escape reached
the end screen every time. **No anomaly from the watcher, no script error, and the only engine line in any log is the headless renderer's `texture_2d_get Parameter "t" is null` (×3 a playthrough, from `balcony_pan._hold_last_frame` reading a viewport
texture the dummy renderer does not provide).** Newly exercised by these runs and clean: the **fuse box** (3 fuses fitted), the **powered lift and an elevator ride**, a **key used on its door**, **the gun
reloaded from the bag**, the **burnt flats' "Take" scrap** (578 bags), **the lobby door's panel** (the leave-one-item path in `god3_102`; both paths in the 25-second checks below). Still **never** exercised in the coverage runs: something **sold** at the merchant, something **mended** with a
toolbox, a **Molotov** thrown (a god character is never hurt, so the bot has no reason to mend or throw, and it never held a surplus to sell). Counts are for what the bot did, not what a player might; a god character never dies, so
the dying flow, corpse recovery and the death card are NOT in these runs (the sweep's 144 deaths cover them).

**One more finding, and it was the bot's, not the game's:** `god3_102` sat paused at the lobby door for ever (the watcher's `PAUSE_STUCK`). When the kit holds an upgraded weapon, `lobby_exit.leave()` opens the door panel
(`handoff_ui.gd`: leave ONE item for a future game, or scrap the kit for Valour) and **pauses until it is answered**; the bot never answered it, and the watcher did not know the panel as a reason for a pause. A person can always
answer (the panel has a "scrap it all" button, Esc / ✕ mean the same), so this is not a softlock. The bot now answers within 1.5 s — the 1st and 3rd character leave their best candidate, the 2nd scraps, so a sweep runs both
paths (`DOOR` events; a `--heirloom` gift makes the first hammer Lv3 for a 25-second check of the door) — and the watcher raises `DOOR_PANEL_OPEN` if it is ever left up 20 s. Checked: Lv3 hammer left by the door on run 3 and
the end screen reached; kit scrapped on run 2 and the run closed. The earlier god runs (seed 424242, and `god3_101`) passed the door without the panel ever opening — it only opens when the kit holds an upgraded weapon, and a stuck panel would have stopped them — so their kits held none.

### Round 44b — can the progression tiers carry the bot to the lobby? (the ceiling experiment)

Asked: "can players beat this game, even with multiple runs, upgraded weapons carrying over and permanent boons?" The bot cannot play a session-after-session grind, so the question was put the other way round: **give it the
whole permanent tier up front and see how far it moves.** New flags `--perm=ID,...` (permanent Valour-shop perks, on for all three characters) and `--hammer-level=N` (the first hammer arrives levelled, first perk of each tree step);
sweep configs `none_m3` (Strong Arm + Field Medic + Second Wind, 625 Valour), `none_m10` (the ten-perk collection, 3,125 Valour: Strong Arm, Crushing Blows, Field Medic, Second Wind, Marathoner, Iron Lungs, Deep Pockets,
Sprinter's Legs, Ghost, Featherfoot), `none_m10h` (+ a Lv4 hammer), `safe_m10h`. Same 12 seeds as the main sweep, paired by seed and run. **An OPTIMISTIC bound** — every character gets everything from floor 30, which no real
route to those perks allows. Tables: `docs/bot_runs/round44_meta.md`.

| config (12 seeds × 3 characters) | deepest floor, median run 1 / 2 / 3 | best character | paired Δ vs the baseline (floors deeper; 95% CI) |
|---|---|---|---|
| `none` — baseline | 17.5 / 20 / 20 | floor 11 | — |
| + 3 perks | 17 / 17 / 21 | floor 10 | +0.4 [−1.0, +1.8] |
| + 10 perks | 16.5 / 17.5 / 20 | floor 7 | +1.0 [−0.7, +2.7] |
| + 10 perks + Lv4 hammer | 18 / 20 / 19.5 | floor 11 | −0.3 [−2.0, +1.3] |
| `safe` — baseline | 22.5 / 26 / 25 | floor 16 | — |
| `safe` + 10 perks + Lv4 hammer | 20 / 25 / 24.5 | floor 10 | +1.2 [−0.2, +2.6] |

**Maxed permanent perks and a levelled weapon move the bot by about one floor, which is inside the noise; no character reached the lobby; the deepest of 144 was floor 7.** The perks work (early stamina 138 vs 84 — checked in the
logs); they simply do not touch what limits the run. **What does:** (1) **kill capacity.** The briefed kit is two 10-use hammers and 8 rounds: the dive bot makes 19.5 swings + 8 shots for 20.3 kills a character (1.36 actions a
kill) — it kills in about one swing already, so +damage has nothing to improve — and a full descent holds a median **88 corridor dead** (67–128 over 12 seeds, per `get_floor_zombie_count`, before stair enemies, bosses and the
flats). (2) **Unarmed, the hit rate triples:** 0.77 stage-hits a floor while a weapon works, 2.34 once every hammer is broken and the gun is empty; 19 of 36 dive characters died on a floor they entered unarmed; the median
floor the weapons ran out on is 19, which is where `none` dies. No permanent perk adds durability, swings, rounds or weapon finds (Tinkerer is scrap, not weapons). **(3) The permanent tier is priced in depth the bot does not
reach.** Valour per game (`d + ⌊d²/60⌋`, +10 escaped, summed over three characters), from the sweep's own deaths: `none` 38.8, `safe` 19.1, `need` 10.6, `all` 11.5 — the ten-perk set (3,125) is **80 games** at `none`'s rate,
164 at `safe`'s, ~290 at `need`/`all`'s; the first 150-Valour perk 4-14 games. Reaching the lobby pays ~165 a game (19 games for the set). **Valour pays for depth only, so the scavenging policies earn a third to a half of
what the dive earns** — the economy that is meant to reward looting pays more for not looting. The heirloom / door-stash tier needs an escape first (1/2/3 lobby-door crossings), so it cannot help anyone who has not already won.
Caveats: one bot policy, melee-first; the hammer tree is a placeholder; a human uses stealth, thrown cans, Molotovs, corpse recovery (the bot does none of these), so the human ceiling is unknown — see the report.

### Open (found, not fixed — the owner's call or not yet understood)

1. **The unexplained pin beside a defender's fight** (above). If it is real it is a softlock-class bug; the next sweep's `[stall]` trace should show what the player is pressed against.
2. **Survivors' fights never end.** A performative defender and the zombies engaged with it blink at each other for ever, in the middle of a corridor, on top of a door the player wants. The player can (and a human would) kill the zombie; the bot treats it as
   "not coming for me" until it blocks. Worth a look if a defender is meant to hold a door open rather than ornament it.
3. **Breach rooms: ~10× the cost of a normal flat for no extra loot** (above) — a balance decision, not a bug. The bot's `safe` policy is the evidence for "skip them", which may or may not be what the owner wants players to learn.
4. **A second key for a door the bag already holds** is accepted silently and the node is emptied (the duplicate node is wasted, nothing is lost); two nodes holding the same key target is a seeding quirk.
5. **Bullets: an all-or-nothing bundle** leaves a 6-round stack unable to take a 4-round pile; the pile stays where it lies (by rule 5, nothing is destroyed). A human sees "Inventory full".

### What the bot does NOT cover (so a green sweep is not "everything works")

* **Listening** (R at doors / stairwells), **talking** to survivors and quests (010 Johnny, 001 Ethel, the personal quests), **crafting** (Molotov / rope), **cans and the extinguisher against fire**, the **banister jump**, the **backpack ring**
  and every UI that needs a pointer; the **real save file → quit → Continue** flow (the watcher round-trips `save_game` / `load_game` and compares ~35 fields, but never restarts the scene); the **tutorial** and the packless / story rules (a sweep
  plays `new_game` with them off); **gamepad and touch**; **look and sound** (a headless run draws nothing).
* It reads the game's state directly for what a player would see (zombies within a screen, the stairwell side), and it never mis-clicks or hesitates. A human is slower and more careful in some places (avoids a breach room) and worse in others.
* Speed 8 distorts real-time-driven code (`Time.get_ticks_msec` guards, the attack buffer); runs of one seed differ a little from run to run, and the sweep runs several godots at once. Compare configs, not single runs.
* The sweep's bot rules are mine (`worth()`, `door_blocker()`, `_fight`); a different policy goes a different depth. `need` / `all` / `safe` bracket scavenging, they do not bound it.

### How to run it

```
python3 tools/bot_sweep.py <outdir> --seeds 424242,101,102 --configs none,need,all,safe [--jobs 3] [--timeout 5400]   # resumable; each run gets its own user://
python3 tools/bot_sweep.py <outdir> --seeds 424242 --configs god,god2,god3 --jobs 1 --timeout 14400                    # coverage runs (hours of game time)
python3 tools/bot_summary.py <outdir>                                                                                # the tables below
godot --headless res://tools/bot_run.tscn -- --seed=424242 --speed=8 --runs=3 --keep-going --loot=need [--avoid-breach] [--god] [--trace] --out=/tmp/bot.md
```
Flags: `--loot=none|need|all`, `--avoid-breach`, `--god`, `--elevator`, `--rest`, `--balcony`, `--start-run=N --start-floor=N`, `--apt=ID,ID` (loot only these flats), `--trace`, and the gifts `--scrap --fuses --notes --power --unarmed --heirloom` (the first hammer is Lv3, so the lobby door has something to offer).
Output per run: `<name>.md` (the report), `.json` (everything, for the summary), `.log` (the run + the engine log). The summary's `anomalies` table is the thing to read first; `[stall]` lines in a log are the per-frame trace of a stall.

## Round 45 — the same sweep after the owner's floor-29 playtest (36 playthroughs, tables in `docs/bot_runs/round45_sweep.md`)
Same bot, same 12 seeds, policies `none` / `need` / `safe`. The changes under test: no breach rooms above floor 24 (and packs 30% smaller, at the far end), loot by depth
(`WorldState` "LOOT BY DEPTH"), one gun cabinet a floor at most. **Zero engine findings in 36 logs.** Depth did not move within the noise (`need` medians 27/26/28 → 25/28/26, `safe`
22/26/25 → 24/25/26); what moved is what a flat costs and pays: breach flats entered 27 → 2, stage-hits per flat in run 1 1.48 → 0.51, **weapons found per flat 0.86 → 0.25**, fuses 0.10 → 0.02,
crowbars unchanged. The bot still dies in the corridors of floors 25-29, so its binding limit is still kill capacity (round 44b), not loot or breach rooms. Dial if the top feels sparse: `LOOT_GEAR_TOP`.
