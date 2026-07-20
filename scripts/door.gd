extends Area2D

@export var room_scene: String = "res://scenes/room.tscn"
@export var apartment_id: String = "3001"

var player_nearby: bool = false
var current_state: int = -1

# Barricade removal state.
# Progress is stored as a FRACTION complete (0.0–1.0) in WorldState.barricade_progress,
# NOT as elapsed seconds. This lets a tool→bare-hands switch rescale the remaining time
# correctly: 60% done with a tool stays 60% done when you resume bare-handed, it just
# maps onto the longer bare-hands duration.
var is_removing_barricade: bool = false
var removal_duration: float = 0.0      # seconds for a full 0→1 removal at the current tier
var removal_fraction: float = 0.0      # 0.0–1.0 progress

# Durability / stamina bookkeeping for the active removal
var removal_tool_instance: ItemInstance = null
var removal_uses_tool: bool = false
var removal_durability_spent: int = 0
var removal_stamina_start: float = 0.0
var removal_stamina_total: float = 0.0

const BARRICADE_SPRITE_HEIGHT: float = 69.0

# ── Barricade tuning ────────────────────────────────────────────────────────
# Pre-upgrade durations. The upgrade tree will later swap these for the upgraded
# pair (TOOL 6.0 / BARE 9.0) — keep them here as the single source of truth.
const BARRICADE_TIME_TOOL: float = 9.0
const BARRICADE_TIME_BARE: float = 12.0
# Durability cost of a full tool-assisted removal (double a 1-use force/attack).
const BARRICADE_DURABILITY_COST: int = 2
# Stamina drained over a full removal, as a fraction of max stamina. Chosen so a
# full-stamina player never bottoms out on a single ≤12s removal.
const BARRICADE_STAMINA_FRACTION_TOOL: float = 1.0 / 3.0
const BARRICADE_STAMINA_FRACTION_BARE: float = 1.0 / 2.0
# ────────────────────────────────────────────────────────────────────────────

@onready var proximity_label: Label = $ProximityLabel
@onready var door_sprite: Sprite2D = $Sprite2D
@onready var barricade_sprite: Sprite2D = $BarricadeSprite2D
@onready var barricade_progress_overlay: ColorRect = $BarricadeProgressOverlay

const PLANK_STREAMS = [
	preload("res://assets/audio/impacts/impactPlank_medium_000.ogg"),
	preload("res://assets/audio/impacts/impactPlank_medium_001.ogg"),
	preload("res://assets/audio/impacts/impactPlank_medium_002.ogg"),
	preload("res://assets/audio/impacts/impactPlank_medium_003.ogg"),
	preload("res://assets/audio/impacts/impactPlank_medium_004.ogg"),
]
const FORCE_STREAMS = [
	preload("res://assets/audio/impacts/impactWood_heavy_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_heavy_002.ogg"),
]
const LATCH_STREAM = preload("res://assets/audio/doors/metalLatch.ogg")
var sfx_player: AudioStreamPlayer2D = null
var rip_sfx_timer: float = 0.0

const TINT_OPEN                = Color(1.2, 1.2, 0.8, 1.0)
const TINT_SHUT_FORCEABLE      = Color(1.0, 1.0, 1.0, 1.0)
const TINT_SHUT_LOCKED         = Color(1.4, 0.4, 0.4, 1.0)
const TINT_BARRICADED_F        = Color(1.0, 1.0, 1.0, 1.0)
const TINT_BARRICADED_L        = Color(1.4, 0.4, 0.4, 1.0)
const TINT_BREACHED            = Color(0.9, 0.5, 1.3, 1.0)
const TINT_INACCESSIBLE        = Color(0.3, 0.3, 0.3, 1.0)


func _is_sealed() -> bool:
	return apartment_id == "3001" and WorldState.current_floor == 30


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	proximity_label.visible = false
	barricade_sprite.visible = false
	_migrate_legacy_progress()
	_setup_progress_overlay()
	_apply_door_state()
	sfx_player = AudioStreamPlayer2D.new()
	sfx_player.max_distance = 700.0
	add_child(sfx_player)


func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	sfx_player.stream = stream
	sfx_player.volume_db = volume_db
	sfx_player.pitch_scale = randf_range(0.9, 1.1)
	sfx_player.play()


# One-time migration: older saves stored barricade_progress as elapsed SECONDS.
# Any value > 1.0 can only be legacy seconds (a fraction is 0–1), so convert it
# against the old bare-hands duration (the previous maximum) into a fraction.
func _migrate_legacy_progress() -> void:
	var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
	if saved > 1.0:
		WorldState.barricade_progress[apartment_id] = clamp(saved / BARRICADE_TIME_BARE, 0.0, 1.0)


func _setup_progress_overlay() -> void:
	barricade_progress_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	barricade_progress_overlay.visible = false
	barricade_progress_overlay.position = Vector2(-25, -35)
	barricade_progress_overlay.size = Vector2(50, BARRICADE_SPRITE_HEIGHT)


func _apply_door_state() -> void:
	if _is_sealed():
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

		WorldState.DoorState.SHUT_FORCEABLE:
			door_sprite.modulate = TINT_SHUT_FORCEABLE
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false

		WorldState.DoorState.SHUT_LOCKED:
			door_sprite.modulate = TINT_SHUT_LOCKED
			barricade_sprite.visible = false
			barricade_progress_overlay.visible = false

		WorldState.DoorState.BARRICADED_FORCEABLE:
			door_sprite.modulate = TINT_BARRICADED_F
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
	# Stored value is already a 0–1 fraction.
	var frac = clamp(WorldState.barricade_progress.get(apartment_id, 0.0), 0.0, 1.0)
	if frac <= 0.0:
		barricade_progress_overlay.visible = false
		barricade_progress_overlay.size.y = BARRICADE_SPRITE_HEIGHT
		return
	var remaining_height = BARRICADE_SPRITE_HEIGHT * (1.0 - frac)
	barricade_progress_overlay.size.y = remaining_height
	barricade_progress_overlay.visible = remaining_height > 1.0


# Whether the currently selected item can serve as a barricade-removal tool.
# No is_melee flag exists, so "tool" = any equipped weapon/tool/force-lock item.
# Bare hands = nothing valid equipped.
func _has_removal_tool() -> bool:
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		return false
	var d = WorldState.get_instance_at(slot).get_data()
	return d.get("is_weapon", false) or d.get("is_tool", false) or d.get("can_force_lock", false)


func _get_removal_duration() -> float:
	return BARRICADE_TIME_TOOL if _has_removal_tool() else BARRICADE_TIME_BARE


func _get_prompt_text() -> String:
	if _is_sealed():
		return apartment_id + " - Sealed"
	return _base_prompt_text() + "  [R] Listen"


func _base_prompt_text() -> String:
	match current_state:
		WorldState.DoorState.OPEN:
			return apartment_id + " - [E] Enter"
		WorldState.DoorState.SHUT_FORCEABLE:
			return apartment_id + " - [X] Force door"
		WorldState.DoorState.SHUT_LOCKED:
			var has_key = _find_key_for_apartment() >= 0
			var has_force = false
			var slot = HUD.selected_slot
			if slot >= 0 and slot < WorldState.inventory.size():
				var item_data = ItemData.get_item(WorldState.get_item_id_at(slot))
				has_force = item_data.get("can_force_lock", false)
			if has_key:
				return apartment_id + " - [X] Use key"
			elif has_force:
				return apartment_id + " - Locked  [X] Force lock"
			else:
				return apartment_id + " - Locked  Needs key"
		WorldState.DoorState.BARRICADED_FORCEABLE:
			if is_removing_barricade:
				var remaining = removal_duration * (1.0 - removal_fraction)
				return apartment_id + " - Removing barricade... %.1fs" % remaining
			var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
			if saved > 0.0:
				return apartment_id + " - Barricade damaged  [X] Continue removal"
			return apartment_id + " - Barricaded  [X] Remove barricade"
		WorldState.DoorState.BARRICADED_LOCKED:
			if is_removing_barricade:
				var remaining = removal_duration * (1.0 - removal_fraction)
				return apartment_id + " - Removing barricade... %.1fs" % remaining
			var saved = WorldState.barricade_progress.get(apartment_id, 0.0)
			if saved > 0.0:
				return apartment_id + " - Barricade damaged  [X] Continue removal"
			return apartment_id + " - Barricaded + Locked  [X] Remove barricade"
		WorldState.DoorState.BREACHED:
			return apartment_id + " - BREACHED  [E] Enter"
	return apartment_id


func _prompt_should_show() -> bool:
	# OPEN / BREACHED / sealed prompts always show (basic traversal). Force / lock /
	# barricade prompts only show in scavenge mode, matching where the action works.
	if _is_sealed():
		return true
	match current_state:
		WorldState.DoorState.OPEN, WorldState.DoorState.BREACHED:
			return true
		_:
			return WorldState.is_scavenge_mode


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = true
		if current_state == WorldState.DoorState.BARRICADED_FORCEABLE or \
		   current_state == WorldState.DoorState.BARRICADED_LOCKED:
			_sync_overlay_to_progress()
		proximity_label.text = _get_prompt_text()
		proximity_label.visible = _prompt_should_show()


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_nearby = false
		proximity_label.visible = false
		if is_removing_barricade:
			_pause_barricade_removal()


func _process(delta: float) -> void:
	if not player_nearby:
		return

	if _is_sealed():
		return

	if is_removing_barricade:
		_tick_barricade_removal(delta)
		if not is_removing_barricade:
			return

	proximity_label.text = _get_prompt_text()
	proximity_label.visible = _prompt_should_show()

	if Input.is_action_just_pressed("interact"):
		match current_state:
			WorldState.DoorState.OPEN, WorldState.DoorState.BREACHED:
				_enter_apartment()

	# Listen works in BOTH modes — sound is a first-class read, not a
	# scavenge-only action (docs/SOUND_STEALTH.md).
	if Input.is_action_just_pressed("listen"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("start_listen"):
			var report = WorldState.get_listen_report_for_apartment(apartment_id)
			player.start_listen(global_position, report)

	# Force / lock / barricade require scavenge mode — forces the player to commit
	# to a vulnerable stance to interact with doors.
	if not WorldState.is_scavenge_mode:
		return

	if Input.is_action_just_pressed("item_context"):
		match current_state:
			WorldState.DoorState.SHUT_FORCEABLE:
				_attempt_force()
			WorldState.DoorState.SHUT_LOCKED:
				_attempt_locked()
			WorldState.DoorState.BARRICADED_FORCEABLE, WorldState.DoorState.BARRICADED_LOCKED:
				_attempt_barricade_removal()


func _enter_apartment() -> void:
	if WorldState.interaction_handled:
		return
	WorldState.interaction_handled = true
	WorldState.current_apartment_id = apartment_id
	WorldState.spawn_source = "door"
	WorldState.exit_spawn_x = global_position.x
	get_tree().change_scene_to_file(room_scene)


# Forcing a door costs exactly ONE use — same as a combat swing.
func _attempt_force() -> void:
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		HUD.show_feedback("Equip a weapon to force the door.")
		return

	var instance = WorldState.get_instance_at(slot)
	var item_data = instance.get_data()

	if not item_data.get("is_weapon", false) and not item_data.get("can_force_lock", false):
		HUD.show_feedback("Need a weapon or tool to force this.")
		return

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
	WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["door_work"], 4.0)
	_play_sfx(FORCE_STREAMS.pick_random(), -2.0)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()


# Forcing a lock costs exactly ONE use — same as forcing a door / a combat swing.
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
	WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["door_work"], 4.0)
	_play_sfx(LATCH_STREAM, -2.0)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()


func _attempt_barricade_removal() -> void:
	if is_removing_barricade:
		return
	# Removing a barricade requires at least 3 bars (37.5%) — must be out of the
	# red zone. If you exhausted yourself to zero, you wait until stamina recovers
	# into yellow before you can start again.
	if WorldState.stamina < WorldState.max_stamina * 0.375 and not WorldState.god_mode:
		HUD.show_feedback("Too exhausted — recover first.")
		return

	removal_uses_tool = _has_removal_tool()
	removal_duration = BARRICADE_TIME_TOOL if removal_uses_tool else BARRICADE_TIME_BARE
	removal_fraction = clamp(WorldState.barricade_progress.get(apartment_id, 0.0), 0.0, 1.0)

	# Capture the tool instance we'll debit. If bare-handed, none.
	removal_tool_instance = null
	removal_durability_spent = 0
	if removal_uses_tool:
		var slot = HUD.selected_slot
		removal_tool_instance = WorldState.get_instance_at(slot)

	# Stamina: drain a fixed fraction of max across the full removal, written as an
	# absolute target each frame so player.gd's passive regen can't fight it.
	removal_stamina_start = WorldState.stamina
	var stam_frac = BARRICADE_STAMINA_FRACTION_TOOL if removal_uses_tool else BARRICADE_STAMINA_FRACTION_BARE
	removal_stamina_total = WorldState.max_stamina * stam_frac

	is_removing_barricade = true
	_sync_overlay_to_progress()
	barricade_progress_overlay.visible = true
	proximity_label.text = _get_prompt_text()


func _tick_barricade_removal(delta: float) -> void:
	removal_fraction += delta / removal_duration
	removal_fraction = clamp(removal_fraction, 0.0, 1.0)
	WorldState.barricade_progress[apartment_id] = removal_fraction
	# Tearing a barricade apart is 10/10 loud, continuously.
	WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["door_work"], 1.0)
	rip_sfx_timer -= delta
	if rip_sfx_timer <= 0.0:
		rip_sfx_timer = randf_range(0.55, 0.85)
		_play_sfx(PLANK_STREAMS.pick_random(), -4.0)

	# Durability — debit progressively so a full removal costs BARRICADE_DURABILITY_COST.
	# target_spend grows with progress; we apply use() each time it crosses an integer.
	if removal_tool_instance != null:
		var target_spend = int(floor(removal_fraction * BARRICADE_DURABILITY_COST))
		while removal_durability_spent < target_spend:
			removal_tool_instance.use()
			removal_durability_spent += 1
			HUD.refresh_inventory()
			if removal_tool_instance.is_depleted:
				_break_tool_mid_removal()
				return

	# Stamina — absolute target based on progress.
	if not WorldState.god_mode:
		var drained = removal_stamina_total * removal_fraction
		WorldState.stamina = max(removal_stamina_start - drained, 0.0)
		HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
		# Out of stamina mid-removal: halt and bank progress. The 3-bar start gate
		# keeps removal locked until stamina recovers into yellow.
		if WorldState.stamina <= 0.0:
			_pause_barricade_removal()
			HUD.show_feedback("Exhausted — catch your breath.")
			return

	# Overlay
	var remaining_height = BARRICADE_SPRITE_HEIGHT * (1.0 - removal_fraction)
	barricade_progress_overlay.size.y = remaining_height
	barricade_progress_overlay.visible = remaining_height > 1.0
	proximity_label.text = _get_prompt_text()

	if removal_fraction >= 1.0:
		_finish_barricade_removal()


# Player walked away (or otherwise interrupted) — bank progress, stop draining.
func _pause_barricade_removal() -> void:
	is_removing_barricade = false
	WorldState.barricade_progress[apartment_id] = removal_fraction
	removal_tool_instance = null


# The tool snapped partway through. Removal halts; the barricade stays up with its
# current progress banked. The player must re-initiate — bare-handed or with another
# tool — and the saved fraction carries over (rescaled to the new duration).
func _break_tool_mid_removal() -> void:
	var weapon_name = "Your weapon"
	if removal_tool_instance != null:
		weapon_name = removal_tool_instance.get_data().get("name", "Your weapon")
	var slot = HUD.selected_slot
	if slot >= 0 and slot < WorldState.inventory.size() and WorldState.get_instance_at(slot) == removal_tool_instance:
		WorldState.remove_from_inventory(slot)
		HUD.selected_slot = -1
	HUD.refresh_inventory()

	is_removing_barricade = false
	removal_tool_instance = null
	WorldState.barricade_progress[apartment_id] = removal_fraction

	_sync_overlay_to_progress()
	proximity_label.text = _get_prompt_text()
	HUD.show_feedback(weapon_name + " broke — barricade still standing.")


func _finish_barricade_removal() -> void:
	is_removing_barricade = false
	removal_tool_instance = null
	WorldState.barricade_progress.erase(apartment_id)
	barricade_progress_overlay.visible = false
	barricade_sprite.visible = false

	var underlying_state = WorldState.DoorState.SHUT_FORCEABLE
	if current_state == WorldState.DoorState.BARRICADED_LOCKED:
		underlying_state = WorldState.DoorState.SHUT_LOCKED

	WorldState.set_door_state(apartment_id, underlying_state)
	_apply_door_state()
	proximity_label.text = _get_prompt_text()
	HUD.show_feedback("Barricade removed.")


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
			var instance = WorldState.get_instance_at(i)
			if instance.target_apartment == apartment_id:
				return i
	return -1
