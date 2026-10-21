# The logo — "Descend From 30"

Made in-house (owner round 48) by `python3 tools/art/logo.py` (the print: `tools/art/logo_hand.py`; the lettering: Barlow Condensed Bold,
SIL OFL, in `assets/fonts/logo/` with its licence). The files below are GENERATED — change the tools, never the files;
`tools/art/logo.py --check` (in `tools/run_all_tests.sh`) fails on a stale or missing one.
**It is not wired into the game yet** (`scenes/title_screen.tscn`, `scripts/opening_exterior.gd`, `project.godot`'s `icon` still use the
placeholders) — see "Using it in the game" below.

![contact sheet](logo_sheet.png)

## What it is

Two lines of capitals on one width — **DESCEND** / **FROM 30**, the 30 in blood — and one slim handprint as tall as the two lines. That is all:
no bevel, outline, shadow, texture, gradient or ornament. It is a vector (SVG), flat, in two colours per version.

History: the first version was pixel art (a dithered print, slab letters with an extrusion, a brick-tower 30 with lit windows). The owner
called it "AI crap… it needs to be clear and clean", so everything but the idea went: the typeface is a real, plain one, the colours are two, the
print is a flat silhouette. (A pixel-art version can come back as a separate in-world sign if wanted; this one is the logo.)

**The print** has two rules that came from the owner's note on two AI attempts — "too fat at the base and comically red, or red paint gore slop":

1. **No fat base.** Proportions are measured in palm-widths (palm 0.9 wide, middle finger 0.95, a spread fan of four fingers each 0.19–0.22
   wide, a narrow curved thumb); the palm tapers to a wrist only ~0.5 wide, cut off short. `--check` measures the unrotated shape: the
   wrist must be under 70 % of the palm's width and the whole hand between 0.55 and 0.78 as wide as it is tall.
2. **No comic red, no gore.** One flat colour, no drips, splatter, gloss or texture. Blood is `#a02123` on a dark ground, `#881b1e` on a light
   one (loudness, saturation × value, 0.50 and 0.43 against a cartoon red's ~0.78; `--check` refuses anything above 0.56).

## Files (`assets/logo/`)

| file | what | for |
|---|---|---|
| `logo_full_dark` | print + two lines, warm-white letters | dark backgrounds (the title screen, a store banner) |
| `logo_full_light` | the same, ink letters | light backgrounds (press kit, documents) |
| `logo_wordmark_dark` / `_light` | the two lines only | tight spaces, credits, a banner that already has art |
| `logo_full_white` / `_black`, `logo_wordmark_white` / `_black` | ONE INK | stamps, embossing, merchandise, single-colour print |
| `mark_handprint_dark` / `_light` | the print alone | a sticker, a loading mark, a watermark |
| `icon` (`.png` 512, `icon_1024.png`, `.ico` 16–256, `.svg`) | the print on a dark rounded tile | app icon, favicon, store tile — drawn natively at every size |

Each logo exists as `.svg` (the master: any size, no blur), `.png` (2400 px wide for the full logo, 1600 for the wordmark, 800 for the
print) and `_600.png` (600 px wide, for small uses). All are on transparent backgrounds.

## Colours

Warm white `#eee6d6` · night ink `#18101c` · blood `#a02123` (dark ground) / `#881b1e` (light ground). All are in `tools/art/logo.py`.

## Rules for using it

- **Clear space** round the logo: at least 30 % of the cap height of the lettering on every side (the files already carry it).
- Do **not** recolour the print brighter, add drips or splatter, outline it, put it behind the letters, stretch it, or re-set the words in
  another font.
- The studio credit lockup ("Mammoth Games") is not drawn yet.
- The **context rule** (CLAUDE.md "Context") holds: the logo names or implies no cause, authority or preparation; the print is a *reaction*,
  the same bloody handprint the opening's cold open already shows.

## Using it in the game (not done — the owner's call)

Wiring it in touches `scenes/title_screen.tscn` (the Label over the painted placeholder), `scripts/opening_exterior.gd` (the title that
rises over the clouds: a Label at size 62 in `TITLE_COLOR`), `scripts/hallway.gd` / `scripts/intro_overlay.gd` (the run-1 title card)
and `project.godot` (`config/icon="res://icon.svg"` is Godot's default). The game's art is hard-edged pixel art, so decide whether the
smooth vector logo should sit over it as it is or be re-drawn as pixel art (the generator's first version was). The suites to re-run after wiring:
`title_test`, `opening_test`, `run_bookends_test`, `tutorial_test`.
