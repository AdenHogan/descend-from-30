# DF30 — Sound & Stealth (Listen System)

> **Status: agreed design, implemented v1.** Decided in session 2026-07-20.
> Supersedes the GDD's "Audio / Listen System (Phase 1)" sketch and the
> earlier idea of a free-roaming TLOU-style listen mode (deliberately
> DROPPED — see Design rationale).

## Design rationale (owner decision)

Sound is a first-class mechanic — as key as combat and scavenging, usable
during both modes. But **sound itself lives under the hood**: floors are one
screen tall and a few screens wide, so a roaming echo-location mode would
only duplicate what ambient audio and the screen already tell the player.
Player-facing listening is **anchored**: press R at an apartment door or a
down-stairwell to answer the one question eyes can't — *what's behind this
door / below these stairs?*

## Under-the-hood noise model

Every player action has a loudness with a hearing radius. Zombies inside the
radius are alerted (`alert_to_noise` opens their detection range for the
duration). Sight detection is unchanged — noise **extends** how far away you
can be noticed, never shrinks it.

| Action | Level (design) | Radius (px) | Duration |
|---|---|---|---|
| Standing still | 0 | — | — |
| Crouch movement | 2/10 | 45 | while moving |
| Scavenge-mode movement | 3/10 | 70 | while moving |
| Walking | 5/10 | 120 | while moving |
| Running | 7/10 | 240 | while moving |
| Forcing a door / lock | 10/10 | 420 | 4s |
| Barricade removal | 10/10 | 420 | continuous |
| Gunshot | max | 2000 (whole floor) | 6s |

Constants: `WorldState.NOISE_RADIUS`; emitter: `WorldState.emit_noise(pos,
radius, duration)`. New noisy actions (thrown cans, breaking glass) should
route through `emit_noise` — never hand-roll zombie loops.

Enemies also make sound the player can hear off-screen (shuffling, moaning)
— **audio assets are an open task**; the model works without them but the
player's half of the loop needs the SFX pass.

## Anchored listen (R)

- **Where:** apartment doors (all states except sealed 3001) and
  **down**-stairwells. Prompt appended to door text: `[R] Listen`.
- Works in BOTH combat and scavenge modes.
- **Rooted + real time:** the player cannot move or act for ~3s and CAN be
  hit — damage cancels the listen with no report. Listening near a shuffler
  is the player's own mistake; the risk is the price of information.
- **Presentation:** screen fades to grey (TLOU-style desaturation) with a
  focus vignette — lighter near the player/screen centre, near-dark at the
  edges (reduced extended visibility while focusing). Organic red echo
  pings (wobbly pressure-ripple rings, not clean circles) pulse at the
  door/stairwell. **Ping tempo = proximity**: faster when enemies sit nearer
  the apartment entrance, slower when deeper inside. Silence = no pings.
  Breach rooms ping darker/heavier.
- **Report:** after the listen, colour returns and a dialogue box shows the
  player's read — one line from a FIXED vocabulary so players learn exactly
  what each phrasing means:

| Category | Meaning | Apartment line | Stairwell line |
|---|---|---|---|
| none | 0 | "...Silent. Nothing moving in there." | "Nothing moving down there." |
| one | 1 | "Something's shuffling in there. Just one, I think." | "Something's moving below. Just one, I think." |
| few | 2–3 | "More than one... two, maybe three." | "A few of them below. I can hear them pacing." |
| many | 4+ | "It's crawling in there. Too many." | "The floor below is crawling with them." |
| big | breach/boss | "Something big is moving in there... and it's not alone." | "Something heavy is dragging around down there." |

  Future categories reserved: NPCs, new monster types (slot into the same
  fixed-vocabulary pattern).
- **Truthful reads:** categories come from the same deterministic seeds that
  spawn enemies (`get_apartment_zombie_count`, `get_floor_zombie_count`,
  breach door state), minus recorded kills in that apartment/floor. Ping
  "nearness" is a per-target seeded value (`get_listen_nearness`) — an
  honest approximation until interiors get pre-simulated positions.

## Listen ambush ("sometimes, not always")

Focusing is dangerous. On listen start, one random roll:
- **18%** — if a living zombie exists on the floor beyond 240px, it is
  silently alerted and shuffles over through the darkened edges; the player
  meets it as colour returns. They have time to fight — it's a cautionary
  tale, not a death sentence.
- **8%** — only if NO living zombies remain on the floor (hallway scenes
  only): one standard zombie spawns at the dark screen edge (~500px out)
  already alerted.
- Otherwise: nothing. Unpredictability is the point — never make it a
  ritual the player can pre-clear.

## Key changes

- **R = Listen** (GDD-canon restored). **Rest moved to T.**

## Open tasks

- **Audio pass (assets):** enemy shuffle/moan loops (audible off-screen),
  player footsteps per gait, gunshot bang, barricade tearing, listen-mode
  heartbeat/muffle. The noise MODEL is live; the player's ears are not.
- **Art:** listen animations — cupping ear at a door / leaning over the
  stairwell rail (placeholder: crouch idle).
- **Later:** thrown-can distraction routes through `emit_noise`; directional
  noise investigation (walk to noise point rather than to player) if
  non-player noise sources arrive.

## Testing

`tests/listen_noise_test.tscn` — noise radii ordering, emit_noise range
gating, category thresholds, kill subtraction, nearness determinism,
lobby edge case.
