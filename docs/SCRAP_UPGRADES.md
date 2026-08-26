# DF30 — Scrap & Item Upgrades

> **Status: AGREED design direction, pre-implementation.** Owner-proposed
> during the fire-hazard work; this doc captures the idea so it survives across
> sessions. Nothing here is built yet — it is the spec to build against.
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

### Persistence / carry-over

- Upgrades are **per-item-instance** (level + chosen upgrades ride the weapon,
  like durability/mag/broken state on `ItemInstance`), applied via the
  **modifier-fold** rule (base × ∏mult + Σadd, never direct writes) so they
  stack cleanly with the global upgrade system.
- **Merchant weapons stay relevant.** Players can still buy rare/legendary
  weapons from the merchant for **cash**. If a purchased weapon already carries
  an upgrade and is then **consumed to level another weapon, its upgrades carry
  over** to the result. (Exact carry-over rule — which of the consumed weapon's
  picks transfer, and whether they can conflict with the target's picks — is an
  Open Question.)
- Levels read clearly on the slot (a small **"Lv2/3/4" tag**, like the
  broken/damaged tags today) plus the chosen-upgrade icons.

## Open questions (to decide before building)

- **Combine-cost inventory pressure.** Lv3/Lv4 consume *extra* weapons (a Lv2 +
  a Lv1 gun, etc.). With only 5+1 slots, where do the spares come from (merchant
  buys, finds?) and is juggling 2–3 guns to feed one upgrade the intended
  tension, or too fiddly? (Option: the station could accept weapons from a small
  "feed" list without them all being in hand at once.)
- **Carry-over semantics.** When a weapon with upgrades is consumed, do its
  chosen upgrades transfer to the result automatically, or does the player
  re-pick? What happens if the consumed weapon's pick conflicts with the
  target's (two Lv2 picks)? Recommend: the *target* keeps its own picks; a
  consumed **purchased** weapon can donate one pick if the target's slot at that
  tier is empty.
- **Which weapons first.** Gun tree is fully specced. Build **gun + one melee**
  (e.g. hammer) as the template, prove the flow, then expand to the rest.
- **Persistence across the 3-run arc.** Fresh character each run
  (`THREE_RUN_ARC.md`) implies upgrades reset per run (like inventory) and scrap
  is spent fresh each run — confirm that's intended vs. some carry-over.
- **Scrap amounts.** Per charred apartment vs natural find; dismantle yield by
  rarity; whether Lv1→Lv2's 50 and the later 80/100 are the right curve.
- **Fuse box / elevator power.** New sub-system bundled into the maintenance
  room: does the elevator not run until a fuse box is found? How does that gate
  the merchant (who lives in the elevator) and traversal? Needs its own mini-spec.
- **Scrap ≠ Bank Notes.** Scrap is fire/scavenge-only and spent only at the
  station — not bought/sold at the merchant (keeps the two economies distinct).
- **Dismantle perk.** Which tier-5 character perk grants "break item → scrap";
  scrap returned vs item value.

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
