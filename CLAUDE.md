# Descend From 30

2D side-scrolling roguelike in **Godot 4.6** (GL Compatibility). Player
descends a 30-floor apartment building during a zombie outbreak, scavenging
and fighting floor by floor. One full session = three character runs
(morning / afternoon / night) over a persistently decaying building.

## Design docs — READ THESE FIRST for any feature work

All agreed design lives in `docs/` (converted from the owner's Word/Excel
originals — the markdown here is canonical for development):

- `docs/GAME_DESIGN_DOC.md` — core loop, tutorial (Floor 30), player/world
  systems, door states, listen system. Oldest doc; some parts superseded
  (noted inline).
- `docs/THREE_RUN_ARC.md` — three-run structure, time skips, escalation,
  fires, balcony descent, fresh-character state. Agreed, pre-implementation.
- `docs/STORE_DESIGN.md` — **FINAL v3**: bank notes, wallet, merchant, shop
  rotation, free pick-1-of-2 upgrades, corpse recovery, implementation order.
- `docs/QUEST_LIST.md` — quests 001–011 with outcomes/rewards.
- `docs/ITEMS_SHEET.md` — item catalog + room spawn pools (design reference;
  **`data/Items.json` is the runtime source of truth**).
- `docs/SOUND_STEALTH.md` — noise model (under the hood) + anchored R-listen
  at doors/stairwells. Agreed + implemented v1; roaming TLOU-style listen
  deliberately dropped.
- `docs/STAIR_BARRICADES.md` — stairwell **barricades** + the Crowbar (035):
  passable-but-costly crossings (crowbar pry, both directions, building shift +
  rest-slot cost), arrival mustering, the narrow cross-floor noise pull, the F2
  hazard cycle (barricade built; horde/fire placeholders), and barricade-keeper
  NPC groundwork. v1 implemented. (Terminology: barricade = debris block pried
  with a crowbar; horde = future live-enemy block; fire = future.)

When docs conflict: STORE_DESIGN.md and THREE_RUN_ARC.md supersede the GDD
(each notes what it overrides). Keep the docs updated when a design decision
changes — they are the cross-session memory for this project.

## Project layout

- `project.godot` — autoloads: `WorldState`, `ItemData`, `Game`, `HUD`,
  `SettingsManager`, `PauseMenu` (pause menu is an autoload, NOT embedded in
  each scene — keeps world scenes editable in the 2D editor)
- `scripts/` — all GDScript. Key files:
  - `world_state.gd` — the big one: master seed, per-floor/apartment
    generation seeds, door states, inventory, wallet, upgrades, corpses,
    save/load. Almost every system hangs off this autoload.
  - `player.gd` — movement, sprint/stamina, combat, push
  - `room.gd`, `hallway.gd`, `building_floors.gd`, `lobby.gd` — world scenes
  - `enemy_zombie_standard.gd`, `enemy_zombie_big.gd` — enemies
  - `loot_ui.gd`, `hud.gd`, `pause_menu.gd` — UI
- `scenes/` — `.tscn` files; `scenes/Room_Modules/` holds modular apartment
  rooms (bedroom, kitchen, bathroom, study, living_room, dining_room) plus
  fixed `Tutorial/` layouts for Floor 30 run 1
- `data/Items.json` — runtime item definitions (`ITEMS`) + per-room spawn
  weights (`ROOM_SPAWN_POOLS`)
- `assets/` — sprites, tilesets, fonts

## Reporting rules (do not violate)

These exist because both were broken, repeatedly, and each cost the owner a
playtest round.

1. **Never claim something is unchanged without diffing it in the same turn.**
   "X is untouched", "this doesn't affect Y", "nothing else moved" — each is a
   claim about the code, not about intent, and must be backed by a diff or a
   value comparison printed in that turn. A change made as a *consequence* of
   another change is still a change; believing it to be behaviour-preserving is
   not the same as it being so. If it hasn't been checked, say "I haven't
   checked X" — that is useful, a confident guess is not.

2. **If a fix requires touching something the owner has frozen, say so BEFORE
   doing it.** When told "don't change X" and the fix needs X changed, stop and
   explain the conflict. Do not make the edit quietly on the grounds that it
   looks inert — that judgement is exactly what fails.

Related: when one constant is read by two features, splitting it into two named
constants beats keeping them in sync by hand (see `DOWN_*` / `UP_*` in
`stair_pan.gd`).

## Hard-won conventions (do not violate)

- **Save/load JSON: string keys only.** Godot's JSON round-trips int dict
  keys as strings; int-keyed dicts silently break on load. Always key
  persisted dicts by `str(...)`.
- **Deterministic seeding:** world generation derives from
  `hash(str(master_seed) + <purpose> + <floor/apartment> + str(current_run))`.
  New procedural systems must follow this pattern so runs are reproducible
  and re-entry is stable.
- **Stat upgrades = modifier lists, never direct writes** to stats like
  `max_stamina` (see STORE_DESIGN.md implementation order, step 6).
- **Balcony column continuity** is a generation-order constraint that must be
  respected by any new room-seeding code (see THREE_RUN_ARC.md).
- **Persistence split:** cross-run state (upgrades, wallet unlock, world
  decay, corpses) vs per-run state (inventory, wallet balance, health).
  Put new state in the right block.
- **Render layers:** the corridor backdrop (walls, static doors, the
  merchant's elevator doors, any future dynamic door art) lives at
  `z_index 0`; **actors (player + enemies) sit at `z_index 1`** (set in each
  `_ready`). New door/entrance visuals must stay at z 0 so bodies never clip
  behind them. Corpses/world-drops stay at z 0 too (on the floor).

## Testing / verification

Headless Godot is available in cloud sessions (installed by the environment
setup script; binary from downloads.godotengine.org). Before every commit:

- `godot --headless --import` — catches broken scenes, bad UIDs, missing
  resources. Run it after adding new scenes/scripts so their UIDs register.
- `godot --headless res://tests/merchant_smoke_test.tscn` — merchant/shop
  regression suite; exit 0 = all passed. Runs with full autoloads, so it
  exercises real WorldState/ItemData/HUD code paths.
- `godot --headless res://tests/gun_combat_test.tscn` — ammo stacking
  (8/slot), consumption, gun animations, noise alerts.
- `godot --headless res://tests/listen_noise_test.tscn` — noise radii,
  emit_noise gating, listen categories/reports, overlay states.
- Other suites: `gun_combat_test`, `can_throw_test`, `settings_test`,
  `repair_test`, `audio_smoke_test`, `tutorial_test`, `click_move_test`,
  `depth_move_test`, `transition_test`, `force_lock_test`, `loot_test`,
  `building_floors_test`, `stair_visuals_test`, `profile_test`,
  `profile_ui_test`, `title_test`, `enemy_memory_test`, `floor_adopt_test`,
  `balcony_test`, `hud_prompt_test`, `stair_block_test`, `fire_test` — run all
  24 before commit. (`floor_adopt_test` is seed-sensitive: `new_game` rolls a random
  master seed and it asserts a floor has zombies, so it fails ~occasionally
  on a 0-zombie seed — a known flake, re-run it.)

Note: `tutorial_test` asserts first-run tutorial content, so it needs
`is_first_run` true — which comes from `tutorial_completed=false` in the active
profile (`user://…profile.cfg`). A profile left with the tutorial completed
makes that flag false and the tutorial apartments seed procedurally, failing the
spec asserts. Reset the flag (or the profile) if the tutorial suite starts
failing on procedural content.

Add a test scene under `tests/` for each new system (copy the pattern:
plain Node + script with `check()` asserts, quit(1) on failure). Headless
means no rendering — UI layout and art still need an in-editor look.

## Current status (update as work lands)

- Built: floors/traversal, procedural apartments, doors (open/locked/weak/
  barricaded), combat (melee/push/gun with stacking ammo + noise alerts),
  inventory (5 + locked 6th slot), loot,
  HUD, save/pause, breach rooms + boss, world drops, enemy corpses,
  Bank Notes + Wallet (store doc steps 1–2), `current_run` seeding,
  Merchant NPC + seeded shop with Legendary hold + buy flow (steps 3–5;
  merchant lives inside the elevator behind sliding doors that open on
  approach; body reuses the player idle sheet — merchant art task open),
  sound & stealth v1 (noise radii per gait, emit_noise, R-listen at
  doors/down-stairwells with grey vignette + pings + report, listen
  ambush; Rest moved to T), audio v1 (CC0 Kenney footsteps/impacts +
  synth moans/gunshot/heartbeat/music in assets/audio/ — see its
  LICENSE.md), playtest round 1 fixes (gun magazine 18/10-damaged with
  reload-on-use, rarer headshots, damaged-gun accuracy + toolbox repair,
  merchant SELL (3/visit), gun→bullet loot pairing + ammo bundles,
  click-to-move / click-to-scavenge with auto-stance, barricade
  interrupt fix, melee SFX, elevator ding, +5% scavenge rates).
- Playtest round 2: fixed HUD root Control swallowing world clicks (left-
  click-to-move now works), drag-and-drop inventory (reorder / swap / drag
  bullets onto gun to load / drag to world to discard), 4 moan variants +
  per-zombie voice pitch + louder mix, room click-to-scavenge reachable
  when no anchor in range.
- Can throwing (item 17): scavenge-mode use of Canned Food throws a can —
  a real `RigidBody2D` (collision_mask layer 1) that arcs, spins, and
  BOUNCES off floor + walls, rolling to a stop with a thud on each impact;
  its landing emits a loud noise + distraction that pulls every non-boss
  zombie to the sound (some de-aggro on arrival, some resume). Bosses
  ignore it. **This is the reusable physics-object pattern** — future gibs/
  enemy-head props confined by walls should copy the can's RigidBody +
  layer-1 mask + PhysicsMaterial setup.
- Upgrades (store step 6): ~30 weighted upgrades (boons + drawbacks) via a
  modifier-fold architecture (base × ∏mult + Σadd, never direct writes);
  Hades-style pick-1-of-2 on the UPGRADES tab before the shop, one-confirm
  refusal, no-duplicate offers, seeded pairs, persists across the arc.
  Effects wired to stamina/regen/sprint/speed/melee/push/gun accuracy+mag/
  listen/heal/scavenge/noise/inventory-slot (unlocks the 6th HUD slot).
- Settings menu (from pause): rebind any key or mouse button (incl. mouse
  side buttons 4/5) via SettingsManager autoload, saved to
  user://keybinds.cfg, applied on load. Combat attack is now a rebindable
  `attack` action (default LMB); rebinding it off LMB frees left-click for
  click-to-move in combat too.
- Broken-item repair (item 12): weapons/tools that deplete now STAY in
  inventory as a "BROKEN" repairable item (greyed + red tag) instead of
  vanishing; broken items can't attack/force/de-barricade. The toolbox
  repairs the first repairable item (damaged gun prioritised, else broken
  weapon/tool), restoring durability; the toolbox is consumed when its
  charges run out. (Crafting-combine of broken parts is still future.)
- Floor 30 scripted tutorial v1 (first run only — see docs/TUTORIAL.md):
  new `TutorialManager` autoload drives player-speech dialogue prompts
  (`HUD.show_dialogue`) and gameplay-PAUSE teaching beats (freeze → "press
  a key" → resume-into-callback). The 3003 encounter is a poll-driven state
  machine in `room.gd` (`_tutorial_process`): neighbour spawns at the BACK,
  frozen; approach → curiosity line + slow release; first lunge → pause →
  **push** intro (scripted long stagger); pause → "find a weapon" → the three
  hidden nodes reveal (junk / bandages / golf club) + auto scavenge mode;
  slow approach paced for sequential searching; club pickup → pause → combat
  (mode+equip auto) with **deterministic 2-hit, no-RNG** death; neighbour
  **drops the 3002 key** on death; pause → heal prompt. Golf club spawns at
  **low durability (4)**. Stairwell descent is **gated + herds** the player
  back until the 3003 zombie is cleared (`stairwell.gd` + `killed_zombies`
  milestone). **DEV F7** toggles the tutorial on/off and drops into a fresh
  Floor 30 for playtesting. **v2 built**: 3004 barricade rips throw sharp
  ORANGE jagged noise pings (`listen_overlay.noise_ping` — reusable "you're
  loud" cue) + corridor zombie walks in from the left stairs, HOLDS at a
  distance (`tutorial_hold_x`) until the barricade falls, then pause-prompt
  choice (force 3004's lock for the room vs kill it and break the club) and
  slow release; stairs gate is STAGED (key → apts → choice → open) with
  per-stage lines + herding to the next objective door; 3002 = conservative
  reward room (cash/ice pack/first aid only) with the earliest descent line;
  3003 kill line = the key realization. Tutorial club now **6 uses** (−2
  zombie, −2 barricade, 2 left for the choice — barricades visibly cost
  durability); a **pause beat** when first passing the barricaded 3004 hints
  it can be torn down (faster with a weapon). The force-vs-fight choice line
  now spells out the durability worry (one job left, door OR enemy), and the
  corridor zombie **drops cash** if fought — so neither path is empty-handed.
  3005 grants a **guaranteed Hammer (002)** on the first run so the player
  descends to 29 armed; all tutorial scripted drops (3002 rewards, 3005
  hammer, corridor cash) are `is_first_run`-gated (run 2+ = plain RNG).
  Dialogue/report panels are mouse-transparent (click-to-move regression,
  locked by click_move_test). Remaining: 3005 interior info; owner-authored
  final dialogue.
- Forcing a door/lock is now a **2s channeled action** game-wide (was
  instant): progress countdown, loud from the first heave, cancels on any
  other action or walking away, durability spent only on completion; a key
  still opens instantly (`door.gd`, locked by force_lock_test).
- Tutorial playtest round 3: **first-run cold-open** (`intro_overlay.gd`,
  black screen + banging → locked out → remember the 3003 key, gated by
  `WorldState.opener_seen`); **all tutorial dialogue centralised** into
  `TutorialManager.LINES` (single edit point, keys grouped by beat); forcing
  3004 now **snaps the club** with a "it broke, get inside" pause (both choice
  paths end weaponless → the 3005 hammer matters); corridor zombie **cash**
  wording; **interact-guard** so the E that dismisses a prompt no longer also
  opens the door behind it; **click-to-move regression fixed** — floating HUD
  labels (dialogue/feedback/mode/floor/wallet) were `MOUSE_FILTER_STOP` and ate
  world clicks, now IGNORE (click_move_test clicks *through* the dialogue box).
  Fade transitions (`Transition` autoload) on door enter/exit + stairs +
  lobby; **depth approach-walk** (`player.approach_door`/`knock_door` — steps
  up toward a door before the fade). Seamless stair pan: **groundwork built +
  tested** — `building_floors` takes `setup_floor`/`passive` to build any
  floor as a backdrop; `StairPan` autoload scaffolds the two-floor camera pan
  but is **DISABLED** (needs in-editor feel-tuning; stairs use the fade until
  then).
- Stairwell **barricades** + Crowbar (docs/STAIR_BARRICADES.md, v1): some
  stairwells are barricaded with debris and can't be fought — they're pried
  through with a **Crowbar (035)** (new `is_tool, is_crowbar` item, single-use/
  consumed), and block **both directions** until cleared. The pry is a channeled
  action (~6s, loud from the first heave, so the current floor's dead converge
  on the steps); completing it spends the crowbar, opens the stairwell for the
  run, and triggers the **same building shift a rest does WITHOUT the heal**
  (`WorldState.shift_building`), at the cost of **one rest slot** (a banked rest
  is burned, else the next merchant-floor rest is forfeited via
  `rest_forfeit_pending`). The crossing is the **anti-rest**: it also drains
  stamina to an **exhausted floor** (`PRY_EXHAUST_FRACTION`, via `minf` so it
  only ever lowers), fades to black on a held time-skip caption, and lands you
  **spent** on the floor you fought toward — its dead **milling at the
  stairwell**. Separately, loud noise (gunfire/forcing) made **near a stairwell**
  pulls only the **stairwell-seeded** dead on the adjacent floor (never a
  whole-floor vacuum; running never pulls). Seeded per (floor,run); floor 30 +
  floor 1 exempt. A blocked stairwell shows a **crate-stack prop**
  (`barricade_prop.gd`) at both landings. **Hazard 2 — hordes (v1):** other
  stairwells are packed with **live zombies** (`is_stair_horde`, seeded ~15%,
  mutually exclusive with barricades) — no crowbar, you **fight or lure** them
  off (thrown can); a seeded 4–7 cluster spawns at both landings (`stair_horde`
  group, kills persist), and `stairwell.gd` blocks the crossing while any live
  zombie is within `HORDE_BLOCK_RANGE`. No shift/rest cost — the fight is the
  cost. A horde stairwell shows a **colored red echo pulse** (`horde_echo.gd`)
  and gives a **one-time approach warning** (brief freeze + player line,
  `building_floors._process` + `hazard_approach_warned`); barricades give no
  advance warning. **Hazard 3 — fire (v2):** a **spreading blaze** that spreads
  across a floor within a run AND **climbs the building across runs**. A
  deterministic (RNG-free) cellular sim `fire_field.gd` — corridor of heat/fuel
  cells; burning cells push heat to neighbours and burn out to **charred**;
  self-ticks + draws pixel flame/smoke; in the `fire_field` group. **Cross-run
  model** (`world_state.gd`): a stable per-arc set of **outbreak origins**
  (`_fire_origin_seeded`, ~12%); `fire_intensity(floor)` = worst `age - distance`
  over live origins (`age = current_run-1`), so the front creeps one floor out +
  one stage hotter per run (LIGHT→BLAZE→CHARRED). Fully extinguishing the
  **source** records it in `fire_dealt_with` (cross-run, saved) and stops the
  whole chain; dousing a spread floor (or just a safe path) doesn't count → it
  comes back worse. Barricade + horde **defer to fire** (no doubling).
  `building_floors._spawn_fire` lights a field on any fire floor; standing in
  flame costs **1 hp / 1.1s** (`_process` + `receive_hit`); when the whole floor
  goes out, `mark_fire_dealt_with` fires. Item **036 Fire Extinguisher**
  (`is_extinguisher`, 3 uses) douses a radius **for good** (`extinguish_at`) —
  one canister only blows a safe path through a big blaze (backtrack for more);
  mounted **by the elevator on EVERY floor** (skips charred) once per (floor,run)
  (`_place_elevator_kit` + `elevator_kit_placed`, saved). **Merchant** shelters
  while its floor burns (`_merchant_pending_fire`) and emerges once it's dealt
  with; left burning, it's absent on that floor across runs. Still to build:
  **smoke fill + crouch-under**, a fire approach-warning beat, and the automatic
  run-advance that drives escalation live. **F2** dev-cycles off → barricade →
  horde → fire → off.
  **Terminology:** barricade = debris block (crowbar); horde = live-enemy block
  (fight/lure); fire = spreading blaze (extinguisher). **Barricade-keeper NPC**
  quest has seeded groundwork (`barricade_has_keeper` + `barricade_keeper_state`)
  but no NPC yet. Covered by `stair_block_test` + `building_floors_test` +
  `fire_test`.
- Next: tutorial **v2** (above), then characters/profiles/stats + the
  two-&-three-run arc; also **Upgrade offers** polish and player-corpse
  recovery (store step 7); barricade-keeper NPC; fire smoke/crouch + warning beat.
- Not started: time-of-day, balcony descent, quests, character stats.
