extends Node2D

# The END of a three-run arc (docs/THREE_RUN_ARC.md) — reached only once all three
# characters' stories have concluded (the last one died OR walked out the lobby).
# Mid-arc deaths/exits time-skip to the next character instead of coming here.

var _ui: Control = null


func _ready() -> void:
	HUD.hide_hud()
	# Anchored Controls need a full-screen Control parent — directly under this Node2D their
	# anchors resolved against nothing and everything piled into the top-left corner.
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
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
	_centre(headline, -300, 300, -160, -100)
	_ui.add_child(headline)

	# The three characters' fates, morning → afternoon → night — and the Descent Valour each
	# run's depth earned (WorldState.finish_session scored it on the way here).
	var fates = Label.new()
	var lines: Array = []
	var scored: Array = WorldState.last_valour.get("runs", [])
	for i in range(outcomes.size()):
		var run_nm: String = WorldState.run_name(i + 1)
		var o := String(outcomes[i])
		var verb := "Escaped" if o == "survived" else ("Fell" if o == "dead" else "—")
		var line := "%s:  %s" % [run_nm, verb]
		if i < scored.size():
			var r: Dictionary = scored[i]
			var where := "the Lobby" if bool(r.get("escaped", false)) else "Floor %d" % int(r.get("deepest", 30))
			line = "%s:  %s  (%s)  +%d" % [run_nm, verb, where, int(r.get("valour", 0))]
			var extra: Array = []
			if int(r.get("quests", 0)) > 0:
				extra.append("%d quest%s" % [int(r["quests"]), "" if int(r["quests"]) == 1 else "s"])
			if int(r.get("npcs", 0)) > 0:
				extra.append("%d aided" % int(r["npcs"]))
			if not extra.is_empty():
				line += "  [%s]" % ", ".join(extra)
		lines.append(line)
	if not scored.is_empty():
		lines.append("")
		lines.append("DESCENT VALOUR  +%d   (banked %d)" % [int(WorldState.last_valour.get("total", 0)), WorldState.valour])
	if not WorldState.carry_items.is_empty():
		var names: Array = []
		for d in WorldState.carry_items:
			names.append(WorldState._handoff_label(WorldState.instance_from_dict(d)))
		lines.append("The shopkeeper keeps for your next game: %s" % ", ".join(names))
	fates.text = "\n".join(lines)
	fates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fates.add_theme_font_override("font", preload("res://assets/fonts/PixelOperator8.ttf"))
	fates.add_theme_font_size_override("font_size", 18)
	fates.add_theme_color_override("font_color", Color(0.82, 0.83, 0.88))
	_centre(fates, -300, 300, -70, 80)
	_ui.add_child(fates)

	var btn = Button.new()
	btn.text = "Return to Title"
	_centre(btn, -80, 80, 110, 150)
	btn.pressed.connect(_on_title)
	_ui.add_child(btn)

	# The LEGACY panel: the offer (perks found this session, bought with Valour), and later the
	# collection. Opens by itself once the headline has had a beat to land.
	var leg = Button.new()
	leg.name = "LegacyButton"
	leg.text = "Legacy"
	_centre(leg, -80, 80, 160, 196)
	leg.pressed.connect(func(): open_legacy())
	_ui.add_child(leg)
	if not WorldState.valour_offer.is_empty():
		var t := Timer.new()                    # a child, so it dies with the screen
		t.one_shot = true
		t.wait_time = 1.6
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		t.timeout.connect(open_legacy)
		add_child(t)
		t.start()


var legacy_ui = null


# Place a control by offsets from the screen centre. (The old per-side set_anchor_and_offset calls
# clamped each LEFT/TOP anchor back to 0 while its opposite was still 0 — everything drifted left.)
func _centre(c: Control, l: float, r: float, t: float, b: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = l
	c.offset_right = r
	c.offset_top = t
	c.offset_bottom = b


func open_legacy(which: String = "") -> void:
	if legacy_ui == null or not is_instance_valid(legacy_ui):
		legacy_ui = preload("res://scripts/legacy_ui.gd").new()
		add_child(legacy_ui)
	if not legacy_ui.visible:
		legacy_ui.open(which)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
