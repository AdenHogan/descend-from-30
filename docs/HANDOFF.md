# Handoff — read this first in a new session

**One page. REWRITE it at the end of each session (never append — the log is `docs/STATUS_LOG.md`).** Written 2026-11-12, after round 50.

## Where things stand

- `main` holds everything. Last round: **50** (2026-11-11/12) — an art pass; grep "ROUND 50" and "PEOPLE, A LOOK TEST" in `docs/STATUS_LOG.md`.
- Suites run in round 50: `opening_test`, `building_floors_test`, `furniture_test`, `two_room_test`, `stealth_test`, `room_depth_test` and every art / audio check — green on the final tree. **Nothing else was run** (no full gate).
- `CLAUDE.md` is rules + pointers only. The round-by-round log is `docs/STATUS_LOG.md`: **grep it, never read it whole.**

## Round 50 in one screen

| What | State |
|---|---|
| Opening: the cat trots in side on, sits, watches the crows; hand-placed crows; the roof flock wheels; the afternoon's fleeing person in the owner's chunky manner | done (`OPENING.md`, last section). Owner: "the cat looks better" |
| Corridor plants stand by a door, never alone on bare wall | done |
| Bathrooms: bath mat fits and lies in front of the bath; mirror centred over the basin and hung first; the pink bathroom's wall redrawn (paper, border, repairs, wear) | done; mirrors still only ~1 in 3 in pink (basin under the window / the curtain rail) |
| The other four bathroom shells, all five kitchens, every other room type | **NOT DONE** — the owner asked for all of them ("each module background… storied and authored") |
| A wetroom with no basin (7-12 of 40 plans) | owner's call: four fixtures do not fit 240 px |
| People in the owner's reference manner | a LOOK TEST, six passes (grep "PEOPLE," in the log): `tools/art/people.py` → `docs/art_reference/people/` — rounded figures on a SKELETON (joints from angles, `people_rig.json`), held items at the hand, a face per person, eight MOODS as data. Owner: "so much better… a good path", but expects more passes on style, colour and proportion. Eight passes by the end of the session (the walk is 12 frames). IN-GAME DEV PREVIEW: `scripts/people_preview.gd` + `scene_capture` step `people[:x0:x1[:size]]` — nothing in the game spawns it. Found there: they are authored about a third too small (level with the player only at 1.5x); re-author at ~66 px tall before going further. No rig replaced; nothing decides when a mood applies |

## What the earlier rounds built (detail: grep the round in `docs/STATUS_LOG.md`)

49n the descent ramp + `InteractArbiter`; 49o-49q hiding places and the hide screen (`STEALTH_SPACES.md`); 49r the shove costs a full bar; 49s shade and
shadows (`LIGHT_AND_DEPTH.md`); 49t the Torch, `LightSense`, darkness as a hiding place (`TORCH_AND_DARK.md`).

## The owner's direction (their words, condensed)

- Furniture must have **physical shape, weight, shadow and depth** so hiding places are "clear and present whenever they contextually should be
  there" — flat pictures painted over backgrounds are what force slice tricks.
- Stealth, hiding, noise and **lighting** are one system. Hiding in This War of Mine is underused (a few alcoves); ours should be robust, including
  total darkness on the night run.
- Hiding places should be reusable as **cover** if combat against NPC neighbours is added later ("not now, but have the tools ready").
- Prompts must **not be overwhelming** (the doorway hide: a quiet two-word prompt, contextual side).
- People: "more like this" (a reference of chunky figures: big hair, a big soft coat, two dark eyes, short SOLID legs — "not spaghetti… pixel legs"); Blender was
  discussed and parked. Rooms: "storied and authored like this was a place someone lived in"; nothing placed "without reason".
- Use the strong model for "the complicated stuff and art stuff with a fresh pair of eyes", fixing bugs met on the way.
- Aside, not a request: the stair transition "could still be way simpler than what we have baked in".

## Waiting on the owner (do not decide these)

1. ANSWERED (2026-11-11): no torch at the start — "night player can find a flashlight and deal with the darkness for now until I test it and decide".
2. **Rooms with nowhere to hide** (50 planned rooms a type): a hide piece in living room 100 %, bathroom 60 %, bedroom 40 %, study 10 %, dining
   room 0 %, kitchen 0 %; a doorway corner bare 11-33 %. Reliable doorways need a planner rule (keep a corner free), which re-lays every planned room.
3. **Baked story rooms** (breach, burnt, the dead, tutorial flats, the gun-cabinet lodge) are one picture: nothing to hide behind, no cast shadows.
   Converting them to planned pieces is the real fix; not started.
4. Still open from before: the balance package A-F (`BALANCE_AUDIT_2026-11-04.md`), ambush from hiding, the furniture / module-width eyeball pass.

## Owed (small, mine)

- A test that hiding beside the FRONT door can never touch the flat's exit trigger (~4 px of margin, measured: trigger 6 px wide at the wall's
  foot, player capsule radius 13, spot 16 px inside the wall).
- A night capture of the torch beam for a look check; nothing in 49s / 49t has been seen on a real monitor or listened to.
- No bot sweep since the ramp; the bot neither hides nor uses a torch. Night difficulty without a torch is not measured.
- The OPEN rows in `docs/BUG_LEDGER.md`.

## Gotchas learned this session (not yet rules in CLAUDE.md)

- **A flat's root is a Node2D at (-1, -1)** though `room.gd` says `extends Node`: room-local x 353 is world 352. Type such parameters as `Node`;
  tests read `global_position`, never a constant.
- **[interact] is polled twice a frame**: by the player in the physics step and by doors / hiding places in the idle step. `Input.action_press`
  made inside a physics frame registers for the NEXT physics tick — make the press in a process frame, then call the steps by hand.
  `InteractArbiter.claim()` spends a press.
- `GradientTexture2D.get_image()` is empty until rendered — read the gradient analytically (`LightSense.texel`).
- A "this bad thing is refused" test must assert the **reason** (a sample that does not exist is refused too, and proves nothing).
- Fresh container: `python3 -m pip install --break-system-packages --ignore-installed pillow fonttools shapely scipy scikit-image` before any art check
  (the logo check needs the last four); `tools/art/corridor_decals.py` deletes the decals' `.import` files (restore with `git checkout`) and redraws `dead_6.png` differently here; run godot with its own
  `XDG_DATA_HOME`; one godot at a time; `SUITE_TIMEOUT=900` for the full gate.
- Mutation checks: swap one line, run the one suite (`-- --only=<section>` where a suite has sections), restore, confirm with `git diff`.

## How the owner wants reports

Short. British English. Say which suites ran and which did not. No mention of the backup branch. Commit and push to `main` at each finished piece.
