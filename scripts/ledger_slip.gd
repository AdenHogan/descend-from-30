class_name LedgerSlip
extends Control

## A slip of paper held to the page with a strip of tape (a perk on offer, a note). Under the pointer — or with focus on anything inside it — it LIFTS: it rises a few px, its shadow grows
## and softens, and a pen draws a line under its title. That is the whole hover; there is no glow and no colour change, because a slip of paper does neither.
## The slip owns a MarginContainer (`content`) the caller fills; it is laid out inside the paper.

@export var seed_value: int = 1
@export var tilt_deg: float = 0.0
@export var tape: bool = true
@export var tint: Color = Ledger.PAPER_SLIP
@export var margin: int = 16
## The control whose text gets underlined when the slip lifts (the title). Optional.
var underline_target: Control = null

var content: MarginContainer = null
var lift: float = 0.0                       # 0 at rest, 1 fully raised
var hovered: bool = false
## A slip the player has ticked (a chosen upgrade): it stays lifted and a pen tick sits in its corner. Nothing else changes — no colour, no glow.
var held: bool = false:
	set(v):
		held = v
		queue_redraw()
var _outline: PackedVector2Array = PackedVector2Array()
var _outline_size: Vector2 = Vector2.ZERO
var _was_hover: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	content = MarginContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	resized.connect(_on_resized)


func _ready() -> void:
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, margin)
	content.add_theme_constant_override("margin_top", margin + 6)       # room for the tape
	rotation = deg_to_rad(tilt_deg)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	content.position = Vector2.ZERO
	content.size = size
	_outline_size = Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var want := get_global_rect().has_point(get_global_mouse_position()) or _has_focus_inside()
	hovered = want
	if want and not _was_hover:
		Ledger.play("tick", -17.0, 0.07)
	_was_hover = want
	var target := 1.0 if (want or held) else 0.0
	var nl := move_toward(lift, target, delta * 7.5)
	if nl != lift:
		lift = nl
		content.position = Vector2(0, -lift * 5.0)
		queue_redraw()


func _has_focus_inside() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and is_ancestor_of(f)


func _draw() -> void:
	if _outline_size != size or _outline.size() < 3:
		_outline = Ledger.ragged(size.x, size.y, 34.0, 1.5, seed_value)
		_outline_size = size
	var up := Vector2(0, -lift * 5.0)
	var out := Ledger.shifted(_outline, up)
	# the shadow: close and hard at rest, longer and softer when it is held up
	var d := 3.0 + lift * 6.0
	draw_colored_polygon(Ledger.shifted(_outline, Vector2(d * 0.6, d + 1.0)), Color(0, 0, 0, 0.14 - 0.04 * lift))
	draw_colored_polygon(Ledger.shifted(_outline, Vector2(d * 0.3, d * 0.55)), Color(0, 0, 0, 0.22 - 0.06 * lift))
	draw_polygon(out, Ledger.lit(out, size, tint, 0.9))
	var fib := RandomNumberGenerator.new()
	fib.seed = absi(seed_value) * 13 + 1
	for i in 50:
		draw_rect(Rect2(Vector2(fib.randf() * size.x, fib.randf() * size.y) + up, Vector2(fib.randf_range(1.0, 5.0), 1.0)), Color(0.45, 0.30, 0.12, 0.06))
	var closed := PackedVector2Array(out)
	closed.append(out[0])
	draw_polyline(closed, tint.darkened(0.36), 1.0)
	if underline_target != null and is_instance_valid(underline_target) and lift > 0.02:
		var r := underline_target.get_global_rect()
		var o := get_global_rect().position
		var a := Vector2(r.position.x - o.x, r.end.y - o.y + 3.0) + up
		var b := Vector2(r.position.x - o.x + minf(r.size.x, maxf(r.size.x, 40.0)) * lift, a.y + 0.6)
		var line := Ledger.pen_line(a, b, seed_value, 0.9)
		draw_polyline(line, Color(Ledger.INK.r, Ledger.INK.g, Ledger.INK.b, 0.75), 1.6, true)
	if held:                                                                                   # the tick: two pen strokes, the long one first
		var tk := Vector2(size.x - 34.0, 28.0) + up
		draw_polyline(PackedVector2Array([tk + Vector2(0, 8), tk + Vector2(7, 16), tk + Vector2(21, -4)]), Color(Ledger.BLUE_INK.r, Ledger.BLUE_INK.g, Ledger.BLUE_INK.b, 0.9), 2.4, true)
	if tape:
		draw_set_transform(Vector2(size.x * 0.5, 4.0) + up, -0.03 + 0.06 * fmod(float(seed_value) * 0.37, 1.0), Vector2.ONE)
		draw_rect(Rect2(-31, -6, 62, 19), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(-32, -9, 62, 19), Ledger.TAPE)
		draw_rect(Rect2(-32, -9, 3, 19), Color(1, 1, 1, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
