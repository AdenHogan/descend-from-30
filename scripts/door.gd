extends Area2D

@export var room_scene: String = "res://scenes/room.tscn"
@export var apartment_id: String = "3001"

var player_nearby: bool = false
var current_state: int = -1

# Barricade removal timer
var is_removing_barricade: bool = false
var removal_duration: float = 0.0  # 6.0 or 12.0 depending on tool
var removal_elapsed: float = 0.0   # local mirror of WorldState progress

const BARRICADE_SPRITE_HEIGHT: float = 69.0  # matches Barricade.png height at scale 1

@onready var proximity_label: Label = $ProximityLabel
@onready var door_sprite: Sprite2D = $Sprite2D
@onready var barricade_sprite: Sprite2D = $BarricadeSprite2D
@onready var barricade_progress_overlay: ColorRect = $BarricadeProgressOverlay

# Tint colours per state
const TINT_OPEN                = Color(1.2, 1.2, 0.8, 1.0)
const TINT_SHUT_JIMMYABLE      = Color(1.0, 1.0, 1.0, 1.0)
const TINT_SHUT_LOCKED         = Color(1.4, 0.4, 0.4, 1.0)
const TINT_BARRICADED_J        = Color(1.0, 1.0, 1.0, 1.0)
const TINT_BARRICADED_L        = Color(1.4, 0.4, 0.4, 1.0)
const TINT_BREACHED            = Color(0.9, 0.5, 1.3, 1.0)
const TINT_INACCESSIBLE        = Color(0.3, 0.3, 0.3, 1.0)

const SEALED_APARTMENT = "3001"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false
	barricade_sprite.visible = false
	_setup_progress_overlay()
	_apply_door_state()


func _setup_progress_overlay() -> void:
	# Semi-transparent dark overlay that shrinks top-down as barricade is removed
	# Sits on top of the barricade sprite as a child — position/size set here in code
	# so we don't need to hand-place it in the scene editor
	barricade_progress_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	barricade_progress_overlay.visible = false
	# Overlay covers the full barricade sprite — position relative to barricade_sprite origin
	# Barricade.png is 50x69, sprite is centred so top-left is at (-25, -34.5)
	barricade_progress_overlay.position = Vector2(-25, -35)
	barricade_progress_overlay.size = Vector2(50, BARRICADE_SPRITE_HEIGHT)


func _apply_door_state() -> void:
	if apartment_id == SEALED_APARTMENT:
		door_sprite.modulate = TINT_INACCESSIBLE
		barricade_sprite.visible = false
		barricade_progress_overlay.visible = false
		return

	current_state = WorldState.get_door_state(apartment_id)

	match current_state:
		WorldState.DoorState.OPEN:
			door_sprite.modulate = TINT_OPEN
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false

		WorldState.DoorState.SHUT_JIMMYABLE:
			door_sprite.modulate = TINT_SHUT_JIMMYABLE
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false

		WorldState.DoorState.SHUT_LOCKED:
			door_sprite.modulate = TINT_SHUT_LOCKED
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false

		WorldState.DoorState.BARRICADED_JIMMYABLE:
			door_sprite.modulate = TINT_BARRICADED_J
			barricade_sprite.visible = true
			_sync_overlay_to_progress()

		WorldState.DoorState.BARRICADED_LOCKED:
			door_sprite.modulate = TINT_BARRICADED_L
			barricade_sprite.visible = true
			_sync_overlay_to_progress()

		WorldState.DoorState.BREACHED:
			door_sprite.modulate = TINT_BREACHED
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false


func _sync_overlay_to_progress() -> void:
	# Restore overlay to match saved progress when re-entering collision area
	# or when scene loads with a partially removed barricade
	var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
	if saved <= 0.0:
		barricade_progress_overlay.visible = false
		barricade_progress_overlay.size.y = BARRICADE_SPRITE_HEIGHT
		return

	# Figure out what duration would have been used — check if player has a tool
	# For display purposes we use the longer duration as a safe default;
	# actual duration is set when the player starts/resumes removal
	var display_ratio = saved / _get_removal_duration()
	display_ratio = clamp(display_ratio, 0.0, 1.0)
	var remaining_height = BARRICADE_SPRITE_HEIGHT * (1.0 - display_ratio)
	barricade_progress_overlay.size.y = remaining_height
	barricade_progress_overlay.visible = remaining_height > 1.0


func _get_removal_duration() -> float:
	var slot = HUD.selected_slot
	if slot >= 0 and slot < WorldState.inventory.size():
		var item_data = WorldState.get_instance_at(slot).get_data()
		if item_data.get("is_tool", false) or item_data.get("can_force_lock", false):
			return 6.0
	return 12.0


func _get_prompt_text() -> String:
	if apartment_id == SEALED_APARTMENT:
		return apartment_id + " - Sealed"

	match current_state:
		WorldState.DoorState.OPEN:
			return apartment_id + " - [E] Enter"
		WorldState.DoorState.SHUT_JIMMYABLE:
			return apartment_id + " - [X] Jimmy door"
		WorldState.DoorState.SHUT_LOCKED:
			return apartment_id + " - Locked  [X] Force lock"
		WorldState.DoorState.BARRICADED_JIMMYABLE:
			if is_removing_barricade:
				var remaining = removal_duration - removal_elapsed
				return apartment_id + " - Removing barricade... %.1fs" % remaining
			var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
			if saved > 0.0:
				return apartment_id + " - Barricade damaged  [X] Continue removal"
			return apartment_id + " - Barricaded  [X] Remove barricade"
		WorldState.DoorState.BARRICADED_LOCKED:
			if is_removing_barricade:
				var remaining = removal_duration - removal_elapsed
				return apartment_id + " - Removing barricade... %.1fs" % remaining
			var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
			if saved > 0.0:
				return apartment_id + " - Barricade damaged  [X] Continue removal"
			return apartment_id + " - Barricaded + Locked  [X] Remove barricade"
		WorldState.DoorState.BREACHED:
			return apartment_id + " - BREACHED  [E] Enter"
	return apartment_id


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		# Sync overlay to saved progress when player re-enters range
		if current_state == WorldState.DoorState.BARRICADED_JIMMYABLE or \
		   current_state == WorldState.DoorState.BARRICADED_LOCKED:
			_sync_overlay_to_progress()
		proximity_label.text = _get_prompt_text()
		proximity_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		proximity_label.visible = false
		# Freeze removal — save progress and stop timer
		if is_removing_barricade:
			is_removing_barricade = false
			WorldState.barricade_progress[apartment_id] = removal_elapsed
			# Overlay stays at current position — frozen visually


func _process(delta: float) -> void:
	if not player_nearby:
		return

	if apartment_id == SEALED_APARTMENT:
		return

	# Update barricade removal timer
	if is_removing_barricade:
		removal_elapsed += delta
		WorldState.barricade_progress[apartment_id] = removal_elapsed

		# Update overlay — shrink from top down
		var progress_ratio = clamp(removal_elapsed / removal_duration, 0.0, 1.0)
		var remaining_height = BARRICADE_SPRITE_HEIGHT * (1.0 - progress_ratio)
		barricade_progress_overlay.size.y = remaining_height
		barricade_progress_overlay.visible = remaining_height > 1.0

		proximity_label.text = _get_prompt_text()

		if removal_elapsed >= removal_duration:
			_finish_barricade_removal()
			return

	proximity_label.text = _get_prompt_text()

	# E to enter — always available regardless of mode
	if Input.is_action_just_pressed("interact"):
		match current_state:
			WorldState.DoorState.OPEN, WorldState.DoorState.BREACHED:
				_enter_apartment()

	# Obstacle interactions require scavenge mode
	if not WorldState.is_scavenge_mode:
		return

	if Input.is_action_just_pressed("item_context"):
		match current_state:
			WorldState.DoorState.SHUT_JIMMYABLE:
				_attempt_jimmy()
			WorldState.DoorState.SHUT_LOCKED:
				_attempt_locked()
			WorldState.DoorState.BARRICADED_JIMMYABLE, WorldState.DoorState.BARRICADED_LOCKED:
				_attempt_barricade_removal()


func _enter_apartment() -> void:
	if WorldState.interaction_handled:
		return
	WorldState.interaction_handled = true
	WorldState.current_apartment_id = apartment_id
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = global_position.x
	get_tree().change_scene_to_file(room_scene)


func _attempt_jimmy() -> void:
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		HUD.show_feedback("Equip a weapon to jimmy the door.")
		return

	var instance = WorldState.get_instance_at(slot)
	var item_data = instance.get_data()

	if not item_data.get("is_weapon", false) and not item_data.get("can_force_lock", false):
		HUD.show_feedback("Need a weapon or tool to jimmy this.")
		return

	instance.use()
	instance.use()
	HUD.refresh_inventory()

	if instance.is_depleted:
		var weapon_name = item_data.get("name", "Item")
		WorldState.remove_from_inventory(slot)
		HUD.selected_slot = -1
		HUD.refresh_inventory()
		HUD.show_feedback(weapon_name + " broke forcing the door!")
	else:
		HUD.show_feedback("Door forced open.")

	WorldState.set_door_state(apartment_id, WorldState.DoorState.OPEN)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()
	# TODO: trigger noise event


func _attempt_locked() -> void:
	var key_slot = _find_key_for_apartment()
	if key_slot >= 0:
		_use_key(key_slot)
		return

	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		HUD.show_feedback("Locked. Need a key or force-lock weapon.")
		return

	var instance = WorldState.get_instance_at(slot)
	var item_data = instance.get_data()

	if not item_data.get("can_force_lock", false):
		HUD.show_feedback("Need a key or a weapon that can force locks.")
		return

	for i in range(4):
		if not instance.is_depleted:
			instance.use()
	HUD.refresh_inventory()

	if instance.is_depleted:
		var weapon_name = item_data.get("name", "Item")
		WorldState.remove_from_inventory(slot)
		HUD.selected_slot = -1
		HUD.refresh_inventory()
		HUD.show_feedback(weapon_name + " broke forcing the lock!")
	else:
		HUD.show_feedback("Lock forced.")

	WorldState.set_door_state(apartment_id, WorldState.DoorState.OPEN)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()
	# TODO: trigger noise event


func _attempt_barricade_removal() -> void:
	if is_removing_barricade:
		return  # already in progress

	removal_duration = _get_removal_duration()
	# Resume from saved progress if any
	removal_elapsed = WorldState.barricade_progress.get(apartment_id, 0.0)
	is_removing_barricade = true

	# Show overlay immediately at correct position
	_sync_overlay_to_progress()
	barricade_progress_overlay.visible = true
	proximity_label.text = _get_prompt_text()


func _finish_barricade_removal() -> void:
	is_removing_barricade = false
	WorldState.barricade_progress.erase(apartment_id)
	barricade_progress_overlay.visible = false
	barricade_sprite.visible = false

	var underlying_state = WorldState.DoorState.SHUT_JIMMYABLE
	if current_state == WorldState.DoorState.BARRICADED_LOCKED:
		underlying_state = WorldState.DoorState.SHUT_LOCKED

	WorldState.set_door_state(apartment_id, underlying_state)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()
	HUD.show_feedback("Barricade removed.")
	# TODO: trigger noise event, possibly spawn zombie


func _use_key(key_slot: int) -> void:
	WorldState.remove_from_inventory(key_slot)
	HUD.refresh_inventory()
	WorldState.consume_key_for_apartment(apartment_id)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()
	HUD.show_feedback("Door unlocked.")


func _find_key_for_apartment() -> int:
	for i in range(WorldState.inventory.size()):
		var item_data = ItemData.get_item(WorldState.get_item_id_at(i))
		if item_data.get("is_key", false):
			return i
	return -1
