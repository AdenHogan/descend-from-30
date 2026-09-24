extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"profiles": "res://scenes/profile_select.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"maintenance": "res://scenes/maintenance.tscn",
	"elevator_interior": "res://scenes/elevator_interior.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"building_floors": "res://scenes/building_floors.tscn"
}

var music_player: AudioStreamPlayer = null

# A dedicated bus for enemy SFX (zombie moans). The stair ascent fades THIS bus
# out as the player climbs away, so the floor's zombies recede without touching
# the music. Everything else stays on Master.
const ENEMY_BUS := "Enemies"


func _ready() -> void:
	# Must keep handling input while the tree is paused, so Esc can un-pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_enemy_bus()
	# Background dread loop (assets/audio/music) — lives on this autoload so
	# it survives scene changes and keeps droning through the pause menu.
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	var stream = preload("res://assets/audio/music/dread_loop.ogg")
	stream.loop = true
	music_player.stream = stream
	music_player.volume_db = -16.0
	add_child(music_player)
	music_player.play()


func _ensure_enemy_bus() -> void:
	# There's no bus layout resource, so create the enemy bus at runtime and
	# route it to Master. Idempotent — safe if it already exists.
	if AudioServer.get_bus_index(ENEMY_BUS) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, ENEMY_BUS)
	AudioServer.set_bus_send(idx, "Master")


func _input(event: InputEvent) -> void:
	# PauseMenu is an autoload now (not embedded in every scene), so it no
	# longer blankets the editor viewport and each world scene stays editable.
	if event.is_action_pressed("ui_cancel") and HUD.visible:
		# The character journal is a pausing overlay of its own: ESC closes IT first. This handler
		# runs before the journal's own input, so without this ESC opened the pause menu ON TOP of
		# the journal — and Resume then unpaused the live game behind a still-open journal.
		# Any open modal panel (the workbench, …) closes first, same as the journal below.
		for m in get_tree().get_nodes_in_group("modal_panel"):
			if m.visible and m.has_method("close"):
				m.close()
				get_viewport().set_input_as_handled()
				return
		var journal = HUD.get("character_panel")
		if journal != null and is_instance_valid(journal) and journal.visible:
			journal.close()
			get_viewport().set_input_as_handled()
			return
		PauseMenu.handle_cancel()
		get_viewport().set_input_as_handled()

func go_to_scene(scene_name: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_name])

func new_game() -> void:
	# Fade the menu out to black first, THEN start: the run opens on its own black cold open
	# (intro_overlay), so the reveal below is invisible — it just hands black to black instead
	# of the menu hard-cutting away. (The cold open waits while Transition is busy.)
	await Transition.cover(0.45)
	WorldState.new_game()
	HUD.show_hud()
	go_to_scene("hallway")
	await get_tree().process_frame
	await get_tree().process_frame
	await Transition.reveal(0.2)

func continue_game() -> void:
	var scene_path = WorldState.load_game()
	if scene_path == "":
		return
	get_tree().paused = false
	HUD.show_hud()
	get_tree().change_scene_to_file(scene_path)

func save_and_quit(go_to_desktop: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		WorldState.saved_player_x = player.global_position.x
		WorldState.saved_player_y = player.global_position.y
		# Remember if we were out on a balcony plane, so the load can re-establish
		# it (the saved Y alone can't — see player.restore_balcony_plane).
		WorldState.saved_on_balcony_plane = bool(player.get("on_balcony_plane"))
	var scene_path = get_tree().current_scene.scene_file_path
	WorldState.save_game(scene_path)
	get_tree().paused = false
	HUD.hide_hud()
	if go_to_desktop:
		get_tree().quit()
	else:
		go_to_scene("title")

func quit_without_saving() -> void:
	# Returns to title WITHOUT touching the save file — the player keeps whatever
	# they last saved. (Permadeath on death is handled separately in game_over.)
	HUD.hide_hud()
	go_to_scene("title")

func game_over() -> void:
	# A character of the arc has died. Per docs/THREE_RUN_ARC.md a death is NOT the
	# end of the session — it triggers the SAME time skip an exit does, and the next
	# character takes over. Only when the THIRD character falls is the playthrough
	# truly over (a dead character leaves a recoverable corpse — store step 7, future).
	WorldState.set_run_outcome(WorldState.current_run, "dead")
	# Record the fallen character's body so the NEXT character can recover its notes + items
	# (STORE_DESIGN step 7). Only when there IS a next character — the 3rd death ends the arc,
	# with no one to recover into. Captured now, while the player node + this run's
	# inventory/wallet still exist (advance_run wipes them below).
	if WorldState.current_run < WorldState.RUN_NAMES.size():
		var dead = get_tree().get_first_node_in_group("player")
		if dead != null:
			var scene_path: String = get_tree().current_scene.scene_file_path
			var apt: String = WorldState.current_apartment_id if scene_path == SCENES["room"] else ""
			# FEET, not origin — the body must lie on the floor line, not float above it.
			var feet: Vector2 = dead.feet_position() if dead.has_method("feet_position") \
				else dead.global_position + Vector2(0, WorldState.PLAYER_FEET_OFFSET)
			WorldState.record_player_corpse(WorldState.current_floor, scene_path, apt, feet)
	get_tree().paused = false
	# THE END CARD: fade to black on "YOU DIED — <name> fell on Floor N." (the bookend to the
	# cold open every run starts with). It leaves the screen BLACK, so advance_run()'s world
	# mutation (new barricades/props/door states) never pops in over the death scene.
	var here: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	var who: String = WorldState.character_display_name(WorldState.current_character())
	if not await Transition.end_card(TutorialManager.LINES["end_died"],
			"%s fell %s." % [who, WorldState.place_in_words(here)], Transition.END_DIED_COLOR):
		await Transition.cover()
	var arc_over: bool = WorldState.advance_run()
	if arc_over:
		# The final character has fallen — the playthrough ends. Reveal onto the game-over card.
		WorldState.finish_session()      # score the session → Descent Valour + the perk offer
		WorldState.delete_save()
		HUD.hide_hud()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
		await get_tree().process_frame
		await get_tree().process_frame
		await Transition.reveal()
		return
	# The next character wakes at Floor 30 after the skip. Persist the fresh run
	# WITHOUT recording the dead scene's zombies, then time-skip into the hallway.
	WorldState.save_game("res://scenes/hallway.tscn", false)
	Transition.to_run_start("res://scenes/hallway.tscn")   # → the cold open's time card
