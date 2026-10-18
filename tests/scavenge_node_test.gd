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

	# STAR → FLARE once searched-but-not-emptied: the light colour goes from a saturated hot pink to near-white, so a looked-in
	# orb reads distinctly different while still glowing (owner round 45: "C for unsearched and E for searched but not picked up").
	node.global_position = Vector2(620, 386)     # back in range
	for i in range(3):
		await get_tree().process_frame
	var star := light.color
	check(star.r > 0.9 and star.b > star.g and (maxf(star.r, maxf(star.g, star.b)) - minf(star.r, minf(star.g, star.b))) > 0.4,
		"unsearched orb light is a saturated hot pink (%s)" % str(star))
	var S: Dictionary = node.STAR
	var F: Dictionary = node.FLARE
	check(S["style"] == "star" and F["style"] == "flare", "two looks: the star (unsearched) and the flare (searched)")
	var body: Color = S["body"]
	var rim: Color = S["rim"]
	check(body.s > 0.7 and rim.get_luminance() < 0.12, "the star is saturated and has a DARK rim (the part that shows on a white wall): sat %.2f, rim lum %.2f" % [body.s, rim.get_luminance()])
	check(is_equal_approx(node.ORB_LIGHT_GAIN, 1.2), "the cast light keeps its 1.2x gain (%.2f)" % node.ORB_LIGHT_GAIN)
	# the cast light follows: energy = level x 0.5 x 1.2 x pulse (pulse within +-8%)
	var lvl: float = node._activity()
	check(light.energy >= lvl * 0.5 * 1.2 * 0.91 and light.energy <= lvl * 0.5 * 1.2 * 1.09, "the cast light is 1.2x the old energy (%.3f at level %.2f)" % [light.energy, lvl])
	check(node.material is CanvasItemMaterial and node.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "the marker is drawn unshaded (the night ambient must not dim it)")
	WorldState.mark_anchor_searched("1501", "anchor_test")
	for i in range(3):
		await get_tree().process_frame
	var flare := light.color
	check(flare.b >= flare.r and (maxf(flare.r, maxf(flare.g, flare.b)) - minf(flare.r, minf(flare.g, flare.b))) < 0.2,
		"searched orb light turns cool white (%s)" % str(flare))
	check(node._palette()["style"] == "flare", "a searched node that still holds something draws the flare")
	await _test_orb_draws()

	WorldState.is_scavenge_mode = false
	p.queue_free()
	node.queue_free()
	await get_tree().process_frame


# The two looks really draw: a canvas item that calls draw_orb must put geometry on screen at every proximity level, and a fully
# faded one (level 0) draws nothing. Counts the draw calls through a recording CanvasItem.
class OrbProbe extends Node2D:
	var pal: Dictionary = {}
	var lvl: float = 1.0
	var tex: Texture2D = null
	var draws: int = 0
	func _draw() -> void:
		draws += 1
		var script = load("res://scripts/interactable.gd")
		script.draw_orb(self, tex, Vector2.ZERO, 8.5, pal, 1.3, lvl)


func _test_orb_draws() -> void:
	var script = load("res://scripts/interactable.gd")
	for style in ["star", "flare"]:
		var probe := OrbProbe.new()
		probe.pal = script.STAR if style == "star" else script.FLARE
		probe.tex = load("res://scripts/floor_lighting.gd").light_texture()
		add_child(probe)
		for lv in [0.34, 0.62, 0.82, 1.0]:
			probe.lvl = lv
			probe.queue_redraw()
			await get_tree().process_frame
		check(probe.draws >= 4, "%s was drawn at every proximity level (%d draws)" % [style, probe.draws])
		probe.queue_free()
