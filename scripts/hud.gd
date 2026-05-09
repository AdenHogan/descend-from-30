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

const SCREEN_W = 1152.0
const SCREEN_H = 648.0
const BAR_H = 80.0
const SLOT_SIZE = 64.0

func _ready() -> void:
	_layout()
	update_floor_label()
	update_portrait(0)

func _layout() -> void:
	color_rect.position = Vector2(0, SCREEN_H - BAR_H - 40)
	color_rect.size = Vector2(SCREEN_W, BAR_H + 40)
	color_rect.color = Color(0.1, 0.1, 0.1, 0.9)

	floor_label.position = Vector2(65, SCREEN_H - BAR_H + 18)
	floor_label.size = Vector2(100, 50)
	floor_label.position = Vector2(SCREEN_W - 200, SCREEN_H - BAR_H + 18)

	hbox.position = Vector2(SCREEN_W - (SLOT_SIZE + 8) * 6, SCREEN_H - BAR_H + 8)
	hbox.add_theme_constant_override("separation", 8)
	for slot in slots:
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.add_theme_stylebox_override("panel", _make_slot_style(false))
	slot_locked.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot_locked.add_theme_stylebox_override("panel", _make_slot_style(true))
	slot_locked.modulate = Color(0.3, 0.3, 0.3, 1.0)

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

func show_hud() -> void:
	visible = true

func hide_hud() -> void:
	visible = false

func update_slot(_slot_index: int, _item_id: String) -> void:
	pass
