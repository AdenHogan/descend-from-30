# DF30 — Game Design Doc

> Converted from `DF30__GAME_DESIGN_DOC.docx`. Some sections are superseded by
> later docs — see [Superseded decisions](#superseded-decisions) at the bottom.

## Game Overview

**Working title:** Descend From 30

2D side-scrolling roguelike set in a 30-floor apartment building during a
zombie outbreak. Player descends floor by floor, scavenging, avoiding or
engaging threats, and managing limited resources.

## Core Loop

- Start on a floor → explore corridor + apartments → make risk decisions
  (fight, loot, avoid) → gather items → reach stairwell → descend → repeat
- Death results in a new player run from Apartment 3001 (Roommate ×2) and a
  time skip.
- Time skip creates new permanent changes to the building, increasing
  difficulty.
- **Three player characters total per full game session.**
- Game session ends when all three player character stories either:
  - End when reaching the lobby and exiting the building
  - End when characters die during the run

## Tutorial Flow (Floor 30)

- Start outside Apartment 3001 (locked, no return)
- Player guided to 3003 (open door, first entry)
- If player continues along Floor 30 to stairs, they are forced back to 3003
- Press **R** to listen outside 3003 — player hears strange noises
- Press **E** to enter 3003
- Inside 3003:
  - First zombie encounter (no weapon → forced damage)
  - Introduce push mechanic (defensive action)
  - Introduce item search (drawer → bandages)
  - Introduce inventory
  - Introduce weapon (cupboard → golf club, durability system)
  - Combat tutorial (kill zombie, durability decreases)
  - Healing tutorial (use bandages)
  - Find apartment key for 3002
- Exit apartment:
  - Door interaction (open/close choice)
  - Player regains control (no more forced prompts)
- Guidance:
  - Suggest elevator → non-functional, player suggests taking stairs
  - Redirect to stairwell (left side opens)
  - Player is suggested to search other apartments
  - Use key to unlock 3002
  - 3004 has a locked door and is barricaded, but the lock can be broken with
    a melee weapon after the barricade has been taken down
  - 3005 is open
- End tutorial:
  - Player descends to Floor 29
  - Future runs remove tutorial prompts but keep structure
  - (Per Three-Run Arc doc: tutorial is FIRST-RUN-ONLY; from run 2, Floor 30
    is plain procedural seeding. Apartment 3001 is never accessible, any run.)

**Diegetic control hints (implemented):** instead of popup boxes, the
controls are scrawled on the corridor/apartment walls **in blood**
(`blood_text.gd` — styled Label + procedural drips). `tutorial_hints.gd`
holds the placement data and pulls key names live from `SettingsManager`
(a rebind updates the wall text). Gated to `is_first_run` + Floor 30
(hallway) / tutorial apartments (rooms). Positions are constants, tune in
editor.

## Player Systems

**Movement:** 2D side-scrolling traversal

**Combat:**
- Melee (e.g. golf club)
- Ranged (e.g. guns)
- Push mechanic for defense

**Health:**
- Player can be damaged (zombie bite & attacks from other humans)
- Healing via consumables (bandages, food, first aid kits)

**Inventory:**
- Limited slots force trade-offs (no hoarding)
- Items include weapons, keys, consumables
- (Current build: 5 slots + locked 6th — GDD's original 4 is superseded)

**Durability:**
- Weapons degrade with use
- Can break completely (e.g. forced entry)

## Enemy Design (Initial)

Zombie (base type):
- Slow approach
- Damages player on contact
- Can be pushed back
- Requires multiple hits to kill
- Becomes dangerous in groups (3+ = avoid)
- Focus: **pressure, not power fantasy**
- Other zombie types introduced later (see Three-Run Arc: variety escalation)

## World Systems

**Building:**
- 30 floors
- Each floor = corridor + 5 apartments (Floor 30 has 4 available apartments)
- Apartments are modular and procedurally generated per run
- Layout persists within a run (re-entering retains same layout)

**Doors — states:**
- Open
- Locked (needs key)
- Weak lock (can be forced with eligible weapons/tools at the cost of durability)
- Barricaded (inaccessible)

**Player choices:**
- Use key (recovered item from apartments, costs inventory slot)
- Force entry on weak lock (destroys or damages weapon)
- Taking items from the game world means subsequent player characters lose
  access to those items

## Audio / Listen System (Phase 1)

"Listen" (**R** key near doors):
- Screen desaturates
- Audio intensifies
- Visual sound indicators (subtle, vague)
- Color indicators (red sound waves)
- Gives a hint of danger behind door (not exact info)

Note: full stealth + active listening system is postponed.

## Risk / Resource Design

- Weapons can also be tools (e.g. breaking doors)
- Using them reduces durability (broken weapons are lost)
- Keys take inventory space
- Encourages constant trade-offs: safety vs access, combat vs exploration

## Demo Scope (Original Target)

Playable floors: 30 → 29 → 28. Include: full traversal between floors,
persistent apartment generation, basic enemy (zombie), basic combat
(melee + push), inventory system, item interaction (bandages, weapons, keys),
door interaction system (locked / forced), basic HUD (health + inventory).

Excluded at the time: advanced stealth, complex AI, multi-character system,
upgrades, deep narrative, quests, NPCs. (Several of these are now in
development — see the other docs.)

## Superseded decisions

Recorded in `STORE_DESIGN.md` ("GDD conflicts to reconcile"):

| GDD said | Superseded by |
|---|---|
| Upgrades "do not carry over" between characters | Upgrades **persist across all three runs** |
| Choice of THREE upgrades | Choice of **TWO**, from the merchant |
| Upgrades awarded automatically per 5 floors descended | Offered **by the merchant** at floors 25/20/15/10/5 |
| 4 inventory slots | Current build is **5 + locked 6th** |
