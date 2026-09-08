extends Node2D

# The END of a three-run arc (docs/THREE_RUN_ARC.md) — reached only once all three
# characters' stories have concluded (the last one died OR walked out the lobby).
# Mid-arc deaths/exits time-skip to the next character instead of coming here.

func _ready() -> void:
	HUD.hide_hud()
	_build_ui()

func _build_ui() -> void:
	# Did the final character make it out, or fall? That sets the headline.
	var outcomes: Array = WorldState.run_outcomes
	var final_survived := String(outcomes[outcomes.size() - 1]) == "survived"
	var any_survived := false
	for o in outcomes:
		if String(o) == "survived":
			any_survived = true

	var headline = Label.new()
	if final_survived:
		headline.text = "YOU MADE IT OUT"
		headline.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	elif any_survived:
		headline.text = "THE BUILDING TAKES ITS DUE"
		headline.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	else:
		headline.text = "YOU DIED"
		headline.add_theme_color_override("font_color", Color(0.82, 0.30, 0.30))
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_override("font", preload("res://assets/fonts/PixelOperator8-Bold.ttf"))
	headline.add_theme_font_size_override("font_size", 48)
	headline.set_anchor_and_offset(SIDE_LEFT, 0.5, -300)
	headline.set_anchor_and_offset(SIDE_RIGHT, 0.5, 300)
	headline.set_anchor_and_offset(SIDE_TOP, 0.5, -160)
	headline.set_anchor_and_offset(SIDE_BOTTOM, 0.5, -100)
	add_child(headline)

	# The three characters' fates, morning → afternoon → night.
	var fates = Label.new()
	var lines: Array = []
	for i in range(outcomes.size()):
		var name: String = WorldState.run_name(i + 1)
		var o := String(outcomes[i])
		var verb := "Escaped" if o == "survived" else ("Fell" if o == "dead" else "—")
		lines.append("%s:  %s" % [name, verb])
	fates.text = "\n".join(lines)
	fates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fates.add_theme_font_override("font", preload("res://assets/fonts/PixelOperator8.ttf"))
	fates.add_theme_font_size_override("font_size", 22)
	fates.add_theme_color_override("font_color", Color(0.82, 0.83, 0.88))
	fates.set_anchor_and_offset(SIDE_LEFT, 0.5, -300)
	fates.set_anchor_and_offset(SIDE_RIGHT, 0.5, 300)
	fates.set_anchor_and_offset(SIDE_TOP, 0.5, -70)
	fates.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 40)
	add_child(fates)

	var btn = Button.new()
	btn.text = "Return to Title"
	btn.set_anchor_and_offset(SIDE_LEFT, 0.5, -80)
	btn.set_anchor_and_offset(SIDE_RIGHT, 0.5, 80)
	btn.set_anchor_and_offset(SIDE_TOP, 0.5, 70)
	btn.set_anchor_and_offset(SIDE_BOTTOM, 0.5, 110)
	btn.pressed.connect(_on_title)
	add_child(btn)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
