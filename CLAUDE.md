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
- `docs/SCRAP_UPGRADES.md` — **AGREED, pre-implementation**: Scrap (a 2nd
  currency) to upgrade weapons at a maintenance-room station; charred apartments
  are the main scrap faucet → fire becomes risk/reward. Not built yet.
- `docs/MAINTENANCE_ELEVATOR.md` — **AGREED, pre-implementation**: the
  maintenance room (`maintenance.tscn`, safe room, every 3 floors, hosts the
  upgrade station + fuse box), fuses (stack 3) powering a single-use **elevator**
  that jumps 5 floors — recommended via an `elevator_interior.tscn` cut, not a
  5-floor pan. Not built yet.
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

- `docs/ART_REQUIREMENTS.md` — brief for contracting pixel artists: the cozy-horror
  tone, the critical conventions (one feet-baseline, author FLAT so the engine's dynamic
  lighting works, face-right + flip), the full asset list by priority, the sectional
  decay bands, and deliverable/naming spec. Share with any artist.
- `docs/Y_PLANES.md` — **LOCKED reference**: every world-Y plane on a corridor
  floor (the feet line 419, spawn/stand origins, stair triggers, staircase art
  boxes, the player stair-transition slice constants, the stairwell-enemy geometry,
  fire planes). Read it before positioning or slicing anything on the vertical axis;
  update it in the same commit as any Y-constant change.

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

- **Y planes: measure, don't eyeball; align by FEET, not origin.** The corridor
  floor line (every actor's collision-bottom when standing) is **419**. Origins
  differ per rig (standard zombie origin 370 → feet 419; player origin ~386 → feet
  419), so aligning two rigs by origin puts the bigger one's feet low. Never guess a
  vertical position — read `docs/Y_PLANES.md`, or measure (a headless trace of
  `global_position` / collision-bottom). Don't reuse the player's stair-slice pixel
  offsets on a different-sized sprite; anchor to that rig's own feet line. Keep
  `docs/Y_PLANES.md` current with any Y change. When the owner asks to place
  something and the spot is unclear, offer the **placement grid overlay** (spec
  locked in `docs/Y_PLANES.md` §9) so they read back an exact zone/coordinate —
  never eyeball a position.

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
  `balcony_test`, `hud_prompt_test`, `stair_block_test`, `fire_test`,
  `maintenance_test`, `elevator_test`, `run_arc_test`, `enemy_variety_test`,
  `dev_menu_test`, `lighting_test`, `plane_lock_test` — run all
  31 before commit. (Run ONE godot at a time — a killed/backgrounded headless run can
  linger and block the next, and a GDScript **parse error makes a test scene load but
  never call `quit()`, so it "hangs" until timeout** rather than printing an error line;
  if a suite hangs, check for a parse error and stray `godot` processes first.
  `floor_adopt_test` is seed-sensitive: `new_game` rolls a random
  master seed and it asserts a floor has zombies, so it fails ~occasionally
  on a 0-zombie seed — a known flake, re-run it. The old `building_floors_test`
  fire-cell-count flake was fixed by widening the LIGHT "small/patchy" bound to
  1..12 cells.)

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
  up toward a door before the fade). Seamless stair pan: **ENABLED**
  (`stair_pan.gd` `ENABLED = true`) — stairs between floors 1–29 pan between two
  contiguous floors instead of a fade. `building_floors` takes `setup_floor`/`passive`
  to build the destination as a backdrop, then `go_live()` promotes it. **Gotcha**:
  the passive build skips everything after `if passive: return` in `_ready`
  (barricades, hordes, merchant), so `go_live` MUST re-spawn those — any new live-only
  floor content added to `_ready` needs a matching call in `go_live` or it'll be
  missing when you arrive by stairs (but present via the fade/apartment path).
  **Exception**: FIRE + door-fire ARE spawned in the passive build (so a floor panned
  UP toward shows its fire as it scrolls into view, not popping in after the commit);
  `go_live` only spawns fire if the backdrop didn't already (`_fire_field == null`).
  Lobby (0) and hallway (30) still use the plain fade.
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
  (`barricade_prop.gd`) at both landings. **Stairwell enemies (NOT a hazard — normal
  enemy seeding):** decoupled from the hazard system entirely. Hazards are barricades +
  fire ONLY; enemies on stairs are just part of the world's enemy population. A count per
  stairwell (`WorldState.stair_enemy_count`, weighted: mostly 0-1, occasionally 2-3 — a
  naturally tougher crossing, emergent not a mechanic), seeded per (choke, run),
  independent of barricades/fire; NOT in the F2 dev hazard cycle (a `dev_force_stair_
  enemies` bool forces them for testing). `building_floors._spawn_stair_enemies` (group
  `stair_enemy`). Each is a STANDARD zombie that spawns partway down the stairs and spawns
  at the stair **TRIGGER x** — the exact point the player itself snaps
  to when using the steps (the authoritative centre of the staircase), NOT the art
  texture centre (which is offset). **Two directions, mirroring the player's own DOWN/UP
  transition** (`_stair_up`): on a **DOWN shaft** (dark, `Hallway_Staircase_*`) it lurks
  BELOW the plane, drawn with the **PLAYER'S OWN mouth cut** (`StairPan.SHRED_SHADER`,
  `DOWN_STAIR_APPROACH` + `DOWN_SHRED_FOOT`, clip_dir +1) so only its head/shoulders show,
  and RISES up appearing head-first — the same slice the player descends through; on an
  **UP stairwell** (visible yellow steps, `Lobby_*`) the steps are VISIBLE so it's drawn
  WHOLE (no slice, just `DOWN_DEPTH_SCALE`), standing up the steps ABOVE the plane, and
  walks DOWN. (An earlier build applied the down-slice to both and sank the enemy into the
  floor with amputated feet on an up-stairwell.) **Sequence** (`_stair_tick` phase machine
  `idle → rise → stepdown → normal AI`): while idle it does **unpredictable, non-looping
  behaviour** (`_stair_idle_behaviour` — mostly pauses, occasionally shuffles a step up or
  down its small band, occasionally swipes at thin air, on random timers). When the player
  comes within `STAIR_ACTIVATE_RANGE` (tight, ~120px) or gunfire alerts it, it is ROUSED
  after a **random delay** (`STAIR_REACT_MAX` — sometimes immediate, sometimes it lingers a
  beat: the jump scare). It then **rises to `_stair_over_y`** (just ABOVE the plane, fully
  clearing the step — the DOWN cut reveals it head-first as it clears), then **steps DOWN**
  onto the plane (`stepdown`: the DOWN cut sweeps off the feet AS it steps, so nothing pops;
  it stops AT the plane, never below — mirroring the player's "up over the step, then down
  onto the floor"), and hands to **normal AI**. Pace is deliberately unhurried
  (`STAIR_RISE_SPEED` / `STAIR_STEPDOWN_SPEED`). It emerges to `STAIR_STAND_Y` (370 — the
  origin whose collision-bottom/FEET rest on the corridor floor line 419, measured equal
  for the player + normal zombies), so it lands flush with every actor with NO floor-
  collision snap when its body collision turns back on (that snap, from emerging to 388/
  feet 437, was the rubber-band). The DOWN-shaft slice cut = `STAIR_STAND_Y +
  STAIR_DOWN_CUT_DROP` (30), the one by-eye knob left. **Robustness — this
  is where earlier builds softlocked, so it's built to be impossible:** while on the
  stairs its **body collision is OFF** (`set_collision_layer_value(1,false)`), so it can
  NEVER shove or wall off the player — but it is **ALWAYS killable/pushable** (attacks are
  distance-based on the `zombie` group, not collision), and **any hit/push/can pulls it
  straight off the stairs** (`receive_damage`/`receive_push` call `_exit_stairwell_mode`)
  into ordinary AI. There is no state where it is present but unremovable. **Leaving &
  returning**: a stair enemy is never RECORDED at an off-floor y (snapped to the stand
  line on `_exit_tree` while still on the steps), and on RETURN a remembered one comes
  back GROUNDED as an ordinary floor zombie (`_spawn_stair_hordes` restore branch:
  y/base_walk_y→`STAIR_STAND_Y`, collision on, passable-until-clear) — never floating
  mid-air, solid, dragging the player (the cross-floor bug). **Disposition**: a seeded
  `stair_eager` flag varies whether it rouses at the normal range (`STAIR_ACTIVATE_RANGE`)
  or only when the player is right on it (`STAIR_ACTIVATE_RANGE_PASSIVE`) — so not every
  stairwell enemy always comes at you. It draws at
  **z 0** (behind the player) while in the shaft, z 1 once stepped off; collision is
  restored on step-off (passable-until-clear so it never jams). Kills persist
  (`stair_horde` group + per-floor key `<floor>:stairwell:<choke>`). **Pan-pop fix (no
  materialising on arrival):** a floor reached by the seamless stair PAN builds as a
  PASSIVE backdrop, so `_spawn_stair_enemies(floor_num, true)` seeds the stair enemies
  there too — as FROZEN scenery (`pan_scenery` group + `set_physics_process(false)`, AI
  off so they can't rouse while the player is still a floor away) that SCROLLS INTO VIEW
  with the floor instead of popping in at the commit; `go_live` WAKES the same nodes
  (`_wake_scenery_zombies` → physics on, drop the tag) and skips a re-spawn
  (`_stair_backdrop_built` guard) so there's never a double set. The passive build now
  calls `_enable_stair_triggers()` before the scenery spawn so the backdrop seeds on the
  SAME 2 active chokes a live/fade floor uses (not all 4 — its triggers were previously
  left at the scene default). The DOWN-shaft slice is WORLD-space, so during the pan the
  floor (the enemy's parent) is offset a whole floor-height; the enemy's `_process`
  re-anchors the shader `cut_y` to the parent's `global_position.y` every frame
  (`off + _stair_cut_y`) so the shaft cut stays aligned as it scrolls in (skipped for UP
  stairwells and during the `stepdown` sweep, which animates the cut itself; at origin
  `off = 0` so it just holds). Covered by `building_floors_test`
  `_test_stair_enemy_backdrop`. **Crossing lock**
  (`stairwell.gd`
  `_stair_enemy_blocking`) blocks the crossing ONLY while an enemy is **on / coming up the
  stairs** — i.e. still in `stair_mode`, within `SHAFT_BLOCK_HALF_WIDTH` (52px) of the
  stair centre (emergent — 2+ on the steps is naturally a hazard). The instant it **steps
  off** onto the corridor the crossing is free again (you can descend past it; you'll fight
  it on the landing, but traversal isn't held hostage). **Returning to a floor**: a stair
  enemy is never recorded off-floor (snapped to the stand line on `_exit_tree` while on the
  steps) and a remembered one comes back GROUNDED as an ordinary floor zombie (restore
  branch re-grounds y/base_walk_y→370, collision on, passable-until-clear) — never mid-air
  or lodging the player. **CROSS-FLOOR FOLLOW — the EXACT SAME node (built):** an enemy
  chasing you onto the stairs comes WITH you, and it is literally the same node, not a copy.
  `stairwell._capture_follower(target)` picks the nearest live chaser within `FOLLOW_RANGE`
  of the steps (standard zombies only, toward a real floor 1..29) and calls
  `enemy.begin_follow()`, which **parks the live node on the SceneTree ROOT** (frozen,
  hidden, out of all groups) so it SURVIVES the scene teardown — root outlives both the
  pan's `_adopt` (which frees the old scene AFTER `go_live`) and a fade's `change_scene`.
  `WorldState.follower_node` holds it in transit (transient, never saved). On arrival
  `building_floors._spawn_follower` (called in the fade build AND pan `go_live`) reparents
  the SAME node into the floor, `end_follow_transit` un-freezes/re-groups/refreshes the
  player ref, and it emerges from the ARRIVAL stairwell, locked on (`alert_timer`), hp/state
  intact. **No duplicate**: the origin slot's `spawn_key` is erased from memory AND added to
  `WorldState.followed_away`, which `_spawn_zombies` + `_spawn_stair_enemies` skip, so the
  floor it left never re-spawns a copy. **Resident persistence**: on the floor it's on, the
  follower's key is `followerR:<floor>`, so a NON-stair exit (apartment/elevator) records it
  and `_spawn_follower` restores it grounded on return (a killed one stays dead). `follower_
  streak` counts consecutive floors the SAME enemy has chased you across (the "whole way
  down" achievement hook; HUD nudge at 3+); reset when the chain breaks or it dies. NOT on a
  pried crossing (a shift re-rolls the world). Cleared by `new_game`; `followed_away` also by
  `shift_building`. (`horde_echo.gd` unused. Earlier follower attempt spawned a fresh copy
  carrying hp — replaced with the real same-node hand-off. Earlier stair-enemy: v2 bespoke
  docked entity that walled the player off — scrapped; v3 corridor-plane; v4 a 3-4 bunch; v5
  a single hazard-gated emerging enemy — now decoupled into normal seeding.)
  **Hazard 3 — fire (v2):** a **spreading blaze** that spreads
  across a floor within a run AND **climbs the building across runs**. A
  deterministic (RNG-free) cellular sim `fire_field.gd` — corridor of heat/fuel
  cells; burning cells push heat to neighbours in a **slow creep** (~1 cell/12s)
  and **never self-extinguish** (`BURN_RATE` 0 — a fire stays lit until doused or
  a run-3 `char_all`); draws **natural pixel flames** (tapered tongues, base
  glow, embers, smoke); in the `fire_field` group. **Cross-run
  model** (`world_state.gd`): a stable per-arc set of **outbreak origins**
  (`_fire_origin_seeded`, ~12%); `fire_intensity(floor)` = worst `age - distance`
  over live origins (`age = current_run-1`), so the front creeps one floor out +
  one stage hotter per run (LIGHT→BLAZE→CHARRED). Fully extinguishing the
  **source** records it in `fire_dealt_with` (cross-run, saved) and stops the
  whole chain; dousing a spread floor (or just a safe path) doesn't count → it
  comes back worse. Barricade + horde **defer to fire** (no doubling).
  `building_floors._spawn_fire` lights a field on any fire floor; standing in
  flame costs **1 hp / 1.1s** (fire never blocks — walk through it, take the
  burn); when the whole floor goes out, `mark_fire_dealt_with` fires. **Smoke =
  ATMOSPHERE ONLY** (reworked): no crouch, no choke damage, no world-space smoke
  clouds — just a subtle, gradual, washed-out screen HAZE (`HUD.set_smoke_fog`, a
  light warm-grey veil that eases in as more of the floor is alight; `smoke_intensity`
  still drives its strength) PLUS a FEW real **smoke-sprite plumes** rising off the
  fire (`_draw_smoke_plumes`, purchased `assets/smoke-effects-pixel-art/`): the
  corridor is scanned in FIXED zones (`SMOKE_ZONE_W`); only a DENSE zone
  (`SMOKE_ZONE_MIN` nearly-full) smokes, so there's always real fire under the plume,
  EMBEDDED at the centroid of that zone's burning cells with a LOW base (rises from the
  fire bed, behind the front tiles — the tileset looks like it's burning). TYPE is
  fixed by STAGE so a plume never morphs short↔long (LIGHT = small `Cycled_smoke` wisp,
  BLAZE = short `Cycled_smoke_long` column), with the height varied a lot per zone by a
  STABLE seed. Cap 5 blaze / 3 light (some spots, not everywhere), drawn BEHIND the
  player (z0). (`_draw_smoke`, the old z4 layer, stays a no-op.) **Aftermath smoke**: fire
  leaves SMOKE, not stray flames. The scatter flame-bits (`_draw_scatter_bits`) are now
  gated PER-CELL (`is_burning_at`) — they used to strew across the whole burning span, so
  dousing the middle stranded flame wisps on doused ground that re-spraying couldn't clear;
  now a bit vanishes the moment its cell is out. Doused/charred (SPENT) cells instead
  SMOULDER: `_draw_smoulder_plumes` rises grey, semi-transparent `Cycled_smoke` off most
  spent cells (z0, behind active-fire smoke), so a stretch you just put out — and a fully
  charred ruin — stays smoky (`has_smoulder` + `smoke_intensity` now count spent cells, and
  `building_floors._process` keeps the HUD haze on while the floor smoulders, not only while
  it burns). A zombie that dies ALIGHT leaves a smouldering corpse: `_die` attaches
  `body_smoke.gd` (a small looping `Cycled_smoke` wisp, no collision) instead of the flame.
  **Aftermath marks where fire WAS, not where the spray landed**: `extinguish_at` only
  spends cells that were actually BURNING (a COOL cell in the blast is left alone), so
  spraying bare floor leaves NO fake ash/smoke; the burnt-out cells act as firebreaks.
  **Door-frame fire** is a separate decal (not the fire field), so a blast also clears
  `door_fire`-group decals within its radius (else they lingered as flames a re-blast
  couldn't touch), and `_spawn_door_fire` uses the doused-aware `apartment_active_fire_stage`
  so a put-out apartment shows no door flame. **Enemies burn too**: a zombie
  (standard AND big) standing in flame catches (`on_fire` overlay) and takes burn
  DoT via `burn_tick` until it dies — same rule as the player, driven from
  `building_floors._process` where `on_fire` is set. The overlay (`enemy_fire.gd`) is
  **2-3 small purchased `3 Flame` globs stuck across the body** (scaled down, NO
  collision — purely cosmetic, never blocks the player); it's cleared the instant the
  zombie dies (`_die` sets `on_fire=false`) and `_process` **skips dead corpses** so a
  lingering body never re-lights or leaves flames floating. **Render**: the flames are the
  purchased **craftpix pixel-fire sprites** in `assets/fire-pixel-art-animation-sprites/`
  (procedural flames dropped — they never read as real fire). Three sheets for
  variety: **`2 Fire_tiles`** (32² floor bed) tiled seamlessly across the burning
  span (`_draw_ground_fire`), **`3 Flame`** (32² mid flame) and **`1 Fire/Idle`**
  (64² big bonfire) rising at intervals in **varied sizes** repeated along the whole
  fire — small/medium/big globs (`_draw_tall_flames`/`_blit_anim`), all
  nearest-filtered, frame advancing at `TILE_FPS`. **Depth** by the rule "fire lower
  than the player draws in front, higher draws behind": the full floor bed is drawn
  ONCE IN FRONT (z2) to ~waist height so the player walks THROUGH it (no doubling —
  it used to be on both layers), while a SMALLER bed runs along the floor-to-wall
  **seam** (`BACK_SEAM_Y` = feet−22 ≈ the door base) and the tall flames rise BEHIND
  (z0), so the player passes in front of them and the fire recedes toward the wall;
  `FIRE_BASE_Y` 426 sits on the walking plane (feet ~418, bed covers them). The depth
  bed is carved harder + **skips doorways** (`avoid_doors`/`_near_door`, a band around
  each `APARTMENT_X`) so it never runs straight across a door (beside one is fine). Tile **stage-scaled** (`_tile_scale`:
  1.6× LIGHT, 2.7× BLAZE), globs bigger/denser on a BLAZE. All the beds + globs are
  **PATCHY** (`_patch_on`, a seeded per-floor clump mask, different salt per layer) —
  fire clumps here and there, never a solid unbroken line. **No-overlap placement**: the
  tall flames (`_draw_tall_flames`) and floor globs (`_draw_scatter_bits`) are placed by a
  MIN-GAP walk (>= the widest glob), not a dense step, so globs read as DISTINCT tongues on
  the continuous bed instead of piling into one blob — on any seed, at LIGHT or BLAZE (the
  jitter in `_blit_anim` is small enough not to close the gap). `apartment_fire` spots use
  the same discipline (spaced ~120-168 on BLAZE, ~108 apart from the entrance on LIGHT, one
  bed per spot). **Complementary tile beds**: the DEPTH (back-seam) bed and the FRONT bed are
  MUTUALLY EXCLUSIVE per cell (`_bed_assign`, ~2-cell clumps assigned back XOR front), so the
  tile-set fire never doubles into a bloated overlap — where depth draws, front doesn't, and
  vice versa; globs/tall flames are a separate layer and may still overlap (fine). BOTH beds
  avoid doorways (`avoid_doors`), so no fire tiles plaster across a door. **Smoke** plumes are
  spaced (`_too_close`, no stacking into a dark blob) and drawn as THIN rising wisps (the
  128-wide sprite squished into a ~62px dest, not a blocky square), with a couple more of them
  (cap 7 blaze / 5 light) plus 2 FOREGROUND stacks (`_draw_front_smoke`, z2) so smoke reads in
  front as well as at the depth seam. The scattered floor globs
  (`_draw_scatter_bits`) sit ON THE FLOOR and IN FRONT of the player (z2, player walks
  behind them) — not floating up the wall. **Ignition patterns** (per stage, seeded per
  (floor,run) so they vary floor-to-floor / game-to-game, `_ignite_light_patch` /
  `_ignite_blaze_patches`): **LIGHT** = a small seeded patch at the origin (2-4 cells,
  varied shape); **BLAZE** = a floor-WIDE scatter of 1-2 cell patches with gaps (~60%
  of the corridor, never one localised blob — the whole floor reads ablaze); **CHARRED**
  = `char_all` (no active fire — a burnt-out ruin; `_spawn_fire` also SKIPS the saved-
  spread `import_state` on charred so a stale burning snapshot can't re-light the ruin,
  the bug when F2-cycling lv1/lv2→lv3 in one run). The breakout origin x is **jittered
  per floor** (`_fire_origin_for`, ±120) off the exact stair/mid anchors so fires aren't
  always at the same three spots. **Within-run spread is CAPPED**
  (`fire_field.spread_cap`, set in `_spawn_fire`): a run-1 LIGHT fire creeps SLOWLY
  (~30s/cell — `SPREAD_RATE`/`COOL_RATE` halved so it doesn't cover the floor in a few
  minutes) up to ~16 cells — spreading across a good chunk of the floor toward nearby
  apartments over time, but staying small enough to extinguish; a run-2+ BLAZE caps
  ~26 (toward floor-wide). Escalation (across floors) is across RUNS, not within one:
  the origin-based `fire_intensity` (age = `current_run-1`, minus distance) means run
  1 lights ONLY the origin floor, run 2 adds its immediate neighbours (LIGHT) while
  the origin goes BLAZE, run 3 pushes two floors out. **DEV fire (F2 scroll)** now has
  THREE fire steps — the cycle is off → barricades → hordes → **fire lv1** → **fire lv2**
  → **fire lv3** → off. All seed a SINGLE origin on the floor F2 is pressed on
  (`dev_fire_origin`); the LEVEL is the scroll step itself (not the run counter): lv1
  (`DEV_HAZARD_FIRE`) = origin LIGHT only; lv2 (`DEV_HAZARD_FIRE2`) = origin BLAZE +
  both neighbours LIGHT; lv3 (`DEV_HAZARD_FIRE3`) = origin CHARRED + neighbours BLAZE +
  two-out LIGHT — mirroring run-1/2/3 escalation without advancing the run. (Avoids F8,
  which is Godot's editor "Stop" shortcut and closes the embedded game window.)
  **Fire memory** is snapshotted PERIODICALLY (every ~0.6s in `_process`) under
  `_built_floor`, re-imported by `_spawn_fire` on return. **Crucial**: the seamless
  stair pan (`stair_pan.gd`, `ENABLED = true`) builds the destination floor as a
  PASSIVE backdrop — which skips EVERY live hazard (they sit after `if passive:
  return` in `_ready`) — then promotes it with `go_live()`. So `go_live` must itself
  spawn fire/barricades/hordes/door-fire (it now does); without that, arriving via
  stairs left a fire floor with NO fire, while an apartment round-trip (the fade
  path, full `_ready`) was fine. Locked by `floor_adopt_test`.
  **Door fire**: a burning apartment's door has flames climbing the two FRAME EDGES
  only (`building_floors._spawn_door_fire` + `fire_decal.gd`, folder 3), at z0 behind
  the player — the doorway itself stays clear so the door is visible/enterable (a big
  central glob used to block it). (`1 Fire`'s Death/Run/Walk anims are a
  fire-elemental character — still unused; candidate for a fire enemy.)
  **Placement** 40% down-stair / 40% mid / 20% arrival-stair (`fire_spawn_kind`,
  resolved x persisted in `fire_origin_x`). **Spreads into apartments** by
  proximity (`apartment_fire_stage`): nearest catches first, run 2 nearby ablaze,
  run 3 whole floor charred; charred apartments = no loot (`room.gd`), burning
  doors glow. **INTERIOR apartment fire** (`apartment_fire.gd`, a NO-SIM procedural
  renderer — spots don't spread): gated by `apartment_active_fire_stage(floor,apt)` (the
  derived `apartment_fire_stage` unless the player DOUSED it out this run —
  `apartment_fire_out['floor:apt:run']`, saved, cleared on shift; cross-run a doused room
  re-derives from the still-burning corridor source, so kill the SOURCE not just the room).
  Stage placement: LIGHT = a few small patches near the ENTRANCE the fire crept in from;
  BLAZE = patches across the whole room; CHARRED = scorch + heavy smoulder smoke, no fire.
  `room.gd` spawns it (live + BalconyPan backdrop), runs the player/enemy burn + HUD haze
  in `_apartment_fire_process`, and marks the room doused when fully out. Enemy-by-stage
  (uses the DERIVED stage): CHARRED = no enemies; BLAZE = no live enemies, 1-2 smouldering
  burnt corpses (`enemy.make_burnt_corpse`); LIGHT/none = normal live spawn (they burn if
  they wander into the flames). The extinguisher + burn code find the interior fire via the
  shared `fire_field` group + interface, zero extra wiring. **Enemies on fire** (`enemy_fire.gd`) deal DOUBLE damage. Item **036 Fire Extinguisher**
  (`is_extinguisher`, 2 uses) douses a radius **for good** (`extinguish_at`) —
  one canister only blows a safe path through a big blaze (backtrack for more);
  mounted **by the elevator on EVERY floor** (skips charred) once per (floor,run)
  (`_place_elevator_kit` + `elevator_kit_placed`, saved; drawn as a wall-mounted
  red/white canister prop by `world_drop.gd` at x929 — halfway apt01↔elevator — and
  registered in the PASSIVE build too so a stair-pan arrival still gets one). Its use
  is bound to the **attack key** (default Space) when it's the selected item — sprays
  in either mode, never swings (Q / double-click / right-click still work). **Spray VFX**:
  using it puts a placeholder red/white canister in the player's HANDS (`held_extinguisher.gd`,
  child of the player, ~1.1s) and jets the purchased **Horisontal_smoke** cloud from the
  nozzle over the fire (`extinguisher_spray.gd`, z3, flips with facing); the actual douse is
  **delayed ~1s** (a `create_timer` in `use_item`) so the fire reads as beaten back rather
  than switched off, then those cells go SPENT and rise black smoulder. **Merchant**
  shelters while its floor burns (`_merchant_pending_fire`) and emerges once it's dealt
  with; left burning, it's absent on that floor across runs. While sheltering it shows a
  **one-time non-interrupting line by the elevator** (`_process`, `_merchant_shelter_line_shown`)
  so the shut doors read as its choice, not a bug. Still to build:
  flames **on walls/ceiling/doors** (corridor flames only today), a fire
  approach-warning beat, and the automatic run-advance that drives escalation
  live. **F2** (all three hazards built)
  rebuilds the current floor and dev-cycles off → barricade →
  horde → fire → off.
  **Terminology:** barricade = debris block (crowbar); horde = live-enemy block
  (fight/lure); fire = spreading blaze (extinguisher). **Barricade-keeper NPC**
  quest has seeded groundwork (`barricade_has_keeper` + `barricade_keeper_state`)
  but no NPC yet. Covered by `stair_block_test` + `building_floors_test` +
  `fire_test`.
- Maintenance room + fuse/elevator traversal (docs/MAINTENANCE_ELEVATOR.md,
  steps 1–3, v1): a small SAFE room (`maintenance.tscn`) placed every 3rd floor
  (`is_maintenance_floor` = 3..27 step 3) via a `MaintenanceDoor` at x929 (the old
  extinguisher spot — **no wall extinguisher on maintenance floors**, blocked at
  both the data and render layers). ONE-WAY **left doorway** (hole in the bricks);
  spawn just inside it, exit trigger sits in the hole. Two toolbox/fuse-weighted
  scavenge anchors (glow fixed: `set_process(true)` after runtime `set_script`).
  Placeholder **workbench** + **fuse-box** ColorRect props (upgrade station UI is
  future — the Scrap system). **Fuse (020)** now `is_fuse` + **stacks to 3/slot**
  (`MAX_FUSE_PER_SLOT`); at the fuse box **[E] fits carried fuses** (accumulates
  across visits), and 3 **powers the elevator** (ding + hum). Power is a **single
  global per-run charge** (`elevator_powered`/`elevator_fuses_loaded`, saved,
  reset by `new_game`). When powered the corridor **Elevator** shows `[E] Ride`
  (hidden on merchant floors — the merchant has the car); on E the **corridor
  doors slide open with a ding** (`_board_elevator`, mirroring the merchant's
  door tween) THEN cut to **`elevator_interior.tscn`** — a self-contained
  **animated car instance** (Silksong bench-room style): the player stands in a
  drawn metal car (`elevator_car.gd`, roomy enough for a future NPC), picks
  `[↑]`/`[↓]`, and the car **rumbles gently** (camera shake) with a **cool light
  band sweeping the back wall** (passing-floor light) while a **floor counter
  ticks** through the floors for a few seconds; on arrival a **bing-bong** and
  the **car doors slide open onto a glimpse of the hallway beyond** (drawn in the
  corridor tileset palette) before it **spends the charge** and drops you
  out **5 floors** up/down
  (`elevator_destination`, clamped [1,29]) via `spawn_source="elevator"`. Riding
  onto a merchant floor triggers a "you rode MY elevator?" beat. **Extinguisher
  economy**: floor spawns randomized (`EXTINGUISHER_FLOOR_CHANCE` 0.6, none on
  maintenance floors); the merchant sells 036 (~30% of visits, or guaranteed at
  the nearest merchant floor to a seeded fire — crisis markup). Covered by
  `maintenance_test` + `elevator_test`.
- Three-run arc + time skip (docs/THREE_RUN_ARC.md, steps 1-3, v1): a session is
  THREE characters (morning / afternoon / night), not one. `WorldState.advance_run()`
  is THE TIME SKIP — it bumps `current_run` (cap 3; returns true when the arc is over),
  sets up a FRESH character (inventory / health / stamina / wallet BALANCE / follower /
  upgrade offers all wiped) and KEEPS the cross-run rewards (active upgrades, wallet
  UNLOCK) plus the DECAYED world on the **same `master_seed`** — almost every escalation
  already reads `current_run` (door-state weights, fire climbing `age=current_run-1`,
  nastier merchant), so the same building simply reads one run harder with no re-roll.
  The stateful decay it adds: `mutate_door_states_for_new_run()` (locks loosen, more
  breaches, keeping the player's opened doors) and clearing kill/position memory so the
  dead **reshuffle** (a `current_run` salt in `building_floors._spawn_zombies` lands them
  in new spots); loot depletion PERSISTS (searched anchors, world drops, consumed keys
  untouched). **Both endpoints wired**: `lobby_exit.gd` (exit — selfish, takes inventory
  out, no corpse) and `game.gd::game_over` (death — a mid-arc death is NO LONGER a
  session end; corpse recovery is store step 7, future) set the finishing character's
  outcome, call `advance_run()`, and — unless the arc is over — save the fresh run
  (`save_game(hallway, record_live_zombies=false)` so the dead scene's zombies aren't
  logged into it) and `Transition.to_run_shift(hallway, next_run)`. **Time visuals**:
  `to_run_shift` is a slow fade-to-black **title card** (game pixel font) animating the
  time-of-day word MORNING / AFTERNOON / NIGHT + a subtitle, held, then the new Floor 30;
  every world scene sets its **ambient darkness** via `WorldState.apply_time_tint(self,
  floor)` — one `CanvasModulate` (node `WorldGrade`, world only, never the HUD). Only the
  THIRD character concluding ends the playthrough: `game_over.tscn` now shows a win/lose
  headline + all three fates. Covered by `run_arc_test`.
- REAL 2D lighting (GL Compatibility PointLight2D; replaced the old flat colour/infection
  "filter" the owner disliked): the world CanvasModulate (`WorldState.ambient_color`) is the
  **ambient DARKNESS** real lights punch through, NOT a tint over lit art. **VIBE = "cozy
  horror"** (owner's word): warm amber light POOLS (cozy) against a cooler, deeper dark
  (horror) — CONTRAST, not a flat wash. So the ambient FILL is COOL/neutral (`AMBIENT_CAST`
  morning cool-daylight → afternoon cool dusk → night deep blue), NOT warm — warm-on-warm read
  flat/beige and "too soft". The lamp light is a RICH amber (`WARM` 1.0,0.78,0.45) so its pools
  pop against the cool fill. **STAGED RAMP (owner's call):** MORNING is DAYTIME — near-fully lit,
  minimal shadow, lighting barely intrudes (ambient base **0.95**, NEUTRAL bright daylight cast
  1.0,0.99,0.96; lamp 0.15, window 0.10, aura 0.10). The lighting design only starts working in
  the AFTERNOON (base 0.42, cool dusk, warm pools begin to matter) and dominates at NIGHT (base
  **0.07 = near-black**). Base dimmed further by DEPTH (`AMBIENT_DEPTH_DIM`). **Brightness budget
  (matters — 2D lights are ADDITIVE):** lamp energy per-run `LAMP_ENERGY_BY_RUN` [0.15/0.95/1.9]
  — barely-there by day, punchy defined pools by dusk/night, but ambient+peak-add ≈ 1.0 so it
  never blows to white (the owner caught an earlier version glaring + a white-blown window). The
  cone cookie has a CRISP edge (`pow(1-hf²,1.6)`) so shafts read as pools, not fuzz. Window
  [0.16/0.28/0.30] + cool day cast keeps the pane's blue; aura [0.16/0.40/0.62]. Lights run
  bright only at night when the ambient is near-black. **NIGHT is deliberately near-black** — only the lights
  reveal the scene, so **enemies lurk unseen in the dark and jump-scare** the player when they
  walk into them (free from the darkness — enemy sprites are just unlit until a light reaches
  them; no reveal code). Lights: **ceiling lamps** cast **DOWNWARD CONES** (a baked
  `FloorLighting.cone_texture()` spotlight cookie, apex at the fixture — NOT a round blanket),
  some **swaying** gently (rotation about the bulb), some **flickering**, some **BLINKING** (a
  failing tube), some **DEAD** — more dead the deeper/later you go (`dead_frac` scales with
  depth + `0.20×(run-1)`, so run 2 loses lamps, run 3 loses more), seeded per floor/run;
  installed by `building_floors._spawn_floor_lighting` in live `_ready` AND the passive backdrop
  + guarded in `go_live` so lamps scroll in with a stair pan. **Window daylight**
  (`FloorLighting.make_window_light`, round cookie, warm by day → dim blue MOONLIGHT at night):
  the two **stairwell windows** (added in `floor_lighting.setup`) and each **apartment balcony
  window** (`room.gd`, on a shown balcony slot). **Fire** is a real orange light
  (`fire_field._spawn_fire_lights`/`_update_fire_lights`) — **LOCALISED** to the flames: small
  glows (scale ~1.0-1.3) and only as many lit as the burning span is wide (`FIRE_LIGHT_SPACING`),
  so a small fire is ONE tight pool, not a floor-wide wash (owner caught an over-scaled "disco"
  version flooding the whole side). The player
  carries a **faint aura** (`player._setup_player_light`, energy/reach from
  `WorldState.player_aura_energy/scale`) — the bubble that reveals lurkers. **"Night Eyes"
  merchant upgrade** (`U_nightvision`, `night_vision` stat): widens the aura a LOT + lifts the
  ambient, most on **run 3** — "see in the dark". **Descent dimming = the SECTIONAL-IDENTITY
  pillar** now (light, not a green cast; `INFECTION_DEEP_TINT` removed). **Lighting is
  INTRINSIC** — always on, varying by scene/run; NOT a dev toggle (owner was explicit). Purely
  visual (can't verify the LOOK headless — see docs/PLAYTEST_CHECKLIST.md §2/§2b). Covered by
  `lighting_test` + `run_arc_test`. TODO/verify in-editor: apartments have no ceiling lamps, so
  at night they rely on window + aura + anchor glow — flag if too dark to scavenge.
- Enemy variety / escalation table (THREE_RUN_ARC step 6, v1): the infestation
  **migrates upward** across the arc, and there are now **five corridor types**. The mix
  is data-driven per (floor band × run) in `world_state.gd`: `HEAVY_CHANCE` (Big Zombie)
  plus `CRAWLER_CHANCE` / `LONGARM_CHANCE` / `SPITTER_CHANCE`, each a 3×3 `[band][run]`
  table (bands LOW 1-10 / MID 11-20 / HIGH 21-29). `enemy_type_for(floor, spawn_key)`
  walks them in a fixed order (`_MIX_ORDER`) accumulating the per-slot chances — the
  leftover is a plain standard — **deterministically** (a pure function of floor/position/
  run, so a pan backdrop and its live commit pick the SAME type, stable on re-entry,
  re-rolled when the run advances). `building_floors._spawn_zombies` maps the id via
  `ENEMY_SCENES`. **Run 1 is barely touched** (only LOW floors: 6% heavy + 10% crawler;
  nothing mid/high); types reach MID by run 2 and are common even up HIGH by run 3.
  Density is unchanged (`get_floor_zombie_count` — MIX not count; no cramming). **The
  types** (all reuse `enemy_zombie_standard.gd` via `extends`, overriding the now-`var`
  stats `SPEED`/`DETECTION_RANGE`/`ATTACK_RANGE`/`ATTACK_DAMAGE`): **Crawler** (`enemy_zombie_crawler`) —
  low to the ground, **SLOW** (26) + fragile (~half HP) but hits for **DOUBLE**
  (`ATTACK_DAMAGE=2`); the run-1 swarm (see spread rebalance). A push is a **general push**
  on it like every other enemy (real knockback via `receive_push`); its scene collision box
  is **taller** (60px, feet still on 419) than the low sprite so the shove connects even into
  the blank space above the body. (`player._do_push` now gates on HORIZONTAL edge distance +
  `MELEE_PLANE_TOLERANCE`, same as melee, so a wide low body can't dodge the range check. The
  old Crawler-only KICK-STUN was dropped; `enemy.receive_kick` remains but is unwired.) **Long Arm**
  (`enemy_zombie_longarm`) — normal pace, long `ATTACK_RANGE` (62 vs 30), the reach threat;
  **Spitter** (`enemy_zombie_spitter`) — its `ATTACK_RANGE` is a 300px SPIT range, so the
  base AI halts and plays Attack from afar; the overridable `_deliver_attack` launches a
  `spit_projectile.gd` (frames sliced at runtime from the purchased Projectile sheet) on a
  cooldown instead of a melee hit. All three settle at origin **374** (feet on 419 — their
  OWN line, `ENEMY_SETTLED_Y`, never the standard's 370; measured, see docs/Y_PLANES.md);
  memory/record/pan-freeze all work via the shared `zombie` group. Frames are baked
  SpriteFrames `.tres` (regenerate with `tools/gen_enemies.gd`). Tuning lives in the four
  `*_CHANCE` tables. Covered by `enemy_variety_test`.
  **Spread rebalance (variety + sectional flavour):** the tables were reworked so runs
  2/3 carry MORE new enemies (esp. MID/HIGH — HIGH run 2 went 8%→22%, run 3 31%→48%), no
  single type dominates (per-type peak trimmed 0.30→~0.22 so a fight reads as a MIX not a
  wall of bigs), and each **section** has a distinct night-time lead so descending isn't
  samey: **LOW = the swarm** (crawler/big, melee), **MID = the bruisers** (long-arm),
  **HIGH = ranged** (spitter *inverts* — it's rarest deep, most common up top). The
  **Crawler is FRONT-LOADED** (owner's 3:1 call): ~0.25 across the WHOLE building in run 1
  (its per-band peak — the early swarm before the tougher types), then its share eases as
  runs 2/3 diversify. So crawler is deliberately NOT monotonic (the other three still only
  grow). Locked by `enemy_variety_test` (`_test_variety_and_flavor` + `_test_crawler_behaviour`).
  **Aim / hitbox (MEASURED + fixed):** the corridor rigs rest on ONE plane by FEET (all on
  419) but at different ORIGINS — player ~388 (feet/col-bottom ~421), standard zombie 370,
  big/crawler/long-arm/spitter 374 — an inherent ~18px origin gap. Melee `_do_melee_attack`
  now gates on **HORIZONTAL edge distance** (`|dx| - _zombie_body_radius`) with a **vertical
  tolerance** (`MELEE_PLANE_TOLERANCE` 48) — genuinely height-independent, so that origin gap
  can't shorten reach or miss (the old euclidean `distance_to` folded the 18px into every
  check and ate reach — the owner caught this: "not on the same plane, affecting attacks").
  The tolerance still excludes a truly off-plane enemy (a corridor zombie while you're up on a
  balcony, or one lurking mid-stair). Priority = nearest by horizontal edge distance. Locked
  by `gun_combat_test` `_test_melee_plane_reach`. (Gun still uses `distance_to` — negligible at
  range.) The **VISUAL** height difference in a screenshot is sprite FRAMING, not position: the
  zombie frame is 128px×3 (drawn feet high in a tall mostly-transparent frame), the player
  48px×2, so their DRAWN feet land at different screen Y even though collisions/feet align at
  419 — a per-rig `AnimatedSprite2D.offset` art tweak (needs an in-editor look), NOT a Y-plane
  bug. `_zombie_body_radius` is RectangleShape2D-aware so the wide low crawler's real
  half-width (40) is used instead of the old 10 fallback. (An impale/bludgeon
  *feel* animation is optional polish, not a fix — the swing VISUAL doesn't angle at the
  target, but the hit lands.)
  **Playtest fixes (measured):** (1) **Crowd-push off the plane** — the Y-pin only guarded
  the MAIN move path; the early-return states (`is_listening`/`is_switching_mode`/lashing/
  dying) each called `move_and_slide()` unpinned, so a crowd shoved the player UP during
  those frames and it stuck. Centralised into `player._move_locked()` (pins Y to pre-slide
  unless balcony/cutscene) used by EVERY move path. Locked by `plane_lock_test` (0px drift
  under a 14-zombie crowd in the mode-switch path). (2) **Spitter couldn't hit** — it
  launched the spit from the mouth (~28px up) and flew level, but the player rig is much
  shorter, so the blob sailed 42px over the player (> the 30px hit radius) and never
  connected. Now launches at the player's plane (`enemy_zombie_spitter`) + the projectile
  hit is horizontal + a 48px vertical tolerance (`spit_projectile`). (3) **Legs behind
  corpses** — `_die`/`make_burnt_corpse` left the corpse at z1 (actor layer, later in the
  tree) so it drew over the player's legs; corpses now drop to **z0** (the floor layer) on
  death (standard + big). (4) **Placeholder scale mismatch** (player ~56px vs zombies
  ~84–99px) makes tall enemies tower — an ART issue (functional hits land after the above);
  documented in docs/ART_REQUIREMENTS.md as "consistent character height" for the art pass,
  NOT fixed by rescaling throwaway rigs (would float their feet).
  **Corridor bosses (runs 2/3):** a floor may set ONE roaming boss loose — a tougher Big
  Zombie (`enemy_zombie_big.is_corridor_boss`: ~1.6×+6 HP, elite red tint, in group
  `corridor_boss`). It guards nothing so drops **NO key**, but drops a **fatter money
  bundle + one good-loot item** from `WorldState.BOSS_LOOT_POOL` (weighted; gun/first-aid
  the rare rolls). Per-FLOOR, at most one, seeded per (floor,run) via
  `WorldState.floor_has_boss` (`BOSS_CHANCE` table, LOW-favoured, none in run 1);
  `building_floors._spawn_corridor_boss` places it mid-corridor with the same
  memory/settle-374/pan-scenery rules as any big, key `boss:<floor>:<run>` (dropped by
  `shift_building` like the stairwell/follower keys). Still to build: distinct AI beyond
  the reskins (spitter kiting, crawler crawl-under), a distinct boss silhouette (art),
  storied-room spawn reserve, descent boon on exit, night-darkness/lighting, character stats.
- DEV TOOLS — consolidated F1 menu (`scripts/dev_menu.gd`, on the HUD; gated by
  `DEV_MODE`): one paused button panel replacing the old scattered F1-F8 keys (which
  were unwieldy, and F8 is the editor's Stop shortcut so it closed the game). Buttons:
  God Mode + Force Stair Enemies (toggles), Set Health / Set Run (time of day) / Floor
  Hazard (sub-panels), Wallet +500, Toggle Tutorial, Warp to Floor…, Spawn Item…. The
  actual actions are public `player.dev_*` methods (`dev_toggle_god`, `dev_set_health_state`,
  `dev_apply_hazard`, `dev_set_run`, `dev_wallet_cash`, `dev_toggle_tutorial`); the old
  item-spawn (`dev_item_prompt`) and floor-warp (`dev_warp_prompt`) prompts lost their own
  F1/F6 hotkeys and are opened from the menu via a public `open()` (found by group). Set
  Run replaces the F8 run-advance. Covered by `dev_menu_test`. (The `dev_*` input actions
  in project.godot are now unbound-in-practice — harmless.)
- Next: characters/profiles/stats; **Upgrade offers** polish and player-corpse
  recovery (store step 7); barricade-keeper NPC; fire smoke/crouch + warning beat;
  the maintenance **upgrade station** UI (Scrap system, SCRAP_UPGRADES.md).
- Not started: balcony descent, quests, character stats.
