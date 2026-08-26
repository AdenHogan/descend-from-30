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

## Gathering scrap

Rough priority (exact numbers TBD in balancing):

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

## Spending scrap — item upgrades

**Drag scrap onto an item to upgrade it** (mirrors the existing drag-to-load
bullets-onto-gun interaction — see the inventory drag/drop system). A threshold
of scrap (working figure: **100 scrap → one level**) converts the item to its
next level.

Examples (illustrative — per-item effects TBD):
- **Gun → level 2:** better **accuracy** and **damage**.
- **Hammer → level 2:** **double durability**.
- Other melee: more damage / more durability / faster swing, per weapon.

Design intent:
- Upgrades are **per-item and persistent** on that item instance (they ride the
  item, like durability/mag state on `ItemInstance`).
- Levels should read clearly (a small "Lv2" tag on the slot, like the
  broken/damaged tags already do).
- Follow the **modifier-fold** rule from `STORE_DESIGN.md` (base × ∏mult + Σadd,
  never direct stat writes) so an upgraded item stacks cleanly with the global
  upgrade system.

## Open questions (to decide before building)

- **Scrap cost curve:** flat 100/level, or rising (100 → 250 → …)? How many
  levels per item (2? 3?).
- **Per-item-type upgrade tables:** what each weapon/tool class gains per level
  (damage / durability / accuracy / speed / capacity).
- **Amounts per source:** scrap per charred apartment vs per natural find;
  scrap yield from dismantling by item rarity.
- **Persistence scope:** does an upgraded item survive across the 3-run arc, or
  reset with fresh-character state? (Probably per-run like inventory, but worth
  confirming against `THREE_RUN_ARC.md`.)
- **UI:** a scrap counter on the HUD (near the wallet), the drag-to-upgrade
  affordance, and the level tag on the slot.
- **Dismantle perk:** which tier-5 perk grants it; scrap returned vs item value.
- **Interaction with the merchant:** can scrap be bought/sold, or is it strictly
  a scavenge/fire resource? (Leaning: fire/scavenge only — keeps it distinct
  from Bank Notes.)

## Why this is good for the game

- Makes **fire a decision, not just damage** — the first hazard that *rewards*
  as well as punishes.
- Gives **runs 2 and 3 a forward pull** (more charred floors = more scrap) so
  the escalating danger has an escalating payoff.
- Adds a **second progression axis** (upgrade what you carry) alongside the
  merchant/Bank-Notes economy, without competing with it.
