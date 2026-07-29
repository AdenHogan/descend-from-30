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
	for name in expected:
		var btn = s.get_node_or_null("Menu/Root/Buttons/%s" % name)
		chk(btn != null, "Menu/Root/Buttons/%s exists" % name)
		if btn != null:
			chk(btn is Button, "%s is a real Button (not a Label + hitbox)" % name)
			chk(btn.text == expected[name],
				"%s reads '%s' (got '%s')" % [name, expected[name], btn.text])
			chk(not btn.disabled, "%s starts enabled" % name)

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

	# Settings is the same rebinding menu the pause screen uses.
	var sm = preload("res://scripts/settings_menu.gd").new()
	chk(sm.has_method("open") and sm.has_method("close"),
		"settings_menu exposes open()/close() for the title to drive")
	sm.free()

	s.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
