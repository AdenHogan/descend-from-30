extends Node2D

# TITLE SCREEN — Play / Settings / Exit.
#
# There is deliberately no New Game or Continue here any more: the profile
# screen owns that choice. An empty slot IS a new game (and runs the Floor 30
# tutorial), a slot with a save IS a continue — so offering both on the title
# just asked the same question twice, and "Continue" had to be greyed out when
# no slot had a run.
#
# Layout lives in scenes/title_screen.tscn; this script only wires presses.
# Node contract: Menu/Root/Buttons/{Play,Settings,Exit}Button.

var settings_menu: CanvasLayer = null


func _ready() -> void:
	HUD.hide_hud()

	# Same rebinding menu the pause screen uses — it's a self-contained
	# CanvasLayer, so it drops in here unchanged.
	settings_menu = preload("res://scripts/settings_menu.gd").new()
	add_child(settings_menu)
	# It draws on layer 3, over the menu. Hide the menu outright while it's up
	# so a stray Enter can't press a button the player can no longer see.
	settings_menu.visibility_changed.connect(_on_settings_visibility_changed)

	_connect("Menu/Root/Buttons/PlayButton", _on_play)
	_connect("Menu/Root/Buttons/SettingsButton", _on_settings)
	_connect("Menu/Root/Buttons/ExitButton", _on_exit)

	var play := get_node_or_null("Menu/Root/Buttons/PlayButton")
	if play != null:
		play.grab_focus()


func _connect(path: String, fn: Callable) -> void:
	var n := get_node_or_null(path)
	if n != null:
		n.pressed.connect(fn)


func _on_settings_visibility_changed() -> void:
	var menu := get_node_or_null("Menu")
	if menu != null:
		menu.visible = not settings_menu.visible
	if not settings_menu.visible:
		var play := get_node_or_null("Menu/Root/Buttons/PlayButton")
		if play != null:
			play.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Esc backs out of Settings; on the title itself it does nothing (quitting
	# is an explicit choice, not a stray keypress).
	if event.is_action_pressed("ui_cancel") and settings_menu != null and settings_menu.visible:
		settings_menu.close()
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	# Which profile you pick decides new-vs-resume, and whether the tutorial runs.
	get_tree().change_scene_to_file("res://scenes/profile_select.tscn")


func _on_settings() -> void:
	settings_menu.open()


func _on_exit() -> void:
	get_tree().quit()
