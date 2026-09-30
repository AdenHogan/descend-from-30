extends Control

# THE IN-HAND BOX (owner round 27). The equipped item's icon sits in a little VIAL of dark glass holding a
# thin, smoky, semi-transparent liquid — never a solid fill, so it doesn't fight the scene — whose COLOUR is
# the item's condition: one calm colour that shifts gradually with every use, from
# green (fresh) through yellow and orange to a dark red, and a faint grey smoke once it is broken. No
# outline ring, no numbers: the only number this box ever shows is a gun's rounds ("10/10" badge). Items
# that don't wear (a bandage, a key) sit in a neutral slate; empty-handed = dark glass. The exact wear per
# item is written down in the journal's Codex tab (`item_codex.gd`).
# Three shapes (`style`): "square", "rounded" (default) and "circle". A pure VIEW: the HUD feeds it through
# `set_item`. The vial look is one canvas_item shader on the `Body` child (SDF shape + glass + tinted liquid that settles toward the walls + a bright lip + a gloss), so all three shapes share it; the icon + badge are drawn by the `Overlay` child on top.

const STYLES := ["square", "rounded", "circle"]
const SIZE := 76.0
const ICON_PX := 56.0
const INK := Color(0.93, 0.89, 0.82)
const STEEL := Color(0.62, 0.60, 0.55, 0.85)

## Condition stops, worst → best (fraction left, colour). Muted on purpose: a colour to glance at, not a siren.
const STOPS := [
	[0.00, Color(0.30, 0.08, 0.08)],
	[0.16, Color(0.52, 0.13, 0.12)],   # dark red
	[0.38, Color(0.86, 0.47, 0.17)],   # orange
	[0.60, Color(0.80, 0.68, 0.24)],   # yellow
	[1.00, Color(0.30, 0.56, 0.36)],   # green
]
const NEUTRAL := Color(0.36, 0.42, 0.50)      # an item that doesn't wear
const GLASS := Color(0.14, 0.15, 0.19)        # empty-handed
const BROKEN := Color(0.20, 0.15, 0.15)       # worn out: dull, cracked

const SHADER_CODE := """
shader_type canvas_item;
uniform int shape = 1;
uniform vec4 tint : source_color = vec4(0.3, 0.56, 0.36, 1.0);
uniform vec2 box_size = vec2(76.0, 76.0);
uniform float glow = 0.0;
uniform float density = 0.42;    // how much of the colour shows: a vial of tinted liquid, never a solid

float sdf(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - h + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * box_size;
	vec2 h = box_size * 0.5 - vec2(4.0);
	float r = (shape == 2) ? h.x : ((shape == 1) ? 16.0 : 3.0);
	float d = sdf(p, h, r);
	float a = 1.0 - smoothstep(-0.7, 0.7, d);
	float ds = sdf(p - vec2(0.0, 2.0), h, r);
	float sh = (1.0 - smoothstep(-2.0, 4.0, ds)) * 0.18 * (1.0 - a);
	vec2 grad = vec2(sdf(p + vec2(1.0, 0.0), h, r) - sdf(p - vec2(1.0, 0.0), h, r),
					 sdf(p + vec2(0.0, 1.0), h, r) - sdf(p - vec2(0.0, 1.0), h, r));
	grad = grad / max(length(grad), 0.0001);
	float depth = min(h.x, h.y);
	float edge = 1.0 - clamp(-d / (depth * 0.9), 0.0, 1.0);      // 1 at the wall of the vial, 0 in the middle
	// the dark glass
	vec3 gcol = vec3(0.05, 0.06, 0.08);
	float ga = 0.30;
	// the liquid: thin in the middle, denser toward the walls and the bottom, like colour settling in a vial
	float settle = smoothstep(-0.7, 1.0, p.y / h.y);
	float ta = clamp(density * (0.70 + 0.55 * edge + 0.35 * settle) * (1.0 + glow * 0.25), 0.0, 0.85);
	float ca = ta + ga * (1.0 - ta);
	vec3 col = (tint.rgb * ta + gcol * ga * (1.0 - ta)) / max(ca, 0.001);
	// the glass wall: a thin bright lip catching light from the top-left, a soft dark outside edge
	float lip = smoothstep(-2.2, -0.6, d) * (1.0 - smoothstep(-0.6, 0.4, d));
	float facing = clamp(0.5 - 0.5 * dot(grad, normalize(vec2(-0.55, -0.85))), 0.0, 1.0);
	col = mix(col, vec3(1.0), lip * (0.10 + 0.40 * facing));
	ca = max(ca, lip * 0.55);
	float outer = smoothstep(-0.2, 0.9, d) * a;
	col = mix(col, vec3(0.0), outer * 0.5);
	// a soft gloss high on the left, and a faint glint low on the right
	float gloss = clamp(1.0 - length((p - vec2(-h.x * 0.25, -h.y * 0.48)) / vec2(h.x * 0.55, h.y * 0.28)), 0.0, 1.0);
	col = mix(col, vec3(1.0), gloss * 0.16);
	ca = max(ca, gloss * 0.22);
	float A = a * ca + sh * (1.0 - a * ca);
	COLOR = vec4((col * a * ca) / max(A, 0.001), A);
}
"""

## Icon art isn't drawn centred in its 56x56 cell (a hammer sits low and left, a bat high): the box centres the
## icon's VISIBLE bounds instead, by a per-texture offset measured once from its alpha.
static var _icon_offsets: Dictionary = {}


static func icon_offset(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var key: int = tex.get_rid().get_id()
	if _icon_offsets.has(key):
		return _icon_offsets[key]
	var off := Vector2.ZERO
	var img: Image = tex.get_image()
	if img != null and not img.is_empty():
		var used := Rect2i()
		var first := true
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.08:
					if first:
						used = Rect2i(x, y, 1, 1)
						first = false
					else:
						used = used.expand(Vector2i(x, y))
		if not first:
			var c := Vector2(used.position) + Vector2(used.size + Vector2i.ONE) * 0.5
			off = (Vector2(img.get_size()) * 0.5 - c).round()      # whole pixels: the art stays crisp
	_icon_offsets[key] = off
	return off


var style: String = "rounded"
var icon: Texture2D = null
## Fraction of durability left, 0..1 — or -1 when the item doesn't wear (neutral).
var fraction: float = -1.0
var broken: bool = false
var has_item: bool = false
## "10/10" for a gun's magazine; "" for everything else (no other numbers, ever).
var ammo_text: String = ""
var body: ColorRect = null
var overlay: Control = null
var _mat: ShaderMaterial = null
var _t: float = 0.0
var _drawn_frac: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE      # a HUD readout: clicks fall through to the world
	process_mode = Node.PROCESS_MODE_ALWAYS          # keeps easing / pulsing under a teaching pause too
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("box_size", Vector2(SIZE, SIZE))
	body = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(SIZE, SIZE)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.material = _mat
	add_child(body)
	overlay = _Overlay.new()
	overlay.name = "Overlay"
	overlay.box = self
	overlay.size = Vector2(SIZE, SIZE)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	set_style(style)
	_apply()


func set_style(s: String) -> void:
	style = s if s in STYLES else "rounded"
	if _mat != null:
		_mat.set_shader_parameter("shape", STYLES.find(style))
	if overlay != null:
		overlay.queue_redraw()


func set_item(tex: Texture2D, frac: float, is_broken: bool, ammo: String) -> void:
	has_item = tex != null
	icon = tex
	fraction = frac
	broken = is_broken
	ammo_text = ammo
	if _drawn_frac < 0.0 or not has_item:
		_drawn_frac = maxf(frac, 0.0)          # snap when the item changes; ease as it wears
	_apply()


func clear_item() -> void:
	icon = null
	has_item = false
	fraction = -1.0
	broken = false
	ammo_text = ""
	_drawn_frac = -1.0
	_apply()


## The body colour for a condition: the gradient above for a wearing item, slate for one that doesn't wear,
## dark glass for nothing, dull grey-red for broken. THE one mapping (the codex legend uses it too).
static func tint_for(frac: float, is_broken: bool = false, item_present: bool = true) -> Color:
	if not item_present:
		return GLASS
	if is_broken:
		return BROKEN
	if frac < 0.0:
		return NEUTRAL
	var f: float = clampf(frac, 0.0, 1.0)
	for i in range(1, STOPS.size()):
		var lo: Array = STOPS[i - 1]
		var hi: Array = STOPS[i]
		if f <= float(hi[0]):
			var t: float = (f - float(lo[0])) / maxf(float(hi[0]) - float(lo[0]), 0.0001)
			return (lo[1] as Color).lerp(hi[1] as Color, t)
	return STOPS[STOPS.size() - 1][1]


## The colour the body is showing right now (what the tests read).
func current_tint() -> Color:
	return tint_for(_drawn_frac if fraction >= 0.0 else -1.0, broken, has_item)


func _apply() -> void:
	if _mat != null:
		_mat.set_shader_parameter("tint", current_tint())
		_mat.set_shader_parameter("density", 0.22 if not has_item else (0.30 if broken else 0.44))
	if overlay != null:
		overlay.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if fraction >= 0.0 and absf(_drawn_frac - fraction) > 0.001:
		_drawn_frac = move_toward(_drawn_frac, fraction, delta * 1.0)      # the colour drifts, it doesn't jump
		_apply()
	if _mat != null:
		var low: bool = has_item and not broken and fraction >= 0.0 and fraction <= 0.16
		_mat.set_shader_parameter("glow", (0.5 + 0.5 * sin(_t * 5.0)) if low else 0.0)


## The icon, a crack when broken, and a gun's rounds — drawn over the body.
class _Overlay extends Control:
	var box: Control = null

	func _draw() -> void:
		if box == null:
			return
		var sz: float = box.SIZE
		if box.icon != null:
			var tint: Color = Color(0.62, 0.50, 0.50, 0.85) if box.broken else Color(1, 1, 1)
			var o: Vector2 = (Vector2(sz, sz) - Vector2(box.ICON_PX, box.ICON_PX)) * 0.5 + box.icon_offset(box.icon)
			draw_texture_rect(box.icon, Rect2(o, Vector2(box.ICON_PX, box.ICON_PX)), false, tint)
		if box.broken and box.has_item:
			var c := Vector2(sz, sz) * 0.5
			var crack := PackedVector2Array([c + Vector2(-4, -30), c + Vector2(2, -14), c + Vector2(-5, -2), c + Vector2(6, 12), c + Vector2(1, 30)])
			draw_polyline(crack, Color(0.05, 0.03, 0.03, 0.85), 2.0)
		if box.ammo_text != "":
			var font: Font = get_theme_default_font()
			var fs := 13
			var tw: float = font.get_string_size(box.ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pill := Rect2(Vector2(sz - tw - 14.0, sz - 20.0), Vector2(tw + 10.0, 18.0))
			draw_rect(pill, Color(0.05, 0.05, 0.07, 0.92))
			draw_rect(pill, box.STEEL, false, 1.0)
			draw_string(font, pill.position + Vector2(5.0, 13.5), box.ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, box.INK)
