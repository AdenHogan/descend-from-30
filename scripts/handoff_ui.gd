extends ChoicePanel

# THE HANDOFF (docs/THREE_RUN_ARC.md "Descent boon"; data in WorldState.leave_for_next). Shown as
# an escaping character steps out of the lobby: leave ONE item at the door for whoever comes next
# (the next character this session, or the next game's first character after the third run), or
# take everything. Emits `decided(slot)` exactly once — -1 when nothing is left (ESC / ✕ / "take
# everything" all count), so the exit flow awaiting it can never hang.

signal decided(slot: int)

const W := 640.0
const H := 300.0
var _done := false
var _grid: GridContainer = null


func _ready() -> void:
	build_card("LEAVE SOMETHING BEHIND?", W, H, Color(0.85, 0.72, 0.40))
	var last_run: bool = WorldState.current_run >= WorldState.RUN_NAMES.size()
	var sub := label(("You're out. Leave one thing at the door for your NEXT game's first survivor?"
		if last_run else "You're out. Leave one thing at the door for whoever comes down next?"), 12, DIM)
	sub.position = Vector2(24, 54)
	sub.size = Vector2(W - 48, 36)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(sub)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.position = Vector2(24, 96)
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	card.add_child(_grid)
	var none := Button.new()
	none.text = "Take everything with me"
	none.position = Vector2(24, H - 56)
	none.size = Vector2(260, 34)
	none.pressed.connect(choose.bind(-1))
	card.add_child(none)


func open() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for slot in WorldState.handoff_candidates():
		var inst = WorldState.inventory[slot]
		var t: String = inst.get_display_name()
		if inst.level > 1:
			t += "  Lv%d" % inst.level
		if inst.count > 1:
			t += "  x%d" % inst.count
		var max_d: int = inst.get_max_durability()
		if inst.is_depleted:
			t += "  (broken)"
		elif max_d > 0 and not inst.get_data().get("single_use", false):
			t += "  %d/%d" % [inst.current_durability, max_d]
		var b := Button.new()
		b.text = t
		b.custom_minimum_size = Vector2((W - 58) * 0.5, 34)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(choose.bind(slot))
		_grid.add_child(b)
	show_panel()


# The player's pick (-1 = nothing). Emits once, then closes.
func choose(slot: int) -> void:
	if _done:
		return
	_done = true
	super.close()
	decided.emit(slot)


# ESC / ✕ / Game's modal-close all mean "take everything" — never leave the exit flow waiting.
func close() -> void:
	choose(-1)
