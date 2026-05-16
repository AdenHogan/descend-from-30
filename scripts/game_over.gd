extends Node2D

func _ready() -> void:
	HUD.hide_hud()
	_build_ui()

func _build_ui() -> void:
	var label = Label.new()
	label.text = "YOU DIED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchor_and_offset(SIDE_LEFT, 0.5, -200)
	label.set_anchor_and_offset(SIDE_RIGHT, 0.5, 200)
	label.set_anchor_and_offset(SIDE_TOP, 0.5, -80)
	label.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -20)
	add_child(label)

	var btn = Button.new()
	btn.text = "Return to Title"
	btn.set_anchor_and_offset(SIDE_LEFT, 0.5, -80)
	btn.set_anchor_and_offset(SIDE_RIGHT, 0.5, 80)
	btn.set_anchor_and_offset(SIDE_TOP, 0.5, 20)
	btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 60)
	btn.pressed.connect(_on_title)
	add_child(btn)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
