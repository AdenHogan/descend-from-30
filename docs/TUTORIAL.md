# DF30 — Floor 30 Tutorial (scripted, first run only)

> **Status: agreed design (owner spec, this session).** Supersedes the loose
> "Tutorial Flow" in GAME_DESIGN_DOC.md. Placeholder dialogue text is
> written by code for now; the owner rewrites the final lines later.

## Principles
- **Diegetic + guided (1C):** the player is gently herded, not free to skip.
  Control teaching is blood-text on the walls (see `blood_text.gd`); story
  beats and nudges are **player dialogue prompts** (first-person one-liners).
- **Deterministic, not RNG:** tutorial combat is hand-tuned so the pacing
  always lands (fixed hit counts, fixed durability). No luck in the tutorial.
- First run only (`WorldState.is_first_run`). From run 2 Floor 30 is normal.

## Player dialogue prompts (new system)
A small first-person speech line shown briefly (own UI, not the wall text).
`HUD.show_dialogue(text)` / driven by the tutorial state machine. Placeholder
lines below in «guillemets» are temporary.

## Stairwell gating + herding (1C)
- The Floor 30 down-stairwell is **blocked** until the tutorial's core is
  done (player has the 3002 key = cleared 3003).
- If the player approaches the stairs while blocked: dialogue «Maybe the
  neighbour in 3003 has a spare key — I should check.» and they are **herded
  back** (nudged away from the stairwell).
- Once unlocked, descent to Floor 29 works normally and ends the tutorial.

## 3003 — the scripted first apartment
Layout: living room / kitchen / bedroom (real anchored modules). This
apartment teaches, in order: **push (defence) → search → weapon → combat →
healing**. The whole sequence is a scripted state machine with gameplay
pauses at each teaching beat (`get_tree().paused` + a dialogue prompt).

1. **Enter.** The zombie is at the **BACK / far end** of the apartment
   (far from the door), idle. **Scavenge nodes are hidden.**
2. **Curiosity.** As the player moves in, dialogue «Mrs Delacroix…? Are you
   okay in here?» — the neighbour, not yet understood as a threat.
3. **The zombie sees the player and closes the gap.** When it gets **too
   close it attacks** → **gameplay PAUSES** → prompt to **PUSH**
   («Get it off me — shove it back!»). This introduces the **push mechanic
   before any weapon exists** (the defensive fallback).
4. **Player pushes.** The tutorial zombie **freezes longer than a normal
   zombie** (bigger recovery window) so the player gets breathing room.
5. **Gameplay PAUSES** for dialogue «I need something to fight back with —
   search the room!». This turns the player toward scavenging.
6. **The three scavenge nodes reveal** (searched under pressure, in this
   intended order):
   - Node 1 → **junk** (spikes panic — a wasted search as it nears).
   - Node 2 → **health item** (bandages / first aid).
   - Node 3 → **golf club** (the weapon), already at **low durability**.
7. **Timed slow approach.** After the push-freeze the zombie resumes but
   moves **slowly**, moaning as it closes — paced so the player has time to
   search **each** node in turn. On picking up the **golf club** the zombie
   is **still not very close**.
8. **Gameplay PAUSES** for dialogue «Swing until it goes down.» →
   **scripted combat, NO RNG:** the 3003 zombie dies in **exactly 2 golf-club
   hits** (no knockdown/instakill rolls). 2 hits spends 2 of the club's uses.
9. **On death the zombie yields the key to 3002.** Now holding a low-durability
   club, dialogue prompts the player to **heal**: «I'm hurt — patch myself up
   with those bandages.» (introduces the heal/consumable flow).

## Golf-club durability risk/reward (tutorial-tailored)
- Tutorial golf club durability = **4 uses**. Each melee hit spends 1.
- 3003 zombie = 2 hits → club at 2 uses left.
- A second scripted zombie (below) also dies in 2 hits → the club **breaks**
  on that kill.
- Forcing a lock costs **1 use**. So the player faces a real choice with the
  ~2 remaining uses: **kill the hallway zombie (club breaks)** OR **force a
  locked door** (leaves too little to fight). This is the durability lesson.

## Hallway / stairwell scripted zombie
- After the player **removes the 3004 barricade** (loud — this introduces the
  **noise mechanic**), a zombie **spawns at the stairwell** (flavour: it came
  up the stairs, drawn by the noise) and approaches — arriving **after** the
  barricade is down so the player has time to choose:
  - **Force the 3004 lock** with the club (1 use) → enter 3004 for optional
    starter loot, then deal with the zombie (push / a weapon found inside).
  - **Fight the zombie** with the club (breaks if at 2 uses) → then can't
    force the lock; must push past or use another weapon.
  - **Push past** either way — push is always the weaponless out.

## Apartment roles
| Apt | State | Tutorial content |
|---|---|---|
| 3001 | sealed | — (never enterable) |
| 3002 | locked (3003 key) | tutorial info inside — **TBD** |
| 3003 | open | scripted encounter; scavenge + attack info |
| 3004 | barricaded+locked | **no** info inside (optional, forced-entry loot) |
| 3005 | open | tutorial info inside |

## Mandatory path
Hallway (movement text) → 3003 (scripted: see zombie → weapon → kill → key)
→ 3002 (unlock, scavenge, info) → 3004 (remove barricade → noise + stairwell
zombie → choice) → 3005 (open, info) → stairs unlock → descend to 29.

## Implementation staging
- **v1 (this pass):** dialogue-prompt UI (`HUD.show_dialogue`); TutorialManager
  (state machine, autoload, first-run/floor-30 only); stairs gate + herding;
  3003 scripted encounter — back-spawn idle zombie; curiosity dialogue;
  attack → **pause → push intro** → longer post-push freeze; **pause →** "find
  a weapon" → delayed 3-node reveal (junk/health/club); timed slow approach;
  **pause →** "attack" → deterministic 2-hit zombie; low-durability club;
  key on kill; **pause →** heal prompt.
- **v2 (next):** 3004 barricade → noise → scripted stairwell zombie + the
  force-lock-vs-fight choice; 3002/3005 interior info; descent-unlock wiring
  to the full path.
- Final dialogue/wall text is owner-authored; code ships placeholders.
