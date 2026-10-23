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

	# Settings is the same rebinding menu the pause screen uses.
	var sm = preload("res://scripts/settings_menu.gd").new()
	chk(sm.has_method("open") and sm.has_method("close"),
		"settings_menu exposes open()/close() for the title to drive")
	sm.free()

	s.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
