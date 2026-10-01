# Overgrowth — the building changing (owner round 26)

> "in lower level rooms we want actual overgrown areas too. I want this to not just be monsters but the
> building changing" — and "shrubbery no… unless you can shrink them a bit and add them to some balconies".

The outbreak isn't the only thing loose in the building: left alone, it is being taken back. Damp, no
maintenance, no light. So growth follows **depth** (the lower floors are already green on the first
morning) and **time** (every run the same building reads greener) — the same two axes as everything else.

## How much — `scripts/overgrowth.gd`

`Overgrowth.level(floor, run)` is a pure function of `(master_seed, floor, run)`, 0..1. **Nothing grows above floor
12** (owner round 33 — "The overgrowth in the building should not set in till at least floor 12. We need the top to still
have an element of normalcy that changes and distorts and gets steadily worse/creepier/gooier/grosser as we descend";
`GROWTH_TOP_FLOOR`). From 12 down, `depth` = (13 − floor) / 12 and the level is `0.02 + 0.58·depth^1.2 + a per-floor
jitter`, plus a per-run step that itself grows with depth: floor 12 barely touched, floor 1 a jungle by night. Floor 30 and
the lobby grow nothing. A resident's houseplant and a balcony's potted plant are normal life, not overgrowth — they still
appear up top. **Fire wins**: a floor that is blazing / burnt out (`WorldState.fire_intensity`) → 0 (a LIGHT
fire holds it to 40%). `room_level(floor, apartment, run, fire_stage)` moves that per flat — a few are still
kept up (−0.22), a few choked (+0.22) — and a burnt flat grows nothing. Words: clear / creeping / overgrown /
choked (`Overgrowth.word`). Dev: F1 → **Overgrowth** cycles the real curve → 0 / 25 / 50 / 75 / 100 % on every
floor and flat (`WorldState.dev_overgrowth`, never saved).

## The sprites — `tools/art/growth.py` → `assets/growth/`

Native-scale pixel art, authored flat (the engine's lights do the shading): `hang_*` vines hanging from the
ceiling (single / pair / cluster / curtain / dry), `creeper_*` ivy climbing from the skirting, `tuft_*` grass +
weeds (some flowering), `flower_*` wildflower stalks, `fern_*`, `roots_*` (a cracked floor lifted by roots),
`moss_*`, `fungus_*` (brackets and toadstools), `pot_*` houseplants (fern / flowers / tall / dead) and
`shrub_*` — **shrubs are NOT used in corridors or flats** (owner); only `shrub_small_*` is, on balconies.
`growth.json` records each sprite's kind / pin / size; `docs/art_reference/growth.png` is the contact sheet.

## Corridors — `scripts/corridor_growth.gd`

Like the horror decals: `SLOTS` candidates per floor in one fixed order (seeded from master_seed + floor,
never the run), each with a rising threshold; the floor shows the prefix its level reaches, so **what grew in
run 1 is still there in run 2, with more added**. Small things (weeds, moss) come first; ivy, vines, ferns,
roots and fungus as it gets worse. It grows in **patches** (4 centres per floor, half at the stairwell ends —
the draughts) that spread as the threshold rises — overgrown *areas*, not confetti. Never over a sign, a lamp,
the exit sign or a door's face (ivy may frame a door); ferns / flowers stand at a door's edge but not its
middle. Laid over the decals, under the doors and every actor; also on the pan backdrop.
`tools/growth_report.tscn` prints the curve per floor and run.

## Flats — `scripts/room_growth.gd` + `tools/art/growth_map.py`

Room art is one baked picture, so a live sprite laid over it would sit in front of furniture it should be
behind. `pixlib.finish_module` therefore records, per module variant, three **skylines** over its 320 columns
(`assets/rooms/growth_meta.json`, measured against the bare wall + floor and against the run-2/3 furniture
looks): clear rows above the floor, up the wall, down from the ceiling. Ivy and vines only go over bare wall;
a plant standing on the floor only needs its footing clear (the floor line is in front of furniture against the
back wall). Same candidate/threshold scheme per module (seeded per flat + slot). No growth in breached flats or
flats holding one of the dead (their story is the point), the fixed tutorial flats, or a burnt flat; none in the
outer 14 columns (the perspective walls cover them) nor, on a balcony slot, over its doors. **Houseplants**:
independent of the wild growth, more likely in a kept-up flat and high in the building; a plant dies lower down
and later in the day (a dead pot beside a jungle is the story).

## Balconies

`room_growth.balcony_plan`: four slots (a small shrub or a pot either side of the doorway, a vine from the lintel,
one trailing over the rail), each shown if its seeded threshold is under `0.22 + 0.78·level` — so up top some
balconies are bare and some planted, and low down by night nearly all are green. Sways ×1.6 (open air). Drawn
after the module's Balcony node so it's over the balcony art.

## Motion

Everything that moves uses `scripts/sway.gd`: whole-texel steps (pixel art stays crisp), pinned at the foot
(standing) or the TOP (hanging vines, with a `lag` so a wave travels down them), wind rising through the day.

## Not built yet

Growth **in the stairwells**; **in-run growth** (a vine that visibly lengthens over minutes); growth that
**reacts** (fire spreads faster through dry overgrowth — the fuel model could read `Overgrowth`; a shove /
gunshot shaking the vines); light-loving vs shade plants (glowing fungus at night on the darkest floors);
the journal / a character's line noticing it ("something's growing in here"); loot under growth.

## Open — depth BIOMES (owner round 33, not built)
The owner's direction: "different visual biomes that will also have visually distinct enemies around those levels" — the top
keeps its normalcy and the building gets "worse / creepier / gooier / grosser" going down. The floor-12 growth line is the first
piece. A proposal to steer (nothing built): **30-21 the Hotel** (normal life, damage + blood only), **20-13 the Rot** (damp, mould,
peeling, the first goo in the corners; an enemy variant to match), **12-6 the Green** (this overgrowth), **5-1 the Nest** (growth
turning to flesh / goo; its own enemy variant). The corridor sections (hotel 21-29 / residential 11-20 / institutional 1-10) and the
per-band enemy tables (`*_CHANCE` LOW/MID/HIGH) are the hooks.
