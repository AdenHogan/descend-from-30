# NPC AI — survivors, allies and a smarter dead (BUILT v1, round 39; THEATRE + RESCUES round 41; HAVENS round 42)

> **Round 42 — the player's help is what makes anyone permanent.** *"Be them theatre or in peril, if you help them they should persist.
> If a theatre style gun or melee survivor is fighting on floor 26 and you help them in run 2, then in run 3 that floor should be a safe
> haven with no enemies. Helping survivors helps the player and helps the building. Likewise if you help an in-peril survivor, you can get
> an item as a thank you or scrap or money, but in subsequent runs they can also be a safe room and heal the player too."* → see
> **"Havens"** below.

> **Round 41 supersedes the fighting rules below.** *"Gun survivors: let's make it performative… they can shoot at enemies, hit
> them, but don't actually cause damage that wounds or causes death. The damage animations still fire, same with if the enemy
> attacks the NPCs, but no damage… No need to have them run out of ammo… NPCs are theatre dressing, with quests of course. What
> changes their fate is if the player intervenes or not… not from their own actions or if the player is delayed in reaching
> them."* → see **"Theatre"** and **"Rescues"** below. The half-damage section is kept as the maths behind
> `AllyCombat.performative = false`.

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

(The rows below describe the behaviours as built. **Round 41:** in the show survivors are never wounded and guns never empty, so
**retreat / wounded and "out of rounds" are unreachable unless `AllyCombat.performative` is switched off**; a rescue adds `shout` /
`fend` — see "Rescues".)

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

### Theatre (`AllyCombat.performative`, default **on** — owner round 41)

Survivors fight for show, and the same goes for the dead's bites on them. ONE static switch, `AllyCombat.performative`:

- A survivor's **swing or shot** plays the dead one's damage flash (`show_hit()` on the standard family and the big zombie: the white
  blink, 0.24 s) and nothing else — no damage, no stun, no knock-down. The dead one carries on with whatever it was doing, so a fight
  stays a lively scuffle rather than a stun-lock, and nothing a survivor does changes what is alive.
- The dead's **bite** on a survivor makes it flinch (the hurt pose, 0.25 s, a cry at most every 5 s) and takes nothing.
- **No gun runs dry** (`ammo` is never spent; a "gun with 0 rounds" never becomes fists), and a pretend shot carries only
  `SHOW_SHOT_NOISE` 420 px (a real one 900) so the show cannot drag the whole floor to a corridor post.
- They never get wounded, so the retreat / wounded states of the defender are unreachable in the show (they stay for the switch-off).
- Survivors can walk through and around the dead with no push or blocking to think about (they never had collision; now they never
  need to care either).
- With the switch **off** everything below ("Half damage") is live again — real hits, real bites, finite rounds. Every pre-round-41
  test in `survivor_ai_test.gd` runs that way, which is what keeps the maths and the patterns honest.

### Half damage (`AllyCombat`, FRACTION 0.5) — the maths behind `performative = false`

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

## Rescues (round 41) — the one place a survivor can die

> *"If it's a floor or an apartment with a survivor shouting for help, we can have a group of three enemies, slowly approaching the
> survivor. If the player doesn't intervene while the survivor fends off the attack, … the survivor can be killed in live
> gameplay. This adds an urgency, but only if we get 'help help'."*

**What it is.** A place (a corridor floor, or a walk-in flat) holds a person SHOUTING for help while **three** of the dead walk at
them (`SurvivorPlan.RESCUE_DEAD`, starting 250 / 320 / 390 px away, sent to the survivor's spot with `EnemyMind.hear`). They stand and
fend off for show (melee: the usual show swing; gun: pretend shots; bare-handed: a flail). Behaviours: `shout` (calling, "!") →
`fend` (a dead one is ON them) → `trust` / `hold` once saved.

**The clock.** Every second a dead one is within `SWARM_GAP` (64 px) of them counts; at `RESCUE_HOLD` (26 s) they are **overrun for
real** (`_overrun` → `_die`, "They didn't make it."). It only runs while the dead are ON them — pull them off (a nearer meal: you) or
kill them and it stops. It is saved on the record (`peril`), so leaving and coming back does not reset it, and it ticks before the
flinch freeze so bites cannot buy time. Dead ones that lose the thread are sent again every 5 s.

**Saved.** All three down → `rescue = "saved"`: they thank you (`rescue_saved`), count once as an NPC aided (+Valour), settle into
holding their post (a flat's person trusts you at once); talking hands over the gift they were keeping (`rescue_thanks` after).

**Fate across runs** (`SurvivorPlan.rescue_status`, worked out when asked — there is no time-skip step to forget):

| status | when | what the place holds |
|---|---|---|
| `future` | the event is in a later run (`appears`) | nobody yet |
| `open` | this is its run, unanswered | the event |
| `saved` | the player stepped in | the person, alive, in **every** later run |
| `lost` | overrun live, **or** the run ended without an answer | a body where they stood |

One identity per **place** (key `f12:rescue` / `1405:rescue`, no run in it), rolled once (corridor 12 %, walk-in flat 6 %), appearing in
a seeded run (weights 45 / 30 / 25), so events spread across the three runs and last runs' people are *seen* again. Never on floors
27–30 (the eased opening), never on a quest floor, never where a quest flat is; a rescue **replaces** the floor's random defender / the
flat's random hider (one survivor per post). A flat's ordinary dead are not laid while the event is on (just the three). Backdrop:
a pan's corridor rescue is frozen scenery (survivor + dead) and wakes with the floor. `WorldState.dev_survivors = 2` forces a rescue
at every eligible place (1 fills the ordinary slots only).

**Not built:** a rescue in the listen report ("someone shouting"), rescuers that are quest people, a rescue whose dead walk in from
the stairs, letting the revenant system punish a lost one.

## Havens (round 42) — who you stood by stays, and the building is quieter for it

`WorldState.havens` (saved, cleared by `new_game`) remembers a **place** the player helped — `"f26"` for a corridor floor, `"1703"` for a
flat — as `{run, kind: "post"|"rescue", floor, apt, snap}`. It is only ever written by the player's own intervention
(`SurvivorPlan.register_haven`): never by a survivor's fight, never by the player arriving late.

**Helping a fighting survivor (kind `post`).** A defender in a fight (`alert` / `engage` / `help` / `retreat`) whose dead are put down by
someone else — in the theatre nothing the defender swings can kill — has been **helped** after `AID_KILLS` (2) of the dead die within
`AID_RANGE` (320 px) of them (`Survivor.on_dead_down`, called by every enemy's `_die` through the `survivor` group). They say `helped`,
count once as an NPC aided (+Valour), and the floor becomes a haven. A quest giver, a rescue and a frozen backdrop copy never count; a
floor with a quest giver, or a rescue still to happen/happening, cannot become a haven (`SurvivorPlan.can_haven_floor`). Helped in run
3: thanked (`helped_last`) but nothing is written — there is no later run.

**What a haven is, from the NEXT run on** (`current_run > run`; never the run it was earned in — that floor's dead are already seeded):

| haven of | the place holds |
|---|---|
| a **floor** (`post`, or a rescued corridor survivor) | **no corridor dead** (`get_floor_zombie_count` → 0), **no boss** (`floor_has_boss`), and **no stair enemies on its two staircases** — a staircase is seen from the two floors it joins, so floor *F* empties chokes *F* and *F+1* (`stair_enemy_count`; this also thins floor *F+1*'s down shaft). Flats on the floor keep their own dead. |
| a **flat** (a rescued hider's) | no dead and no riser inside (`room.gd`); the corridor outside is untouched |

The person is the same one: a `post` haven's defender is rebuilt from the snapshot (`look`, `weapon`, `ammo`, `post`, `post_kind`)
under a **run-less key** `f26:haven` (`SurvivorPlan.haven_for_floor`), holds the same post, greets you (`haven`) and cannot be
"helped" or paid for again (`helped`/`credited` are set on the record). They are not healers — the floor is the gift. A rescued survivor
is already a run-less record (below), so it needs no rebuild.

**Rescued survivors (kind `rescue`).** The thank-you is drawn from `SurvivorPlan.RESCUE_GIFTS`: the hider's items plus **scrap** (a Scrap
Bag, 28) and **money** (Bank Notes, 40) — the ordinary hider's `GIFTS` table is unchanged. In every **later** run
(`rec.saved_run < current_run`) talking to them **patches the player up all the way, once a run** (`_tend_player`; `tended_run` on the
record): `haven_tend`, then `haven_again` the same run, `haven_fine` if you are not hurt. A corridor rescue also makes its floor a
haven; a flat rescue makes the flat a safe room.

**Unaided survivors are exactly as before** — re-rolled per run, gone when the dice say so. Waiters (calmed) and ordinary hiders (trusted,
a gift given) are *not* "helped" by this rule; only a fighting defender and a rescue are.

Locked by `survivor_ai_test` (`_test_stand_by_a_defender`, `_test_haven_effects`, `_test_rescue_reward_and_heal`, `_test_safe_room`,
`_test_haven_roundtrip` — mutation-checked: the aid count, the aid range, the floor / staircase / boss effects, the safe room, the heal,
the same-run rule and the rescue registration each fail a check when removed).

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

## Round 40 audit additions (details and numbers: `NPC_BALANCE.md`)

- **The Talk key is claimed.** A survivor offering `[Talk]` holds the interact press (`WorldState.claim_interact_for_talk`, time-based so it does not
  depend on node order); every scene-changing E-poller (doors, the powered lift, the lobby door, the floor backpack) already asks
  `TutorialManager.interact_guarded()`, which now includes the claim. A survivor itself asks `tutorial_guard_active()` (just the tutorial's window).
  Without it a defender posted beside a door, or a waiter 45 px from the lift (80 px ride range), changed the scene on the same press.
- **Investigating has a time limit** (`EnemyMind.INVESTIGATE_SLACK`: the walk to the spot + 3 s). An unreachable spot — past the corridor's end,
  behind a wall — used to leave a zombie pushing at the wall for ever.
- **A quest giver cannot be killed before the first conversation** (`Quests.protects`, data opt-out `protected_until_met`): the dead can wound
  them, never finish them. Johnny was dead before he could be met on ~37% of real floors.
- **Known, deliberate:** survivors are not in `resident_target` (the player's swing/shot/push can never hurt them) and are not in any fire/blast group.

## Persistence and the pan

- `WorldState.survivors` (saved): per-record `x`, `hp`, `ammo`, `dead`, `met`, `aided`, `gave`, `calm`. `Survivor._exit_tree` writes back.
  `WorldState.havens` (saved, string keys) is the separate ledger of what the player helped (see "Havens"); a helped defender is rebuilt under `f<floor>:haven`.
  Ordinary survivors are keyed **per run** (a new run is a new roll — they dwindle); a **rescue** is keyed per **place** (no run) and keeps
  `rescue` (`pending`/`saved`/`lost`), `appears` (1-3), `peril` (seconds left) and `credited` (the Valour was paid) across all three runs.
- A stair pan builds the destination as a passive backdrop: `building_floors._spawn_survivors(floor, true)` lays the survivors there as
  **scenery** (frozen, group `pan_scenery`), `go_live` wakes them (`wake()`) and skips a re-spawn (`_survivors_built`). **Flats do not
  pan** (a hider is only built when you walk in).
- Dev: `WorldState.dev_survivors` (1 forces every ordinary roll to succeed, 2 also forces a rescue at every eligible place — used by tests;
  **no F1 button yet**).

## Not built / owner's call

- A gamepad/keyboard way to pick a quest choice (buttons in the speech bubble are mouse/touch only).
- Survivors following the player, trading, or fighting each other; survivor art (placeholder); survivor sounds beyond the screams/bangs/gunshots.
- Elevator survivors (the waiter stands *beside* the lift; nobody rides it).
- The dead's intelligence is v1: no group flanking, no door-opening, no fear of fire.

Locked by `tests/survivor_ai_test.gd` (every behaviour edge, half damage maths — switch off — and the theatre — switch on, placement
census over 300 seeds × 3 runs, persistence, pan scenery, and the rescues: status by run, the overrun clock, saved + gift + next run, a flat's) and `tests/enemy_mind_test.gd` (investigate / search / give up / lose / spot / prey, the noise change, spitters). The older
`enemy`, `gun`, `listen`, `crowd`, `can_throw`, `softlock` and `plane` suites were run against the enemy changes (see the commit report).
