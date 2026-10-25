class_name LedgerSheet
extends Control

## A sheet of ledger paper lying on the desk: a shadow it throws, the stack of sheets under it, paper that is lit from the upper left (vertex tones, not a glow), fibres and a few stains,
## ruled lines and a red margin rule, an outline that wanders a little. Pure function of `seed_value` and its size — it always looks the same and no two look alike.
## Children (the page's contents) are laid out by Godot's containers on top of it; the sheet only draws behind them.

@export var seed_value: int = 1
@export var ruled: bool = true
@export var rule_gap: float = 28.0
@export var rule_first: float = 96.0                # y of the first ruled line
@export var margin_x: float = 78.0                  # the red margin rule (0 = none)
@export var edge_amp: float = 2.6
@export var stack: int = 2                          # how many more sheets show under this one
@export var tint: Color = Ledger.PAPER
@export var tape_corners: bool = false              # two strips holding the sheet to the desk

var _outline: PackedVector2Array = PackedVector2Array()
var _outline_size: Vector2 = Vector2.ZERO
var _fibres: Array = []
var _stains: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(queue_redraw)


func _ensure() -> void:
	if _outline_size == size and _outline.size() >= 3:
		return
	_outline = Ledger.ragged(size.x, size.y, 30.0, edge_amp, seed_value)
	_outline_size = size
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed_value) * 31 + 5
	_fibres.clear()
	for i in 150:
		_fibres.append(Rect2(rng.randf() * size.x, rng.randf() * size.y, rng.randf_range(1.0, 6.0), 1.0))
	_stains.clear()
	for i in 3:
		_stains.append([Vector2(rng.randf_range(40.0, maxf(41.0, size.x - 40.0)), rng.randf_range(40.0, maxf(41.0, size.y - 40.0))), rng.randf_range(6.0, 16.0), rng.randf_range(0.02, 0.04)])
	# one cup-ring, now and then, where someone set a mug down
	if rng.randf() < 0.65:
		_stains.append([Vector2(rng.randf_range(size.x * 0.55, size.x - 70.0), rng.randf_range(size.y * 0.55, size.y - 70.0)), rng.randf_range(24.0, 32.0), -1.0])


func _draw() -> void:
	_ensure()
	var out := _outline
	# the shadow it throws on the desk, and the sheets under it
	draw_colored_polygon(Ledger.shifted(out, Vector2(7, 10)), Color(0, 0, 0, 0.20))
	draw_colored_polygon(Ledger.shifted(out, Vector2(3, 5)), Color(0, 0, 0, 0.26))
	for i in range(stack, 0, -1):
		var e := Ledger.shifted(out, Vector2(1.6 * i, 2.8 * i))
		draw_colored_polygon(e, tint.darkened(0.10 + 0.05 * i))
		draw_polyline(_closed(e), tint.darkened(0.45), 1.0)
	draw_polygon(out, Ledger.lit(out, size, tint))
	# fibres and stains
	for r in _fibres:
		draw_rect(r, Color(0.45, 0.30, 0.12, 0.06))
	for s in _stains:
		if float(s[2]) < 0.0:
			draw_arc(s[0], float(s[1]), 0.3, 5.6, 28, Color(0.42, 0.27, 0.10, 0.11), 2.0)
			draw_arc(s[0], float(s[1]) - 2.0, 0.3, 5.4, 28, Color(0.42, 0.27, 0.10, 0.05), 3.0)
		else:
			draw_circle(s[0], float(s[1]), Color(0.55, 0.38, 0.14, float(s[2])))
	# ruled lines (a faint blue-grey, the way a printed ledger has them) and the margin rule
	if ruled:
		var y := rule_first
		while y < size.y - 18.0:
			draw_line(Vector2(10, y), Vector2(size.x - 10, y), Ledger.RULE, 1.0)
			y += rule_gap
	if margin_x > 0.0:
		draw_line(Vector2(margin_x, 6), Vector2(margin_x, size.y - 6), Ledger.MARGIN_RULE, 1.0)
		draw_line(Vector2(margin_x + 3, 6), Vector2(margin_x + 3, size.y - 6), Color(Ledger.MARGIN_RULE.r, Ledger.MARGIN_RULE.g, Ledger.MARGIN_RULE.b, 0.22), 1.0)
	draw_polyline(_closed(out), tint.darkened(0.38), 1.0)
	if tape_corners:
		_tape(Vector2(36, 2), -0.20)
		_tape(Vector2(size.x - 36, 2), 0.20)


func _tape(at: Vector2, rot: float) -> void:
	draw_set_transform(at, rot, Vector2.ONE)
	draw_rect(Rect2(-34, -8, 68, 20), Color(0, 0, 0, 0.12))
	draw_rect(Rect2(-35, -11, 68, 20), Ledger.TAPE)
	draw_rect(Rect2(-35, -11, 4, 20), Color(1, 1, 1, 0.14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := PackedVector2Array(p)
	c.append(p[0])
	return c
