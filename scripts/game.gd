extends Node

const SCENES = {
	"title": "res://scenes/title_screen.tscn",
	"hallway": "res://scenes/hallway.tscn",
	"room": "res://scenes/room.tscn",
	"lobby": "res://scenes/lobby.tscn",
	"building_floors": "res://scenes/building_floors.tscn"
}

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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			var pause_menu = get_tree().get_root().find_child("PauseMenu", true, false)
			if pause_menu and HUD.visible:
				if pause_menu.visible:
					pause_menu.toggle(false)
				else:
					pause_menu.toggle(true)
