class_name LedgerStamp
extends Control

## A rubber stamp pressed on a slip: red ink, a ruled border, a word, thick where the stamp pressed and thin where it didn't (a few dropouts in the ink), a little crooked.
## `play()` lands it — it comes down from slightly too big (the hand still pushing), thuds, and the sheet it sits on gets a small knock. It never glows or pulses; once pressed it stays.

@export var word: String = "TAKEN"
@export var ink: Color = Ledger.STAMP_RED
@export var tilt_deg: float = -7.0
@export var seed_value: int = 3
@export var px: int = 30
@export var centre: Vector2 = Vector2(0.5, 0.5)        # where on its rect the stamp lands (fractions) — a slip's lands below its text, not over it

var progress: float = 0.0               # 0 = not pressed yet, 1 = down
var pressed: bool = false
var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Press it. `shake` = the control to knock (the sheet), optional.
func play(shake: Control = null) -> void:
	if pressed:
		return
	pressed = true
	visible = true
	pivot_offset = size * centre
	Ledger.play("stamp", -4.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if shake != null and is_instance_valid(shake):
		_tween.tween_callback(_knock.bind(shake))


func _knock(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var base := node.position
	var t := node.create_tween()
	t.tween_property(node, "position", base + Vector2(0, 3), 0.04)
	t.tween_property(node, "position", base + Vector2(1, -1), 0.05)
	t.tween_property(node, "position", base, 0.07)


func _set_progress(v: float) -> void:
	progress = v
	scale = Vector2.ONE * lerpf(1.35, 1.0, v)
	modulate.a = clampf(v * 1.6, 0.0, 1.0)
	queue_redraw()


## Set it down already pressed (a slip that was taken earlier is shown stamped on re-entry).
func set_down() -> void:
	pressed = true
	visible = true
	_set_progress(1.0)


func _draw() -> void:
	var f := Ledger.font("head")
	var sz := px
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var h := f.get_height(sz)
	var pad := 8.0
	var box := Rect2(-w * 0.5 - pad, -h * 0.5 - 3.0, w + pad * 2.0, h + 6.0)
	draw_set_transform(size * centre, deg_to_rad(tilt_deg), Vector2.ONE)
	var col := Color(ink.r, ink.g, ink.b, 0.88)
	draw_rect(box, col, false, 2.4)
	draw_rect(box.grow(-4.0), Color(ink.r, ink.g, ink.b, 0.55), false, 1.0)
	draw_string(f, Vector2(-w * 0.5, h * 0.5 - f.get_descent(sz) - 1.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
	draw_string(f, Vector2(-w * 0.5 + 0.7, h * 0.5 - f.get_descent(sz) - 0.4), word, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(col.r, col.g, col.b, 0.35))   # ink that spread a hair
	# the ink did not take everywhere: a few specks of paper showing through
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + word.hash()
	var back := Ledger.PAPER_SLIP
	for i in 70:
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		draw_rect(Rect2(p, Vector2(rng.randf_range(1.0, 3.5), rng.randf_range(1.0, 2.2))), Color(back.r, back.g, back.b, rng.randf_range(0.55, 0.95)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
