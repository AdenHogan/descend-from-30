extends Node2D

func _ready() -> void:
	HUD.hide_hud()
	# Continue is enabled if ANY profile has a run in progress — the slot itself
	# is chosen on the profile screen, not here.
	var continue_btn = get_node_or_null("ContinueButton")
	if continue_btn:
		continue_btn.disabled = not _any_slot_has_save()


func _any_slot_has_save() -> bool:
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		if WorldState.slot_summary(slot)["has_save"]:
			return true
	return false


func _on_new_game_button_pressed() -> void:
	_open_profiles()

func _on_continue_button_pressed() -> void:
	_open_profiles()


func _open_profiles() -> void:
	# BOTH entry points land here: which profile you pick decides whether this
	# is a new game or a resume, and whether the tutorial runs.
	get_tree().change_scene_to_file("res://scenes/profile_select.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
