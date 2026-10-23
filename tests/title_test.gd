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

	# The title carries the in-house logo (docs/logo/README.md), not a Label: a transparent
	# PNG over the painted building, wholly on screen and clear of the menu below it.
	var logo = s.get_node_or_null("Logo")
	chk(logo is Sprite2D, "the title has a Logo sprite")
	if logo is Sprite2D:
		chk(logo.texture != null and logo.texture.resource_path == "res://assets/logo/logo_full_dark.png",
			"the Logo is assets/logo/logo_full_dark.png (got '%s')" % (logo.texture.resource_path if logo.texture != null else "none"))
		var half: Vector2 = logo.texture.get_size() * logo.scale * 0.5
		var rect := Rect2(logo.position - half, half * 2.0)
		var shown := Rect2(Vector2.ZERO, Vector2(1152, 648))
		chk(shown.encloses(rect), "the Logo sits wholly on screen (rect %s)" % str(rect))
		var buttons_node = s.get_node("Menu/Root/Buttons")
		var menu_rect := Rect2(Vector2(576.0 + buttons_node.offset_left, 324.0 + buttons_node.offset_top),
			Vector2(buttons_node.offset_right - buttons_node.offset_left, buttons_node.offset_bottom - buttons_node.offset_top))
		chk(not rect.intersects(menu_rect), "the Logo %s keeps clear of the menu %s" % [str(rect), str(menu_rect)])
		chk(logo.position.x > 576.0 and logo.position.y < 324.0, "the Logo sits top-right (owner round 48e pick), at %s" % str(logo.position))
		chk(logo.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"the Logo is drawn linear + mipmapped (a 2400 px image shrunk to ~380 px)")
	var old_title := []
	stack = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and String(n.text).to_lower().contains("descend"):
			old_title.append(n.name)
		for c in n.get_children():
			stack.append(c)
	chk(old_title.is_empty(), "no placeholder title Label left under the logo %s" % str(old_title))

	_test_backdrop(s)

	# Settings is the same rebinding menu the pause screen uses.
	var sm = preload("res://scripts/settings_menu.gd").new()
	chk(sm.has_method("open") and sm.has_method("close"),
		"settings_menu exposes open()/close() for the title to drive")
	sm.free()

	s.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)


# The title's backdrop is the game's own night exterior, ALIVE (owner round 48f: "that background itself needs changing… more animated").
func _test_backdrop(s: Node) -> void:
	var Ext = preload("res://scripts/opening_exterior.gd")
	chk(s.get_node_or_null("Backdrop") is CanvasLayer, "the title has a Backdrop layer")
	chk(s.get_node_or_null("Backdrop/Fallback") is ColorRect, "…with a plain dark Fallback under it (a title must always come up)")
	chk(s.get_node_or_null("DescendFrom30PlaceholderTitleScreen") == null, "the painted placeholder is gone")
	chk(Ext.art_present(Ext.TITLE_RUN), "the night exterior's art is present")

	# pure functions of the clock: starts on the roof, sinks TITLE_DROP, is back after a period, never leaves that band
	chk(is_equal_approx(Ext.title_camera(0.0, 457.0), 457.0), "the camera starts on the roof")
	chk(is_equal_approx(Ext.title_camera(Ext.TITLE_PERIOD * 0.5, 457.0), 457.0 - Ext.TITLE_DROP), "…is a TITLE_DROP lower half a period later")
	chk(is_equal_approx(Ext.title_camera(Ext.TITLE_PERIOD, 457.0), 457.0), "…and back on the roof after a whole period")
	var lo := 1.0e9
	var hi := -1.0e9
	for i in 2000:
		var c: float = Ext.title_camera(float(i) * 0.37, 457.0)
		lo = minf(lo, c)
		hi = maxf(hi, c)
	chk(lo >= 457.0 - Ext.TITLE_DROP - 0.001 and hi <= 457.001, "the camera stays inside its band (%.1f..%.1f)" % [lo, hi])
	chk(is_equal_approx(Ext.title_black(0.0), 1.0) and is_equal_approx(Ext.title_black(Ext.TITLE_FADE_IN), 0.0) and is_equal_approx(Ext.title_black(999.0), 0.0),
		"it fades up from black once and never back down")

	# the fire is the title's own — the same whatever game state is (or isn't) loaded
	var seed0: int = WorldState.master_seed
	var run0: int = WorldState.current_run
	var plan_a: Array = Ext.title_burn_plan()
	WorldState.master_seed = seed0 + 12345
	WorldState.current_run = 3
	var plan_b: Array = Ext.title_burn_plan()
	WorldState.master_seed = seed0
	WorldState.current_run = run0
	chk(plan_a.size() == 4 and JSON.stringify(plan_a) == JSON.stringify(plan_b), "the title's burning floors do not depend on the game state")
	var drifted := true
	for e in plan_a:
		# the floor's top edge in scene px (30 floors of 14, floor 30's top at 30); the layer sits at VIEW_H - 526 + camera
		var y_top: float = 30.0 + float(30 - int(e["floor"])) * 14.0
		var seen := false
		for i in 400:
			var cam: float = Ext.title_camera(float(i) * Ext.TITLE_PERIOD / 400.0, 457.0)
			var sy: float = y_top + (Ext.VIEW_H - 526.0) + cam
			if sy >= 0.0 and sy + 14.0 <= Ext.VIEW_H:
				seen = true
				break
		drifted = drifted and seen
	chk(drifted, "every burning floor comes into view at some point of the drift")

	# built and ticked: a live node tree that never ends
	var host := Node.new()
	add_child(host)
	var stale: Node = s
	host.add_child(stale)
	var bd = stale.get("backdrop")
	chk(bd != null and bd.load_ok and bd.title_mode, "the backdrop builds (title mode, load_ok)")
	if bd != null and bd.load_ok:
		chk(bd.run == 3 and not bd.title.visible, "it is the run-3 night and carries no title card")
		chk(bd.rain != null and bd.bolt != null and bd.flash != null, "rain, bolt and flash are all there")
		chk(not bd.beacons.is_empty() and not bd.flames.is_empty(), "beacons blink and flames burn (%d / %d)" % [bd.beacons.size(), bd.flames.size()])
		chk(bd.shade.color.a > 0.99, "it opens on black")
		var sky = bd.layers["sky"]["node"].get_child(0)
		chk(sky is Sprite2D and sky.flip_h, "the sky is turned so the moon is clear of the top-right logo")
		chk(bd._hum == null and bd._siren == null and bd._swell == null, "no hum / siren / swell: Game's music is the bed")
		chk(bd._rain_snd != null and bd._rain_snd.stream != null and bd._thunder != null, "the storm's own rain wash and thunder are on")
		var struck := 0
		var prev := 0.0
		var y_first := -1.0
		var y_min := 1.0e9
		var y_max := -1.0e9
		for i in 4000:                                   # 400 s of game time, ~5 periods of the drift
			bd.tick(0.1)
			if bd.flash.modulate.a > prev + 0.2:
				struck += 1
			prev = bd.flash.modulate.a
			var y: float = bd.layers["scene"]["node"].position.y
			if y_first < 0.0:
				y_first = y
			y_min = minf(y_min, y)
			y_max = maxf(y_max, y)
		chk(not bd.done, "it never ends (done stays false after %.0f s)" % bd.t)
		chk(bd.shade.color.a < 0.01, "and it has faded up out of black")
		chk(struck >= 20, "lightning keeps striking (%d flashes in 400 s)" % struck)
		chk(y_max - y_min > 100.0, "the building really does drift (%.0f px of scene travel)" % (y_max - y_min))
	host.remove_child(stale)
	host.free()

