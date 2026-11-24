# Midjourney prompts for the HUD portraits

Written 2026-11-24 for the owner. The procedural / hand-coded portraits (five attempts) were rejected, and the placeholder busts in `assets/Health_Bar` are AI-made
and drop in quality as the wounds get worse, so the portraits are to be made outside the repo. This file is the brief: one prompt for each of the **24 pictures** (4 characters x 6 health stages).

## What the game needs

| | |
|---|---|
| Files | `assets/Health_Bar/<id> - <N> - <Stage>.png` (24 files, names below), PNG with a transparent background |
| Size | the HUD shows them at 132 x 165 px; the source art is 281 x 351 (4 : 5). Make them 4 : 5 and larger, then downscale. |
| Pose | head and shoulders, the face turned to the right (3/4 view), the same framing in every picture so the six stages swap cleanly |
| Tone | cosy horror in an ordinary British block of flats; a sudden emergency. NOTHING that names a cause: no virus, no lab, no military, no quarantine, no news, no zombies (CLAUDE.md "Context") |
| Language | British English in anything written on the clothes (the prompts avoid writing) |

## How to run it (Midjourney)

1. **Do each character's `1 - Healthy` first.** Pick the one you like and keep it as that character's anchor.
2. **Hold the character steady across the six stages** with your version's character / omni reference (`--cref <anchor url>` in v6, `--oref <anchor url>` in v7) and the same `--seed`; keep the rest of the prompt
   identical and change only the stage sentence. Raise the reference weight (`--cw 100` / `--ow`) if the face drifts.
3. **Hold the STYLE steady across all four characters** with a style reference taken from the first anchor you approve (`--sref <url>`), so the set looks drawn by one hand.
4. Settings used below: `--ar 4:5`, `--s 150` (raise for more stylisation), add `--v 7` or `--v 6.1` as you prefer. If a prompt is refused for the blood wording, soften it to "red paint stains" and
   add the blood afterwards in an editor, keeping the same flat red shapes on every stage.
5. **Layout reference (optional):** `docs/art_reference/portraits/joe_sprite_stages.png` is Joe in the game's own sprite style, six stages, right-facing; upload it and use it as an image prompt (not a style reference) if you
   want the same framing and the same stage-to-stage progression.
6. Cut the background out (it is a flat mid-grey on purpose), crop all 24 to the same 4 : 5 frame so the head sits in the same place, export 281 x 351 (or any 4 : 5 and tell me), and name the files exactly as below.
   Drop them in `assets/Health_Bar/`; tell me and I will import them and run the HUD tests.

## The shared style block (already inside every prompt below)

> head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background

`--no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses`

## The wounds, by stage (so they are the same for every character)

- **1 - Healthy** — healthy: calm, alert, a little worried, clean undamaged clothes, tidy hair
- **2 - Hurt** — hurt: a red scratch across one cheek, a bead of sweat, a tense worried expression, hair a little messy
- **3 - Injured** — injured: a purple bruise round one eye, a split lip with a thin trickle of blood, a small cut above the brow, smudges of dirt on the face and clothes, a pained worried expression
- **4 - Wounded** — wounded: a gauze bandage wrapped round the forehead with a spot of blood soaking through, a trail of blood down the temple, pale drawn skin, dark circles under the eyes, matted hair, a grimace
- **5 - Severely Wounded** — severely wounded: a head bandage soaked red, one eye swollen shut and bruised, blood round the mouth and chin, grey-pale skin, a dazed half-lidded stare, blood spatter on the clothes
- **6 - Dying** — dying: ashen grey skin, eyes closed or barely open and glazed, head heavy, mouth slightly open with a little blood, a soaked bandage, runs of blood down the face and neck, clothes heavily stained

Keep the wounds in the SAME flat, stylised treatment as the face (hard-edged flat red shapes, no photographic gore), so the last stage is drawn as carefully as the first.


## Joe — the Tenant (`blond_man`)

**Who:** a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face.

**`blond_man - 1 - Healthy.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, healthy: calm, alert, a little worried, clean undamaged clothes, tidy hair, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_man - 2 - Hurt.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, hurt: a red scratch across one cheek, a bead of sweat, a tense worried expression, hair a little messy, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_man - 3 - Injured.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, injured: a purple bruise round one eye, a split lip with a thin trickle of blood, a small cut above the brow, smudges of dirt on the face and clothes, a pained worried expression, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_man - 4 - Wounded.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, wounded: a gauze bandage wrapped round the forehead with a spot of blood soaking through, a trail of blood down the temple, pale drawn skin, dark circles under the eyes, matted hair, a grimace, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_man - 5 - Severely Wounded.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, severely wounded: a head bandage soaked red, one eye swollen shut and bruised, blood round the mouth and chin, grey-pale skin, a dazed half-lidded stare, blood spatter on the clothes, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_man - 6 - Dying.png`**
```
Portrait of Joe: a white man in his late twenties, messy dark brown mop of hair swept to the right, light stubble, blue-grey eyes, a faded teal knit jumper over a grey t-shirt, a steady, tired, honest face, dying: ashen grey skin, eyes closed or barely open and glazed, head heavy, mouth slightly open with a little blood, a soaked bandage, runs of blood down the face and neck, clothes heavily stained, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```


## Vivianne — the Neighbour (`blond_woman`)

**Who:** a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look.

**`blond_woman - 1 - Healthy.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, healthy: calm, alert, a little worried, clean undamaged clothes, tidy hair, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_woman - 2 - Hurt.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, hurt: a red scratch across one cheek, a bead of sweat, a tense worried expression, hair a little messy, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_woman - 3 - Injured.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, injured: a purple bruise round one eye, a split lip with a thin trickle of blood, a small cut above the brow, smudges of dirt on the face and clothes, a pained worried expression, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_woman - 4 - Wounded.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, wounded: a gauze bandage wrapped round the forehead with a spot of blood soaking through, a trail of blood down the temple, pale drawn skin, dark circles under the eyes, matted hair, a grimace, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_woman - 5 - Severely Wounded.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, severely wounded: a head bandage soaked red, one eye swollen shut and bruised, blood round the mouth and chin, grey-pale skin, a dazed half-lidded stare, blood spatter on the clothes, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`blond_woman - 6 - Dying.png`**
```
Portrait of Vivianne: a white woman in her thirties, loose golden blonde hair falling to just below the shoulders with a side-swept fringe, blue eyes, a coral zip-up jacket with a white yoke and a high collar, a quiet, watchful, athletic look, dying: ashen grey skin, eyes closed or barely open and glazed, head heavy, mouth slightly open with a little blood, a soaked bandage, runs of blood down the face and neck, clothes heavily stained, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```


## Alex — the Super (`bald_man`)

**Who:** a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face.

**`bald_man - 1 - Healthy.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, healthy: calm, alert, a little worried, clean undamaged clothes, tidy hair, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`bald_man - 2 - Hurt.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, hurt: a red scratch across one cheek, a bead of sweat, a tense worried expression, hair a little messy, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`bald_man - 3 - Injured.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, injured: a purple bruise round one eye, a split lip with a thin trickle of blood, a small cut above the brow, smudges of dirt on the face and clothes, a pained worried expression, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`bald_man - 4 - Wounded.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, wounded: a gauze bandage wrapped round the forehead with a spot of blood soaking through, a trail of blood down the temple, pale drawn skin, dark circles under the eyes, matted hair, a grimace, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`bald_man - 5 - Severely Wounded.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, severely wounded: a head bandage soaked red, one eye swollen shut and bruised, blood round the mouth and chin, grey-pale skin, a dazed half-lidded stare, blood spatter on the clothes, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`bald_man - 6 - Dying.png`**
```
Portrait of Alex: a Black man in his forties, short cropped black hair, clean-shaven with no beard and no moustache, warm brown eyes, navy boiler-suit overalls with brass buttons and a small name patch over a plain tee, a calm, capable, practical face, dying: ashen grey skin, eyes closed or barely open and glazed, head heavy, mouth slightly open with a little blood, a soaked bandage, runs of blood down the face and neck, clothes heavily stained, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```


## Amina — the Nurse (`dark_woman`)

**Who:** an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face.

**`dark_woman - 1 - Healthy.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, healthy: calm, alert, a little worried, clean undamaged clothes, tidy hair, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`dark_woman - 2 - Hurt.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, hurt: a red scratch across one cheek, a bead of sweat, a tense worried expression, hair a little messy, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`dark_woman - 3 - Injured.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, injured: a purple bruise round one eye, a split lip with a thin trickle of blood, a small cut above the brow, smudges of dirt on the face and clothes, a pained worried expression, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`dark_woman - 4 - Wounded.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, wounded: a gauze bandage wrapped round the forehead with a spot of blood soaking through, a trail of blood down the temple, pale drawn skin, dark circles under the eyes, matted hair, a grimace, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`dark_woman - 5 - Severely Wounded.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, severely wounded: a head bandage soaked red, one eye swollen shut and bruised, blood round the mouth and chin, grey-pale skin, a dazed half-lidded stare, blood spatter on the clothes, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

**`dark_woman - 6 - Dying.png`**
```
Portrait of Amina: an Indian woman in her thirties, long straight black hair with a centre parting, warm brown eyes, small gold earrings, a mustard-yellow cardigan over a magenta top and a hospital ID lanyard, a kind, tired, determined face, dying: ashen grey skin, eyes closed or barely open and glazed, head heavy, mouth slightly open with a little blood, a soaked bandage, runs of blood down the face and neck, clothes heavily stained, facing right in three-quarter view, head-and-shoulders character portrait for a 2D horror survival game HUD, three-quarter view with the face turned to the right, stylised illustration with bold clean contour lines in a dark plum colour (not black), flat cel-shaded colour with hard-edged shadow shapes and a thin rim light, a plain readable face with normal proportions and simple features, big soft shapes for the hair, slightly oversized clothing, hand-drawn look, ordinary British flat resident, plain flat mid-grey background --no text, watermark, signature, frame, border, photo, 3d render, extra people, weapon, hat, glasses --ar 4:5 --s 150
```

## Things to check on every picture

- The face is turned to the **right** (the game's characters face right).
- The same head size, position and crop as the other five stages of that character.
- Clothes and hair colours match the character's sprite (Joe teal and brown, Vivianne coral and gold, Alex navy and black, Amina mustard and black).
- No text, no logos, no hat or glasses (none of them wears any), no moustache or beard on Alex (the owner asked for a clean-shaven face).
- The wounds get steadily worse from 1 to 6 and keep the same quality of drawing.
