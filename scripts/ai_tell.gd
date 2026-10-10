class_name AiTell
extends Node2D

# A TELL: the small mark over a head that says what it is thinking (docs/NPC_AI.md). The whole AI layer is built
# so a player can READ it — the same three marks mean the same thing on a survivor and on the dead:
#
#   !  alert   — it has seen / heard something and is committing (red)
#   ?  search  — it lost track and is looking for it (amber)
#   …  fear    — it is hiding / frozen, holding its breath (pale)
#
# Purely visual: no collision, no input, never in a group anything queries. Add one per actor with `attach`;
# call `show_mark(kind)` when the behaviour changes — a repeated call with the same kind just keeps it up.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const KINDS := {
	"alert":  {"glyph": "!", "color": Color(0.95, 0.30, 0.24)},
	"search": {"glyph": "?", "color": Color(0.96, 0.78, 0.30)},
	"fear":   {"glyph": "…", "color": Color(0.80, 0.84, 0.92)},
}
const HOLD := 1.1                # seconds a mark stays before it fades
const FADE := 0.35
const RISE_PX := 3.0             # it bobs up this far while shown

var kind: String = ""            # "" = nothing shown
var _t: float = 0.0
var _hold: float = 0.0


## Hangs a tell on `actor`, `lift` px above its origin (the actor's head). Returns it.
static func attach(actor: Node2D, lift: float = 70.0) -> AiTell:
	var t := AiTell.new()
	t.name = "AiTell"
	t.position = Vector2(0, -lift)
	t.z_index = 3
	actor.add_child(t)
	return t


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


## Shows `new_kind`. The same kind again only refreshes the hold, so a behaviour that re-enters every frame
## doesn't re-trigger the pop. Unknown kind = hide.
func show_mark(new_kind: String, hold: float = HOLD) -> void:
	if not KINDS.has(new_kind):
		clear()
		return
	if kind != new_kind:
		_t = 0.0
	kind = new_kind
	_hold = hold
	set_process(true)
	queue_redraw()


func clear() -> void:
	kind = ""
	_hold = 0.0
	set_process(false)
	queue_redraw()


func is_showing() -> bool:
	return kind != ""


func _process(delta: float) -> void:
	_t += delta
	_hold -= delta
	if _hold <= -FADE:
		clear()
		return
	queue_redraw()


func _draw() -> void:
	if kind == "":
		return
	var spec: Dictionary = KINDS[kind]
	var a := 1.0 if _hold > 0.0 else clampf(1.0 + _hold / FADE, 0.0, 1.0)
	var pop := minf(_t / 0.12, 1.0)                      # a quick pop-in
	var lift := -RISE_PX * minf(_t / 0.4, 1.0)
	var col: Color = spec["color"]
	col.a = a * pop
	var shadow := Color(0, 0, 0, 0.7 * a * pop)
	var s := 14
	var pos := Vector2(-4, lift)
	draw_string(FONT, pos + Vector2(1, 1), spec["glyph"], HORIZONTAL_ALIGNMENT_LEFT, -1, s, shadow)
	draw_string(FONT, pos, spec["glyph"], HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
