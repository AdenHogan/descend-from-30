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
| Backpack | **B** | I | D-pad up | |
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

`scripts/touch_overlay.gd` (a child of the HUD) draws a fixed thumb-stick bottom-left, **HIT / USE / PUSH / RUN / DUCK** bottom-right,
**FORCE / LISTEN / MODE / PACK / ITEM** up the right edge, **PAUSE / JOURNAL** top-left. Each is a real Control in
`hud_widget_extra`, so `HUD.pointer_over_widget` is true over it (a tap on a button is never a click on the world). They press
`InputEventAction`s, so `_input` handlers and polling both see them; multi-touch works (walk + hit). The stick sends analog
`move_left/right` (a flick up / down is `move_up/down`).
Taps anywhere else are ordinary clicks (`emulate_mouse_from_touch`): tap the floor to walk, a node to scavenge, a zombie to hit.
Shown when a touchscreen is in use (`SettingsManager.touch_ui_wanted`: last device = touch, or Settings → "Always on"), hidden on keyboard / pad;
hiding or pausing **lets go of everything held**. `project.godot`: landscape (`window/handheld/orientation=0`), `quit_on_go_back=false`.
**Not tested on a device** — see "What isn't verified".

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
`InputMap`, the real player in a real corridor. **No physical controller, no phone, no APK** was involved. Still open for an in-hand
check: stick feel and dead-zones, the layout of the touch buttons on a real screen (positions are a first guess for a 16:9 landscape
phone — render them with `tools/scene_capture`), the Android export itself (Godot's Android export template, a keystore, the
`gl_compatibility` renderer on a device, performance on a low-end phone), haptics (none yet), and whether `emulate_mouse_from_touch`
events really carry device −1 on every Android build (the device tracker relies on it to tell a tap from a mouse).
Not built: gyro / aim assist (the game has no aiming), pad rumble, a pinch-to-zoom, a left-handed touch layout, per-button touch scaling, on-screen
pad glyph art (labels are text), a "hold to sprint with the stick rim" shortcut.
