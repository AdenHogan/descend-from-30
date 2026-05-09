extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"lobby": "res://scenes/lobby.tscn"
}

func go_to_scene(scene_name: String) -> void:
	get_tree().change_scene_to_file(SCENES[scene_name])

func new_game() -> void:
	WorldState.new_game()
	go_to_scene("hallway")
	
	HUD.show_hud()
