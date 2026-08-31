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
  `balcony_test`, `hud_prompt_test`, `stair_block_test`, `fire_test`,
  `maintenance_test`, `elevator_test` — run all
  26 before commit. (`floor_adopt_test` is seed-sensitive: `new_game` rolls a random
  master seed and it asserts a floor has zombies, so it fails ~occasionally
  on a 0-zombie seed — a known flake, re-run it. `building_floors_test` is the same
  class: its arrival-stair-horde asserts depend on the rolled seed placing a horde at
  the arrival stairwell, so it too flakes ~occasionally — re-run it.)

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
  (`barricade_prop.gd`) at both landings. **Hazard 2 — hordes (v2):** other
  stairwells hold a **small knot of live zombies** (`is_stair_horde`, seeded ~15%,
  mutually exclusive with barricades) — no crowbar, you **fight or lure** them off
  (thrown can). **3–4 zombies wait DOCKED IN the stairwell** (`stair_docked`), each
  **sliced** by the stair-pan `SHRED_SHADER` (reused via `StairPan.SHRED_SHADER`) so
  only the part above the landing shows — they read as standing down in the shaft,
  confined to its x-band (nothing on the wall beside the opening). **Consistent with
  the player's stair transition** (owner-audited): the slice sits on the SAME cut line
  the player descent uses (`CORRIDOR_PLANE_Y − StairPan.DOWN_STAIR_APPROACH +
  DOWN_SHRED_FOOT` = y401), shrunk to the SAME `StairPan.DOWN_DEPTH_SCALE`. They're
  frozen (no roaming the hall) until the player comes within `STAIR_DOCK_EMERGE_RANGE`,
  then they **EMERGE** one-by-one (`stair_emerging`): a climb up to the stairwell's own
  standing spot (`stair_x`, where the player lands) using the SAME footfall stepping
  (`StairPan._stagger_y`, 16px steps at `STEP_TIME`) and the SAME reveal-cut sweep
  (`+ StairPan.SHRED_BOTTOM`), **un-slicing** + brightening + growing back to full as
  they rise, landing spots fanned so they file out rather than stack, after which normal
  AI (chase) takes over — no camera move (in-scene actors). (Two intentional deviations
  from the single-actor transition: the group is staggered at multiple depths, and it
  dims into the unlit shaft — the player code shrinks but doesn't dim.) `stair_horde` group, kills
  persist; `stairwell.gd` blocks the crossing while any live zombie is within
  `HORDE_BLOCK_RANGE`. No shift/rest cost — the fight is the cost. A horde stairwell
  shows a **colored red echo pulse** (`horde_echo.gd`)
  and gives a **one-time approach warning** (brief freeze + player line,
  `building_floors._process` + `hazard_approach_warned`); barricades give no
  advance warning. **Hazard 3 — fire (v2):** a **spreading blaze** that spreads
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
- Next: tutorial **v2** (above), then characters/profiles/stats + the
  two-&-three-run arc; also **Upgrade offers** polish and player-corpse
  recovery (store step 7); barricade-keeper NPC; fire smoke/crouch + warning beat;
  the maintenance **upgrade station** UI (Scrap system, SCRAP_UPGRADES.md).
- Not started: time-of-day, balcony descent, quests, character stats.
