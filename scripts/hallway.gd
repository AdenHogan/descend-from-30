extends Node

# --- Floor-30 tutorial: the 3004 barricade beat (first run only) -----------
# Tearing the 3004 barricade is LOUD; a zombie comes up the left stairs drawn
# by the noise, walks INTO the scene but holds at a distance, and only starts
# closing once the barricade is down — so the player clearly sees the choice:
# force the 3004 lock (1 club use, take the room) or kill the zombie (2 hits,
# the club breaks, the room is lost). See docs/TUTORIAL.md.
const HALL_ZOMBIE_SPAWN_X = 80.0
const HALL_ZOMBIE_HOLD_X = 260.0
const BARRICADE_HINT_RANGE = 90.0
const HALL_ZOMBIE_CASH = 25   # Bank Notes it drops if the player fights it
var hall_zombie: Node = null
var hall_choice_prompted: bool = false
var barricade_hint_shown: bool = false
var hall_force_break_done: bool = false


func _ready() -> void:
	if WorldState.master_seed == 0:
		WorldState.new_game()
	var player = get_node("Player")
	if WorldState.spawn_source == "stair":
		if WorldState.stair_spawn_side == "left":
			player.global_position = Vector2(148, 388.0)
		elif WorldState.stair_spawn_side == "right":
			player.global_position = Vector2(1202, 388.0)
			
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	# (The first-encounter zombie now lives INSIDE 3003 per the GDD — see
	# room.gd _spawn_tutorial_zombie — not out here in the corridor. The
	# corridor's own scripted zombie is the barricade beat below.)

	# Same framing as building_floors. NOTE the hallway's tilemap is taller than a
	# floor (243..483 — blue filler above and below the corridor), so it must use
	# the SHARED floor band, not its own bounds: deriving per-scene gave floor 30
	# a different zoom from floor 29 and put that blue on screen.
	var tm = get_node_or_null("TileMapLayer")
	if tm != null:
		var cam = player.get_node_or_null("Camera2D")
		if cam != null:
			StairPan.apply_floor_camera(cam, StairPan.floor_band(tm))

	# Say out loud which player the game thinks you are — otherwise "why is the
	# tutorial running again?" is invisible guesswork.
	if not WorldState.profile_announced:
		WorldState.profile_announced = true
		HUD.show_feedback("%s — tutorial %s" % [
			WorldState.profile_status().capitalize(),
			"ON" if WorldState.is_first_run else "skipped"])

	_spawn_corpses(30)
	_spawn_world_drops(30)

	# First-run cold open: black screen, banging, locked out, remember the
	# 3003 spare key. Plays once (opener_seen), then hands to gameplay.
	if WorldState.is_first_run and WorldState.current_floor == 30 and not WorldState.opener_seen:
		WorldState.opener_seen = true
		add_child(preload("res://scripts/intro_overlay.gd").new())

	# Diegetic tutorial: blood-scrawled control hints are baked into the scene
	# (group "tutorial_blood") so they can be positioned/resized in the editor.
	# They only belong on the FIRST run — hide them otherwise.
	if not WorldState.is_first_run:
		for hint in get_tree().get_nodes_in_group("tutorial_blood"):
			hint.visible = false

func _process(_delta: float) -> void:
	if not (WorldState.is_first_run and WorldState.current_floor == 30):
		return
	_maybe_hint_barricade()
	_maybe_break_club_on_force()
	if WorldState.killed_zombies.has(TutorialManager.HALLWAY_ZOMBIE_KEY):
		return
	var d3004 = WorldState.get_door_state("3004")
	var barricade_up = d3004 == WorldState.DoorState.BARRICADED_LOCKED \
			or d3004 == WorldState.DoorState.BARRICADED_FORCEABLE
	# The noise of barricade work summons it (once any progress is banked);
	# if the barricade is already down (re-entry), it's simply here.
	if hall_zombie == null:
		if WorldState.barricade_progress.get("3004", 0.0) > 0.05 or not barricade_up:
			_spawn_hall_zombie()
		return
	if not is_instance_valid(hall_zombie) or hall_zombie.is_dead:
		return
	# The barricade just came down: the corridor zombie is loose. No forced
	# kill-vs-3004 pause any more (the descent choice at the stairs is the real
	# decision) — just say the line and release it as an emergent threat.
	if not barricade_up and hall_zombie.tutorial_frozen and not hall_choice_prompted:
		hall_choice_prompted = true
		TutorialManager.say(TutorialManager.LINES["hall_choice"])
		_release_hall_zombie()


func start_opener_lockout() -> void:
	# Called by intro_overlay after the title fades: the player (visible now,
	# not on black) steps up and bangs on their own door 3001, gets no answer,
	# then remembers the 3003 spare key. knock_door provides the up-to-the-door
	# movement; the lines chain on any key / click.
	var player = get_tree().get_first_node_in_group("player")
	var door = get_node_or_null("3001")
	if player == null:
		return
	if door != null and player.has_method("knock_door"):
		player.knock_door(door.global_position, _opener_lockout_lines)
	else:
		_opener_lockout_lines()


func _opener_lockout_lines() -> void:
	TutorialManager.prompt(TutorialManager.LINES["opener_4"], "interact", _opener_lockout_line2, "[continue]")


func _opener_lockout_line2() -> void:
	TutorialManager.prompt(TutorialManager.LINES["opener_5"], "interact", _opener_lockout_done, "[continue]")


func _opener_lockout_done() -> void:
	pass


func _maybe_hint_barricade() -> void:
	# After 3003 is cleared, the first time the player walks past the still-
	# barricaded 3004, pause and flag that it can be torn down — faster with a
	# weapon (foreshadows both the removal AND that it'll cost durability).
	if barricade_hint_shown:
		return
	if not WorldState.killed_zombies.has(TutorialManager.TUTORIAL_ZOMBIE_KEY):
		return  # 3003 not cleared yet
	var d3004 = WorldState.get_door_state("3004")
	if not (d3004 == WorldState.DoorState.BARRICADED_LOCKED
			or d3004 == WorldState.DoorState.BARRICADED_FORCEABLE):
		return
	var player = get_tree().get_first_node_in_group("player")
	var door = get_node_or_null("3004")
	if player == null or door == null:
		return
	if absf(player.global_position.x - door.global_position.x) > BARRICADE_HINT_RANGE:
		return
	barricade_hint_shown = true
	TutorialManager.prompt(
		TutorialManager.LINES["3004_hint"],
		"interact", _on_barricade_hint, "[E] to continue")


func _on_barricade_hint() -> void:
	pass


func _maybe_break_club_on_force() -> void:
	# The force-vs-fight choice must leave the player weaponless either way:
	# fighting breaks the club on the 2nd hit; forcing 3004's lock would leave
	# a sliver of durability, so we snap it here — the scripted "one job left"
	# payoff — the moment 3004 opens. (They pick up the 3005 Hammer next.)
	if hall_force_break_done:
		return
	if not WorldState.killed_zombies.has(TutorialManager.TUTORIAL_ZOMBIE_KEY):
		return  # barricade beat not reached yet
	if WorldState.get_door_state("3004") != WorldState.DoorState.OPEN:
		return
	hall_force_break_done = true
	var broke = false
	for i in range(WorldState.inventory.size()):
		var inst = WorldState.inventory[i]
		if inst.item_id == "012" and not inst.is_depleted:
			inst.current_durability = 0
			inst.is_depleted = true
			if HUD.selected_slot == i:
				HUD.selected_slot = -1
			broke = true
	HUD.refresh_inventory()
	if broke:
		TutorialManager.prompt(TutorialManager.LINES["hall_force_break"],
			"interact", _on_force_break, "[E]")


func _on_force_break() -> void:
	pass


func _release_hall_zombie() -> void:
	if hall_zombie != null and is_instance_valid(hall_zombie):
		hall_zombie.tutorial_shamble = true
		hall_zombie.tutorial_release()


func _spawn_hall_zombie() -> void:
	var zombie = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	zombie.global_position = Vector2(HALL_ZOMBIE_SPAWN_X, 388.0)
	zombie.spawn_key = TutorialManager.HALLWAY_ZOMBIE_KEY
	zombie.tutorial_scripted = true   # deterministic 2-hit kill, no RNG
	zombie.tutorial_frozen = true
	zombie.tutorial_hold_x = HALL_ZOMBIE_HOLD_X
	zombie.tutorial_cash_drop = HALL_ZOMBIE_CASH  # fighting it still pays out
	if WorldState.zombie_positions.has(TutorialManager.HALLWAY_ZOMBIE_KEY):
		var saved = WorldState.zombie_positions[TutorialManager.HALLWAY_ZOMBIE_KEY]
		zombie.global_position = Vector2(saved["x"], saved["y"])
	add_child(zombie)
	hall_zombie = zombie
	TutorialManager.say_once("hall_zombie", TutorialManager.LINES["hall_zombie"])


func _spawn_corpses(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var corpse_positions = WorldState.get_corpse_positions_for_floor(floor_num, scene_path)
	if corpse_positions.is_empty():
		return
	# Corpse visuals are type-aware: standard zombies have a looping "Dead_Dead"
	# frame; the big zombie has no Dead_Dead, so its corpse shows the final frame
	# of its "Death" animation, paused.
	var std_instance = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	var std_frames = std_instance.get_node("AnimatedSprite2D").sprite_frames
	std_instance.queue_free()
	var big_instance = preload("res://scenes/enemy_zombie_big.tscn").instantiate()
	var big_frames = big_instance.get_node("AnimatedSprite2D").sprite_frames
	big_instance.queue_free()
	for entry in corpse_positions:
		var corpse = AnimatedSprite2D.new()
		corpse.scale = Vector2(3, 3)
		if entry["type"] == "big":
			corpse.sprite_frames = big_frames
			corpse.animation = "Death"
			corpse.frame = big_frames.get_frame_count("Death") - 1
		else:
			corpse.sprite_frames = std_frames
			corpse.animation = "Dead_Dead"
			corpse.autoplay = "Dead_Dead"
		corpse.global_position = entry["pos"]
		corpse.z_index = 0
		add_child(corpse)

func _spawn_world_drops(floor_num: int) -> void:
	var scene_path = get_tree().current_scene.scene_file_path
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.amount = int(data.get("amount", 0))
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)
