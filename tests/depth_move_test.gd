extends Node

# Headless test for the depth approach-walk framework (player.gd): approach_door
# suspends normal control, steps the player UP toward the door, then runs the
# arrival callback. knock_door returns to the start position.
# Run:  godot --headless res://tests/depth_move_test.tscn

var failures: int = 0
var arrived: bool = false


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== depth approach-walk test ===")
	WorldState.new_game()
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2(500, 388)
	var start_y = player.global_position.y

	# approach_door: steps up toward the door x, then fires the callback.
	player.approach_door(Vector2(560, 360), func(): arrived = true)
	check(player.is_cutscene, "approach_door enters cutscene (control suspended)")
	# Wait out the tween (real-time timer — headless renders frames faster than realtime).
	var waited := 0.0
	while not arrived and waited < 3.0:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	check(arrived, "arrival callback fires")
	check(not player.is_cutscene, "cutscene clears after arrival")
	check(player.global_position.y < start_y, "player stepped UP toward the door (%.0f→%.0f)" % [start_y, player.global_position.y])
	check(absf(player.global_position.x - 560.0) < 2.0, "player moved to the door's x")

	# knock_door: returns to where it started.
	player.global_position = Vector2(500, 388)
	var knock_start = player.global_position
	var done = [false]
	player.knock_door(Vector2(560, 360), func(): done[0] = true)
	var kwaited := 0.0
	while not done[0] and kwaited < 4.0:
		await get_tree().create_timer(0.05).timeout
		kwaited += 0.05
	check(done[0], "knock_door completes")
	check(player.global_position.distance_to(knock_start) < 2.0, "knock_door returns to the start plane")

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)
