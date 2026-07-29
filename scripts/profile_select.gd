extends Control

# PROFILE SELECT — the LAYOUT lives in scenes/profile_select.tscn, not here.
# Every panel, label and button is a real node you can move, restyle, skin or
# replace with art in the 2D editor; this script only fills in the text and
# wires the buttons up. Nothing here creates or positions a control, so an art
# pass can rework the whole screen without touching this file.
#
# Reached from the title screen by BOTH New Game and Continue: the slot you pick
# decides which of those it is. An empty slot is a NEW PLAYER and runs the
# Floor 30 tutorial; a slot with history skips it. Delete puts a slot back to
# new-player state.
#
# Node contract (rename in the scene → update here):
#   Slot1..Slot3 / Name, Stats, MainButton, OverwriteButton, DeleteButton
#   BackButton

var _pending_delete: int = -1   # slot armed for deletion (two-click confirm)


func _ready() -> void:
	HUD.hide_hud()
	var back := get_node_or_null("BackButton")
	if back != null:
		back.pressed.connect(func(): Game.go_to_scene("title"))
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		_wire(slot)
	_refresh()


func _slot_node(slot: int, child: String) -> Node:
	return get_node_or_null("Slot%d/%s" % [slot, child])


func _wire(slot: int) -> void:
	# Connect once in _ready; _refresh only ever changes text and visibility, so
	# signals are never duplicated.
	var main := _slot_node(slot, "MainButton")
	if main != null:
		main.pressed.connect(func(): _on_main(slot))
	var over := _slot_node(slot, "OverwriteButton")
	if over != null:
		over.pressed.connect(func(): _new_game(slot))
	var del := _slot_node(slot, "DeleteButton")
	if del != null:
		del.pressed.connect(func(): _delete(slot))


func _refresh() -> void:
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		var info: Dictionary = WorldState.slot_summary(slot)

		var stats := _slot_node(slot, "Stats")
		if stats != null:
			stats.text = _describe(info)

		# A slot with a run offers Continue; overwriting it is a SEPARATE button
		# so a resume can never be destroyed by a misclick.
		var main := _slot_node(slot, "MainButton")
		if main != null:
			main.text = "Continue" if info["has_save"] else "New Game"
		var over := _slot_node(slot, "OverwriteButton")
		if over != null:
			over.visible = info["has_save"]
		var del := _slot_node(slot, "DeleteButton")
		if del != null:
			del.visible = info["exists"]
			del.text = "Delete — confirm?" if _pending_delete == slot else "Delete"


func _describe(info: Dictionary) -> String:
	if not info["exists"]:
		return "Empty\n\nA new player starts here — the Floor 30 tutorial will run."
	var lines: Array[String] = []
	lines.append("Runs made: %d" % info["runs_made"])
	lines.append("Successful: %d" % info["runs_successful"])
	lines.append("")
	if info["has_save"]:
		lines.append("In progress — Floor %d" % info["floor"])
		lines.append("Run %d of 3 (%s)" % [info["run"], WorldState.run_name(info["run"])])
	else:
		lines.append("No run in progress")
		if info["tutorial_completed"]:
			lines.append("Tutorial complete — it will be skipped")
	return "\n".join(lines)


func _on_main(slot: int) -> void:
	if WorldState.slot_summary(slot)["has_save"]:
		_continue(slot)
	else:
		_new_game(slot)


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
		_refresh()
		return
	WorldState.delete_slot(slot)
	_pending_delete = -1
	_refresh()
