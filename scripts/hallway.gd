extends Node2D

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


# Stair-pan support (same contract as building_floors): StairPan builds floor 30 as a
# PASSIVE backdrop above floor 29 when you climb back up, so it scrolls into view like
# any other floor, then promotes it in place with go_live(). Set BEFORE add_child().
var setup_floor: int = -1
var passive: bool = false
var _dormant: Array = []
const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")


func _ready() -> void:
	if WorldState.master_seed == 0:
		WorldState.new_game()
	if passive:
		# Drawn exactly as it will be once you arrive — corpses, drops, a fallen character,
		# lamps — but inert: no player, no triggers, no tutorial logic, no tint of its own
		# (one CanvasModulate per canvas; the live floor's grade covers the pan).
		PanBackdrop.drop_scene_player(self)
		_build_world()
		_dormant = PanBackdrop.make_inert(self)
		return
	var player = get_node("Player")
	WorldState.apply_time_tint(self, 30)   # top of the building — least infected
	if WorldState.spawn_source == "stair":
		# Y 386 = the shared corridor plane origin (feet on 419, level with every enemy).
		if WorldState.stair_spawn_side == "left":
			player.global_position = Vector2(148, 386.0)
		elif WorldState.stair_spawn_side == "right":
			player.global_position = Vector2(1202, 386.0)
			
	elif WorldState.spawn_source == "door" and WorldState.exit_spawn_x != 0.0:
		player.global_position.x = WorldState.exit_spawn_x
		player.global_position.y = 386.0

	if WorldState.saved_player_x != 0.0:
		player.global_position = Vector2(WorldState.saved_player_x, WorldState.saved_player_y)
		WorldState.saved_player_x = 0.0
		WorldState.saved_player_y = 0.0

	# (The first-encounter zombie now lives INSIDE 3003 per the GDD — see
	# room.gd _spawn_tutorial_zombie — not out here in the corridor. The
	# corridor's own scripted zombie is the barricade beat below.)

	# Same framing as every corridor floor (the tilemap is exactly the shared band,
	# 243..435 — the old blue filler rows above/below are gone).
	_frame_camera(player)

	_build_world()
	# Journal memory: floor 30 is where every run begins — reveal it on the map.
	WorldState.note_floor_arrival(self, 30)

	# EVERY run's cold open (not just the first): black screen, banging, the new character's
	# first line, then the visible lockout at 3001. Plays once per run (opener_seen is reset by
	# new_game + advance_run, and saved, so Continue never replays it).
	if WorldState.current_floor == 30 and not WorldState.opener_seen:
		WorldState.opener_seen = true
		var intro = preload("res://scripts/intro_overlay.gd").new()
		var cfg := opener_config()
		for k in ["title_text", "time_word", "time_color", "name_text", "sub_text", "line_text"]:
			intro.set(k, cfg[k])
		add_child(intro)


# What this run's cold open says — ONE shape for all three runs (the owner's "synergy"): the
# game's title on its own screen (run 1 only), then the time-of-day card (the big coloured word +
# who this is + a subtitle) over the bloody handprint, then the character's line; then the lockout
# lines, which on runs 2/3 nod to how the previous character's story ended. Lines:
# TutorialManager.LINES.
static func opener_config() -> Dictionary:
	var run: int = WorldState.current_run
	var i: int = clampi(run - 1, 0, WorldState.RUN_NAMES.size() - 1)
	var L: Dictionary = TutorialManager.LINES
	var cfg := {
		"title_text": "DESCEND FROM 30" if run <= 1 else "",
		"time_word": WorldState.RUN_NAMES[i].to_upper(),
		"time_color": Transition.TIME_WORD_COLORS[i],
		"name_text": WorldState.character_display_name(WorldState.current_character()),
		"sub_text": WorldState.TIME_SUBTITLES[i],
	}
	if run <= 1:
		cfg["line_text"] = L["opener_1"]
		cfg["lockout"] = [L["opener_4"], L["opener_5"] if WorldState.is_first_run else L["opener_5_free"]]
		return cfg
	cfg["line_text"] = L["run2_open"] if run == 2 else L["run3_open"]
	var lockout: Array = [L["run_lockout"]]
	match str(WorldState.chronicle_entry(run - 1).get("outcome", "")):
		"fell": lockout.append(L["run_after_fell"])
		"escaped": lockout.append(L["run_after_escaped"])
	cfg["lockout"] = lockout
	return cfg


func _build_world() -> void:
	# Everything that is part of the PLACE (not the arrival): the same whether the floor
	# loads fresh or is built as a pan backdrop, so nothing pops in when a pan commits.
	_spawn_corpses(30)
	_spawn_world_drops(30)
	# A character who fell here (floor 30) leaves a recoverable body for the next one.
	WorldState.spawn_player_corpse_into(self, 30, scene_file_path, "")
	# Real ceiling lamps, like every other floor — otherwise the top floor sits dark at
	# night beside a lit floor 29 and the pan between them shows the seam.
	if get_node_or_null("FloorLighting") == null:
		var lights = FLOOR_LIGHTING.new()
		lights.name = "FloorLighting"
		add_child(lights)
		lights.setup(30, ["left"])   # only the down stairwell — floor 30 is the top
	# Diegetic tutorial: blood-scrawled control hints are baked into the scene
	# (group "tutorial_blood") so they can be positioned/resized in the editor.
	# They only belong on the FIRST run — hide them otherwise.
	if not WorldState.is_first_run:
		for hint in get_tree().get_nodes_in_group("tutorial_blood"):
			if is_ancestor_of(hint):
				hint.visible = false


func _frame_camera(player: Node) -> void:
	PanBackdrop.frame_camera(self, player)


# Wake the passive backdrop into the live floor 30, in place (StairPan._adopt reparents the
# live player in first). No intro, no announce: you walked up here, you didn't load in.
func go_live() -> void:
	if not passive:
		return
	passive = false
	PanBackdrop.restore(_dormant)
	PanBackdrop.wake_scenery(self)
	WorldState.apply_time_tint(self, 30)
	WorldState.note_floor_arrival(self, 30)

func _process(_delta: float) -> void:
	if passive:
		return
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
	# not on black) steps up and bangs on their own door 3001, gets no answer, and
	# says this run's lockout lines (opener_config). knock_door provides the
	# up-to-the-door movement; the lines chain on any key / click.
	var player = get_tree().get_first_node_in_group("player")
	var door = get_node_or_null("3001")
	if player == null:
		return
	if door != null and player.has_method("knock_door"):
		player.knock_door(door.global_position, _opener_lockout_lines)
	else:
		_opener_lockout_lines()


var _lockout_queue: Array = []


func _opener_lockout_lines() -> void:
	_lockout_queue = opener_config()["lockout"].duplicate()
	_next_lockout_line()


func _next_lockout_line() -> void:
	if _lockout_queue.is_empty():
		return
	TutorialManager.prompt(str(_lockout_queue.pop_front()), "interact", _next_lockout_line, "[continue]")


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
		"interact", _on_barricade_hint, "[continue]")


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
			"interact", _on_force_break, "[continue]")


func _on_force_break() -> void:
	pass


func _release_hall_zombie() -> void:
	if hall_zombie != null and is_instance_valid(hall_zombie):
		hall_zombie.tutorial_shamble = true
		hall_zombie.tutorial_release()


func _spawn_hall_zombie() -> void:
	var zombie = preload("res://scenes/enemy_zombie_standard.tscn").instantiate()
	zombie.global_position = Vector2(HALL_ZOMBIE_SPAWN_X, 370.0)   # feet on 419 from frame 0 (standard rig)
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
	var scene_path = scene_file_path   # THIS scene — a pan backdrop is not the current scene yet
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
	var scene_path = scene_file_path   # THIS scene — a pan backdrop is not the current scene yet
	var drops = WorldState.get_world_drops_for_floor(floor_num, scene_path)
	if drops.is_empty():
		return
	var drop_scene = preload("res://scenes/world_drop.tscn")
	for drop_key in drops:
		var data = drops[drop_key]
		var drop = drop_scene.instantiate()
		drop.item_id = data["item_id"]
		drop.amount = int(data.get("amount", 0))
		drop.instance_data = data.get("instance", {})
		drop.drop_key = drop_key
		drop.target_apartment = data.get("target_apartment", "")
		drop.global_position = Vector2(data["x"], data["y"])
		add_child(drop)
