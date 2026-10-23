# The logo — "Descend From 30"

Made in-house (owner round 48) by `python3 tools/art/logo.py`: the print is drawn by `tools/art/logo_print.py` (on the hand shape of
`tools/art/logo_hand.py`), the lettering is Barlow Condensed Bold (SIL OFL, `assets/fonts/logo/` with its licence). The files below are
GENERATED — change the tools, never the files; `tools/art/logo.py --check` (in `tools/run_all_tests.sh`) fails on a stale or missing one.
**It is wired into the TITLE SCREEN** (round 48e / 48g, `scenes/title_screen.tscn`); the opening's own title (`scripts/opening_exterior.gd`), the run-1 title
card and `project.godot`'s `icon` still use the placeholders — see "Using it in the game" below.

![contact sheet](logo_sheet.png)

## What it is

**The bloodied handprint is the logo** (the owner: "if that doesn't work then the logo doesn't work"), and it sits **directly behind the 30** (round 48d):
the hand's own middle (its centre of mass, the palm) is on the middle of the numerals (`logo.py --check` holds it within a tenth of the 30's size), the
fingers rise above the numerals, the heel and a few drips hang below them. It is a **right hand with the thumb on the LEFT** (owner round 48e: "I prefer the hand to be the other
way around with the thumb side on the left" — round 48d had mirrored it to a left hand), so the thumb reaches toward DESCEND / FROM, and **the thumb tucks in UNDER DESCEND** (owner round 48h: "the descend from is just a little too far away from the 30 and handprint… I am completely
okay with some of the handprint being behind descend a little"): the 30 and its print are slid left together until the print's real, wobbly ink (not the clean outline) reaches `TIP_REACH` (0.15 of the 30's
height) in under DESCEND. The words are drawn OVER the print; in the light version the print is knocked out in a thin halo round the letters so ink letters never vanish into dark blood
(`logo.py --check` holds the reach to 0.02 .. 0.30 and DESCEND >= 0.12 of the 30's height clear of the numerals). The words stand on the left in plain capitals, set close (`TRACK_TEXT` 14). Landscape.

**The print is a print, not a silhouette.** A flat red shape read as a cold-war poster (the owner: "some ww2 / cold war spy thriller"), and a first textured
print read as foam / plastic wrap (mottled cloud noise, blobs of "shine", a flat bucket-shaped bottom). `logo_print.py` now draws how blood *transfers*:

- **Pressure decides where it touched.** The pads of the fingers and the heel press hardest; the print BREAKS across the finger joints and the heart / life
  lines of the palm as narrow, wandering creases that dissolve into streaks (never a ruled band); the arch of the palm barely touches.
- **The heel does not end, it lets go.** The wrist and the bottom of the palm fade out into long ragged streaks (a round heel, never a flat cut), and the
  drips run out of that torn edge. The drips are drawn UNDER the print so they flow from its pooled rim, never as separate pipes.
- **The edge is wet:** rounded and a little uneven (a low wobble, softened and re-thresholded), and every edge - the outline and the edge of any gap -
  pools darker where the blood was squeezed out. A thin glint runs along the rim that faces the light, only where the blood is thick.
- **Dry-brush streaks** all one way (the hand slid a hair) - a few long thin lines in patches that lighten the film; no fine grain (that read as woven cloth).
- **Skin:** loops of ridges round every fingertip pad, visible where the film is thin - the tell that this is a real hand.
- **A wall makes it run:** four or five irregular drips (wide where they leave the print, a neck, a swelling, a tall teardrop foot), and spatter - round
  drops, some thrown off in a streak with a tail pointing back to the hand; none lands on the print or to its left.
- It stays **dark blood, never a bright red** (`THIN` 180/38/34 to `THICK` 92/10/16, a pooled rim 50/5/10), and restrained: no gore.

The hand under it (`logo_hand.py`) is anatomically measured (palm 0.9 wide, middle finger 0.95, four fingers in a natural fan, a curved thumb, a wrist
only ~0.5 wide; `MIRROR = False` draws the right hand as written, `True` mirrors it to a left hand): `--check` keeps the wrist under 70 % of the palm and the hand 0.55-0.78 as wide as tall.

**The type** is the owner's pick ("clean and mature"): Barlow Condensed Bold capitals, vector, no bevel / outline / shadow / distress, tracked close (the
owner: "the text is spaced rather far apart"). The print does the roughness; the lettering stays quiet. (Rejected on the way: pixel art with a dithered
print and a brick-tower 30 - "AI crap"; the print beside the words - "incorrect"; the flat print - "spy thriller"; gritty brush-lettering - the owner prefers
the clean type; a first textured print up and to the right of the 30 - "should be directly behind the number"; the foam-textured second print - "still very
far from good".)

## Variants and files (`assets/logo/`, all on transparent backgrounds)

| file | what | for |
|---|---|---|
| `logo_full_dark.png` (2400 px wide) / `_600.png` | the print behind the 30, warm-white letters | dark backgrounds — the title screen, a store banner |
| `logo_full_light.png` / `_600.png` | the same with ink letters; the 30 stays warm white inside an ink keyline so it reads over the blood *and* over the paper | light backgrounds — press kit, documents |
| `logo_wordmark_dark|light` (`.svg` pure vector, `.png` 1600 px, `_600.png`) | DESCEND / FROM and the 30 in flat blood, no print | tight spaces, credits |
| `mark_handprint.png` (1000 px) | the print alone, drips and spatter included | a sticker, a loading mark, a watermark |
| `icon.png` (512), `icon_1024.png`, `icon.ico` (16–256) | the print on a dark rounded tile with the 30 over its palm | app icon, favicon, store tile — reads at 64, the 30 still reads at 32 |

The print is a texture, so the full logo, the mark and the icon are high-resolution PNGs (the brief allows "vector, or high-resolution raster");
only the wordmark is vector. There are no one-ink versions of the full logo (a texture has no single-ink form) — use the wordmark for those.

## Colours

Warm white `#eee6d6` · night ink `#18101c` · blood: the print runs from `#b42622` (thin) to `#5c0a10` (thick); the wordmark's flat 30 is the print's own
mid tone (`#841718`, `#761416` on paper). All are in `tools/art/logo.py` / `logo_print.py`.

## Rules for using it

- Keep the **print directly behind the 30** (the hand's middle on the numerals' middle); do not recolour it brighter, flatten it, or clean up the drips.
- **Clear space**: 10 % of the 30's height on every side (the files already carry it).
- Do not stretch it or re-set the words in another font.
- The studio credit lockup ("Mammoth Games") is not drawn yet.
- The **context rule** (CLAUDE.md "Context") holds: no cause, authority or preparation is named or drawn; the print is a *reaction*, the same
  bloody handprint the opening's cold open already shows.

## Using it in the game

**Wired (round 48e, owner: "add it without background to our title"; re-laid in round 48g):** `scenes/title_screen.tscn` has `Menu/Logo`, a Sprite2D of
`assets/logo/logo_full_dark.png` (transparent, 2400 px) at scale 0.168 (about 403 x 286 on the 1152 x 648 screen), centred on (244, 188) — the LEFT column, with Play /
Settings / Exit left-aligned under it — drawn LINEAR + MIPMAPPED (`texture_filter = 4`; the PNG's import has `mipmaps/generate=true` — the project default is nearest, which
would shred a 2400 px image shrunk 6x), above a soft dark shade column (`Menu/Root/LeftShade`) so it reads over the live hallway behind it (docs/OPENING.md "The title").
`title_test` locks it: the dark logo, wholly on screen, in the left half, clear of the three buttons, drawn over the shade, mipmapped. History: round 48e first put it
top-right over the Gemini painting (centred, the red hand lost contrast on the red-brown brick; top-right on the stormy sky it popped); round 48f tried a live night-exterior
backdrop under it, and the owner called that "double dipping" with the opening's pan up the outside — so the title now lives INSIDE the building (round 48g).

Still on the placeholders, and not touched without a word from the owner: `scripts/opening_exterior.gd` (the title that rises over the clouds: a Label at size 62
in `TITLE_COLOR`), `scripts/hallway.gd` / `scripts/intro_overlay.gd` (the run-1 title card) and `project.godot` (`config/icon="res://icon.svg"` is Godot's default).
The full logo is landscape, about 1.41 : 1 (2400 x 1702). The suites to re-run after wiring another place: `title_test`, `opening_test`, `run_bookends_test`,
`tutorial_test`.
