# Round 49n sweep - the descent ramp, measured with the bot

Question (owner, 2026-11-04): *"run a bot sweep to measure the new difficulty"*, after the tutorial and the first floors were put back to the old numbers
and the new ones were ramped in over floors 28-25 (`WorldState.descent_ramp`).

Raw per-configuration tables: `round49n_summary.md` (the `bot_summary.py` output, unedited). Per-run reports are not kept (36 playthroughs x 3 characters).

## What was run

36 playthroughs, **6 seeds (101-106) x 6 configurations**, 3 characters each = 108 characters, on the tree at `5a3114f1` (the ramp is in; the bot's rest rule is fixed).

| config | what it is | ramp |
|---|---|---|
| `none` / `none_r0` / `none_r1` | the briefed dive: 2 hammers, a gun with 8 rounds, 2 first aids, no scavenging | as shipped / old rules on every floor / new rules on every floor |
| `need` / `need_r0` / `need_r1` | scavenges what it needs (doors, nodes, the bench, the shop) | as shipped / old / new |

`--ramp=0` is `WorldState.dev_ramp_override = 0` (the pre-49l/49m reach, followers, bullets and toolbox on EVERY floor); `--ramp=1` is the full new rules on every floor.
What `--ramp` does NOT switch: the workbench rework, the shop changes (no bullets, wider wares), cash +20 %, scrap +10 % - those are in all six configurations.

## Result

Pooled over 18 characters per row (17 for `need_r0`: one playthrough lost a character to a timeout - see below).

| config | n | deepest floor, median / mean | by run (median) | time alive (median) | stage-hits taken (median) | kills (median) | outcomes |
|---|---|---|---|---|---|---|---|
| none_r0 | 18 | 25 / 23.9 | 24 / 22 / 26 | 85 s | 11 | 11 | 18 died |
| none | 18 | 25 / 24.2 | 24 / 24 / 26 | 83 s | 11 | 10.5 | 18 died |
| none_r1 | 18 | 25 / 24.0 | 25 / 23 / 26 | 82 s | 11 | 11 | 18 died |
| need_r0 | 17 | 24 / 21.9 | 20 / 24 / 25 | 918 s | 15 | 35 | 15 died, **2 timeouts** |
| need | 18 | 24.5 / 23.9 | 23 / 25 / 25 | 495 s | 19.5 | 28.5 | 18 died |
| need_r1 | 18 | 24.5 / 23.7 | 22 / 24 / 26 | 605 s | 15 | 34 | 18 died |

**Nobody reached the lobby, nobody reached floor 10** (deepest of 108 characters: floor 15, `need_r0`).

### How to read it

* **The ramp is not visible in this bot.** Old rules everywhere, new rules everywhere and the shipped ramp give the same median deepest floor (25 / 25 / 25 for the dive, 24 / 24.5 / 24.5 when it scavenges) and the same stage-hits for the dive (11 - it dies when the kit is spent). With 6 seeds per row a floor of difference is noise (the per-run medians move 3-4 floors between rows that differ only by seed order). **I cannot say from this sweep that the +8 px reach, the followers or the bullet / toolbox cuts made the first floors harder or easier; I can say they did not move the bot's depth by more than the noise.**
* **Where the bot dies is the same everywhere: floors 24-26** (`none`: 6 x f26, 4 x f25, 3 x f24; `need_r1`: 4 x f26, 4 x f25, 2 x f24, 3 x f21). That is the end of the kit: both hammers and the 8 rounds are gone by about floor 26 in every row. The ramp ends at floor 25, so the "tough" numbers start exactly where this bot's kit runs out - which also means **a better-equipped player is the one who would feel the ramp, and the bot is not that player**.
* **Scavenging is worth ~1 floor and ~7x the time** (`need` median 24.5 against 25 for the dive) - the same finding as rounds 44 / 45 / 49f.
* **Stage-hits per scavenging character: `need_r0` 15, `need` 19.5, `need_r1` 15.** Not ordered the way the rules would predict (the shipped ramp should sit between r0 and r1); again within the noise.

### Confounders (do not read a ramp effect into the table)

1. n = 6 seeds a row; the bot is real-time and chaotic (the same seed does not replay identically).
2. The module-width flip (round 49j), the workbench rework (49m) and the shop changes (49l) all landed since the last sweep (`round49f_sweep.md`), so **this sweep cannot be compared to round 49f's** either.
3. The bot has no way to feel the new bench / repair rules or the no-bullets shop; it takes few upgrades.
4. Pass 1 of this sweep was killed twice by container restarts and its partial results were counted as finished (three seed-104 `need` runs had 2 characters); the whole folder was re-run. Pass 1 is not used anywhere above.
5. The bot's own rest rule was changed in the middle (see below) and applies to every row of pass 2.

## What the sweep found (bugs; all in `docs/BUG_LEDGER.md`)

1. **A bot bug, fixed:** the `none` bot sat "stuck" for 150 s in 7 of 18 playthroughs. It treated any dead body in `chase / attack / hit` within 260 px as "coming for me", including one biting a survivor in a performative fight that never ends, so a winded bot never rested; it kited instead - and since round 49d walking in combat mode stops stamina recovering, it could never get its wind back. A body now counts only if it is after the bot or within 90 px. Not a game fault.
2. **A game bug, fixed:** the two `need_r0` timeouts (seed 102 run 2, seed 101 run 3, both floor 25, `NO_PROGRESS ... shop=open ... pack=open`). Both characters arrived at the floor-25 merchant after the previous one had died there; one [interact] press opened the shop AND knelt them over the previous character's body (merchant.gd and player_corpse.gd each answered). `floor15_test` reproduces it (and three siblings: a powered lift, a flat door, the pack closing on its own opening press); each is mutation-checked. It was in the `r0` row only because that row happened to have two characters die on floor 25 followed by a character reaching it; the bug is independent of the ramp.
3. **A process bug in `bot_sweep.py`, fixed:** a restart-truncated playthrough counted as finished.
4. Seen again and NOT investigated: `TAKE_NO_EFFECT` x1 and `DROP_NOT_TAKEN` x2 in `need` (a floor drop that stayed after three presses with a free slot) - the survivor-[Talk] suspicion in the ledger is unchanged.

## Did the fix clear the two timeouts?

**Replay result (fixed tree, `need_r0` seeds 101 and 102, 6 characters):** all six died as normal (101: Joe f22, Vivianne f26, Amina f21; 102: Amina f25, Alex f26, Vivianne f23), **0 timeouts, 0 anomalies, 0 `SCRIPT ERROR`s**. That is **absence of evidence, not proof**: the bots are real-time and chaotic (101's third character died on floor 21 this time, not at the floor-25 lift where it stalled before), and the bot does not log meeting its own body, so I cannot say the replay ever put a character beside its predecessor's body at the lift. The fix rests on `floor15_test` (which reproduces the double answer on the old code and fails when each part of the fix is removed), not on this replay.

## What this sweep does not tell the owner

Whether the ramp FEELS right: that needs a human at floors 28-24 with a real kit, which is the owner's own sweep. The numbers to look at while playing are in `docs/BALANCE_AUDIT_2026-11-04.md` "Changed since" and the ramp table in CLAUDE.md round 49n (reach 30 / 30 / 32 / 34 / 36 / 38 for a standard on floors 30 / 29 / 28 / 27 / 26 / 25).
