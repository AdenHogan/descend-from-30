extends Node

# The profile-select LAYOUT is a real scene, so an art pass can restyle it
# freely. This guards the contract the script relies on: the nodes it fills in
# must exist under the names it looks for.
# Run:  godot --headless res://tests/profile_ui_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1

func _ready() -> void:
	print("=== profile select scene ===")
	var s = load("res://scenes/profile_select.tscn").instantiate()
	chk(s != null, "profile_select.tscn loads")
	# Left navigation column carries the heading and every action.
	for nav in ["Nav/Heading", "Nav/Subheading", "Nav/ContinueButton",
			"Nav/NewGameButton", "Nav/DeleteButton", "Nav/BackButton"]:
		chk(s.get_node_or_null(nav) != null, "%s exists" % nav)
	# Cards stay clean: header, emblem, current run, stats.
	for slot in range(1, WorldState.SLOT_COUNT + 1):
		var root := "Slot%d" % slot
		chk(s.get_node_or_null(root) != null, "%s exists" % root)
		for child in ["SelectBorder", "Card", "Name", "Emblem", "RunCaption",
				"RunPlace", "RunName", "Playtime", "Status", "RunsMade",
				"RunsWon", "SelectButton", "SurvivorCaption", "Money",
				"Survivor1", "Survivor2", "Survivor3",
				"SurvivorFace1", "SurvivorFace2", "SurvivorFace3",
				"SurvivorTag1", "SurvivorTag2", "SurvivorTag3"]:
			chk(s.get_node_or_null("%s/%s" % [root, child]) != null,
				"%s/%s exists" % [root, child])
	# Nothing in the scene may swallow world clicks the way HUD labels once did.
	var stop := 0
	var stack: Array[Node] = [s]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label or n is Panel or n is ColorRect:
			if n.mouse_filter == Control.MOUSE_FILTER_STOP:
				stop += 1
		for c in n.get_children():
			stack.append(c)
	chk(stop == 0, "no decorative control swallows clicks (%d)" % stop)
	# Playtime formatting is what the card shows for time played.
	chk(WorldState.format_playtime(5064.0) == "01:24:24",
		"playtime formats as HH:MM:SS (%s)" % WorldState.format_playtime(5064.0))
	s.free()
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
