extends CharacterBody2D

const SPEED = 150.0
const SPRINT_SPEED = 300.0
const CROUCH_SPEED = 60.0
const SCAVENGE_SPEED = 80.0
const PUSH_DURATION = 0.8
const PUSH_RANGE = 40.0
const PUSH_FORCE = 100.0
const MODE_SWITCH_TIME = 0.2

const DEV_MODE = true
const DEV_ITEMS = ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010", "011", "012", "013", "014", "015", "016", "017", "018", "019", "020", "021", "022"]
var dev_item_index = 0

# Stamina
const STAMINA_SPRINT_DRAIN = 18.0
const STAMINA_PUSH_COST = 28.0
const STAMINA_PUSH_REPEAT_WINDOW = 0.6
const STAMINA_PUSH_REPEAT_MULT = 2.0
const STAMINA_PASSIVE_RATE = 4.0
const STAMINA_RECOVERY_DELAY = 1.5
var stamina_recovery_timer: float = 0.0
var last_push_time: float = 0.0
var push_count_window: int = 0

# Weapon attack
const WEAPON_RANGES = {
	"knife": 32.0,
	"sword": 50.0,
	"bat": 65.0
}
const WEAPON_DAMAGE = {
	"knife": 1,
	"sword": 1,
	"bat": 3
}
const WEAPON_STAMINA_COST = {
	"knife": 8.0,
	"sword": 16.0,
	"bat": 26.0
}
const WEAPON_COOLDOWN = {
	"knife": 0.3,
	"sword": 0.5,
	"bat": 0.8
}
const GUN_RANGE_CLOSE = 120.0
const GUN_RANGE_MID = 250.0

var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

enum HealthState {HEALTHY, HURT, INJURED, WOUNDED, SEVERELY_WOUNDED, DYING}
var health_state: HealthState = HealthState.HEALTHY

var is_crouching = false
var is_pushing = false
var push_timer = 0.0
var is_hit = false
var hit_flash_timer = 0.0
const HIT_FLASH_DURATION = 0.5

var is_dying = false
var dying_timer = 0.0
const DYING_TIME = 15.0
var is_dead = false

var is_switching_mode = false
var mode_switch_timer = 0.0

func _ready() -> void:
	add_to_group("player")
	health_state = HealthState.values()[WorldState.player_health]
	is_dying = WorldState.is_dying
	dying_timer = WorldState.dying_timer
	HUD.update_portrait(health_state)
	HUD.update_mode_indicator()
	HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
	HUD.refresh_inventory()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_dying:
		dying_timer -= delta
		WorldState.dying_timer = dying_timer
		if dying_timer <= 0:
			_die()
		var dying_direction = Input.get_axis("move_left", "move_right")
		velocity.x = dying_direction * CROUCH_SPEED * 0.5
		move_and_slide()
		return

	if is_switching_mode:
		mode_switch_timer -= delta
		velocity.x = 0
		move_and_slide()
		if mode_switch_timer <= 0:
			is_switching_mode = false
			WorldState.is_scavenge_mode = !WorldState.is_scavenge_mode
			animated_sprite.play("idle")
			HUD.update_mode_indicator()
		return

	if Input.is_action_just_pressed("mode_toggle"):
		is_switching_mode = true
		mode_switch_timer = MODE_SWITCH_TIME
		animated_sprite.play("air_spin")
		return

	if Input.is_action_just_pressed("crouch_toggle"):
		is_crouching = !is_crouching

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			is_attacking = false

	var direction = Input.get_axis("move_left", "move_right")
	var is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and not WorldState.is_scavenge_mode

	if not WorldState.is_scavenge_mode:
		if Input.is_action_just_pressed("push") and not is_pushing:
			if not _is_mouse_over_hud():
				_do_push()

	if is_pushing:
		push_timer -= delta
		if push_timer <= 0:
			is_pushing = false

	if is_hit:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0:
			is_hit = false
			animated_sprite.modulate = Color(1, 1, 1, 1)

	if is_sprinting and WorldState.stamina > 0:
		WorldState.stamina = max(WorldState.stamina - STAMINA_SPRINT_DRAIN * delta, 0.0)
		stamina_recovery_timer = STAMINA_RECOVERY_DELAY
		HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
	else:
		if stamina_recovery_timer > 0:
			stamina_recovery_timer -= delta
		elif WorldState.stamina < WorldState.max_stamina:
			WorldState.stamina = min(WorldState.stamina + STAMINA_PASSIVE_RATE * delta, WorldState.max_stamina)
			HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)

	if push_count_window > 0:
		var time_since_push = Time.get_ticks_msec() / 1000.0 - last_push_time
		if time_since_push > STAMINA_PUSH_REPEAT_WINDOW:
			push_count_window = 0

	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	var current_speed = SPEED
	if WorldState.is_scavenge_mode:
		current_speed = SCAVENGE_SPEED
	elif is_sprinting and WorldState.stamina > 0:
		current_speed = SPRINT_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED

	if is_crouching:
		if direction == 0:
			animated_sprite.play("crouch_idle")
		else:
			animated_sprite.play("crouch_walk")
	elif is_pushing:
		animated_sprite.play("punch_jab")
		velocity.x = 0
	elif is_hit:
		pass
	elif is_attacking:
		pass
	else:
		var equipped_weapon = _get_equipped_weapon_type()
		if direction == 0:
			match equipped_weapon:
				"sword", "knife", "bat": animated_sprite.play("katana_idle")
				_: animated_sprite.play("idle")
		elif is_sprinting and WorldState.stamina > 0:
			match equipped_weapon:
				"sword", "knife", "bat": animated_sprite.play("katana_run")
				_: animated_sprite.play("run")
		else:
			match equipped_weapon:
				"sword", "knife", "bat": animated_sprite.play("katana_walk")
				_: animated_sprite.play("walk")

	if is_pushing:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	elif direction != 0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

func _get_equipped_weapon_type() -> String:
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		return ""
	var item_data = ItemData.get_item(WorldState.get_item_id_at(slot))
	if not item_data.get("is_weapon", false):
		return ""
	return _get_weapon_type(item_data)

func _get_weapon_type(item_data: Dictionary) -> String:
	var name = item_data.get("name", "").to_lower()
	if name.contains("knife") or name.contains("scalpel"):
		return "knife"
	elif name.contains("sword") or name.contains("katana") or name.contains("machete"):
		return "sword"
	elif name.contains("bat") or name.contains("club") or name.contains("wrench") or name.contains("hammer"):
		return "bat"
	elif name.contains("gun") or name.contains("pistol") or name.contains("rifle") or name.contains("shotgun"):
		return "gun"
	return ""

func _get_weapon_damage_type(weapon_type: String) -> String:
	match weapon_type:
		"knife", "sword": return "blade"
		"bat": return "bludgeon"
		"gun": return "bullet"
	return "blunt"

func _do_melee_attack(instance: ItemInstance, slot_index: int) -> void:
	if is_attacking:
		return
	var item_data = instance.get_data()
	var weapon_type = _get_weapon_type(item_data)
	if weapon_type == "" or weapon_type == "gun":
		return
	var stamina_cost = WEAPON_STAMINA_COST.get(weapon_type, 15.0)
	if WorldState.stamina < stamina_cost:
		HUD.show_feedback("Too exhausted to swing.")
		return

	WorldState.stamina = max(WorldState.stamina - stamina_cost, 0.0)
	stamina_recovery_timer = STAMINA_RECOVERY_DELAY
	HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
	is_attacking = true
	attack_cooldown_timer = WEAPON_COOLDOWN.get(weapon_type, 0.5)
	animated_sprite.play("katana_attack_continuous")

	var attack_range = WEAPON_RANGES.get(weapon_type, 40.0)
	var damage = WEAPON_DAMAGE.get(weapon_type, 1)
	var damage_type = _get_weapon_damage_type(weapon_type)
	var hit_something = false
	var zombies = get_tree().get_nodes_in_group("zombie")
	for zombie in zombies:
		var dist = global_position.distance_to(zombie.global_position)
		if dist <= attack_range:
			var diff = zombie.global_position.x - global_position.x
			var facing_right = not animated_sprite.flip_h
			if (facing_right and diff > -16.0) or (not facing_right and diff < 16.0):
				if zombie.has_method("receive_damage"):
					zombie.receive_damage(damage, damage_type)
					hit_something = true

	if hit_something:
		instance.use()
		if instance.is_depleted:
			var weapon_name = item_data.get("name", "Weapon")
			WorldState.remove_from_inventory(slot_index)
			HUD.selected_slot = -1
			HUD.refresh_inventory()
			HUD.show_feedback(weapon_name + " broke!")
		else:
			HUD.refresh_inventory()

func _do_gun_attack(instance: ItemInstance, slot_index: int) -> void:
	var ammo_slot = _find_ammo_in_inventory()
	if ammo_slot == -1:
		HUD.show_feedback("No ammo.")
		return
	if is_attacking:
		return
	is_attacking = true
	attack_cooldown_timer = 0.4
	WorldState.remove_from_inventory(ammo_slot)
	HUD.refresh_inventory()
	var zombies = get_tree().get_nodes_in_group("zombie")
	var nearest: Node = null
	var nearest_dist: float = 9999.0
	for zombie in zombies:
		var dist = global_position.distance_to(zombie.global_position)
		var diff = zombie.global_position.x - global_position.x
		var facing_right = not animated_sprite.flip_h
		if (facing_right and diff > -16.0) or (not facing_right and diff < 16.0):
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = zombie
	if nearest == null:
		HUD.show_feedback("Nothing in sight.")
		return
	var outcome = _calculate_gun_outcome(nearest_dist)
	match outcome:
		"headshot": HUD.show_feedback("Headshot!")
		"body": HUD.show_feedback("Body shot.")
		"miss": HUD.show_feedback("Missed.")
	if nearest.has_method("receive_hit_from_gun"):
		nearest.receive_hit_from_gun(outcome)

func _calculate_gun_outcome(distance: float) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(Time.get_ticks_msec()))
	var roll = rng.randf()
	if distance <= GUN_RANGE_CLOSE:
		if roll < 0.70: return "headshot"
		elif roll < 0.95: return "body"
		else: return "miss"
	elif distance <= GUN_RANGE_MID:
		if roll < 0.20: return "headshot"
		elif roll < 0.75: return "body"
		else: return "miss"
	else:
		if roll < 0.05: return "headshot"
		elif roll < 0.30: return "body"
		else: return "miss"

func _find_ammo_in_inventory() -> int:
	for i in range(WorldState.inventory.size()):
		var item_data = ItemData.get_item(WorldState.get_item_id_at(i))
		if item_data.get("is_ammo", false):
			return i
	return -1

func _do_push() -> void:
	if WorldState.stamina < 10.0:
		HUD.show_feedback("Too exhausted to push.")
		return
	var now = Time.get_ticks_msec() / 1000.0
	var time_since_last = now - last_push_time
	var cost = STAMINA_PUSH_COST
	if time_since_last < STAMINA_PUSH_REPEAT_WINDOW:
		push_count_window += 1
		cost = STAMINA_PUSH_COST * pow(STAMINA_PUSH_REPEAT_MULT, push_count_window)
	else:
		push_count_window = 1
	last_push_time = now
	WorldState.stamina = max(WorldState.stamina - cost, 0.0)
	HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
	is_pushing = true
	push_timer = PUSH_DURATION
	animated_sprite.play("punch_jab")
	var zombies = get_tree().get_nodes_in_group("zombie")
	for zombie in zombies:
		var dist = global_position.distance_to(zombie.global_position)
		if dist <= PUSH_RANGE:
			var push_dir = sign(zombie.global_position.x - global_position.x)
			zombie.receive_push(push_dir * PUSH_FORCE)

func restore_stamina(amount: float) -> void:
	WorldState.stamina = min(WorldState.stamina + amount, WorldState.max_stamina)
	HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)

func do_rest() -> void:
	if not WorldState.rest_available:
		HUD.show_feedback("Need to descend further to rest.")
		return
	WorldState.rest_available = false
	WorldState.rest_count += 1
	WorldState.last_rest_floor = WorldState.current_floor
	WorldState.stamina = WorldState.max_stamina
	HUD.update_stamina(WorldState.stamina, WorldState.max_stamina)
	_reseed_zombies()
	HUD.show_feedback("You rest. The building shifts.")

func _reseed_zombies() -> void:
	WorldState.master_seed = randi()
	WorldState.apartment_layouts.clear()
	WorldState.anchor_items.clear()

func _input(event: InputEvent) -> void:
	if is_dead or is_dying or is_switching_mode:
		return

	if DEV_MODE:
		if event.is_action_pressed("dev_add_item"):
			var item_id = DEV_ITEMS[dev_item_index % DEV_ITEMS.size()]
			if WorldState.add_to_inventory(item_id):
				HUD.refresh_inventory()
				HUD.show_feedback("DEV: Added " + ItemData.get_item(item_id).get("name", item_id))
			else:
				HUD.show_feedback("DEV: Inventory full.")
			dev_item_index += 1
		elif event.is_action_pressed("dev_set_health"):
			var next = (int(health_state) + 1) % (HealthState.DYING + 1)
			health_state = next as HealthState
			WorldState.player_health = health_state
			if health_state == HealthState.DYING:
				is_dying = true
				WorldState.is_dying = true
				dying_timer = DYING_TIME
				WorldState.dying_timer = DYING_TIME
			else:
				is_dying = false
				WorldState.is_dying = false
			_update_hud()
			HUD.show_feedback("DEV: Health = " + HealthState.keys()[health_state])

	if not WorldState.is_scavenge_mode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _is_mouse_over_hud():
				return
			var slot = HUD.selected_slot
			if slot >= 0 and slot < WorldState.inventory.size():
				var instance = WorldState.get_instance_at(slot)
				var item_data = instance.get_data()
				if item_data.get("is_weapon", false):
					var weapon_type = _get_weapon_type(item_data)
					if weapon_type == "gun":
						_do_gun_attack(instance, slot)
					else:
						_do_melee_attack(instance, slot)
				else:
					HUD.show_feedback("No weapon selected.")
			else:
				HUD.show_feedback("No weapon selected.")

	if event.is_action_pressed("item_slot_1"): HUD.select_slot(0)
	elif event.is_action_pressed("item_slot_2"): HUD.select_slot(1)
	elif event.is_action_pressed("item_slot_3"): HUD.select_slot(2)
	elif event.is_action_pressed("item_slot_4"): HUD.select_slot(3)
	elif event.is_action_pressed("item_slot_5"): HUD.select_slot(4)
	elif event.is_action_pressed("item_use"):
		var slot = HUD.selected_slot
		if slot >= 0 and slot < WorldState.inventory.size():
			use_item(slot)
	elif event.is_action_pressed("rest"):
		do_rest()

func _is_mouse_over_hud() -> bool:
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	if mouse_y > screen_h - (80.0 + 40.0):
		return true
	if HUD.context_menu and HUD.context_menu.visible:
		return true
	return false

func use_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= WorldState.inventory.size():
		return
	var instance = WorldState.get_instance_at(slot_index)
	if instance == null:
		return
	var item_data = instance.get_data()
	if item_data.is_empty():
		return

	if item_data["is_health_item"]:
		var heals = item_data["heals_states"]
		heal(heals)
		instance.use()
		if instance.is_depleted:
			WorldState.remove_from_inventory(slot_index)
			HUD.selected_slot = -1
		HUD.refresh_inventory()
	elif item_data["is_speed_boost"]:
		restore_stamina(WorldState.max_stamina * 0.35)
		HUD.show_feedback("Stamina restored.")
		instance.use()
		if instance.is_depleted:
			WorldState.remove_from_inventory(slot_index)
			HUD.selected_slot = -1
		HUD.refresh_inventory()
	elif item_data.get("is_weapon", false) and _get_weapon_type(item_data) != "gun":
		HUD.selected_slot = slot_index
		HUD._update_slot_highlights()
		HUD.show_feedback("Equipped.")
	elif item_data.get("is_weapon", false) and _get_weapon_type(item_data) == "gun":
		HUD.selected_slot = slot_index
		HUD._update_slot_highlights()
		HUD.show_feedback("Not implemented yet.")
	elif item_data["is_junk"]:
		HUD.show_feedback("Nothing happens.")
	else:
		HUD.show_feedback("Not implemented yet.")

func heal(states: int) -> void:
	if health_state == HealthState.HEALTHY:
		HUD.show_feedback("Already healthy.")
		return
	var new_state = max(int(health_state) - states, int(HealthState.HEALTHY))
	health_state = new_state as HealthState
	WorldState.player_health = health_state
	if is_dying and health_state < HealthState.DYING:
		is_dying = false
		WorldState.is_dying = false
		WorldState.dying_timer = 0.0
	_update_hud()
	HUD.show_feedback("Used item.")

func receive_hit() -> void:
	if is_dead or is_dying:
		return
	is_hit = true
	hit_flash_timer = HIT_FLASH_DURATION
	animated_sprite.modulate = Color(1, 0, 0, 1)
	animated_sprite.play("hurt")
	take_damage()

func take_damage() -> void:
	if health_state < HealthState.DYING:
		health_state = (health_state + 1) as HealthState
		WorldState.player_health = health_state
	if health_state == HealthState.DYING:
		is_dying = true
		WorldState.is_dying = true
		dying_timer = DYING_TIME
		WorldState.dying_timer = DYING_TIME
	_update_hud()

func _die() -> void:
	is_dead = true
	is_dying = false
	WorldState.is_dying = false
	WorldState.dying_timer = 0.0
	animated_sprite.play("death")
	print("Player died")
	await get_tree().create_timer(2.0).timeout
	Game.game_over()

func _update_hud() -> void:
	HUD.update_portrait(health_state)
