extends CanvasLayer

# Scavenge result panel — CENTRED, shows the item icon + name, and is taken by:
#   • double-clicking it, or
#   • dragging it down onto the inventory bar, or
#   • pressing E / interact,
# and LEFT by simply walking away (the panel vanishes; searching again re-opens
# it). No Take/Leave buttons. Built in code so the layout is controlled here.

const REVEAL_TIME = 3.0
const NOTHING_CLOSE_TIME = 1.6
const DRAG_THRESHOLD = 8.0
const DOUBLE_CLICK_TIME = 0.35
const PANEL_W = 300.0
const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const BAR_TOP = SCREEN_H - 96.0   # dropping below here = onto the inventory bar

var reveal_timer = 0.0
var is_revealing = false
var nothing_timer = 0.0
var current_item_id = ""
var current_key_target = ""
var current_anchor_name = ""
var current_apartment_id = ""
var anchor_node: Node = null
var has_item = false               # a takeable item is currently shown

# UI
var panel: PanelContainer = null
var icon: TextureRect = null
var name_label: Label = null
var hint_label: Label = null

# drag / double-click
var drag_armed = false
var drag_active = false
var drag_from = Vector2.ZERO
var ghost: TextureRect = null
var last_press_time = 0.0


func _ready() -> void:
	layer = 3
	_build_ui()
	visible = false


func _build_ui() -> void:
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_color = Color(0.7, 0.68, 0.55, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var icon_row = CenterContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_row.custom_minimum_size = Vector2(PANEL_W - 32, 96)
	vbox.add_child(icon_row)
	icon = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(96, 96)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_row.add_child(icon)

	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.82))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(PANEL_W - 32, 0)
	vbox.add_child(name_label)

	hint_label = Label.new()
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(PANEL_W - 32, 0)
	vbox.add_child(hint_label)


func open(item_id: String, anchor_name: String, apartment_id: String) -> void:
	WorldState.loot_open = true
	is_revealing = false
	has_item = false
	nothing_timer = 0.0
	current_item_id = item_id
	current_anchor_name = anchor_name
	current_apartment_id = apartment_id
	current_key_target = ""
	anchor_node = get_tree().get_root().find_child(anchor_name, true, false)

	if WorldState.is_anchor_a_key(apartment_id, anchor_name):
		current_key_target = WorldState.get_anchor_key_target(apartment_id, anchor_name)
		current_item_id = "022"

	if WorldState.is_anchor_searched(apartment_id, anchor_name):
		_reveal_item()
		visible = true
		return

	reveal_timer = 0.0
	is_revealing = true
	icon.texture = null
	name_label.text = "Searching…"
	hint_label.text = ""
	visible = true


func _reveal_item() -> void:
	WorldState.mark_anchor_searched(current_apartment_id, current_anchor_name)
	is_revealing = false
	var item_data = ItemData.get_item(current_item_id)
	if current_item_id == "" or item_data.is_empty():
		icon.texture = null
		name_label.text = "Nothing found."
		hint_label.text = ""
		has_item = false
		nothing_timer = NOTHING_CLOSE_TIME
		_notify_anchor_closed(false)
		return
	has_item = true
	icon.texture = ItemData.get_texture(current_item_id)
	if current_key_target != "":
		name_label.text = "Key — Apt " + current_key_target
	else:
		name_label.text = item_data["name"]
	hint_label.text = "Double-click or drag to inventory · walk away to leave"


func _process(delta: float) -> void:
	if not visible:
		return

	# Walk away = leave. (Skip while actively dragging the item to a slot.)
	if not drag_active and anchor_node != null and is_instance_valid(anchor_node):
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var dist = anchor_node.global_position.distance_to(player.global_position)
			if dist > anchor_node.INTERACT_DISTANCE * 1.5:
				_close(false)
				return

	if is_revealing:
		# Searching demands both hands: leaving scavenge / acting cancels it.
		if not WorldState.is_scavenge_mode:
			_close(false)
			return
		var searcher = get_tree().get_first_node_in_group("player")
		if searcher != null and (searcher.is_switching_mode or searcher.is_pushing or searcher.is_attacking):
			_close(false)
			return
		reveal_timer += delta
		if reveal_timer >= REVEAL_TIME:
			_reveal_item()
		return

	# "Nothing found" auto-dismisses shortly.
	if not has_item and nothing_timer > 0.0:
		nothing_timer -= delta
		if nothing_timer <= 0.0:
			_close(false)
		return

	_update_drag()


func _update_drag() -> void:
	if not drag_armed:
		return
	var mouse = get_viewport().get_mouse_position()
	if not drag_active:
		if mouse.distance_to(drag_from) > DRAG_THRESHOLD:
			_start_drag()
	elif ghost != null:
		ghost.position = mouse - Vector2(28, 28)


func _start_drag() -> void:
	drag_active = true
	ghost = TextureRect.new()
	ghost.texture = icon.texture
	ghost.custom_minimum_size = Vector2(56, 56)
	ghost.size = Vector2(56, 56)
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0.85)
	add_child(ghost)


func _end_drag(take: bool) -> void:
	drag_armed = false
	drag_active = false
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if take:
		_take()


func _input(event: InputEvent) -> void:
	if not visible or is_revealing or not has_item:
		return
	# E / interact takes.
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_take()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_press_time < DOUBLE_CLICK_TIME:
				get_viewport().set_input_as_handled()
				_take()
				return
			last_press_time = now
			# Arm a drag from anywhere on the panel.
			if panel.get_global_rect().has_point(event.position):
				drag_armed = true
				drag_from = event.position
				get_viewport().set_input_as_handled()
		else:
			# Release: a drag that ended over the inventory bar takes it.
			if drag_active:
				_end_drag(event.position.y >= BAR_TOP)
				get_viewport().set_input_as_handled()
			else:
				drag_armed = false


func _take() -> void:
	WorldState.interaction_handled = true
	if current_item_id == "":
		_close(true)
		return
	var added: bool
	if current_key_target != "":
		added = WorldState.add_key_to_inventory(current_key_target)
	else:
		var amount = WorldState.get_anchor_amount(current_apartment_id, current_anchor_name)
		if amount <= 0 and ItemData.get_item(current_item_id).get("is_ammo", false):
			amount = _roll_ammo_bundle()
		added = WorldState.add_to_inventory(current_item_id, amount)
	if added:
		WorldState.clear_anchor_item(current_apartment_id, current_anchor_name)
		HUD.refresh_inventory()
		_close(true)
	else:
		name_label.text = "Inventory full"
		hint_label.text = "Drop something first."


func _roll_ammo_bundle() -> int:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "ammobundle" + current_apartment_id + current_anchor_name)
	var weights = [30, 22, 16, 12, 9, 7, 4]  # sizes 2..8
	var roll = rng.randi() % 100
	var acc = 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return i + 2
	return 2


func _close(item_taken: bool) -> void:
	_end_drag(false)
	is_revealing = false
	has_item = false
	visible = false
	WorldState.loot_open = false
	_notify_anchor_closed(item_taken)
	anchor_node = null
	current_key_target = ""
	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("restore_stance"):
		player.restore_stance()


func _notify_anchor_closed(item_taken: bool) -> void:
	if anchor_node != null and is_instance_valid(anchor_node) and anchor_node.has_method("on_loot_closed"):
		anchor_node.on_loot_closed(item_taken)
