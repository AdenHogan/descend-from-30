# DF30 — Game Design Doc

> **Canonical, reconciled GDD.** Originally converted from `DF30__GAME_DESIGN_DOC.docx` (the owner's Word
> original, which describes the *early* game and is now historical). **Reconciled with the build on
> 2026-10-10** against the per-system docs and the CLAUDE.md status log.
>
> **How to read it.** Each section says what the game *is now*, tagged **BUILT**, **PARTIAL** or
> **NOT BUILT**, and points at the doc that holds the detail. Where the original GDD said something
> different, the change is recorded in [What changed since the original GDD](#what-changed-since-the-original-gdd).
> What is still to do (leaving narrative to the owner) is in [Outstanding work](#outstanding-work-non-narrative).
> When docs conflict: `STORE_DESIGN.md` and `THREE_RUN_ARC.md` supersede this file; this file supersedes
> nothing — it is the map, the per-system docs are the territory.

---

## 1. Game overview

**Working title:** Descend From 30 (studio credit: Mammoth Games).

A 2D side-scrolling roguelike set in a 30-floor apartment building during a zombie outbreak. The player
descends floor by floor, scavenging, avoiding or fighting what they meet, and spending a small, always-too-small
supply of stamina, items and nerve. **Pillars:**

- **Pressure, not power fantasy.** Zombies are slow but you are fragile; groups are to be avoided; every weapon wears out.
- **Cozy horror.** Warm lamp-light pools against a cool, deep dark; ordinary homes gone wrong. The look is
  *lit by real 2D lights* — the night run is near-black and enemies lurk unseen.
- **Three runs, one building.** A session is three characters over one persistently decaying building
  (morning → afternoon → night). Your earlier characters' choices, deaths and looting are still there for the next one.
- **Sectional identity.** The building is sicker the lower you go and worse the later you come. Floors 21–29 are a
  faded hotel, 11–20 residential, 1–10 institutional; the enemy mix, the dilapidation, the lighting and the
  growth all follow depth and run.
- **Sound is a mechanic.** Everything you do has a loudness; listening at a door or stairwell is the one thing eyes cannot do.
- **Every choice is a trade-off:** safety vs access, combat vs exploration, a key vs a slot, a weapon's last uses
  vs a barricade.

Tech: Godot 4.6, GL Compatibility renderer, GDScript. Targets keyboard + mouse, gamepad, and Android touch
(the owner playtests on an Android phone through the editor; an exported APK is untried).

## 2. Core loop and the session

**Per floor:** arrive → read the corridor (listen at doors and stairs) → decide which apartments to risk →
scavenge, fight, push past, or avoid → spend what you found (heal, repair, craft) → find the way down
(stairs, balcony, elevator) → descend. **Every 5th floor (25/20/15/10/5)** the merchant waits in the elevator;
**every 3rd floor (3…27)** has a maintenance room with a workbench and a fuse box.

**Per session (BUILT — `THREE_RUN_ARC.md`):**

| Run | Time of day | Notes |
|---|---|---|
| 1 | Morning | Bright, lighting barely intrudes; tutorial on Floor 30 (Joe, always). Rarer enemy types appear only on the low floors; no corridor bosses. |
| 2 | Afternoon | Dusk light; infestation has migrated upward; more locks gone, more breaches; fires have climbed a floor; corridor bosses begin. |
| 3 | Night | Near-black; storm; the worst of everything. Its character's end is the end of the playthrough. |

- A run ends when its character **exits through the lobby door** (escape) or **dies**. Either triggers the time
  skip (`WorldState.advance_run()`): a **fresh character** (inventory, health, stamina, wallet balance, boons wiped)
  inherits the **decayed world on the same master seed** — loot depletion, kills' aftermath, opened doors and fire
  scars persist; enemies re-shuffle; locks loosen; more breaches and barricades; fire climbs.
- A session casts **3 of 4 characters**, one per run, in a seeded order (Joe always opens the tutorial run).
  The session ends when the **third** character concludes; the end screen scores the whole playthrough and offers
  one permanent perk (see §5.6).
- Every run **ends** on a card (YOU DIED / YOU SURVIVED, with the run's stats) and **begins** with the same cold
  open: an exterior shot of the tower (three looks — morning / dusk / night — that show *this playthrough's* burnt
  floors), the time card, the character's own line, and the lockout at 3001. Loading a save replays the exterior
  in the save's run. (`OPENING.md`, `TUTORIAL.md`.)
- **Escaping** is a choice: at the lobby door the character *scraps their kit for Valour* or *leaves one upgraded
  weapon by the door* for a future game, then walks out into a white card. Tone: the ambiguous horror-movie ending.

## 3. Tutorial — Floor 30, first run only (BUILT; `TUTORIAL.md`)

Scripted, completable, mostly diegetic. 3001 is sealed forever; 3002 locked; 3003 open; 3004 barricaded + locked;
3005 open. Beats: cold-open lockout → the neighbour in 3003 is a **body that gets up** (a held cutscene, then the
lunge) → **push** → find a weapon (three hidden nodes: junk, bandages, a 6-use golf club) → deterministic 2-hit kill →
the neighbour drops the 3002 key → heal prompt → the **backpack** beat (the pockets overload, the pack is found) →
a stair gate (staged: key → apartments → barricade choice → open) → 3004's barricade is torn down (loud — a corridor
zombie comes from the left stairs and holds until it falls) → *force the lock vs. kill it and snap the club* → 3005
gives a guaranteed Hammer → descend to 29 (one-way on the first run).

- Prompts are player-speech dialogue (`HUD.show_dialogue`) and gameplay-pausing teaching beats
  (`TutorialManager`); every line lives in `TutorialManager.LINES`. Wall hints are handwritten blood-text
  (`blood_text.gd`), not popups.
- From run 2 Floor 30 is plain procedural seeding and carries the cold open only. All scripted drops are
  `is_first_run`-gated.
- The original GDD's "forced back to 3003 / forced damage / forced door choice" railroading was deliberately
  replaced by soft herding at the stairs plus the above beats.

## 4. Player systems

### 4.1 Movement, planes and stamina (BUILT)
Side-scroll walk / sprint / crouch on a fixed **feet line (419)**; **depth planes** the player steps between:
the **back plane** (step up to furniture in a flat), the **balcony plane**, and door approach / exit walks.
Stamina gates sprinting, pushing and melee; it is a modifier-fold stat (never written directly). **Rest (T):** once
per merchant-floor grant it refills stamina and *the building shifts* (enemies reseed); pried stairwell crossings cost
a rest slot (`STAIR_BARRICADES.md`). Click-to-move / click-to-scavenge, an approach-walk to doors, a Y-pin that
keeps the player on the plane, and an **anti-stuck valve** (holding into a body for 0.5 s phases you through it)
guarantee the player can never be walled in.

### 4.2 Combat (BUILT)
- **Melee** (hammer, golf club, katana, knife, etc.) — a landed swing costs 1 durability; reach is measured
  horizontally with a plane tolerance; hurt enemies blink and are passable but never immune.
- **Gun** — 8-round-per-slot ammo stacking, an 18-round magazine, a worn-mark system (8 marks, one per 6 rounds),
  reload-on-use, headshots, damaged-gun inaccuracy; gunfire is the loudest thing in the game.
- **Push** — shoves **one** enemy; the Big zombie is passable for a moment instead of stunned; anything that can
  strike you can be shoved and a shove opens the way through the crowd it was aimed into.
- **Throwables** — Canned Food (can), Empty Bottle (shatters), Molotov (item 039: bursts into a splash fire).
  Cans and bottles are noise-and-distraction tools; the Molotov is a weapon.
- **Crowds** fight from ranked positions, not one blob; the player can always fight their way through.
- Hits are not instant damage-to-death: the player has six visible health stages (Healthy → Dying), bites hurt,
  burning enemies hit twice as hard, and fire damages whoever walks (not sprints) through it.

### 4.3 Health and healing (BUILT)
Bandages, ice packs, first-aid kits, painkillers and food heal by amounts that upgrades modify. Health shows as a
portrait (four character sets × six stages) in the bottom-left.

### 4.4 Inventory, the backpack and crafting (BUILT — `BACKPACK.md`)
- **The backpack is an in-world item.** A new game's characters begin with **pockets only** (2 slots, one carried
  freely, a second overloads and halves max stamina) until the pack is found beside 3001 / in 3003; the pack gives **5
  slots + a locked 6th** (the Deep Pockets upgrade unlocks it). Once found it carries over to later characters in the playthrough.
- The pack opens by **kneeling**: a live (real-time) **ring** of the whole bag floats above the player — any hit
  slams it shut. Ring: click equip, right-click menu (Equip / Use / Drop), drag off the ring to drop, **drag one
  item onto another to craft** (Molotov = Empty Bottle + Torn Clothes; Rope = three Clothes). Items can be taken
  from a loot panel by double-click, E, or by dragging onto the pack button.
- **Item Codex** (journal tab): every item's durability and wear rules, a "???" until first found.
- 39 items (`data/Items.json` is the source of truth; `ITEMS_SHEET.md` is design reference), all with in-house 56×56
  icons and a hover tooltip.

### 4.5 Durability, repair and breakage (BUILT)
Weapons and tools wear and **stay as BROKEN items** (not deleted); a Toolbox repairs the first repairable item; forcing
doors and tearing barricades cost durability; a gun loses a mark per 6 rounds. In-hand box: a little vial whose smoky
colour is the held item's condition (green → red → grey).

### 4.6 The four characters (BUILT — `CHARACTERS.md`, `CHARACTER_STORIES.md`)
Joe (steady all-rounder; cheaper push + melee), Vivianne (endurance, quieter, slower sprint), Alex (exact hearing,
faster listening, cheaper melee — but ~20% more enemies), Amina (luck: better finds; −15% gun hit chance). Traits
are a modifier source in the same stat fold as upgrades. Each character **opens their run on their own cue and
carries a personal quest** (banner + journal). The cast/portraits/names are single-sourced in `WorldState`.

### 4.7 Controls, HUD and journal (BUILT — `CONTROLS.md`)
- One table (`scripts/input_scheme.gd`) builds the InputMap: keyboard + mouse, gamepad, Android touch, four bind
  slots per action, rebindable in Settings, **device-aware prompts** (`[{interact}]` tokens).
- No bottom bar: the HUD floats — portrait bottom-left with name / mode / stamina bar and the in-hand vial, pack
  button bottom-right, notes + scrap top-right.
- **Journal** (click the portrait / J): a worn journal of loose papers in each character's own handwriting — Story
  (profile, traits, the cross-run chronicle), Quests, Map (fog-of-war over 30 floors + lobby), Codex.
- Dev F1 menu (god mode, warp, spawn item, set run / hazard / health…).

## 5. Economy and progression (BUILT — `STORE_DESIGN.md`, `SCRAP_UPGRADES.md`, `PROGRESSION.md`, `PERKS.md`)

Five layers, all feeding **one stat fold** (`base × ∏mult + Σadd`, never direct writes):

1. **Bank Notes + Wallet.** Cash drops as notes; a Wallet item unlocks a counter; the balance is per-run, the
   unlock is cross-run. Dying leaves a **recoverable body** with your notes and kit for the next character.
2. **The Merchant** — one man, in the jammed elevator on floors 25/20/15/10/5 (sheltering when his floor burns).
   Each character's first visit to each merchant: a **pick-1-of-2 upgrade** (persists across the whole arc; a refusal
   needs a "you sure?" confirm), then a **pick-1-of-2 run boon** (temporary — this character only), then the shop
   (seeded stock, a Legendary hold, buy and **sell** 3 items per visit). ~30 upgrades incl. drawbacks.
3. **Scrap + the workbench.** Charred apartments are the main scrap faucet (a scrap node there reads "[E] Take" and
   needs no search); the maintenance-room bench levels a weapon (pick 1 of 2 per level), with seven levels
   (Lv4 Legendary, then Legendary + / ++ / +++), per-weapon **tuning** points, legendary names, **heirloom** tiers gated
   by lobby-door crossings, **special mods** (fire, wound, knockdown…), and **Salvage**.
4. **Run boons** — temporary, via the merchant.
5. **Descent Valour** (permanent, the owner's design) — at the session's end each run is scored by depth (+ escape bonus +
   what the kit scrapped for at the door); the player may buy **one** perk found that session, forever (max 10,
   tradeable for a 50% refund). Fortune's Favour tilts offers toward desirable perks.

The gun cabinet is an *unannounced* quest: a locked cabinet with a guaranteed Lv3 gun, its key carried by a tough
spitter in a breach room on the same floor, or pried with a crowbar.

## 6. Enemies (BUILT — `THREE_RUN_ARC.md` escalation table)

The original GDD described one zombie and "other types introduced later". Now:

| Type | Role |
|---|---|
| Standard | Slow, pressure in groups. |
| Big | Heavy; cannot be stunned; passable after a push. Corridor bosses (runs 2–3) are tougher Bigs that drop fat loot. |
| Crawler | Low, slow, fragile, double damage; **pounces**; "crawler nests" cling to walls/ceilings and drop. |
| Long Arm | Reach threat. |
| Spitter | Ranged, **kites**; crouching dodges the spit. |

- **Mix, not density:** per-(floor band × run) tables; the infestation **migrates upward** over the arc; LOW floors =
  the swarm, MID = bruisers, HIGH = ranged. A **run-opening grace** keeps floors 29–27 gentle every run.
- **Variants:** breach-room leaders (big / crawler nest / long-arm / spitter), **risers** (the dead who get up),
  **revenants** (a killed resident returns stronger in later runs), **stairwell enemies** (one population per staircase;
  rise head-first from the shaft), **followers** (the *same node* chases you across floors).
- Enemies fight on their own **plane** (floor vs. balcony), burn, remember their state across re-entry, and shuffle
  audibly. Placeholder art — all five share one rig (see Outstanding).

## 7. The world

### 7.1 Building and floors (BUILT)
30 floors + lobby, **corridor + 5 apartments** (Floor 30 has 4). **The whole building pans seamlessly 30 → lobby**
(no load screens): stairs pan between contiguous floors; the half-wall in a down stairwell can be **vaulted** (a hurt-risk
drop that lands on the floor below). Stair layout is a pure function of the floor.
- **Corridors** are painted per section / variant / dilapidation / run, dressed per floor (shoe racks, bikes, plants,
  notices), carry live **signs** (floor numbers, STAIRS, door plates), fire scars, wall **sconces** (the real light source),
  and horror marks that only accumulate across runs. Wall paper — memos, safety plates, missing flyers — is a shared kit.
- **Outside the windows** is one city (sky per run, towers, fires, blasts, pixel rain, parallax); the lobby door opens onto the street.
- **Overgrowth** follows depth and time (nothing wild above floor 12) — vines, ivy, ferns, moss, fungus; sways in the wind.

### 7.2 Apartments (BUILT)
Three modules side by side (bedroom, kitchen, bathroom, study, living room, dining room — **30 variants**, each with
run looks, lamps, live details like a dripping fridge or a TV, a window onto the city, a doorway saddle, and a back plane to step up to).
Layout is seeded and stable. **Searched furniture opens** (10 openings on the base modules). Burnt flats look burnt.
Rooms follow a **locked template** (`docs/blueprints/`) so outside artists can draw to it.

### 7.3 Doors (BUILT)
Open / locked (key) / weak (force, costs durability — a 2-second channel, loud from the first heave) / barricaded
(boards torn off one at a time) / breached (a torn-out doorway) — ten door styles by section. Door states decay across
runs (some locked flats open or barricade; more breaches).

### 7.4 Residents (BUILT v1 — `RESIDENTS.md`)
Survivors behind LOCKED doors: **scared** (run, cower, beg), **hostile** (square up, threaten, attack), **trader** (swap
offers). They shout, can be fought, die, and return as revenants. Their lines are the owner's, in `data/npc_dialogue.json`.

### 7.4b Survivors, allies and the smarter dead (BUILT v1 — `NPC_AI.md`)
People the building still has, placed by context: armed **defenders** holding a stairwell or a door in the corridor, **waiters** by the
lift (bang in threes — the dead hear it), **hiders** crouched at the back of walk-in flats. Every one perceives → decides one of a few NAMED
behaviours → acts, and shows a **tell** over its head (`!` alert, `?` search, `…` fear). They fight at **half the player's damage**
(derived from the player's own weapon tables) and the dead bite them for full damage — a survivor can die. The dead think a little too: a noise
tells them *where* (they investigate the source, search, give up), losing you sends them to your last-seen spot, a lunge alerts the dead beside
it, and they go for the nearer meal. Placeholder art and lines.

### 7.5 The dead and breach rooms (BUILT)
Breach rooms are "nests" with a story told in generated art (the door, the kill, the drag); an ordinary flat holds a body
10–22% of the time by run (searchable pockets); corridors have bodies; some bodies **rise**. Fire and breach rules agree
(a burnt breach has no boss).

### 7.6 Hazards (BUILT — `STAIR_BARRICADES.md`)
- **Barricade** — pry with a Crowbar (single-use, ~6 s, loud), both directions, costs a rest slot and shifts the building.
- **Horde** — a live-enemy stair block (v1; dev-cycle placeholder type).
- **Fire** — a spreading, deterministic sim that creeps within a run and **climbs the building across runs** (LIGHT →
  BLAZE → CHARRED), never self-extinguishes; Extinguishers (every floor) put it out for good; charred apartments are
  the scrap faucet; the building warns you; the merchant shelters; flames are the licensed craftpix art, cleaned.

### 7.7 Traversal (BUILT)
Stairs (pan), **balcony descent** (rope/clothes lash or a jump), **banister vault**, **elevator** (maintenance room
fuse box takes 3 fuses → single-use, 5-floor jump in an animated car; `MAINTENANCE_ELEVATOR.md`), the backpack kneel from any plane.

### 7.8 Light, time and atmosphere (BUILT)
Real PointLight2D lighting on a time-of-day ambient (morning near-fully lit, afternoon dusk, night near-black), sconces
that flicker / blink / die, window and balcony light-beams, a player aura, fire light, storm + lightning + thunder at night,
and descent dimming. Ambient animation (swaying plants, dripping, exit-sign decay) per `MOTION.md`.

## 8. Audio, listening and stealth (BUILT v1 — `SOUND_STEALTH.md`)

Sound lives under the hood: every action has a radius (crouch 45 → walk 120 → run 240 → forcing/barricade 420 →
gunshot whole floor). The one player-facing mode is **anchored Listen (R)** at an apartment door or down-stairwell: rooted ~3 s
in real time (any hit or movement cancels, no report), the world greys, red pings pulse faster the nearer the dead are,
and you get a deliberately vague report (a number only for Alex). The roaming "TLOU" listen mode was *dropped* by design.
Audio is CC0 / generated: footsteps, zombie shuffles, moans, glass, fire, storm, room hums, a tonal opening drone.

## 9. Risk and resource design

Keys cost slots, weapons are also tools, the last uses of a weapon are a decision, noise near stairwells pulls the dead
across floors, a rest costs a window of safety, fire is both a threat and the biggest scrap faucet, and fresh characters
start with nothing but what the earlier runs left behind. *Pressure, not power fantasy.*

## 10. State model

- **Per-run:** inventory, health, stamina, wallet balance, run boons, scrap, the personal-quest stage, `has_backpack`
  (carried over once found), follower, kills/looted tallies.
- **Cross-run (the arc):** `master_seed`, door states, loot depletion, world drops, fire scars + dealt-with sources,
  active merchant upgrades, wallet unlock, player corpses, run chronicle, map memory, revenants, gun-cabinet states.
- **Profile (forever):** Valour, permanent perks, the codex, taught hints, best depth, tutorial-completed.
- All saves go through `WorldState.data_dir()`; persisted dicts use string keys; world generation derives from
  `hash(master_seed + purpose + floor/apartment + current_run)`.

## 11. Quests (status)

The quest list (`QUEST_LIST.md`) is the **design**. The engine now has a **data-driven quest framework** (`QUESTS.md`: `data/quests.json`,
seeded sites, conversations with need-checked choices and effects, outcomes that change the place in later runs, a Quests journal page) with
two quests on it, plus *character personal quests* and *world encounters* that overlap others. Still open: quest-room reservation from the
reshuffle, achievements, and the other quests.

| # | Quest | Status |
|---|---|---|
| 001 | Old Lady Ethel | BUILT v1 — flat quest on the framework; supplied → the turned + a half-strength kit, mercy → she mourns, then a revolver (`QUESTS.md`); placeholder lines |
| 002 | The Shopkeeper (save him on 25) | PARTIAL — the merchant exists on 25/20/15/10/5 **unconditionally**; the elevator-doors rescue, the "dead shopkeeper" hard-run branch and its achievement are not built |
| 003 | The Babysitter | NOT BUILT |
| 004 | Power the Elevator | PARTIAL — the fuse/elevator **mechanic** is built as a system (maintenance room, 3 fuses, 5-floor jump); the maintenance-worker NPC encounter is not |
| 005 | The Prepper | NOT BUILT (a trader resident and a "safe rest spot" are different things) |
| 006 | Into the Breach | PARTIAL — breach rooms, leaders and keys are built, and the dead now go for the nearer meal (a survivor); the neighbour-to-save quest layout, its timer and its reward are not |
| 007–009, 011 | Stubs | Not designed |
| 010 | Johnny the Gun Guy | BUILT v1 — corridor quest on the framework; 10 bullets → a Durable Hand Cannon, 20 more → Waste Not or Johnny's Eye (`QUESTS.md`) |
| — | The Gun Cabinet (unannounced) | BUILT |
| — | Personal quests (Joe/Vivianne/Alex/Amina) | BUILT v1 — one hook each; later stages open |

## 12. Original demo scope (historical)

Original target: floors 30 → 28, one zombie, melee + push, inventory, bandages / weapons / keys, locked / forced doors,
a basic HUD — *excluding* advanced stealth, complex AI, multi-character, upgrades, narrative, quests, NPCs.
**Status:** exceeded on every line. Everything in the exclusion list is now built to some degree except a general
quest system and the deep narrative.

## What changed since the original GDD

| Original GDD said | Now |
|---|---|
| Death → new run from Apartment 3001 (Roommate ×2) | New run begins outside 3001 (never accessible) after an end card and a cold open; Joe's run is the tutorial |
| 4 inventory slots | **Pockets (2) until the backpack is found, then 5 + a locked 6th** |
| Upgrades "do not carry over"; choice of THREE; awarded every 5 floors | **Persist across the arc**; choice of **TWO**, from the **merchant** at 25/20/15/10/5 (+ boons, scrap upgrades, Valour) |
| Tutorial forces the player back to 3003 / forced prompts | Soft, diegetic herding + paused teaching beats |
| One zombie type | Five corridor types + bosses, leaders, risers, revenants, stairwell enemies, followers |
| Listen = a free roaming sound view ("full stealth postponed") | **Anchored R-listen** at doors and stairwells; noise model built; roaming listen dropped |
| Door states open / locked / weak / barricaded | + **breached**; ten door styles; per-run decay |
| Floor 30 has 4 apartments (tutorial fixed) | Same, first run only |
| Inventory items "weapons, keys, consumables" | + scrap, bank notes, crafting parts, ammo, throwables, fuses, 39 items |
| Session ends on lobby exit or death | Same, but only the **third** character ends it; a mid-arc death leaves a recoverable corpse |
| Healing via consumables only | Same, plus rest (stamina only — the building shifts) |
| Demo excluded multi-character / upgrades / NPCs / quests | Built, except a general quest system |

## Outstanding work (non-narrative)

*Excludes everything the owner is writing or deciding as narrative: dialogue and lore (the tutorial's final lines,
`data/npc_dialogue.json`, journal/story text, finder thoughts, the cat/scream/meow lines, time-card wording, item lore,
the quest stories themselves and their later stages). The quest **mechanics** below are engineering and are listed.*

### A. Gameplay and systems still to build
1. **More quests on the framework** (`QUESTS.md` — 001 Ethel and 010 Johnny are built) — quests 003, 005 and the mechanical halves of
   002 (rescue + hard-run branch), 004 (maintenance-worker encounter, ten-floor ride), 006 (save-the-neighbour timer); quest-room reservation
   from the building shift ("storied rooms" were never specified); a gamepad/keyboard way to pick a conversation choice; an **achievements**
   system (the shopkeeper hard-run and the pack-less "ultra difficult" run are both specced as achievements).
2. **Barricade-keeper NPC** — seeded groundwork only.
3. **Weapon content** — the **hammer upgrade tree** (placeholder; the owner is writing it), more special mods, merchant-sold
   pre-upgraded weapons, the tier-5 character "dismantle" perk.
4. **Hazards** — fire spreading from door frames onto corridor walls; fire on the ceiling (dropped); fire reacting to
   overgrowth; a fire-elemental enemy (art exists); the horde stair block's own enemy type and tuning; melee noise pulling
   enemies across floors (currently quiet by design); a balcony-route hint when a stairwell is blocked.
5. **Enemies** — a distinct boss silhouette/behaviour; per-type AI beyond the spitter's kiting, the crawler's pounce and the shared
   investigate / search / spot / prey layer (`NPC_AI.md`; no flanking, door-opening or fear of fire yet);
   **depth biomes** (30–21 Hotel, 20–13 Rot, 12–6 Green, 5–1 Nest, each with its own enemy variant — a proposal, nothing built);
   growth in stairwells, in-run growth, light/shade plants.
6. **Backpack** — drag-to-reorder and stack-splitting on the ring, a quick-use subset, a rummage noise cost, a corpse that
   carries its backpack, a **pack-less mode** (the "ultra difficult" run).
7. **Residents** — sounds, balcony-descent backdrop, searchable bodies, a held-weapon pose.
8. **Economy** — merchant stock / salvage worth for the Molotov, tooltip/hint wording for throwables, perk effects shown on
   durability in the Codex.
9. **World** — per-floor decals on the lobby; the lobby's city view; hallway/lobby stair-sign polish; other module variants
   beyond A getting openable furniture and front-layer window furniture; the cat in apartments / the lobby.
10. **Y_PLANES §9** — the agreed placement-grid overlay for positioning things (spec locked, not built).
11. **Arrival hitch** — `STAIRWELL_LAYERS.md` records a scene-load hitch on the fade path as still open. The seamless pan is
    now the main route down and I have not re-measured the hitch on either path, so treat it as unverified, not fixed.

### B. Art still placeholder or missing (see `ART_REQUIREMENTS.md`)
Player rig and animations (scavenge, listen/cup-ear, door knock, **kneel/open pack**, balcony lash — all stand-ins);
the standard zombie rig and **distinct silhouettes** for Crawler / Long Arm / Spitter (all five share one rig today) and
the Big/boss; the **merchant** and **resident** bodies (reuse the player/homeless sheets); the **game logo**; the three
**escape stills** (`assets/escape/escape_<time>.png` — the slot exists, nothing in it); a cat; the maintenance **bench**
art; the extra survivors the art brief anticipates (up to ~8, now 4); per-section **grotesque** environment + enemy art;
final fire/FX (impact puffs, muzzle flash). All in-house art (rooms, corridors, icons, openings, fire, wall paper) was
made to be replaced by an artist working from the locked templates.

### C. Audio
Replace the synthetic moans / gunshot / heartbeat with recorded SFX; an ambient building tone per time of day; listen
animation audio; resident voices; pack flap/slam, rummage, drawer/door-open sounds; an opening music cue.

### D. Platform and verification debt
- **Android:** the exported APK is untried (Godot export template, keystore, `gl_compatibility` on a device, low-end
  performance, haptics, `emulate_mouse_from_touch` device ids); touch sizes and `MIN_HOLD` are first guesses.
- **Gamepad:** never tested on a physical pad (stick feel, dead zones, glyph art, rumble).
- **Controls not built:** gyro (no aiming), a left-handed touch layout, per-button scaling, pinch-to-zoom.
- **Looks verified only headless / under xvfb** (need the owner's eye): the opening (three looks, garden, fog), wall art,
  openable furniture, burnt rooms, the journal, the pack ring, stairwell art, fire, corpse depth, the balcony, the touch
  layout, the HUD at the current zoom.
- **Balance needs a playtest:** scrap curve and Valour prices, upgrade / boon strengths, trait numbers, enemy tables, the
  molotov spawn weight, tutorial pacing, night visibility ("see in the dark" upgrades vs. a dark flat).
- **Stale docs:** the "Known-not-done" list in `PLAYTEST_CHECKLIST.md` described an older build (corrected alongside this
  GDD). `STORE_DESIGN.md`'s "out of scope v1: selling" and `MAINTENANCE_ELEVATOR.md`'s "open questions" were answered by
  later builds (selling, every-3rd-floor rooms, the clamped 5-floor ride) but their text was not edited.

### E. What is *not* outstanding
Core loop, the three-run arc, tutorial structure, all five enemy types, the economy stack, fire / barricade hazards,
traversal (stairs, balcony, banister, elevator), listening and noise, lighting and time of day, journal and chronicle,
controls for three input families, the opening and the run bookends, saves. The suite (66 headless tests) locks them.

## Doc map

| Topic | Doc |
|---|---|
| Three-run arc, time skip, escalation, fires, balcony | `THREE_RUN_ARC.md` |
| Currency, merchant, shop, corpse recovery | `STORE_DESIGN.md` |
| Scrap, workbench, tuning, heirlooms, salvage | `SCRAP_UPGRADES.md` |
| Boons, Valour, permanent perks (generated table `PERKS.md`) | `PROGRESSION.md` |
| Maintenance room, fuses, elevator | `MAINTENANCE_ELEVATOR.md` |
| Stair barricades, hordes, cross-floor noise | `STAIR_BARRICADES.md`, `STAIRWELL_LAYERS.md` |
| Backpack, crafting, codex | `BACKPACK.md` |
| Sound and stealth | `SOUND_STEALTH.md` |
| Tutorial | `TUTORIAL.md` |
| Characters, personal quests | `CHARACTERS.md`, `CHARACTER_STORIES.md` |
| Residents | `RESIDENTS.md` |
| Survivors, ally combat, enemy intelligence | `NPC_AI.md` |
| Quests (design / how they run) | `QUEST_LIST.md` / `QUESTS.md` |
| Controls (kb/m, pad, touch) | `CONTROLS.md` |
| Opening / exterior | `OPENING.md` |
| Items | `ITEMS_SHEET.md` (reference), `data/Items.json` (source) |
| Y planes and dimensions | `Y_PLANES.md`, `ART_REQUIREMENTS.md`, `blueprints/` |
| Environment systems | `OVERGROWTH.md`, `MOTION.md`, `OPENABLE_FURNITURE.md` |
