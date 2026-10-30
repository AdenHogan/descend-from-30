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

# The text column. Everything on this screen sits in ONE centred column that is only SIDE_MARGIN narrower than the screen and
# WRAPS, so no line can run off an edge however the window is shaped (owner round 49d: on a full-screen fit-to-aspect window the
# fixed-size, non-wrapping labels grew rightward from their left edge — the run lines ran off the screen and the block sat off-centre).
const SIDE_MARGIN := 146.0
const HEAD_FONT := preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const BODY_FONT := preload("res://assets/fonts/PixelOperator8.ttf")


func _build_ui() -> void:
	# Did the final character make it out, or fall? That sets the headline.
	var outcomes: Array = WorldState.run_outcomes
	var final_survived := String(outcomes[outcomes.size() - 1]) == "survived"
	var any_survived := false
	for o in outcomes:
		if String(o) == "survived":
			any_survived = true

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(SIDE_MARGIN))
	margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	_ui.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var headline: Label
	if final_survived:
		headline = _line(column, "YOU MADE IT OUT", 48, Color(0.55, 0.85, 0.55), HEAD_FONT)
	elif any_survived:
		headline = _line(column, "THE BUILDING TAKES ITS DUE", 48, Color(0.85, 0.72, 0.45), HEAD_FONT)
	else:
		headline = _line(column, "YOU DIED", 48, Color(0.82, 0.30, 0.30), HEAD_FONT)
	headline.name = "Headline"
	_gap(column, 22)

	# The three characters' fates, morning → afternoon → night — and the Descent Valour each
	# run's depth earned (WorldState.finish_session scored it on the way here). Each run is a line of its own
	# (what happened) and, under it, a smaller dimmer one (what they did) — the tallies are what used to run off the screen.
	var scored: Array = WorldState.last_valour.get("runs", [])
	for i in range(outcomes.size()):
		var run_nm: String = WorldState.run_name(i + 1)
		var o := String(outcomes[i])
		var verb := "Escaped" if o == "survived" else ("Fell" if o == "dead" else "—")
		var line := "%s:  %s" % [run_nm, verb]
		var extra: Array = []
		if i < scored.size():
			var r: Dictionary = scored[i]
			var where := "the Lobby" if bool(r.get("escaped", false)) else "Floor %d" % int(r.get("deepest", 30))
			line = "%s:  %s  (%s)  +%d" % [run_nm, verb, where, int(r.get("valour", 0))]
			if int(r.get("kills", 0)) > 0:
				extra.append("%d felled" % int(r["kills"]))
			if int(r.get("nodes", 0)) > 0:
				extra.append("%d searched" % int(r["nodes"]))
			if int(r.get("flats", 0)) > 0:
				extra.append("%d flat%s" % [int(r["flats"]), "" if int(r["flats"]) == 1 else "s"])
			if int(r.get("quests", 0)) > 0:
				extra.append("%d quest%s" % [int(r["quests"]), "" if int(r["quests"]) == 1 else "s"])
			if int(r.get("npcs", 0)) > 0:
				extra.append("%d aided" % int(r["npcs"]))
		_line(column, line, 18, Color(0.82, 0.83, 0.88), BODY_FONT)
		if not extra.is_empty():
			_line(column, ", ".join(extra), 14, Color(0.58, 0.60, 0.66), BODY_FONT)
	if not scored.is_empty():
		_gap(column, 14)
		_line(column, "DESCENT VALOUR  +%d   (banked %d)" % [int(WorldState.last_valour.get("total", 0)), WorldState.valour], 18, Color(0.82, 0.83, 0.88), BODY_FONT)
	if not WorldState.carry_items.is_empty():
		var names: Array = []
		for d in WorldState.carry_items:
			names.append(WorldState._handoff_label(WorldState.instance_from_dict(d)))
		_gap(column, 6)
		_line(column, "The shopkeeper keeps for your next game: %s" % ", ".join(names), 14, Color(0.58, 0.60, 0.66), BODY_FONT)
	_gap(column, 34)

	var btn = _button(column, "Return to Title")
	btn.name = "TitleButton"
	btn.pressed.connect(_on_title)

	# The LEGACY panel: the offer (perks found this session, bought with Valour), and later the
	# collection. Opens by itself once the headline has had a beat to land.
	var leg = _button(column, "Legacy")
	leg.name = "LegacyButton"
	leg.pressed.connect(func(): open_legacy())
	if not WorldState.valour_offer.is_empty():
		var t := Timer.new()                    # a child, so it dies with the screen
		t.one_shot = true
		t.wait_time = 1.6
		t.process_mode = Node.PROCESS_MODE_ALWAYS
		t.timeout.connect(open_legacy)
		add_child(t)
		t.start()


var legacy_ui = null


## One wrapped, centred line of text in the column.
func _line(parent: Control, text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _gap(parent: Control, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


func open_legacy(which: String = "") -> void:
	if legacy_ui == null or not is_instance_valid(legacy_ui):
		legacy_ui = preload("res://scripts/legacy_ui.gd").new()
		add_child(legacy_ui)
	if not legacy_ui.visible:
		legacy_ui.open(which)

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
