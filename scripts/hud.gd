extends CanvasLayer

const PORTRAITS = [
	preload("res://assets/Health_Bar/1 - Healthy.png"),
	preload("res://assets/Health_Bar/2 - Hurt.png"),
	preload("res://assets/Health_Bar/3 - Injured.png"),
	preload("res://assets/Health_Bar/4 - Wounded.png"),
	preload("res://assets/Health_Bar/5 - Severely Wounded.png"),
	preload("res://assets/Health_Bar/6 - Dying.png")
]

@onready var portrait = $Control/Portrait
@onready var floor_label = $Control/FloorLabel
@onready var color_rect = $Control/ColorRect
@onready var hbox = $Control/HBoxContainer
@onready var slots = [
	$Control/HBoxContainer/Slot1,
	$Control/HBoxContainer/Slot2,
	$Control/HBoxContainer/Slot3,
	$Control/HBoxContainer/Slot4,
	$Control/HBoxContainer/Slot5
]
@onready var slot_locked = $Control/HBoxContainer/SlotLocked

var mode_label: Label = null
var slot_icons: Array = []
var slot_durability_bars: Array = []
var selected_slot: int = -1
var feedback_label: Label = null
var feedback_timer: float = 0.0
var context_menu: Control = null
var context_slot: int = -1
var last_click_time: float = 0.0
var last_click_slot: int = -1
const DOUBLE_CLICK_TIME = 0.4
var slot_key_labels: Array = []

# Drag-and-drop inventory: hold LMB on a slot and move to drag its item.
# Drop on another slot to swap; bullets onto a gun (or gun onto bullets)
# loads the magazine; drop on the game world to discard.
const DRAG_THRESHOLD = 6.0
var drag_from: int = -1
var drag_armed_pos: Vector2 = Vector2.ZERO
var drag_active: bool = false
var drag_icon: TextureRect = null

var stamina_bar: Control = null
var stamina_segments: Array = []
var wallet_label: Label = null
var listen_overlay: CanvasLayer = null
const STAMINA_SEGMENTS = 8
const STAMINA_BAR_W = 14.0
const STAMINA_BAR_H = 60.0

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const BAR_H = 80.0
const SLOT_SIZE = 64.0

func _ready() -> void:
	_layout()
	_create_mode_label()
	_create_slot_icons()
	_create_feedback_label()
	_create_context_menu()
	_create_stamina_bar()
	_create_wallet_label()
	_create_dev_warp_prompt()
	# Listen-mode grey/ping/report overlay (own CanvasLayer above the HUD).
	listen_overlay = preload("res://scripts/listen_overlay.gd").new()
	add_child(listen_overlay)
	update_floor_label()
	update_portrait(0)
	update_mode_indicator()
	refresh_inventory()

func _layout() -> void:
	# The root Control spans the whole screen: it must NOT swallow mouse
	# events or click-to-move/world clicks never reach the game (playtest
	# bug). Children (slots, buttons) keep their own filters and stay
	# clickable.
	$Control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchor_and_offset(SIDE_TOP, 0, SCREEN_H - BAR_H - 40)
	color_rect.set_anchor_and_offset(SIDE_BOTTOM, 0, SCREEN_H)
	color_rect.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	color_rect.set_anchor_and_offset(SIDE_RIGHT, 0, SCREEN_W)
	color_rect.color = Color(0.1, 0.1, 0.1, 0.9)

	floor_label.position = Vector2(SCREEN_W - 200, SCREEN_H - BAR_H + 18)
	floor_label.size = Vector2(100, 50)

	hbox.position = Vector2(SCREEN_W - (SLOT_SIZE + 8) * 6, SCREEN_H - BAR_H + 8)
	hbox.add_theme_constant_override("separation", 8)
	for slot in slots:
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", _make_slot_style(false))
	slot_locked.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_locked.add_theme_stylebox_override("panel", _make_slot_style(true))
	slot_locked.modulate = Color(0.3, 0.3, 0.3, 1.0)

func _create_mode_label() -> void:
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_label.position = Vector2(SCREEN_W - 258, SCREEN_H - BAR_H - 10)
	mode_label.size = Vector2(180, 40)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Control.add_child(mode_label)

func _create_slot_icons() -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchors_preset = Control.PRESET_CENTER
		icon.visible = false
		slot.add_child(icon)
		slot_icons.append(icon)

		# Durability bar — thin strip at bottom of slot
		var dur_bg = ColorRect.new()
		dur_bg.size = Vector2(SLOT_SIZE - 4, 4)
		dur_bg.position = Vector2(2, SLOT_SIZE - 6)
		dur_bg.color = Color(0.2, 0.2, 0.2, 1.0)
		dur_bg.visible = false
		slot.add_child(dur_bg)

		var dur_fill = ColorRect.new()
		dur_fill.size = Vector2(SLOT_SIZE - 4, 4)
		dur_fill.position = Vector2(2, SLOT_SIZE - 6)
		dur_fill.color = Color(0.2, 0.8, 0.2, 1.0)
		dur_fill.visible = false
		slot.add_child(dur_fill)
		
		var key_label = Label.new()
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))
		key_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
		key_label.add_theme_constant_override("outline_size", 2)
		key_label.position = Vector2(2, 2)
		key_label.size = Vector2(SLOT_SIZE - 4, 16)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.visible = false
		slot.add_child(key_label)
		slot_key_labels.append(key_label)

		slot_durability_bars.append({"bg": dur_bg, "fill": dur_fill})

		slot.gui_input.connect(_on_slot_gui_input.bind(i))

func _create_feedback_label() -> void:
	feedback_label = Label.new()
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.position = Vector2(SCREEN_W / 2 - 100, SCREEN_H - BAR_H - 35)
	feedback_label.size = Vector2(200, 30)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.modulate = Color(1, 1, 0.5, 0)
	$Control.add_child(feedback_label)

func _create_context_menu() -> void:
	context_menu = PanelContainer.new()
	context_menu.visible = false
	var vbox = VBoxContainer.new()
	context_menu.add_child(vbox)

	var use_btn = Button.new()
	use_btn.text = "Use"
	use_btn.pressed.connect(_context_use)
	vbox.add_child(use_btn)

	var discard_btn = Button.new()
	discard_btn.text = "Discard"
	discard_btn.pressed.connect(_context_discard)
	vbox.add_child(discard_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_context_cancel)
	vbox.add_child(cancel_btn)

	$Control.add_child(context_menu)

func _create_stamina_bar() -> void:
	stamina_bar = Control.new()
	stamina_bar.position = Vector2(8, SCREEN_H - BAR_H + 10)
	stamina_bar.size = Vector2(STAMINA_BAR_W, STAMINA_BAR_H)
	$Control.add_child(stamina_bar)

	var segment_h = (STAMINA_BAR_H - (STAMINA_SEGMENTS - 1) * 2) / STAMINA_SEGMENTS
	for i in range(STAMINA_SEGMENTS):
		var seg = ColorRect.new()
		seg.size = Vector2(STAMINA_BAR_W, segment_h)
		seg.position = Vector2(0, STAMINA_BAR_H - (i + 1) * (segment_h + 2))
		seg.color = Color(0.2, 0.8, 0.4, 1.0)
		stamina_bar.add_child(seg)
		stamina_segments.append(seg)

func _create_wallet_label() -> void:
	wallet_label = Label.new()
	wallet_label.add_theme_font_size_override("font_size", 12)
	wallet_label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55, 1.0))
	wallet_label.position = Vector2(SCREEN_W - (SLOT_SIZE + 8) * 6 - 8, SCREEN_H - BAR_H - 16)
	wallet_label.size = Vector2((SLOT_SIZE + 8) * 6, 16)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_label.visible = false
	$Control.add_child(wallet_label)
	update_wallet()


func _create_dev_warp_prompt() -> void:
	# DEV: F6 floor-warp prompt (see dev_warp_prompt.gd). Lives on the HUD
	# layer so it exists in every gameplay scene.
	var warp = preload("res://scripts/dev_warp_prompt.gd").new()
	$Control.add_child(warp)


func update_wallet() -> void:
	if wallet_label == null:
		return
	wallet_label.visible = WorldState.wallet_unlocked
	wallet_label.text = "WALLET  " + str(WorldState.wallet_balance)


func update_stamina(current: float, maximum: float) -> void:
	if stamina_segments.is_empty():
		return
	var ratio = current / maximum
	var filled = int(round(ratio * STAMINA_SEGMENTS))
	# All filled bars share one colour, chosen by how many bars are filled:
	# 1-2 = red, 3-4 = yellow, 5+ = green. Avoids per-segment gradient flicker.
	var band: Color
	if filled <= 2:
		band = Color(0.9, 0.2, 0.2, 1.0)
	elif filled <= 4:
		band = Color(0.9, 0.7, 0.1, 1.0)
	else:
		band = Color(0.2, 0.8, 0.4, 1.0)
	for i in range(STAMINA_SEGMENTS):
		if i < filled:
			stamina_segments[i].color = band
		else:
			stamina_segments[i].color = Color(0.15, 0.15, 0.15, 1.0)

func _process(delta: float) -> void:
	_update_drag()
	if feedback_timer > 0:
		feedback_timer -= delta
		var alpha = min(feedback_timer / 0.5, 1.0)
		feedback_label.modulate = Color(1, 1, 0.5, alpha)
		if feedback_timer <= 0:
			feedback_label.modulate = Color(1, 1, 0.5, 0)

	# Close context menu on click outside
	if context_menu and context_menu.visible:
		if Input.is_action_just_pressed("interact") or \
		   (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
		   not context_menu.get_global_rect().has_point(get_viewport().get_mouse_position())):
			context_menu.visible = false

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Arm a potential drag; the actual drag start / drop / cancel is driven
		# by mouse polling in _process, since a slot's gui_input stops firing
		# once the cursor leaves it. A plain press (no drag) still selects, and
		# a double-press still uses the item.
		if slot_index < WorldState.inventory.size():
			drag_from = slot_index
			drag_armed_pos = get_viewport().get_mouse_position()
		var now = Time.get_ticks_msec() / 1000.0
		if last_click_slot == slot_index and (now - last_click_time) < DOUBLE_CLICK_TIME:
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("use_item"):
				player.use_item(slot_index)
			last_click_slot = -1
			drag_from = -1
		else:
			select_slot(slot_index)
			last_click_time = now
			last_click_slot = slot_index
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_index < WorldState.inventory.size():
			show_context_menu(slot_index)


func _update_drag() -> void:
	# Whole drag lifecycle, polled so it survives the cursor leaving the slot.
	if drag_from < 0:
		return
	var held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not drag_active:
		if not held:
			drag_from = -1  # released without moving — it was just a click
			return
		if get_viewport().get_mouse_position().distance_to(drag_armed_pos) > DRAG_THRESHOLD:
			_start_drag()
	else:
		drag_icon.position = get_viewport().get_mouse_position() - Vector2(24, 24)
		if not held:
			_finish_drag()


func _start_drag() -> void:
	drag_active = true
	drag_icon = TextureRect.new()
	drag_icon.texture = ItemData.get_texture(WorldState.get_item_id_at(drag_from))
	drag_icon.custom_minimum_size = Vector2(48, 48)
	drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_icon.modulate = Color(1, 1, 1, 0.8)
	$Control.add_child(drag_icon)


func _finish_drag() -> void:
	drag_active = false
	if drag_icon != null:
		drag_icon.queue_free()
		drag_icon = null
	var from = drag_from
	drag_from = -1
	if from < 0 or from >= WorldState.inventory.size():
		return
	var mouse = get_viewport().get_mouse_position()
	# Dropped on another slot?
	for i in range(slots.size()):
		if slots[i].get_global_rect().has_point(mouse) and i != from:
			_drop_on_slot(from, i)
			return
	# Dropped on the game world (above the HUD bar) = discard.
	if mouse.y < SCREEN_H - BAR_H - 40:
		_discard_slot(from)


func _drop_on_slot(from: int, to: int) -> void:
	var from_inst = WorldState.get_instance_at(from)
	var from_data = from_inst.get_data()
	# Dropping onto an empty slot reorders to the end.
	if to >= WorldState.inventory.size():
		WorldState.move_inventory_slot_to_end(from)
		refresh_inventory()
		return
	# Bullets onto a gun (either direction) load the magazine.
	if to < WorldState.inventory.size():
		var to_inst = WorldState.get_instance_at(to)
		var to_data = to_inst.get_data()
		var gun_inst: ItemInstance = null
		if from_data.get("is_ammo", false) and to_data.get("name", "").to_lower().contains("gun"):
			gun_inst = to_inst
		elif to_data.get("is_ammo", false) and from_data.get("name", "").to_lower().contains("gun"):
			gun_inst = from_inst
		if gun_inst != null:
			var loaded = WorldState.reload_gun(gun_inst)
			if loaded > 0:
				show_feedback("Loaded %d — mag %d/%d." % [loaded, gun_inst.mag_count, gun_inst.get_mag_cap()])
			else:
				show_feedback("Magazine full." if gun_inst.mag_count >= gun_inst.get_mag_cap() else "No bullets to load.")
			return
	WorldState.swap_inventory_slots(from, to)
	refresh_inventory()


func _discard_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= WorldState.inventory.size():
		return
	var instance = WorldState.get_instance_at(slot_index)
	var item_data = instance.get_data()
	if not instance.is_depleted:
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var drop_pos = player.global_position + Vector2(randf_range(-20, 20), 0)
			var extra = {}
			if instance.target_apartment != "":
				extra["target_apartment"] = instance.target_apartment
			WorldState.add_world_drop(instance.item_id, drop_pos, WorldState.current_floor, extra)
	if selected_slot > slot_index:
		selected_slot -= 1
	elif selected_slot == slot_index:
		selected_slot = -1
	WorldState.remove_from_inventory(slot_index)
	_update_slot_highlights()
	refresh_inventory()
	show_feedback(item_data.get("name", "Item") + " dropped.")

func select_slot(index: int) -> void:
	if selected_slot == index:
		selected_slot = -1
	else:
		selected_slot = index
	_update_slot_highlights()
	context_menu.visible = false

func _update_slot_highlights() -> void:
	for i in range(slots.size()):
		if i == selected_slot:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style_selected())
		else:
			slots[i].add_theme_stylebox_override("panel", _make_slot_style(false))

func _make_slot_style_selected() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.1, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(1.0, 1.0, 0.2, 1.0)
	return style

func show_context_menu(slot_index: int) -> void:
	context_slot = slot_index
	var slot_pos = slots[slot_index].global_position
	context_menu.position = Vector2(slot_pos.x, slot_pos.y - 100)
	context_menu.visible = true

func _context_use() -> void:
	context_menu.visible = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("use_item"):
		player.use_item(context_slot)

func _context_discard() -> void:
	context_menu.visible = false
	if context_slot >= 0 and context_slot < WorldState.inventory.size():
		var instance = WorldState.get_instance_at(context_slot)
		var item_data = instance.get_data()
		var is_broken = item_data.get("is_weapon", false) and instance.is_depleted
		var is_consumed = not item_data.get("is_weapon", false) and instance.is_depleted
		if not is_broken and not is_consumed:
			var player = get_tree().get_first_node_in_group("player")
			if player != null:
				var drop_pos = player.global_position + Vector2(randf_range(-20, 20), 0)
				var extra = {}
				if instance.target_apartment != "":
					extra["target_apartment"] = instance.target_apartment
				WorldState.add_world_drop(instance.item_id, drop_pos, WorldState.current_floor, extra)
		if selected_slot > context_slot:
			selected_slot -= 1
		elif selected_slot == context_slot:
			selected_slot = -1
		WorldState.remove_from_inventory(context_slot)
		_update_slot_highlights()
		refresh_inventory()
		show_feedback("Item dropped.")

func _context_cancel() -> void:
	context_menu.visible = false

func show_feedback(text: String) -> void:
	feedback_label.text = text
	feedback_timer = 2.0
	feedback_label.modulate = Color(1, 1, 0.5, 1)

func _make_slot_style(locked: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.25, 1.0) if not locked else Color(0.15, 0.15, 0.15, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.6, 0.6, 0.6, 1.0) if not locked else Color(0.35, 0.35, 0.35, 1.0)
	return style

func update_floor_label() -> void:
	floor_label.text = "FLOOR:\n" + str(WorldState.current_floor) + " / 30"

func update_portrait(health_index: int) -> void:
	if portrait == null:
		return
	portrait.texture = PORTRAITS[health_index]

func update_mode_indicator() -> void:
	if mode_label == null:
		return
	if WorldState.is_scavenge_mode:
		mode_label.text = "[ SCAVENGE ]"
		mode_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		mode_label.text = "[ COMBAT ]"
		mode_label.modulate = Color(1.0, 0.3, 0.3, 1.0)

func refresh_inventory() -> void:
	for i in range(slots.size()):
		var dur = slot_durability_bars[i]
		if i < WorldState.inventory.size():
			var instance = WorldState.inventory[i]
			var item_id = instance.item_id
			var texture = ItemData.get_texture(item_id)
			if texture != null:
				slot_icons[i].texture = texture
				slot_icons[i].visible = true
			else:
				slot_icons[i].visible = false

			var item_data = ItemData.get_item(item_id)

			var key_label = slot_key_labels[i]
			var item_name_l = item_data.get("name", "").to_lower()
			if item_data.get("is_key", false) and instance.target_apartment != "":
				key_label.text = instance.target_apartment
				key_label.visible = true
			elif item_data.get("is_money", false) or item_data.get("is_ammo", false):
				key_label.text = "x" + str(instance.count)
				key_label.visible = true
			elif item_data.get("is_weapon", false) and item_name_l.contains("gun"):
				key_label.text = "%d/%d" % [instance.mag_count, instance.get_mag_cap()]
				key_label.visible = true
			else:
				key_label.visible = false

			var max_dur = item_data.get("max_durability", -1)
			if max_dur > 0 and not item_data.get("single_use", false):
				var ratio = float(instance.current_durability) / float(max_dur)
				dur["bg"].visible = true
				dur["fill"].visible = true
				dur["fill"].size.x = (SLOT_SIZE - 4) * ratio
				if ratio > 0.5:
					dur["fill"].color = Color(0.2, 0.8, 0.2, 1.0)
				elif ratio > 0.25:
					dur["fill"].color = Color(0.9, 0.7, 0.1, 1.0)
				else:
					dur["fill"].color = Color(0.9, 0.2, 0.2, 1.0)
			else:
				dur["bg"].visible = false
				dur["fill"].visible = false
		else:
			slot_icons[i].visible = false
			dur["bg"].visible = false
			dur["fill"].visible = false
			slot_key_labels[i].visible = false
	_update_slot_highlights()

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false
