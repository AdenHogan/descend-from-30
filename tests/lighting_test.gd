extends Node

# Headless smoke test for the REAL lighting system: the ceiling-lamp rig
# (scripts/floor_lighting.gd), the ambient-darkness model (WorldState), and the dev
# bypass. Rendering is off headless, but the PointLight2D nodes + seeded dead/flicker
# bookkeeping still build, so we verify the STRUCTURE and the determinism/escalation.
# Run: godot --headless res://tests/lighting_test.tscn

const FLOOR_LIGHTING := preload("res://scripts/floor_lighting.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== lighting test ===")
	_test_shared_texture()
	_test_lamp_rig_builds()
	_test_more_dead_deeper_and_later()
	_test_window_light()
	_test_night_vision_upgrade()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _dead_count(node: Node) -> int:
	# A dead lamp's PointLight2D is left invisible; count them.
	var dead := 0
	for c in node.get_children():
		if c is PointLight2D and not c.visible:
			dead += 1
	return dead


func _test_shared_texture() -> void:
	print("[shared light cookies]")
	var a := FLOOR_LIGHTING.light_texture()
	var b := FLOOR_LIGHTING.light_texture()
	check(a != null, "light_texture (round) builds a cookie")
	check(a == b, "the round cookie is shared (cached), not rebuilt per light")
	var c := FLOOR_LIGHTING.cone_texture()
	var d := FLOOR_LIGHTING.cone_texture()
	check(c != null, "cone_texture (downward spotlight) builds a cookie")
	check(c == d, "the cone cookie is shared (cached)")
	check(c != a, "the cone and round cookies are distinct textures")


func _test_window_light() -> void:
	print("[window natural light]")
	WorldState.new_game()
	WorldState.current_run = 1
	var day := FLOOR_LIGHTING.make_window_light(Vector2(171, 300))
	add_child(day)
	check(day is PointLight2D, "make_window_light returns a PointLight2D")
	var day_e: float = day.energy
	WorldState.current_run = 3
	var night := FLOOR_LIGHTING.make_window_light(Vector2(171, 300))
	add_child(night)
	check(night.energy < day_e, "window daylight is dimmer at night (moonlight) (%.2f < %.2f)" % [night.energy, day_e])
	check(night.color.b > night.color.r, "night window reads cool/blue (moonlight)")
	day.queue_free()
	night.queue_free()


func _test_night_vision_upgrade() -> void:
	print("[Night Eyes upgrade]")
	WorldState.new_game()
	WorldState.current_run = 3
	var base_e: float = WorldState.player_aura_energy()
	var base_s: float = WorldState.player_aura_scale()
	var base_amb := WorldState.ambient_color(15)
	check("U_nightvision" in WorldState.UPGRADE_POOL, "Night Eyes is in the upgrade pool")
	WorldState.active_upgrades.append("U_nightvision")
	check(WorldState.get_night_vision() > 0.0, "owning Night Eyes registers night vision")
	check(WorldState.player_aura_energy() > base_e, "Night Eyes widens the aura energy at night (%.2f > %.2f)" % [WorldState.player_aura_energy(), base_e])
	check(WorldState.player_aura_scale() > base_s, "Night Eyes widens the aura reach at night (%.2f > %.2f)" % [WorldState.player_aura_scale(), base_s])
	var nv_amb := WorldState.ambient_color(15)
	check((nv_amb.r + nv_amb.g + nv_amb.b) > (base_amb.r + base_amb.g + base_amb.b), "Night Eyes lifts the night ambient a little")
	WorldState.active_upgrades.erase("U_nightvision")


func _test_lamp_rig_builds() -> void:
	print("[ceiling lamp rig]")
	WorldState.new_game()
	WorldState.current_run = 1
	var rig := FLOOR_LIGHTING.new()
	add_child(rig)
	rig.setup(30)
	var cone := FLOOR_LIGHTING.cone_texture()
	var lamps := 0
	var windows := 0
	for c in rig.get_children():
		if c is PointLight2D:
			if c.texture == cone:
				lamps += 1
			else:
				windows += 1
	check(lamps == FLOOR_LIGHTING.COUNT, "one cone lamp per slot (%d)" % lamps)
	check(windows == 2, "two stairwell window lights (%d)" % windows)
	# Determinism: the same floor/run/seed produces the same dead layout.
	var rig2 := FLOOR_LIGHTING.new()
	add_child(rig2)
	rig2.setup(30)
	check(_dead_count(rig) == _dead_count(rig2), "dead-lamp layout is deterministic per (floor,run,seed)")
	rig.queue_free()
	rig2.queue_free()


func _test_more_dead_deeper_and_later() -> void:
	print("[failing lower/later building]")
	WorldState.new_game()
	# Average dead across floors is higher deep than up top (seeded per floor, so compare
	# a spread rather than a single seed which can tie).
	WorldState.current_run = 1
	var dead_top := 0
	var dead_bot := 0
	for f in range(25, 31):        # near the top
		var r := FLOOR_LIGHTING.new(); add_child(r); r.setup(f)
		dead_top += _dead_count(r); r.queue_free()
	for f in range(1, 7):          # near the bottom
		var r2 := FLOOR_LIGHTING.new(); add_child(r2); r2.setup(f)
		dead_bot += _dead_count(r2); r2.queue_free()
	check(dead_bot >= dead_top, "more lamps dead deep in the building (bottom %d >= top %d)" % [dead_bot, dead_top])
	# Later runs kill more lamps on the same floor band.
	var dead_r1 := 0
	var dead_r3 := 0
	for f in range(10, 20):
		WorldState.current_run = 1
		var a := FLOOR_LIGHTING.new(); add_child(a); a.setup(f)
		dead_r1 += _dead_count(a); a.queue_free()
		WorldState.current_run = 3
		var b := FLOOR_LIGHTING.new(); add_child(b); b.setup(f)
		dead_r3 += _dead_count(b); b.queue_free()
	check(dead_r3 >= dead_r1, "more lamps dead later in the arc (run3 %d >= run1 %d)" % [dead_r3, dead_r1])
