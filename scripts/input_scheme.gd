extends RefCounted

# THE control scheme — the ONE table every input in the game is built from (docs/CONTROLS.md).
#
# Each action has FOUR binding slots:  kb1 kb2  (keyboard + mouse)   pad1 pad2  (gamepad).
# Touch is not a slot: the on-screen buttons just press the same actions (touch_overlay.gd).
# SettingsManager turns these defaults + the player's changes into the InputMap.
#
# A binding is a short string, so it saves as readable text and a test can say what it means:
#   "k:E"    keyboard key (by position, so WASD stays WASD on an AZERTY board)
#   "m:1"    mouse button (1 left, 2 right, 3 middle, 4 wheel up, 5 wheel down, 8 / 9 side)
#   "j:0"    gamepad button (JoyButton: 0 A, 1 B, 2 X, 3 Y, 4 Back, 6 Start, 7 L3, 8 R3, 9 LB, 10 RB, 11-14 D-pad)
#   "a:4+"   gamepad axis + direction (0/1 left stick X/Y, 2/3 right stick, 4 LT, 5 RT)
# "" = empty slot.
#
# The defaults follow what most keyboard-and-mouse and twin-stick games already teach: WASD + mouse,
# left-click to attack, right-click for the secondary, E to interact, Shift to sprint, C / Ctrl to
# crouch, 1-5 and the wheel for items, I / B for the bag, J / M for the journal, Esc to pause —
# and on a pad: left stick moves, A interacts, X / RT attacks, B shoves, Y swaps stance, LB / RB
# cycle items, LT sprints, the D-pad is the quick-action cross, Back is the journal, Start pauses.

const SLOTS := ["kb1", "kb2", "pad1", "pad2"]
const SLOT_TITLES := {"kb1": "Keyboard / Mouse", "kb2": "Alternate", "pad1": "Gamepad", "pad2": "Gamepad alt"}

# Menu order. `touch` = the label on the on-screen button (touch_overlay.gd lays them out).
const GROUPS := ["Movement", "Combat", "Interact", "Items", "Menus"]

const ACTIONS := [
	{"id": "move_left", "label": "Move left", "group": "Movement", "kb": ["k:A", "k:Left"], "pad": ["a:0-", ""], "dead": 0.25},
	{"id": "move_right", "label": "Move right", "group": "Movement", "kb": ["k:D", "k:Right"], "pad": ["a:0+", ""], "dead": 0.25},
	{"id": "move_up", "label": "Up / step out / back plane", "group": "Movement", "kb": ["k:W", "k:Up"], "pad": ["a:1-", ""], "dead": 0.45},
	{"id": "move_down", "label": "Down / step back", "group": "Movement", "kb": ["k:S", "k:Down"], "pad": ["a:1+", ""], "dead": 0.45},
	{"id": "sprint", "label": "Sprint (hold)", "group": "Movement", "kb": ["k:Shift", ""], "pad": ["a:4+", ""], "dead": 0.5, "touch": "RUN"},
	{"id": "crouch_toggle", "label": "Crouch", "group": "Movement", "kb": ["k:C", "k:Ctrl"], "pad": ["j:7", ""], "touch": "DUCK"},

	{"id": "attack", "label": "Attack", "group": "Combat", "kb": ["m:1", "k:Space"], "pad": ["j:2", "a:5+"], "dead": 0.5, "touch": "HIT"},
	{"id": "push", "label": "Push", "group": "Combat", "kb": ["m:2", "k:V"], "pad": ["j:1", ""], "touch": "PUSH"},
	{"id": "mode_toggle", "label": "Combat / Scavenge", "group": "Combat", "kb": ["k:F", ""], "pad": ["j:3", ""], "touch": "MODE"},
	{"id": "listen", "label": "Listen", "group": "Combat", "kb": ["k:R", ""], "pad": ["j:13", ""], "touch": "LISTEN"},
	{"id": "rest", "label": "Rest", "group": "Combat", "kb": ["k:T", ""], "pad": ["j:8", ""]},

	{"id": "interact", "label": "Interact / Enter", "group": "Interact", "kb": ["k:E", ""], "pad": ["j:0", ""], "touch": "USE"},
	{"id": "item_context", "label": "Force / Barricade", "group": "Interact", "kb": ["k:X", ""], "pad": ["j:14", ""], "touch": "FORCE"},

	{"id": "open_pack", "label": "Backpack", "group": "Items", "kb": ["k:B", "k:I"], "pad": ["j:11", ""], "touch": "PACK"},
	{"id": "item_use", "label": "Use item", "group": "Items", "kb": ["k:Q", ""], "pad": ["j:12", ""], "touch": "ITEM"},
	{"id": "item_prev", "label": "Previous item", "group": "Items", "kb": ["m:4", ""], "pad": ["j:9", ""]},
	{"id": "item_next", "label": "Next item", "group": "Items", "kb": ["m:5", ""], "pad": ["j:10", ""]},
	{"id": "item_slot_1", "label": "Item slot 1", "group": "Items", "kb": ["k:1", ""], "pad": ["", ""]},
	{"id": "item_slot_2", "label": "Item slot 2", "group": "Items", "kb": ["k:2", ""], "pad": ["", ""]},
	{"id": "item_slot_3", "label": "Item slot 3", "group": "Items", "kb": ["k:3", ""], "pad": ["", ""]},
	{"id": "item_slot_4", "label": "Item slot 4", "group": "Items", "kb": ["k:4", ""], "pad": ["", ""]},
	{"id": "item_slot_5", "label": "Item slot 5", "group": "Items", "kb": ["k:5", ""], "pad": ["", ""]},

	{"id": "open_journal", "label": "Journal", "group": "Menus", "kb": ["k:J", "k:M"], "pad": ["j:4", ""], "touch": "JOURNAL"},
	{"id": "pause", "label": "Pause", "group": "Menus", "kb": ["k:Escape", ""], "pad": ["j:6", ""], "touch": "PAUSE"},
]

# Actions the game cannot be played without: a rebind that would leave one with NO binding on a
# device family is refused (it swaps instead — see SettingsManager.rebind_slot).
const ESSENTIAL := ["move_left", "move_right", "interact", "attack", "pause"]

# What the pad's menus do (added to Godot's ui_* actions by SettingsManager; the keyboard side of
# those is Godot's own and is not remappable). A / B follow the platform's accept / back.
const UI_PAD := {
	"ui_accept": ["j:0"],
	"ui_cancel": ["j:1"],
	"ui_page_up": ["j:9"],          # LB / RB turn the journal's pages / switch menu tabs
	"ui_page_down": ["j:10"],
}

# The phone's own Back button counts as "back" too (Android sends it as a key, not as ui_cancel).
const UI_KEYS := {"ui_cancel": ["k:Back"]}

# Prompt words for the touch buttons, spelled the way a tutorial line would say them.
# (HUD hints on touch read "[USE]", "[HIT]"…, matching the button the player sees.)

# Names a pad button / axis prints as, per controller family. "xbox" is the default family.
const PAD_NAMES := {
	"xbox": {"j:0": "A", "j:1": "B", "j:2": "X", "j:3": "Y", "j:4": "View", "j:6": "Menu", "j:7": "L3", "j:8": "R3",
		"j:9": "LB", "j:10": "RB", "j:11": "D-pad Up", "j:12": "D-pad Down", "j:13": "D-pad Left", "j:14": "D-pad Right",
		"a:4+": "LT", "a:5+": "RT"},
	"playstation": {"j:0": "Cross", "j:1": "Circle", "j:2": "Square", "j:3": "Triangle", "j:4": "Create", "j:6": "Options",
		"j:7": "L3", "j:8": "R3", "j:9": "L1", "j:10": "R1", "j:11": "D-pad Up", "j:12": "D-pad Down", "j:13": "D-pad Left",
		"j:14": "D-pad Right", "a:4+": "L2", "a:5+": "R2"},
	"nintendo": {"j:0": "B", "j:1": "A", "j:2": "Y", "j:3": "X", "j:4": "Minus", "j:6": "Plus", "j:7": "L3", "j:8": "R3",
		"j:9": "L", "j:10": "R", "j:11": "D-pad Up", "j:12": "D-pad Down", "j:13": "D-pad Left", "j:14": "D-pad Right",
		"a:4+": "ZL", "a:5+": "ZR"},
}
const STICK_NAMES := {"a:0-": "Left stick left", "a:0+": "Left stick right", "a:1-": "Left stick up", "a:1+": "Left stick down",
	"a:2-": "Right stick left", "a:2+": "Right stick right", "a:3-": "Right stick up", "a:3+": "Right stick down"}
const MOUSE_NAMES := {1: "Left-click", 2: "Right-click", 3: "Middle-click", 4: "Wheel up", 5: "Wheel down", 8: "Mouse 4", 9: "Mouse 5"}


static func action_ids() -> Array:
	var out: Array = []
	for a in ACTIONS:
		out.append(a["id"])
	return out


static func entry(action: String) -> Dictionary:
	for a in ACTIONS:
		if a["id"] == action:
			return a
	return {}


## The default four-slot row for an action: [kb1, kb2, pad1, pad2].
static func defaults_for(action: String) -> Array:
	var e := entry(action)
	if e.is_empty():
		return ["", "", "", ""]
	return [e["kb"][0], e["kb"][1], e["pad"][0], e["pad"][1]]


static func slot_is_pad(slot: int) -> bool:
	return slot >= 2


# ---- spec <-> event ----------------------------------------------------------------------------

static func spec_to_event(spec: String) -> InputEvent:
	if spec.length() < 3 or spec[1] != ":":
		return null
	var body := spec.substr(2)
	match spec[0]:
		"k":
			var code := OS.find_keycode_from_string(body)
			if code == 0:
				return null
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			return ev
		"m":
			if not body.is_valid_int():
				return null
			var mb := InputEventMouseButton.new()
			mb.button_index = int(body)
			return mb
		"j":
			if not body.is_valid_int():
				return null
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(body)
			return jb
		"a":
			if body.length() != 2 or not (body[1] in ["+", "-"]) or not body[0].is_valid_int():
				return null
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(body[0])
			jm.axis_value = 1.0 if body[1] == "+" else -1.0
			return jm
	return null


static func event_to_spec(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if code == 0:
			return ""
		return "k:" + OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		return "m:%d" % ev.button_index
	if ev is InputEventJoypadButton:
		return "j:%d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "a:%d%s" % [ev.axis, "+" if ev.axis_value > 0.0 else "-"]
	return ""


## Which slot family an event belongs in: 0 = keyboard / mouse, 1 = gamepad, -1 = something we can't bind.
static func family_of(spec: String) -> int:
	if spec.begins_with("k:") or spec.begins_with("m:"):
		return 0
	if spec.begins_with("j:") or spec.begins_with("a:"):
		return 1
	return -1


## Text for a binding, e.g. "Left-click", "Space", "RT", "Cross". `style` = "xbox" / "playstation" / "nintendo".
static func spec_label(spec: String, style: String = "xbox") -> String:
	if spec == "":
		return "—"
	var fam: int = family_of(spec)
	if spec.begins_with("k:"):
		return spec.substr(2)
	if spec.begins_with("m:"):
		return MOUSE_NAMES.get(int(spec.substr(2)), "Mouse %s" % spec.substr(2))
	if fam == 1:
		var names: Dictionary = PAD_NAMES.get(style, PAD_NAMES["xbox"])
		if names.has(spec):
			return names[spec]
		return STICK_NAMES.get(spec, spec)
	return spec


## A shorter form for in-world hints and wall text ("LMB", "RMB").
static func spec_short(spec: String, style: String = "xbox") -> String:
	if spec.begins_with("m:"):
		match int(spec.substr(2)):
			1: return "LMB"
			2: return "RMB"
			3: return "MMB"
			4: return "Wheel up"
			5: return "Wheel down"
			8: return "M4"
			9: return "M5"
	return spec_label(spec, style)


## The controller family a joypad's name says it is.
static func pad_style_for(joy_name: String) -> String:
	var n := joy_name.to_lower()
	for k in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if n.contains(k):
			return "playstation"
	for k in ["nintendo", "switch", "joy-con", "pro controller"]:
		if n.contains(k):
			return "nintendo"
	return "xbox"
