# DF30 — Merchant, Currency & Upgrades Overview

> Converted from `DF30__STORE_DESIGN.docx`.
> **Status: FINAL design (v3), pre-implementation.** Covers: bank notes,
> wallet, merchant, shop rotation, upgrades, drawbacks, corpse recovery.

## Currency — Bank Notes

**Fiction:** Outbreak is contained to the building. The outside world still
runs on cash, and so does the merchant. Other trapped residents are his
customers, resulting in an ever-changing storefront selection.

**Item:**
- New item: Bank Notes (id in 03x range, near Wallet/031)
- Stackable, small bills sprite

**Acquisition:**
- Scavenge anchors: weighted into all loot tiers
  - Common bundles: 5–15 notes
  - High-density (dangerous) apartments: 15–40 notes
- Zombie drops (added to existing 18% drop table):
  - Standard zombie: 5–10 notes
  - Big Zombie: always drops 30–60 notes
- No respawning sources. Finite cash per run seed.

**Inventory behaviour (pre-Wallet):**
- All notes stack in ONE inventory slot ("Bank Notes ×N")
- Stack still costs a slot. Carrying money means carrying less gear
  (deliberate).

**The Wallet (was junk item id 031, becomes functional):**
- On pickup/first use, money leaves the item grid permanently
- HUD gains wallet icon + running total near the slot bar
- Existing Bank Notes slot converts to wallet balance; future pickups go
  straight in
- Wallet consumed on use, becomes a HUD feature, not an item
- Freed slot is the reward

## The Merchant

**Character:**
- Same man every visit, squatting in the jammed-open elevator
- RE4-merchant energy: cheeky, familiar, faintly unsettling
- Never explains how the elevator moves between floors when it plainly
  doesn't work
- Implies other residents shop with him ("The lady on 22 cleaned me out of
  bandages, heh") — lore hook for stock rotation

**Location & cadence:**
- Every 5 floors: **25, 20, 15, 10, 5** (floor 30 is the start; first visit
  at 25 teaches the system early)
- Interaction: walk to elevator, press E

**Visit flow (decided):**
- First interaction each visit: merchant leads with the UPGRADE OFFER
  (choose one of two) BEFORE shop wares
- The boon is the event; shopping is the errand
- Player may refuse the pair — one "You sure, friend?" confirm (agency must
  be deliberate, never a misclick)
- After the upgrade beat resolves (pick or confirmed refusal), shop opens
- Re-interacting same visit goes straight to shop; the pair does not return

**UI:**
- One screen, two tabs: SHOP and UPGRADES
- Upgrades tab shows current pair, or owned list once resolved
- Buy with confirm
- Selling player items to merchant: OUT of scope v1

## Shop Stock

**Slots:** max 6 items per visit

**Rarity bands:**
- **Common (3–4 slots):** bandages, snacks, basic tools, small ammo later —
  cheap, affordable most visits
- **Quality (1–2 slots):** first aid kit, good melee (bat/hammer tier),
  stamina items — one ≈ a full visit's scavenged notes
- **Legendary (0–1 slots):** high-durability sword, unique tools, later
  gun/ammo cache — 2.5–4 visits of diligent saving

**Rotation rules:**
- Stock seeded per **(master_seed, visit floor, current_run)** —
  deterministic per run, different between runs
- Common/Quality reroll every visit (chance repeats are fine)
- **LEGENDARY HOLD RULE:** an unpurchased Legendary stays in stock for at
  least the next 3 shop visits (15 floors). Lore: "Been saving this one for
  you." Guarantees a savings goal is reachable
- After the hold window it may rotate out
- If purchased: ~25% chance next visit rolls a new Legendary

**Economy target:**
- Thorough scavenger affords per visit: all-common shopping OR one Quality
  item OR progress toward one Legendary
- Never everything — decision-making is the point
- Building-clearing for infinite cash is naturally capped by weapon
  durability; no additional cap v1

**Tuning constants (starting values, expect iteration):**
- Anchor bundles: common 5–15, dense-tier 15–40
- Zombie drops: standard 5–10, big 30–60
- Prices: common 15–40 · quality 80–150 · legendary 300–500

## Upgrades

**Acquisition model (decided, supersedes earlier priced model):**
- **FREE: choose one of two, once per merchant visit** (Hades-boon style)
- Money buys items only
- Choosing is optional — an unpicked pair does NOT bank; skip it and it's
  gone until next visit's fresh pair
- Offered BEFORE shop wares (see Visit flow)

**Why free instead of priced:**
- Upgrades persist across all three runs and counterweight run 2/3 difficulty
  scaling — only balances if acquisition is predictable (exactly 5/run,
  15/arc)
- Priced upgrades make the rate luck/frugality dependent — unlucky player
  hits hardest content underpowered ("punish fairly" violation)
- Anti-meta protection comes from the pool itself: 50+ weighted upgrades =
  low odds of being offered any specific "meta" pick
- Per-visit money tension survives fully inside the shop tab

**Numbers:**
- 5 visits/run × 1 pick from 2 = 5 upgrades/run, **15 across the
  three-character arc**
- Pool target: 50+ upgrades (possibly 100 long-term)
- Weights are a later design pass (e.g. inventory slot weighted more common)

**Persistence (DECIDED):**
- Upgrades persist across ALL THREE character runs
- Buying on character 1 = investment in the whole descent; death never voids
  picks (anti-frustration)
- Difficulty scales per run to compensate (see room.gd note re: zombie→boss
  evolution for run 2/3)
- **NO DUPLICATE OFFERS:** pairs draw only from UNOWNED upgrades. <2 unowned
  = offer one; none = tab empty (merchant: "nothing left to teach you")
- Pool size is the tuning lever for how long the upgrade economy lasts
  across the arc

**Drawback upgrades (category built now, content later):**
- Trade-off upgrades: benefit paired with a cost
  - e.g. "half max stamina, +2 inventory slots"
  - e.g. "improved hearing, reduced visibility" (NOTE: gated on systems that
    don't exist yet — wishlist, not v1 content)
- **LEGIBILITY IS ABSOLUTE:** both halves fully stated before picking.
  Players gamble on build synergy, never hidden information. (A future
  flagged "cursed/mystery" category may break this deliberately; the default
  never does)
- Drawbacks make REFUSAL a live decision — with pure boons only, refusing is
  always wrong and the confirm prompt is dead weight. The two features
  justify each other
- Weight trade-offs rarer than pure boons initially; the boon:trade-off
  ratio becomes a per-run difficulty lever (run 2/3 merchant offers nastier
  bargains)
- Owned drawback upgrades never reappear, same as boons. No removal/respec v1

## Money & Death — Corpse Recovery

- Bank Notes do NOT persist directly — money dies with the character,
  literally: it's on the corpse
- **CORPSE RECOVERY:** next character can reach the previous character's
  death location and loot the body — recovering its notes AND inventory items
- World already persists across the three runs; corpse is a placed
  interactable at the recorded death position
- Makes the dying-state window (currently 8s) strategically vital:
  - Dying somewhere reachable = a gift to your next character
  - Dying deep in a swarm = your cash is guarded by whatever killed you
- Hoarding still punished (recovery is a risk, not a refund), but death is
  never a total economic wipe
- The Wallet UNLOCK persists like an upgrade (HUD element + freed slot);
  balance resets to 0 per run. Refinding it each run would be tedium, not
  tension

## Implementation Order (each step testable alone)

1. ✅ Bank Notes item in Items.json + loot pool weights + zombie drop table;
   stacking display in existing slot UI (only inventory-system change)
2. ✅ Wallet conversion + HUD wallet counter
3. Merchant scene in elevator on floors %5==0 (excluding 30): sprite,
   E-interact, placeholder dialogue
4. Shop data: seeded stock generation with rarity bands + Legendary hold
   state in WorldState (persisted: merchant_stock, legendary_hold)
5. Shop UI tab; buy flow debiting wallet/stack
6. Upgrades tab: offer-before-shop flow (pair gates shop on first
   interaction; refusal = one confirm; resolved pair never returns that
   visit), pair generation from unowned weighted pool, effect application
   - **ARCHITECTURE REQUIREMENT — STAT MODIFIERS, NOT DIRECT WRITES:**
     upgrades apply as modifier-list entries over base stats; derived values
     computed (e.g. `get_max_stamina()` folds base × multiplicative mods +
     additive mods, fixed documented order: multiplicative first, then
     additive, clamp ≥1 bar). Never write directly into `max_stamina` etc. —
     drawbacks modify both directions and stack with boons; retrofitting
     modifier math onto direct-write upgrades is misery.
     `WorldState.upgrades` stores owned ids; single upgrade-effects module
     maps id → modifiers
7. Player-corpse system: on death, record position/floor/scene + wallet
   balance + inventory into cross-run state; spawn interactable corpse for
   later characters; loot transfers and clears the record
8. Save/load for all of the above (**string keys only** — see int-key JSON
   lesson). Upgrades + wallet-unlock live in cross-run persistence block
   (survives death/new-run reset); Bank Notes balance is per-run state

Out of scope v1: selling to merchant, merchant dialogue trees, upgrade
respec, money caps.

## Game Design Doc Conflicts to Reconcile (older GDD text this supersedes)

- GDD says upgrades "do not carry over" between characters → SUPERSEDED:
  they persist (decided)
- GDD says choice of THREE upgrades → SUPERSEDED: choice of TWO, from
  merchant
- GDD says upgrades awarded automatically per 5 floors descended →
  SUPERSEDED: offered by merchant at floors 25/20/15/10/5
- GDD says 4 inventory slots → current build is 5 + locked 6th; update GDD
