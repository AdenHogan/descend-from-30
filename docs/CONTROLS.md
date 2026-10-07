# Controls — keyboard + mouse, gamepad, touch

**BUILT v1** (owner round 36: "optimise the control scheme so it will be intuitive to anyone used to mouse and
keyboard games … controller support … touch control if we ship on android"). One table (`scripts/input_scheme.gd`)
builds every input; `SettingsManager` turns it + the player's changes into the `InputMap`; the touch overlay
presses the same actions. No game system knows which device is in use except the prompts.

## The scheme

Defaults follow what most keyboard-and-mouse and twin-stick games already teach. Every action has **four slots**:
keyboard/mouse, a keyboard/mouse alternate, a gamepad button, a gamepad alternate.

| Action | Keyboard / mouse | Alternate | Gamepad | Notes |
|---|---|---|---|---|
| Move | **A / D** | ← → | left stick | analog: a gentle push walks slower |
| Up / step out / back plane | **W** | ↑ | stick up (flick) | balcony, banister, step up to furniture |
| Down / step back | **S** | ↓ | stick down (flick) | |
| Sprint (hold) | **Shift** | | **LT** | |
| Crouch | **C** | Ctrl | L3 | |
| Attack | **Left-click** | Space | **X**, RT | smart-click: a click on empty floor still walks, a click on a zombie swings |
| Push | **Right-click** | V | **B** | |
| Combat / Scavenge | **F** | | **Y** | |
| Listen | **R** | | D-pad left | |
| Rest | **T** | | R3 | |
| Interact / Enter | **E** | | **A** | |
| Force / Barricade | **X** | | D-pad right | |
| Backpack | **B** | I | D-pad up | opens from anywhere you can stand — up at set-back furniture and out on a balcony too (the bag is drawn at the plane's scale; S stands you up first, the next S steps down) |
| Use item | **Q** | | D-pad down | |
| Previous / next item | **mouse wheel** | | **LB / RB** | empty hands → item 1 … last → empty hands. With 2+ scavenge nodes in reach the wheel / LB / RB pick between nodes instead (Tab still does too) |
| Item slots 1–5 | **1–5** | | | |
| Journal | **J** | M | **View / Back** | |
| Pause | **Esc** | | **Menu / Start** | Esc always pauses, whatever `pause` is bound to |

Menus: A accepts, B goes back, LB / RB turn the journal's bookmarks (`ui_page_up/down`), the stick / D-pad move the
focus, the Android Back key is Back. **B only ever closes** (it is push in play), so it can never open the pause menu.

**The one deliberate change from before:** attack used to default to Space alone so the left button stayed free for
click-to-move. It is now **Left-click + Space** (plus X / RT on a pad). Click-to-move survives because the left button is
*smart*: with a target under the cursor it attacks; on empty ground (or in scavenge mode, or over the HUD) it walks / scavenges
exactly as before. A fire extinguisher / molotov is used by the key or pad button, never by a pointer click (a click on the floor
must stay a walk). Players who preferred the old way: Settings → Controls → Attack → clear the Left-click slot.

## Gamepad specifics

- **Pack ring**: kneel (D-pad up), then the **right stick** points at a wedge (it stays chosen when the stick returns to the
  middle), **A** equips, **X** opens the item's menu (right stick up/down steps rows, A runs one), **B** puts the pack away.
  A does not also stand the player up while a wedge is chosen.
- **Search panel**: A takes, B leaves.
- **Pause menu / title / settings**: the first button is focused when a pad is used (`SettingsManager.ensure_menu_focus`).
- **Button faces** follow the controller: auto-detected from the pad's name (Xbox / PlayStation / Nintendo), or forced in
  Settings. Nintendo layouts swap A/B and X/Y by position, as the glyphs do.
- Triggers are axes (`a:4+` LT, `a:5+` RT) and bind like buttons. Stick drift under half travel never counts as a press and
  never switches the game over to the pad.

## Touch (Android first)

`scripts/touch_overlay.gd` (a child of the HUD) draws a fixed thumb-stick bottom-left and a deliberately QUIET right hand
(owner round 36b, first phone playtest: "the button set up is really unintuitive on the right hand side… too much going on"; round 36d: no
duplicated controls; **round 36f, second phone playtest: PUSH was dead, scavenging showed only PUSH + DUCK, and the layout needed a colour-coded
stance button — rebuilt below**). Right hand: a **stance pill** (green SCAVENGE / red COMBAT, "TAP TO SWITCH") above ONE big **contextual** button, with a
smaller **PUSH** to its LEFT in combat — close enough that the right thumb slides between them, clear of it so they never overlap. **PAUSE** top-right.
Context buttons (**USE** in combat, **LISTEN**, **FORCE**) stack up the right edge only while a world prompt offers them. DUCK is gone (it is the stick),
and so is the journal button (the framed avatar top-left IS the journal button). That is all that is ever on screen in plain play.
- **The stance pill** (`Btn_mode_toggle`, a pill-shaped `touch_stick.gd` widget) shows the CURRENT stance in its colour (`COL_SCAV` green / `COL_COMBAT` red)
  and says "TAP TO SWITCH"; it presses `mode_toggle`. The big button and PUSH wear the same colour, so in a tight spot one glance says which stance you are
  in. The HUD's text SCAVENGE / COMBAT pill is hidden under touch (this one replaces it).
- **The big button follows the stance, then the hand** (`touch_overlay._primary_ctx`): **SCAVENGING it is USE** (`interact` — open / search / take; nodes and doors can
  also just be tapped in the world). **In COMBAT** it follows `HUD.hand_context()` (label + the action it presses): a weapon is **HIT** (a gun **SHOOT**);
  a first aid kit **HEAL**, an extinguisher **SPRAY**, a can / bottle / molotov **THROW**, a stamina boost **DRINK**, a toolbox **FIX** — those press `item_use`;
  empty hands (or a key / junk / a worn-out thing) = **HIT**, the bare-handed swing. The press lets go of the action it sent even if the hand changes mid-press.
- **Tapping the in-hand box uses what is in hand** (`HUD.use_equipped`, also a click on PC): a usable item is used, a gun reloads, a melee weapon is
  drawn when scavenging, and **empty hands open the backpack**. The box is a registered HUD widget, so the tap never also walks. (In scavenge this is how
  you heal / draw — the big button is USE.)
- **PUSH (combat only; gone while scavenging).** The 36f bug: a touch press arrives as an *action* but `player._is_mouse_over_hud()` asks where the (emulated)
  mouse is — on a phone that is the PUSH button itself, so the HUD gate ate the press. `Player.push_blocked_by_hud(device, over_hud)` now applies the gate to
  `kbm` only. Headless can't see it (`_is_mouse_over_hud` is false there), so `controls_test` pins the pure function.
- **DUCK is the stick** (`_duck_edge`): pushing it DOWN past 0.6 of its travel crouches, pushing it back UP past 0.6 stands — only the *entry* into a zone ducks
  or stands, so sideways walking while ducked works and **letting go of the stick never stands you up**. It does nothing on the back / balcony planes or while
  at the pack, where the same push already means "step down / get up" (`move_down` is still sent). The stick draws a chevron at each end that lights for the state.
- **Run is a deliberate push PAST the rim** (owner: "you can run way too easily"): the walk eases from the dead zone to the rim (full walk at 1.0 of the
  stick's radius); sprint holds from `STICK_SPRINT_ON` 1.3 radii (≈107 px) and lets go below `STICK_SPRINT_OFF` 1.12, read from the RAW offset
  (`stick_raw`, not clamped). A dashed ring OUTSIDE the stick marks it and lights while you run; the knob is drawn at the finger. A vertical flick never sprints.
- **Context buttons appear only when they would do something**: **USE** (combat), **LISTEN**, **FORCE** only while a world prompt next to you offers them
  (`HUD.world_prompt_mentions("[FORCE]")`). The bag is the HUD's own backpack button (no copy here).
- **The avatar rides the TOP-left** under a touchscreen (`HUD.apply_identity_layout`, re-run on `device_changed`): a smaller bust in a framed card, the name +
  stamina beside it, the in-hand box at its right — so the stick no longer sits over it and the journal (the portrait) is easy to hit.
Each is a real Control in `hud_widget_extra`, so `HUD.pointer_over_widget` is true over it (a hidden one is not) and a tap on a
button never also walks / swings in the world. They press `InputEventAction`s, so `_input` handlers and polling both see them; multi-touch
works (walk + hit). The stick sends analog `move_left/right` (a flick up / down is `move_up/down`).
**Teaching beats**: a paused STRICT beat (the shove intro, `TutorialManager.strict_action()`) keeps the overlay up showing ONLY the button that
answers it (the big one when the beat waits for the item action), pulsing — it used to vanish on every pause, which locked a phone player on "[PUSH] to shove" with nothing to press. A loose beat takes any tap.
**Push is a combat move** (it does nothing in scavenge mode, as before) — pressing it while scavenging now says so ("Can't shove while searching —
switch to combat [MODE]"), and the tutorial's shove beat first draws a still-scavenging player back to combat.
Taps anywhere else are ordinary clicks (`emulate_mouse_from_touch`): tap the floor to walk, a node to scavenge, a zombie to hit.
Shown when a touchscreen is in use (`SettingsManager.touch_ui_wanted`: last device = touch, or Settings → "Always on"), hidden on keyboard / pad;
hiding or pausing (outside a strict beat) **lets go of everything held**. `project.godot`: landscape (`window/handheld/orientation=0`), `quit_on_go_back=false`.
**Phone-tested twice by the owner** (Godot 4.7.1 Android editor, Run in the editor) — that is how the cluttered layout, the beat lock and the dead PUSH were found; rounds 36d / 36f's changes (above) are tested with synthetic touches only (`controls_test._test_touch_layout`).

## Prompts name the right button

`SettingsManager.last_device` (`kbm` | `pad` | `touch`) follows the last real input (a key / mouse button / mouse move > 3 px → kbm; a pad
button or a stick past half → pad; a touch → touch). Prompts are written with the *action* in braces — `"[{interact}] Enter"` — and
`SettingsManager.localize` makes it `[E]`, `[A]`, `[Cross]` or `[USE]`. `HUD.show_world_prompt / show_dialogue / show_feedback` run every
line through it, so a prompt reads right the moment the player picks up a pad. Tutorial lines use `TutorialManager.key(action)`
(= `SettingsManager.action_text`), the in-hand / pack hints `HUD.action_key_name`, and the wall scrawls `BloodText.key_for` (the short keyboard
key on a keyboard, the pad button on a pad). "Press any key" beats accept a key, mouse button or pad button (`SettingsManager.is_any_press`).
Never write a literal `[E]` into a prompt again.

## Rebinding (Settings → Controls)

Every action in four columns; click (or A on) a slot, press the key / mouse button (wheel and side buttons included) / pad button / trigger.
**Del** clears, **Esc** cancels. A button another action already holds on the same kind of device is **swapped** (that action takes the slot's
old button) and the screen says so; essentials (move left / right, interact, attack, pause) can't be left with no binding on a kind of device.
Options: controller button style (auto / Xbox / PlayStation / Nintendo) and touch controls (auto / on / off). `keybinds.cfg` (through
`WorldState.data_dir()`) saves **only what differs from the defaults** (`[binds2]`, four strings per action) so a later better default
reaches everyone who never changed it; the old v1 file is migrated (a changed binding becomes the first keyboard slot; one equal to the old
default is dropped).

## Where the pieces are

- `scripts/input_scheme.gd` — the table, spec strings (`k:E`, `m:1`, `j:0`, `a:4+`), labels per controller family.
- `scripts/settings_manager.gd` — InputMap build, `rebind_slot` (swap rules), save / load / v1 migration, device tracking, `localize`, `is_any_press`, menu focus.
- `scripts/settings_menu.gd` — the screen. `scripts/game.gd` `_input` — pause / back / journal. `scripts/pack_wheel.gd` — the pad ring. `HUD.cycle_item`.
- `scripts/touch_overlay.gd`, `scripts/touch_stick.gd` — touch.
- `tests/controls_test.gd` (62nd suite) + `tests/settings_test.gd`. The controls suite reads every script for polled action names and fails on one that
  isn't in the InputMap (a misspelt action is a silent no-op in Godot).

## What isn't verified (be straight about it)

Everything above was tested with **synthetic events** in headless Godot: pad buttons / axes / touches pushed into the viewport, the real
`InputMap`, the real player in a real corridor. **No physical controller** was involved; the touch controls got ONE real phone session (the owner, Android editor Run), which found the layout clutter and the shove-beat lock fixed above — the exported APK is still untried. Still open for an in-hand
check: stick feel and dead-zones, the layout of the touch buttons on a real screen (positions are a first guess for a 16:9 landscape
phone — render them with `tools/scene_capture`), the Android export itself (Godot's Android export template, a keystore, the
`gl_compatibility` renderer on a device, performance on a low-end phone), haptics (none yet), and whether `emulate_mouse_from_touch`
events really carry device −1 on every Android build (the device tracker relies on it to tell a tap from a mouse).
Not built: gyro / aim assist (the game has no aiming), pad rumble, a pinch-to-zoom, a left-handed touch layout, per-button touch scaling, on-screen
pad glyph art (labels are text).
