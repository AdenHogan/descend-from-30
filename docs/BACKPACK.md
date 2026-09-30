# The backpack — inventory you open with your hands (owner round 26)

> "a image of a backpack as part of the UI, click it and the player does a bend down and open their
> backpack animation followed by an opening of a sub menu scroll wheel for inventory with live gameplay
> underneath so you can still be attacked."

**BUILT v1** on top of the quick wheel. The HUD has a small pixel backpack in the bottom-right corner
(`scripts/hud_pack_button.gd`, key **B**, rebindable in Settings → "Backpack"). Click it (or press B):

1. **Kneel** (`Player.PACK_KNEEL_TIME` 0.45 s): rooted, `crouch_idle` pose, the body leans toward the pack
   (`Node2D.skew` about the sprite, the feet held by moving the sprite `feet_dy·sin(skew)` back — measured
   by `pack_test`), and a placeholder pack (`scripts/held_pack.gd`) lies at their feet with its flap opening.
2. **Open** — the ring (`scripts/pack_wheel.gd`) floats above them: the WHOLE bag (empty slots faint), in
   **real time** — no slow motion, no dimming beyond a thin shade. Left-click = equip / put away (the
   hotbar's own toggle), right-click = use (a bandage from the bag; a can or the extinguisher says "Stand up
   first"), **Delete** = drop it at your feet (same path as the hotbar's Discard — nothing destroyed).
   The middle, **Esc**, **B**, or a click out in the world closes it; a click in the hotbar strip is left alone.
3. **Stand** (0.3 s, still rooted and vulnerable).

**The cost / the risk**: it takes ~0.75 s down and up, rooted, on your knees. **Any hit slams the pack shut
at once** (`Player.receive_hit → end_pack(true)`: upright, hurt, "The pack slams shut.", no stand-up wait).
Moving, jumping, interacting, listening, resting, crouching or switching stance also gets you up. It refuses
to start mid-swing / mid-shove, listening, lashing, cutscene/dead/dying, out on a balcony or stepped up at
a back-plane spot, with a panel / loot / dialogue / journal open, or while the quick wheel is up (and the
quick wheel refuses while you're at the pack — never two rings).

## The backpack as an ITEM (owner round 27 — BUILT)
"When a player begins a run they have no inventory. But on the floor next to apartment 3001 there will be a
backpack to pick up which will become the inventory."
- **The rule** (`WorldState.packless_rule`, saved; `Game.new_game()` turns it on, a plain `WorldState.new_game()`
  — every test — leaves it OFF so the classic five slots stay): each run starts with `has_backpack = false`
  (`new_game` + `advance_run`; saved). Without a pack `get_inventory_slots()` = `POCKET_SLOTS` (2): a third item
  is refused like any full inventory (nothing is silently lost). An old save has no keys = rule off.
- **What a pack-less character has:** `POCKET_SLOTS` (2) hold-able items, but only `FREE_CARRY` (1) comfortably —
  **a second item OVERLOADS them: max stamina is cut in half** (`get_max_stamina` × `OVERLOAD_STAMINA_MULT` 0.5, so
  every consumer — HUD bar, sprint, regen, exhaustion thresholds — follows), current stamina is cut down at once, and
  putting the second item down (or taking the pack) sends stamina **straight back to full**
  (`WorldState.is_overloaded` / `sync_overload`, run after every `HUD.refresh_inventory` and each player physics frame;
  a one-line notice each way; a load doesn't re-announce). No pack button, no wheel hint, and the pack key / quick
  wheel refuse (`"no backpack"`; the pack key says "You don't have a pack."). **No pocket bar** (owner: "what are
  those black boxes at the top?" — the empty slots were noise): the in-hand box shows what they hold, number keys 1-2
  switch. The opt-in hotbar (`set_hotbar_visible`) is separate and unchanged.
- **The pickup** (`backpack_pickup.gd`, an Area2D built in code like `player_corpse.gd`; art = `PackArt`, the same
  rucksack pixel drawing as the HUD button): [E] / click → `WorldState.take_backpack()` → slots open out to the full
  bag, and the pack button + ring + quick wheel wake. Skipping it is legal — a pack-less run is
  the planned "ultra difficult" achievement (balance to follow).
- **Where:** every run after the first — on Floor 30's floor just right of 3001's door (`hallway.BACKPACK_X` 884,
  feet 419; laid out only while the character has none). **Run 1 (the tutorial): inside 3003** by the entrance,
  far from the neighbour (`room._spawn_tutorial_backpack`); Floor 30 stays clear that run.
- **The tutorial beat** (room.gd `TutStep.PACK`): 3003's panicked-search node is an EMPTY search under the rule (a
  magazine would eat a pocket), so the pockets fill with the bandages + the golf club. When the neighbour dies her
  key is on the floor and there's nowhere to put it: a paused **"overloaded"** beat (`3003_overloaded`; if a pocket
  happens to be free, `3003_backpack`) → the pack pulses (`highlight`) → taking it opens a paused **inventory-intro**
  beat (`pack_intro`, hinting the pack key + quick-wheel key) → then the usual heal beat. Grabbing the pack
  mid-fight defers the intro until the kill. Lines live in `TutorialManager.LINES`.
- **The floor pack is just the pack** (no outline / box — owner: the world prompt "Backpack [E] Pick up" says what it is).
- **The icon:** `hud_pack_button.gd` now draws the shared `PackArt` texture (16x20: grab loop, domed lid, two tan
  straps with brass buckles, front pocket with zip, bottle pockets) — replacing the code-drawn version that read as a
  Polaroid camera. The kneel prop (`held_pack.gd`) is still a separate placeholder.
- Locked by `backpack_test` (mutation-checked: dropping the `advance_run` reset and the empty-junk rule each fail).
- Not built: a pack-less-run achievement, a corpse carrying its backpack (the next character just gets a fresh one),
  a rummage-sound / pickup-sound.

## Design notes
- **The player owns the state** (`pack_phase`: `""` / `kneel` / `open` / `stand`); the ring is a pure VIEW
  of it (`_process` shows it only in `open`), so it cannot desync, strand the game, or scale time. Any way
  out of play (death, a cutscene, escaping, a scene change) drops the ring within a frame.
- The ring reuses the quick wheel's geometry (`QuickWheel.index_for` / `slot_position`) and the block rules
  (`QuickWheel.ui_block_reason`, shared).
- Number keys 1-5 and Q still equip / use while kneeling; attack / push are the ring's clicks.
- `HUD.action_key_name(action, fallback)` names the CURRENT binding for any hint (the wheel hint uses it too).

## Placeholder art — what's needed
There is **no bend-down / open-pack animation** in the player's sheets. v1 fakes it: crouch pose + a lean +
a code-drawn pack. Real art wants a `kneel_down` (4-6 frames), `pack_open_loop` (rummaging, 4 frames),
`stand_up` (the reverse) and a proper pack sprite (closed / open) — drop them in `player.tscn` and swap
the `animated_sprite.play("crouch_idle")` calls in `Player._pack_tick` / `begin_pack`; the lean can then be
removed. The HUD button and the floor pack share the pixel `PackArt` drawing (`pack_art.gd`).

## Not built
- Drag-to-swap / reorder on the ring, and splitting stacks.
- A "quick-use" subset (the vision-board concept where favourites sit on the ring): the ring is the whole bag.
- ~~Removing the bottom strip~~ — DONE (owner round 26c): no bottom bar; the world fills the screen
  (`StairPan.HUD_BAR_H` 0). The hotbar itself is now hidden by default too (owner: "redundant if we have the wheel") — the pack IS the inventory,
  and the pack button is bottom-right; a loot item can be dragged onto it to take it.
- Stealth: opening the pack is silent. (A rummage noise is a possible cost.)
- A sound for the flap / the slam.

## The in-hand box (owner round 27)
The bottom-left "HAMMER 10 / 10 uses" text is gone. `hud_equip_box.gd` is a 76px BOX to the right of the name / mode /
stamina block: the equipped item's ICON inside an OUTLINE that is its durability — drained clockwise from the top as it
wears (green > 50% → amber → red, pulsing at the end), empty + red pulse when BROKEN; things that don't wear (a bandage,
a key) keep a calm full outline; empty-handed = the bare box. **The only number it ever shows is a gun's rounds**
("10/10" badge). Three shapes (`HUD.set_equip_box_style`: `square` / `rounded` default / `circle`); `scene_capture`
steps `eqstyle:` and `wear:` render them. Locked by `hud_wheel_test`.
