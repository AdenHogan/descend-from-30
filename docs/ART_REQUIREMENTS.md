# Descend From 30 - Art Requirements (v1)

A brief for contracting artists. Share this plus a few in-game screenshots. If anything
here is unclear, ask before starting a full set; a quick test frame saves re-work.

## The game in one paragraph

A 2D **side-scrolling** roguelike (Godot 4.6). You play survivors **descending a 30-floor
apartment building** during a zombie outbreak, scavenging apartments and fighting through
corridors, floor by floor, down to the lobby. One playthrough is **three characters** (a
morning, an afternoon and a night run) through the *same* building as it decays. Everything
plays on a **single flat walking plane** (the camera scrolls left and right; there is no
jumping or verticality in normal play).

## Tone: "cozy horror"

Warm, lived-in apartments turned dangerous. The dread comes mostly from **atmosphere, light
and decay**, but **blood and gore are welcome** as an element where a scene earns it (a
mauled corpse, a blood-slick floor, a spatter up a wall). Think: an ordinary building you
know, wrong. Grounded, slightly muted palette; strong, readable silhouettes.

## Art style: open

**Pixel art is one good fit but not the only one.** A painterly / cartoon full-art style
would suit this vibe just as well, for example *Valiant Hearts: The Great War*. Pitch
whichever style you are strongest in; what matters is the tone and readability set out here,
not the medium. (The current placeholders happen to be pixel art.) If you work in pixel art,
keep it pixel-perfect; if in full-art, deliver clean high-resolution art with transparent
backgrounds and we scale to fit.

---

## CRITICAL technical rules (read first, these prevent re-work)

1. **One feet baseline.** Every character and enemy stands on the **same floor line**.
   Author each sheet so the character's **feet sit at a fixed row within the frame**,
   identical across every frame and every character, and tell us that feet offset (or
   keep it at the very bottom of a tightly-cropped frame). Our current placeholder rigs
   were authored at different scales/paddings, so their drawn feet don't line up, the
   #1 thing to get right.

2. **Author art FLAT / neutrally lit, the engine does the lighting.** The game applies
   **real dynamic 2D lighting** on top of the art: warm ceiling-lamp pools, fire glow,
   cool moonlight, and darkness. So deliver art that is **evenly lit, near shadeless**,
   **no baked-in hard highlights or cast shadows** on characters/props. (A soft
   contact-shadow oval under the feet is fine and welcome.) Form-shading with gentle
   ambient volume is OK; directional "sun from top-left" baking is not, it fights the
   engine light. Every asset must still read when the only light on it is a **single
   warm pool in a near-black room** (our night runs).

3. **Author facing RIGHT.** The engine mirrors horizontally for left-facing. Avoid
   asymmetric details (text, single-shoulder bags) that look wrong flipped.

4. **Transparent background, no baked scenery.** Characters/props on their own
   transparent layer; never paint the corridor into a character sheet.

5. **Match the medium's discipline.** For **pixel art**: pixel-perfect, nearest-neighbour,
   integer frame sizes, crisp edges (no soft anti-aliased halos unless a glow is intended).
   For **full-art**: clean high-resolution art, transparent backgrounds, and we scale to fit.

---

## Canvas, scale & density

- The game renders **1152 × 648** (nearest-filter for pixel art).
- **Match the existing density.** Standard humanoids (player, zombies, NPCs) should read
  **~90-110 px tall on screen** standing. Author at a **tight native frame** (≈ 64 × 64
  for a normal human, larger for the Big Zombie/boss) and we scale in-engine, deliver
  native pixels + the intended scale factor.
  - The current player rig is 48², the zombie rigs 128² (mostly empty padding), please
    **don't** copy the padded 128² approach; use a tight crop with feet on the baseline.
- **Bigger creatures are taller, not lower**, the Big Zombie reads larger but its
  **feet still sit on the same floor line**.
- **Consistent character height (a live gameplay issue).** The current PLACEHOLDER player
  reads only ~56 px tall while the zombies are ~84-99 px, so the player is the odd one out,
  tall enemies (Long Arm, Spitter) tower and their attacks read as going over the player's
  head. New art must fix this: the **player and a standard zombie stand at roughly the same
  height**, with attack reach at a matching level; the Big is taller but proportioned so its
  hits still land. (Engine-side, the spit projectile and melee already connect regardless of
  the current mismatch; this is about how it *reads*.)

---

## Asset list (by priority)

### Tier 1: core actors (replace placeholders)
- **Player character** (full set). Animations: idle, walk, run, crouch-idle, crouch-walk,
  scavenge (searching a cupboard), **melee attack** (swing), **gun**: idle / walk / run /
  shoot, hurt/stagger, death, door-approach + knock (a step-up toward a door), balcony
  rope-lash + climb-down. Author neutral clothing (a scavenger/survivor). NOTE: the
  placeholder rig **already includes attack animation sheets** (melee swing + gun shoot) and
  the full walk/run/crouch/hurt/death cycles, use them as reference for timing/frame counts.
- **Multiple playable characters (future):** the health portraits + body shown are ONE
  character. We plan up to **~8 survivors, male and female body types**, each needing its
  own full body sprite set AND its own six health-state portraits.
- **Standard Zombie**, idle, walk, attack (lunge/grab), hit/stagger, death.
- **Big Zombie**, a **larger, heavier zombie with a heavy attack** (bulkier silhouette).
  (There is no separate "boss" asset, a corridor boss is just this Big rig, so it is NOT a
  distinct art item.)

### Tier 2: enemy variety (need DISTINCT silhouettes; today all five share one rig)
- **Crawler**, low to the ground, dragging itself (reads as *low* even in shadow).
- **Long-Arm**, elongated reaching arms (the long-reach threat).
- **Spitter**, ranged; also a small **spit projectile** sprite/anim.
- Each: idle, walk/move, attack, hit, death.

### Tier 3: NPCs
- **Merchant**, a shopkeeper who trades from inside the elevator car; **already in-game**
  (reuses the player sheet as a placeholder). Idle + a talk/gesture beat.
- **More NPCs (future):** a barricade-keeper survivor and further story NPCs will need
  designing as the game grows, flag capacity for an expanding cast.

### Environment
- **Corridor / hallway set**, wall, baseboard/trim, ceiling, floor, **with VARIETY**. The
  player descends 30 floors; it must not feel like the same background 30 times. Need several
  **corridor variants** (layout / decor / wear) plus day-state & immersion differences so each
  stretch feels distinct (this is *separate* from the top-to-bottom decay bands below).
- **Apartment doors, by state**, closed, open, **locked**, **weak/damaged**,
  **barricaded**, **breached** (busted open). Same door, readable state changes.
- **Stairwells**, an *up* flight (visible steps) and a *down* shaft (dark opening).
- **Windows**, a stairwell window and an apartment **balcony** window/door (daylight
  comes through these; keep the glass able to read as lit).
- **Elevator**, corridor doors (closed/open) + the **interior car** (a small room the
  player rides in, roomy enough for the merchant).
- **Maintenance room**, small utility room: workbench, fuse box.
- **Lobby** (ground floor) and the **floor-30 hallway** (tutorial floor).
- **Apartment room modules**, bedroom, kitchen, bathroom, study, living room, dining
  room. Each a self-contained ~**320 px-wide** module (three sit side by side per
  apartment); furnish for scavenging. **Same anti-repetition rule as corridors:** a **few
  variations per room type** (not the same bathroom every time).

### Props
- Crate-stack **barricade** (blocks a stairwell), scavenge-anchor highlight, corpse,
  world-drop pickups, keys, wall-mounted fire extinguisher canister.

### UI / icons
- **36 inventory item icons** (small, readable at ~32-48 px in a HUD slot). List below.
- HUD frame / slot art, a pixel display font is already in use (match its feel).

### FX
- Fire & smoke are currently **licensed sprite packs** (craftpix/Kenney), no bespoke
  fire needed yet, but a matching **impact/blood-hit** puff and a **muzzle flash** would
  help.

---

## Sectional identity: the descent DECAYS (a key pillar)

The infection is **worst at the bottom**, so the building should visibly rot the lower
you go. Please deliver corridor + door (and ideally room-dressing) variants across
**three bands**:

- **Floors 30-21 (top):** clean, intact, lived-in, an ordinary nice building.
- **Floors 20-11 (mid):** disturbed, damage, blood, disorder, things breaking down.
- **Floors 10-1 + lobby (bottom):** **grotesque**, heavy infection growth, biological
  corruption, ruin.

Descending should *feel* like sinking into something sick. Enemies can also pick up
per-band grime if budget allows.

## Time of day: the ENGINE handles it, not the art

Each run is Morning / Afternoon / Night. **We light and tint that dynamically** (morning
bright daylight; afternoon a cool dusk with warm interior pools; night near-black lit
only by lamps/fire). **Author each asset once, neutrally lit**, do **not** deliver
separate day/night versions unless we ask.

---

## Deliverables & naming

- **PNG**, transparent, nearest-filter-safe.
- Sprite sheets as **horizontal strips, one animation per row** (or per-file frames),
  either is fine, just be consistent and tell us the layout.
- For each animation give: **name, frame count, frame size, suggested fps, loop or
  one-shot**, and the **feet/pivot offset**.
- Naming: `subject_anim.png`, e.g. `player_walk.png`, `zombie_standard_attack.png`,
  `door_barricaded.png`, `corridor_wall_low.png`.
- First, a **palette swatch** + one **"hero" mock** of a lit corridor with a character
  in it, so we can lock the look before you produce full sets.

## Inventory items (36, for icons)

001 Knife · 002 Hammer · 003 Sword · 004 Gun · 005 Canned Food · 006 Bandages ·
007 First Aid Kit · 008 Clothes · 009 Torn Clothes · 010 Painkillers · 011 Ice Pack ·
012 Golf Club · 013 Cricket Bat · 014 Baseball Bat · 015 Flashlight · 016 Bullets ·
017 Aluminium Baseball Bat · 018 Rope · 019 Toolbox · 020 Fuse · 021 Battery ·
022 Apartment Key · 023 Broken Glass · 024 Empty Bottle · 025 Old Magazine ·
026 Takeaway Boxes · 027 Dead Plant · 028 Broken Remote · 029 Pile of Paperwork ·
030 Old Shoes · 031 Empty Wallet · 032 Broken Umbrella · 033 Bank Notes ·
034 Screwdriver · 035 Crowbar · 036 Fire Extinguisher
