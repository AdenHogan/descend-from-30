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

## 2. REAL lighting — ceiling lamps, fire, player aura (NEW — replaces the flat filter)

The old flat colour "filter" is GONE. The world now has **actual 2D lighting**: a dark
ambient with warm ceiling lamps casting **downward CONES** (like the sun/a spotlight from
the fixture, not a round blanket), window daylight, fire, and a faint player aura. Lighting
is **intrinsic** — always on, varying by scene and run (no toggle). **Use the F1 dev menu →
"Set Run (time of day)"** to compare runs quickly.

- [ ] **Ceiling lamps** cast **CONE** pools that fan DOWNWARD from each fixture (brightest
      at the bulb, fading toward the floor + edges) — NOT a flat blanket over the scene.
- [ ] **Some cones SWAY** very gently side to side; some lamps **flicker**; some **BLINK**
      (a failing tube — on a while, brief dark stutters); some are **DEAD** (dark fixture).
- [ ] **Morning (run 1):** fairly lit. **Afternoon (run 2):** golden, dimmer, more lamps
      dead. **Night (run 3):** GENUINELY DARK — lit only by the cones, windows, fire and
      your aura; even MORE lamps dead. Scary, but you can still navigate the lit pools.
- [ ] **Enemies lurk in the dark at night** — a zombie outside any light is near-invisible
      until your aura/a cone reaches it (walk into one = jump scare). Confirm this reads as
      tension, not as a bug/pop-in.
- [ ] **Stairwell windows** cast natural daylight beside the stairs (warm by day, a dim
      blue MOONLIGHT at night). Same at each **apartment balcony window**.
- [ ] The lighting covers the **world only** — HUD, inventory, wallet, dialogue and
      listen overlays stay full-brightness and unshifted.
- [ ] Consistent across corridor, apartments, maintenance room, lobby, hallway (floor 30).
- [ ] During a **stair pan**, the next floor's lamps **scroll into view lit** (no pop-in
      of lighting at the commit); no jarring ambient seam (brief, if any — flag if ugly).
- [ ] **Fire throws real light** — an apartment/corridor blaze lights the walls and the
      player near it with a flickering orange glow, not just drawn flames. Bigger/reachier
      on a BLAZE than a LIGHT fire; winks out when the fire's put out.
- [ ] The **player aura** is FAINT by default — enough to read your own footing, not to
      light the room. Flag if it's too strong (washes out the dark) or too weak (can't see).
- [ ] **"Night Eyes"** merchant upgrade (in the pick-1-of-2 pool): after taking it, the
      dark is noticeably more visible on **run 3** (wider aura + lifted ambient). Verify it's
      worth a pick and that WITHOUT it night is meaningfully darker.
- [ ] Apartments have **no ceiling lamps** — at night they lean on the balcony window + your
      aura + anchor glow. Flag if it's too dark to scavenge (may need apartment lamps).

## 2b. Descent dimming (sectional identity via lighting)

Instead of a green tint, the DESCENT now dims the ambient and kills more lamps the LOWER
you go (the failing lower building) — tension + sectional identity through light.

- [ ] Floor 30 is the **best lit**; by the low floors (1–10) and the lobby the ambient is
      **darker** and noticeably **more lamps are dead/out**.
- [ ] The shift is **gradual** as you descend, not a hard jump between sections.
- [ ] Still **readable** at the deepest + night combination (dim but not black). Tuning
      lives in `WorldState.AMBIENT_BASE_BY_RUN` / `AMBIENT_DEPTH_DIM` and
      `floor_lighting.gd` (lamp count, energy, dead fraction).
- [ ] Later runs also kill more lamps (a floor at night has more out than the same floor
      in the morning).

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

## 4b. Three NEW enemy types (crawler / long-arm / spitter) — use F8

These read from the same escalation table, so they show up deep-and-rare in run 1,
climb by run 2–3. Fastest way to see them: **F8 to run 3, walk low floors (1–10).**

- [ ] **Crawler** — low to the ground, now **SLOW** (it drags itself), fragile,
      but its bite does **DOUBLE damage** — letting one reach you hurts. Common
      across the WHOLE building in run 1 (~1 crawler per 3 standards).
- [ ] **Hitting a low crawler connects** — a melee swing and a gunshot both land
      on it even though it's low (the hit targets its on-floor position, not the
      low sprite). Confirm it doesn't *feel* like swings whiff over it; if it
      does, that's a swing-animation feel issue, not a miss (flag it and we can
      add a low/impale/bludgeon animation).
- [ ] **Right-click on a crawler KICKS it** — it's rooted/stunned in place for a
      beat (no knockback, because it's on the ground), buying you time. Right-
      click on a normal zombie still SHOVES it back as before.
- [ ] **Long Arm** — normal speed, but lands its hit from further back than a
      standard (don't trust a one-step backpedal). A little tougher.
- [ ] **Spitter** — hangs back and SPITS a projectile that flies at you and hurts
      on contact; it doesn't rush into melee. The spit sprite reads clearly and
      flies the right direction; check it doesn't spam (there's a cooldown).
- [ ] All three **stand on the floor line** (feet grounded, no float/sink),
      including when they **scroll in via a stair pan** (no warp at the commit).
- [ ] Each **animates** (idle/walk/attack) and plays a **death** on kill; a
      damaged one you leave **comes back with the same HP** on re-entry.
- [ ] Balance gut-check: the new mix on run 2–3 low floors is a step up but not
      unfair. All prevalence is tunable in `WorldState`'s `*_CHANCE` tables.
- [ ] Art/scale sanity: none of the three look oversized/undersized next to the
      player and standard zombie (a look-only check headless can't do).

## 4c. Spread / variety by section (F8 through the runs)

The mix was tuned so it doesn't feel samey. Descending in run 3, watch for:

- [ ] **Low floors (1–10)** read as a **melee swarm** — crawlers and the odd big,
      up close and personal.
- [ ] **Mid floors (11–20)** lean on the **Long Arm** — the reach bruiser is the
      most common new face here.
- [ ] **High floors (21–29)** at night lean **ranged** — the Spitter is most
      common up top (it's rarest deep). Top vs bottom should feel different.
- [ ] A fight reads as a **mix** — you're not just fighting a wall of Big Zombies
      any more (their share was trimmed for variety).
- [ ] Runs 2 and 3 clearly have **more** new enemies than run 1, and they now
      reach the **middle and upper** floors, not just the bottom.

## 4d. Corridor bosses (runs 2 & 3 only)

Occasionally a floor sets a **roaming boss** loose — a tougher Big Zombie in the
corridor (tinted reddish so it reads as elite). Rare; more common on low floors.

- [ ] It's a **real wall of HP** — a proper fight, not a normal big.
- [ ] It drops **NO key**, but on death drops a **fat money bundle + one good
      item** (bullets / first-aid / a weapon / crowbar / extinguisher — a gun is
      the jackpot). Confirm the loot actually appears and is worth the fight.
- [ ] It **stands on the floor line** (grounded, no float), including scrolling
      in via a stair pan.
- [ ] Elite tint reads under all three time-of-day grades (morning/afternoon/night).
- [ ] Balance gut-check: a boss on top of the denser run-2/3 mix isn't unfair —
      `WorldState.BOSS_CHANCE` (how often) and the HP multiplier are one-line tunes.

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
