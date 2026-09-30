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

# HANDWRITING (owner round 29: "needs more work to look better and more varied rather than all on the same
# line"): a scrawl isn't typeset. Each word is drawn on its own — a little off the baseline and tilted a
# touch, seeded off the text so it never shuffles — with spatter flecks, and optionally an ARROW (scratched
# in blood, pointing at what the words are about) and a SMEAR (the hand dragged on after the last word).
# The node's own `rotation` tilts the whole block; the scene places each hint at its own height and size.
@export_enum("none", "down", "right", "left") var arrow: String = "none":
	set(v):
		arrow = v
		queue_redraw()
@export var smear: bool = false:
	set(v):
		smear = v
		queue_redraw()
@export_range(0.0, 1.0) var scrawl: float = 1.0:     # how unsteady the hand is (0 = typeset)
	set(v):
		scrawl = v
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
	var block_w := 0.0
	for li in lines.size():
		var line: String = lines[li]
		if line == "":
			continue
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x / SS
		block_w = maxf(block_w, w)
		var top := Vector2(-w * 0.5, li * font_size * LINE_GAP)   # centred on the node
		# the hand drifts along the line: each line starts a little off the last
		top.x += (rng.randf() - 0.5) * font_size * 0.5 * scrawl
		top.y += (rng.randf() - 0.5) * font_size * 0.25 * scrawl
		var x_cursor := 0.0
		var words := line.split(" ")
		var last_end := top
		for wi in words.size():
			var word: String = words[wi]
			var ww: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x / SS
			if word != "":
				var jy := (rng.randf() - 0.5) * font_size * 0.32 * scrawl
				var tilt := (rng.randf() - 0.5) * 0.14 * scrawl
				var origin := Vector2(top.x + x_cursor, top.y + jy)
				# Rasterise big, draw scaled back down: sharp at the camera's zoom.
				draw_set_transform(origin, tilt, Vector2(1.0 / SS, 1.0 / SS))
				draw_string_outline(font, Vector2(0, big), word, HORIZONTAL_ALIGNMENT_LEFT, -1, big, outline, BLOOD_DARK)
				draw_string(font, Vector2(0, big), word, HORIZONTAL_ALIGNMENT_LEFT, -1, big, BLOOD)
				draw_set_transform(Vector2.ZERO)
				last_end = origin + Vector2(ww, 0.0)
			x_cursor += ww + font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x / SS
		# Drips fall from just under the letters; seeded off the text so they stay put.
		var count := int(maxf(1.0, w / 30.0) * drip_density)
		var base_y: float = top.y + font_size + 1.0
		for i in range(count):
			var x: float = top.x + rng.randf() * w
			var length := rng.randf_range(4.0, 14.0) if rng.randf() < 0.35 else rng.randf_range(2.0, 6.0)
			var wd := rng.randf_range(0.8, 1.6)
			draw_line(Vector2(x, base_y), Vector2(x, base_y + length), DRIP, wd)
			draw_circle(Vector2(x, base_y + length), wd * 0.8, DRIP)
		# flecks flung off the brush
		for i in range(int(1.0 + w / 26.0 * scrawl)):
			var fp := Vector2(top.x + rng.randf() * w, top.y + rng.randf_range(-0.4, 1.3) * font_size)
			draw_circle(fp, rng.randf_range(0.35, 0.8), DRIP)
		if smear and li == lines.size() - 1:
			# the hand dragged on past the last word: a tapering streak, dark at the start
			var sy := last_end.y + font_size * 0.55
			for k in range(6):
				var t := float(k) / 5.0
				var a := lerpf(0.55, 0.05, t)
				draw_line(Vector2(last_end.x + 2.0 + t * font_size * 2.2, sy + t * 1.6 + rng.randf() * 0.6),
					Vector2(last_end.x + 4.0 + t * font_size * 2.2 + font_size * 0.6, sy + t * 1.8),
					Color(BLOOD.r, BLOOD.g, BLOOD.b, a), maxf(1.0, font_size * 0.3 * (1.0 - t * 0.7)))
	if arrow != "none":
		_draw_arrow(block_w, lines.size(), rng)


# A scratched arrow under / beside the block: three strokes (shaft + two barbs), a bit uneven, dripping.
func _draw_arrow(block_w: float, line_count: int, rng: RandomNumberGenerator) -> void:
	var fs := float(font_size)
	var reach := fs * 3.0
	var start: Vector2
	var dir: Vector2
	match arrow:
		"down":
			start = Vector2((rng.randf() - 0.5) * fs, line_count * fs * LINE_GAP + fs * 0.4)
			dir = Vector2(0.06, 1.0)
		"right":
			start = Vector2(block_w * 0.5 + fs * 0.7, fs * 0.5)
			dir = Vector2(1.0, 0.05)
		_:
			start = Vector2(-block_w * 0.5 - fs * 0.7, fs * 0.5)
			dir = Vector2(-1.0, 0.05)
	dir = dir.normalized()
	var tip := start + dir * reach
	var wd := maxf(1.0, fs * 0.22)
	draw_line(start, tip, BLOOD_DARK, wd + 1.0)
	draw_line(start, tip, BLOOD, wd)
	var perp := Vector2(-dir.y, dir.x)
	for side in [-1.0, 1.0]:
		var barb: Vector2 = tip - dir * fs * 0.9 + perp * side * fs * 0.6
		draw_line(tip, barb, BLOOD_DARK, wd + 1.0)
		draw_line(tip, barb, BLOOD, wd)
	draw_line(tip, tip + Vector2(0.0, rng.randf_range(3.0, 7.0)), DRIP, 1.0)   # it dripped
