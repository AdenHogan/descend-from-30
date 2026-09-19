extends Node

# The scavenge marker is a glowing "mini sun": it must carry a REAL PointLight2D that
# lights up only while the player is scavenging within range, and goes dark otherwise.
# (The animated LOOK can't be checked headless — this locks the weight/glow wiring.)
# Run: godot --headless res://tests/scavenge_node_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== scavenge node test ===")
	await _test_mini_sun_light()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_mini_sun_light() -> void:
	WorldState.new_game()
	var p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 386)
	var node = Marker2D.new()
	node.set_script(load("res://scripts/interactable.gd"))
	node.name = "anchor_test"
	node.apartment_id = "1501"
	add_child(node)
	node.set_process(true)
	node.global_position = Vector2(620, 386)   # ~20px from the player, inside INTERACT range
	await get_tree().process_frame

	var light: PointLight2D = null
	for c in node.get_children():
		if c is PointLight2D:
			light = c
	check(light != null, "the marker carries a real PointLight2D (physical glow)")

	# Scavenging + in range → the orb lights up.
	WorldState.is_scavenge_mode = true
	for i in range(10):
		await get_tree().physics_frame
		await get_tree().process_frame
	check(light != null and light.energy > 0.0, "orb lights up while scavenging in range (energy %.2f)" % (light.energy if light else -1))

	# Out of scavenge mode → dark (never lights a room you're not searching).
	WorldState.is_scavenge_mode = false
	for i in range(4):
		await get_tree().process_frame
	check(light != null and light.energy == 0.0, "orb goes dark out of scavenge mode (energy %.2f)" % (light.energy if light else -1))

	# Far away, even while scavenging → dark.
	WorldState.is_scavenge_mode = true
	node.global_position = Vector2(1100, 386)   # well beyond GLOW_DISTANCE
	for i in range(4):
		await get_tree().process_frame
	check(light != null and light.energy == 0.0, "orb is dark when the player is far (energy %.2f)" % (light.energy if light else -1))

	WorldState.is_scavenge_mode = false
	p.queue_free()
	node.queue_free()
	await get_tree().process_frame
