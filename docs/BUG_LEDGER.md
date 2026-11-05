# Bug ledger

The owner (2026-11-04): *"Let's keep doing what we can to keep track of and correct bugs."* This is the one list of bugs that were
FOUND, whether they are FIXED, what proves it, and what is still OPEN (found but not explained or not fixed). It starts at round 49d; the
earlier ones are in CLAUDE.md's status log and `docs/BOT_RUNS.md` (round 44's twelve).

Rules for this file:

- A bug is **fixed** only when a test (or a re-run of the thing that found it) fails without the fix. Say which.
- A bug is **open** when it was seen and not explained, or explained and not fixed. Say what was and was not shown. "Did not reproduce" is
  written as that, never as "fixed".
- A bug the owner's playtest finds goes in the same day it is reported; a bug the bot sweep finds goes in with the sweep's file name.
- Do not delete a row; move it to the FIXED table when it is.

## FIXED

| Round | Bug | Cause | Proof |
|---|---|---|---|
| 49n | The tutorial's first lunge never fired for a player standing still (and the neighbour bit them to death without the shove lesson) | `room.gd` compared a separate constant (30) with the EUCLIDEAN distance between two origins that are ~17 px apart vertically, so the beat's range was shorter than the bite's. Present on the old code too | `tutorial_test` stands still and waits for the beat; mutation-checked (slack -20 fails it) |
| 49n | Flat followers: no standard zombie was ever captured | `str(null)` is `"<null>"`, so `z.get("wall_mode") != ""` excluded every body that has no `wall_mode` (only the crawler has it) | `flat_follow_test`; mutation-checked (no chase gate; no corridor-slot handling) |
| 49n | A building shift (rest / pry) left flat-follower keys behind, so a re-rolled building kept a dead record | `shift_building` dropped the stair / follower keys but not `:flat_in:` | `flat_follow_test`; mutation-checked |
| 49n | `back_plane_test` failed ~1 run in 4 (also on the commit before any round-49m change) | the helper waited 8 frames and a room sets its step-up spots up over its first frames (5..14 spots from run to run) | 0 failures in 20 runs after waiting 40 frames |
| 49j | A rescue flat's listen report under-counted the ordinary dead | subtracted the three dead the rescue sends from an ordinary count they were never part of | `survivor_ai_test`; mutation-checked |
| 49i | Survivors and enemies reacted to the floor they were being panned toward (the floor bleed) | `AiMind.gap` measured only the horizontal gap on a shared plane | `survivor_ai_test._test_floor_bleed` (7 checks fail without the `same_world` line) |
| 49i | Listen at a door said "silent" while someone was being attacked inside | the report read the flat's ordinary roll only | `survivor_ai_test`, `quest_test` |
| 49i | An enemy came up a barricaded stairwell | the staircase's enemy count did not look at the barricade | `stair_block_test` (40-seed sweep: 169 barricaded chokes, 0 with an enemy; the old rule left 73) |
| 49i | A door's bullet holes stayed on the wall while it swung | decals on the wall layer | `building_floors_test` |
| 49i | Pack Mule offered a seventh slot that was not there | `get_inventory_slots` capped at 6 | `progression_test._test_seventh_slot` |
| 49i | With seven wedges the pack ring's middle card overlapped a slot | `RING_R` too small | `lamp_test` measures 3-7 wedges |
| 49f | The anti-stuck net did not fire for a player jittering ±0.6 px between a zombie and a defender's fight | judged per-frame movement, not net progress | `softlock_test._test_jitter_pin`; mutation-checked |
| 49f | A script error per flat entry when a switched-off TV was remembered | `get_tree()` called before the node was in the tree | `open_furniture_test._test_screen_off_before_the_tree`; mutation-checked |
| 49f | A resident in a two-room flat stood outside the flat's wall | "module 2" hard-coded as the far room | `resident_npc_test._test_placement_in_short_flats`; mutation-checked |
| 49d | Fire hurt the player standing visibly beside it and under the tapering ends | damage read the 42 px sim cell, not the carpet that is drawn | `fire_test` (10 checks fail on the old rule) |

## OPEN

| Since | What was seen | What is known | What is not |
|---|---|---|---|
| 49i | `pack_test` once failed 5 checks ("ring up", "an EMPTY bag still opens"…) in a full gate | it passed in 20 direct reruns and 3 more through the gate script | the cause. The test waits in frame counts on a real-time headless loop; a slow moment is the suspect, not shown |
| 49f | One gate run logged "the trader's home" (no resident spawned) and then hung for 300 s | neither reproduced in 60 later runs; the two-room placement bug fixed in the same round is NOT shown to be the cause | the cause |
| 49g | Bot: `TAKE_NO_EFFECT` x2 and `DROP_NOT_TAKEN` x3 (a floor drop stayed after three [interact] presses with a free slot) | a survivor's [Talk] holding the press is the suspect | everything else — never investigated |
| 49g | Bot seeds 101 / 102 pinned at a door for 30-75 s (round 49f) | the one pin caught with a per-frame trace was the BOT thrashing `move_left` / `move_right`; no game code changed; replays did not pin | the 2601 pins carry no trace; "no longer seen" is absence of evidence |
| 49i | Ethel: "I chose Leave to come back with bandages; the husband died immediately; E does nothing" | not reproduced — a test walks the whole real flow and every step holds; the husband cannot die by a bite under the shipped theatre rules | the owner's flat number, run, and whether a pan or balcony descent was involved |
| 49m | Followers do not chase the player back OUT of a flat | by design for now | — |
| 49m | The workbench rework (stat picks, repair tab, name row in the header) was checked by geometry tests only | no xvfb capture | how it looks |
| 49f | Balance sweeps predate the round-49j module-width flip, the workbench rework and the shop changes | `docs/bot_runs/round49f_sweep.md` | — |

## BOT SWEEP FINDINGS

(filled in from `docs/bot_runs/round49n_sweep.md` when the sweep lands)
