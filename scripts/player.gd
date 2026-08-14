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
# F1 item spawning is now a typed prompt (dev_item_prompt.gd) — pick any item by
# number instead of cycling. F2 (dev_force_hazards) CYCLES floor hazards one at a
# time (WorldState.dev_hazard_mode: off → barricades → hordes → fire → off); only
# barricades is built so far, so each can be tested in a vacuum without overlap.

# Stamina
const STAMINA_SPRINT_DRAIN = 12.0
const STAMINA_PUSH_COST = 28.0
const STAMINA_PUSH_REPEAT_WINDOW = 0.6
const STAMINA_PUSH_REPEAT_MULT = 2.0
const STAMINA_PASSIVE_RATE = 10.0
const STAMINA_RECOVERY_DELAY = 0.8
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
const DYING_TIME = 8.0
const EXTINGUISH_RADIUS := 130.0   # how wide a fire-extinguisher blast reaches
var is_dead = false

var is_switching_mode = false
var mode_switch_timer = 0.0

# Depth approach-walk framework: for 2D-hallway depth, the player steps UP the
# screen (−Y) toward a door before entering (or to knock). While a cutscene
# move runs, normal control/input is suspended. Art (knock/enter frames) comes
# later; this is the movement scaffold. See docs/TUTORIAL.md.
# Small on purpose: the player's feet should reach the line where the door
# meets the floor, not float up into the doorway (playtest — 26 was too high).
const APPROACH_DEPTH = 12.0     # how far "into" the hallway (up) the player steps
const APPROACH_TIME = 0.35
const KNOCK_PAUSE = 0.5
var is_cutscene: bool = false
# Balcony descent (THREE_RUN_ARC): lashing a rope is a timed, SILENT channel the
# player stands still for — and can be interrupted by a hit. Once lashed the rope
# stays as a permanent balcony fixture (WorldState.roped_balconies).
const BALCONY_LASH_TIME = 2.5
var is_lashing: bool = false
var _lash_cancel: bool = false
# A no-rope jump takes a deliberate second press (with a warning first).
const BALCONY_JUMP_CONFIRM_WINDOW = 4.0
var _jump_confirm_time: float = 0.0
# The balcony is a real walkable SPACE (2.5D): W steps the player up onto its
# own plane (higher Y line, sprite slightly smaller for depth), where they can
# move left/right between the rails; S steps back inside. Descent (rope/jump)
# is only offered ON the plane. It is NOT a safe island: enemies climb up too.
const BALCONY_PLANE_RISE = 25.0
const BALCONY_PLANE_SCALE = 0.88
const BALCONY_HALF_WIDTH = 34.0
const BALCONY_STEP_TIME = 0.35
var on_balcony_plane: bool = false
var balcony_plane_y: float = 0.0
var balcony_center_x: float = 0.0
var _plane_return_y: float = 0.0
var _plane_base_scale: Vector2 = Vector2.ONE

# Audio (docs/SOUND_STEALTH.md audio pass). Carpet steps for the quiet
# gaits, concrete for the loud ones — the sound mirrors the noise model.
const FOOTSTEPS_SOFT = [
	preload("res://assets/audio/footsteps/footstep_carpet_000.ogg"),
	preload("res://assets/audio/footsteps/footstep_carpet_001.ogg"),
	preload("res://assets/audio/footsteps/footstep_carpet_002.ogg"),
	preload("res://assets/audio/footsteps/footstep_carpet_003.ogg"),
	preload("res://assets/audio/footsteps/footstep_carpet_004.ogg"),
]
const FOOTSTEPS_HARD = [
	preload("res://assets/audio/footsteps/footstep_concrete_000.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_001.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_002.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_003.ogg"),
	preload("res://assets/audio/footsteps/footstep_concrete_004.ogg"),
]
const GUNSHOT_STREAM = preload("res://assets/audio/gunshot.wav")
const MELEE_THUNK = [
	preload("res://assets/audio/impacts/impactWood_medium_000.ogg"),
	preload("res://assets/audio/impacts/impactWood_medium_001.ogg"),
	preload("res://assets/audio/impacts/impactWood_medium_002.ogg"),
]
const MELEE_SLICE = [
	preload("res://assets/audio/impacts/knifeSlice.ogg"),
	preload("res://assets/audio/impacts/knifeSlice2.ogg"),
]
# Step cadence (s) and loudness (dB) per gait — tuned to the noise radii.
const FOOTSTEP_INTERVAL = {"crouch": 0.55, "scavenge": 0.50, "walk": 0.38, "run": 0.26}
const FOOTSTEP_VOLUME = {"crouch": -22.0, "scavenge": -16.0, "walk": -10.0, "run": -5.0}
var footstep_player: AudioStreamPlayer2D = null
var gunshot_player: AudioStreamPlayer2D = null
var melee_player: AudioStreamPlayer2D = null
var footstep_timer: float = 0.0

# Click-to-move (playtest feedback): LMB sets a walk target. Keyboard input
# always overrides. In scavenge mode a far anchor click walks + auto-loots;
# in combat mode clicking a far zombie walks over and swings once.
var move_target_x: float = 0.0
var has_move_target: bool = false
var pending_anchor: Node = null
var pending_attack: Node = null
var auto_stance_was_crouching: bool = false
var auto_stance_changed: bool = false

# Listen (docs/SOUND_STEALTH.md): rooted, real-time, interruptible by damage.
const LISTEN_DURATION = 3.0
const LISTEN_AMBUSH_ALERT_CHANCE = 0.18
const LISTEN_AMBUSH_SPAWN_CHANCE = 0.08
var is_listening: bool = false
var listen_timer: float = 0.0
var listen_report_line: String = ""


func _ready() -> void:
	add_to_group("player")
	WorldState.loot_open = false  # defensive: never carry a stuck loot lock into a new scene
	# ACTOR LAYER (z 1) — the player, like enemies, always renders above the
	# corridor backdrop (walls, static doors, the merchant's elevator doors,
	# and future dynamic door art at z 0). Keep new door/entrance visuals at
	# z 0 and they'll sit behind bodies automatically.
	z_index = 1
	_setup_gun_animations()
	footstep_player = AudioStreamPlayer2D.new()
	footstep_player.name = "FootstepPlayer"
	footstep_player.max_distance = 500.0
	add_child(footstep_player)
	gunshot_player = AudioStreamPlayer2D.new()
	gunshot_player.name = "GunshotPlayer"
	gunshot_player.stream = GUNSHOT_STREAM
	gunshot_player.volume_db = -4.0
	gunshot_player.max_distance = 2500.0
	add_child(gunshot_player)
	melee_player = AudioStreamPlayer2D.new()
	melee_player.name = "MeleePlayer"
	melee_player.volume_db = -6.0
	melee_player.max_distance = 500.0
	add_child(melee_player)
	# Entering a room/stairs while listening frees the old player node; make
	# sure a lingering grey overlay is cleared for this fresh scene.
	if HUD.listen_overlay != null:
		HUD.listen_overlay.abort()
	health_state = HealthState.values()[WorldState.player_health]
	is_dying = WorldState.is_dying
	dying_timer = WorldState.dying_timer
	HUD.update_portrait(health_state)
	HUD.update_mode_indicator()
	HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	HUD.refresh_inventory()
	# God mode no longer flares "God Mode ON" on every scene load (it clobbered
	# other feedback and spammed on room/stairwell entry). The F3 toggle still
	# announces ON/OFF when you change it. If a DEV action queued a message for
	# after a rebuild (e.g. the F2 hazard toggle), surface it now.
	if WorldState.pending_dev_feedback != "":
		HUD.show_feedback(WorldState.pending_dev_feedback)
		WorldState.pending_dev_feedback = ""


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# A scripted approach/knock owns the body — skip normal control.
	if is_cutscene:
		return

	# Lashing a rope: rooted and silent, vulnerable to a hit (which cancels it).
	if is_lashing:
		velocity.x = 0
		move_and_slide()
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

	if is_listening:
		# Rooted and vulnerable — the world keeps moving while you focus.
		# ANY break (movement, or an action) cancels the listen immediately
		# with NO report. Only holding still to the end delivers the read.
		if Input.get_axis("move_left", "move_right") != 0 \
				or Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("mode_toggle") \
				or Input.is_action_just_pressed("attack") \
				or Input.is_action_just_pressed("push") \
				or Input.is_action_just_pressed("jump"):
			_cancel_listen()
			return
		velocity.x = 0
		move_and_slide()
		listen_timer -= delta
		if listen_timer <= 0:
			_finish_listen()
		return

	if Input.is_action_just_pressed("mode_toggle"):
		request_mode_toggle()
		return

	if Input.is_action_just_pressed("crouch_toggle"):
		is_crouching = !is_crouching

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		if attack_cooldown_timer <= 0:
			is_attacking = false

	var direction = Input.get_axis("move_left", "move_right")
	# Click-to-move: keyboard always overrides; otherwise steer toward the
	# clicked point and resolve any queued anchor-loot / zombie-attack there.
	if direction != 0:
		_clear_move_target()
	elif has_move_target:
		var dx = move_target_x - global_position.x
		if abs(dx) <= 8.0:
			_arrive_at_move_target()
		else:
			direction = signf(dx)
	# Sprint requires a small stamina floor to (re)engage. Without this, stamina
	# ticking a sliver above 0 between frames lets sprint flicker back on at zero.
	var can_sprint_stamina = WorldState.stamina > STAMINA_SPRINT_DRAIN * 0.2 or WorldState.god_mode
	var is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and not WorldState.is_scavenge_mode and can_sprint_stamina

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

	if is_sprinting and direction != 0 and WorldState.stamina > 0 and not WorldState.god_mode:
		WorldState.stamina = max(WorldState.stamina - STAMINA_SPRINT_DRAIN * WorldState.get_sprint_drain_mult() * delta, 0.0)
		stamina_recovery_timer = STAMINA_RECOVERY_DELAY
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	else:
		if stamina_recovery_timer > 0:
			stamina_recovery_timer -= delta
		elif WorldState.stamina < WorldState.get_max_stamina():
			WorldState.stamina = min(WorldState.stamina + STAMINA_PASSIVE_RATE * WorldState.get_stamina_regen_mult() * delta, WorldState.get_max_stamina())
			HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())

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
	current_speed *= WorldState.get_move_speed_mult()

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
				"gun": animated_sprite.play("gun_idle")
				_: animated_sprite.play("idle")
		elif is_sprinting and WorldState.stamina > 0:
			match equipped_weapon:
				"sword", "knife", "bat": animated_sprite.play("katana_run")
				"gun": animated_sprite.play("gun_run")
				_: animated_sprite.play("run")
		else:
			match equipped_weapon:
				"sword", "knife", "bat": animated_sprite.play("katana_walk")
				"gun": animated_sprite.play("gun_walk")
				_: animated_sprite.play("walk")

	if is_pushing:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	elif direction != 0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

	# On the balcony plane: held to the balcony's own line, clamped between the
	# rails (its X collision bounds), free to move left/right; S steps back in.
	if on_balcony_plane:
		global_position.y = balcony_plane_y
		global_position.x = clampf(global_position.x,
			balcony_center_x - BALCONY_HALF_WIDTH, balcony_center_x + BALCONY_HALF_WIDTH)
		if Input.is_action_just_pressed("move_down"):
			exit_balcony_plane()

	# Movement noise (under the hood — docs/SOUND_STEALTH.md): louder gaits
	# are audible further. Zombies whose sight misses you can still hear you.
	if direction != 0 and not is_pushing:
		var noise_key = "walk"
		if is_crouching:
			noise_key = "crouch"
		elif WorldState.is_scavenge_mode:
			noise_key = "scavenge"
		elif is_sprinting and WorldState.stamina > 0:
			noise_key = "run"
		WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS[noise_key] * WorldState.get_noise_mult(), 0.5)
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			footstep_timer = FOOTSTEP_INTERVAL[noise_key]
			var pool = FOOTSTEPS_SOFT if noise_key in ["crouch", "scavenge"] else FOOTSTEPS_HARD
			footstep_player.stream = pool.pick_random()
			footstep_player.volume_db = FOOTSTEP_VOLUME[noise_key]
			footstep_player.pitch_scale = randf_range(0.92, 1.08)
			footstep_player.play()
	else:
		footstep_timer = 0.0


func _setup_gun_animations() -> void:
	# Gun animations are built at runtime from the character-template sheets so
	# the hand-tuned SpriteFrames in player.tscn stays untouched. An art pass
	# can bake these into the scene later; the has_animation guard makes that a
	# safe no-op here. Sheets: shoot 2H = 10 frames, running aiming = 8 frames.
	var frames = animated_sprite.sprite_frames
	if frames.has_animation("gun_shoot"):
		return
	var shoot_tex = preload("res://assets/2D-Pixel-Art-Character-Template/Shooting (two-handed)/player shoot 2H 48x48.png")
	var aim_tex = preload("res://assets/2D-Pixel-Art-Character-Template/Shooting (running and aiming)/Player Running Aiming 48x48.png")

	frames.add_animation("gun_idle")
	frames.set_animation_loop("gun_idle", true)
	frames.set_animation_speed("gun_idle", 8.0)
	frames.add_frame("gun_idle", _atlas_frame(shoot_tex, 0))

	frames.add_animation("gun_walk")
	frames.set_animation_loop("gun_walk", true)
	frames.set_animation_speed("gun_walk", 8.0)
	for i in range(8):
		frames.add_frame("gun_walk", _atlas_frame(aim_tex, i))

	frames.add_animation("gun_run")
	frames.set_animation_loop("gun_run", true)
	frames.set_animation_speed("gun_run", 14.0)
	for i in range(8):
		frames.add_frame("gun_run", _atlas_frame(aim_tex, i))

	frames.add_animation("gun_shoot")
	frames.set_animation_loop("gun_shoot", false)
	frames.set_animation_speed("gun_shoot", 16.0)
	for i in range(10):
		frames.add_frame("gun_shoot", _atlas_frame(shoot_tex, i))


func _atlas_frame(sheet: Texture2D, index: int) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(index * 48, 0, 48, 48)
	return atlas


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


func _zombie_body_radius(zombie: Node) -> float:
	# Melee range is measured to the target's collision EDGE, not its centre.
	# The boss capsule (radius 35) is wider than a knife's whole range (32), so
	# centre-to-centre checks made small weapons physically unable to hit it.
	var shape_node = zombie.get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is CapsuleShape2D:
		return shape_node.shape.radius
	return 10.0

func _do_melee_attack(instance: ItemInstance, slot_index: int) -> void:
	if is_attacking:
		return
	var item_data = instance.get_data()
	var weapon_type = _get_weapon_type(item_data)
	if weapon_type == "" or weapon_type == "gun":
		return
	if instance.is_depleted:
		HUD.show_feedback("It's broken — repair it with a toolbox.")
		return
	var stamina_cost = WEAPON_STAMINA_COST.get(weapon_type, 15.0)
	# Attacking requires at least 2 bars (25%). In the red zone you can move but not swing.
	if WorldState.stamina < WorldState.get_max_stamina() * 0.25 and not WorldState.god_mode:
		HUD.show_feedback("Too exhausted to swing.")
		return
	if WorldState.stamina < stamina_cost and not WorldState.god_mode:
		HUD.show_feedback("Too exhausted to swing.")
		return

	if not WorldState.god_mode:
		WorldState.stamina = max(WorldState.stamina - stamina_cost, 0.0)
		stamina_recovery_timer = STAMINA_RECOVERY_DELAY
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())

	is_attacking = true
	attack_cooldown_timer = WEAPON_COOLDOWN.get(weapon_type, 0.5)
	animated_sprite.play("katana_attack_continuous")
	# Swing sound: slice for blades, thunk for blunt weapons.
	melee_player.stream = (MELEE_SLICE if weapon_type in ["knife", "sword"] else MELEE_THUNK).pick_random()
	melee_player.pitch_scale = randf_range(0.9, 1.1)
	melee_player.play()

	var attack_range = WEAPON_RANGES.get(weapon_type, 40.0)
	var damage = WEAPON_DAMAGE.get(weapon_type, 1) + WorldState.get_melee_damage_bonus()
	damage = max(damage, 1)
	var damage_type = _get_weapon_damage_type(weapon_type)
	var hit_something = false
	var zombies = get_tree().get_nodes_in_group("zombie")
	# Gather every zombie in range and within the facing arc, then strike ONE at
	# random. A single swing must never clear a bunched group — each hit lands on
	# one enemy, so hordes stay a real threat.
	# One swing strikes ONE enemy — the NEAREST valid one, so you never hit a
	# boss behind the zombie that's currently mauling you. (Was random pick.)
	var target: Node = null
	var target_dist: float = 99999.0
	for zombie in zombies:
		if zombie.is_dead:
			continue
		# Range gate: edge distance (centre minus body radius) so small weapons can
		# reach the boss's wide capsule. Priority: RAW centre distance — using edge
		# distance for priority handed the boss a radius-sized head start, so it
		# stole hits from standards visibly in front of it.
		var center_dist = global_position.distance_to(zombie.global_position)
		var edge_dist = center_dist - _zombie_body_radius(zombie)
		if edge_dist <= attack_range:
			var diff = zombie.global_position.x - global_position.x
			var facing_right = not animated_sprite.flip_h
			if (facing_right and diff > -16.0) or (not facing_right and diff < 16.0):
				if zombie.has_method("receive_damage") and center_dist < target_dist:
					target_dist = center_dist
					target = zombie
	if target != null:
		target.receive_damage(damage, damage_type)
		hit_something = true

	if hit_something:
		instance.use()
		if instance.is_depleted:
			# Broken weapons now STAY in inventory as a repairable item (item
			# 12) — deselect so we don't keep swinging a broken tool.
			var weapon_name = item_data.get("name", "Weapon")
			if HUD.selected_slot == slot_index:
				HUD.selected_slot = -1
			HUD.refresh_inventory()
			HUD.show_feedback(weapon_name + " broke — repair it with a toolbox.")
		else:
			HUD.refresh_inventory()


func _do_gun_attack(instance: ItemInstance, _slot_index: int) -> void:
	# Guns fire from their MAGAZINE (18, or 10 damaged). Loose bullets stay
	# in inventory until loaded — press the use key on the equipped gun.
	if instance.mag_count <= 0:
		if WorldState.get_ammo_total() > 0:
			HUD.show_feedback("Magazine empty — use the gun to reload.")
		else:
			HUD.show_feedback("No ammo.")
		return
	if is_attacking:
		return
	var zombies = get_tree().get_nodes_in_group("zombie")
	var nearest: Node = null
	var nearest_dist: float = 9999.0
	for zombie in zombies:
		if zombie.is_dead:
			continue
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
	# Only now commit the shot — no target means no ammo spent.
	is_attacking = true
	attack_cooldown_timer = 0.65
	instance.mag_count -= 1
	HUD.refresh_inventory()
	animated_sprite.play("gun_shoot")
	gunshot_player.pitch_scale = randf_range(0.95, 1.05)
	gunshot_player.play()
	var outcome = _calculate_gun_outcome(nearest_dist, instance.is_damaged)
	match outcome:
		"headshot": HUD.show_feedback("Headshot!")
		"body": HUD.show_feedback("Body shot.")
		"miss": HUD.show_feedback("Missed.")
	if nearest.has_method("receive_hit_from_gun"):
		nearest.receive_hit_from_gun(outcome)
	# Gunfire is LOUD (GDD: noise draws enemies) — whole-floor noise event.
	WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["gunshot"], 6.0)


func _calculate_gun_outcome(distance: float, damaged: bool = false) -> String:
	# Rebalanced after playtest: headshots (instant kill) are RARE now.
	# Upgrades and rare/legendary guns will buff these odds later; a damaged
	# gun (used to force a door) shoots markedly worse until repaired.
	var head: float
	var body: float
	if distance <= GUN_RANGE_CLOSE:
		head = 0.25; body = 0.60
	elif distance <= GUN_RANGE_MID:
		head = 0.08; body = 0.52
	else:
		head = 0.02; body = 0.23
	if damaged:
		head *= 0.5
		body *= 0.65
	# Upgrades (Steady Aim, Marksman, Trigger Discipline) and — later — rare
	# guns sharpen the odds.
	head = clamp(head + WorldState.get_headshot_bonus(), 0.0, 0.95)
	body = clamp(body + WorldState.get_body_bonus(), 0.0, 1.0 - head)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(Time.get_ticks_msec()))
	var roll = rng.randf()
	if roll < head: return "headshot"
	elif roll < head + body: return "body"
	return "miss"


func _do_push() -> void:
	if WorldState.stamina < 10.0 and not WorldState.god_mode:
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
	if not WorldState.god_mode:
		WorldState.stamina = max(WorldState.stamina - cost, 0.0)
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	is_pushing = true
	push_timer = PUSH_DURATION
	animated_sprite.play("punch_jab")
	var zombies = get_tree().get_nodes_in_group("zombie")
	for zombie in zombies:
		var dist = global_position.distance_to(zombie.global_position)
		if dist <= PUSH_RANGE:
			var push_dir = sign(zombie.global_position.x - global_position.x)
			zombie.receive_push(push_dir * PUSH_FORCE * WorldState.get_push_mult())


func request_mode_toggle() -> bool:
	# Public: start the scavenge↔combat switch (same as pressing F). Called by
	# the HUD mode button so mouse players don't need the key.
	if is_switching_mode or is_dead or is_dying or is_listening or is_cutscene:
		return false
	if WorldState.loot_open:
		return false
	_clear_move_target()
	is_switching_mode = true
	mode_switch_timer = MODE_SWITCH_TIME
	animated_sprite.play("air_spin")
	return true


func approach_door(door_global: Vector2, on_arrive: Callable = Callable()) -> void:
	# Step up toward the door (depth), then run on_arrive (typically the scene
	# transition). Used on apartment entry so the player visibly walks in.
	if is_cutscene:
		return
	is_cutscene = true
	_clear_move_target()
	velocity = Vector2.ZERO
	var target = Vector2(door_global.x, global_position.y - APPROACH_DEPTH)
	animated_sprite.flip_h = target.x < global_position.x
	animated_sprite.play("walk")
	var tw = create_tween()
	tw.tween_property(self, "global_position", target, APPROACH_TIME)
	await tw.finished
	animated_sprite.play("idle")
	is_cutscene = false
	if on_arrive.is_valid():
		on_arrive.call()


func knock_door(door_global: Vector2, on_done: Callable = Callable()) -> void:
	# Step up to a door, knock (placeholder pause + SFX later), and — when there's
	# no answer — step back down to the main plane. Framework for sealed/locked
	# doors and the opener; not auto-wired yet.
	if is_cutscene:
		return
	is_cutscene = true
	_clear_move_target()
	velocity = Vector2.ZERO
	var start = global_position
	var target = Vector2(door_global.x, global_position.y - APPROACH_DEPTH)
	animated_sprite.flip_h = target.x < global_position.x
	animated_sprite.play("walk")
	var tw = create_tween()
	tw.tween_property(self, "global_position", target, APPROACH_TIME)
	await tw.finished
	animated_sprite.play("idle")  # knock frames go here
	# Knock: a couple of quick raps (placeholder — wood impact).
	for i in range(2):
		if melee_player != null:
			melee_player.stream = MELEE_THUNK.pick_random()
			melee_player.pitch_scale = randf_range(0.9, 1.05)
			melee_player.play()
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(KNOCK_PAUSE).timeout
	animated_sprite.play("walk")
	var tw2 = create_tween()
	tw2.tween_property(self, "global_position", start, APPROACH_TIME)
	await tw2.finished
	animated_sprite.play("idle")
	is_cutscene = false
	if on_done.is_valid():
		on_done.call()


func set_move_target(x: float, anchor: Node = null) -> void:
	move_target_x = x
	has_move_target = true
	pending_anchor = anchor
	pending_attack = null


func _clear_move_target() -> void:
	has_move_target = false
	pending_anchor = null
	pending_attack = null


func _arrive_at_move_target() -> void:
	has_move_target = false
	if pending_anchor != null and is_instance_valid(pending_anchor):
		WorldState.interaction_handled = false
		auto_stance_for_anchor(pending_anchor.global_position.y)
		pending_anchor.try_interact()
	elif pending_attack != null and is_instance_valid(pending_attack) and not pending_attack.is_dead:
		animated_sprite.flip_h = pending_attack.global_position.x < global_position.x
		var slot = HUD.selected_slot
		if slot >= 0 and slot < WorldState.inventory.size():
			var instance = WorldState.get_instance_at(slot)
			if instance.get_data().get("is_weapon", false):
				_do_melee_attack(instance, slot)
	pending_anchor = null
	pending_attack = null


func auto_stance_for_anchor(anchor_y: float) -> void:
	# Low anchors crouch you automatically; a crouched player stands for high
	# ones. Original stance restores when the loot panel closes.
	auto_stance_changed = false
	auto_stance_was_crouching = is_crouching
	if anchor_y > global_position.y + 15.0 and not is_crouching:
		is_crouching = true
		auto_stance_changed = true
	elif anchor_y < global_position.y - 25.0 and is_crouching:
		is_crouching = false
		auto_stance_changed = true


func restore_stance() -> void:
	# After an auto-stance scavenge, always return to STANDING idle (playtest:
	# auto-crouching for a low item used to leave the player stuck crouched,
	# especially across back-to-back low searches).
	if auto_stance_changed:
		is_crouching = false
		auto_stance_changed = false


func _mouse_world_pos() -> Vector2:
	var cam = get_node_or_null("Camera2D")
	if cam == null:
		return global_position
	return cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom


func _unhandled_input(event: InputEvent) -> void:
	# Ground click-to-move. In scavenge, room.gd consumes anchor clicks first;
	# in combat, a default-LMB attack consumes the click in _input before it
	# reaches here — so LMB only walks you when it ISN'T bound to attack
	# (e.g. attack rebound to a mouse side button). Works in both modes.
	if is_dead or is_dying or is_switching_mode or is_listening or is_cutscene or WorldState.loot_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over_hud():
			return
		set_move_target(_mouse_world_pos().x)


func start_listen(source_pos: Vector2, report: Dictionary) -> void:
	# Anchored listen at a door or down-stairwell. Rooted for the duration,
	# real time — listening while something shuffles toward you is on you.
	if is_listening or is_dead or is_dying or is_switching_mode:
		return
	_clear_move_target()
	is_listening = true
	listen_timer = LISTEN_DURATION * WorldState.get_listen_speed_mult()
	listen_report_line = report.get("line", "")
	velocity.x = 0
	# Placeholder stance until the ear-cupping/lean-over animation exists
	# (art task — see docs/SOUND_STEALTH.md).
	animated_sprite.play("crouch_idle")
	HUD.listen_overlay.begin(source_pos, report)
	_roll_listen_ambush()


func _finish_listen() -> void:
	is_listening = false
	HUD.listen_overlay.finish(listen_report_line)
	animated_sprite.play("idle")


func _cancel_listen() -> void:
	# Took a hit mid-listen: colour snaps back, no report — you lost focus.
	is_listening = false
	HUD.listen_overlay.abort()


func _roll_listen_ambush() -> void:
	# Sometimes — not always — focusing invites trouble (docs/SOUND_STEALTH.md).
	# Prefer waking a distant leftover; only very rarely conjure one at the
	# dark screen edge, and only in hallway scenes where that reads fairly.
	var roll = randf()
	var any_living = false
	var far_zombies: Array = []
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if not zombie.is_dead:
			any_living = true
			if global_position.distance_to(zombie.global_position) > 240.0:
				far_zombies.append(zombie)
	if not far_zombies.is_empty() and roll < LISTEN_AMBUSH_ALERT_CHANCE:
		far_zombies.pick_random().alert_to_noise(10.0)
	elif not any_living and roll < LISTEN_AMBUSH_SPAWN_CHANCE:
		var scene_path = get_tree().current_scene.scene_file_path
		if scene_path.contains("building_floors") or scene_path.contains("hallway"):
			var zombie = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
			var side = 1.0 if randf() < 0.5 else -1.0
			zombie.global_position = Vector2(clamp(global_position.x + side * 500.0, 50.0, 1300.0), 388.0)
			get_tree().current_scene.add_child(zombie)
			zombie.alert_to_noise(10.0)


func restore_stamina(amount: float) -> void:
	WorldState.stamina = min(WorldState.stamina + amount, WorldState.get_max_stamina())
	HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())


func do_rest() -> void:
	if not WorldState.rest_available:
		HUD.show_feedback("Need to descend further to rest.")
		return
	WorldState.rest_available = false
	WorldState.rest_count += 1
	WorldState.last_rest_floor = WorldState.current_floor
	WorldState.stamina = WorldState.get_max_stamina()
	HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
	_reseed_zombies()
	HUD.show_feedback("You rest. The building shifts.")


func _reseed_zombies() -> void:
	# The rest-time building shift. Same reseed the crowbar crossing uses, factored
	# into WorldState.shift_building; do_rest() adds the stamina heal on top.
	WorldState.shift_building()


func _input(event: InputEvent) -> void:
	if is_dead or is_dying or is_switching_mode or is_cutscene:
		return
	if is_listening:
		# A click (like keyboard movement/actions in _physics_process) breaks
		# the listen with no report; nothing else is processed while focused.
		if event is InputEventMouseButton and event.pressed:
			_cancel_listen()
		return

	if DEV_MODE:
		# F1 item spawning is handled by dev_item_prompt.gd (typed prompt).
		if event.is_action_pressed("dev_set_health"):
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
		elif event.is_action_pressed("dev_god_mode"):
			WorldState.god_mode = !WorldState.god_mode
			HUD.show_feedback("DEV: God Mode " + ("ON" if WorldState.god_mode else "OFF"))
		elif event.is_action_pressed("dev_force_hazards"):
			# DEV (F2): CYCLE floor hazards one at a time so they never overlap —
			# off → barricades → hordes → fire → off — then REBUILD the current floor
			# so the new hazard applies right here, on both stairwells, immediately.
			# Barricade props self-sync live, but hordes (live zombies) and fire
			# fields are only spawned in building_floors._ready, so without a reload a
			# toggle to hordes/fire shows nothing until you cross to the next floor.
			WorldState.dev_hazard_mode = (WorldState.dev_hazard_mode + 1) % WorldState.DEV_HAZARD_COUNT
			var m = WorldState.dev_hazard_mode
			var msg: String
			if m == WorldState.DEV_HAZARD_NONE:
				msg = "DEV: Hazards off (seed defaults)"
			elif m in WorldState.DEV_HAZARD_UNBUILT:
				msg = "DEV: Hazard → %s (not built yet)" % WorldState.DEV_HAZARD_NAMES[m]
			else:
				msg = "DEV: Hazard → %s (every floor)" % WorldState.DEV_HAZARD_NAMES[m]
			# Rebuild the floor so the new hazard applies right here — but ONLY on the
			# floor scene (stairwells/hazards live there). In a room/hallway/lobby the
			# reload would do nothing useful, and its _ready would just re-flash text;
			# the mode still takes effect when you step back onto the floor. Carry the
			# message through the rebuild so it shows AFTER the reload, not before.
			var path := get_tree().current_scene.scene_file_path
			if path.ends_with("building_floors.tscn"):
				WorldState.saved_player_x = global_position.x
				WorldState.saved_player_y = global_position.y
				WorldState.pending_dev_feedback = msg
				get_tree().call_deferred("reload_current_scene")
			else:
				HUD.show_feedback(msg)
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
			# DEV: unlock the Wallet and grant 500 Bank Notes.
			if not WorldState.wallet_unlocked:
				WorldState.unlock_wallet()
			WorldState.add_to_inventory("033", 500)
			HUD.refresh_inventory()
			HUD.show_feedback("DEV: Wallet + 500 Bank Notes")
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
			_dev_toggle_tutorial()

	# Attack is a rebindable action (default LMB, can live on a mouse side
	# button — see SettingsManager). Combat only.
	# A MOUSE attack only swings when there's an actual target (a zombie under
	# the cursor or in reach ahead); on empty ground the click is NOT consumed,
	# so it falls through to click-to-move. A key/side-button attack always
	# swings. This is what makes left-click move in combat, not just attack.
	if not WorldState.is_scavenge_mode and event.is_action_pressed("attack"):
		if not _is_mouse_over_hud():
			var from_mouse = event is InputEventMouseButton
			if not from_mouse or _has_attack_target():
				_do_attack_action(from_mouse)
				get_viewport().set_input_as_handled()

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


func _throw_can(slot_index: int) -> void:
	# Scavenge-only distraction. Reuses the sword-swing anim for the throw
	# motion; the can flies the length of a room and its landing pulls aggro.
	if not WorldState.is_scavenge_mode:
		HUD.show_feedback("Switch to scavenge to throw.")
		return
	if is_attacking:
		return
	is_attacking = true
	attack_cooldown_timer = 0.5
	animated_sprite.play("katana_attack_continuous")
	melee_player.stream = MELEE_SLICE.pick_random()
	melee_player.pitch_scale = 1.2
	melee_player.play()
	var dir = -1.0 if animated_sprite.flip_h else 1.0
	var can = preload("res://scenes/thrown_can.tscn").instantiate()
	get_tree().current_scene.add_child(can)
	can.launch(dir, global_position + Vector2(dir * 20.0, -10.0))
	# Spend one from the stack; keep the slot (and selection) if more remain.
	var inst = WorldState.inventory[slot_index]
	if inst.count > 1:
		inst.count -= 1
	else:
		WorldState.remove_from_inventory(slot_index)
		HUD.selected_slot = -1
	HUD.refresh_inventory()
	HUD.show_feedback("Can thrown — that'll draw them.")


func _do_attack_action(from_mouse: bool) -> void:
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		HUD.show_feedback("No weapon selected.")
		return
	var instance = WorldState.get_instance_at(slot)
	var item_data = instance.get_data()
	if not item_data.get("is_weapon", false):
		HUD.show_feedback("No weapon selected.")
		return
	var weapon_type = _get_weapon_type(item_data)
	if weapon_type == "gun":
		_do_gun_attack(instance, slot)
		return
	# Melee: a mouse attack can click a distant zombie to walk over and swing;
	# a key/side-button attack just swings at whatever's in front.
	if from_mouse:
		var clicked = _zombie_under_cursor()
		var reach = WEAPON_RANGES.get(weapon_type, 40.0) + 40.0
		if clicked != null and global_position.distance_to(clicked.global_position) > reach:
			var approach = clicked.global_position.x - signf(clicked.global_position.x - global_position.x) * reach * 0.6
			set_move_target(approach)
			pending_attack = clicked
			return
	_do_melee_attack(instance, slot)


func _has_attack_target() -> bool:
	# Is there something a mouse-click should SWING at right now? A zombie under
	# the cursor, or one within reach in the facing direction. If not, the click
	# should move instead.
	var slot = HUD.selected_slot
	if slot < 0 or slot >= WorldState.inventory.size():
		return false
	var item_data = WorldState.get_instance_at(slot).get_data()
	if not item_data.get("is_weapon", false):
		return false
	if _zombie_under_cursor() != null:
		return true
	var weapon_type = _get_weapon_type(item_data)
	var reach = GUN_RANGE_MID if weapon_type == "gun" else WEAPON_RANGES.get(weapon_type, 40.0) + 24.0
	var facing_right = not animated_sprite.flip_h
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if zombie.is_dead:
			continue
		var diff = zombie.global_position.x - global_position.x
		if (facing_right and diff > -16.0) or (not facing_right and diff < 16.0):
			if global_position.distance_to(zombie.global_position) <= reach:
				return true
	return false


func _zombie_under_cursor() -> Node:
	var mouse_world = _mouse_world_pos()
	var best: Node = null
	var best_dist = 45.0
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if zombie.is_dead:
			continue
		var d = zombie.global_position.distance_to(mouse_world)
		if d < best_dist:
			best_dist = d
			best = zombie
	return best


func _is_mouse_over_hud() -> bool:
	var mouse_y = get_viewport().get_mouse_position().y
	var screen_h = get_viewport().get_visible_rect().size.y
	# Headless (tests) has a degenerate viewport rect; without this every click
	# reads as "over the HUD" and click-to-move can't be regression-tested.
	if screen_h < 200.0:
		return false
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
		# Field Medic upgrade bumps every heal by +1 state.
		var heals = item_data["heals_states"] + WorldState.get_heal_bonus()
		# Don't burn a use of the item if we're already at full health.
		if heal(heals):
			instance.use()
			if instance.is_depleted:
				WorldState.remove_from_inventory(slot_index)
				HUD.selected_slot = -1
			HUD.refresh_inventory()
	elif item_data["is_speed_boost"]:
		restore_stamina(WorldState.get_max_stamina() * 0.35)
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
		# First use equips; using the ALREADY-equipped gun reloads it.
		if HUD.selected_slot == slot_index:
			var loaded = WorldState.reload_gun(instance)
			if loaded > 0:
				HUD.show_feedback("Loaded %d — mag %d/%d." % [loaded, instance.mag_count, instance.get_mag_cap()])
			elif instance.mag_count >= instance.get_mag_cap():
				HUD.show_feedback("Magazine full.")
			else:
				HUD.show_feedback("No bullets to load.")
		else:
			HUD.selected_slot = slot_index
			HUD._update_slot_highlights()
			HUD.show_feedback("Equipped — mag %d/%d." % [instance.mag_count, instance.get_mag_cap()])
	elif item_data.get("is_throwable", false):
		_throw_can(slot_index)
	elif item_data.get("is_extinguisher", false):
		# Fire Extinguisher (036): beat back the flames around you, spend a charge.
		var field = get_tree().get_first_node_in_group("fire_field")
		if field == null or not field.any_burning():
			HUD.show_feedback("Nothing to put out here.")
			return
		field.extinguish_at(global_position.x, EXTINGUISH_RADIUS)
		instance.use()
		if instance.is_depleted:
			WorldState.remove_from_inventory(slot_index)
			if HUD.selected_slot == slot_index:
				HUD.selected_slot = -1
		HUD.refresh_inventory()
		WorldState.emit_noise(global_position, WorldState.NOISE_RADIUS["scavenge"], 1.0)
		HUD.show_feedback("You beat back the flames." if field.any_burning() else "The fire's out.")
	elif item_data.get("is_tool", false) and item_data.get("can_repair", false):
		# Toolbox: repairs the first repairable item — a damaged gun OR a
		# broken durability weapon/tool (one toolbox use). Damaged guns take
		# priority so a beaten gun beats a broken bat for the same charge.
		var target: ItemInstance = null
		for i in range(WorldState.inventory.size()):
			var other = WorldState.get_instance_at(i)
			if other == instance:
				continue
			if other.is_damaged:
				target = other
				break
			if target == null and other.is_repairable():
				target = other
		if target != null:
			var was_broken = target.is_depleted
			target.repair_full()
			instance.use()
			var noun = target.get_data().get("name", "Item")
			if instance.is_depleted:
				# Toolbox spent its last charge — it's gone (a broken toolbox
				# can't repair itself, so it isn't kept as clutter).
				WorldState.remove_from_inventory(slot_index)
				if HUD.selected_slot == slot_index:
					HUD.selected_slot = -1
			HUD.refresh_inventory()
			HUD.show_feedback(noun + (" rebuilt" if was_broken else " repaired") + ".")
			return
		HUD.show_feedback("Nothing needs repairing.")
	elif item_data.get("is_key", false):
		var target = instance.target_apartment
		if target != "":
			HUD.show_feedback("Apartment " + target + " Key")
		else:
			HUD.show_feedback("Apartment Key")
	elif item_data.get("is_clothes", false):
		# No crafting — three clothes are knotted AT a balcony during the lash.
		HUD.show_feedback("Clothes for a balcony line — need 3 (have %d)." % WorldState.count_clothes())
	elif item_data.get("is_rope", false):
		# Descending is done AT a balcony (see room.gd, balcony descent).
		HUD.show_feedback("Take this to a balcony to climb down.")
	elif item_data["is_junk"]:
		HUD.show_feedback("Nothing happens.")
	else:
		HUD.show_feedback("Not implemented yet.")


func heal(states: int) -> bool:
	if health_state == HealthState.HEALTHY:
		HUD.show_feedback("Already healthy.")
		return false
	var new_state = max(int(health_state) - states, int(HealthState.HEALTHY))
	health_state = new_state as HealthState
	WorldState.player_health = health_state
	if is_dying and health_state < HealthState.DYING:
		is_dying = false
		WorldState.is_dying = false
		WorldState.dying_timer = 0.0
	_update_hud()
	HUD.show_feedback("Used item.")
	return true


func receive_hit(amount: int = 1) -> void:
	if is_dead or is_dying:
		return
	if WorldState.god_mode:
		return
	if is_listening:
		_cancel_listen()
	if is_lashing:
		_lash_cancel = true   # a hit knocks you off the rope job
	is_hit = true
	hit_flash_timer = HIT_FLASH_DURATION
	animated_sprite.modulate = Color(1, 0, 0, 1)
	animated_sprite.play("hurt")
	take_damage(amount)


func flash_hurt() -> void:
	# The VISUAL of a hit (red flash + hurt pose) with NO damage — used on a hard
	# balcony landing to show the drop hurt, when the HP was already spent during
	# the descent. is_hit holds the hurt frame for HIT_FLASH_DURATION (see the
	# `elif is_hit: pass` in _physics_process), then it reverts on its own.
	if is_dead or is_dying:
		return
	is_hit = true
	hit_flash_timer = HIT_FLASH_DURATION
	animated_sprite.modulate = Color(1, 0, 0, 1)
	animated_sprite.play("hurt")


func enter_balcony_plane(center_x: float, below_apartment: String = "", slot: int = 0) -> void:
	# Step UP into the balcony space (depth walk): a short owned move onto the
	# balcony's own Y line, sprite scaled down a touch. Not an invincibility
	# nook — zombies follow the player up (see enemy Y-pursuit).
	if on_balcony_plane or is_cutscene or is_dead or is_dying or is_lashing or is_listening:
		return
	is_cutscene = true
	_clear_move_target()
	balcony_center_x = center_x
	_plane_return_y = global_position.y
	balcony_plane_y = global_position.y - BALCONY_PLANE_RISE
	_plane_base_scale = animated_sprite.scale
	# Load the floor below the instant we're out here, so it's visible under us
	# "in motion" while deciding — not popped in on landing. Freed on step-back.
	if below_apartment != "" and BalconyPan.can_pan():
		BalconyPan.prefetch(below_apartment, slot)
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "global_position", Vector2(
		clampf(global_position.x, center_x - BALCONY_HALF_WIDTH, center_x + BALCONY_HALF_WIDTH),
		balcony_plane_y), BALCONY_STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(animated_sprite, "scale", _plane_base_scale * BALCONY_PLANE_SCALE, BALCONY_STEP_TIME)
	await t.finished
	is_cutscene = false
	on_balcony_plane = true
	HUD.show_feedback("Out on the balcony — [S] steps back inside.")


func exit_balcony_plane() -> void:
	if not on_balcony_plane or is_cutscene or is_lashing:
		return
	on_balcony_plane = false
	# Stepped back inside without descending — deload the floor below.
	BalconyPan.clear_prefetch()
	is_cutscene = true
	_clear_move_target()
	var t = create_tween().set_parallel(true)
	t.tween_property(self, "global_position",
		Vector2(global_position.x, _plane_return_y), BALCONY_STEP_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(animated_sprite, "scale", _plane_base_scale, BALCONY_STEP_TIME)
	await t.finished
	is_cutscene = false


func restore_balcony_plane(center_x: float) -> void:
	# Re-establish the balcony-plane state after a LOAD. Unlike arrive_/enter_,
	# the saved Y is ALREADY the balcony line (the plane held the body there while
	# saved), so there is NO step-up: adopt the current Y as the plane line, put
	# the corridor return line one RISE below it, and re-apply the depth scale.
	# Without this the loaded player sits at the balcony Y but off-plane, and normal
	# depth movement drifts them onto the default line.
	balcony_center_x = center_x
	balcony_plane_y = global_position.y
	_plane_return_y = global_position.y + BALCONY_PLANE_RISE
	_plane_base_scale = animated_sprite.scale
	animated_sprite.scale = _plane_base_scale * BALCONY_PLANE_SCALE
	on_balcony_plane = true


func arrive_on_balcony_plane(center_x: float) -> void:
	# Land straight ONTO the lower balcony's plane after a descent (the drop
	# already carried the body here, so no step-up tween). Same end state as
	# enter_balcony_plane: on the balcony's own Y line, sprite scaled, free to
	# move left/right between the rails; S drops back onto the corridor.
	balcony_center_x = center_x
	global_position.x = clampf(global_position.x,
		center_x - BALCONY_HALF_WIDTH, center_x + BALCONY_HALF_WIDTH)
	_plane_return_y = global_position.y                 # corridor line for S
	balcony_plane_y = global_position.y - BALCONY_PLANE_RISE
	global_position.y = balcony_plane_y
	_plane_base_scale = animated_sprite.scale
	animated_sprite.scale = _plane_base_scale * BALCONY_PLANE_SCALE
	on_balcony_plane = true


func begin_balcony_descent(apartment_id: String, slot: int, _from_global: Vector2) -> void:
	# Triggered by W at a balcony zone (balcony_zone.gd). Rope (carried or already
	# lashed) = a stamina climb with a slip risk when tired; no rope = a jump for
	# heavier guaranteed injury.
	if is_dead or is_dying or is_cutscene or is_lashing or is_listening:
		return
	# Descent is only offered ON the balcony plane (you must step out first) and
	# works in EITHER mode (like a door or the stairs). Only a descendable (top)
	# balcony leads anywhere — its partner below is a dead-end.
	if not on_balcony_plane:
		return
	if not WorldState.is_balcony_descendable(apartment_id, slot):
		return
	if WorldState.balcony_below(apartment_id) == "":
		HUD.show_feedback("Nothing below — this is the ground floor.")
		return
	if WorldState.is_balcony_roped(apartment_id, slot):
		_do_balcony_descent(apartment_id, slot, false)   # the rope is already there
		return
	if WorldState.has_descent_rope():
		_lash_and_descend(apartment_id, slot)
	else:
		# No rope and not enough clothes — jumping is a real risk, so make it a
		# DELIBERATE second press: first press warns, a second within the window
		# commits to the jump.
		var now = Time.get_ticks_msec() / 1000.0
		# A jump always needs a DELIBERATE second press within the window (1-3 HP,
		# never on a stray tap). But the teaching dialogue box is a one-time thing:
		# shown ONCE per run, then never again — later arms get only a brief toast.
		if now - _jump_confirm_time > BALCONY_JUMP_CONFIRM_WINDOW:
			_jump_confirm_time = now
			if not WorldState.balcony_jump_warned:
				WorldState.balcony_jump_warned = true
				HUD.show_dialogue("Long drop without a rope — press again to risk the jump.", "", false, 1.6)
			else:
				HUD.show_feedback("Press again to jump.")
			return
		_jump_confirm_time = 0.0
		_do_balcony_descent(apartment_id, slot, true)     # confirmed — jump


func _lash_and_descend(apartment_id: String, slot: int) -> void:
	# Silent, timed — you stand still and can be interrupted by a hit. Materials
	# (a Rope, or 3 Clothes knotted on the spot) are spent only on completion.
	is_lashing = true
	_lash_cancel = false
	_clear_move_target()
	HUD.show_feedback("Lashing a line to the balcony…")
	var t := 0.0
	while t < BALCONY_LASH_TIME:
		if _lash_cancel or is_dead or is_dying:
			is_lashing = false
			HUD.show_feedback("Interrupted.")
			return
		await get_tree().process_frame
		t += get_process_delta_time()
	is_lashing = false
	# The line is now tied to the balcony for good — spend the materials.
	if not WorldState.consume_descent_rope():
		return   # materials vanished mid-lash (dropped?) — no free descent
	HUD.selected_slot = -1
	HUD.refresh_inventory()
	WorldState.rope_balcony(apartment_id, slot)
	_do_balcony_descent(apartment_id, slot, false)


func _do_balcony_descent(apartment_id: String, slot: int, is_jump: bool) -> void:
	# Committing to the drop — clear any lingering warning so it never carries
	# over into the pan or the floor below.
	HUD.hide_dialogue()
	var injury := 0
	if is_jump:
		# A deliberate jump hurts, but not brutally — one or two knocks.
		# (Fall-mitigation upgrades hook in here later.)
		injury = randi_range(1, 2)
	else:
		WorldState.stamina = maxf(WorldState.stamina - WorldState.BALCONY_STAMINA_COST, 0.0)
		HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())
		if randf() < WorldState.balcony_slip_chance():
			injury = 1   # a slip is a single knock
			HUD.show_feedback("Lost your grip!")
	var target = WorldState.descend_from_balcony(apartment_id)
	if target == "":
		return
	HUD.update_floor_label()
	on_balcony_plane = false
	# The injury is spent AT THE LANDING (synced with the hurt flare), NOT now —
	# so the HP/portrait don't drop early while the body is still falling. The pan
	# applies it at touchdown; the fade fallback (no pan) applies it on the spot.
	var hurt := injury > 0 and not WorldState.god_mode
	if BalconyPan.can_pan():
		WorldState.balcony_pending_injury = injury if hurt else 0
		BalconyPan.pan_down(target, slot, not is_jump)
	else:
		if hurt:
			take_damage(injury)
		WorldState.balcony_arrival_hurt = hurt
		Transition.to_scene("res://scenes/room.tscn")


func take_damage(amount: int = 1) -> void:
	for i in range(amount):
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


func _dev_toggle_tutorial() -> void:
	# DEV (F7): flip the first-run tutorial on/off and drop into a fresh Floor
	# 30 so the change takes effect immediately. Turning it ON resets the 3003
	# encounter so the scripted sequence replays from the top; turning it OFF
	# makes Floor 30 a normal procedural floor (no gate, no scripted neighbour).
	WorldState.is_first_run = not WorldState.is_first_run
	# Write the PROFILE too, so the choice sticks across restarts instead of
	# being undone the next time you press Play. Tutorial ON = "treat me as a new
	# player"; OFF = "I've seen it".
	WorldState.set_tutorial_completed(not WorldState.is_first_run)
	if WorldState.is_first_run:
		WorldState.dev_reset_tutorial()
	# Land in the Floor 30 hallway via the standard arrival path.
	WorldState.current_floor = 30
	WorldState.spawn_source = "stair"
	WorldState.stair_spawn_side = "left"
	WorldState.stair_direction = "down"
	WorldState.on_floor_arrived(30)
	if TutorialManager.has_method("cancel"):
		TutorialManager.cancel()  # drop any pending prompt / unpause
	HUD.update_floor_label()
	HUD.show_feedback("DEV: Tutorial %s — profile: %s" % [
		"ON" if WorldState.is_first_run else "OFF", WorldState.profile_status()])
	get_tree().change_scene_to_file("res://scenes/hallway.tscn")
