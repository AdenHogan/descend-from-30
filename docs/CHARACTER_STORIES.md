# Character stories — four openings, four personal quests (owner round 37, BUILT v1)

> "We don't need the new character to have to go up to the door of 3001 and show they are locked out always. And we don't need
> to have them pick up the backpack. If player 1 picks up the backpack, then players 2 and 3 will just automatically have it
> equipped. We can start a character's run with a personal quest to get them going."

**Every line, sound and the cat's art in this build is a PLACEHOLDER.** The structure (cue → line → quest → hook) is what
is built; the owner rewrites the words. All the text lives in ONE file, `scripts/character_story.gd` (Joe's lines stay in
`TutorialManager.LINES`, the tutorial's single edit point).

## The rule

`WorldState.story_rule` is a default-OFF flag only the real `Game.new_game()` turns on (like `packless_rule`). A plain
`WorldState.new_game()` — every test, which deals a RANDOM cast — keeps the old game: no Joe lock, no quest, no scripted
body, no cat. It is saved (an old save has no key = no story). `character_story_test` checks `game.gd` sets it BEFORE the
world is dealt (the cast is cast from it).

## Joe is always the tutorial's character

`WorldState.joe_opens = story_rule and is_first_run` (set in `new_game`, before any cast read; saved). `run_cast()` then
puts `TUTORIAL_CHARACTER` (`blond_man` = Joe) first and draws the other two from the remaining three. A game that
skips the tutorial (a completed profile) casts freely, so any of the four can open. The cast cache is keyed by seed AND
the lock.

## The openers (`CharacterStory.opener(cid)`)

Each run opens as before — the exterior, the time card — then the black "line" screen, whose **cue** (a sound) and **line**
are now the character's own (`hallway.opener_config(cid)` → `intro_overlay.cue`; `CUE_AUDIO` / `CUE_DELAY` in
`intro_overlay.gd` say what plays and when the line reacts).

| | cue | first line | locked out? | on stepping out |
|---|---|---|---|---|
| **Joe** | banging on his own door | the tutorial's `opener_1` | **yes** — knocks at 3001, no spare key (run 1: remember the 3003 key) | `opener_4/5` lockout, then he chooses to descend |
| **Alex** (the Super) | a far SCREAM | "That scream… it came from the stairwell…" | no | one line, off to the stairwell |
| **Vivianne** | a MEOW | "Where did you get to this time?…" | no | one line, after her cat |
| **Amina** (the Nurse) | a hungry growl (stomach) | "Nothing in the fridge…" | **yes** — locked out, keys inside | two lockout lines: "Someone downstairs will have food." |

The two who knock use the old visible lockout (`hallway.start_opener_lockout` → `player.knock_door`) and — on a later run —
still nod to how the previous character's run ended (`lockout_lines`, `run_after_fell` / `run_after_escaped`). The other
two (`knock` false) say their `walkout` line (no pause) and set off. Either way `CharacterStory.begin_run_quest()` runs when
the opening ends.

## The personal quest

`WorldState.run_story_stage` (-1 not begun · 0 the opening objective · 1 after the hook) + `run_story_flags` (one-off beats,
string keys), both per-run (reset by `new_game` and `advance_run`) and saved. `begin_run_quest()` shows the **NEW QUEST** banner
(`quest_banner.gd`, a HUD plate); the hook shows **OBJECTIVE UPDATED**. The journal's *Quests* page lists the title, the
finished objectives struck through, and the current one (`CharacterPanel._quest_bbcode`). A quest never goes backwards, and
**every hook is ignored until the quest has begun** (the opener's own time must not spend a flag).

| | quest | stage 0 | the hook (→ stage 1) |
|---|---|---|---|
| Joe | Locked out | "Get the spare key from 3003." (tutorial) / "Find a way out of the building." | reaching floor **29** — he chose to descend (`on_floor_arrival`, via `WorldState.note_floor_arrival`) |
| Alex | The scream | "Find out who screamed." | walking up to the body on **29** (below) |
| Vivianne | Lost cat | "Find your cat." | the first sight of the cat — the floor-30 cameo, a corridor cat, or a foreground dash (`on_cat_seen`) |
| Amina | Hungry | "Find something to eat." | Canned Food (**005**, the only food) enters her inventory (`on_item_gained`, from `add_to_inventory`) |

## Alex's body on floor 29

`CharacterStory.alex_body(floor)` returns a scripted corpse only in Alex's run on floor 29 (`story_rule` on). `corridor_decals.add_to`
reserves its rect before planning the dressing (nothing is dropped on it), lays it FIRST among the dead as a normal searchable
`corridor_body` (`dead_3`, plan index 90), and puts a `StoryAlexBody` tripwire (`story_trigger.gd`, a 300×90 Area2D) on it.
Walking onto it plays one paused beat ("No… Mr Hale. 2904. I fixed his sink last week…"), then the quest turns over with
"I'm not staying up here." Once per run (a flag). The victim's name and flat are placeholders.

## Vivianne's cat (`cat_actor.gd`, `fg_cat.gd`) — never dies

* **In the world:** a black cat that sits, flicks its tail, now and then meows (positional), wanders and bolts when the player
  nears. It is a plain `Node2D` in group `cat` ONLY — no collision, never in `zombie` / `resident_target` — so it can't be
  hit, burned, shoved, spat at or block anyone, and has no health to lose. Feet on the standard corridor line (419, local to its
  floor). Eyes are an UNSHADED second strip, so the glint stays lit at night.
* **Where:** floor 30 (`hallway._spawn_cat_cameo`): it sits at x 600 and, once she's close and the quest has begun, RUNS to the
  stairwell (x 190) and vanishes — the hook that sends her down (live-only; gone for good once seen). On floors 1-29
  (`building_floors._spawn_cat`, live + `go_live`, never a passive pan backdrop) in `CAT_FLOOR_CHANCE` (34%) of floors, seeded
  per floor + run (`cat_on_floor`, `cat_start_x`).
* **Foreground:** every 55-110 s (first 16-32 s after the quest begins) a big (×9) black cat streaks along the bottom of the
  screen with a meow (`fg_cat.gd`, a HUD child, mouse-transparent, only while the game runs and nothing else has the screen).
  The first dash or sight turns her quest over.
* Only in HER run (`story_rule` + `current_character() == VIVIANNE`).

## The pack carries over

`WorldState.backpack_found` (cross-run, per playthrough; reset by `new_game`; saved, defaulting from an old save's
`has_backpack`) is set by `take_backpack()`. `advance_run` gives the next character `has_backpack = (not packless_rule) or
backpack_found`, so runs 2 and 3 have it on from the first step; nobody found it = pockets only again. Floor 30's pack beside
3001 is only laid out for a character who doesn't have one (`hallway._spawn_backpack`, unchanged).

## Files

`scripts/character_story.gd` (all text, openers, quests, hooks) · `quest_banner.gd` · `cat_actor.gd` · `fg_cat.gd` ·
`story_trigger.gd` · `tools/art/cat.py` → `assets/cat/` (body + eyes strips: walk 4, run 4, sit 2, meow 2; 28×18 px frames) ·
`tools/gen_story_audio.py` → `assets/audio/cat/meow_{1,2,3}.wav`, `assets/audio/story/{scream_far,growl}.wav` (CC0, synthesized
placeholders). Removed: the shared `run2_open` / `run3_open` / `run_lockout` lines from `TutorialManager.LINES`.

Locked by `character_story_test` (rule, Joe lock + cast cache, openers + their audio, quest lifecycle for all four, pack carry-over,
save/load, journal, Alex's body + tripwire, cat floors / plane / groups / flee / bounds / cameo / go_live, foreground dash;
mutation-checked: Joe lock, pack carry-over, cat group, backward quests, tripwire, seen-during-opening each fail the suite),
`run_bookends_test` (`_test_opener_config`) and `backpack_test` (`_test_take_and_runs`).

## Not built / the owner's call

* The words, the screams and meows (all placeholder), the cat's art, a real "growl" (it's a stomach).
* Whether the cat should appear for the other characters too, and its rate (`CAT_FLOOR_CHANCE`).
* Quest stages beyond the one hook (each quest turns over once; the later floors' payoffs — Mr Hale's story, the cat found for
  good, a meal eaten — are open).
* The cat in apartments / the lobby; it is not in the pan backdrop (it appears when you arrive).
* Touch / pad for the quest banner is the same plate (no input).
* The look of the banner, the cat and the floor-29 body needs the owner's eye (headless only).
