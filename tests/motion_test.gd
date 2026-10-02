extends Node

# MOTION (owner round 26: "animations for certain items like the dripping milk or flowers moving in
# the wind"). Ambient movement that costs nothing to gameplay but makes the building feel lived in:
#  * potted plants in the corridor lean in the wind — pinned at the pot, in whole texel steps, and never
#    move where they stand; the wind rises through the day;
#  * the EXIT sign follows the building's decay (steady / stutters / dead) and never un-decays.
# Run:  godot --headless res://tests/motion_test.tscn

const Sway := preload("res://scripts/sway.gd")
const SignFx := preload("res://scripts/exit_sign_fx.gd")
const CD := preload("res://scripts/corridor_decals.gd")
const BF := preload("res://scripts/building_floors.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== motion test ===")
	await get_tree().process_frame
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	_test_sway()
	_test_corridor_plants()
	_test_exit_sign()
	await _test_exit_sign_in_a_floor()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_sway() -> void:
	print("[sway]")
	check(not Sway.spec_for("plant_tall").is_empty() and Sway.spec_for("shoe_rack").is_empty(),
		"plants sway; a shoe rack doesn't")
	var tex: Texture2D = load("res://assets/corridor/decals/plant_tall.png")
	check(tex != null, "plant_tall art loads")
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(100, 50)
	var w0: int = tex.get_width()
	var h0: int = tex.get_height()
	check(Sway.apply(s, "plant_tall", 7, 1), "apply() takes a plant")
	check(s.texture.get_width() == w0 + 2 * Sway.PAD and s.texture.get_height() == h0,
		"…its texture grows by the pad each side, not in height (%dx%d → %dx%d)" % [w0, h0, s.texture.get_width(), s.texture.get_height()])
	check(is_equal_approx(s.position.x, 100.0 - Sway.PAD) and is_equal_approx(s.position.y, 50.0),
		"…and it moves left by the pad so it stands where it did")
	var a: Image = tex.get_image()
	var b: Image = s.texture.get_image()
	var same := true
	for y in range(0, h0, 3):
		for x in range(0, w0, 3):
			if a.get_pixel(x, y) != b.get_pixel(x + Sway.PAD, y):
				same = false
	var edges_clear := true
	for y in range(h0):
		for k in range(Sway.PAD):
			if b.get_pixel(k, y).a != 0.0 or b.get_pixel(b.get_width() - 1 - k, y).a != 0.0:
				edges_clear = false
	check(same and edges_clear, "…every pixel is where it was, the added columns are clear")
	check(s.material is ShaderMaterial and s.material.shader == Sway.shader() and s.get_meta("sway", false), "…with the shared sway shader")
	check(not Sway.apply(s, "plant_tall", 7, 1), "a second apply() is refused (no double padding)")
	check(Sway.wind_for_run(1) < Sway.wind_for_run(2) and Sway.wind_for_run(2) < Sway.wind_for_run(3),
		"the wind rises morning → afternoon → night")
	var s3 := Sprite2D.new()
	s3.texture = tex
	Sway.apply(s3, "plant_tall", 7, 3)
	check(float(s3.material.get_shader_parameter("wind")) > float(s.material.get_shader_parameter("wind")), "…and the sprite carries its run's wind")
	var s4 := Sprite2D.new()
	s4.texture = tex
	Sway.apply(s4, "plant_tall", 8, 1)
	check(s4.material.get_shader_parameter("phase") != s.material.get_shader_parameter("phase")
		and is_equal_approx(float(s3.material.get_shader_parameter("phase")), float(s.material.get_shader_parameter("phase"))),
		"the phase is seeded: two plants differ, the same seed repeats")
	check(Sway.SHADER_CODE.contains("floor(") and Sway.SHADER_CODE.contains("TEXTURE_PIXEL_SIZE"), "the shader steps in whole texels (pixel art)")
	_test_gusts()
	for n in [s, s3, s4]:
		n.free()


## Owner round 34: "a small potted plant with no leaves… no reason whatsoever that it should be swaying… we also don't need the
## pixel jump on the animation to be so extreme. The plant looked like it was cut up when it swayed."
func _test_gusts() -> void:
	print("[gusts: still most of the time, never more than one texel]")
	check(Sway.spec_for("plant_dead").is_empty(), "a dead corridor planter doesn't sway")
	check(Sway.SHADER_CODE.contains("gust(") and Sway.SHADER_CODE.contains("max_amp"), "the shader gusts and caps the lean")
	var winds := [Sway.wind_for_run(1), Sway.wind_for_run(2), Sway.wind_for_run(3)]
	var calm: Array = []
	for w in winds:
		var still := 0
		var total := 0
		var worst := 0
		for ph in [0.0, 1.3, 2.9, 4.4, 5.6]:
			var t := 0.0
			while t < 900.0:
				var g: float = Sway.gust_at(t, ph, w)
				if g < 0.02:
					still += 1
				total += 1
				for kind in ["plant_tall", "plant_stand"]:
					worst = maxi(worst, absi(Sway.offset_at(t, Sway.spec_for(kind), ph, w, 1.0)))
				for kind in ["tuft", "flower", "fern", "potted"]:
					worst = maxi(worst, absi(Sway.offset_at(t, Sway.GROWTH[kind], ph, w, 1.0)))
				t += 0.25
		calm.append(float(still) / float(total))
		check(worst <= 1, "wind %.1f: anything that stands leans at most ONE texel (worst %d)" % [w, worst])
	check(calm[0] >= 0.6 and calm[1] >= 0.5 and calm[2] >= 0.35, "it's still most of the time: calm %s of the day (morning / afternoon / night)" % str(calm))
	check(calm[0] > calm[1] and calm[1] > calm[2], "later runs gust more often (calm shrinks)")
	var vine_worst := 0
	var vine_mid := 0
	for ph in [0.0, 2.0, 4.0]:
		var t2 := 0.0
		while t2 < 900.0:
			vine_worst = maxi(vine_worst, absi(Sway.offset_at(t2, Sway.GROWTH["hang"], ph, 1.7, 1.0)))
			vine_mid = maxi(vine_mid, absi(Sway.offset_at(t2, Sway.GROWTH["hang"], ph, 1.7, 0.5)))
			t2 += 0.25
	check(vine_worst <= 2 and vine_worst >= 1 and vine_mid <= 1, "a long vine swings at most two texels at its tip (%d), one half way down (%d)" % [vine_worst, vine_mid])
	# the CPU copy IS the shader's maths: the shader text carries the same constants
	check(Sway.SHADER_CODE.contains(str(Sway.GUST_OPEN)) and Sway.SHADER_CODE.contains(str(Sway.GUST_FULL)) and Sway.SHADER_CODE.contains(str(Sway.MAX_STAND)),
		"the shader and gust_at share their constants")


func _test_corridor_plants() -> void:
	print("[corridor plants]")
	var found_floor := -1
	var found_run := 1
	for seed_ in range(1, 15):                                  # any one seed may deal no plant at all
		if found_floor > 0:
			break
		WorldState.master_seed = seed_ * 104729
		for f in range(1, 30):
			for r in [1, 2, 3]:
				for d in CD.plan(f, r, BF.corridor_base_name(f)):
					if Sway.spec_for(CD.base_of(String(d["name"]))).size() > 0 and found_floor < 0:
						found_floor = f
						found_run = r
	check(found_floor > 0, "some floor carries a swaying plant (floor %d, run %d)" % [found_floor, found_run])
	var root := Node2D.new()
	add_child(root)
	CD.add_to(root, found_floor, found_run, BF.corridor_base_name(found_floor), Vector2.ZERO)
	var planned: Dictionary = {}
	for d in CD.plan(found_floor, found_run, BF.corridor_base_name(found_floor)):
		if Sway.spec_for(CD.base_of(String(d["name"]))).size() > 0:
			planned[str(d["pos"])] = true
	var swaying := 0
	var moved := false
	var wrong := false
	for holder in root.get_children():
		for c in holder.get_children():
			if c is Sprite2D:
				var nm: String = String(c.get_meta("decal", ""))
				if c.get_meta("sway", false):
					swaying += 1
					if not Sway.spec_for(CD.base_of(nm)).size() > 0:
						wrong = true
					if not planned.has(str(Vector2(c.position.x + Sway.PAD, c.position.y))):
						moved = true
				elif Sway.spec_for(CD.base_of(nm)).size() > 0:
					wrong = true
	check(swaying == planned.size() and swaying > 0, "every planned plant sways (%d of %d)" % [swaying, planned.size()])
	check(not wrong, "…and nothing else does (no fallen plant, no shoe rack)")
	check(not moved, "…and each still stands exactly where the planner put it")
	root.free()
	# a knocked-over plant stays put (which seed knocks one over varies — new_game rolls a random seed —
	# so look across a few until one shows; the rule itself is the spec table, not the dice)
	var fallen := 0
	for seed_ in range(1, 15):
		if fallen > 0:
			break
		WorldState.master_seed = seed_ * 104729
		for f in range(1, 30):
			for d in CD.plan(f, 3, BF.corridor_base_name(f)):
				if CD.base_of(String(d["name"])) in ["plant_fallen", "plant_stand_fallen"]:
					fallen += 1
	check(fallen > 0 and Sway.spec_for("plant_fallen").is_empty() and Sway.spec_for("plant_stand_fallen").is_empty(),
		"knocked-over plants exist and don't sway (%d)" % fallen)


func _severity(st: String) -> int:
	return {"steady": 0, "flicker": 1, "dead": 2}[st]


func _test_exit_sign() -> void:
	print("[exit sign]")
	var mono := true
	var seen := {}
	var early_dead := 0
	for seed_ in [1, 2, 3, 4, 5]:
		WorldState.master_seed = seed_ * 7919
		for f in range(1, 30):
			var prev := -1
			for r in [1, 2, 3]:
				var sv: int = _severity(SignFx.state_for(f, r))
				if sv < prev:
					mono = false
				prev = sv
				if r == 3:
					seen[SignFx.state_for(f, r)] = true
			if f >= 25 and SignFx.state_for(f, 1) == "dead":
				early_dead += 1
	check(mono, "a sign never gets better through the day (5 seeds × 29 floors)")
	check(seen.has("steady") and seen.has("flicker") and seen.has("dead"), "by night all three states occur (%s)" % str(seen.keys()))
	check(SignFx.state_for(29, 1) == SignFx.state_for(29, 1), "it's deterministic")
	var dead_run1 := 0
	var dead_run3 := 0
	WorldState.master_seed = 4242
	for f in range(1, 30):
		if SignFx.state_for(f, 1) == "dead":
			dead_run1 += 1
		if SignFx.state_for(f, 3) == "dead":
			dead_run3 += 1
	check(dead_run3 > dead_run1, "more signs are dead by night than by morning (%d → %d)" % [dead_run1, dead_run3])
	var lit_n := 0
	var dark_n := 0
	for i in range(400):
		if SignFx.flicker_lit(float(i) * 0.01, 4.0):
			lit_n += 1
		else:
			dark_n += 1
	check(lit_n > 0 and dark_n > 0, "a stuttering sign is lit and dark within a period (%d lit / %d dark)" % [lit_n, dark_n])
	var steady_after := true
	for i in range(90, 400):
		if not SignFx.flicker_lit(float(i) * 0.01, 4.0):
			steady_after = false
	check(steady_after, "…and steady for the rest of it")
	WorldState.master_seed = 9
	var dead_floor := -1
	var flick_floor := -1
	for f in range(1, 30):
		var st: String = SignFx.state_for(f, 3)
		if st == "dead" and dead_floor < 0:
			dead_floor = f
		if st == "flicker" and flick_floor < 0:
			flick_floor = f
	if dead_floor > 0:
		var fx = SignFx.new()
		add_child(fx)
		fx.setup(dead_floor, 3)
		check(fx.state == "dead" and not fx.lit and fx._light.energy == 0.0 and not fx.is_processing(), "a dead sign is dark, gives no light, costs no frames")
		fx.free()
	if flick_floor > 0:
		var fx2 = SignFx.new()
		add_child(fx2)
		fx2.setup(flick_floor, 3)
		check(fx2.state == "flicker" and fx2.is_processing() and fx2._light.energy > 0.0, "a flickering sign is live and lit")
		fx2.free()


func _test_exit_sign_in_a_floor() -> void:
	print("[exit sign in a floor]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	WorldState.current_floor = 14
	WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(14)
	WorldState.stair_direction = "down"
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 14
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	var fx = bf.get_node_or_null("ExitSignFx")
	check(fx != null and fx.state == SignFx.state_for(14, WorldState.current_run), "a real floor carries its sign's fx (%s)" % (fx.state if fx != null else "missing"))
	check(fx != null and fx.position == BF.CORRIDOR_ART_POS, "…on the corridor art")
	var decals = bf.get_node_or_null("CorridorDecals")
	var doors_first = bf.get_node_or_null("apartment01")
	check(fx != null and decals != null and fx.get_index() == decals.get_index() + 1, "…drawn just above the decals (the decals keep their place right on the art)")
	check(fx != null and doors_first != null and fx.get_index() < doors_first.get_index(), "…and under the doors and every actor")
	bf.free()
