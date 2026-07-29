extends Control

# PROFILE SELECT — layout lives in scenes/profile_select.tscn. This script
# creates and positions NOTHING: it fills text, toggles visibility, and wires
# presses, so an art pass can restyle or replace every node freely.
#
# Structure follows the Battlestar Galactica reference the owner supplied:
# navigation and ACTIONS sit in a left column, and the cards stay clean —
# header, emblem, current run, stats. You click a card to SELECT it; the left
# column then offers what that slot can actually do.
#
# An empty slot is a NEW PLAYER and runs the Floor 30 tutorial; a slot with
# history skips it. Delete returns a slot to new-player state.
#
# Node contract (rename in the scene → update here):
#   Nav/Subheading, Nav/ContinueButton, Nav/NewGameButton, Nav/DeleteButton,
#   Nav/BackButton
#   Slot1..3/{SelectBorder, Name, Emblem, RunCaption, RunPlace, RunName,
#             Playtime, SurvivorCaption, Survivor1..3, SurvivorFace1..3,
#             SurvivorTag1..3, Money, Status, RunsMade, RunsWon, SelectButton}

var _selected: int = 1
var _confirm_delete: bool = false


func _ready() -> void:
	HUD.hide_hud()
	_connect("Nav/ContinueButton", _on_continue)
	_connect("Nav/NewGameButton", _on_new_game)
	_connect("Nav/DeleteButton", _on_delete)
	_connect("Nav/BackButton", func(): Game.go_to_scene("title"))
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		var btn := get_node_or_null("Slot%d/SelectButton" % slot)
		if btn != null:
			btn.pressed.connect(func(): _select(slot))
	# Open on the first slot that has a run to resume, else slot 1.
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		if WorldState.slot_summary(slot)["has_save"]:
			_selected = slot
			break
	_refresh()


func _connect(path: String, fn: Callable) -> void:
	var n := get_node_or_null(path)
	if n != null:
		n.pressed.connect(fn)


func _node(slot: int, child: String) -> Node:
	return get_node_or_null("Slot%d/%s" % [slot, child])


func _set_text(slot: int, child: String, value: String) -> void:
	var n := _node(slot, child)
	if n != null:
		n.text = value


func _select(slot: int) -> void:
	_selected = slot
	_confirm_delete = false   # changing slots disarms a pending delete
	_refresh()


func _refresh() -> void:
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		_fill_card(slot, WorldState.slot_summary(slot))
	_fill_nav(WorldState.slot_summary(_selected))


func _fill_card(slot: int, info: Dictionary) -> void:
	var border := _node(slot, "SelectBorder")
	if border != null:
		border.visible = slot == _selected

	var empty: bool = not info["exists"]
	_set_text(slot, "Name", "EMPTY" if empty else "SAVE SLOT %d" % slot)

	# An empty card shows only its header — everything else is blank, exactly as
	# in the reference.
	var hide_when_empty := ["RunCaption", "RunPlace", "RunName", "Playtime",
		"Status", "RunsMade", "RunsWon", "StatRule", "Divider", "Emblem",
		"SurvivorCaption", "Money"]
	for i in range(1, 4):
		hide_when_empty.append("Survivor%d" % i)
		hide_when_empty.append("SurvivorFace%d" % i)
		hide_when_empty.append("SurvivorTag%d" % i)
	for child in hide_when_empty:
		var n := _node(slot, child)
		if n != null:
			n.visible = not empty
	if empty:
		return

	if info["has_save"]:
		_set_text(slot, "RunCaption", "CURRENT RUN")
		_set_text(slot, "RunPlace", "FLOOR %d" % info["floor"])
		_set_text(slot, "RunName", "RUN %d OF 3 — %s" % [
			info["run"], WorldState.run_name(info["run"]).to_upper()])
		_set_text(slot, "Status", "IN PROGRESS")
	else:
		_set_text(slot, "RunCaption", "NO RUN IN PROGRESS")
		_set_text(slot, "RunPlace", "")
		_set_text(slot, "RunName", "")
		_set_text(slot, "Status", "TUTORIAL COMPLETE" if info["tutorial_completed"] else "")
	_set_text(slot, "Playtime", WorldState.format_playtime(info["playtime_seconds"]))
	_fill_survivors(slot, info)
	_set_text(slot, "Money", "$%d" % info["wallet"])
	_set_text(slot, "RunsMade", "NUMBER OF RUNS: %d" % info["runs_made"])
	_set_text(slot, "RunsWon", "SUCCESSFUL RUNS: %d" % info["runs_successful"])


# The three survivors of the arc — morning, afternoon, evening — and how each
# one ended. Colour carries the state so it still reads before portrait art
# exists; the Face slots are TextureRects waiting for that art.
const SURVIVOR_COLOURS := {
	"alive": Color(0.79, 0.19, 0.19, 1.0),      # the run you are in
	"survived": Color(0.22, 0.45, 0.26, 1.0),   # made it out
	"dead": Color(0.14, 0.14, 0.15, 1.0),       # did not
	"": Color(0.22, 0.22, 0.24, 1.0),           # not played yet
}
const SURVIVOR_TAGS := {
	"alive": "NOW", "survived": "OUT", "dead": "DEAD", "": "—",
}


func _fill_survivors(slot: int, info: Dictionary) -> void:
	var states: Array = info["survivors"]
	for i in range(3):
		var state: String = String(states[i]) if i < states.size() else ""
		var box := _node(slot, "Survivor%d" % (i + 1))
		if box != null:
			box.color = SURVIVOR_COLOURS.get(state, SURVIVOR_COLOURS[""])
		_set_text(slot, "SurvivorTag%d" % (i + 1), SURVIVOR_TAGS.get(state, "—"))


func _fill_nav(info: Dictionary) -> void:
	var sub := get_node_or_null("Nav/Subheading")
	if sub != null:
		sub.text = "SAVE SLOT %d" % _selected

	# Only offer what this slot can actually do.
	var cont := get_node_or_null("Nav/ContinueButton")
	if cont != null:
		cont.visible = info["has_save"]
	var new_btn := get_node_or_null("Nav/NewGameButton")
	if new_btn != null:
		new_btn.text = "NEW GAME (OVERWRITE)" if info["has_save"] else "NEW GAME"
	var del := get_node_or_null("Nav/DeleteButton")
	if del != null:
		del.visible = info["exists"]
		del.text = "DELETE — CONFIRM?" if _confirm_delete else "DELETE"


func _on_continue() -> void:
	WorldState.use_slot(_selected)
	Game.continue_game()


func _on_new_game() -> void:
	WorldState.use_slot(_selected)
	WorldState.delete_save()      # starting fresh in this slot
	Game.new_game()


func _on_delete() -> void:
	# Two-step: the first press arms it, the second wipes. No modal needed, and
	# no way to lose a profile to a stray click.
	if not _confirm_delete:
		_confirm_delete = true
		_refresh()
		return
	WorldState.delete_slot(_selected)
	_confirm_delete = false
	_refresh()
