extends CanvasLayer

@onready var save_quit_submenu = $Control/SaveQuitSubmenu
var settings_menu: CanvasLayer = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_quit_submenu.visible = false
	$Control/PanelContainer/VBoxContainer/Resume.pressed.connect(_on_resume)
	_add_settings_button()
	$Control/PanelContainer/VBoxContainer/"Save and Quit".pressed.connect(_on_save_quit)
	$Control/PanelContainer/VBoxContainer/"Quit Without Saving".pressed.connect(_on_quit_without_saving)

func _add_settings_button() -> void:
	settings_menu = preload("res://scripts/settings_menu.gd").new()
	add_child(settings_menu)
	var btn = Button.new()
	btn.text = "Settings"
	btn.pressed.connect(func(): settings_menu.open())
	# Sit the Settings button just under Resume.
	var vbox = $Control/PanelContainer/VBoxContainer
	vbox.add_child(btn)
	vbox.move_child(btn, $Control/PanelContainer/VBoxContainer/Resume.get_index() + 1)
	$Control/SaveQuitSubmenu/VBoxContainer/"Return to Title".pressed.connect(_on_save_to_title)
	$Control/SaveQuitSubmenu/VBoxContainer/"Exit to Desktop".pressed.connect(_on_save_to_desktop)
	$Control/SaveQuitSubmenu/VBoxContainer/Cancel.pressed.connect(_on_submenu_cancel)

func toggle(should_show: bool) -> void:
	visible = should_show
	save_quit_submenu.visible = false
	# The settings menu is a separate CanvasLayer — hiding the pause menu
	# doesn't cascade to it, so close it explicitly or it floats over live
	# gameplay after Resume/Esc.
	if settings_menu != null:
		settings_menu.close()
	# Freeze the entire SceneTree. Every node inherits PROCESS_MODE_INHERIT by
	# default and halts; only this menu (PROCESS_MODE_ALWAYS, set in _ready) keeps
	# running so its buttons stay live. This replaces the old approach of manually
	# disabling the player and zombie group, which left timers, the loot UI, world
	# drops and HUD feedback all running during the pause.
	get_tree().paused = should_show

func handle_cancel() -> void:
	# Esc hierarchy: from Settings, go BACK to the pause menu (stay paused);
	# from the pause menu, resume; from gameplay, open the pause menu.
	if settings_menu != null and settings_menu.visible:
		settings_menu.close()
		return
	toggle(not visible)


func _on_resume() -> void:
	toggle(false)

func _on_save_quit() -> void:
	save_quit_submenu.visible = true

func _on_save_to_title() -> void:
	toggle(false)
	Game.save_and_quit(false)

func _on_save_to_desktop() -> void:
	toggle(false)
	Game.save_and_quit(true)

func _on_submenu_cancel() -> void:
	save_quit_submenu.visible = false

func _on_quit_without_saving() -> void:
	toggle(false)
	Game.quit_without_saving()
