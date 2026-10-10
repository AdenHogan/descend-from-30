# NPC AI — survivors, allies and a smarter dead (BUILT v1, round 39)

> Owner brief: *"populating our building with NPCs in contextually appropriate areas — apartments, hallways, elevators;
> some cowering, others armed like our player and using their AI to fight. They will do half damage of the player
> because obviously we still need the player to take initiative."* and *"NPCs must have intelligence in their actions and
> clear patterns and actions"* and *"our enemies will also need to start having better intelligence too."*
>
> Every line a survivor speaks (`data/survivor_dialogue.json`) is a PLACEHOLDER the owner rewrites. The mechanics are real;
> the art is the homeless pack at 1.6× (placeholder); the LOOK of the tells and speech bubbles needs the owner's eye
> (checked headless only).

## The shape of it — perceive → decide → act, with a visible tell

Every thinking actor (a survivor, a zombie) does the same three things each frame, and says which it is doing:

1. **Perceive** — who is near, on my plane, in range (`AiMind.gap`: horizontal gap on the same plane, `INF` otherwise,
   so the 18 px origin differences between rigs never matter — see CLAUDE.md "align by FEET").
2. **Decide** — pick ONE named behaviour from a short ordered list. The behaviour is written to `behaviour` (survivors) /
   `mind` + `state` (the dead), so a test (and the player) can read exactly what it is doing.
3. **Act** — move / strike / speak / make noise.

The **tell** (`AiTell`, a small mark over the head) is the player-facing half. Three marks, the same meaning on a survivor
and on the dead:

| mark | meaning | colour |
|---|---|---|
| `!` | alert — it has seen / heard something and is committing | red |
| `?` | search — it lost track and is looking | amber |
| `…` | fear — hiding, frozen, holding its breath | pale |

Tells are deliberately **not unshaded**: in the dark they are dark too, so the "lurkers unseen at night" pillar holds.

Files: `ai_mind.gd` (senses), `ai_tell.gd` (marks), `ally_combat.gd` (damage), `survivor_plan.gd` (who/where),
`survivor.gd` (the brain), `enemy_mind.gd` (the dead's brain).

## Where they are — context, not scatter (`SurvivorPlan`)

Seeded `hash(master_seed + "survivor" + key)` per (place, **run**), settled into `WorldState.survivors` (saved, string
keys), so re-entry, a stair-pan backdrop and its live commit agree and a dead one stays dead. A new run is a new key → a new
roll: the building empties as the arc goes on.

| role | where | armed? | chance run 1/2/3 | hp |
|---|---|---|---|---|
| **Defender** | corridor, holding the way down (55%, 150 px in from the stair trigger) or beside an apartment door | yes — a weapon from a per-run list (the guns appear later) | .30 / .24 / .16 | 8 |
| **Waiter** | corridor, 45 px left of the lift — waiting for a car that is never coming. **Never on a merchant floor** (the merchant has the car) | no | .18 / .14 / .10 | 4 |
| **Hider** | inside an apartment you can walk in (door OPEN or only weakly locked), as far from the front door as the flat goes | 30% a kitchen knife | .12 / .09 / .06 | 3 |
| Host / Patient | quest people only (Ethel and her husband) | — | quest data | 4 |

Rules of context (`floor_ok`, `hider_flat_ok`): floors 1–28 only (29 keeps its scripted neighbour and the run-opening
grace; 30 is the tutorial); never on a BLAZE/CHARRED floor; a hider never shares a flat with a resident, a revenant, a
corpse story or a quest. A quest giver on a floor replaces that floor's random defender.

## Survivor pattern tables (`survivor.gd`)

A survivor is an `Area2D` with **no collision layers** (like a resident): it can never block, shove or wall off the player.
It is not in the `zombie` group (no zombie system — memory, crowds, cans — treats it as one); the dead find it through
group `survivor_prey`. Ranges and timings are consts at the top of `survivor.gd`.

**DEFENDER** — `hold → alert → engage ⇄ help → (retreat → wounded) → return → hold`

| behaviour | enters when | does | tell |
|---|---|---|---|
| hold | default | stands at its post; every 3.5–6 s turns to scan the corridor | — |
| alert | a dead one comes within `SENSE` 340 px on its plane | faces it for `REACT_TIME` 0.55 s (the beat to read) | `!` |
| engage | alert elapsed, target within `LEASH` 250 of the post | closes to its weapon's reach and fights (guns keep `GUN_STAND_OFF` 150 and back off if closed on) | — |
| help | the player is within 330 and the dead are within `HELP_LEASH` 400 | leaves its post to fight beside you, returns after | — |
| retreat | below 35% health | falls back toward its post, no longer attacks unless cornered (52 px) | — |
| wounded | at the post, hurt | sits out; gets back up after 6 s of quiet | — |
| return | threat gone | walks back to the post | — |

**HIDER** — `hide → peek → trust ⇄ freeze → panic → relieved`

| behaviour | enters when | does | tell |
|---|---|---|---|
| hide | default | crouched, still | `…` when the dead are near |
| peek | the player within 170 px | looks out, whispers | — |
| trust | player within 84 px for 1.4 s (weapon down) / 3.2 s (weapon drawn) | stands, talks, hands over its gift once | — |
| freeze | one of the dead within 230 px (hysteresis) | does not move a muscle | `…` |
| panic | the dead within 84 px | runs for the far wall and SCREAMS (noise radius 380, 7 s cooldown — the dead hear it) | `!` |
| relieved | the danger is gone | breathes out, then trusts | — |

**WAITER** — `wait (+ bangs in threes) → startle → calm ⇄ flee`: bangs on the lift in sets of three every 22–34 s
(noise radius 300 — **the dead hear it, so a waiter is a risk to the floor**); the player within 96 px startles it, calm
after 1.2 s; the dead within 200 px and it flees.

**HOST / PATIENT** (quest 001): the host pleads / mourns; the patient lies (not prey — the dead do not go for the dying).

### Half damage (`AllyCombat`, FRACTION 0.5)

All numbers are **derived from the player's own tables**, read off `player.gd` (`WEAPON_DAMAGE/RANGES/COOLDOWN` — a retune of
the player's hammer retunes every survivor's at half), never copied:

- **Melee**: damage = ½ × the player's for that weapon type, at the player's reach and rhythm. The fraction is **carried**
  between swings (`take_swing`): a knife lands 1 every other swing, a bat 1,2,1,2 … exactly half over time, no luck.
- **Gun**: a hit does ½ the player's body shot (2 → 1); **never headshots** (an instant kill would be MORE than the player's
  average); hit odds are the player's own body odds; rounds are finite (4–7).
- **Fists**: the player can't hurt anything bare-handed, so neither can a survivor — an unarmed survivor hides.
- The dead hit a survivor for their **ordinary** damage — no gentler with them than with you. A survivor can die and stays dead.

`AllyCombat.player_script()` loads `player.gd` **lazily**: a `preload` made a compile cycle
(`WorldState → Quests → Survivor → AllyCombat → player.gd → WorldState`) that broke `:=` type inference inside `player.gd`
itself. Do not turn it back into a `preload`.

## The dead think a little (`EnemyMind`, shared by the standard family and the big zombie)

| pattern | trigger | does | tell |
|---|---|---|---|
| **investigate** | a noise (`alert_to_noise(duration, source)`) | walks to the noise's SOURCE — **a noise tells it WHERE, not where you are now** | `?` |
| **search** | arrived at the noise / your last-seen spot | looks about for 4 s, turning its head every 1.1 s | `?` |
| **give up** | search over | stands down, back to idle | — |
| **lose** | you leave its sight mid-chase | goes to where it LAST SAW you, searches there | `?` |
| **spot** | idle → chase | marks, and the dead within 170 px (4 s cooldown) turn toward the commotion | `!` |
| **prey** | a survivor stands nearer than you (sticky: `SIGHT_STICKY` 30) | chases and bites the survivor (a big one windup 1.2, damage 2); goes for the last-seen spot if the survivor is lost | — |

Spitters ignore survivors (`allows_survivor_prey()` false — they only shoot at you). Crowd ranks (`enemy_crowd.engaged`) only count
enemies whose prey is the player.

### What changed against SOUND_STEALTH.md (read this before tuning stealth)

Before round 39 a noise gave every zombie in range your **exact position** across the whole floor. Now `WorldState.emit_noise` calls
`z.alert_to_noise(duration, pos)` and a zombie walks to the noise's **source**; it only chases what it actually sees (within
detection range, on its plane). Consequences: running past a noise-maker is safer than it was; a thrown can/bottle is now a real
decoy (it pulls the dead to *where it landed*); the old "I know where you are" behaviour survives only for callers that pass no source — the dead
mustered at a stairwell you pried open (`building_floors` `alert_to_noise(12.0)`) and the far-zombie pulls in `player.gd`. A survivor's
noises call `emit_noise(..., cross_floor=false)`, which skips `note_cross_floor_pull`, so its gunfire (radius 900), screams (380), bangs (300)
and swings (120) are heard on its own floor only.

## The survivor rule — why a plain `new_game()` has nobody

`WorldState.survivor_rule` (saved; **only the real `Game.new_game()` turns it on**, like `packless_rule` / `story_rule`) gates ALL placement:
`SurvivorPlan.corridor_records` / `hider_for` and the quests' `Quests.corridor_records` / `is_quest_flat` / `quest_for_flat`. Off, a floor holds only
what a test put there. This exists because the first build populated every seeded corridor, and `enemy_variety_test` went flaky (~40% of runs): its
corridor sometimes rolled a bat-carrying defender, whose half-damage bludgeon knocked a test zombie down (state `knockdown`, not a crowd member) and
whose presence changed what the crawler/crowd checks saw. **Any test that wants survivors sets `WorldState.survivor_rule = true` itself** (`survivor_ai_test`
and `quest_test` do); an old save has no key = off.

## Persistence and the pan

- `WorldState.survivors` (saved): per-record `x`, `hp`, `ammo`, `dead`, `met`, `aided`, `gave`, `calm`. `Survivor._exit_tree` writes back.
- A stair pan builds the destination as a passive backdrop: `building_floors._spawn_survivors(floor, true)` lays the survivors there as
  **scenery** (frozen, group `pan_scenery`), `go_live` wakes them (`wake()`) and skips a re-spawn (`_survivors_built`). **Flats do not
  pan** (a hider is only built when you walk in).
- Dev: `WorldState.dev_survivors` (non-zero forces every roll to succeed — used by tests; **no F1 button yet**).

## Not built / owner's call

- A gamepad/keyboard way to pick a quest choice (buttons in the speech bubble are mouse/touch only).
- Survivors following the player, trading, or fighting each other; survivor art (placeholder); survivor sounds beyond the screams/bangs/gunshots.
- Elevator survivors (the waiter stands *beside* the lift; nobody rides it).
- The dead's intelligence is v1: no group flanking, no door-opening, no fear of fire.

Locked by `tests/survivor_ai_test.gd` (every behaviour edge, half damage maths, placement census over 300 seeds × 3 runs, persistence,
pan scenery) and `tests/enemy_mind_test.gd` (investigate / search / give up / lose / spot / prey, the noise change, spitters). The older
`enemy`, `gun`, `listen`, `crowd`, `can_throw`, `softlock` and `plane` suites were run against the enemy changes (see the commit report).
