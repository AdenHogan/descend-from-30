extends CanvasLayer

@onready var save_quit_submenu = $Control/SaveQuitSubmenu

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	save_quit_submenu.visible = false
	$Control/PanelContainer/VBoxContainer/Resume.pressed.connect(_on_resume)
	$Control/PanelContainer/VBoxContainer/"Save and Quit".pressed.connect(_on_save_quit)
	$Control/PanelContainer/VBoxContainer/"Quit Without Saving".pressed.connect(_on_quit_without_saving)
	$Control/SaveQuitSubmenu/VBoxContainer/"Return to Title".pressed.connect(_on_save_to_title)
	$Control/SaveQuitSubmenu/VBoxContainer/"Exit to Desktop".pressed.connect(_on_save_to_desktop)
	$Control/SaveQuitSubmenu/VBoxContainer/Cancel.pressed.connect(_on_submenu_cancel)

func toggle(should_show: bool) -> void:
	visible = should_show
	save_quit_submenu.visible = false
	# Freeze the entire SceneTree. Every node inherits PROCESS_MODE_INHERIT by
	# default and halts; only this menu (PROCESS_MODE_ALWAYS, set in _ready) keeps
	# running so its buttons stay live. This replaces the old approach of manually
	# disabling the player and zombie group, which left timers, the loot UI, world
	# drops and HUD feedback all running during the pause.
	get_tree().paused = should_show

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
