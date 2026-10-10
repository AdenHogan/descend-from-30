# Quests — the framework and the first two (BUILT v1, round 39)

> Owner brief: *"Let's start on quest mechanics, and populating our building with NPCs in contextually appropriate areas."*
> Design lives in `docs/QUEST_LIST.md` (outcomes + rewards per quest, the owner's words). This file is how they RUN.
> **Every `lines` / `label` / `journal` string in `data/quests.json` is a placeholder the owner rewrites** — the keys and
> structure are the contract. People: `docs/NPC_AI.md`. Code: `scripts/quests.gd` (the engine), `scripts/survivor.gd` (the people).

## The model

A quest is DATA (`data/quests.json`): a **giver** standing somewhere sensible, a set of **states**, and a **world** table saying what
the place looks like in later runs. The engine is a small static class, `Quests`.

```
quest := { number, title, kind: "corridor"|"flat", floors:[lo,hi],
           npc{…} | npcs{…}, giver, start, on_giver_died,
           states{ <name>: { journal, lines (or per run {"1":[…],"2":[…]}), choices:[ {label, need{ammo|item}, do[…]} ] } },
           talk_mourn{ run: [lines] },
           world{ <outcome>: { <run>: [ spec… ] } } }
```

### Where it happens (`Quests.site`)
Chosen **once per playthrough**, seeded on `master_seed + "questsite" + qid`, pinned in the quest's state — the same place in all three
runs. `corridor` quests pick a floor in their band and a post (the down-stair or beside a door); `flat` quests pick a floor and an
apartment whose door is **OPEN** (`seed_floor_door_states` pins which are open, and they stay open all arc — the player can always
get in). Both keep off merchant floors and **±3 floors of any fire origin**. A flat quest's flat gets no hider, no resident, no
ordinary dead (`Quests.is_quest_flat`); a corridor giver replaces that floor's random defender.

### The conversation (`talk` / `choose`)
Talking to the giver (`[{interact}] Talk`) starts the quest (a **NEW QUEST** banner + a journal entry) and shows the state's line and its
**choices** as buttons in the speech bubble. A choice may **need** bullets (`{"ammo": 10}`) or an item (`{"item": "007"}`) — a
choice that can't be met is shown disabled with a hint ("need 10 bullets"). Choosing runs its **effects** in order:

| effect | does |
|---|---|
| `take_ammo:N` / `take_item:ID` | removes bullets (across stacks) / one item (fixes the selected slot) |
| `give_item:ID[:n]` / `give_gun:PRESET` | hands over an item / a built gun (`GUN_PRESETS`) |
| `upgrade:ID` | grants a quest-only upgrade (`Quests.UPGRADES` → folded by `WorldState._stat_mods_sources`; saved in `quest_upgrades`) |
| `kill:NPC` | `Survivor.mercy_kill()` on that quest person (the owner's "put him out of his misery") |
| `outcome:NAME` | records the outcome the later runs read |
| `complete` | marks the quest done (banner, `note_quest_completed` → Valour) |
| `banner:TEXT` / `flag:NAME` / `goto:STATE` | feedback line / a once-flag / move to a state |

**Never half a trade.** Everything the player must hand over is checked first; if the quest is to GIVE a gun/item and it won't fit
(counting the slots the payment itself frees — `_slots_freed`), the WHOLE choice is refused ("No room to carry it.") and nothing is taken
(robustness rule 5). The giver **dying** (a zombie, a bad fight, the player's hand) moves the quest to its `on_giver_died` state for good,
with a **QUEST FAILED** banner if it had started.

### What persists (`WorldState.quests[qid]`, saved, string keys)
`{started, stage, outcome, done, flags{}, site{}}`, plus `quest_upgrades[]`; people are records in `WorldState.survivors` keyed
`q:<qid>:<npc>:r<run>`. `new_game` clears all of it. The journal's **Quests** page lists every begun quest with its current objective and a
done / failed marker (`Quests.journal_entries` → `character_panel._quest_bbcode`).

### Later runs (`world`, `populate_flat`, `settle_time_skip`)
Run 1 lays the quest's base people. **Runs 2 and 3 read the `world` table by the outcome** ("" = never resolved) and lay specs, each once:

| spec | lays |
|---|---|
| `{npc, mood}` | the person, alive, in that mood (`mourn` → a different line set) |
| `{body}` | the person dead, lying there |
| `{zombies, key}` | N of the dead (keys `q:<qid>:<key>:<i>`; a kill is remembered for good by `settle_time_skip`) |
| `{drop, half, key}` | an item drop, once (`half` = `ItemInstance.heal_scale 0.5` — heals half as much, shown "part used") |
| `{gun, key}` | a built gun drop, once |

## Built quests

### 010 — Johnny the Gun Guy (corridor, floors 9–22)
Johnny holds a post with his own gun (hp 10 — he is a fighter and will help you, see NPC_AI). *Ten bullets* → he hands you a **Durable
Hand Cannon** (`johnny` preset: Lv2, `G_durable`, 6 rounds). Then *twenty more* → one of two quest upgrades (your pick):
**Waste Not** (`Q_refund`, `gun_refund` +0.20: a shot has a 20% chance not to spend a round — folded with the gun's own Lucky Bullet in
`player._do_gun_attack`) or **Johnny's Eye** (`Q_crit`, `headshot_bonus` +0.10). "Not now" leaves the quest open; if you never pay, he is
simply still there in later runs and gives nothing — exactly the owner's outcomes B/D. If he dies the quest is `lost`.

### 001 — Old Lady Ethel (flat, floors 14–26)
Ethel (host, hp 4) begs; her bitten husband lies (patient — the dead don't go for the dying). Choices: **give a first aid kit**, **give
bandages**, **put him out of his misery**, **leave**.
- **Supplied** → run 1 she thanks you; **run 2** the couple have *turned* (two of the dead in the flat) and the kit is on the floor **at half
  strength** (heals 1 of 3 states, "part used"); run 3 the turned remain.
- **Mercy** → **run 2** Ethel is alive, *mourning* (her own lines) beside his body; **run 3** she is gone, both bodies lie there and a
  **revolver (5 of 6 rounds)** is on the floor.
- **Never helped** → by run 2 the couple have turned.

## Not built yet

- **006 Into the Breach** (a neighbour at the back of a breach room, the dead trudging toward them) — the prey logic exists (the dead go for the
  nearer meal) but the quest's timed layout hasn't been built. **002 / 003 / 004 / 005 / 007 / 008 / 009 / 011** per `QUEST_LIST.md`; the general
  quest log beyond the journal page, quest-room reservation and achievements are still open (GDD §11).
- Choosing a quest option with a **gamepad or keyboard**: the options are buttons in the bubble (mouse / touch) and nothing focuses them.
- A dev hook in the F1 menu to jump a quest's stage (tests set it directly).

Locked by `tests/quest_test.gd` (site rules, Johnny's trades incl. a full pack refusing whole, upgrades folding into the stat sheet,
Ethel's three outcomes across all three runs, kills remembered, the giver dying, save/load round-trip, the journal).
