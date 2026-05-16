extends Node2D

func _ready() -> void:
	HUD.hide_hud()
	var continue_btn = get_node_or_null("ContinueButton")
	if continue_btn:
		continue_btn.disabled = not WorldState.save_exists()

func _on_new_game_button_pressed() -> void:
	Game.new_game()

func _on_continue_button_pressed() -> void:
	if WorldState.save_exists():
		Game.continue_game()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
