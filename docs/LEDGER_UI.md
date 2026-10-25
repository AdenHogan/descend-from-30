# The Ledger — the look the menus that act on the world share

**BUILT v1 (round 48j).** Owner: *"I quite like the ledger look as it ties together with the Player detail UI. At the same time, I'd like the appropriate amount of UX design too, from glitz,
glam, lighting, sound effects and whatnot that makes a UI like this look good. We want it to look good, clean, connected, and strong… and no offence, we don't want it to look like AI slop."*

It is paper, ink and a desk, because that is what the journal already is (`character_panel.gd`'s paper kit). The menus that wear it: **the merchant** (`shop_ui.gd`), **the workbench**
(`workbench_ui.gd`), **the found-item panel** (`loot_ui.gd`), **the pack ring and the body ring** (`pack_wheel.gd`, `body_ring.gd`). The journal itself is the reference the kit was
drawn from, not a consumer of it (it keeps its own `_Paper`).

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
| `ledger_ring.gd` (`LedgerRing`) | the ring kit, pure drawing on a `CanvasItem`: `shade`, `tag` (a paper disc that lifts), `pen_circle`, `dashed` (pencil outline of where something was), `slip`, `card` (the middle slip: head, body, typed lines and stat rows with the hand's mark), `plate` (a strip of paper, kept on screen), `padlock`, `gauge`, `fit`. `BODY_TINT` = the body ring's cooler stock. |

## The four menus

- **Merchant** — one sheet on a dimmed desk (vignette backdrop, the page settles in). "THE OFFER" / "WARES" are tabs; the offer is three taped slips (rarity word printed in an ink by the
  perk's weight; a drawback in red); TAKE presses a TAKEN stamp, the other two slips are set aside, then the page moves on to the wares. Wares are ruled lines; SOLD is stamped; BUY
  → SIGN?, SELL → SURE? (the two-click confirms are unchanged). The notes and the floor line are in the player's hand.
- **Workbench** — the same sheet; the perk choice is two slips; the tuning column is a fixed grid with `LedgerPips`; a spare part / scrap line is written, not printed.
- **Found-item panel** — a slip of paper taped down; the thing lies on it with its shadow; the name is a printed head over a pen rule; the comparison with the weapon in hand is a ruled
  column in ink (`ItemCompare.bbcode(c, true)`; the dark form stays the default for the floor pill and the rings) with the better / worse mark in the player's hand (green / red ink);
  the hint is what the player jots to themselves. The slip *lands* (a hair large and turned, settling in a tenth of a second) with the paper sound. While it searches, the bar is a **box
  the player's pen fills in**, diagonal strokes laid down left to right, the one being drawn only part-way across. A refused take turns the name red and knocks twice.
- **Pack ring / body ring** — the pack lies open on a dark shade and every slot is a paper tag on it. The one in hand is circled in the player's pen (and labelled "in hand" on its
  outer side); a craft that would work is ringed green, one that would not red; durability is a pen line under the thing; stacks are typed `x3`. The middle is a taped slip. The help
  strip is paper. The right-click menu is a slip with the hovered row underlined. The body's tags are a cooler stock. A tick when the pointer moves onto an item, a pen scratch when you
  equip, tape when a craft works, a page when you drop, two raps when it will not.

## Tested (`tests/ledger_test.gd`, the 78th suite; mutation-checked: no stamp press, no paper under the loot panel, no on-screen clamp on the help strip each fail it)

The kit's purity (same seed, same sheet; edges stay inside the rectangle; no flicker), the faces exist and differ, every named sound exists on disk, a muted kit plays nothing and a
throttled one does not machine-gun; the merchant (one slip per perk on offer, none cut the same, the stamp presses at once but the choice waits for the beat and then runs exactly once);
the workbench opens, tabs and gives the pause back; the loot panel (paper first, no stock box, the shadow and the icon one picture, the landing settles, paper vs dark comparison); the
rings are the same family. Existing suites cover the rules: `loot_test`, `item_compare_test`, `pack_test`, `body_ring_test`, `weapon_upgrade_test`, `merchant_smoke_test`,
`click_claim_test`, `hud_wheel_test`, `inventory_flow_test`.

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
