# The torch, and the dark

**BUILT v1 (round 49t, 2026-11-11). Seen in engine captures under xvfb only; every number is a first guess.**

The owner: *"hiding [in This War of Mine] is reserved for shadowy alcoves mainly, so it's somewhat underutilised. We need something more robust, like also
being able to hide in total dark spaces during the night run when lighting may be out on a floor. This is another reason why we need to get the flashlight
working now… for now using the gun animations, and then the flashlight can be a natural light source for darkness. Turning off the flashlight in those dark
zones would be real dark in a night run."*

This extends `STEALTH_SPACES.md` (hiding places and their rules) and `LIGHT_AND_DEPTH.md` (how rooms are lit). The furniture hiding places of the same
round (behind a sofa, beside a doorway) are in `STEALTH_SPACES.md` §10.

## 1. What This War of Mine does, and what we take from it

| In This War of Mine | Why it is underused there | Here |
|---|---|---|
| **Hiding places are fixed alcoves** — a few dark recesses per map with a hide icon. Inside one you are invisible to anyone who did not watch you go in. | There are two or three a map and they are rarely where you need one, so most players sneak or fight instead. | A hiding place is **any piece a person would hide in or behind, wherever the room has it** (wardrobe, bath, shower curtain, sofa, armchair), **the wall beside any doorway with a bare corner**, and — new — **the dark itself**. |
| **They saw you go in** — hiding in front of someone does not work. | — | Kept: a dead thing within its own attack reach and one more length when you commit has you (`Stealth.too_close`). |
| **Noise is the main channel.** Running draws circles the guards react to; sneaking is slow and quiet. | — | Kept, and already the same system: gait noise 45 / 120 / 240 px, the dead walk to a noise's source and look about (`SOUND_STEALTH.md`). A hiding place is silent; the step out of it is a footstep. |
| **Sight is line of sight**: you see only rooms you have a line into; doors and walls block it; you peek through keyholes. | — | Our dead see by a **radius**, with no facing. Not changed here — but the radius now **follows the light on you** (§4). A sight cone is still the open question in `STEALTH_SPACES.md` §4. |
| **Darkness is only a look.** The art is dark; how lit you are changes nothing. | The missed opportunity the owner points at. | **Light is measured** from the real lights (§3) and it matters twice: how far the dead see you, and whether the spot you stand in is a hiding place. |
| **The player has no light of their own to manage.** | — | **The torch** (§2): it shows you the dark and shows you to the dead. Switching it off is a decision. |
| **Ambush from hiding**: a passer-by can be killed in one blow from an alcove. | — | **Not built.** It would sit naturally on the hiding rules (a strike from a hiding place at a dead thing that has just passed), but the save audit says one-swing kills are already too easy; the owner's call. |

## 2. The torch

Item **015 Torch** (`is_tool, is_torch`) and item **021 Battery** (`is_tool, is_battery`). Both were in the loot pools already and did nothing.

- **In hand + the use key** (Q / right-click Use / a double-click / the touch button, which reads **LIGHT**) switches it on and off. The first use of a
  torch that is not in hand takes it in hand and lights it. The attack key still attacks.
- **Lit, it is a real light**: a `PointLight2D` on the player with a beam cookie (`FloorLighting.torch_texture`), pointing the way they face, about
  243 px long. It lights the wall, the floor, furniture and whatever stands in it like every other light — so at night it is what shows you a dead
  thing before you walk into it. Strength by run: 0.5 / 1.0 / 1.55 (additive: barely needed by day).
- **The pose is the gun's aiming pose** (`gun_idle` / `gun_walk` / `gun_run`) while it is lit — the owner's stand-in until there is torch art. No torch
  is drawn in the hands.
- **It runs a battery down**: `ItemInstance.charge`, seconds of light. A fresh battery is `WorldState.TORCH_FULL` **180 s**; a found torch holds half
  (`TORCH_FOUND`). It only drains while lit. Under 15 % the beam stutters; at 0 it dies (*"The torch dies. It needs a battery."*).
- **A Battery refills it**: use the battery, or drag it onto the torch in the pack ring (or the other way round) — the ring says LOAD. Switching on a
  dead torch with a battery in the pack swaps it in and lights it in one press. A battery is never spent on a torch that is still over 90 % full.
- **It goes out** when it is no longer the thing in hand (put away, dropped, sold), when you hide (nobody hides with a light on), and on death. It
  cannot be lit from a hiding place.
- The in-hand vial is the battery (draining as it burns); the tooltip reads `Battery 62%`; the codex explains both items. The charge is saved with the
  item, so a dropped torch, a corpse's torch and a loaded game keep what was left (a save from before this round gets a found torch's charge).

## 3. How lit is a spot (`scripts/light_sense.gd`)

`LightSense.level_at(point, scene)` = the scene's ambient (the luminance of its `WorldGrade`: about 0.95 by morning, 0.42 by afternoon, 0.07 at night,
dimmer with depth) **plus every real light whose cookie covers the point**, each as energy x its colour x the cookie's own texel there — so a
sconce's cone, a slanting window shaft and a torch's beam are measured as they are drawn, not as circles. A light that is off, hidden, or a tiny marker
(a scavenge star's glint) adds nothing. `DARK` = 0.16, `LIT` = 0.40. Nothing is "dark" before night, bar a very deep floor.

The light **on the player** leaves out their own lights (`Stealth.light_now` / `light_on`): their aura and their beam are how *they* see.

## 4. The dead see by the light on you (`Stealth.sight_scale`)

The dead's sight radius (standard 100 px, big 130 ± 45) is multiplied by:

| Where you are | Sight |
|---|---|
| plainly lit — any morning, any afternoon, under a working lamp, by a fire, in a window's pool | **x 1.0** (exactly as before) |
| in the dark, torch off, standing | **x 0.6** |
| in the dark, torch off, crouched | **x 0.45** |
| in the dark with a **lit torch** | **x 1.5** — a light in the dark is seen from further than a person in daylight |

Smooth between dark and lit. A source-less alert (*"it knows"*, 2000 px) is not scaled, and noise is unchanged: a walking step still carries 120 px,
further than a dark sight, so the dark helps a player who is also quiet.

## 5. Darkness is a hiding place (`scripts/dark_spot.gd`)

Every player carries a `DarkSpot`. Wherever the light on them is at or under `DARK` and their torch is off, the dark itself is a place to hide:
**`Darkness   [E] Hide`** over the head, one press, and from then on **every rule of a hiding place** (`STEALTH_SPACES.md` §4): too close when you
commit and it has you; a chaser further off shambles past, *through* where you stand, and looks about on the far side; a searcher that lingers within
70 px finds you; a hit throws you out; one more press brings you out. Two rules of its own:

- **It does not nag.** A night corridor is dark from end to end, so the prompt only shows when hiding is on your mind: you are **crouched**, or one of
  the dead is **up and within 420 px** (`Stealth.wants_hiding`).
- **Light ends it.** A lamp that stutters back on, a fire, a torch that is not yours: `BREAK_LEVEL` 0.30 of light on you for `BREAK_TIME` 0.35 s and
  you are out (*"The light's on me."*). A lightning flash is shorter than that and does not.

It answers `[interact]` **last**: a door, a body, a drop, a wardrobe — anything else that would answer the press — takes it. Beside a real hiding place
the prompt is the piece's, not the dark's. While you hide in the dark your own pool of light is **not** raised (it is for the other hiding places).

## 6. A behaviour change to know about: the night is darker round the player

The player's own aura was 0.62 over a 269 px radius at night — it lit the whole screen round them, so "near-black night" was not true anywhere the
player stood and a torch would have had nothing to do. **At night it is now 0.36 over 160 px** (`WorldState.player_aura_energy` / `player_aura_scale`):
you see your own footing and what is about to touch you; the torch, the lamps that still work, fire and the windows show the rest. Morning and afternoon
are unchanged. Night Eyes still widens it. **If the night is now too dark to play without a torch, those two numbers are the dial** — and a torch is
ordinary loot, not a guaranteed find; guaranteeing the night character one (beside 3001, like the backpack) is a decision I have not made.

## 7. Dials

| Dial | Now | In |
|---|---|---|
| a fresh battery / what a found torch holds / the stutter / when a battery may be swapped in | 180 s / 50 % / under 15 % / under 90 % | `WorldState.TORCH_FULL`, `TORCH_FOUND`, `TORCH_LOW`, `TORCH_SWAP_BELOW` |
| the beam's strength by run / its reach | 0.5 / 1.0 / 1.55 · 0.95 x 256 px | `Player.TORCH_ENERGY_BY_RUN`, `TORCH_SCALE` |
| dark / lit | 0.16 / 0.40 | `LightSense.DARK`, `LIT` |
| the dead's sight in the dark: standing / crouched / at a lit torch | x 0.6 / x 0.45 / x 1.5 | `Stealth.DARK_SIGHT`, `DARK_SIGHT_CROUCHED`, `TORCH_SIGHT` |
| the light that ends a dark hide, and for how long | 0.30 for 0.35 s | `DarkSpot.BREAK_LEVEL`, `BREAK_TIME` |
| how near the dead must be for the quiet prompts to show without a crouch | 420 px | `Stealth.THREAT_RANGE` |
| the night aura | 0.36 over 160 px | `WorldState.player_aura_energy`, `player_aura_scale` |

## 8. Tests, and what is NOT known

`tests/torch_test.tscn` (the 85th suite; `-- --only=item,sense,torch,sight,dark`): the two items (flags, a found torch's charge, the save and an old
save, the pair rule, loading: spent only when it goes in, the hand keeps the torch when the indices shift, the tooltip, the hand's verb, the codex);
LightSense (ambient, a lamp's pool, off / hidden / marker lights, `skip`, a beam measured ahead and not behind and turned with its node); the torch in a
real night corridor (one use lights it, a real light at the night's strength, turning with the player, the gun pose, the battery draining in real time
and only while lit, off, putting it away, dying, a dead torch, the one-press swap, a battery used by itself, hiding puts it out); sight (the rule as a
pure function; a morning corridor untouched; in the dark a dead thing 80 px off does not come, with a lamp over the player it does; a lit torch draws one
from 130 px); the dark as a hiding place (none by day or under a lamp, no prompt standing with nobody near, offered crouched or with the dead near, not
with the torch lit, one press in and out, a dead thing walking through, too close, light ending it, a flash not ending it, answering last, a wardrobe
winning).

**Not known / not built:**

- How any of it **looks** on a real monitor: the beam's shape and strength, the darker night, the aiming pose with no torch drawn.
- Whether the night is now **too hard without a torch** (no bot sweep on this tree; the bot does not use a torch or hide).
- **Ambush from hiding** (the This War of Mine backstab): not built.
- **Light on the dead**: a dead thing standing in darkness is as easy for the *player's swing* to hit as ever; light changes what the dead see, not what
  the player can do.
- **The dead do not react to the beam itself** (a torch shone on one does nothing special); the beam only makes the *holder* easier to see.
- Survivors, residents and the merchant ignore light altogether.
- No torch art in the hands; the click is the existing switch sound.
- The flat-follower and breach-entrant rules are unchanged, so a follower that walks into a dark flat locked on to you still knows where you are until
  you hide.
