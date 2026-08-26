# DF30 — Maintenance Room, Fuses & Elevator Traversal

> **Status: AGREED design, pre-implementation.** Owner-specified alongside the
> Scrap system. The maintenance room hosts the weapon **upgrade station** (see
> `SCRAP_UPGRADES.md`) AND the **fuse box** that powers the **elevator**, a new
> traversal mode. Build this sub-system first (it's the foundation for scrap
> upgrades and a new way to move through the building).
>
> Ties into: `SCRAP_UPGRADES.md` (upgrade station), the merchant
> (`STORE_DESIGN.md` — lives in the elevator), and the stairwell/balcony
> traversal + persistence patterns (`CLAUDE.md`).

## The maintenance room (`maintenance.tscn`)

A new scene — a **much smaller version of the current apartment rooms**. One is
placed **next to the elevator every 3 floors** (a "maintenance door"). It is:

- A **safe room — NO enemies, ever.** A breather.
- A place with an **increased chance of toolboxes** (repairs), and **two
  scavenge nodes** (its only loot anchors — small, but reliable).
- A natural spot for the player to **commit to a rest cycle** (rest is safe here).
- Home to **the upgrade work station** (weapon upgrades — `SCRAP_UPGRADES.md`)
  and **the fuse box** (elevator power, below).

## Fuses → powering the elevator

**Narrative:** the merchant has taken over the elevator, but that doesn't stop
the player from fitting fuses to run it themselves.

- **Fuse** = a new item that **stacks in inventory to a max of 3**.
- The elevator needs **3 fuses** to run.
- At the fuse box in the maintenance room, the player loads their fuses. When the
  box has 3: an **elevator "ding"** plays in the room + a **rising electrical
  whirr** (power coming on).
- On **leaving the maintenance room**, the elevator doors **ding and open** —
  the player can step in.
- **Single use:** once the player rides it and leaves, the elevator **stops
  working again** — they must collect **3 more fuses** for the next ride. (So the
  elevator is a rationed shortcut, not free fast-travel.)

## Riding the elevator

- Inside, the player presses **up** or **down**; the elevator travels **5 floors**
  in that direction and lets them out.
- **Merchant floors:** if the player rides to (or is on) a traditional merchant
  floor, then walks away and back, the elevator **dings, the merchant appears**,
  gives a quick **dialogue bubble complaining about the player stealing their
  elevator**, then trades as normal. (So the merchant reclaims their elevator the
  moment the player stops using it.)

### Traversal approach — RECOMMENDED: `elevator_interior.tscn`

Two ways to realise the 5-floor trip:

- **(A) Pan the building 5 floors** (like the stair pan) — show the floors and
  their enemies scroll past.
- **(B) `elevator_interior.tscn`** — the doors shut, we cut to the **inside of
  the elevator** (player alone, or with an NPC for a quick narrative beat), a
  **quick unseen load** happens, then the player steps out 5 floors up/down into
  a ready-loaded `building_floors`.

**Recommendation: (B), the interior scene.** Reasons:

- **Cheaper & simpler.** The stair pan builds *two contiguous* floors as passive
  backdrops and is already the fiddliest thing in the codebase (go_live, hazard
  re-spawn, pop-in). Panning **five** floors — each with enemies, fire,
  barricades, hordes and their persistence — multiplies that cost and risk. The
  interior scene needs **only the destination floor** loaded (which already has
  full persistence), during a black/interior beat the player can't see through.
- **Narratively truthful.** A real elevator is a closed box — you don't watch the
  floors scroll by. The interior sells the ride better than a pan would.
- **Enables story beats.** The closed car is a free place for a one-off NPC
  encounter or line, with zero extra streaming complexity.
- **Persistence stays simple.** No need to hold 5 floors of live memory mid-trip;
  the destination floor uses the same saved state everything else does.

The pan approach's only edge is spectacle (seeing the building), and for an
enclosed elevator that spectacle is arguably wrong anyway. Go interior.

> If we ever *do* want to show movement, a middle option is a brief interior with
> a tiny "floor counter" ticking 5 numbers — the feel of travel without streaming
> five real floors. Not needed for v1.

## Build order (this sub-system)

1. **`maintenance.tscn`** — the room itself: small layout, safe (no enemies), 2
   scavenge nodes, higher toolbox chance, rest-friendly. Placed next to the
   elevator every 3 floors. (Self-contained; doesn't touch fire/horde.)
2. **Fuse item** (stack max 3) + **fuse box** interaction (load 3 → ding + whirr
   → doors open on exit). Elevator becomes rideable, single-use.
3. **`elevator_interior.tscn`** + the ride (press up/down → 5-floor jump → exit
   into the destination floor). Merchant "you stole my elevator" beat on
   merchant floors.
4. Later: the **upgrade station** UI in the room (that's the Scrap system —
   `SCRAP_UPGRADES.md`).

## Open questions

- **Which floors get a maintenance room** — literally every 3rd (3, 6, 9, …)?
  And how does that interact with the merchant floors (25/20/15/10/5) and the
  30-floor descent?
- **Fuse sources** — where do fuses spawn (scavenge weight, charred rooms,
  zombies)? Rarity tuned so a ride every ~5 floors is achievable but not free.
- **Elevator ride bounds** — what happens near the top/bottom (floor 30 / lobby)
  if a 5-floor jump would overshoot? Clamp to the end, or disallow.
- **The interior NPC beat** — optional flavour now, or a hook for a future NPC
  system? (Keep it a simple optional line for v1.)
