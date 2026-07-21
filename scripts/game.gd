extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"building_floors": "res://scenes/building_floors.tscn"
}

var music_player: AudioStreamPlayer = null


func _ready() -> void:
	# Must keep handling input while the tree is paused, so Esc can un-pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _input(event: InputEvent) -> void:
	# PauseMenu is an autoload now (not embedded in every scene), so it no
	# longer blankets the editor viewport and each world scene stays editable.
	if event.is_action_pressed("ui_cancel") and HUD.visible:
		PauseMenu.toggle(not PauseMenu.visible)
		get_viewport().set_input_as_handled()

func go_to_scene(scene_name: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENES[scene_name])

func new_game() -> void:
	WorldState.new_game()
	HUD.show_hud()
	go_to_scene("hallway")

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
	get_tree().paused = false
	WorldState.delete_save()
	HUD.hide_hud()
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
