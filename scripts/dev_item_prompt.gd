extends PanelContainer

# DEV: item spawn (F1). Press F1, type an item number, Enter to add it to the
# inventory; Esc cancels. Submitting keeps the box open so you can spam the same
# number (e.g. fill a whole inventory with cans) — Esc or empty-Enter closes.
# The tree is paused while open so typed digits don't trigger item-slot hotkeys.
# Gated by DEV_MODE (keep in sync with player.gd) — disable for release.

const DEV_MODE = true
const SCREEN_W = 1152.0
const SCREEN_H = 648.0

var edit: LineEdit = null
var hint: Label = null


func _ready() -> void:
	# Must keep processing while the tree is paused, both for typing and Esc.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dev_item_prompt")   # the F1 dev menu finds + opens this
	visible = false
	position = Vector2(SCREEN_W / 2 - 140, SCREEN_H / 2 - 60)
	custom_minimum_size = Vector2(280, 0)

	var vbox = VBoxContainer.new()
	add_child(vbox)
	var title = Label.new()
	title.text = "DEV — SPAWN ITEM"
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	edit = LineEdit.new()
	edit.placeholder_text = "item number, Enter spawns, Esc closes"
	edit.text_submitted.connect(_on_submitted)
	vbox.add_child(edit)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _input(event: InputEvent) -> void:
	# Opened from the F1 DEV MENU now (open()), not its own hotkey. Only Esc-to-close
	# lives here while the box is up.
	if not DEV_MODE or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()


func open() -> void:
	# Called by the dev menu (which has already unpaused itself). Needs a live player.
	if not DEV_MODE:
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	visible = true
	edit.text = ""
	edit.placeholder_text = "item number, Enter spawns, Esc closes"
	hint.text = ""
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
		hint.text = "numbers only"
		return
	# Item ids are zero-padded strings ("005"); accept "5" or "005".
	var item_id = "%03d" % int(trimmed)
	var item = ItemData.get_item(item_id)
	if item.is_empty():
		edit.text = ""
		hint.text = "no item #" + item_id
		return
	# Ammo arrives as a full stack so one spawn = a loaded gun test.
	var amount = WorldState.MAX_AMMO_PER_SLOT if item.get("is_ammo", false) else 0
	if WorldState.add_to_inventory(item_id, amount):
		HUD.refresh_inventory()
		hint.text = "+ " + item.get("name", item_id)
	else:
		hint.text = "inventory full"
	# Keep the box open and reselected so the same number can be spammed.
	edit.text = ""
	edit.grab_focus()
