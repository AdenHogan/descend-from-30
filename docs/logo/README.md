# The logo — "Descend From 30"

Made in-house (owner round 48) by `python3 tools/art/logo.py` (the print: `tools/art/logo_hand.py`; the lettering: Barlow Condensed Bold,
SIL OFL, in `assets/fonts/logo/` with its licence). The files below are GENERATED — change the tools, never the files;
`tools/art/logo.py --check` (in `tools/run_all_tests.sh`) fails on a stale or missing one.
**It is not wired into the game yet** (`scenes/title_screen.tscn`, `scripts/opening_exterior.gd`, `project.godot`'s `icon` still use the
placeholders) — see "Using it in the game" below.

![contact sheet](logo_sheet.png)

## What it is

**A bloodied handprint behind the number** (the owner's brief). A big **30** in warm white stands over one slim handprint in dried blood; the
hand's fingers rise behind a small line of capitals, **DESCEND FROM**, set at an open tracking and sized to the exact width of the 30; the thumb
curls out behind the 3 and the heel of the palm shows under the 0. Two flat colours, one typeface, one shape. No bevel, outline, shadow, texture,
gradient or ornament. It is a vector (SVG).

History (so the same mistakes aren't made twice): the first version was pixel art — a dithered print, slab letters with an extrusion, a brick-tower
30 with lit windows — and the owner called it "AI crap… it needs to be clear and clean"; the second set the print BESIDE the words, which was wrong
("the handprint should be a bloodied handprint behind the number"). A rounded heel with no wrist made the base fat; thin crease cuts across the
fingers read as rings; both are gone.

**The print** has two rules that came from the owner's note on two AI attempts — "too fat at the base and comically red, or red paint gore slop":

1. **No fat base.** Proportions are measured in palm-widths (palm 0.9 wide, middle finger 0.95, a spread fan of four fingers each 0.19–0.22
   wide, a narrow curved thumb); the palm tapers to a wrist only ~0.5 wide, cut off short. `--check` measures the unrotated shape: the
   wrist must be under 70 % of the palm's width and the whole hand between 0.55 and 0.78 as wide as it is tall.
2. **No comic red, no gore.** One flat colour, no drips, splatter, gloss or texture. Blood is `#a02123` on a dark ground (loudness, saturation ×
   value, 0.50 against a cartoon red's ~0.78; `--check` refuses anything above 0.56).

`--check` also keeps the composition honest: DESCEND FROM and the 30 are exactly the same width, and the print really is behind the 30 (it rises
above it, hangs below it, and at least a quarter of the numerals' area stands over it).

## Variants

| ground | what changes |
|---|---|
| `dark` — dark backgrounds | warm-white letters over the blood print |
| `light` — light backgrounds | ink letters over a PALER print (`#b25452`), so ink never sits on dark red (ink on it 3.8 : 1, the print on the paper 3.9 : 1; warm white on the blood print is 6.2 : 1) |
| `white` / `black` — one ink | the print is cut back a hair (34 units) round every letter so the letters stay clean |

The **wordmark alone** (no print) sets the 30 itself in blood (`#a02123` / `#881b1e`), DESCEND FROM above it in the letter colour.

## Files (`assets/logo/`)

| file | what | for |
|---|---|---|
| `logo_full_<dark|light|white|black>` | the print behind the 30 + DESCEND FROM | the title screen, a store banner, press kit, stamps |
| `logo_wordmark_<dark|light|white|black>` | DESCEND FROM over the 30, no print | tight spaces, credits, a banner that already has art |
| `mark_handprint_<dark|light>` | the print alone | a sticker, a loading mark, a watermark |
| `icon` (`.png` 512, `icon_1024.png`, `.ico` 16–256, `.svg`) | the print on a dark rounded tile with the 30 over its palm | app icon, favicon, store tile — drawn natively at every size |

Each logo exists as `.svg` (the master: any size, no blur), `.png` (2000 px wide for the full logo, 1400 for the wordmark, 800 for the print)
and `_600.png` (600 px wide, for small uses). All are on transparent backgrounds.

## Colours

Warm white `#eee6d6` · night ink `#18101c` · blood `#a02123` (dark ground) / `#881b1e` (the 30 alone on a light ground) · pale print `#b25452`
(light ground). All are in `tools/art/logo.py`.

## Rules for using it

- **Clear space** round the logo: 12 % of the 30's height on every side (the files already carry it).
- Do **not** recolour the print brighter, add drips or splatter, outline it, move it from behind the number, stretch it, or re-set the words in
  another font.
- The studio credit lockup ("Mammoth Games") is not drawn yet.
- The **context rule** (CLAUDE.md "Context") holds: the logo names or implies no cause, authority or preparation; the print is a *reaction*,
  the same bloody handprint the opening's cold open already shows.

## Using it in the game (not done — the owner's call)

Wiring it in touches `scenes/title_screen.tscn` (the Label over the painted placeholder), `scripts/opening_exterior.gd` (the title that
rises over the clouds: a Label at size 62 in `TITLE_COLOR`), `scripts/hallway.gd` / `scripts/intro_overlay.gd` (the run-1 title card)
and `project.godot` (`config/icon="res://icon.svg"` is Godot's default). The logo is portrait (0.72 : 1 including its clear space), so on the 1152 × 648 title
screen it wants roughly 440 px of height (about 320 px wide). The game's art is hard-edged pixel art, so decide whether the smooth vector logo should sit over it as
it is or be re-drawn as pixel art. The suites to re-run after wiring: `title_test`, `opening_test`, `run_bookends_test`, `tutorial_test`.
