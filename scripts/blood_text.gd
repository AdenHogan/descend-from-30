@tool
extends Node2D
class_name BloodText

# Diegetic tutorial text scrawled in blood on the walls (Floor 30, first run).
# @tool so it renders live in the editor — drop a BloodText node into a scene,
# type the message and set the size in the Inspector, and drag it exactly
# where you want it on the wall. Draws the text + procedural drips itself (no
# child nodes), so what you see in the editor is what ships.
#
# - MULTI-LINE: one node per hint; put line breaks in `text` (centred on the node).
# - LIVE KEYS: write {action} (e.g. {sprint}, {interact}, {attack}) and it shows the
#   player's CURRENT binding for that action — so a rebound key never leaves the wall
#   lying. {move} = the two movement keys.
# - CRISP: the camera zooms the corridor ~2.75×, and a 6px font drawn in world space was
#   rasterised at 6px then blown up — mushy letters under a fat outline ("hear" read
#   "hoar"). It's drawn SUPERSAMPLED (rasterised at SS× and scaled back down) with a thin
#   outline, so it stays sharp at game zoom.

const BLOOD = Color(0.60, 0.06, 0.05, 1.0)
const BLOOD_DARK = Color(0.16, 0.01, 0.01, 0.95)
const DRIP = Color(0.46, 0.03, 0.02, 0.9)
const SS := 4.0                 # supersample factor
const LINE_GAP := 1.35          # line height, × font size

@export_multiline var text: String = "THEY ARE HERE":
	set(v):
		text = v
		queue_redraw()
@export var font_size: int = 22:
	set(v):
		font_size = max(1, v)
		queue_redraw()
@export_range(0.0, 1.0) var drip_density: float = 1.0:
	set(v):
		drip_density = v
		queue_redraw()

var _font: Font = null


func _ready() -> void:
	z_index = 1  # actor/foreground scrawl sits above the wall backdrop
	queue_redraw()


func _get_font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/PixelOperator8-Bold.ttf")
	return _font


# The text as the player will read it: {action} → that action's current key.
func resolved_text() -> String:
	var out := text
	if out.find("{") == -1:
		return out
	if out.contains("{move}"):
		out = out.replace("{move}", "%s %s" % [key_for("move_left"), key_for("move_right")])
	var guard := 0
	while out.find("{") != -1 and guard < 16:
		guard += 1
		var a := out.find("{")
		var b := out.find("}", a)
		if b == -1:
			break
		var action := out.substr(a + 1, b - a - 1)
		out = out.substr(0, a) + key_for(action) + out.substr(b + 1)
	return out


# The shortest readable label among an action's bindings (A beats Left, RMB beats
# "Mouse Right") — wall space is tight. Falls back to the action name in the editor.
static func key_for(action: String) -> String:
	if not InputMap.has_action(action):
		return action.to_upper()
	var best := ""
	for ev in InputMap.action_get_events(action):
		var s := _short_label(ev)
		if s != "" and (best == "" or s.length() < best.length()):
			best = s
	return best if best != "" else action.to_upper()


static func _short_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_XBUTTON1: return "M4"
			MOUSE_BUTTON_XBUTTON2: return "M5"
	return ""


# World-space size of the drawn block (for layout checks / tests).
func block_size() -> Vector2:
	var font = _get_font()
	if font == null:
		return Vector2.ZERO
	var lines := resolved_text().split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size * SS)).x / SS)
	return Vector2(w, lines.size() * font_size * LINE_GAP)


func _draw() -> void:
	var font = _get_font()
	var shown := resolved_text()
	if font == null or shown == "":
		return
	var lines := shown.split("\n")
	var big := int(round(font_size * SS))
	var outline := int(maxf(2.0, font_size * 0.28 * SS))
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(text)
	for li in lines.size():
		var line: String = lines[li]
		if line == "":
			continue
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x / SS
		var top := Vector2(-w * 0.5, li * font_size * LINE_GAP)   # centred on the node
		# Rasterise big, draw scaled back down: sharp at the camera's zoom.
		draw_set_transform(top, 0.0, Vector2(1.0 / SS, 1.0 / SS))
		draw_string_outline(font, Vector2(0, big), line, HORIZONTAL_ALIGNMENT_LEFT, -1, big, outline, BLOOD_DARK)
		draw_string(font, Vector2(0, big), line, HORIZONTAL_ALIGNMENT_LEFT, -1, big, BLOOD)
		draw_set_transform(Vector2.ZERO)
		# Drips fall from just under the letters; seeded off the text so they stay put.
		var count := int(maxf(1.0, w / 30.0) * drip_density)
		var base_y: float = top.y + font_size + 1.0
		for i in range(count):
			var x: float = top.x + rng.randf() * w
			var length := rng.randf_range(4.0, 14.0) if rng.randf() < 0.35 else rng.randf_range(2.0, 6.0)
			var wd := rng.randf_range(0.8, 1.6)
			draw_line(Vector2(x, base_y), Vector2(x, base_y + length), DRIP, wd)
			draw_circle(Vector2(x, base_y + length), wd * 0.8, DRIP)
