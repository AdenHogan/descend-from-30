extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"building_floors": "res://scenes/building_floors.tscn"
}

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and HUD.visible:
		var pause_menu = get_tree().get_root().find_child("PauseMenu", true, false)
		if pause_menu:
			pause_menu.toggle(not pause_menu.visible)
			get_viewport().set_input_as_handled()

func go_to_scene(scene_name: String) -> void:
	get_tree().change_scene_to_file(SCENES[scene_name])

func new_game() -> void:
	WorldState.new_game()
	HUD.show_hud()
	go_to_scene("hallway")

func continue_game() -> void:
	var scene_path = WorldState.load_game()
	if scene_path == "":
		return
	HUD.show_hud()
	get_tree().change_scene_to_file(scene_path)

func save_and_quit(go_to_desktop: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		WorldState.saved_player_x = player.global_position.x
		WorldState.saved_player_y = player.global_position.y
	var scene_path = get_tree().current_scene.scene_file_path
	WorldState.save_game(scene_path)
	HUD.hide_hud()
	if go_to_desktop:
		get_tree().quit()
	else:
		go_to_scene("title")

func quit_without_saving() -> void:
	WorldState.delete_save()
	HUD.hide_hud()
	go_to_scene("title")

func game_over() -> void:
	WorldState.delete_save()
	HUD.hide_hud()
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
