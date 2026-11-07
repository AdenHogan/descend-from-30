# DF30 — Stealth spaces: cover, hiding, and what each Y plane means

> **Status: owner round 49o, 2026-11-07. Phase 1 (hiding + the noise it is tied to) is BUILT; cover (creeping behind furniture) is phase 2, designed, not built.**
> Owner's words: *"wire in more stealth interactions… additional Y planes for moving into environments… moving in crouch behind furniture like moving behind a sofa in order for enemies to not see the player and move past, giving the player more room. Same with hiding. When a player hides in a stealth spot, the screen should go very washed out and dark, with only the player really being visible, then the enemy passing the player which we can see, but once it moves past the enemy is washed out faded just like everything else. We can even zoom in on the player during this effect so it looks claustrophobic."* Then: *"because of this, we may need more contextual elements to the various Y planes"* and *"a prompt appear for those areas where the player can hide."*

Then: *"stealth, hiding and noise are intricately linked, so this is the point where all of that needs to work well together. For example, if a player enters a module and immediately has a hide prompt to hide against the module wall, enemies can move past; when the player leaves the hiding spot they may need to crouch and move quietly, otherwise their noise of regular movement will alert those same enemies, who will then turn around."*

This extends `SOUND_STEALTH.md` (noise) and `NPC_AI.md` (what the dead perceive). It does not change the noise radii.

## 1. What is true today (read from the code, not remembered)

- The dead see by a **radius**: `distance <= detection` (standard 100, big 130 ± 45; `enemy_zombie_standard.gd` ~1358, `enemy_zombie_big.gd` ~508). No facing, no line of sight, no crouch modifier. A loud noise or an `alert_timer` raises it to 2000 (omniscient) unless the noise carried a source (round 39: then it walks to the source, looks about for 4 s and gives up — `EnemyMind`).
- Crouch only shrinks the **noise** you make (radius 45 while moving). It does not make you harder to *see*.
- Planes that exist: the **lane** (feet 353 in a flat, 419 in a corridor), the **back plane** (feet 339, `back_plane_spot.gd`: step up to search set-back furniture; enemies still see and reach you), the **balcony** (feet 319, its own enemy plane, `enemy_plane.gd`).
- Hiding places exist as art but not as a mechanic: planned wardrobes / cupboards open when searched; every bed has the `underbed` gap.
- The lift, doors, bodies, drops… all answer `[interact]` through `InteractArbiter` (round 49n): the nearest wins.

## 2. The plane context table

The owner's point: a plane is not just a Y value. Each one needs the same set of answers, kept in ONE place so a new plane cannot forget one. (`scripts/stealth.gd` `PLANES` is the single source; this table is its prose.)

| Plane | Where | Feet | How you get there | Do the dead see you? | Can they reach you? | Your noise | Screen | Prompt |
|---|---|---:|---|---|---|---|---|---|
| **Lane** | everywhere | 353 / 419 | default | by radius, as today | yes | by gait | normal | doors, lifts, bodies (arbiter) |
| **Back plane** | set-back furniture with a live node | 339 | `[W]` in scavenge mode | yes | yes (a step back, not a hiding place) | scavenge | normal | tutorial arrow only |
| **Balcony** | study / dining balcony | 319 | `[W]` | only the dead on the balcony | only the dead on it | — | normal | standing pill (round 49c) |
| **Cover** *(phase 2)* | behind a low piece ≥ 30 px tall (sofa, bed, table, sideboard, chest, desk) | ~335 (lane − 18, behind the piece's base) | crouch + `[W]` at the piece | **no** — the piece blocks sight; revealed only inside `COVER_REVEAL` (24 px) of the dead, or if you stand / sprint / strike | they walk past on the lane; if one finds you it is on top of you | crouch (45 px) | slight desaturation, nothing else | **"Duck behind the sofa  [W]"** |
| **Hidden** *(phase 1)* | inside / under: wardrobe, cupboard, under a bed | on the piece | crouch + `[W]` at the piece | **no**, at all — but see §4 *finding* | no, until found | none (still) | **washed out, dark, zoomed, spotlit** (§5) | **"Hide  [W]"** |

Contextual elements every plane must state (the checklist for the next plane someone adds): *entry verb · exit verb · what blocks sight · what the dead can still do · noise · camera · prompt text · draw order against the furniture · what ends it (a hit, a noise, a scene change, death) · how a save treats it (always on the lane — `lane_position()`).*

## 3. The prompt (owner: "a prompt appear for those areas where the player can hide")

A **standing world pill** (the same `HUD.show_world_prompt` the balcony uses) appears whenever a hiding place is in reach and the player is not already in it:

- crouched: `Wardrobe   [W] Hide`
- standing: `Wardrobe   crouch [C] to hide` (the verb is taught by the place, not a tutorial)
- refused while seen: the pill turns to the red refusal line *"They're looking right at me."*
- inside: `[W] / any move  Come out` (shown small, never in the way of the washed-out view)

**The wall nook** (owner's example): every live, ordinary flat has a hiding place by its front door — `Against the wall   [W] Hide` — and it sits 8 px inside the arrival point, so the player is in its reach, and the prompt is up, **from the first step in**. It is a bare wall in the dark, so coming out of it makes no noise (a wardrobe's door does).

Keys are written as `{action}` tokens (never literal `[W]`), so the pad / touch prompts follow (`docs/CONTROLS.md`). Where a hide spot and a search node share a wardrobe, **search wins in scavenge stance while the node is still live** (`back_plane_spot` already owns `[W]` there); hiding is for combat stance or a searched-out piece. If the owner wants hiding to win, the dial is `StealthSpot.yield_to_search`.

## 4. The rules (phase 1: hiding)

1. **Enter** (`[W]` crouched at a hide spot): refused while any dead thing is *looking for you right now* — state `chase` / `attack` within `SEEN_RANGE` (260 px) — with the red line above. You can hide from the ones that have **lost** you.
2. **While hidden** the dead cannot *see* you at all: `Stealth.sight_blocked` turns their detection to −1 and their reach to INF in the same two places the radius lives (standard + big; spitter / crawler / long-arm inherit). A follower that walks in locked on to you (`alert_timer`, the 2000 omniscient case) is blinded too, **and its lock-on ENDS** (`Stealth.lose_track`): it looks about where it stands, then gives up — left running, it would charge across the flat the moment you came out. A dead thing that was on you does what it always does when it loses you: goes to where it last saw you, looks about for 4 s, gives up.
3. **The dead walk through you.** While you are hidden the player's body lets the dead within 56 px pass through (`Player._hide_phase`: the same mutual collision exception the anti-stuck net uses, released by it once they are clear). Without it a dead thing walking past would stand pressed against the wardrobe, blind, for ever. "Enemies can move past" is literal.
4. **Finding** (so it is a risk, not a wall): a dead thing that is *searching* (it has arrived at a noise or at your last-seen spot) within `FIND_RANGE` (70 px) of you for `FIND_TIME` (2.5 s) **finds** you: you are thrown out of the hiding place, it is on you (`EnemyMind.spotted`). Walking *past* does not find you. So the skill is: break sight first, hide *away* from where they last saw you. (Consequence worth knowing: a follower that enters beside a nook by the door loses you, searches where it stands and, being within 70 px, finds you. A nook only saves you from followers if you are further from the door than that, or hide before they are close.)
5. **Noise — one system, not two.** Hiding adds no new noise numbers; it plugs into the existing ones (`SOUND_STEALTH.md`):
   - **Hidden = silent.** You are not moving, so the gait noise is 0; the dead beside you are not alerted.
   - **Coming out is a footstep, not a reset.** The way out keeps your stance: `[W]` / a move key leave you **crouched**, so a creeping step carries `crouch` 45 px; standing and walking carries `walk` 120 px, running 240 px. A dead thing that has just passed — say 110 px off, beyond its sight (100) but inside a walk's reach — **does not hear a crouched step and does hear a standing one, and turns round for it** (`EnemyMind.hear`: it walks to the noise, looks about, and chases only what it then sees). The game says so once, when it matters: *"They're close. Stay low."* if any of the dead are within a walking step's reach as you come out.
   - **A wardrobe's door is not silent**: coming out of a piece makes `Stealth.EXIT_NOISE` (40 px, 0.4 s); the bare-wall nook makes none.
   - **Sight is still a full circle.** The dead have no facing today (`distance <= detection`), so a dead thing that has just passed *within 100 px* sees you the moment you are out. "Passing behind" only works from further than that. A **sight cone** (they see ahead, not behind) is the obvious next step and would make this whole system richer; it changes the dead's AI and every fight, so it is the owner's call and not built.
   - **Light** (night makes a hiding place deeper) is the other dial noise has not met yet; designed in §6, not built.
6. **Leave**: `[W]`, any movement key, attack, push, interact, the stance toggle, a click. A hit or any damage throws you out. Anything else that takes over the body (a door's approach walk, a lash, a listen, the pack, a scripted scene) ends it, and while you are hidden **nothing else answers `[interact]`** (`InteractArbiter`) so the press that brings you out cannot also open the door beside the wardrobe. Death, a scene change, a freed player: the state, the camera and the washed-out layer all clear (tested).
7. **Survivors** (friendly) are unaffected; hostile residents stay as they are.

## 5. The screen (the owner's description, made precise)

`scripts/stealth_fx.gd` — a CanvasLayer *below* the HUD (so the HUD stays readable) whose shader samples the screen:

- the world fades to a **cool, dim grey** (colour ×0.12, brightness ×0.34, slightly lifted blacks so it reads *washed out*, not just dark) over 0.6 s;
- **spotlights** keep colour: the **player** always (radius ≈ 0.36 screen-heights, soft edge, a touch brighter) and **each living dead thing near them** — its spotlight strength follows its horizontal gap to you: full inside `ENEMY_FULL` (90 px), fading to nothing by `ENEMY_GONE` (260 px). So a dead thing walking past *comes into the light as it nears and washes out again as it moves off* — the owner's "once it moves past, it is washed out like everything else";
- the **camera zooms in** on the player (`ZOOM_IN` ×1.3, eased over 0.6 s, restored on leaving) so it feels claustrophobic;
- a slow breath in the vignette radius (±3 %) and the heartbeat sound already used by Listen at low volume.

All of it is a pure function of `intensity` (0..1) and the foci, so a pause, a death or a scene change can only ever leave it at a value a test can read; `_exit_tree` restores the camera.

## 6. Cover — phase 2 (designed, not built)

A **second Y line behind a low piece**: `[W]` crouched at a cover-eligible piece (data: `kind` in sofa / loveseat / bed / dining table / kitchen table / sideboard / chest of drawers / desk / low bookcase / trunk, and `h ≥ 30`, i.e. taller than the crouched player) steps the player up onto the line ~18 px behind the piece's base, **crouched, drawn behind the piece** (that piece's sprite z-sorts above the actors while the player is in its cover — the one rule the draw order needs). Along the piece's own width you can **creep** (crouch speed, noise 45 → 0 at half pace); standing, sprinting, striking or leaving its ends drops you to the lane. The dead on the lane do not see you unless within `COVER_REVEAL`; they walk past — *"more room"*: a dead thing investigating a noise walks the full lane through the room instead of stopping at you, which is what makes the sofa worth reaching. Open questions for the owner: whether cover also blocks *noise* (I propose it halves the radius), and whether the dead may *investigate* a cover spot they pass twice (I propose no in v1).

**Corridors** get the same on their dressing (hall table, planter, pram, bin bags, shoe rack): phase 3, after the flat version has been felt. **Light** is the contextual dial both want: on the night run a spot outside a lamp pool is harder to see into (`sight × 0.5`); morning is `× 1.0`.

## 7. Data, tests, and what is NOT known

- **Hide pieces (phase 1):** `wardrobe_wood`, `wardrobe_mirror`, `wardrobe_small`, `linen_cupboard`, `larder_tall` (planned rooms only). The baked story rooms and the gun-cabinet lodge have none yet. Under-bed hiding waits for the bed art to show a gap you can see the player in.
- **Tests (run directly — no gate today):** `tests/stealth_test.tscn` (87 checks, ~60 s): the plane table and numbers; the dead's sight (a control that sees an unhidden player, hidden = unseen, omniscient alert, striking distance, a big zombie, seen again on coming out); entry refused while seen; finding (walk-past through the player, a far search, a near search); the noise chain (hidden is silent, a crouched step is not heard / a standing step is and the zombie turns round and returns, the wardrobe door vs the bare wall, a locked-on follower loses a hidden player and does not charge on the old lock-on); leaving by every input, a hit, damage, the screen and camera clearing, a freed player; the washed-out layer (layer between world and HUD, intensity, zoom, spotlights on the player and on a near / mid / far dead thing, the player's spotlight on the player); the prompt (far / standing / crouched / edge of reach / inside / search-owns-the-key); real flats (hiding places on wardrobes, a nook by the door that is in reach at arrival with its prompt up, none in a pan backdrop). Mutation-checked: see the commit report for which mutants fail it.
- **NOT known, owner's eye:** how the washed-out layer *looks* (judged from xvfb frames only — and whether canvas layer 0 really draws under the HUD on a real renderer: the test asserts the layer numbers, a render was not compared), the numbers (`FIND_TIME`, `SEEN_RANGE`, `EXIT_NOISE`, zoom, radii — first guesses), whether the player should be drawn *inside* the wardrobe (door ajar) or simply stand in the piece's footprint with the door overlay (phase 1 does the latter: the opening art for these pieces exists), and how the bot should treat hiding (it does not hide).
