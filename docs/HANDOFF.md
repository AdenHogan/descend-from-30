# Handoff — read this first in a new session

**One page. REWRITE it at the end of each session (never append — the log is `docs/STATUS_LOG.md`).** Written 2026-11-11, after round 49t.

## Where things stand

- `main` holds everything; nothing is uncommitted or unpushed. Last code commit: `8ef9863` (round 49t).
- Full gate on that tree: 84 of 85 suites + every art / audio check ok; the one failure was a new test check (wrong sample piece), fixed in the
  test and that section re-run green. The other 84 were not re-run after that one-line test fix.
- `CLAUDE.md` is rules + pointers only (44 KB). The round-by-round log is `docs/STATUS_LOG.md` (~490 KB): **grep it, never read it whole.**

## What the last rounds built (detail: grep the round in `docs/STATUS_LOG.md`)

| Round | What | Doc |
|---|---|---|
| 49n | The descent ramp (floors 30-29 old numbers, 25 down the new); ONE rule for who answers an [interact] press (`InteractArbiter`) | `NPC_AI.md`, `BUG_LEDGER.md` |
| 49o-49q | Hiding places (wardrobe, bath, shower curtain), too-close / pass-by / finding rules, the lighting-based hide screen, heartbeat audio | `STEALTH_SPACES.md` |
| 49r | A shove needs and takes a full stamina bar on EVERY floor (Joe two charges, Brawler +1) | `STEALTH_SPACES.md` §8 |
| 49s | Room / corridor shade, cast shadows behind planned furniture, window pools at dusk / night, contact shadows under actors | `LIGHT_AND_DEPTH.md` |
| 49t | Torch + batteries; light is measured (`LightSense`); the dead's sight follows the light on the player; darkness is a hiding place; hiding behind sofa / loveseat / armchair; standing against the wall beside a doorway; cover numbers (unused); floor shadows | `TORCH_AND_DARK.md`, `STEALTH_SPACES.md` §10 |

## The owner's direction (their words, condensed)

- Furniture must have **physical shape, weight, shadow and depth** so hiding places are "clear and present whenever they contextually should be
  there" — flat pictures painted over backgrounds are what force slice tricks.
- Stealth, hiding, noise and **lighting** are one system. Hiding in This War of Mine is underused (a few alcoves); ours should be robust, including
  total darkness on the night run.
- Hiding places should be reusable as **cover** if combat against NPC neighbours is added later ("not now, but have the tools ready").
- Prompts must **not be overwhelming** (the doorway hide: a quiet two-word prompt, contextual side).
- Use the strong model for "the complicated stuff and art stuff with a fresh pair of eyes", fixing bugs met on the way.
- Aside, not a request: the stair transition "could still be way simpler than what we have baked in".

## Waiting on the owner (do not decide these)

1. **Night is darker round the player** (aura 0.36 over 160 px, was 0.62 over 269 px). A torch is ordinary loot. Give the night character one at
   the start? Dials: `WorldState.player_aura_energy` / `player_aura_scale`.
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
- Fresh container: `python3 -m pip install --break-system-packages --ignore-installed pillow` before any art check; run godot with its own
  `XDG_DATA_HOME`; one godot at a time; `SUITE_TIMEOUT=900` for the full gate.
- Mutation checks: swap one line, run the one suite (`-- --only=<section>` where a suite has sections), restore, confirm with `git diff`.

## How the owner wants reports

Short. British English. Say which suites ran and which did not. No mention of the backup branch. Commit and push to `main` at each finished piece.
