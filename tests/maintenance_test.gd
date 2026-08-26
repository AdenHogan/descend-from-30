extends Node
# Maintenance room (maintenance.tscn) — a small SAFE room: no enemies, exactly two
# scavenge anchors (toolbox/fuse-weighted), reusing room.gd's scavenge/loot layer via
# its maintenance branch. Run: godot --headless res://tests/maintenance_test.tscn
var fails := 0
func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c: fails += 1

func _ready() -> void:
	print("=== maintenance room ===")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.current_floor = 21
	WorldState.is_scavenge_mode = true
	var m = load("res://scenes/maintenance.tscn").instantiate()
	add_child(m)
	for i in range(10): await get_tree().process_frame
	chk(m.get_node_or_null("Player") != null, "maintenance room has a player")
	chk(m._is_maintenance(), "room.gd takes the maintenance branch")
	chk(m.interactables.size() == 2, "exactly two scavenge anchors (%d)" % m.interactables.size())
	var non_maint := false
	for a in m.interactables:
		if not str(a.apartment_id).begins_with("MAINT"):
			non_maint = true
	chk(not non_maint, "anchors are keyed to the maintenance room, not an apartment")
	# SAFE: no enemies ever.
	var zc := get_tree().get_nodes_in_group("zombie").size()
	chk(zc == 0, "no enemies spawn in the maintenance room (%d)" % zc)
	# Loot is toolbox/fuse/notes/empty only (never a random apartment item).
	var ok_items := true
	for a in m.interactables:
		var it: String = WorldState.get_anchor_item(a.apartment_id, a.name)
		if it != "" and not (it in ["019", "020", "033"]):
			ok_items = false
	chk(ok_items, "anchor loot is maintenance-appropriate (toolbox/fuse/notes/empty)")
	m.free()
	await get_tree().process_frame
	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
