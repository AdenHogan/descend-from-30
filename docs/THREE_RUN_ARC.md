# DF30 — Three-Run Arc & Time Skip Overview

> Converted from `DF30__THREERUN_ARC.docx`.
> **Status:** agreed design, pre-implementation. Covers: run structure,
> time-of-day skip, escalation levers, world decay, fires, balcony descent,
> fresh-character state, victory conditions.

## The Arc

- **One gameplay experience = ALL THREE runs, not one.**
- Always three runs per session — a run ends when its character exits the
  lobby OR dies.
- Either ending triggers the time skip; the next character starts at
  Apartment 3001.
- Session ends when all three character stories have concluded.

**Run bookends (BUILT — owner: "a synergy for all three runs in how they begin/end"):**
every run ENDS and BEGINS the same way.
- **End card** (`Transition.end_card`): a slow fade to black, then **YOU DIED** (red) —
  "<name> fell on Floor N." / "…in apartment 1703 on Floor 17." / "…in the Lobby."
  (`WorldState.place_in_words`). Held, then cleared; the screen stays black while the run
  advances.
- **Escape (owner, BUILT):** at the lobby door the player presses **[E] Leave the building** (walking
  past no longer ends the run by accident) → THE DOOR choice (take everything / leave one item) → **steps up into the doorway** (the
  apartment-door depth walk) → the screen blooms **WHITE**: **YOU SURVIVED**, "<name> walked out
  into the <morning/afternoon/night>.", and a table of the run's stats (`WorldState.run_summary`:
  descended, time in the building, felled, searched, apartments looted, quests/residents aided if
  any, braved the unknown, this run's Descent Valour, the item left at the door) → **[continue]** (a key, or it moves
  on by itself after 20s — never a dead end) → white crossfades to **BLACK** and the next run's
  cold open begins (`Transition.survived_card`, `lobby_exit.gd`). **Tone (owner): the ambiguous
  horror-movie ending** — the hero is out, their fate uncertain. **The outside (slot built, art
  pending):** when `assets/escape/escape_<morning|afternoon|night>.png` exists, the white card
  dissolves into that painting of the world outside, lingers (~3.5s, a key moves on), then goes
  to black (`WorldState.escape_art`; brief in ART_REQUIREMENTS.md "Endings"). Once E is pressed the player is
  `escaping`: no hit, burn or dying countdown can kill them mid-exit (which would run the death
  AND exit flows together).
- **Cold open** (`intro_overlay.gd`, every run, once — `opener_seen` is reset by `new_game` +
  `advance_run` and SAVED), separate black screens over one bloody handprint: the game's
  **title** (run 1 only) → the **time card** (big MORNING / AFTERNOON / NIGHT in its own colour +
  the character's name + subtitle; the handprint fades out with it) → banging and the character's
  **line** on clean black → the visible
  **lockout at 3001**. (The end card hands straight to it via `Transition.to_run_start`;
  `to_run_shift`'s separate time card is no longer used between runs.) Run 2/3 lockout lines nod to how the
  previous character's story ended (fell / escaped). All lines: `TutorialManager.LINES`
  (`opener_*`, `run2_open`, `run3_open`, `run_lockout`, `run_after_*`, `end_*`).
  Config: `hallway.opener_config()`. Locked by `run_bookends_test`.

**Time skip (uniform, decided):**

| Run | Time of day |
|---|---|
| 1 | MORNING |
| 2 | AFTERNOON |
| 3 | NIGHT (hardest) |

Skip length does not vary with how far the previous character got — the
fiction is fixed time-of-day; the difficulty curve is authored, not emergent.

**Victory & the exit:**
- Reaching the lobby and exiting ends that character's story — success, not
  game end.
- **DESCENT BOON — DECIDED (owner) + BUILT:** the descent boon IS Descent Valour (escaping
  adds +10 to that run's Valour — docs/PROGRESSION.md), **plus THE DOOR** (owner, round 3 — "a
  little like the Arc Raiders safe pocket"): pressing to leave, the escaping character chooses
  (`handoff_ui.gd`, titled THE DOOR):
  - **Take everything and brave the unknown** → **+10 Valour** (`VALOUR_BRAVE_BONUS`, on top of
    the escape bonus; chronicle `braved`, `WorldState.note_braved`). Nothing to leave counts as
    taking everything; so does ESC/✕.
  - **Leave ONE item by the door** (`WorldState.leave_for_next`) — any weapon/item except keys and
    cash, with its FULL state (upgrade level, perks, durability — an upgraded legendary weapon
    carries over as-is). It is **stashed for a FUTURE GAME SESSION, never this one**: the
    session's later characters (runs 2/3) do NOT receive it. The stash lives in the **profile**
    (`carry_items`); the next game's `new_game` hands it to the shopkeeper (`handoff_items`), who
    hints at it in his greeting ("Somebody left something by the lobby door, a while back…
    Business first.") and gives it **free, right after that first visit's upgrade pick** (floor
    25; `shop_ui._give_handoff_gift`, `collect_handoff_gifts`). Never lost: a skipped floor 25 →
    the next merchant visit; full pockets → he keeps it till there's room; several escapes in a
    session → all stashed; still unclaimed when that next game ends → it rolls to the one after.
  - **No duplication:** the choice is held in `door_stash_pending` and only written to the profile
    (`commit_door_stash`) after `advance_run`, beside the save that drops it from the pockets. Quit
    during the white card → the last save still has it in the pockets, and it is not stashed.
  The white card lists "Braved the unknown" or "Left by the door: X (for your next game)". One item
  per escape — "reward but not too much reward". Locked by `progression_test` (incl. a real
  shop-screen run) + `run_bookends_test`.
- A character who exits takes their notes and inventory OUT of the building —
  no corpse, nothing to recover. **DELIBERATE:** escaping is the selfish
  outcome; dying reachable is the generous one. (See `STORE_DESIGN.md` —
  corpse recovery.)

## Sectional Identity (a design PILLAR)

The building should feel different by SECTION as well as by run — two axes of
identity that compound:

- **Down the building = more grotesque.** The infection has spread WORST to the
  lower floors, so as the player descends the world gets sicker and more decayed
  and the enemy make-up shifts. Floor 30 is near-clean; floor 1 / the lobby is the
  rotten heart of it.
- **Across the runs = worse everywhere** (morning → afternoon → night), the time
  skip layered on top.
- **Narrative will reinforce this in due course** (story beats tied to sections),
  and eventually **per-section GROTESQUE ART** (environment + enemy art that
  degrades as you go down).

**Built so far (v1):**
- **Real lighting + descent dimming** (`WorldState.ambient_color` /
  `apply_time_tint`, `scripts/floor_lighting.gd`): the old flat sickly-green "filter"
  was replaced with actual 2D lighting. The world CanvasModulate is the AMBIENT DARKNESS
  real lights punch through — morning fairly bright, afternoon golden, **NIGHT near-black**
  — and the DESCENT dims it further (more dead lamps + less ambient the lower/later you go).
  Ceiling lamps cast **DOWNWARD CONES** (spotlight cookie, not a blanket): some **sway**
  gently, some **flicker**, some **BLINK** (a failing tube), some **DEAD** — run 2 loses
  lamps, run 3 loses more. **Window daylight** (warm by day, blue MOONLIGHT at night) at the
  **stairwell windows** and each **apartment balcony window**. Fire is a real orange light;
  the player carries a faint **aura** that reveals lurkers. At night the scene is lit ONLY by
  these, so **enemies lurk unseen and jump-scare** when you walk into them. The merchant's
  **"Night Eyes"** upgrade widens the aura + lifts the ambient (see in the dark, most on run
  3). Lighting is **intrinsic** — always on, varying by scene and run (no toggle). Covered by
  `lighting_test` + `run_arc_test`. (Still a placeholder for eventual per-section grotesque
  ART, but now a lit atmosphere, not a tint.)
- **Enemy sectional flavour** (see escalation table below): LOW = melee swarm
  (crawler/big), MID = long-arm bruisers, HIGH = ranged spitters; the spitter inverts
  to favour the top so descending genuinely changes the threat.
- **Deeper = tougher** already: zombie HP scales up toward the lower floors
  (`_set_hp_from_floor`).

**Still to come:** per-section grotesque art (environment + new enemy TYPES — art-
gated); story/narrative section beats; possibly finer sections than the current 3
bands, and per-section behavioural intensity (aggression) once it can be playtested.

## Escalation Levers (Runs 2/3)

**Enemy VARIETY, not density:**
- Apartment population stays realistic — no cramming eight bodies into a flat
  because the run number went up. Hordes (breach rooms) are the exception and
  already exempt.
- New enemy types beyond zombie standard + Big Zombie (art-gated, future):
  - Run 1: rarer types appear only on very LOW floors
  - Runs 2/3: those types become frequent on UPPER floors too — the building's
    infestation migrates upward as time passes
- Long-term: not just zombies — other monster types as art allows.

**Spawn reshuffle:**
- Time skip re-rolls enemy spawn positions (building shift), EXCEPT storied
  rooms.
- Storied/quest rooms have their own persistent rules — future implementation,
  own doc.

**Loot depletion (mostly automatic):**
- World state persists: anchors emptied by earlier characters stay empty.
- Character 1 cannot open every door (locks/keys), so runs 2/3 inherit a
  partially looted building, not a stripped one.

**Door decay & access shift:**
- Runs 2/3 see MORE barricaded and breached rooms.
- Some previously LOCKED doors become open or barricaded — narrative
  fighting/attacks happened during the skip. Room access CHANGES across
  morning/afternoon/night; the map you learned is not the map you return to.

**Merchant:**
- Boon:trade-off ratio worsens per run — the night merchant offers nastier
  bargains (see `STORE_DESIGN.md`).

**Night (run 3) note:**
- Time-of-day implies lighting/visibility as a difficulty axis (dark floors,
  flashlight relevance). Scope TBD — flagged, not designed.

## Fires (New Hazard, To Add)

- Fires may break out on certain floors during time skips.
- Block access to rooms or whole corridor sections.
- Together with strong barricades, fires create floors that CANNOT be
  descended by stairs — forcing the balcony route.

## Balcony Descent (New Traversal, To Add)

**Mechanic:** rope/clothes used from a balcony to descend to the balcony
directly below.

**Purpose:** alternate descent when stairs are blocked (fire, barricade);
also a scavenger's shortcut trade-off.

**ARCHITECTURE REQUIREMENT — BALCONY COLUMN CONTINUITY:**
- Any apartment with a balcony room in slot N must have the SAME balcony room
  state in slot N of the apartment directly below (2603 slot 2 balcony →
  2503 slot 2 balcony).
- This is a **generation-order constraint**: balconies must be planned as a
  per-building COLUMN SEED decided before individual apartments roll their
  modules — apartments conform to the column plan, not the other way round.
- Must be built into procedural generation BEFORE more content assumes rooms
  seed independently; retrofitting vertical constraints later is misery.

**Descent mechanics (decided):**
- Rope is an existing scavengeable item and works alone. Clothes work too:
  THREE clothes items (separate slots) combine from inventory into a
  clothes-rope.
- At a balcony with rope/clothes-rope: send it down, climb to the balcony
  below. Costs stamina. LOW stamina = the player falls mid-slide and takes
  injury.
- The target apartment may contain enemies — listen mode applies before
  committing.
- Door state from the INSIDE: a locked door unlocks from within (never a soft
  block). A barricaded door is dismantled from the inside — needs a dismantle
  animation (art task).
- NO ROPE: the player can still jump. Serious injury guaranteed UNLESS
  mitigated by character stats (e.g. athletics — see character stats system)
  or fall-related upgrades.
- STAIRWELL JUMPING: same jump option at stairwells (escape
  fires/barricades/approaching enemies) — same injury rules.
- TABLED (liked, later): landing on an enemy group below cushions the fall
  and crushes them; listen mode turns "how many do I hear down there" into a
  real jump/don't-jump read.

## Fresh Character State

Starts with:
- Persistent upgrades (see `STORE_DESIGN.md`)
- Wallet unlock if earned (balance 0)
- Pre-provided character stats — the three characters differ statistically.
  System to introduce later, own design pass.
- Nothing else: no items, no notes.

Floor 30 after run 1:
- Tutorial is FIRST-RUN-ONLY. From run 2, Floor 30 is plain procedural
  seeding like every other floor (believed mostly in place already).
- Apartment 3001 is NEVER accessible, any run.
- Runs 2/3 inherit whatever state character 1 left: searched anchors, opened
  doors, corpses, world drops.

## Implementation Notes (rough order, post-merchant)

1. Run/time-of-day state in WorldState (`current_run` already exists; add
   `time_of_day` derived from it; palette/tint hook per scene) — **BUILT (v1)**.
   `WorldState.advance_run()` bumps `current_run` (cap 3, returns true when the
   arc is over), wipes the PER-RUN character (inventory, health, stamina, wallet
   BALANCE, follower, upgrade offers) and KEEPS the cross-run rewards (upgrades,
   wallet UNLOCK) + the decayed world (same `master_seed`). `time_of_day()` →
   Morning/Afternoon/Night; `apply_time_tint()` sets each world scene's ambient
   DARKNESS via a `CanvasModulate` (world only — never the HUD) that the real lights
   punch through — see "Real lighting + descent dimming" above.
2. Time-skip transition: on character end (death or exit), advance run,
   reshuffle spawn seeds (except storied-room flag, reserved), apply
   door-decay pass, roll fires — **BUILT (v1)**. Both endpoints wired:
   `lobby_exit.gd` (exit) and `game.gd::game_over` (death) set the finishing
   character's outcome, call `advance_run()`, and — unless the arc is over —
   `Transition.to_run_start(hallway)` (from the end card's black onto Floor 30's cold open,
   whose time card animates the time-of-day word + name + subtitle — see "Run bookends"). Death is no
   longer a session-end mid-arc; only the THIRD character concluding ends it
   (`game_over.tscn` now shows the three fates + a win/lose headline). Enemy
   positions reshuffle via a `current_run` salt in `building_floors._spawn_zombies`;
   fires climb automatically off `current_run`. Storied-room reserve: not yet.
3. Door-decay pass: seeded per (master_seed, run) — converts a fraction of
   locked→open/barricaded, adds breaches. Tuning table per run —
   `mutate_door_states_for_new_run()` exists and is now CALLED by `advance_run`
   (decays the doors the player left in place). Per-run tuning table: future.
4. Balcony column seed in generation + balcony descent (spec above, DECIDED)
5. Fire hazard objects: blocking volumes + visuals; floors flagged
   fire-affected at skip time
6. Enemy-type spawn tables per (floor band × run) — data-driven so new types
   slot in as art arrives — **BUILT (v1, mix only)**. `WorldState.HEAVY_CHANCE`
   is a 3×3 table [band][run] (bands LOW 1-10 / MID 11-20 / HIGH 21-29) giving the
   per-slot chance a corridor spawn is a HEAVY; `enemy_type_for(floor, spawn_key)`
   rolls it deterministically (backdrop == live, stable on re-entry, re-rolls per
   run). `building_floors._spawn_zombies` maps the result to a scene. Today the only
   heavy is the **Big Zombie** (settles at origin **374**, feet on 419 — its own
   line, not the standard's 370; `BIG_ZOMBIE_SETTLED_Y`); new art-gated types slot
   into the same table. Faithful to the migration model: heavies rare + LOW-floor
   only in the morning, reaching MID by afternoon, common even up HIGH at night.
   Density stays with `get_floor_zombie_count` (mix, not count — no cramming).
   **Three new types added** (Crawler / Long Arm / Spitter — art in `assets/Enemies/`),
   each with its own `*_CHANCE` table alongside `HEAVY_CHANCE` and its own scene/script
   (reskins of the standard AI; the Spitter adds a real ranged projectile).
   **Spread tuned for VARIETY + section flavour**: runs 2/3 carry more new enemies up the
   building; no type dominates; LOW reads as a melee swarm, MID as long-arm bruisers, HIGH
   at night as a ranged/spitter threat (the spitter inverts and favours the top). Run 1
   unchanged. **Corridor bosses (runs 2/3)**: a floor may hold ONE roaming tougher Big
   Zombie (`is_corridor_boss`) — NO key (guards nothing) but a fatter money bundle + one
   good-loot item (`BOSS_LOOT_POOL`); per (floor,run) via `floor_has_boss`.
   **Crawler redefined**: SLOW + fragile but DOUBLE-damage bite, and the run-1 swarm
   (~3:1 standards, whole building); a push on it becomes a KICK-STUN (can't be shoved
   back). Aim/hitbox verified height-independent (melee + gun target the on-plane origin),
   so low crawlers connect. Covered by `enemy_variety_test`. Still open: distinct AI per
   type beyond the reskin; a low/impale melee *feel*; a boss silhouette; storied rooms.
7. Descent boon on successful exit (design TBD)
8. Character stats system (own design doc first)

Out of scope here: storied/quest rooms (own doc), stealth/listen phase 2,
night lighting implementation detail.
