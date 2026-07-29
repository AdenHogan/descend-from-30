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

**Two lines, from the same two constants, applied to whichever floor is being
left or reached** — the red line (`standing_y - STAIR_APPROACH`, where the player
stands before dissolving / after climbing back into view) and the cut
(`red line + SHRED_FOOT`, on the yellow steps). Leaving and arriving must derive
them the same way or a body dissolves at one height and reappears at another.

**The shredder cuts on BOTH axes.** Vertically at the step line, and
horizontally to the stairwell's own width (`shaft_band` / `SHAFT_MARGIN`). The
player sprite is 48px at scale 3 — 144 wide — while the shaft is barely 60, so a
body standing dead centre in it still spills across the corridor wall on either
side. The x crop is live for exactly as long as the y cut is, in both directions.

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

**If you change one beat, change its partner.** Every regression here has been a
beat that stopped mirroring — most recently the ascent flipping `clip_dir` to −1
for its turn when the descent never flips it at all.

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
