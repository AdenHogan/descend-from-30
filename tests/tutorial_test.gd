extends Node

# Headless test for the Floor-30 blood-text tutorial hints.
# Run:  godot --headless res://tests/tutorial_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== tutorial hints test ===")
	_test_hint_data()
	await _test_blood_text_builds()
	_test_spawn()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_hint_data() -> void:
	print("[hint data]")
	var hall = TutorialHints.hallway_hints()
	var room = TutorialHints.room_hints()
	check(hall.size() >= 5, "several hallway hints (%d)" % hall.size())
	check(room.size() >= 2, "room hints present (%d)" % room.size())
	# Live key labels are interpolated in (no leftover format tokens).
	var joined = ""
	for h in hall:
		joined += h[2]
	check(not joined.contains("%s"), "key placeholders resolved to real bindings")
	check(joined.contains(SettingsManager.binding_label("listen")), "listen key appears in the hints")


func _test_blood_text_builds() -> void:
	print("[blood text]")
	var bt = load("res://scripts/blood_text.gd").new()
	bt.setup("MOVE  A · D", 20)
	add_child(bt)
	await get_tree().process_frame
	await get_tree().process_frame
	check(bt._label != null and bt._label.text == "MOVE  A · D", "blood text builds its label")
	check(bt._drips.size() > 0, "drips generated under the text")
	bt.queue_free()


func _test_spawn() -> void:
	print("[spawn]")
	var holder = Node2D.new()
	add_child(holder)
	TutorialHints.spawn(holder, TutorialHints.hallway_hints())
	check(holder.get_child_count() == TutorialHints.hallway_hints().size(), "spawn adds one node per hint")
	holder.queue_free()
