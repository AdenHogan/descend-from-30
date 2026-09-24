extends ChoicePanel

# THE DOOR (docs/THREE_RUN_ARC.md "Descent boon"; data in Progression.door_valour +
# WorldState.leave_for_next). Shown as an escaping character presses to leave the lobby. Their kit is
# SCRAPPED AT THE DOOR for Valour — every weapon's worth, + a bonus for leaving nothing behind — or
# they LEAVE ONE item by the door, stashed for their NEXT game, and forfeit that item's worth and the
# bonus. Each button shows its price, so the choice is made with the numbers in view. Emits
# `decided(slot)` exactly once — -1 when nothing is left (ESC / ✕ / "scrap it all" all count), so
# the exit flow awaiting it can never hang.

signal decided(slot: int)

const W := 700.0
const H := 350.0
var _done := false
var _grid: GridContainer = null
var _all: Button = null


func _ready() -> void:
	build_card("THE DOOR", W, H, Color(0.85, 0.72, 0.40))
	var sub := label("Your kit is scrapped at the door for Valour. Or leave ONE thing by the door for your NEXT game: you lose its worth, and the bonus for leaving nothing behind.", 12, DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # before the size, or it grows to one line
	sub.position = Vector2(24, 52)
	sub.size = Vector2(W - 48, 52)
	card.add_child(sub)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.position = Vector2(24, 116)
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	card.add_child(_grid)
	_all = Button.new()
	_all.position = Vector2(24, H - 56)
	_all.size = Vector2(W - 48, 34)
	_all.pressed.connect(choose.bind(-1))
	card.add_child(_all)


func open() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var inv: Array = WorldState.inventory
	for slot in WorldState.handoff_candidates():
		var inst = inv[slot]
		var t: String = inst.get_display_name()
		if inst.level > 1:
			t += "  " + inst.tier_tag()
		if inst.count > 1:
			t += "  x%d" % inst.count
		var max_d: int = inst.get_max_durability()
		if inst.is_depleted:
			t += "  (broken)"
		elif max_d > 0 and not inst.get_data().get("single_use", false):
			t += "  %d/%d" % [inst.current_durability, max_d]
		var keep_v: int = Progression.door_valour(inv, slot)
		t += "\nLeave it: +%d Valour" % keep_v
		var b := Button.new()
		b.text = t
		b.clip_text = true
		b.custom_minimum_size = Vector2((W - 58) * 0.5, 44)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 11)
		if inst.level >= WeaponUpgrades.LEGENDARY_LEVEL:
			b.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		b.pressed.connect(choose.bind(slot))
		_grid.add_child(b)
	_all.text = "Scrap it all, brave the unknown: +%d Valour" % Progression.door_valour(inv, -1)
	show_panel()


# The player's pick (-1 = nothing). Emits once, then closes.
func choose(slot: int) -> void:
	if _done:
		return
	_done = true
	super.close()
	decided.emit(slot)


# ESC / ✕ / Game's modal-close all mean "scrap it all" — never leave the exit flow waiting.
func close() -> void:
	choose(-1)
