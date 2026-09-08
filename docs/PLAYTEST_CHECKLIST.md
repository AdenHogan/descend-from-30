# Playtest Checklist — Three-Run Arc, Time Skip & Enemy Variety

> Physical (in-editor) checks for the work that headless tests can't judge —
> visuals, feel, and balance. All logic is covered by `run_arc_test` +
> `enemy_variety_test`; this list is for the things only a human can see.
> Scope: the run-arc / time-skip / enemy-escalation session.

## How to trigger things (dev aids)

- **F8** — advance the run in place (1 → 2 → 3 → 1) and rebuild the current
  floor. Fast way to preview each run's **tint** and **enemy mix** without
  playing through. (Lightweight: it does NOT reset your character or play the
  title card — it's a world preview.)
- **Die** (God Mode off — toggle with the dev god key — then walk into a zombie)
  → triggers the REAL time skip: the MORNING/AFTERNOON/NIGHT title card, a fresh
  character, and the decayed next run. This is how to see the transition itself.
- **Reach the lobby and step out** → same real time skip (the "survived" path).
- Only the **third** character dying or exiting ends the session (the arc-end
  screen). Runs 1 and 2 always hand over to the next character.

## 1. Time-skip title card (die or exit to see it)

- [ ] Fading to black is slow enough to read as "time passing," not a hard cut.
- [ ] The big word reads **MORNING → AFTERNOON → NIGHT** in the game's pixel
      font, drifts up as it fades in, and holds long enough to register.
- [ ] The subtitle line under it is legible and sensibly timed.
- [ ] The word's colour suits the time (gold morning → orange afternoon → cold
      blue night) and the outline keeps it readable over black.
- [ ] It fades cleanly into the new Floor 30 (no flash of the old scene, no
      lingering text).

## 2. Time-of-day world tint (use F8 to compare runs quickly)

- [ ] **Morning (run 1):** near-neutral, faint warm daylight — basically how the
      game looks today.
- [ ] **Afternoon (run 2):** noticeably golden/amber, lower-sun feel.
- [ ] **Night (run 3):** cool blue and dimmer, but the art is still readable
      (it's a colour grade, NOT a darkness/visibility mechanic yet).
- [ ] The tint covers the **world only** — the HUD, inventory, wallet, dialogue
      and listen overlays stay full-brightness and unshifted.
- [ ] Tint is consistent across corridor, apartments, maintenance room, lobby,
      and the hallway (floor 30).
- [ ] During a **stair pan** between floors, no jarring tint seam as the next
      floor scrolls in (brief, if any — flag if it's ugly).

## 3. Fresh character / persistence across the skip

- [ ] New character starts at **Floor 30** with an **empty inventory**, full
      health, wallet **balance 0**.
- [ ] **Upgrades you earned persist** (check an active upgrade's effect carries
      over) and the **wallet stays unlocked** if you'd unlocked it.
- [ ] The building is **recognisably the same** (same seed) but **decayed**:
      some doors changed state, more breaches. The map you learned isn't quite
      the map you return to.
- [ ] **Loot you already took stays taken** — previously emptied anchors are
      still empty in the next run.
- [ ] Enemies are **back and in different spots** (a fresh infestation), not the
      corpses you left.

## 4. Enemy variety / escalation (heavies = Big Zombie) — use F8

- [ ] **Run 1:** heavies are **rare and only deep** (floors ~1–10). Upper and
      mid floors are standard-only. NOTE: this is the ONLY change to run 1 — if
      run 1 feels harder low down, that's the 6% heavy chance on floors 1–10.
      (Tunable in one place: `WorldState.HEAVY_CHANCE`.)
- [ ] **Run 2:** heavies reach the **middle floors** and are a bit more common
      low down.
- [ ] **Run 3:** heavies appear **even on the top floors** and are common deep —
      the infestation has climbed.
- [ ] A corridor Big Zombie **stands correctly on the floor** (feet on the
      ground line, not floating or sunk) — including when it first **scrolls in
      via a stair pan** (no warp/pop onto the floor at the commit).
- [ ] A Big Zombie you damaged and left **comes back with the same HP / spot** if
      you re-enter the floor (memory works for heavies too).
- [ ] Density still feels realistic — heavies **replace** standards, they don't
      pile on top (no cramming).
- [ ] Big Zombies fight/behave normally in the corridor (attack, push, burn in
      fire) — nothing breaks vs. their breach-room behaviour.

## 5. Arc-end screen (only after run 3 concludes)

- [ ] Dying as the 3rd character → headline reads **YOU DIED** (or the "takes
      its due" line if earlier characters survived).
- [ ] Exiting the lobby as the 3rd character → **YOU MADE IT OUT**.
- [ ] The three fates list shows **Morning / Afternoon / Night → Escaped / Fell**
      correctly for how each character ended.
- [ ] "Return to Title" works and a fresh New Game starts a clean arc.

## 6. Earlier-today fix worth an eye (stair-enemy pan-pop)

- [ ] A stairwell enemy on the **next** floor **scrolls into view during the
      pan** rather than popping in when the floor commits.
- [ ] No doubled stairwell enemies on a floor reached by stairs.

## Known-not-done (don't flag these)

- Night is a colour grade only — no real darkness/flashlight difficulty yet.
- No brand-new enemy TYPES yet (heavies = the existing Big Zombie); the table is
  ready for new art to slot in.
- No descent boon on a successful exit yet; no player-corpse recovery yet.
- Storied/quest rooms are not reserved from the reshuffle yet.
