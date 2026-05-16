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

var stamina_bar: Control = null
var stamina_segments: Array = []
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
	update_floor_label()
	update_portrait(0)
	update_mode_indicator()
	refresh_inventory()

func _layout() -> void:
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

func update_stamina(current: float, maximum: float) -> void:
	if stamina_segments.is_empty():
		return
	var ratio = current / maximum
	var filled = int(round(ratio * STAMINA_SEGMENTS))
	for i in range(STAMINA_SEGMENTS):
		var seg = stamina_segments[i]
		if i < filled:
			if ratio > 0.5:
				seg.color = Color(0.2, 0.8, 0.4, 1.0)
			elif ratio > 0.25:
				seg.color = Color(0.9, 0.7, 0.1, 1.0)
			else:
				seg.color = Color(0.9, 0.2, 0.2, 1.0)
		else:
			seg.color = Color(0.15, 0.15, 0.15, 1.0)

func _process(delta: float) -> void:
	if feedback_timer > 0:
		feedback_timer -= delta
		var alpha = min(feedback_timer / 0.5, 1.0)
		feedback_label.modulate = Color(1, 1, 0.5, alpha)
		if feedback_timer <= 0:
			feedback_label.modulate = Color(1, 1, 0.5, 0)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var now = Time.get_ticks_msec() / 1000.0
			if last_click_slot == slot_index and (now - last_click_time) < DOUBLE_CLICK_TIME:
				var player = get_tree().get_first_node_in_group("player")
				if player and player.has_method("use_item"):
					player.use_item(slot_index)
				last_click_slot = -1
			else:
				select_slot(slot_index)
				last_click_time = now
				last_click_slot = slot_index
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if slot_index < WorldState.inventory.size():
				show_context_menu(slot_index)

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
		WorldState.remove_from_inventory(context_slot)
		if selected_slot > context_slot:
			selected_slot -= 1
		elif selected_slot == context_slot:
			selected_slot = -1
		_update_slot_highlights()
		refresh_inventory()
		show_feedback("Item discarded.")

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

			# Show durability bar for items with limited uses
			var item_data = ItemData.get_item(item_id)
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
	_update_slot_highlights()

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false

func update_slot(_slot_index: int, _item_id: String) -> void:
	pass
