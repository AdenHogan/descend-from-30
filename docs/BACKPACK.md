# The backpack — inventory you open with your hands (owner round 26)

> "a image of a backpack as part of the UI, click it and the player does a bend down and open their
> backpack animation followed by an opening of a sub menu scroll wheel for inventory with live gameplay
> underneath so you can still be attacked."

**BUILT v1** on top of the quick wheel. The HUD strip has a small pixel backpack right of the hotbar
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
removed. The HUD button is also code-drawn (`hud_pack_button.gd`).

## Not built
- Drag-to-swap / reorder on the ring, and splitting stacks.
- A "quick-use" subset (the vision-board concept where favourites sit on the ring): the ring is the whole bag.
- Removing the bottom strip (the camera still frames to it — `StairPan.HUD_BAR_H`); the hotbar is still
  there, the pack is an addition. Dropping the strip is a separate, larger camera change.
- Stealth: opening the pack is silent. (A rummage noise is a possible cost.)
- A sound for the flap / the slam.
