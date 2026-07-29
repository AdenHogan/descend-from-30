extends Control

# PROFILE SELECT — three save slots, built in code so there is no .tscn to keep
# in sync with the layout. Reached from the title screen by BOTH New Game and
# Continue: the slot decides which of those it offers.
#
# A slot with no files is a NEW PLAYER, so it starts with the tutorial. A slot
# with history skips it. That is the whole "does the game know me?" question,
# answered somewhere the player can see and control it — and Delete puts a slot
# back to new-player state deliberately.

const PANEL_W := 300.0
const PANEL_H := 300.0
const GAP := 24.0

var _pending_delete: int = -1   # slot awaiting a confirm click


func _ready() -> void:
	HUD.hide_hud()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.07, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = "SELECT PROFILE"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(HUD.SCREEN_W, 44)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var total_w: float = WorldState.SLOT_COUNT * PANEL_W + (WorldState.SLOT_COUNT - 1) * GAP
	var x0: float = (HUD.SCREEN_W - total_w) * 0.5
	for i in range(WorldState.SLOT_COUNT):
		_build_slot(i + 1, x0 + i * (PANEL_W + GAP))

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2((HUD.SCREEN_W - 160) * 0.5, 560)
	back.size = Vector2(160, 40)
	back.pressed.connect(func(): Game.go_to_scene("title"))
	add_child(back)


func _build_slot(slot: int, x: float) -> void:
	var info: Dictionary = WorldState.slot_summary(slot)

	var panel := ColorRect.new()
	panel.position = Vector2(x, 140)
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.color = Color(0.14, 0.14, 0.16, 1.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var head := Label.new()
	head.text = "PROFILE %d" % slot
	head.add_theme_font_size_override("font_size", 20)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(x, 154)
	head.size = Vector2(PANEL_W, 26)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)

	var body := Label.new()
	body.add_theme_font_size_override("font_size", 15)
	body.position = Vector2(x + 18, 192)
	body.size = Vector2(PANEL_W - 36, 150)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = _describe(info)
	add_child(body)

	# A slot offers CONTINUE when it has a save, otherwise NEW GAME. An empty
	# slot says "New Game" and will run the tutorial.
	var main_btn := Button.new()
	main_btn.position = Vector2(x + 18, 340)
	main_btn.size = Vector2(PANEL_W - 36, 40)
	if info["has_save"]:
		main_btn.text = "Continue"
		main_btn.pressed.connect(func(): _continue(slot))
	else:
		main_btn.text = "New Game"
		main_btn.pressed.connect(func(): _new_game(slot))
	add_child(main_btn)

	# Restarting a slot that already has a save is destructive, so it is its own
	# button rather than something Continue might do by accident.
	if info["has_save"]:
		var restart := Button.new()
		restart.text = "New Game (overwrite)"
		restart.position = Vector2(x + 18, 386)
		restart.size = Vector2(PANEL_W - 36, 32)
		restart.pressed.connect(func(): _new_game(slot))
		add_child(restart)

	if info["exists"]:
		var del := Button.new()
		del.text = "Delete" if _pending_delete != slot else "Delete — click to confirm"
		del.position = Vector2(x + 18, 396 if not info["has_save"] else 424)
		del.size = Vector2(PANEL_W - 36, 32)
		del.pressed.connect(func(): _delete(slot))
		add_child(del)


func _describe(info: Dictionary) -> String:
	if not info["exists"]:
		return "Empty\n\nA new player starts here — the Floor 30 tutorial will run."
	var lines: Array[String] = []
	lines.append("Runs made: %d" % info["runs_made"])
	lines.append("Successful: %d" % info["runs_successful"])
	if info["has_save"]:
		lines.append("")
		lines.append("In progress — Floor %d" % info["floor"])
		lines.append("Run %d of 3 (%s)" % [info["run"], WorldState.run_name(info["run"])])
	else:
		lines.append("")
		lines.append("No run in progress")
		if info["tutorial_completed"]:
			lines.append("Tutorial complete — it will be skipped")
	return "\n".join(lines)


func _new_game(slot: int) -> void:
	WorldState.use_slot(slot)
	WorldState.delete_save()      # starting fresh in this slot
	Game.new_game()


func _continue(slot: int) -> void:
	WorldState.use_slot(slot)
	Game.continue_game()


func _delete(slot: int) -> void:
	# Two-step: the first click arms it, the second wipes. No modal needed, and
	# no way to lose a profile to a stray click.
	if _pending_delete != slot:
		_pending_delete = slot
		_build()
		return
	WorldState.delete_slot(slot)
	_pending_delete = -1
	_build()
