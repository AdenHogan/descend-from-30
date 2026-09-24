extends ChoicePanel

# RUN BOONS (docs/PROGRESSION.md, tier 2 — this character only). Opened from the HUD's boon badge
# when a milestone floor has a boon waiting: pick one of two, or pass. The boon lasts until this
# character's story ends (the time skip wipes it). Data: Progression.RUN_BOONS.

var floor_num: int = -1
var _row: HBoxContainer = null
var _sub: Label = null


func _ready() -> void:
	build_card("A SECOND WIND", 640.0, 300.0, Color(0.85, 0.66, 0.22))
	_sub = label("", 13, DIM)
	_sub.position = Vector2(24, 52)
	_sub.size = Vector2(592, 36)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_sub)
	_row = HBoxContainer.new()
	_row.position = Vector2(24, 96)
	_row.add_theme_constant_override("separation", 16)
	card.add_child(_row)
	var skip := Button.new()
	skip.text = "Pass"
	skip.position = Vector2(640 - 124, 300 - 52)
	skip.size = Vector2(100, 34)
	skip.pressed.connect(func(): pass_boon())
	card.add_child(skip)


# Show the offer for the OLDEST waiting milestone. Returns false when nothing is waiting.
func open() -> bool:
	if WorldState.pending_boon_floors.is_empty():
		close()
		return false
	floor_num = int(WorldState.pending_boon_floors[0])
	_sub.text = "Reaching floor %d has steadied you. Choose one — it lasts for the rest of this life, not the next." % floor_num
	for c in _row.get_children():
		c.queue_free()
	for id in WorldState.boon_offer(floor_num):
		var d: Dictionary = Progression.boon(id)
		var b := choice_button(d.get("name", id), d.get("desc", ""), 288.0, 120.0)
		b.pressed.connect(choose.bind(id))
		_row.add_child(b)
	show_panel()
	return true


func choose(boon_id: String) -> String:
	var err: String = WorldState.take_boon(floor_num, boon_id)
	if err == "":
		HUD.show_feedback("%s — for the rest of this run." % Progression.boon(boon_id).get("name", boon_id))
		_next_or_close()
	return err


func pass_boon() -> void:
	WorldState.skip_boon(floor_num)
	_next_or_close()


func _next_or_close() -> void:
	if WorldState.pending_boon_floors.is_empty():
		close()
	else:
		open()
