extends Node2D

func _ready() -> void:
	HUD.hide_hud()
	pass
	

func _on_new_game_button_pressed() -> void:
	Game.new_game()
