extends Node

# SEARCHED FURNITURE CHANGES (owner round 34): a drawer opens / a door swings once its node has been
# searched. tools/art/openables.py bakes the frames; scripts/open_furniture.gd lays them over the module
# art. This locks the data (every opening matches an anchor on that furniture and fits the module), the
# wiring (closed until searched, plays on the search, open on re-entry, run looks) and that the loot
# panel's search really triggers it.
# Run: godot --headless res://tests/open_furniture_test.tscn

const OF := preload("res://scripts/open_furniture.gd")
var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== open furniture test ===")
	_test_meta()
	await _test_attach_and_open()
	await _test_loot_panel_triggers()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_meta() -> void:
	var meta: Dictionary = OF.meta()
	check(not meta.is_empty(), "open_meta.json loads (%d arts)" % meta.size())
	var total := 0
	var all_ok := true
	var near_ok := true
	var run_files := true
	for art in meta.keys():
		var scene: Node = load("res://scenes/Room_Modules/%s.tscn" % art).instantiate()
		for anchor in meta[art].keys():
			total += 1
			var d: Dictionary = meta[art][anchor]
			var fits: bool = int(d["x"]) >= 0 and int(d["y"]) >= 0 and int(d["x"]) + int(d["w"]) <= 320 and int(d["y"]) + int(d["h"]) <= 144
			var tex: Texture2D = OF._texture_for(art, anchor, 1)
			if not fits or tex == null or tex.get_width() != int(d["w"]) * int(d["frames"]) or tex.get_height() != int(d["h"]):
				all_ok = false
				print("    bad opening ", art, " ", anchor, " ", d)
			var a: Node = scene.get_node_or_null(String(anchor))
			if a == null:
				near_ok = false
				print("    no anchor ", art, " ", anchor)
			else:
				var p: Vector2 = a.position
				# the node sits on the furniture that opens: inside its patch (give or take the frame)
				if p.x < d["x"] - 6 or p.x > d["x"] + d["w"] + 6 or p.y < d["y"] - 6 or p.y > d["y"] + d["h"] + 6:
					near_ok = false
					print("    anchor not on its furniture ", art, " ", anchor, " ", p, " ", d)
			for r in [2, 3]:
				if OF._texture_for(art, anchor, r) == null:
					run_files = false
		scene.free()
	check(total >= 10, "at least ten openings are defined (%d)" % total)
	check(all_ok, "every opening fits its 320x144 module and its sheet is frames x patch size")
	check(near_ok, "every opening belongs to a real anchor sitting on that furniture")
	check(run_files, "every opening has a look for runs 2 and 3 (they fall back to run 1 at worst)")


func _kitchen_module(apt: String, run: int) -> Node2D:
	var m: Node2D = load("res://scenes/Room_Modules/kitchen.tscn").instantiate()
	add_child(m)
	OF.attach(m, apt, run)
	return m


func _test_attach_and_open() -> void:
	WorldState.new_game()
	var m := _kitchen_module("o1", 1)
	var fridge: Sprite2D = m.get_node_or_null("Open_anchor_centre_fridge")
	var oven: Sprite2D = m.get_node_or_null("Open_anchor_centre_oven")
	check(fridge != null and oven != null, "the kitchen's fridge and oven get an opening each")
	if fridge == null or oven == null:
		return
	check(not fridge.visible and not oven.visible, "closed until searched")
	var art: Node = m.get_node("Art")
	check(fridge.get_index() == art.get_index() + 1 or fridge.get_index() == art.get_index() + 2,
		"laid just above the art, under the scavenge orbs (index %d, art %d)" % [fridge.get_index(), art.get_index()])
	WorldState.mark_anchor_searched("o1", "anchor_centre_fridge")
	get_tree().call_group("open_furniture", "on_searched", "o1", "anchor_centre_fridge")
	check(fridge.visible and not oven.visible, "searching the fridge's node opens ONLY the fridge")
	check(fridge.frame == 0, "it starts at the first frame (the door just moving)")
	await get_tree().create_timer(OF.STEP * (fridge.frames_total + 2)).timeout
	check(fridge.frame == fridge.frames_total - 1, "…and rests on the last frame (%d)" % fridge.frame)
	# another apartment's identical module is unaffected
	var m2 := _kitchen_module("o2", 1)
	check(not m2.get_node("Open_anchor_centre_fridge").visible, "another flat's fridge stays shut")
	m.queue_free(); m2.queue_free()
	await get_tree().process_frame
	# a re-entry / load: already searched → open at once, no animation
	var m3 := _kitchen_module("o1", 1)
	var f3: Sprite2D = m3.get_node("Open_anchor_centre_fridge")
	check(f3.visible and f3.frame == f3.frames_total - 1, "a searched node's furniture is already open on re-entry")
	m3.queue_free()
	# the aged run looks load their own sheets
	var m4 := _kitchen_module("o3", 3)
	var f4: Sprite2D = m4.get_node("Open_anchor_centre_fridge")
	check(f4.texture != null and f4.texture.resource_path.ends_with("_r3.png"), "run 3 uses the run-3 sheet (%s)" % f4.texture.resource_path)
	m4.queue_free()
	# a module with no openings (a variant) attaches nothing and never errors
	var v: Node2D = load("res://scenes/Room_Modules/kitchen_b.tscn").instantiate()
	add_child(v)
	check(OF.attach(v, "o4", 1).is_empty(), "a module without openings gets none")
	v.queue_free()


func _test_loot_panel_triggers() -> void:
	WorldState.new_game()
	var m := _kitchen_module("o5", 1)
	var oven: Sprite2D = m.get_node("Open_anchor_centre_oven")
	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame
	WorldState.is_scavenge_mode = true
	WorldState.set_anchor_item("o5", "anchor_centre_oven", "")
	loot.open("", "anchor_centre_oven", "o5")
	check(not oven.visible, "still shut while the search is under way")
	loot._process(loot.REVEAL_TIME + 0.1)
	check(oven.visible, "finishing the search in the REAL loot panel opens the oven")
	loot.queue_free(); m.queue_free()
