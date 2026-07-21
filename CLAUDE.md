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

When docs conflict: STORE_DESIGN.md and THREE_RUN_ARC.md supersede the GDD
(each notes what it overrides). Keep the docs updated when a design decision
changes — they are the cross-session memory for this project.

## Project layout

- `project.godot` — autoloads: `WorldState`, `ItemData`, `Game`, `HUD`
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
- Can throwing (item 17): scavenge-mode use of Canned Food throws a can
  (sword-swing anim, manual arc physics w/ bounce+roll); its landing emits
  a loud noise + distraction that pulls every non-boss zombie to the sound
  (some de-aggro on arrival, some resume). Bosses ignore it.
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
- Deferred from playtest feedback: broken-item crafting.
- Next: **Upgrade offers** (store doc step 6 — needs the upgrade pool
  designed first), then player-corpse recovery (step 7).
- Not started: time-of-day, fires, balcony descent, quests, character stats.
