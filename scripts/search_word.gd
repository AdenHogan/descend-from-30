class_name SearchWord
extends Control

## THE SEARCH, AS A WORD (owner round 48j: "maybe we don't even need the bar. It can be smaller, live in game, and we see the player. With searching, the word searching literally can be the bar —
## the word and the timer is a transition going from nothing, from the S to the G. Once the word is filled in we know if it's something or nothing found").
## SEARCHING hangs just above the node being searched, small, on a thin dark plate; its letters light one after another, S to G, as the search runs — dim to brass. When the last one is lit
## it RESOLVES where it hangs: found = the whole word flares warm white and lifts away (the panel appears); nothing = the letters go grey and sink (a line says so). Drawing only: how long a
## search takes, what it finds and whether it was cancelled are loot_ui's, as they always were.

const WORD := "SEARCHING"
const PX := 20
const RESOLVE_TIME := 0.5

var progress: float = 0.0           # 0..1, how far the search is
var active: bool = false            # showing (searching or resolving)
var resolving: bool = false
var found: bool = false             # how it resolved
var _resolve_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 30)
	size = Vector2(150, 30)
	visible = false
	set_process(false)


## A search starts: nothing lit.
func begin() -> void:
	progress = 0.0
	active = true
	resolving = false
	_resolve_t = 0.0
	visible = true
	set_process(false)
	queue_redraw()


func set_progress(done: float, of: float) -> void:
	progress = clampf(done / maxf(of, 0.001), 0.0, 1.0)
	queue_redraw()


func fraction() -> float:
	return progress


## How many letters are fully lit.
func lit_letters() -> int:
	return int(floor(progress * float(WORD.length()) + 0.0001))


## The last letter is in: the word says what the search found, then goes.
func resolve(was_found: bool) -> void:
	if not active:
		return
	progress = 1.0
	found = was_found
	resolving = true
	_resolve_t = 0.0
	set_process(true)
	queue_redraw()


## Gone at once (the search was walked away from, not finished).
func cancel() -> void:
	active = false
	resolving = false
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not resolving:
		return
	_resolve_t += delta
	if _resolve_t >= RESOLVE_TIME:
		cancel()
		return
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	var f: Font = Lamp.font("label")
	var n := WORD.length()
	var widths: Array = []
	var total := 0.0
	for i in range(n):
		var w: float = f.get_string_size(WORD[i], HORIZONTAL_ALIGNMENT_LEFT, -1, PX).x
		widths.append(w)
		total += w
	var u := clampf(_resolve_t / RESOLVE_TIME, 0.0, 1.0) if resolving else 0.0
	var alpha := 1.0 - (maxf(0.0, u - 0.35) / 0.65 if found else u * u)
	var lift := (-6.0 * u) if (resolving and found) else (5.0 * u if resolving else 0.0)
	var plate := Rect2(Vector2(size.x * 0.5 - total * 0.5 - 12.0, 2.0 + lift), Vector2(total + 24.0, 26.0))
	draw_rect(plate, Color(0.03, 0.022, 0.014, 0.74 * alpha))
	Lamp.outline(self, plate, Lamp.fade(Lamp.EDGE, alpha), 1.0)
	Lamp.brackets(self, plate, Lamp.fade(Lamp.BRASS_DIM, alpha), 6.0, 2.0, Lamp.TL | Lamp.BR, 1.0)
	var x := plate.position.x + 12.0
	var base := plate.position.y + 19.0
	for i in range(n):
		var k := clampf(progress * float(n) - float(i), 0.0, 1.0)         # this letter's own fill: 0 dim .. 1 lit; the one being reached is part-way
		var col: Color = Lamp.DIM.lerp(Lamp.BRASS_HI, k)
		col.a = lerpf(0.55, 1.0, k)
		var dy := 0.0
		if resolving and found:
			col = col.lerp(Lamp.TEXT, minf(u * 4.0, 1.0))                  # the whole word flares
		elif resolving:
			col = Lamp.DIM                                                  # nothing: the letters go grey…
			col.a = 0.85
			dy = 3.0 * u                                                    # …and sink
		col.a *= alpha
		draw_string(f, Vector2(x, base + dy), WORD[i], HORIZONTAL_ALIGNMENT_LEFT, -1, PX, col)
		x += float(widths[i])
