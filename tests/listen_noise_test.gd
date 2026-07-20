extends Node

# Headless test for the sound & listen system (docs/SOUND_STEALTH.md):
# noise radii, emit_noise range gating, listen report categories, kill
# subtraction, nearness determinism.
# Run:  godot --headless res://tests/listen_noise_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== listen & noise test ===")
	_test_noise_radii()
	_test_emit_noise()
	_test_categories()
	_test_apartment_report()
	_test_floor_below_report()
	_test_overlay()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_noise_radii() -> void:
	print("[noise radii]")
	var r = WorldState.NOISE_RADIUS
	check(r["crouch"] < r["scavenge"] and r["scavenge"] < r["walk"]
		and r["walk"] < r["run"] and r["run"] < r["door_work"]
		and r["door_work"] < r["gunshot"], "radii strictly ordered by loudness")


func _test_emit_noise() -> void:
	print("[emit_noise]")
	WorldState.new_game()
	var near = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	near.global_position = Vector2(100, 388)
	add_child(near)
	var far = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	far.global_position = Vector2(900, 388)
	add_child(far)
	WorldState.emit_noise(Vector2(50, 388), 120.0, 2.0)
	check(near.alert_timer > 0.0, "zombie inside radius hears the noise")
	check(far.alert_timer == 0.0, "zombie outside radius hears nothing")
	near.queue_free()
	far.queue_free()


func _test_categories() -> void:
	print("[categories]")
	check(WorldState._listen_category(0, false) == "none", "0 => none")
	check(WorldState._listen_category(1, false) == "one", "1 => one")
	check(WorldState._listen_category(2, false) == "few", "2 => few")
	check(WorldState._listen_category(3, false) == "few", "3 => few")
	check(WorldState._listen_category(4, false) == "many", "4 => many")
	check(WorldState._listen_category(10, false) == "many", "horde => many")
	check(WorldState._listen_category(4, true) == "big", "big flag wins")
	for cat in ["none", "one", "few", "many", "big"]:
		check(WorldState.LISTEN_LINES_APARTMENT.has(cat) and WorldState.LISTEN_LINES_BELOW.has(cat),
			"line exists for category " + cat)


func _test_apartment_report() -> void:
	print("[apartment report]")
	WorldState.new_game()
	WorldState.master_seed = 424242
	var apt = "2503"
	WorldState.current_floor = 25
	var raw_count = WorldState.get_apartment_zombie_count(apt)
	var report = WorldState.get_listen_report_for_apartment(apt)
	check(report["count"] == raw_count, "report count matches spawn seed (%d)" % raw_count)
	check(report["line"] == WorldState.LISTEN_LINES_APARTMENT[report["category"]],
		"line matches category")

	# Record a kill inside that apartment: the report must subtract it.
	if raw_count > 0:
		WorldState.killed_zombies["test:1"] = {
			"x": 0, "y": 0, "floor": 25, "scene": "res://scenes/room.tscn",
			"apartment_id": apt, "type": "standard",
		}
		var after = WorldState.get_listen_report_for_apartment(apt)
		check(after["count"] == raw_count - 1, "kill inside apartment reduces the read")
	else:
		check(report["category"] == "none", "empty apartment reads silent")

	# Hallway kills tagged with this apartment id must NOT reduce the read.
	WorldState.killed_zombies["test:2"] = {
		"x": 0, "y": 0, "floor": 25, "scene": "res://scenes/building_floors.tscn",
		"apartment_id": apt, "type": "standard",
	}
	var count_before = WorldState.get_listen_report_for_apartment(apt)["count"]
	WorldState.killed_zombies.erase("test:2")
	check(count_before == WorldState.get_listen_report_for_apartment(apt)["count"],
		"hallway kills don't distort the apartment read")

	var near_a = WorldState.get_listen_nearness("apartment", apt)
	var near_b = WorldState.get_listen_nearness("apartment", apt)
	check(near_a == near_b and near_a >= 0.0 and near_a <= 1.0,
		"nearness is stable and in [0,1]")


func _test_floor_below_report() -> void:
	print("[floor below report]")
	WorldState.new_game()
	WorldState.master_seed = 90210
	WorldState.current_floor = 20
	var raw = WorldState.get_floor_zombie_count(19)
	var report = WorldState.get_listen_report_for_floor_below()
	check(report["count"] == raw, "stairwell read matches floor-19 seed (%d)" % raw)
	check(report["line"] == WorldState.LISTEN_LINES_BELOW[report["category"]],
		"below line matches category")

	WorldState.current_floor = 1
	var lobby = WorldState.get_listen_report_for_floor_below()
	check(lobby["category"] == "none" and lobby["line"].contains("lobby"),
		"floor 1 listens down to the lobby line")


func _test_overlay() -> void:
	print("[overlay]")
	var overlay = load("res://scripts/listen_overlay.gd").new()
	add_child(overlay)
	check(overlay.grey_rect != null and overlay.grey_rect.material != null,
		"grey shader rect builds")
	overlay.begin(Vector2(500, 388), {"count": 3, "has_big": false, "nearness": 0.9})
	check(overlay.state == "fading_in", "begin starts the fade")
	overlay._tick_pings(1.0)
	check(overlay.pings.size() > 0, "audible target spawns pings")
	overlay.abort()
	check(overlay.state == "idle" and overlay.pings.is_empty(),
		"abort clears grey and pings without a report")
	overlay.begin(Vector2(500, 388), {"count": 0, "has_big": false, "nearness": 0.9})
	overlay._tick_pings(1.0)
	check(overlay.pings.is_empty(), "silence produces no pings")
	overlay.finish("test line")
	check(overlay.state == "fading_out", "finish begins the fade-out")
	overlay.queue_free()