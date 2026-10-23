extends Node

# The title screen is Play / Settings / Exit — new-vs-continue is the profile
# screen's job. Guards the node contract title_screen.gd wires to, and that the
# old duplicate entry points are really gone.
# Run:  godot --headless res://tests/title_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1

func _ready() -> void:
	print("=== title screen ===")
	var s = load("res://scenes/title_screen.tscn").instantiate()
	chk(s != null, "title_screen.tscn loads")

	var expected := {"PlayButton": "Play", "SettingsButton": "Settings", "ExitButton": "Exit"}
	for nm in expected:
		var btn = s.get_node_or_null("Menu/Root/Buttons/%s" % nm)
		chk(btn != null, "Menu/Root/Buttons/%s exists" % nm)
		if btn != null:
			chk(btn is Button, "%s is a real Button (not a Label + hitbox)" % nm)
			chk(btn.text == expected[nm],
				"%s reads '%s' (got '%s')" % [nm, expected[nm], btn.text])
			chk(not btn.disabled, "%s starts enabled" % nm)

	# New Game / Continue moved to the profile screen — nothing may still offer
	# them here, or the player is asked the same question twice.
	var stale := []
	var stack: Array[Node] = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var txt := ""
		if n is Button or n is Label:
			txt = String(n.text).to_lower()
		if txt.contains("new game") or txt.contains("continue"):
			stale.append(n.name)
		for c in n.get_children():
			stack.append(c)
	chk(stale.is_empty(), "no New Game / Continue left on the title %s" % str(stale))

	# The three buttons are the ONLY pressables — the old scene had invisible
	# Button rectangles floating over Labels, which drifted out of alignment.
	var buttons := []
	stack = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			buttons.append(n.name)
		for c in n.get_children():
			stack.append(c)
	chk(buttons.size() == 3, "exactly 3 buttons on the title (%s)" % str(buttons))

	# Every button carries its own text, so there is one source of truth for
	# where an entry sits.
	var blank := []
	for b in buttons:
		var node = s.find_child(b, true, false)
		if node != null and String(node.text).strip_edges() == "":
			blank.append(b)
	chk(blank.is_empty(), "no textless hitbox buttons %s" % str(blank))

	# The title carries the in-house logo (docs/logo/README.md), not a Label: a transparent PNG in the LEFT column (owner round 48g: "logo,
	# play, settings, exit on the left side, cleanly"), wholly on screen, over the menu's shade and clear of the three buttons below it.
	var logo = s.get_node_or_null("Menu/Logo")
	chk(logo is Sprite2D, "the title has a Logo sprite in the menu layer (it hides with the menu)")
	if logo is Sprite2D:
		chk(logo.texture != null and logo.texture.resource_path == "res://assets/logo/logo_full_dark.png",
			"the Logo is assets/logo/logo_full_dark.png (got '%s')" % (logo.texture.resource_path if logo.texture != null else "none"))
		var half: Vector2 = logo.texture.get_size() * logo.scale * 0.5
		var rect := Rect2(logo.position - half, half * 2.0)
		var shown := Rect2(Vector2.ZERO, Vector2(1152, 648))
		chk(shown.encloses(rect), "the Logo sits wholly on screen (rect %s)" % str(rect))
		chk(rect.end.x < 576.0, "the Logo is in the left half (ends at x %.0f)" % rect.end.x)
		var bx = s.get_node("Menu/Root/Buttons")
		var menu_rect := Rect2(Vector2(bx.offset_left, bx.offset_top), Vector2(bx.offset_right - bx.offset_left, bx.offset_bottom - bx.offset_top))
		chk(menu_rect.end.x < 576.0 and menu_rect.position.x < rect.position.x + 60.0, "the menu is the same left column (%s)" % str(menu_rect))
		chk(not rect.intersects(menu_rect), "the Logo %s keeps clear of the menu %s" % [str(rect), str(menu_rect)])
		chk(logo.get_index() > s.get_node("Menu/Root").get_index(), "the Logo draws OVER the left shade (it would be dimmed under it)")
		chk(logo.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"the Logo is drawn linear + mipmapped (a 2400 px image shrunk to ~400 px)")
	for b in ["PlayButton", "SettingsButton", "ExitButton"]:
		chk(int(s.get_node("Menu/Root/Buttons/" + b).alignment) == HORIZONTAL_ALIGNMENT_LEFT, "%s is left-aligned" % b)
	var old_title := []
	stack = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and String(n.text).to_lower().contains("descend"):
			old_title.append(n.name)
		for c in n.get_children():
			stack.append(c)
	chk(old_title.is_empty(), "no placeholder title Label left %s" % str(old_title))
	chk(s.get_node_or_null("DescendFrom30PlaceholderTitleScreen") == null, "the painted placeholder is gone")
	chk(s.get_node_or_null("Backdrop") == null, "no exterior backdrop either — the opening already shows the outside")
	chk(s.get_node_or_null("Fallback/Dark") is ColorRect, "a plain dark Fallback sits under the hall (a title must always come up)")
	chk(s.get_node_or_null("Hall") != null and s.get_node_or_null("Profiles") is CanvasLayer, "the title hosts the Hall and the Profiles layer")
	chk(s.get_node_or_null("Menu/Root/LeftShade") is ColorRect, "a shade column keeps the left readable")

	await _test_hall(s)

	# Settings is the same rebinding menu the pause screen uses.
	var sm = preload("res://scripts/settings_menu.gd").new()
	chk(sm.has_method("open") and sm.has_method("close"),
		"settings_menu exposes open()/close() for the title to drive")
	sm.free()

	s.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


# THE LIVE HALL (owner round 48g): built from the game's own pieces, in the dark, alive, and it never touches the player's state.
func _test_hall(s: Node) -> void:
	var Hall = preload("res://scripts/title_hall.gd")
	# pure functions of the clock
	var hall_script: Script = Hall
	var methods: Array = []
	for m in hall_script.get_script_method_list():
		methods.append(String(m["name"]))
	chk(methods.has("fade_alpha") and not methods.has("camera_x") and not hall_script.get_script_constant_map().has("CAM_SWAY"),
		"there is no camera drift any more (owner round 48h: a slow whole-pixel pan judders) — the script still lists its other statics (%s)" % str(methods.has("fade_alpha")))
	chk(is_equal_approx(Hall.fade_alpha(0.0), 1.0) and is_equal_approx(Hall.fade_alpha(Hall.FADE_IN), 0.0) and is_equal_approx(Hall.fade_alpha(99.0), 0.0),
		"it lifts from black once and stays up")

	# built in the tree: the real pieces are there
	var keep_seed: int = WorldState.master_seed
	var keep_run: int = WorldState.current_run
	WorldState.master_seed = 777001
	WorldState.current_run = 2
	var host := Node.new()
	add_child(host)
	host.add_child(s)
	var hall = s.get_node("Hall")
	chk(hall.build_ok, "the hall builds")
	chk(WorldState.master_seed == 777001 and WorldState.current_run == 2,
		"…and puts the player's seed + run back (%d / %d)" % [WorldState.master_seed, WorldState.current_run])
	if not hall.build_ok:
		host.remove_child(s)
		host.free()
		return
	chk(hall.get_node_or_null("CorridorArt") is Sprite2D and hall.get_node_or_null("CorridorDecals") != null, "the corridor's own art and dressing are in")
	chk(hall.get_node_or_null("WorldGrade") is CanvasModulate and hall.get_node("WorldGrade").color.v < 0.3, "the world is dark (a CanvasModulate near black)")
	chk(hall.lights != null and hall.lights._lamps.size() >= 2, "working sconces light it (%d lamps)" % hall.lights._lamps.size())
	var kinds := {}
	for e in hall.lights._lamps:
		kinds[e["mode"]] = true
	chk(kinds.has("blink") and kinds.has("flicker"), "some of them blink and some flicker (%s)" % str(kinds.keys()))
	chk(hall.dead.size() == 3, "three of the dead are in it")
	chk(hall.camera is Camera2D and hall.camera.is_current() and is_equal_approx(hall.camera.zoom.x, 648.0 / 192.0), "its camera is the game's own corridor framing")
	var blood := 0
	for n in hall.get_node("CorridorDecals").get_children():
		if n.has_meta("decal"):
			blood += 1
	chk(blood >= 6, "the walls and floor are dressed (%d decals)" % blood)
	var doors := 0
	for n in hall.get_children():
		if String(n.name).begins_with("Door") and n.get_node_or_null("Plate") != null:
			doors += 1
	chk(doors == 5, "five numbered doors line it (%d)" % doors)

	# alive: the dead walk (and stay on their stretch), the lamps cut out and come back, the camera STAYS PUT, the fade lifts
	chk(hall.camera != null and hall.camera.position == Vector2(Hall.CAM_X, Hall.CAM_Y), "the camera stands at its fixed place from the first frame (%s)" % str(hall.camera.position if hall.camera != null else "none"))
	var moved := false
	var start_x: Array = []
	for z in hall.dead:
		start_x.append(z.position.x)
	var walked: Dictionary = {}
	var states_seen: Dictionary = {}
	for i in 4000:                                       # 400 s of game time
		hall._process(0.1)
		for k in range(hall.dead.size()):
			var z = hall.dead[k]
			states_seen[z.state] = true
			if absf(z.position.x - float(start_x[k])) > 30.0:
				walked[k] = true
	var on_stretch := true
	for z in hall.dead:
		on_stretch = on_stretch and z.position.x >= z.lo - 1.0 and z.position.x <= z.hi + 1.0
	chk(walked.size() >= 2, "the dead shamble about (%d of 3 went more than 30 px)" % walked.size())
	chk(states_seen.has("walk") and states_seen.has("idle") and states_seen.has("lunge"), "they walk, stand and lunge (%s)" % str(states_seen.keys()))
	chk(on_stretch, "each keeps to its own stretch of corridor")
	chk(hall.blackouts >= 8, "the lights cut out now and then (%d blackouts in 400 s)" % hall.blackouts)
	chk(hall.fade.color.a < 0.01, "and the hall has faded up from black")
	chk(hall.camera.position == Vector2(Hall.CAM_X, Hall.CAM_Y), "…and 400 s later the camera has not moved an inch (%s)" % str(hall.camera.position))

	# a blackout really cuts every working lamp, and the power comes back
	hall._blackout_steps = []
	hall.lights.set_power(false)
	var all_dark := true
	for e in hall.lights._lamps:
		all_dark = all_dark and not e["light"].visible and not e["glow"].visible
	hall.lights.set_power(true)
	var all_lit := true
	for e in hall.lights._lamps:
		all_lit = all_lit and e["light"].visible and e["glow"].visible
	chk(all_dark and all_lit, "set_power(false) darkens every working lamp and set_power(true) lights them again")

	# the same hall every launch: another build (another player seed) gives the same lamps and the same dressing
	var second = Hall.new()
	WorldState.master_seed = 123456
	host.add_child(second)
	chk(second.build_ok and second.lights._lamps.size() == hall.lights._lamps.size(), "a second build has the same lamps")
	var names_a: Array = []
	var names_b: Array = []
	for n in hall.get_node("CorridorDecals").get_children():
		if n.has_meta("decal"):
			names_a.append(str(n.get_meta("decal")) + str(n.position))
	for n in second.get_node("CorridorDecals").get_children():
		if n.has_meta("decal"):
			names_b.append(str(n.get_meta("decal")) + str(n.position))
	chk(names_a == names_b and not names_a.is_empty(), "…and the same dressing, whatever the player's seed was (%d decals)" % names_a.size())
	second.queue_free()
	WorldState.master_seed = keep_seed
	WorldState.current_run = keep_run

	await _test_profiles(s)
	host.remove_child(s)
	host.free()


# PLAY lays the profile screen over the hall (owner round 48g: "so no longer a black screen behind profiles").
func _test_profiles(s: Node) -> void:
	var hall = s.get_node("Hall")
	var menu = s.get_node("Menu")
	chk(menu.visible and s.profiles == null, "the menu is up and there is no profile screen yet")
	s.get_node("Menu/Root/Buttons/PlayButton").pressed.emit()
	chk(s.profiles != null and is_instance_valid(s.profiles), "PLAY opens the profile screen")
	if s.profiles == null:
		return
	chk(s.profiles.get_parent() == s.get_node("Profiles"), "…on the title's own Profiles layer (the scene does not change)")
	chk(s.profiles.embedded, "…embedded")
	chk(not menu.visible, "the menu + logo step aside")
	chk(is_instance_valid(hall) and hall.is_inside_tree(), "the same live hall is still there under it")
	var veil = s.profiles.get_node("Background")
	chk(veil.color.a < 0.9 and veil.color.a > 0.2, "the opaque black backdrop is a see-through veil now (alpha %.2f)" % veil.color.a)
	var slots := 0
	for n in range(1, WorldState.SLOT_COUNT + 1):
		if s.profiles.get_node_or_null("Slot%d/SelectButton" % n) != null:
			slots += 1
	chk(slots == 3, "all three profile slots are there (%d)" % slots)
	s._open_profiles()
	chk(s.get_node("Profiles").get_child_count() == 1, "opening twice does not stack a second screen")
	# Back returns to the menu without a scene change
	s.profiles.get_node("Nav/BackButton").pressed.emit()
	await get_tree().process_frame
	chk(s.profiles == null and menu.visible, "BACK closes it and the menu is back")
	chk(s.get_node("Profiles").get_child_count() == 0, "…and it is freed")
	# Esc closes it too
	s._open_profiles()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	s._unhandled_input(esc)
	await get_tree().process_frame
	chk(s.profiles == null and menu.visible, "ui_cancel (Esc / B) closes it as well")
	# standalone it is what it was: opaque, and Back goes to the title scene
	var alone = load("res://scenes/profile_select.tscn").instantiate()
	add_child(alone)
	chk(not alone.embedded and is_equal_approx(alone.get_node("Background").color.a, 1.0), "opened on its own the profile screen keeps its opaque backdrop")
	alone.queue_free()
