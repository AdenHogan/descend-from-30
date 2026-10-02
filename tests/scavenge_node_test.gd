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
	check(light != null and light.energy > 0.0, "orb lights up while scavenging in range (energy %.2f)" % (light.energy if light else -1.0))

	# Out of scavenge mode → dark (never lights a room you're not searching).
	WorldState.is_scavenge_mode = false
	for i in range(4):
		await get_tree().process_frame
	check(light != null and light.energy == 0.0, "orb goes dark out of scavenge mode (energy %.2f)" % (light.energy if light else -1.0))

	# Far away, even while scavenging → dark.
	WorldState.is_scavenge_mode = true
	node.global_position = Vector2(1100, 386)   # well beyond GLOW_DISTANCE
	for i in range(4):
		await get_tree().process_frame
	check(light != null and light.energy == 0.0, "orb is dark when the player is far (energy %.2f)" % (light.energy if light else -1.0))

	# GOLD → PALE once searched-but-not-emptied: the light colour drains from warm gold to
	# cool white, so a searched orb reads distinctly different while still glowing.
	node.global_position = Vector2(620, 386)     # back in range
	for i in range(3):
		await get_tree().process_frame
	var gold := light.color
	check(gold.r > gold.b, "unsearched orb light is warm gold (r %.2f > b %.2f)" % [gold.r, gold.b])
	# owner round 34: "a little more silvery gold… dial up the brightness of them 20%"
	var G: Dictionary = node.GOLD
	var body: Color = G["body"]
	check(body.get_luminance() >= 0.88 and body.b > 0.5 and body.r > body.b, "the gold is a pale champagne, not a saturated yellow (lum %.2f, b %.2f)" % [body.get_luminance(), body.b])
	check(is_equal_approx(node.ORB_LIGHT_GAIN, 1.2) and node.ORB_BRIGHTNESS > 1.05 and node.ORB_BRIGHTNESS < 1.15, "the glow gains ~20%% over the old gold (layers x%.2f, light x%.2f)" % [node.ORB_BRIGHTNESS, node.ORB_LIGHT_GAIN])
	# the cast light follows: energy = level x 0.5 x 1.2 x pulse (pulse within +-8%)
	var lvl: float = node._activity()
	check(light.energy >= lvl * 0.5 * 1.2 * 0.91 and light.energy <= lvl * 0.5 * 1.2 * 1.09, "the cast light is 1.2x the old energy (%.3f at level %.2f)" % [light.energy, lvl])
	WorldState.mark_anchor_searched("1501", "anchor_test")
	for i in range(3):
		await get_tree().process_frame
	var pale := light.color
	check(pale.b >= pale.r, "searched orb light turns cool/pale (r %.2f <= b %.2f)" % [pale.r, pale.b])

	WorldState.is_scavenge_mode = false
	p.queue_free()
	node.queue_free()
	await get_tree().process_frame
