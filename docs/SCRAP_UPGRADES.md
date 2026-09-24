# DF30 — Scrap & Item Upgrades

> **Status: BUILT v1** (the spec below is what it was built against; the notes in
> "What's built" record the interpretations + what's still open). Locked by
> `tests/weapon_upgrade_test`.

## What's built (v1)

- **Scrap counter** — `WorldState.scrap` (per-character: reset by the time skip, carried on the
  corpse and MERGED into the finder's total) + `scrap_unlocked` (the HUD counter appears with the
  first bag; cross-run like the wallet unlock). **Scrap Bag (037)** never takes a slot:
  `add_to_inventory("037")` empties it into the counter (works with full pockets). HUD: "SCRAP N"
  above the wallet.
- **Faucets** (each on its OWN seeded RNG, so no other loot roll shifted):
  charred apartment anchors — 75% hold a big bag (14–30); an ordinary room's EMPTY anchor — 7%
  a small bag (6–14); maintenance rooms — ~16% of anchors (spare parts, right by the bench).
  Never sold by the merchant.
- **The bench** — `[E] Upgrade / salvage` at the maintenance workbench opens `workbench_ui.gd` (a
  pausing panel like the journal): your gun/hammer, the perks each has, the next level's cost and
  the PICK-ONE-OF-TWO. Costs exactly as specced (50 → a spare Lv1 + 80 → a spare Lv2 + 100); the
  LOWEST qualifying spare is fed in, never a better one. Rules + perks: `WeaponUpgrades`
  (`weapon_upgrades.gd`, one table). Action: `WorldState.upgrade_weapon(slot, perk)`.
- **Per-weapon perks** on `ItemInstance` (`level`, `perks`), applied through the fold
  (`perk_add` / `perk_mult` / `has_perk_flag`), saved with the item, kept on a corpse, and shown as
  a "LvN" tag on the slot. Gun: Aim Assist, Durable Hand Cannon, Silencer, Through-and-Through,
  Lucky Bullet, Bigger Bang — all wired into real combat.
  - **Durable Hand Cannon** (owner, round 2): the gun now WEARS (below), and this perk halves the
    wear — a mark every **12** shots instead of 6 — and forcing a door never damages it. (It used
    to be "+6 rounds" while the gun had no durability.)
- **Gun wear (built, owner's rule)** — the gun has **8 durability marks** and loses **one every 6
  rounds fired** (48 shots from new). Only a round actually spent counts (a Lucky Bullet free shot
  doesn't). Worn out = BROKEN like any weapon: it won't fire, stays in inventory, and a toolbox
  restores it (and resets the count). The count toward the next mark rides the gun
  (`ItemInstance.shots_since_mark`, saved/dropped/corpse-carried); `shots_per_mark()` is 6 ×
  the `shots_per_mark` perk mult. Old saves' guns (no durability yet) load as new. Forcing a door
  still DAMAGES a gun separately (worse aim + 10-round mag until repaired). The HUD slot shows the
  durability bar under the mag count.
- **Salvage (built, owner's calls — "give junk a use"; round 3: bench-only + Tinkerer)** — the
  workbench's **Salvage** tab breaks any carried item down for scrap. **Only at a workbench** —
  never anywhere — so inventory can't go in and out easily and the small pockets keep their
  tension. By default it pays **RUBBISH scrap** (`Salvage.YIELD_BASE` 0.4 × the values below);
  the **Tinkerer** merchant upgrade (`U_tinker`, offered at the every-five-floors merchant pick;
  can be kept forever via Descent Valour) raises the yield ×2.5 to the FULL values. There is no
  extra incentive for using the bench itself (benches come every 3 floors). Full-yield values (`Salvage` in `salvage.gd`, one table; action
  `WorldState.salvage_item`). Junk 2–6 each (metal-bearing junk — umbrella ribs, a remote's
  board — the most); weapons/tools 4–25 (Gun 25, Sword 20, Aluminium Bat / Toolbox 16, Hammer /
  Crowbar 14…). **Worn items give less:** × (0.4 + 0.6 × durability left) — a broken one still
  gives 40%; a damaged gun ×0.7; a stack counts every item. An upgraded weapon also returns **40%
  of the workbench scrap sunk into it**. A loaded gun's rounds come back as bullets. Junk breaks
  down on one press; anything else asks to confirm. Not salvageable: healing items, clothes/rope,
  ammo, keys, money, the Scrap Bag.
  - **Supersedes the original spec's gated "tier-5 dismantle perk"** (owner): dismantling is
    always available at a bench, and the upgrade now improves the YIELD instead of unlocking it.
  - **Balance intent:** without the Tinkerer a bag of junk (~5 slots) is ~6–8 scrap and a spare
    gun 10 — a trickle; with it, ~15–20 and 25. Never a substitute for a charred ruin (14–30 per
    bag); scrapping a spare weapon stays a real choice against keeping it as upgrade feed.
  - **Hammer tree = PLACEHOLDER** (the doc leaves it to the owner): Heavy Head (+1 dmg) / Reinforced
    Handle (×2 durability); Door Breaker (forcing + barricades cost no durability) / Sweeping Blow
    (a swing also hits a 2nd enemy); Skull Splitter (15% to drop an ordinary enemy outright) /
    Featherweight (−40% swing stamina). Rename/rebalance in `WeaponUpgrades.PERKS`.
- **Discard memory (built)** — a dropped item now remembers EXACTLY what it was
  (`WorldState.instance_to_dict` on the world drop): durability, magazine, damage, level + perks,
  stack count; a BROKEN weapon/tool drops too (repairable, and upgrade feed); two drops on one spot
  no longer overwrite each other. (Before: a drop was re-created from its id — a worn weapon came
  back at full durability, an upgraded one would have come back Lv1, broken ones vanished.)
- **Still open:** merchant-sold pre-upgraded
  weapons; more weapon trees; real bench art; balance numbers (playtest).

## What's built (v2): make it YOURS — tuning, legendary names, heirlooms

Owner, round 4: *"re-look at weapons so players can really add their own stats within scope, so
upgraded weapons feel like their own. At legendary those weapons get a cool title so they feel
personal"* + *"legendary +++ tiers that really make these weapons sing if you can keep hold of
them… like a new game plus, certain upgrades can only happen there"*. All data in
`WeaponUpgrades` (`weapon_upgrades.gd`); locked by `weapon_upgrade_test`.

- **Seven levels.** Lv1-3 ordinary → **Lv4 LEGENDARY** → **Lv5/6/7 = Legendary + / ++ / +++**
  (heirloom tiers). `WeaponUpgrades.tier_name` / `ItemInstance.tier_label` ("Legendary +") /
  `tier_tag` (HUD slot: "Lv2", "LEG", "LEG++").
- **Every weapon levels now** (knife, sword, gun, golf club, cricket bat, baseball bat, aluminium
  bat, hammer — `WeaponUpgrades.KIND`). A weapon WITH a perk tree (gun, hammer) still picks one of
  two perks at Lv2-4; one without levels on tuning alone (trees for the others are future content).
- **Feed by FAMILY** (so a rare sword or bat can reach legendary at all): a Lv3/Lv4 step strips a
  spare of the same weapon OR the same melee family — **blades** (knife, sword) / **blunt** (hammer,
  golf club, cricket bat, baseball bat, aluminium bat). The gun still needs a gun (the owner's
  spec). An exact copy is preferred at the same level; a **legendary is never fed**.
- **TUNING — the weapon's own stat sheet.** Every level-up grants **2 points** (`POINTS_PER_LEVEL`:
  6 by Legendary, 12 by +++). The player spends them at the bench's **Tune** tab (stage with − / +,
  then **Set in steel** — points are permanent; no respec, so the build is theirs). Each stat has
  a **cap** (the "within scope"), and **each heirloom tier lifts every cap by one** — the crazy
  numbers exist only on heirlooms. Applied through the same per-weapon fold as perks
  (`ItemInstance.perk_add/perk_mult` now sum tuning ranks too), so combat reads one number.

  | Melee stat | Per rank | Cap (Lv≤4) | Gun stat | Per rank | Cap |
  |---|---|---|---|---|---|
  | Weight | +1 damage | 1 | Sights | +4% head + body hit | 3 |
  | Edge | +4% chance to drop an ordinary enemy | 3 | Magazine | +2 rounds | 3 |
  | Reach | +6 px reach | 3 | Oiled | wears 25% slower | 4 |
  | Handling | swing recovers 8% faster | 3 | Hand-loaded | +5% free shot | 3 |
  | Balance | swing −10% stamina | 3 | | | |
  | Temper | +25% durability | 4 | | | |

  Reach and Handling are NEW combat hooks (`player._do_melee_attack`: range + `perk_add("reach")`,
  cooldown × `perk_mult("cooldown")`); the rest reuse the perk stats.
- **LEGENDARY names.** Reaching Lv4 draws a **title** from a word bank keyed by what the weapon is
  best at — its highest-ranked tuning, else its latest perk's flavour (`title_theme`,
  `TITLE_BANKS`: Weight → "Widowmaker", "Bonebreaker"…; Reach → "Long Goodbye"…; Silencer →
  "Lullaby"…; Bigger Bang → "Housewarming"…). It reads **Hammer "Widowmaker"** everywhere
  (`get_display_name`), remembers who forged it (`forged_by`, shown on the bench: "Forged by X,
  afternoon"), leaves a trace in the chronicle, and **the player can rename it** on the Tune tab
  (`rename_weapon`; printable ASCII for the pixel font, 18 chars).
- **HEIRLOOM tiers — the new game plus.** Beyond Legendary a weapon needs to have **crossed the
  lobby door** — been left by the door at an escape and collected from the shopkeeper in a LATER
  game — **1 / 2 / 3 times** for + / ++ / +++ (`crossings`, counted when the shopkeeper hands it
  over). So +++ takes at least four games with the same weapon. Scrap is paid in **INSTALMENTS
  that ride the weapon** (`forge_paid`; bench **Upgrade** tab becomes "THE HEIRLOOM FORGE": Put in
  25 / Put in all I can) — any character holding it can add to it, even before it has crossed, and
  once it's paid AND crossed the bench offers the tier's two specials (`forge_heirloom` →
  `upgrade_weapon`). **Lose the weapon, lose
  the investment** — the keep-hold-of-it tension. Costs `HEIRLOOM`: **+ 400 / ++ 500 / +++ 600**,
  sized against the measured income below (each about two to three characters' scrap).
- **SPECIAL MODS — real upgrades that make a weapon special** (owner, round 5: *"add fire to your
  sword so striking an enemy has a 20% chance of setting it on fire"*). Every level-up that has no
  tree perk — a tree-less weapon's Lv2-4 and **every heirloom tier** (gun and hammer too) — offers a
  **pick of two specials** (`WeaponUpgrades.MODS`, seeded per weapon + level, never one it already
  has). Proc chances **grow +5% with each heirloom tier** (`mod_chance`; the bench shows the live
  number), so an heirloom's specials sing. Hooked in `player._weapon_mods_on_hit` (melee swing,
  Sweeping/Cleave second target, landed gun shots):

  | Special | Pool | Effect |
  |---|---|---|
  | **Fuel-Soaked** | melee | 20% a hit sets the enemy alight (~6 s burn) |
  | **Incendiary Rounds** | gun | 20% a landed shot sets it alight |
  | **Serrated** | melee | 30% a hit opens a wound: 3 more damage over ~4.5 s |
  | **Bell-Ringer** | melee | 25% a hit knocks an ordinary enemy flat |
  | **Stopping Power** | gun | 30% a landed shot knocks an ordinary enemy flat |
  | **Home Run** | melee | every hit shoves the enemy back (a real push) |
  | **Second Wind** | both | 30% of max stamina back on a kill |
  | **Mended** | melee | a killing blow costs no durability |
  | **Cleave** | melee | a swing also strikes a second enemy (not offered if it already sweeps) |
  | **Quick Hands** | gun | fires 30% faster |

  Burns and wounds are a `WeaponAffliction` node on the enemy (every rig — standard, crawler,
  long-arm, spitter, big/boss); a `weapon_lit` flag keeps a weapon-set fire from being put out by
  the floor's fire bookkeeping. Big zombies/bosses can't be knocked flat or shoved (as before) but
  do burn and bleed; the scripted tutorial neighbour is never afflicted. **Burning enemies hit twice
  as hard** — the world's existing fire rule, kept on purpose as the risk of a fire weapon (one
  line to change if it plays badly). Titles take their theme from the newest special first — a fire
  sword is a "Firestarter", "Kindling"… (`TITLE_BANKS` fire / bleed / stagger / shove / wind).
- **Salvage** now refunds 40% of EVERYTHING sunk in (`scrap_sunk`: levels + heirloom tiers +
  instalments). **At the door** a weapon is worth Valour by level (docs/PROGRESSION.md "The door").
- **Measured scrap income** (`tools/economy_report.tscn` — builds every apartment on every floor
  with the real loot rolls; `-- --seeds=N`, slow — ~25 min a seed): the whole building holds
  **~630 scrap in run 1, ~1,090 in run 2** (more charred ruins as the fire climbs) **and ~420 in
  run 3**, i.e. 3-7 per apartment, + ~27 in the maintenance rooms. A character who searches ~45
  apartments on the way down (1-2 a floor) finds **~200**. So Lv1 → Legendary (230 + spares) is
  one thorough character; each heirloom tier is two to three. (One seed measured; the run-1 figure
  matched a second partial run. Treat it as a ceiling-based estimate until a playtest logs real
  hauls.)
>
> Ties into: `STORE_DESIGN.md` (upgrades/economy), the fire hazard
> (`CLAUDE.md` Hazard 3), `THREE_RUN_ARC.md` (escalation across runs), and
> `ITEMS_SHEET.md` (item catalog).

## Concept

**Scrap** is a *second* currency, separate from Bank Notes / the Wallet. Bank
Notes buy things from the merchant; **Scrap upgrades the gear you already
carry.** It is the "make my stuff better" resource, and its main faucet is the
one thing that otherwise only *destroys* value: **fire**.

The point is to turn fire from a pure hazard into a **risk-vs-reward decision**:
a burnt-out apartment has no normal loot to scavenge, but it is rich in
**scrap**. So "do I let this place burn?" becomes a real question — you trade a
room's ordinary loot (and the danger of the flames) for scrap to level up a
weapon. Because fire escalates across runs (see `THREE_RUN_ARC.md`), runs 2 and
3 become a **scrap-farming opportunity as much as a threat**: more of the
building is charred, so more scrap is available — if you can survive it.

## Scrap is a COUNTER, not an inventory stack (mirrors the Wallet)

Scrap works like Bank Notes / the Wallet, **not** like a normal item:

- It is presented as an item concept in the UI at first, but once the player
  finds their **first scrap bag**, scrap becomes a **running total shown in the
  top-right of the screen, exactly like the cash counter** (same treatment as
  the Wallet balance — see `STORE_DESIGN.md`).
- A **scrap bag pickup does NOT go into inventory** (it never takes one of the
  5+1 slots). Instead, picking one up **adds a randomised amount of scrap to the
  total** and the bag is consumed.
- So finding scrap bags just grows the number; the player never has to manage
  scrap as an item, the way they never carry individual bank notes once the
  Wallet is unlocked.
- Implementation note (when built): this parallels `WorldState`'s wallet
  unlock + balance (cross-run/per-run split TBD) and a HUD counter next to the
  cash readout — reuse that pattern rather than inventing a new one.

- **Scrap is NOT dragged onto items.** Upgrading is not an inventory action at
  all — it happens at a physical **upgrade station** in a **maintenance room**
  (below). Scrap is purely the currency spent there.

## Gathering scrap

Rough priority (exact numbers TBD in balancing). Every source below adds to the
**scrap counter** (above) — none of them place an item in inventory:

1. **Charred / burned apartments — the primary faucet.** A CHARRED apartment
   (a burnt-out ruin — see the fire hazard) yields **scrap** instead of normal
   loot. Its scavenge anchors give scorched, non-functional debris that reads
   as scrap rather than usable items. This is *more* scrap than you'd find
   anywhere else, and it's the reward for letting fire take a room (or for
   braving a floor the fire already ruined).
   - Fits the existing charred rule: charred apartments already suppress normal
     loot (`room.gd`); this replaces "empty" with "scrap."
   - The one-time charred context line ("the fire gutted this place —
     everything's burned down to scrap and cinders") already primes this.
2. **Natural finds — a trickle.** Scrap can also be found in normal scavenging,
   but at a **lower rate** than a charred ruin — enough to make upgrades
   possible without fire, slow enough that fire is the tempting shortcut.
3. **Dismantling items — a level-5 perk.** With a specific perk/upgrade
   unlocked (a "tier-5" character/skill milestone), the player can **break down
   items they don't want into scrap** — turning surplus weapons/junk into
   upgrade fuel. Gated so it's a late reward, not a run-1 given.

## The maintenance room (where upgrades happen)

A new **maintenance room** — its own `.tscn` (a small room, not a full
apartment), placed **next to the elevator every 3 floors** (a "maintenance
door"). It serves two jobs:

1. **The upgrade work station.** Click the station → the player walks to it → a
   **UpgradeUI** opens (like the merchant/shop UI) listing what you can upgrade,
   the **scrap cost**, and any **item requirements** (which weapons of which
   level it consumes). Confirm → the upgrade applies to the selected weapon.
2. **The fuse box → elevator power.** The maintenance room is also where the
   **fuse boxes that power the elevators** are found. (Separate sub-system; see
   Open Questions — how elevator power gates traversal/the merchant is TBD.)

### Upgrade costs (crafting-combine + scrap)

Higher levels cost scrap **and consume lower-level copies of the same weapon**
(so a spare gun is upgrade material, not junk — and a reason to buy a second one
from the merchant). Worked example (gun):

| Step            | Cost                                      |
|-----------------|-------------------------------------------|
| Gun Lv1 → Lv2   | 50 scrap                                  |
| Gun Lv2 → Lv3   | a **Lv2 gun** + a **Lv1 gun** + 80 scrap  |
| Gun Lv3 → Lv4 (max) | a **Lv3 gun** + a **Lv2 gun** + 100 scrap |

### Static, player-CHOSEN upgrade trees

Levelling is not "part → variant" (e.g. silencer makes a silenced pistol).
Instead each weapon has **three static upgrade tiers** (basic → rare →
legendary), and at each level the player **picks 1 of 2** static upgrades — so
they shape the weapon deliberately. (Reuse the existing Hades-style **pick-1-of-2
UI** from the character upgrades — see `STORE_DESIGN.md` step 6.)

Worked example — **gun**:
- **Lv2 (rare) — pick one:**
  - *Aim Assist* — improved aim + higher headshot chance.
  - *Durable Hand Cannon* — doubles the weapon's durability.
- **Lv3 (legendary path) — pick one:**
  - *Silencer* — firing makes no noise (huge for the stealth system).
  - *Through-and-Through* — a shot can also hit an enemy behind the target.
- **Lv4 (max) — pick one:**
  - *Lucky Bullet* — a shot has a chance not to consume a bullet.
  - *Bigger Bang* — bullets are volatile: explosive AoE damage to nearby enemies.

Every weapon we support needs its own 3-tier × 2-choice tree. That's a lot of
content, but it's what lets a player build a **unique arsenal per run**, on top
of the every-5-floors **character** upgrades.

### Persistence / carry-over (DECIDED)

- Upgrades are **per-item-instance** (level + chosen upgrades ride the weapon,
  like durability/mag/broken state on `ItemInstance`), applied via the
  **modifier-fold** rule (base × ∏mult + Σadd, never direct writes) so they
  stack cleanly with the global upgrade system.
- **A weapon KEEPS all its upgrades as it levels.** Upgrades never disappear
  when you level up and choose a new perk. Example: buy a **Lv2 gun that already
  has *Aim Assist*** → upgrade it to Lv3 → it **still has Aim Assist** *and*
  gains the Lv3 pick. So merchant-bought pre-upgraded weapons are worth
  levelling further, and picks accumulate up the tiers.
- **Combine/consume:** the weapon you're upgrading is the **target** (it keeps
  its upgrades). The extra lower-level gun(s) in the cost are **feed material** —
  consumed, their state discarded. (Reading of the cost table: to reach Lv3 you
  have your target Lv2 gun + feed a spare Lv1 gun + 80 scrap; Lv4 = target Lv3 +
  feed a spare Lv2 + 100 scrap.)
- **Player-specific, like cash/wallet.** Scrap, scrap total, and upgraded
  weapons belong to the **current character**, not the arc. Only **character
  upgrades** (the every-5-floors perks) carry fully across all three runs — the
  game gets harder each run *and* the player gets stronger, whichever character
  they are.
- **Death → corpse recovery.** If a character dies, the next character can find
  the **previous character's corpse** and scavenge to recover their supplies
  (ties into `STORE_DESIGN.md` corpse recovery). **Scrap totals MERGE** on
  recovery — char 2 with a scrap total who loots char 1's corpse simply adds the
  two totals, never carries two separate "bags."
- Levels read clearly on the slot (a small **"Lv2/3/4" tag**, like the
  broken/damaged tags today) plus the chosen-upgrade icons.

### Discard memory (fair drops)

Because the player is meant to **collect spare weapons over time** to feed
upgrades (maintenance rooms are every 3 floors but you needn't upgrade at each),
dropping/keeping decisions matter — so an **accidental drop must be
recoverable**. A discarded item must persist in the world with a **held memory**
so the player can return and pick it back up (as other games do). *To verify /
ensure when we build:* the existing drag-to-world discard already creates a
persisted `world_drop` on the floor — confirm it survives leaving + re-entering,
and add it if any gap.

## Remaining TBD (small, balancing-level)

- **Scrap amounts.** Per charred apartment vs natural find; dismantle yield by
  rarity; whether the 50 / 80 / 100 curve and Lv1/Lv2 feed requirements feel
  right. (Tune in playtest.)
- **Hammer upgrade tree.** Gun tree is specced; owner will define hammer perks
  while we build the gun tree as the first test.
- **Dismantle perk.** Which tier-5 character perk grants "break item → scrap"
  and how much scrap it returns by rarity.

**Settled:** inventory pressure is intended (collect + decide, with discard
memory as the safety net); scrap is fire/scavenge-only, spent only at the
station (never traded with the merchant); build **gun + hammer first**.

> **The maintenance room + fuse box + elevator traversal it enables is a whole
> sub-system — see `MAINTENANCE_ELEVATOR.md`.**

## Why this is good for the game

- Makes **fire a decision, not just damage** — the first hazard that *rewards*
  as well as punishes (let a room burn → scrap).
- Gives **runs 2 and 3 a forward pull** (more charred floors = more scrap) so
  escalating danger has an escalating payoff.
- A **maintenance room every 3 floors** gives a physical upgrade ritual and a
  reason to explore off the apartment path, and folds in the elevator fuse-box.
- **Two progression axes at different cadences:** weapon upgrades every ~3 floors
  (scrap, at the station) and character upgrades every ~5 floors — plus a
  crafting-combine sink that makes duplicate/merchant weapons valuable.
- **Player-chosen static trees** = build variety and a unique per-run arsenal,
  without the frustration of random rolls.
