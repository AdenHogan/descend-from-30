# Stairwell layering — why the descent looks wrong, and what to build

Status: **descent solved with a clip shader ("the shredder") — see below.** An
art overhaul is still wanted for LOOKS (the owner finds the stairwell ugly), but
it is no longer required to make the descent read correctly. Written up so the
next session does not repeat three rounds of wrong fixes.

## The shredder (implemented, stair_pan.gd)

A ShaderMaterial applied to the player sprite during the pan discards every
pixel below `cut_y` (world space). Descending through the stair line feeds the
player through it — feet first, sliced in staggered stages — with no z tricks,
no painted boxes, no tilemap hole. The cut reverses (sweeps down) during the
landing turn on the floor below, reassembling them to full form, and the last
flight is walked visibly. Tunables: STAIR_APPROACH (the red line height),
TURN_HEIGHT (bend height — the old halfway turn was far too high), SHRED_FOOT,
DEPTH_SCALE.

## Mirrored in design, separate in code

Every value that PLACES something on screen exists twice — `DOWN_*` and `UP_*`:

| | descending | arriving |
|---|---|---|
| red line above the floor | `DOWN_STAIR_APPROACH` | `UP_STAIR_APPROACH` |
| bend height | `DOWN_TURN_HEIGHT` | `UP_TURN_HEIGHT` |
| cut below the red line | `DOWN_SHRED_FOOT` | `UP_SHRED_FOOT` |
| depth shrink | `DOWN_DEPTH_SCALE` | `UP_DEPTH_SCALE` |

**Identical values mean "these happen to match", never "these must match."**
Tune `DOWN_*` and only the descent moves; tune `UP_*` and only the ascent does.
Nothing has to be kept in sync by hand.

This is not tidiness. These were single shared constants, and that is precisely
how a tweak aimed at the ascent silently moved the descent and broke a descent
the owner had already signed off. Each value is placed by eye against the art for
ONE direction; sharing them makes the two impossible to tune independently.
`stair_visuals_test` pins the descent's four numbers so a future ascent tweak
cannot move them unnoticed.

Deliberately NOT split, because they are genuinely one thing: `SHRED_TOP` /
`SHRED_BOTTOM` (the sprite's extents, a fact about the art) and `STEP_HEIGHT` /
`STEP_TIME` / `TURN_TIME` (walking pace, which has no direction).

**The shredder cuts on BOTH axes.** Vertically at the step line, and
horizontally to the stairwell's own width (`shaft_band`, which takes its margin
as an argument so neither direction can inherit the other's). The
player sprite is 48px at scale 3 — 144 wide — while the shaft is barely 60, so a
body standing dead centre in it still spills across the corridor wall on either
side. The ascent passes `UP_SHAFT_MARGIN`; the descent passes no band at all.

**The player moves through the cut; the cut does not move through the player.**
Descending, the cut is pinned to the step line and they walk down through it.
Arriving, it is pinned to the destination's step line and they walk up through
it — scalp, head, shoulders, a step at a time. An earlier version swept the cut
across a player standing still, which printed them into existence top-down like
a dot-matrix. The only place the cut moves is the landing turn.

## Ascending is the descent played backwards — literally

The descent is correct and has been signed off. `_ascend` therefore invents
nothing: its four beats are `_descend`'s four in reverse order, each undoing its
partner, with the same cut, the same clip direction, the same distances, the same
easings.

| descend | ascend |
|---|---|
| (1) step UP onto the red line, 0.3s ease | (4) step DOWN off it, 0.3s ease |
| (2) drop through the fixed cut, shrinking | (3) climb up through the same fixed cut, growing |
| (3) turn, cut sweeps DOWN → re-form | (2) turn, cut sweeps UP → dissolve |
| (4) visible walk down, TURN_HEIGHT | (1) visible walk up, TURN_HEIGHT |

**If you change one beat, change its partner — with one exception, the turn.**

The turn is the one beat that is deliberately NOT a strict reversal. Mirrored
exactly it uses `clip_dir +1`, where visible means everything *above* the cut —
so as the cut rises the last thing left is the top of the head, floating out
across the corridor wall. The ascent's turn therefore uses `clip_dir -1`, which
discards above the cut, so sweeping it DOWN eats the body head-first and the last
thing left is the feet, low and inside the shaft. Both sweeps are
player-relative, so the dissolve always completes within the turn however far
apart the floors are.

Every other regression here has been a beat that stopped mirroring.

## The handover

`_commit` does a plain `change_scene_to_file`. Two attempts to make the swap
smoother were tried and BOTH reverted — see below.

## Three things that must never come back

Each was tried, each looked worse than the problem it solved, and each cost a
playtest round:

1. **A front-layer occluder sprite** (`StairFrontLeft/Right`, `_fit_stair_front`).
   It re-cut the top of the staircase PNG and drew it at `z_index 2` to hide the
   player. That region of the art is the dark shaft, so it rendered as a **black
   box over the corridor** — and the player still surfaced in front of it. The
   shredder does the hiding; nothing needs drawing on top of the player.
   `stair_visuals_test` asserts it stays gone.
2. **A viewport snapshot over the scene swap** (`Transition.cross_fade_scene`).
   Reading the viewport back into a texture returns black under GL
   Compatibility, which is the renderer this project ships, so it painted a
   black rectangle over every arrival.
3. **Pre-instantiating the destination floor and swapping it in by hand**
   (`_build_pending`), to move the load cost off the arrival frame. It crashed:
   during the incoming scene's `_ready`, `get_tree().current_scene` is not yet
   the incoming node, so `_spawn_corpses` dereferenced null.

The arrival hitch these were aiming at is STILL OPEN. Whatever fixes it must not
draw anything over the stairwell and must not disturb `current_scene` during
`_ready`.
