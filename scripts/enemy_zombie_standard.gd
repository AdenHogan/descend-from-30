extends CharacterBody2D

const SPEED = 40.0
const DETECTION_RANGE = 100.0
const ATTACK_RANGE = 30.0

# On fire: a zombie standing in flame catches, gets a flame overlay, and its
# attacks hit for DOUBLE (a burning corpse lunging at you is far worse). Toggled
# by building_floors._process as it moves in and out of the fire.
const ENEMY_FIRE := preload("res://scripts/enemy_fire.gd")
const BODY_SMOKE := preload("res://scripts/body_smoke.gd")
var on_fire: bool = false: set = _set_on_fire
var _fire_fx = null


var _burn_acc: float = 0.0
const BURN_INTERVAL := 1.5           # fire damage-over-time cadence (in flame)


func _set_on_fire(v: bool) -> void:
	if v == on_fire:
		return
	on_fire = v
	if not v:
		_burn_acc = 0.0
	if v and _fire_fx == null:
		_fire_fx = ENEMY_FIRE.new()
		_fire_fx.position = Vector2(0, -6)
		add_child(_fire_fx)
	elif not v and _fire_fx != null:
		_fire_fx.queue_free()
		_fire_fx = null


func make_burnt_corpse() -> void:
	# Spawn straight into a dead, smouldering state — no AI, no collision, no loot. Used
	# for a BLAZE-stage apartment where everyone already burned to death (room.gd).
	is_dead = true
	state = "dead"
	set_physics_process(false)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if animated_sprite:
		animated_sprite.play("Death")
		# settle on the final (dead-on-the-ground) frame, not the standing first frame
		animated_sprite.animation_finished.connect(
			func(): if is_instance_valid(animated_sprite): animated_sprite.pause(),
			CONNECT_ONE_SHOT)
	var sm = BODY_SMOKE.new()
	sm.position = Vector2(0, -6)
	add_child(sm)


func burn_tick(delta: float) -> void:
	# Standing in fire burns me: accumulate and take a QUIET hit on a cadence (no
	# flinch, no knockdown — I keep shambling, alight) until the flames kill me. Same
	# rule as the player: if fire hurts them, it hurts me. Driven by building_floors.
	if is_dead:
		return
	_burn_acc += delta
	if _burn_acc >= BURN_INTERVAL:
		_burn_acc = 0.0
		current_hp -= 1
		if current_hp <= 0:
			_die()
const PUSH_FRICTION = 0.85
const HIT_DURATION = 2
const RECOVER_DURATION = 0.5
const KNOCKDOWN_DURATION = 3.0

# --- Tutorial (scripted 3003 zombie) --------------------------------------
# The first-run neighbour is hand-tuned, not RNG: it starts frozen facing the
# back wall, closes at normal pace once released (the menacing first advance),
# dies in exactly two golf-club swings, and after the scripted push takes a
# DOUBLE-length stagger then a slow shamble — paced so the player can search
# all three nodes (3s each + walking + thinking, ~17s) and the neighbour
# arrives just as the golf club comes up. See room.gd / docs/TUTORIAL.md.
const TUTORIAL_SHAMBLE_SPEED = 35.0
const TUTORIAL_HITS_TO_DIE = 2
# Post-push recover: hit slide (2s) + this = ~5s total, double a normal push.
const TUTORIAL_PUSH_FREEZE = 3.0
var tutorial_scripted: bool = false
var tutorial_frozen: bool = false    # idle until the script releases it
var tutorial_shamble: bool = false   # after the scripted push: slow pursuit
var tutorial_long_recover: bool = false
var tutorial_hits: int = 0
# While frozen, a hold point >= 0 makes the zombie WALK there first, then wait
# facing the player — the barricade beat's "arrive on scene but keep distance
# until the barricade is down" behaviour (docs/TUTORIAL.md).
var tutorial_hold_x: float = -1.0
# Key drop (tutorial neighbour yields the 3002 key on death — matching the big
# zombie's drop pattern).
var drops_key: bool = false
var key_target_apartment: String = ""
var key_dropped: bool = false
# Tutorial corridor zombie: a guaranteed Bank Notes bundle on death, so
# choosing to FIGHT it (instead of forcing 3004) isn't walking away empty —
# the door-vs-enemy risk/reward stays real, both paths pay out.
var tutorial_cash_drop: int = 0

var animated_sprite: AnimatedSprite2D
var player: Node2D = null
var state = "idle"
var state_timer = 0.0
var spawn_key: String = ""

var max_hp: int = 3
var current_hp: int = 3
var is_dead: bool = false
# The corridor walking line this zombie spawned on. When the player steps up
# onto a balcony plane, close zombies CLIMB UP after them (the balcony is not a
# safe island — THREE_RUN_ARC); otherwise they hold their own line.
var base_walk_y: float = 0.0
const PLANE_PURSUIT_X = 140.0     # close enough in X to start climbing
const PLANE_PURSUIT_MAX = 60.0    # never chase further off-line than this
const PLANE_CLIMB_SPEED = 45.0
var passable_to_player: bool = false
# Gunfire (and future noise sources) override detection range while this runs.
var alert_timer: float = 0.0
# Thrown-can distraction: overrides chase; the zombie walks to the sound and
# stays fixated on it for distraction_timer seconds (the can's whole life). While
# distracted it ignores the player's proximity entirely — only a loud noise
# (break_distraction) pulls it off. When the timer runs out (the can despawns)
# normal aggro resumes.
var is_distracted: bool = false
var distraction_target: Vector2 = Vector2.ZERO
var distraction_timer: float = 0.0


# --- A single enemy on the stairs, using the PLAYER'S stair slice -----------
# A stairwell enemy is just a STANDARD zombie that spawns partway down the stairs
# instead of out on the corridor. It's drawn with the EXACT slice the player's stair
# transition uses (StairPan.SHRED_SHADER): the player's own mouth cut feeds the body
# through feet-first, so sunk in the shaft it shows only its upper half — sliced,
# waiting. The player's depth scale (DOWN_DEPTH_SCALE) sits it back in the shaft. The
# x-band + top clip come from the staircase art so it stays framed by the opening.
#
# Sequence (what the player sees): it waits sliced, drifting a little up/down. When
# the player gets close it RISES up the steps — appearing slice by slice, head first,
# as it clears the fixed cut — grows to full size, and as it steps onto the corridor
# the last of the slice sweeps off its feet (the player's own arrival reveal). Only
# THEN is it a solid, attackable/pushable, ordinary chaser. While still on the steps
# it is passable and unharmable — you fight it once it's off the stairwell.
var stair_mode: bool = false
var _stair_plane_y: float = 391.0      # corridor standing line (where it steps off)
var _stair_rest_y: float = 401.0       # where it waits, sunk in the shaft
var _stair_bob_amp: float = 0.0        # gentle up/down drift while waiting
var _stair_dir: float = -1.0
var _stair_cut_y: float = 1.0e9        # the player's mouth cut (fixed) — feet-first slice
var _stair_shaft_min: float = -1.0e9   # opening x-band, from the staircase art
var _stair_shaft_max: float = 1.0e9
var _stair_clip_top: float = -1.0e9    # top edge of the opening, from the staircase art
var _stair_phase: String = "idle"      # idle → rise → stepoff → (normal AI)
var _stair_reveal_t: float = 0.0
var _stair_face_flip: bool = false
var _stair_mat: ShaderMaterial = null
var _stair_base_scale: Vector2 = Vector2.ONE
const STAIR_ACTIVATE_RANGE := 170.0    # player this close in X → it rises and emerges
const STAIR_IDLE_SPEED := 10.0         # gentle up/down drift while waiting
const STAIR_RISE_SPEED := 40.0         # climbing up the steps toward the corridor
const STAIR_STEPOFF_TIME := 0.22       # the arrival reveal (cut sweeps off the feet)
const STAIR_DEPTH_SPAN := 44.0         # how far below the plane counts as "fully in the shaft"


func enter_stairwell_mode(rest_y: float, plane_y: float, bob_amp: float, cut_y: float,
		shaft_min: float, shaft_max: float, clip_top: float, on_left: bool) -> void:
	stair_mode = true
	_stair_plane_y = plane_y
	_stair_rest_y = rest_y
	_stair_bob_amp = bob_amp
	_stair_cut_y = cut_y
	_stair_shaft_min = shaft_min
	_stair_shaft_max = shaft_max
	_stair_clip_top = clip_top
	_stair_face_flip = not on_left      # left stairwell faces right (toward the corridor), right faces left
	_stair_phase = "idle"
	base_walk_y = plane_y               # once it steps off, its corridor line is the standing plane
	global_position.y = rest_y
	_stair_dir = -1.0
	if animated_sprite != null:
		_stair_base_scale = animated_sprite.scale
	# No invisible wall and no damage while it's on the steps — you interact once it
	# has stepped off (below, when the sequence finishes).
	_make_passable_to_player()
	_apply_stair_slice()
	_update_stair_draw()


func _apply_stair_slice() -> void:
	# The player's shredder, verbatim: clip_dir +1 (discard below the cut = sliced
	# feet-first, exactly as _descend does) and the player's own mouth cut. The x-band
	# and top clip come from the staircase art so the body stays framed by the opening.
	if animated_sprite == null:
		return
	if _stair_mat == null:
		var sh := Shader.new()
		sh.code = StairPan.SHRED_SHADER
		_stair_mat = ShaderMaterial.new()
		_stair_mat.shader = sh
		_stair_mat.set_shader_parameter("clip_dir", 1.0)
	_stair_mat.set_shader_parameter("cut_y", _stair_cut_y)
	_stair_mat.set_shader_parameter("shaft_min", _stair_shaft_min)
	_stair_mat.set_shader_parameter("shaft_max", _stair_shaft_max)
	_stair_mat.set_shader_parameter("shaft_top", _stair_clip_top)
	animated_sprite.material = _stair_mat


func _update_stair_draw() -> void:
	# Depth scale from the player's constant, eased by how deep in the shaft it sits:
	# full size at the plane, shrinking to DOWN_DEPTH_SCALE when fully sunk.
	if animated_sprite == null:
		return
	var depth: float = clampf((global_position.y - _stair_plane_y) / STAIR_DEPTH_SPAN, 0.0, 1.0)
	var s: float = lerpf(1.0, StairPan.DOWN_DEPTH_SCALE, depth)
	animated_sprite.scale = _stair_base_scale * s


func _exit_stairwell_mode() -> void:
	# Back to an ordinary corridor zombie: drop the slice, restore full size. It stays
	# passable until the normal AI's _try_resolidify makes it solid once the player is
	# clear — so it never re-solidifies while overlapping the player.
	stair_mode = false
	_stair_phase = "done"
	if animated_sprite != null and is_instance_valid(animated_sprite):
		if animated_sprite.material == _stair_mat:
			animated_sprite.material = null
		animated_sprite.scale = _stair_base_scale


func _stair_tick(delta: float) -> bool:
	# Returns true while stairwell mode still owns this zombie (skip normal AI). A can
	# distraction hands straight off to the normal machine (it walks to the sound).
	if state == "distracted":
		_exit_stairwell_mode()
		return false
	velocity.x = 0.0
	match _stair_phase:
		"idle":
			# Wait, sliced, drifting gently up/down. The player getting close (or a
			# noise) starts it rising up the steps.
			var near: bool = player != null \
				and absf(player.global_position.x - global_position.x) <= STAIR_ACTIVATE_RANGE
			if near or alert_timer > 0.0:
				_stair_phase = "rise"
			else:
				global_position.y += _stair_dir * STAIR_IDLE_SPEED * delta
				if global_position.y <= _stair_rest_y - _stair_bob_amp:
					global_position.y = _stair_rest_y - _stair_bob_amp
					_stair_dir = 1.0
				elif global_position.y >= _stair_rest_y + _stair_bob_amp:
					global_position.y = _stair_rest_y + _stair_bob_amp
					_stair_dir = -1.0
				if animated_sprite != null:
					animated_sprite.play("Walk")
					animated_sprite.flip_h = _stair_face_flip
				_update_stair_draw()
			return true
		"rise":
			# Climb up the steps to the standing plane. The fixed mouth cut reveals the
			# body slice by slice (head first) as it clears the cut; it grows to full size.
			global_position.y = move_toward(global_position.y, _stair_plane_y, STAIR_RISE_SPEED * delta)
			if animated_sprite != null:
				animated_sprite.play("Walk")
				if player != null:
					animated_sprite.flip_h = player.global_position.x < global_position.x
				else:
					animated_sprite.flip_h = _stair_face_flip
			_update_stair_draw()
			if absf(global_position.y - _stair_plane_y) <= 0.5:
				global_position.y = _stair_plane_y
				_stair_phase = "stepoff"
				_stair_reveal_t = 0.0
			return true
		"stepoff":
			# The arrival reveal: sweep the cut down past the feet so the last of the
			# slice (the lower legs) fades in as it steps off, then hand to normal AI.
			_stair_reveal_t += delta
			var f: float = clampf(_stair_reveal_t / STAIR_STEPOFF_TIME, 0.0, 1.0)
			if _stair_mat != null:
				_stair_mat.set_shader_parameter("cut_y", lerpf(_stair_cut_y, _stair_plane_y + 140.0, f))
			if animated_sprite != null:
				animated_sprite.play("Walk")
			if f >= 1.0:
				_exit_stairwell_mode()
				state = "chase"
				return false                    # this frame: run normal AI (it chases)
			return true
	return false


func be_distracted(pos: Vector2, duration: float = 6.0) -> void:
	if is_dead or state in ["hit", "recovering", "knockdown"]:
		return
	is_distracted = true
	distraction_target = pos
	distraction_timer = duration
	alert_timer = 0.0  # the can wins over prior gunfire/sight aggro
	state = "distracted"
	animated_sprite.play("Walk")


func break_distraction() -> void:
	# A loud enough noise (running, forcing a door, gunfire — see emit_noise)
	# snaps a can-distracted zombie back onto the player. Quiet movement won't.
	if not is_distracted:
		return
	is_distracted = false
	distraction_timer = 0.0
	state = "chase"
	animated_sprite.play("Walk")

# Off-screen presence: positional moans/shuffles the player can HEAR before
# seeing (docs/SOUND_STEALTH.md — this is why roaming listen isn't needed).
const MOAN_STREAMS = [
	preload("res://assets/audio/zombie/moan_1.wav"),
	preload("res://assets/audio/zombie/moan_2.wav"),
	preload("res://assets/audio/zombie/moan_3.wav"),
	preload("res://assets/audio/zombie/moan_4.wav"),
]
var moan_player: AudioStreamPlayer2D = null
var moan_timer: float = 0.0
# Each zombie gets its own voice (pitch offset) so a crowd never choruses.
var voice_pitch: float = 1.0


func alert_to_noise(duration: float = 6.0) -> void:
	alert_timer = max(alert_timer, duration)

func _ready() -> void:
	# ACTOR LAYER: player + enemies render one z-layer above the corridor
	# backdrop (walls, static doors, the merchant's elevator doors, and any
	# future dynamic door art at z 0), so nothing on the wall ever clips over
	# a living body. Backdrop stays at z 0; actors at z 1.
	z_index = 1
	animated_sprite = $AnimatedSprite2D
	animated_sprite.play("Idle")
	player = get_tree().get_first_node_in_group("player")
	base_walk_y = global_position.y
	add_to_group("zombie")
	_set_hp_from_floor()
	_register_zombie_exceptions()
	moan_player = AudioStreamPlayer2D.new()
	moan_player.name = "MoanPlayer"
	moan_player.volume_db = -2.0
	moan_player.max_distance = 650.0
	# Enemy SFX bus so the stair ascent can fade the floor's moans out without
	# quieting the music (see Game._ensure_enemy_bus).
	if AudioServer.get_bus_index(Game.ENEMY_BUS) != -1:
		moan_player.bus = Game.ENEMY_BUS
	add_child(moan_player)
	voice_pitch = randf_range(0.82, 1.22)
	moan_timer = randf_range(0.5, 9.0)

func _register_zombie_exceptions() -> void:
	# Swarm fix: zombies ignore collisions with each other (mutually), so a group
	# converges and overlaps instead of queueing behind the front one. No layer or
	# mask changes anywhere — walls, player, doors, stairs all untouched.
	for other in get_tree().get_nodes_in_group("zombie"):
		if other != self and other is PhysicsBody2D:
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)

func _make_passable_to_player() -> void:
	# A staggered/knocked-down zombie stops blocking the player, so the push
	# mechanic lets you shove past. Uses collision exceptions, not layers.
	if player and not passable_to_player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
		passable_to_player = true

func _try_resolidify() -> void:
	# Restore solidity only once the player is clear, so the zombie never
	# re-solidifies while overlapping the player (which would jam both bodies).
	if not passable_to_player or player == null:
		return
	if global_position.distance_to(player.global_position) > 26.0:
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
		passable_to_player = false

func _set_hp_from_floor() -> void:
	var floor_num = WorldState.current_floor
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(floor_num))
	var base = lerp(7.0, 1.0, float(floor_num - 1) / 29.0)
	var variance = rng.randi() % 3 - 1
	max_hp = clamp(int(base) + variance, 1, 8)
	current_hp = max_hp

func receive_push(force: float) -> void:
	if stair_mode:
		return   # still on the steps — no interaction until it has stepped off
	if state == "hit" or state == "recovering" or state == "knockdown" or is_dead:
		return
	velocity.x = clamp(force, -200.0, 200.0)
	state = "hit"
	state_timer = HIT_DURATION
	animated_sprite.play("Hit")
	_make_passable_to_player()

func tutorial_release() -> void:
	# room.gd releases the frozen neighbour into its slow approach.
	tutorial_frozen = false


func tutorial_stagger() -> void:
	# The scripted push: a real knockback (so the shove visibly connects even
	# if the player's own push whiffed on range), then a double-length recover,
	# then the slow shamble. Passable while staggered so the player can slip by.
	if state != "hit" and player != null:
		# The player's _do_push didn't reach it — apply the shove ourselves.
		var push_dir = signf(global_position.x - player.global_position.x)
		velocity.x = (push_dir if push_dir != 0.0 else 1.0) * 180.0
		state = "hit"
		state_timer = HIT_DURATION
		animated_sprite.play("Hit")
	tutorial_long_recover = true
	tutorial_shamble = true
	_make_passable_to_player()


func receive_damage(amount: int, damage_type: String) -> void:
	if stair_mode:
		return   # still on the steps — no interaction until it has stepped off
	if is_dead or state == "knockdown":
		return
	# Scripted combat: no luck. Exactly two golf-club hits put the neighbour
	# down, no knockdown/instakill rolls, whatever the weapon's raw damage.
	if tutorial_scripted:
		tutorial_hits += 1
		if tutorial_hits >= TUTORIAL_HITS_TO_DIE:
			_die()
		else:
			state = "hit"
			state_timer = HIT_DURATION
			animated_sprite.play("Hit")
		return
	current_hp -= amount
	if current_hp <= 0:
		if damage_type == "blade":
			var rng = RandomNumberGenerator.new()
			rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
			if rng.randf() < 0.6:
				_die()
				return
			else:
				current_hp = 1
		else:
			_die()
			return
	if damage_type == "bludgeon":
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
		if rng.randf() < 0.55:
			_knockdown()
			return
	animated_sprite.play("Hit")

func _knockdown() -> void:
	state = "knockdown"
	state_timer = KNOCKDOWN_DURATION
	velocity.x = 0
	animated_sprite.play("Hit")
	_make_passable_to_player()

func _exit_tree() -> void:
	# Leaving this floor (stairs, apartment door, save/quit): remember where I am,
	# facing which way, how hurt — so returning doesn't reset me to my seeded
	# spawn. record_zombie skips the dead (killed_zombies has those), keyless, and
	# pan-backdrop scenery. Guard the autoload in case this fires during shutdown.
	if is_instance_valid(WorldState):
		WorldState.record_zombie(self)


func _die() -> void:
	is_dead = true
	if on_fire:                    # died alight → the corpse smoulders (smoke, not flame)
		var sm = BODY_SMOKE.new()
		sm.position = Vector2(0, -6)
		add_child(sm)
	on_fire = false                # the flames go out the instant it dies (clears the fx)
	state = "dead"
	velocity.x = 0
	animated_sprite.play("Death")
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	if spawn_key != "" and not WorldState.killed_zombies.has(spawn_key):
		WorldState.killed_zombies[spawn_key] = {
			"x": snappedf(global_position.x, 1.0),
			"y": snappedf(global_position.y, 1.0),
			"floor": WorldState.current_floor,
			"scene": get_tree().current_scene.scene_file_path,
			"apartment_id": WorldState.current_apartment_id,
			"type": "standard"
		}

	# Tutorial neighbour yields the 3002 key on death (its scripted reward);
	# it doesn't also roll the random consumable drop.
	if drops_key and key_target_apartment != "" and not key_dropped:
		key_dropped = true
		_drop_key()
		await animated_sprite.animation_finished
		animated_sprite.pause()
		await get_tree().create_timer(300).timeout
		queue_free()
		return

	# Tutorial corridor zombie: guaranteed cash instead of the random roll.
	if tutorial_cash_drop > 0:
		_drop_tutorial_cash()
		await animated_sprite.animation_finished
		animated_sprite.pause()
		await get_tree().create_timer(300).timeout
		queue_free()
		return

# Roll for loot drop — 18% chance, consumables only
	var loot_id = WorldState.roll_zombie_loot_id(global_position, WorldState.current_floor)
	if loot_id != "":
		var drop_scene = preload("res://scenes/world_drop.tscn")
		var drop = drop_scene.instantiate()
		drop.item_id = loot_id
		drop.drop_key = str(WorldState.current_floor) + ":" + str(snappedf(global_position.x, 1.0)) + ":" + str(snappedf(global_position.y, 1.0))
		drop.global_position = global_position
		get_parent().add_child(drop)
 
	await animated_sprite.animation_finished
	animated_sprite.pause()
	await get_tree().create_timer(300).timeout
	queue_free()

func _drop_tutorial_cash() -> void:
	# Register the drop (for persistence) AND spawn the visible pickup now —
	# same pattern the big zombie uses for its cash bundle.
	var pos = global_position
	WorldState.add_world_drop("033", pos, WorldState.current_floor, {"amount": tutorial_cash_drop})
	var drop = preload("res://scenes/world_drop.tscn").instantiate()
	drop.item_id = "033"
	drop.amount = tutorial_cash_drop
	drop.drop_key = str(WorldState.current_floor) + ":" + str(snappedf(pos.x, 1.0)) + ":" + str(snappedf(pos.y, 1.0))
	drop.global_position = pos
	get_parent().add_child(drop)
	HUD.show_feedback("It was carrying cash — grab it.")


func _drop_key() -> void:
	var added = WorldState.add_key_to_inventory(key_target_apartment)
	if added:
		HUD.show_feedback("Key — Apt " + key_target_apartment + " found!")
	else:
		WorldState.add_world_drop("022", global_position, WorldState.current_floor, {"target_apartment": key_target_apartment})
		HUD.show_feedback("Key dropped nearby — inventory full.")


func receive_hit_from_gun(outcome: String) -> void:
	if is_dead or stair_mode:
		return   # on the steps: unharmable until it has stepped off
	match outcome:
		"headshot":
			_die()
		"body":
			receive_damage(2, "bullet")
		"miss":
			pass

func _update_plane_pursuit(delta: float) -> void:
	# Balcony is not a safe island: an aggro'd zombie (chasing or attacking) that
	# is close in X climbs UP onto the player's raised balcony line to keep
	# attacking, and eases back to its own corridor line when the player drops
	# back inside. Scripted tutorial zombies never do this (no F30 balconies).
	if tutorial_scripted or player == null:
		return
	var aggro := state in ["chase", "attack"] or alert_timer > 0.0
	var pursue_y := base_walk_y
	if aggro and absf(player.global_position.x - global_position.x) < PLANE_PURSUIT_X \
			and absf(player.global_position.y - base_walk_y) <= PLANE_PURSUIT_MAX:
		pursue_y = player.global_position.y
	global_position.y = move_toward(global_position.y, pursue_y, PLANE_CLIMB_SPEED * delta)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if alert_timer > 0:
		alert_timer -= delta

	moan_timer -= delta
	if moan_timer <= 0.0:
		moan_timer = randf_range(3.0, 14.0)
		moan_player.stream = MOAN_STREAMS.pick_random()
		moan_player.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
		moan_player.play()

	# Stairwell horde: while idle up in the shaft, run the shuffle/slice; it returns
	# false the frame it commits to coming down, so normal AI takes over seamlessly.
	if stair_mode and _stair_tick(delta):
		move_and_slide()
		return

	_update_plane_pursuit(delta)

	match state:
		"knockdown":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var rng = RandomNumberGenerator.new()
				rng.seed = hash(str(WorldState.master_seed) + str(global_position) + str(Time.get_ticks_msec()))
				if rng.randf() < 0.6:
					state = "chase"
					animated_sprite.play("Walk")
				else:
					_die()
		"hit":
			velocity.x *= PUSH_FRICTION
			state_timer -= delta
			if state_timer <= 0:
				state = "recovering"
				# Scripted push: double-length recover so the player can turn
				# and start searching before the shamble begins.
				state_timer = TUTORIAL_PUSH_FREEZE if tutorial_long_recover else RECOVER_DURATION
				tutorial_long_recover = false
				animated_sprite.play("Idle")
		"recovering":
			velocity.x = move_toward(velocity.x, 0, SPEED)
			state_timer -= delta
			if state_timer <= 0:
				state = "chase"
		"attack":
			velocity.x = 0
			state_timer -= delta
			if state_timer <= 0:
				var distance = global_position.distance_to(player.global_position)
				if distance <= ATTACK_RANGE:
					if player and player.has_method("receive_hit"):
						player.receive_hit(2 if on_fire else 1)
				state = "chase"
				animated_sprite.play("Walk")
		"distracted":
			_try_resolidify()
			distraction_timer -= delta
			if distraction_timer <= 0.0:
				# The can's gone quiet (it despawns about now) — normal aggro
				# resumes next frame via the chase block.
				is_distracted = false
				state = "chase"
				animated_sprite.play("Walk")
			else:
				var to_can = distraction_target.x - global_position.x
				if abs(to_can) <= 20.0:
					# At the can: loiter, fixated on the sound. The player walking
					# up does NOT pull it back — only a loud noise does.
					velocity.x = 0
					animated_sprite.flip_h = distraction_target.x < global_position.x
					animated_sprite.play("Idle")
				else:
					var dir = signf(to_can)
					velocity.x = dir * SPEED
					animated_sprite.flip_h = dir < 0
					animated_sprite.play("Walk")
		"chase", "idle":
			_try_resolidify()
			# Scripted zombie: stays put until the script releases it, then
			# closes in at a slow, telegraphed pace so the player can scavenge.
			# With a hold point set it first walks THERE (arriving on scene),
			# then waits facing the player — visible menace, held at distance.
			if tutorial_scripted and tutorial_frozen:
				if tutorial_hold_x >= 0.0 and absf(global_position.x - tutorial_hold_x) > 6.0:
					var hold_dir = signf(tutorial_hold_x - global_position.x)
					velocity.x = hold_dir * SPEED
					animated_sprite.flip_h = hold_dir < 0
					animated_sprite.play("Walk")
				else:
					velocity.x = 0
					if player == null:
						player = get_tree().get_first_node_in_group("player")
					if player != null:
						animated_sprite.flip_h = player.global_position.x < global_position.x
					animated_sprite.play("Idle")
				move_and_slide()
				return
			if player == null:
				player = get_tree().get_first_node_in_group("player")
			if player != null:
				# Scripted neighbour: normal pace on the first advance (menace),
				# slow shamble after the push (paced for the three searches).
				var move_speed = SPEED
				if tutorial_scripted and tutorial_shamble:
					move_speed = TUTORIAL_SHAMBLE_SPEED
				var distance = global_position.distance_to(player.global_position)
				var effective_detection = DETECTION_RANGE if alert_timer <= 0 else 2000.0
				if tutorial_scripted:
					effective_detection = 2000.0  # always aware once released
				if distance <= ATTACK_RANGE:
					state = "attack"
					state_timer = 0.8
					animated_sprite.play("Attack")
				elif distance <= effective_detection:
					state = "chase"
					var direction = sign(player.global_position.x - global_position.x)
					velocity.x = direction * move_speed
					animated_sprite.flip_h = direction < 0
					animated_sprite.play("Walk")
				else:
					state = "idle"
					velocity.x = 0
					animated_sprite.play("Idle")
	move_and_slide()
