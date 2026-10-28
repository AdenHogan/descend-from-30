# The Ledger — the look the menus that act on the world share

**BUILT v1 (round 48j) — two looks, one for each job (see "The Lamplight" below: the rings, the found-item panel and SEARCHING were moved to it after the owner saw the paper rings).** Owner: *"I quite like the ledger look as it ties together with the Player detail UI. At the same time, I'd like the appropriate amount of UX design too, from glitz,
glam, lighting, sound effects and whatnot that makes a UI like this look good. We want it to look good, clean, connected, and strong… and no offence, we don't want it to look like AI slop."*

It is paper, ink and a desk, because that is what the journal already is (`character_panel.gd`'s paper kit). The menus that wear it: **the merchant** (`shop_ui.gd`) and **the workbench**
(`workbench_ui.gd`) — the places you sit and read. The journal itself is the reference the kit was drawn from, not a consumer of it (it keeps its own `_Paper`).
The glance-and-go layer over the live game (**the pack ring, the body ring, the found-item panel, SEARCHING**) is the dark Lamplight look, below.

## The rules that keep it from being a stock "fantasy UI"

1. **Every effect has a physical reason.** A slip is taped; a stamp is pressed; a line is written with a pen; a sheet throws a shadow because it lies on something. If an effect has no
   physical reason it is not in the kit.
2. **Nothing glows.** Light is the paper's own shading (`Ledger.lit` — vertex tones, brighter toward the upper left where the lamp is) and the dark of the desk round it. Hover is a slip
   **lifting** (a bigger, softer shadow, a few px up, a pen line drawn under its title) — never a halo or a colour swap.
3. **No stock icon set, no gradient-filled rectangles, no rounded "cards".** Edges wander a little, *seeded* (`Ledger.ragged`): a sheet always looks the same and no two look alike.
4. **A real mix of type.** Printed heads = Barlow Condensed Bold (the logo's); plain body = Barlow; the typed voice = Special Elite (the merchant's receipts); and **the player's own
   hand** — the same face and ink the journal writes in for the run's character (`Ledger.font("hand")`, `Ledger.hand_ink()`, `character_panel.HAND`) — for what the *player* does: their notes, their
   money, their choices, the mark beside a better number.
5. **Sound is what the thing would sound like on a desk** (`tools/gen_ui_audio.py` → `assets/audio/ui/`, CC0, pink noise under a steep ceiling, in the audit): paper laid down, a page
   flicked, a pencil tapped, a rubber stamp, a pen, tape, banknotes counted, two knuckle raps for *no*. Quiet, two or three takes each, a hair of pitch, throttled — never a UI "blip".
6. **The flourish sits on top of the logic.** Every animation is a beat *before* the call the click always made (`shop_ui._on_card_chosen` stamps, waits `STAMP_BEAT`, then calls the
   unchanged `_on_take_upgrade`); bots and tests call the logic directly and never wait for a tween.

## The kit (`scripts/ledger*.gd`)

| file | what it is |
|---|---|
| `ledger.gd` (`Ledger`) | the ONE place for the palette (`PAPER`, `INK`, `STAMP_RED`, …), the fonts (`font(kind)`), the hand (`hand_info/hand_ink/hand_scale`), the sounds (`play(name, db, min_gap)`, `SOUNDS`, `muted` for tests / captures), and the paper maths (`ragged`, `shifted`, `lit`, `pen_line`). `label()` / `style()` make a Label in one of the faces. |
| `ledger_sheet.gd` | a sheet lying on the desk: shadow, the stack of sheets under it, lit paper, fibres, stains, a cup ring now and then, ruled lines + a red margin. Children are laid out by Godot's containers on top. |
| `ledger_slip.gd` | a slip held by a strip of tape (a perk on offer). Lifts under the pointer or with focus inside it; `held` leaves it lifted with a pen tick. |
| `ledger_paper.gd` | the same paper that only *draws* — first child of a container (the loot panel), so a panel that changes height is still one sheet. |
| `ledger_button.gd` | a real `Button` (focus, shortcut and pad all work) drawn as a box ruled in ink; hover = pencil hatching, pressed = ink floods, disabled = dotted + struck through, focus = four proofreader's corner marks; `refuse()` shivers it with a knock. |
| `ledger_stamp.gd` | a rubber stamp: red ink, ruled border, thick where it pressed and thin where it did not, a little crooked; `play()` lands it (comes down too big, thuds, knocks the sheet). Once pressed it stays. |
| `ledger_rule.gd`, `ledger_pips.gd` | a pen line (single, or the bookkeeper's double that closes a column); tally boxes (set = inked, staged = pencilled, empty = ruled). |

## The two paper menus

- **Merchant** — one sheet on a dimmed desk (vignette backdrop, the page settles in). "THE OFFER" / "WARES" are tabs; the offer is three taped slips (rarity word printed in an ink by the
  perk's weight; a drawback in red); TAKE presses a TAKEN stamp, the other two slips are set aside, then the page moves on to the wares. Wares are ruled lines; SOLD is stamped; BUY
  → SIGN?, SELL → SURE? (the two-click confirms are unchanged). The notes and the floor line are in the player's hand.
- **Workbench** — the same sheet; the perk choice is two slips; the tuning column is a fixed grid with `LedgerPips`; a spare part / scrap line is written, not printed.

## The Lamplight — rings, found-item panel, SEARCHING (round 48j, part 4)

Owner, on the taped-paper rings: *"I don't like this. Can you give me a version of the wheel that looked like that other mockup… the one that was dark and goldish in the corners. It looked
pretty smart and clean. The grungy taped on style looks nice in the profile UI, but it might be a bit too much now. Also there's just way too much text going on up there at the top…
It needs to be clean information a player can glance at and recognise. If we even need text, it needs to be one word (equip, drop, compare, etc). I also definitely don't like the search bar
like this… the word searching literally can be the bar… going from the S to the G… once the word is filled in we know if it's something or nothing found."* And: *"Place the searching over
the node being searched, not in the centre of the screen."*

The look is the "Descent Menu Mockups" Lamplight board's, hex for hex (`scripts/lamp.gd`, `Lamp`): dark glass (a vertical gradient with a faint warm inner light), a 2-px brass-brown edge, brass
corner brackets, warm cream text, green / red for better / worse and a cool steel for a body's things. Barlow Condensed (heads and letter-spaced one-word captions) over Barlow — the logo's faces.
**Rules (a gate on any later UI of this layer):** information first — a word is ONE word (EQUIP, DROP, HELD, LOCKED, CRAFT, LOAD, CLOSE, EMPTY, BROKEN), a number carries a drawn ▲ / ▼ (drawn,
not a font glyph: none of our fonts has them), never a sentence; **no help strips**; brass = what is yours or chosen (in hand, brackets, what you are about to do), green / red only ever mean
better / worse; everything is drawing — nothing in the kit decides anything.

- **Pack ring** (`pack_wheel.gd`) — a smoked dark ring with a dashed track; every slot a dark card (`Lamp.slot`): the thing at 56 px, its key number, an `x3` count, and a 3-px bar of what is left
  of it (green / brass / red). The one in hand has brass brackets and a **HELD** tab; the pointer lifts a slot (brass edge, a warm halo, 76 px); a craft being dragged over an item rings it green
  (it will work) or red. Ring radius 120 / slot 64 so the card in the middle never touches a slot (`lamp_test` measures it for 3-6 wedges). **The middle is ONE small card** (`Lamp.info`): the
  item's name and — for a weapon — the three rows that matter (the ones that differ from the weapon in hand come first, `Lamp.pick_rows`, in the card's own order), a short fact for anything
  else (`Heals 2`), one word when broken; with a drag in hand it is just the word — **CRAFT** over what it makes, **LOAD**, **DROP**, **NO** over the reason — and **CLOSE** when the pointer is
  on nothing. The right-click menu is a dark panel, one word a row (Equip / **Unequip** / Use / Drop), the row under the pointer lit in brass (a drop in red). **The long help line is gone.**
  Sounds are the desk ones, softly (a tick on hover / equip, the pack's flap on open, tape on a craft, a page on a drop, two raps for no).
- **Body ring** (`body_ring.gd`) — the same drawing in steel (`Lamp.STEEL` brackets, edge and base) with the fallen character's NAME on a steel tab over it; the middle says LOOT (take all) /
  EMPTY / TAKE (a drag over the pack) / the item as the pack ring reads it (`Lamp.item_lines`, so a thing reads the same on either).
- **Found-item tag — IN THE WORLD (round 48l)** (`loot_ui.gd`) — owner: *"This hammer box is too much honestly… simplify this information to what the player needs. Also I don't want the box to just be overlayed in front. I like how
  searching is now in the game world. Let's put the box in the game world too, smaller, and beside the node, when a player walks back up to a node they have searched but did not take."* The tag is **300 px wide** (was
  380) and stands **beside the node** it came from — right of it, or left when the right would leave the screen, a little above its middle (`_place_tag`, screen px through the canvas transform; with no node it stands beside the
  player, never mid-screen) — and follows the node as the camera moves. It carries only what a player needs: the icon at 1× on a dark well, a one-word kind (`Lamp.kind_word` — **BLUNT / BLADE / GUN / MEDICAL / KEY…**; the combat table's
  "bat" is not shown: a hammer is not a bat), the name, **one line for what matters** (a weapon's "VS KNIFE" box lists only the rows that DIFFER, two at most — `LampRows`, header 16 px), and the keys **[E] TAKE**
  (+ **[R] LOAD**). A refusal turns the name red and says MAKE ROOM. **A PREVIEW stands whenever the player is in reach of a searched node that still holds something** (`loot_ui.preview_target`: scavenge mode, in range,
  searched, takeable; not while a search / the modal tag / the pack ring is up, paused, dead, mid-switch) — a second, non-modal tag on its own nested layer (`_preview`), faded in over 0.12 s; **pressing [interact] while it
  shows takes the item in that one press** (`open(..., node)` sees `preview_showing_for(node)` → `_take()`; a full pack leaves the real tag up saying MAKE ROOM, as a second press always did). A locked cabinet's gun behind
  glass is not "takeable" yet, so shows no preview. Taking is otherwise unchanged (E, double-click, drag onto the pack / a ring slot).
- **SEARCHING** (`search_word.gd`, `SearchWord`) — **no panel and no bar while a search runs.** The word hangs just above the node being searched (screen position through the canvas transform
  of the node `Interactable` hands over — never the screen's centre; with no node it hangs over the player), on a thin dark plate, and its letters light **one after another, S to G**, dim to brass, as
  the timer runs (a very quiet tick as each comes on). When the last is lit it resolves where it hangs: **found** = the whole word flares warm white and lifts away as the result panel arrives;
  **nothing** = the letters go grey and sink and a line is said in passing ("Nothing."). Walking away takes it at once. The search's length, what it finds and the cancel rules are `loot_ui`'s and
  unchanged. `tools/scene_capture` steps: `loot:<apt>:<anchor>[:<fraction>]` (a fraction holds the search there), `anchors` (lists a room's nodes), `ringmenu:<k>`, `ringdrag:<k>[:out]`.

## Tested

`tests/ledger_test.gd` (the 78th suite; mutation-checked: no stamp press fails it) — the paper kit's purity (same seed, same sheet; edges stay inside the rectangle; no flicker), the faces exist and
differ, every named sound exists on disk, a muted kit plays nothing and a throttled one does not machine-gun; the merchant (one slip per perk on offer, none cut the same, the stamp presses at once but
the choice waits for the beat and then runs exactly once); the workbench opens, tabs and gives the pause back.
`tests/lamp_test.gd` (the 79th suite) — the palette is the board's hex for hex, the type settings differ, `fit` never runs over and stops at 8 px, `pick_rows`, the card grows with what it says, every
item's caption is one word; SEARCHING lights its letters in order and never goes back, resolves found / nothing and is gone after its beat, cancels at once; the loot panel is dark glass, has no
progress bar, shows NO panel while searching, hangs the word over the node (a stub node at a known position), lights half the word half-way, shows the panel + a resolved-FOUND word at the end, names the
item with a one-word caption and one line of keys, compares a weapon, turns red on a refusal; an empty node ends as NOTHING with no panel; leaving mid-search takes the word; the rings are drawn in the
kit (source check), have no help strip, the middle card never overlaps a slot for 3-6 wedges, every menu row and every readout is one word, a bottle dragged onto torn clothes says CRAFT over
"Molotov Cocktail". Existing suites cover the rules: `loot_test`, `item_compare_test`, `pack_test`, `body_ring_test`, `weapon_upgrade_test`, `merchant_smoke_test`, `click_claim_test`, `hud_wheel_test`,
`inventory_flow_test`.

## Capturing it

`tools/scene_capture.tscn` steps: `shop:<offer|wares|take|buy:<i>|x>`, `notes:<n>`, `bench:<upgrade|tune|salvage|x>`, `loot:<apartment>:<anchor>:<item>[:<search fraction>]`
(`loot:x` closes), and the existing `pack:<k>` (needs `ws:has_backpack:1` under the real `Game.new_game()` rules — the packless rule gives a new game no pack until it is picked up).

## Not done / owner's call

- **The LOOK and the SOUND are unheard / unseen by the owner.** Everything was captured under xvfb and judged from frames and numbers; the sounds were judged by spectrum
  (`tools/audio_audit.py`), not listened to.
- The journal (`character_panel.gd`) keeps its own paper code; unifying it with `ledger.gd` is a later tidy-up (the look already matches — the kit was drawn from it).
- Other panels still in the old look: the pause menu, settings, the profile screen, the Valour offer (`legacy_ui.gd`), the lobby door's panel (`handoff_ui.gd`), the end screen, the
  quest conversation box, the HUD in-hand box and tooltips. They are next if the look is liked.
- The hotbar / world pills (`world_drop` pickup pill) are still the dark form.
- No gamepad focus pass on the new buttons beyond Godot's own (the buttons are real `Button`s, so focus and `ui_accept` work; the proofreader's-corner focus mark is drawn).
- Fonts: Barlow (SIL OFL) and Special Elite (Apache 2.0) live in `assets/fonts/ledger/` with their licences; the heads reuse the logo's Barlow Condensed.
