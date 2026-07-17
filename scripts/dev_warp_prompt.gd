extends PanelContainer

# DEV: floor warp (F6). Press F6, type a floor number, Enter to warp there;
# Esc cancels. The tree is paused while the prompt is open so typed digits
# don't trigger item-slot hotkeys and enemies don't advance.
# Gated by DEV_MODE (keep in sync with player.gd) — disable for release.

const DEV_MODE = true
const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var edit: LineEdit = null


func _ready() -> void:
	# Must keep processing while the tree is paused, both for typing and Esc.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	position = Vector2(SCREEN_W / 2 - 140, SCREEN_H / 2 - 60)
	custom_minimum_size = Vector2(280, 0)

	var vbox = VBoxContainer.new()
	add_child(vbox)
	var title = Label.new()
	title.text = "DEV — WARP TO FLOOR"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	edit = LineEdit.new()
	edit.placeholder_text = "0-30, Enter warps, Esc cancels"
	edit.text_submitted.connect(_on_submitted)
	vbox.add_child(edit)


func _input(event: InputEvent) -> void:
	if not DEV_MODE:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F6:
		if visible:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	# Only in live gameplay: needs a player to warp, and must not fight the
	# pause menu (or anything else) over tree pause state.
	if not HUD.visible or get_tree().paused:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	visible = true
	edit.text = ""
	edit.placeholder_text = "0-30, Enter warps, Esc cancels"
	edit.grab_focus()
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false


func _on_submitted(text: String) -> void:
	var trimmed = text.strip_edges()
	if trimmed == "":
		_close()
		return
	if not trimmed.is_valid_int():
		edit.text = ""
		edit.placeholder_text = "numbers only (0-30)"
		return
	var floor_num = clampi(int(trimmed), 0, 30)
	_close()
	_warp_to(floor_num)


func _warp_to(floor_num: int) -> void:
	# Mirrors stairwell.gd's descent transition so all arrival hooks fire.
	WorldState.current_floor = floor_num
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = "left"
	WorldState.stair_direction = "down"
	WorldState.on_floor_arrived(floor_num)
	HUD.update_floor_label()
	HUD.show_feedback("DEV: Warped to floor " + str(floor_num))
	if floor_num == 30:
		get_tree().change_scene_to_file("res://scenes/hallway.tscn")
	elif floor_num == 0:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/building_floors.tscn")
