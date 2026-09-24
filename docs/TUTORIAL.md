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

> **Editing the dialogue:** every tutorial line lives in ONE place — the
> `LINES` dictionary at the top of `scripts/tutorial_manager.gd`. Rewrite the
> string values freely (keep the keys); nothing else needs touching. Keys are
> grouped by beat: `opener_*`, `3003_*`, `3002_entry`, `3004_hint`,
> `hall_*`, `stairs_*`.

## Opener (cold open — EVERY run, not just the first)
Gated by `WorldState.opener_seen` (reset by `new_game()` / `advance_run()` / F7, and SAVED, so
Continue never replays it). New Game fades the menu to black first, so the cold open starts
from black with no hard cut.
1. **Black screens** (`scripts/intro_overlay.gd`), each its OWN screen, over ONE bloody
   handprint that stays put through the title and the time card (owner's call):
   a. **Title** — «DESCEND FROM 30» in gory red, on its own (run 1 only).
   b. **Time card** — the big time-of-day word in its own colour (MORNING gold / AFTERNOON
      orange / NIGHT blue — the Transition time-card look the owner preferred) drifting up,
      with the character's name and the time subtitle under it.
   c. **The line** — on CLEAN black (the handprint fades out WITH the time card — owner: the red
      was overwhelming behind the text): a short loud burst of banging, then the character's
      line + [any key], a door-slam, then the black lifts on the hallway.
   A key during (a)/(b) hurries that screen to its fade (never skips it). Waits while a
   Transition still covers the screen. Runs 2/3 open on (b) — the death/escape end card hands
   straight to it (`Transition.to_run_start`), no separate time card.
2. **Visible lockout** (`hallway.start_opener_lockout()`): the player — on screen, not
   black — steps up and bangs on their own door 3001 (`player.knock_door`), gets no answer,
   and says the run's lockout lines (`hallway.opener_config()`): run 1 tutorial = remember the
   3003 spare key; run 1 without the tutorial = «no time for a spare key»; runs 2/3 = locked
   out + a nod to how the previous character's story ended.
Any key / mouse click advances every beat. SFX are placeholder impacts. See
THREE_RUN_ARC.md → "Run bookends" for the matching END card.

## Wall text (blood scrawl) — rules
- ONE `BloodText` node per hint (multi-line text, centred on the node), placed in a CLEAR wall
  gap between doors at door height (y ~314-346) — never across a door, never at the ceiling
  (locked by `run_bookends_test`). Current six: Move (3001↔elevator), Run (3002↔3001), Enter
  (3003↔3002), Listen (3004↔3003), Strike/Stance (3005↔3004), Rest (stairwell↔3005).
- Keys are LIVE: write `{action}` (e.g. `[{sprint}]`, `{move}`) and the wall shows the player's
  CURRENT binding (shortest label: `A`, `RMB`) — a rebound key never leaves the wall lying.
- Drawn SUPERSAMPLED with a thin outline so it's crisp at the ~2.75× game zoom (it used to be
  rasterised tiny then blown up — "hear" read "hoar").
- Prompt hints follow the same rule: any-key prompts say `[continue]`; teaching prompts name
  the real key (`TutorialManager.key(action)` → "Right-click", "Space").

## Stairwell gating + herding (1C)
(Simplified from the earlier 4-stage gate — this is what's built.) The Floor 30 down-stairwell
is HARD-blocked only until the 3003 spare key is in hand (`TutorialManager.stair_stage()`):
1. **"key"** — 3003 neighbour still up → «3003 isn't downstairs, I need the spare key» and
   herd the player to **3003's door**.
2. **"open"** — key in hand: the player MAY descend at any time. Descending is a ONE-WAY
   choice (end the tutorial early / leave apartments unsearched), so the first use of the
   stairs says «stairs_choice» and a second use within 4s commits (the descent is the
   seamless stair pan to 29, like any floor). On the first run 29 → 30 is refused
   («no_return»).

## 3003 — the scripted first apartment
Layout: living room / kitchen / bedroom (real anchored modules). This
apartment teaches, in order: **push (defence) → search → weapon → combat →
healing**. The whole sequence is a scripted state machine with gameplay
pauses at each teaching beat (`get_tree().paused` + a dialogue prompt).

1. **Enter.** The zombie stands **almost at the back wall** (the far wall
   from the door), idle, **facing the wall**. **Scavenge nodes are hidden.**
2. **Curiosity.** When the player is about a **quarter of the way into the
   final room** (~200px from her): dialogue «Mrs Delacroix…? Are you okay in
   here?» — and she **turns around** and starts closing at normal pace.
3. **The lunge.** The beat fires the instant she reaches attack range
   (30px — tight, so the taught push always connects) → scripted bite →
   **gameplay PAUSES** → prompt to **PUSH** («It's on me — shove it back!»).
   Push before any weapon exists (the defensive fallback).
4. **Player pushes.** Real knockback + a **double-length stagger** (~5s,
   twice a normal push) so the player can turn and start searching.
5. **Gameplay PAUSES** for dialogue «I need something to fight back with —
   search the room!». This turns the player toward scavenging.
6. **The three scavenge nodes reveal**, laid out **along the retreat path**
   (back → entrance), searched under pressure in this order:
   - Node 1 (met first, nearest the encounter) → **junk** (spikes panic —
     a wasted search as she nears).
   - Node 2 (mid-apartment) → **health item** (bandages / first aid).
   - Node 3 (nearest the entrance) → **golf club**, already **low
     durability**.
7. **Timed slow shamble.** After the stagger she pursues at a slow shamble
   (~35 px/s vs the normal 40), moaning as she closes — paced against three
   3s searches + walking + a little player thinking time (~17s), so she is
   **almost on the player seconds before the golf club comes up**.
8. **Gameplay PAUSES** for dialogue «Swing until it goes down.» →
   **scripted combat, NO RNG:** the 3003 zombie dies in **exactly 2 golf-club
   hits** (no knockdown/instakill rolls). 2 hits spends 2 of the club's uses.
9. **On death the zombie yields the key to 3002.** Now holding a low-durability
   club, dialogue prompts the player to **heal**: «I'm hurt — patch myself up
   with those bandages.» (introduces the heal/consumable flow).

## Golf-club durability risk/reward (tutorial-tailored)
- Tutorial golf club durability = **6 uses**. Budgeted across the whole path:
  - 3003 zombie = 2 hits → **4 left**.
  - 3004 **barricade removal = 2 uses** (tool-assisted) → **2 left**. This is
    deliberate — it teaches that durability also drains on barricades, not
    just on swings. (Remove it bare-handed to save the club, at the cost of
    time + stamina — an emergent option, not signposted.)
  - At the hallway choice the club is at **2**: **force the 3004 lock** (−1,
    take the room, ~1 use left) OR **fight the corridor zombie** (−2, the
    club **breaks**, room lost). Push is always the weaponless out.
- (Earlier design used 4 uses and exempted the barricade; bumped to 6 so the
  barricade's durability cost is visible while the choice stays a clean 2.)

## 3004 approach beat
- After 3003 is cleared, the first time the player walks past the still-
  barricaded 3004 the game **PAUSES** and they note it can be torn down —
  «probably faster if I pry at it with a weapon» — teaching the removal action
  and foreshadowing its durability cost. One-shot (`hallway.gd`).

## Forcing is channeled, not instant (game-wide)
- Forcing a **door** or a **lock** now takes **`FORCE_TIME` = 2s** (a heave,
  not a snap): a progress line counts down, it's loud from the first frame,
  and any other action (move/attack/push/switch/listen) or walking away
  **cancels** it with no durability spent. A key still opens instantly. This
  is general (`door.gd`), not tutorial-only.

## Hallway / stairwell scripted zombie (IMPLEMENTED)
- **Removing the 3004 barricade is the noise lesson**: every plank rip throws
  a **sharp orange jagged echo ping** at the door (the aggressive counterpart
  to the listen system's soft red ripples — noise is BAD), plus a burst on
  the final crash. `listen_overlay.noise_ping()` — reusable for any future
  "you are being loud" moment.
- Once barricade work starts, a zombie **walks in from the left stairs**
  (drawn by the noise), but **holds at a distance** (`tutorial_hold_x`),
  facing the player — visible menace, no pressure yet.
- The moment the barricade falls: **gameplay PAUSES** for the choice line —
  «this club's nearly spent, enough for ONE more job: force 3004 and take the
  room, OR put the thing down and take what it's carrying. Not both.» — then
  the zombie is released at a slow shamble:
  - **Force the 3004 lock** with the club (1 use → 1 left) → take the room,
    but too little club left to kill the zombie (2 hits needed).
  - **Fight the zombie** (2 hits → the club **breaks**) → 3004 stays locked,
    but the zombie **drops a Bank Notes bundle** — so fighting still pays out.
    The door-vs-enemy risk/reward is real; neither path is empty-handed.
  - **Push** remains the weaponless out either way.
- The zombie is scripted (deterministic 2-hit kill, no RNG), keyed
  `30hall:tutorial` so the kill persists.

## Apartment roles
| Apt | State | Tutorial content |
|---|---|---|
| 3001 | sealed | — (never enterable) |
| 3002 | locked (3003 key) | **reward room** — conservative loot only: cash (weighted heaviest), ice pack, first aid kit; NO weapons/keys/toolbox (nothing that defuses the club-durability lesson). Entry line is the earliest descent mention. |
| 3003 | open | scripted encounter; scavenge + attack info. **No descent talk here** — the kill dialogue is the key realization («this isn't my spare key — it's for 3002»). |
| 3004 | barricaded+locked | **no** info inside (optional, forced-entry loot) |
| 3005 | open | **guaranteed Hammer (002)** on the first run, so the player descends to 29 with a real weapon (their club may be broken/low). Interior info TBD. |

**First-run generosity:** the tutorial's scripted kind drops (3002 reward
pool, the 3005 hammer, the corridor zombie's cash) are all
`is_first_run`-gated. From run 2 on, Floor-30 apartments 3002–3005 are plain
RNG seeding like any other floor.

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
- **v2 (BUILT):** 3004 barricade → orange noise pings → corridor zombie with
  hold-then-release + the force-lock-vs-fight choice; staged stairs gate along
  the full path; 3002 reward room + entry line. **Remaining:** 3005 interior
  info; owner-authored final dialogue.
- Final dialogue/wall text is owner-authored; code ships placeholders.

## Transitions & depth (BUILT — was "planned")
- **Depth approach-walk** (`player.approach_door` / `knock_door`) — used by door entry and the
  opener knock.
- **Door enter/exit** fade (`Transition.to_scene`).
- **Seamless stairs everywhere**: every floor 30 → lobby pans (StairPan), no fade — see
  CLAUDE.md. The first-run 30 → 29 descent is a pan like any other.

## Testing the tutorial (DEV)
- **F7** toggles the first-run tutorial on/off and drops you into a fresh
  Floor 30 hallway so the change takes effect at once. Turning it **ON**
  resets the 3003 encounter (`WorldState.dev_reset_tutorial()`) so the
  scripted sequence replays from the top; **OFF** makes Floor 30 a normal
  procedural floor (no stairs gate, no scripted neighbour). Your inventory /
  wallet / upgrades are left as-is. Gated by `DEV_MODE` — off for release.
