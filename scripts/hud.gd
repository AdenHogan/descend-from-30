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

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const BAR_H = 80.0
const SLOT_SIZE = 64.0

func _ready() -> void:
	_layout()
	_create_mode_label()
	_create_slot_icons()
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
	for slot in slots:
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchors_preset = Control.PRESET_CENTER
		icon.visible = false
		slot.add_child(icon)
		slot_icons.append(icon)

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
		if i < WorldState.inventory.size():
			var item_id = WorldState.inventory[i]
			var texture = ItemData.get_texture(item_id)
			if texture != null:
				slot_icons[i].texture = texture
				slot_icons[i].visible = true
			else:
				slot_icons[i].visible = false
		else:
			slot_icons[i].visible = false

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false

func update_slot(_slot_index: int, _item_id: String) -> void:
	pass
