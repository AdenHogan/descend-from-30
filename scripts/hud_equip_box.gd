extends Control

# THE IN-HAND BOX (owner round 27: "I don't like the text hammer and 10/10 uses. This can be an actual item
# box to the right of the player name / stamina bar / mode text… the icon of the item there that is equipped
# and the durability can be the outline of the box that goes down and depletes until broken — the only 10/10
# numbers should be when the player has bullets in their gun"). A pure VIEW: the HUD feeds it the equipped
# item through `set_item`. The outline is the durability gauge — a ring round the box that drains clockwise
# from the top as the item wears (green → amber → red) until it is empty = BROKEN. Items with nothing to wear
# out (a bandage, a key) keep a full calm outline; empty-handed shows the bare box. A gun carries a small
# "rounds/magazine" badge on the box — the ONLY number this box ever shows.
# Three shapes to choose from (`style`): "square", "rounded" (default) and "circle".

const STYLES := ["square", "rounded", "circle"]
const SIZE := 76.0
const RING_W := 4.0
const ICON_PX := 56.0
const INK := Color(0.93, 0.89, 0.82)
const PLATE := Color(0.06, 0.06, 0.08, 0.72)
const TRACK := Color(0.30, 0.28, 0.26, 0.55)
const STEEL := Color(0.62, 0.60, 0.55, 0.85)
const GOOD := Color(0.42, 0.85, 0.42)
const WARN := Color(0.95, 0.72, 0.22)
const BAD := Color(0.92, 0.30, 0.26)

var style: String = "rounded"
var icon: Texture2D = null
## Fraction of durability left, 0..1 — or -1 when the item doesn't wear (a calm full outline).
var fraction: float = -1.0
var broken: bool = false
var has_item: bool = false
## "10/10" for a gun's magazine; "" for everything else (no other numbers, ever).
var ammo_text: String = ""
var _t: float = 0.0
var _drawn_frac: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE      # a HUD readout: clicks fall through to the world
	process_mode = Node.PROCESS_MODE_ALWAYS          # keeps easing / pulsing under a teaching pause too
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_style(s: String) -> void:
	style = s if s in STYLES else "rounded"
	queue_redraw()


func set_item(tex: Texture2D, frac: float, is_broken: bool, ammo: String) -> void:
	has_item = tex != null
	icon = tex
	fraction = frac
	broken = is_broken
	ammo_text = ammo
	if _drawn_frac < 0.0 or not has_item:
		_drawn_frac = maxf(frac, 0.0)          # snap when the item changes; ease as it wears
	queue_redraw()


func clear_item() -> void:
	icon = null
	has_item = false
	fraction = -1.0
	broken = false
	ammo_text = ""
	_drawn_frac = -1.0
	queue_redraw()


func ring_colour(f: float) -> Color:
	if f > 0.5:
		return GOOD
	if f > 0.25:
		return WARN
	return BAD


func _process(delta: float) -> void:
	_t += delta
	if fraction >= 0.0:
		_drawn_frac = move_toward(_drawn_frac, fraction, delta * 1.6)      # the outline drains, it doesn't jump
	if broken or (fraction >= 0.0 and fraction <= 0.25):
		queue_redraw()                                                      # the low / broken pulse
	elif absf(_drawn_frac - fraction) > 0.001 and fraction >= 0.0:
		queue_redraw()


## The box outline as a closed loop starting at the TOP-CENTRE and running clockwise.
func outline_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := Vector2(SIZE, SIZE) * 0.5
	var h: float = SIZE * 0.5 - RING_W * 0.5
	if style == "circle":
		var n := 72
		for i in range(n + 1):
			var a: float = -PI * 0.5 + TAU * float(i) / float(n)
			pts.append(c + Vector2(cos(a), sin(a)) * h)
		return pts
	var r: float = 0.0 if style == "square" else 14.0
	# top-centre → right along the top, then round the corners clockwise
	pts.append(c + Vector2(0, -h))
	var corners := [Vector2(h, -h), Vector2(h, h), Vector2(-h, h), Vector2(-h, -h)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in range(4):
		var cor: Vector2 = corners[k]
		var inward := Vector2(-signf(cor.x), -signf(cor.y)) * r
		var ctr: Vector2 = c + cor + inward
		if r <= 0.0:
			pts.append(c + cor)
		else:
			var a0: float = starts[k]
			for i in range(7):
				var a: float = a0 + (PI * 0.5) * float(i) / 6.0
				pts.append(ctr + Vector2(cos(a), sin(a)) * r)
	pts.append(c + Vector2(0, -h))
	return pts


## The first `frac` of a polyline's length.
static func partial(pts: PackedVector2Array, frac: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2 or frac <= 0.0:
		return out
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	var want: float = total * clampf(frac, 0.0, 1.0)
	var run := 0.0
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var seg: float = pts[i].distance_to(pts[i + 1])
		if run + seg >= want:
			out.append(pts[i].lerp(pts[i + 1], (want - run) / maxf(seg, 0.0001)))
			return out
		out.append(pts[i + 1])
		run += seg
	return out


func _draw() -> void:
	var loop := outline_points()
	# plate
	var inset: float = RING_W
	if style == "circle":
		draw_circle(Vector2(SIZE, SIZE) * 0.5, SIZE * 0.5 - inset * 0.5, PLATE)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PLATE
		var rr: int = 0 if style == "square" else 14
		sb.set_corner_radius_all(rr)
		draw_style_box(sb, Rect2(Vector2.ONE * (RING_W * 0.5), Vector2.ONE * (SIZE - RING_W)))
	# the outline: a dim track, then the live part of it
	draw_polyline(loop, TRACK, RING_W, true)
	if not has_item:
		pass
	elif broken:
		var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
		draw_polyline(loop, Color(BAD.r, BAD.g, BAD.b, 0.25 + 0.35 * pulse), RING_W, true)
	elif fraction < 0.0:
		draw_polyline(loop, STEEL, RING_W - 1.0, true)         # nothing to wear out: a calm, full outline
	else:
		var f: float = clampf(_drawn_frac, 0.0, 1.0)
		var col: Color = ring_colour(f)
		if f <= 0.25:
			col = col.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_t * 6.0)))
		var live := partial(loop, f)
		if live.size() >= 2:
			draw_polyline(live, col, RING_W, true)
	# the item
	if icon != null:
		var tint: Color = Color(0.55, 0.32, 0.32, 0.85) if broken else Color(1, 1, 1)
		var o: Vector2 = (Vector2(SIZE, SIZE) - Vector2(ICON_PX, ICON_PX)) * 0.5
		draw_texture_rect(icon, Rect2(o, Vector2(ICON_PX, ICON_PX)), false, tint)
	# a gun's rounds — the only number this box shows
	if ammo_text != "":
		var font: Font = get_theme_default_font()
		var fs := 13
		var tw: float = font.get_string_size(ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pill := Rect2(Vector2(SIZE - tw - 14.0, SIZE - 20.0), Vector2(tw + 10.0, 18.0))
		draw_rect(pill, Color(0.05, 0.05, 0.07, 0.92))
		draw_rect(pill, STEEL, false, 1.0)
		draw_string(font, pill.position + Vector2(5.0, 13.5), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
