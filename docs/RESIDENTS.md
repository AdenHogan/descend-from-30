# Residents — survivors behind locked doors (BUILT v1, owner round 32)

> Survivors in the CORRIDOR and in walk-in flats (defenders, waiters, hiders, quest givers) are a different system: `NPC_AI.md`. A resident's flat never holds a hider or a quest.

> "Let's populate some of the locked door rooms with NPCs. We want them to shout at the player when
> inside demanding the player leaves, moving towards, running around, even threatening with weapons.
> If player scavenges items, NPCs can beg not to, might get violent, or offer to trade."

## Who lives where

- Only behind a **LOCKED** door (`SHUT_LOCKED` / `BARRICADED_LOCKED`), never on Floor 30, never in a flat
  on fire (`WorldState.resident_eligible`).
- Chance per still-locked flat: **45% / 35% / 25%** for runs 1 / 2 / 3 (`RESIDENT_CHANCE` — survivors dwindle).
- Seeded per (flat, run) and **settled while the door is still locked**: `WorldState.set_door_state` calls
  `resident_for` the moment a lock gives (key, force, crowbar), so the person is still there when you walk in.
  Kept in `WorldState.residents` (`"apt:run"` → record, saved, cleared by `new_game`; a new run is a new key → a
  new roll, only for doors still locked).
- A resident's flat has **no zombies** and no riser (they've kept the dead out); its loot is seeded as usual.
- Listening at their door gives a voice, not a count (`npc_dialogue.json` → `listen`).

Record: `temper`, `look` (homeless-pack character 1-6), `weapon` (item id or ""), `goods` (`[{id, amount}]` —
trade stock / pockets), `hp`, `dead`, `x`, `violent`, `warned`, `traded`, `offered`, `met`, `lash`, `turn`, `spot`.

## Tempers (`RESIDENT_TEMPERS`: run 1 45/30/25, run 2 35/30/35, run 3 25/25/50 scared/trader/hostile)

| | moves | when you search | when hit |
|---|---|---|---|
| **Scared** (3 hp, 35% a knife) | keeps away; RUNS for the far wall when you come within 150; cornered it cowers. Cornered ~2.2 s: 40% (`lash`) snap and swing ONCE then run again, else bolt past you to the other side | begs (`scavenge_beg`), sobs when you take (`item_taken`) | flees, or snaps (`lash`) |
| **Hostile** (5 hp, always armed) | squares up ~72 px from you on its side and PACES; brandishes the weapon every 6-9 s (`threaten`); crowd it (<44 px) → `too_close`, stay 1.6 s more → attacks | first search: ONE warning (`scavenge_warn`); a second search or taking anything → attacks for good | fights |
| **Trader** (4 hp, 50% armed) | keeps ~92 px off; with a deal on the table walks up to arm's length | offers a swap: one of its goods for the best thing it wants in your pack (`trade_offer`); `[Trade]` / `[No]` in its bubble or the interact key. Nothing it wants → `no_trade`. Take something after it spoke → `trade_refused`, and 50% (`turn`) turn hostile | turns hostile |

Everyone shouts `leave_demand` every 4.5-7.5 s; after 4 with nothing happening they go quiet (`calm`). Any
search / hit / crowding starts the shouting over. Re-entry: `enter_again`; walked in with their key: `enter_key`.

**Attacks**: wind-up 0.45 s (the look's Special animation), 1 damage via `player.receive_hit` (so it closes the
pack, interrupts listening, etc.), 1.4 s between swings, only on the same plane (never at the balcony).

**Trading** never destroys the player's things: the wanted item is removed, the goods added; if they don't fit the
item goes back where it was. The resident keeps what you gave it (it's in its pockets when it dies). The offer is
dropped if the item leaves your pack. A resident's FIRST trade counts as an **NPC aided** (`WorldState.note_npc_aided`
→ +4 Valour at the end of the session, owner's call) — once per resident, however many swaps follow. What it wants: `WANT_SCORE` (first aid, bandages, bullets, painkillers, food,
… any weapon 5; junk / keys / money never), avoiding the item in your hand.

**Death**: a last word, the Death animation, lies there for the rest of the run (re-entry too), drops its weapon +
goods as world drops, and leaves a chronicle trace ("Killed someone still alive behind a locked door.").

## Scripted residents (owner round 32c)

The owner writes fixed three-line SCRIPTS: line 1 when you walk in, line 2 the first time you search their things,
line 3 the second time (`npc_dialogue.json` → `scripts.<temper>.<run>.<id>`; letters are only identifiers). v1 has
11 scripts (A–K) for **scared residents on run 1**; runs 2/3 and the other tempers have none yet and use the pools.

- Picked when the resident is rolled (`WorldState._pick_resident_script`, the resident's seeded RNG): never a script
  another resident already has this run while unused ones remain, so 11 scared residents in a run get 11 different
  scripts. Stored in the record (`script`), with how many searches you've made (`searches`, kept across re-entry).
- A scripted resident says ONLY its three lines plus `hurt` / `death` from the pools — no "get out" shouts, no
  cornered / calm / item-taken lines (they would break the script's character, e.g. I only cries). It still BEHAVES
  like its temper (runs, cowers, may snap once — silently). Coming back: no second greeting; a third search: silence.
- `{player}` in a line = the current character's name (script G). Stage directions like `(cries)` / `(whisper)` show
  as written.

## Revenants — kill one and they come back (owner round 32b)

> "If you fight and kill a resident, they will respawn in a subsequent run as a crawler or spitter, but let's punish
> the player by making them 20% faster and 20% more health."

- A resident killed in run 1 or 2 is remembered by its flat (`WorldState.revenants`, cross-run, saved, cleared by
  `new_game`; `note_resident_killed` from `resident_npc._die`). Killed on run 3 → nothing (no run left).
- From the NEXT run on, `room._spawn_revenant` lays a **crawler or spitter** (seeded per flat) where they fell —
  `enemy.make_revenant()`: SPEED ×1.2 and max HP ×1.2 **rounded up** (`REVENANT_SPEED_MULT` / `REVENANT_HP_MULT`; a
  1-hp crawler comes back with 2, a 7-hp spitter with 9). Group `revenant`. It's in addition to the flat's ordinary
  dead (a resident's flat had none while they lived), not in a BLAZE / CHARRED flat.
- It stays every run until killed: a kill is ordinary kill memory in-run, and `_settle_revenants` (at the time skip,
  before the kill memory is cleared) makes it permanent. The flat never gets a new resident again.
- Listening at the door counts it. The first sight of it each run, the PLAYER says a line from
  `npc_dialogue.json` → `revenant.recognise` (owner-authored).
- Not in the balcony-descent backdrop (pops in on landing, like residents).

## Robustness

- An **Area2D with no collision layers** — it can never block, shove or trap the player (softlock rule).
- A combat target through group `resident_target` (`player._combat_targets()` feeds melee / gun / push); never in
  `zombie`, so zombie memory, crowd spacing, cans, noise, the unjam valve etc. never touch it.
- Its speech bubble is a screen-space panel (`CanvasLayer` 2) in group `hud_widget_extra`, which
  `HUD.pointer_over_widget` honours — clicking `[Trade]` is never also a swing or a walk.
- State the player can see is written back to the record as it changes (`WorldState.update_resident`).

## Dialogue — `data/npc_dialogue.json` (owner-authored)

One pool of lines per (temper, moment); a line is picked at random, never the same twice running; `{give}` /
`{get}` are the trade's item names. An empty pool = that moment stays silent. Moments used by the code:

- all: `enter`, `enter_key`, `enter_again`, `leave_demand`, `too_close`, `calm`, `hurt`, `death`
- scared: `cornered`, `scavenge_beg`, `item_taken`, `lash_out`
- hostile: `threaten`, `scavenge_warn`, `attack`, `item_taken`
- trader: `trade_offer`, `trade_reminder`, `trade_done`, `trade_declined`, `trade_refused`, `turned_hostile`, `no_trade`
- `listen`: one line per temper (heard at the door)

`resident_npc_test` fails if any of these pools is empty.

## Art (placeholder)

The purchased homeless pack (`assets/homeless-character-pixel-art-pack/1..6`: Idle / Walk / Special / Hurt /
Death) at 1.6x (stands level with the player's rig). Look 2 carries a stick in its own art and is used exactly
for bat / club holders; anyone else holding a weapon shows the item's icon small in hand (placeholder).

## Dev

F1 → **Residents**: NORMAL / EVERY LOCKED FLAT / ALL SCARED / ALL HOSTILE / ALL TRADERS (`WorldState.dev_residents`,
not saved; applies to flats not yet decided this run).

## Not built / open

- No voices or sounds (shouts are text only); shouting doesn't make noise for the dead outside.
- Not drawn in the balcony-descent backdrop (a resident below appears on landing).
- No quests yet.
- Not searchable as a body (their things drop instead).
- Real resident art + a held-weapon pose.
