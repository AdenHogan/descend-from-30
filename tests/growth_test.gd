extends Node

# OVERGROWTH — the building changing (owner round 26). How much (depth × run), where it grows in a
# corridor, that it only ever adds, that fire wins, and that what moves sways.
# Run:  godot --headless res://tests/growth_test.tscn

const OG := preload("res://scripts/overgrowth.gd")
const CG := preload("res://scripts/corridor_growth.gd")
const CD := preload("res://scripts/corridor_decals.gd")
const BF := preload("res://scripts/building_floors.gd")
const Sway := preload("res://scripts/sway.gd")
const RG := preload("res://scripts/room_growth.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== growth test ===")
	await get_tree().process_frame
	WorldState.new_game()
	_test_library()
	_test_level()
	_test_corridor_plan()
	_test_corridor_nodes()
	_test_rooms()
	_test_balconies()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_library() -> void:
	print("[growth library]")
	var meta: Dictionary = CG.meta()
	check(meta.size() >= 40, "growth.json lists the sprites (%d)" % meta.size())
	var missing: Array = []
	for kind in CG.KINDS:
		for n in CG.KINDS[kind][2]:
			if not meta.has(n) or CG._tex(n) == null:
				missing.append(n)
	check(missing.is_empty(), "every sprite a kind can pick exists %s" % str(missing))
	var bad_pin: Array = []
	for n in meta:
		var k: String = meta[n]["kind"]
		# owner round 34: only leaves / drapes move — never a dead or dry plant, wall-bound ivy, a dense bush, roots, moss, fungus
		var moves: bool = Sway.GROWTH.has(k) and not ("dead" in n or "dry" in n)
		if moves != (meta[n]["pin"] != "none") or moves != not Sway.growth_spec(meta[n]).is_empty():
			bad_pin.append(n)
	check(bad_pin.is_empty(), "a sprite sways exactly when it has leaves or a drape and isn't dead / dry %s" % str(bad_pin))
	check(not Sway.GROWTH.has("creeper") and not Sway.GROWTH.has("shrub"), "wall-bound ivy and dense bushes are not in the moving kinds")
	for dead in ["pot_dead_8", "pot_dead_9", "tuft_dry_1", "creeper_dry_1", "shrub_dry_1"]:
		check(Sway.growth_spec(meta[dead]).is_empty(), "%s never sways (owner: a leafless plant swaying had 'no reason whatsoever')" % dead)
	check(not Sway.growth_spec(meta["pot_fern_1"]).is_empty() and not Sway.growth_spec(meta["hang_1"]).is_empty(), "a leafy pot and a hanging vine do")
	check(Sway.GROWTH["hang"]["pin"] == "top" and Sway.GROWTH["fern"]["pin"] == "bottom", "hanging vines pin at the top, the rest at the foot")


func _quiet_floors() -> Array:
	# floors with no fire in ANY run this seed, so the curve is the plain one
	var out: Array = []
	for f in range(1, 30):
		var burns := false
		for r in [1, 2, 3]:
			WorldState.current_run = r
			if WorldState.fire_intensity(f) >= 0:
				burns = true
		if not burns:
			out.append(f)
	WorldState.current_run = 1
	return out


func _test_level() -> void:
	print("[overgrowth level]")
	var floors := _quiet_floors()
	var runs_up := true
	var depth_up := true
	var in_range := true
	for seed_ in [3, 17, 91, 4242]:
		WorldState.master_seed = seed_
		var q := _quiet_floors()
		for f in q:
			var a: float = OG.level(f, 1)
			var b: float = OG.level(f, 2)
			var c: float = OG.level(f, 3)
			if not (a <= b and b <= c):
				runs_up = false
			for v in [a, b, c]:
				if v < 0.0 or v > 1.0:
					in_range = false
		var top := 0.0
		var bottom := 0.0
		var n_top := 0
		var n_bot := 0
		for f in q:
			if f >= 21:
				top += OG.level(f, 1)
				n_top += 1
			elif f <= 10:
				bottom += OG.level(f, 1)
				n_bot += 1
		if n_top > 0 and n_bot > 0 and not (top / n_top < bottom / n_bot):
			depth_up = false
	check(runs_up, "every floor is at least as overgrown each run (4 seeds)")
	check(depth_up, "the lower floors are more overgrown than the upper, from the first morning")
	check(in_range, "levels stay in 0..1")
	WorldState.master_seed = 4242
	var q2 := _quiet_floors()
	var top_f: int = q2.max()
	var low_f: int = q2.min()
	check(OG.level(top_f, 1) < 0.2, "the top of the building starts almost clear (floor %d: %.2f)" % [top_f, OG.level(top_f, 1)])
	check(OG.level(low_f, 3) > 0.8, "the bottom is choked by night (floor %d: %.2f)" % [low_f, OG.level(low_f, 3)])
	check(OG.level(30, 1) == 0.0 and OG.level(0, 1) == 0.0, "floor 30 and the lobby aren't overgrown")
	# owner round 33: "The overgrowth in the building should not set in till at least floor 12"
	var above := 0.0
	for f in range(13, 30):
		for r in [1, 2, 3]:
			above = maxf(above, OG.level(f, r))
	check(above == 0.0, "nothing wild grows above floor 12, any run (max %.2f)" % above)
	check(OG.level(12, 3) > 0.0 and OG.level(12, 1) < OG.level(1, 1), "it sets in at floor 12 and is worst at the bottom")
	check(OG.level(low_f, 2) == OG.level(low_f, 2), "a floor's level is deterministic")
	# flats: a spread of clear ↔ choked, stable
	var lo := 1.0
	var hi := 0.0
	var stable := true
	for a in range(1, 6):
		var id := "%d0%d" % [low_f, a]
		var v: float = OG.room_level(low_f, id, 2)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		if v != OG.room_level(low_f, id, 2):
			stable = false
	check(stable and hi > lo, "flats on one floor differ (%.2f .. %.2f) and are stable" % [lo, hi])
	# fire wins
	var burning := -1
	for seed_ in range(1, 400):
		WorldState.master_seed = seed_ * 31
		for f in range(2, 29):
			WorldState.current_run = 2
			if WorldState.fire_intensity(f) >= WorldState.FIRE_BLAZE and burning < 0:
				burning = f
		if burning > 0:
			break
	if burning > 0:
		WorldState.current_run = 2
		check(OG.level(burning, 2) == 0.0, "a burning / burnt floor grows nothing (floor %d)" % burning)
	else:
		check(false, "found a blazing floor to test against")
	WorldState.current_run = 1
	WorldState.master_seed = 4242
	check(OG.word(0.05) == "clear" and OG.word(0.9) == "choked", "levels have words")
	floors.clear()


func _test_corridor_plan() -> void:
	print("[corridor growth plan]")
	var subset := true
	var det := true
	var counts_up := true
	var inside := true
	var fixed_hit := ""
	var big_overlap := ""
	for seed_ in [5, 77, 2024]:
		WorldState.master_seed = seed_
		for f in [26, 18, 12, 7, 2]:
			var p1: Array = CG.plan(f, 1, BF.corridor_base_name(f))
			var p2: Array = CG.plan(f, 2, BF.corridor_base_name(f))
			var p3: Array = CG.plan(f, 3, BF.corridor_base_name(f))
			if p1.size() > p2.size() or p2.size() > p3.size():
				counts_up = false
			var names2 := {}
			for d in p2:
				names2[str(d["name"]) + str(d["pos"])] = true
			for d in p1:
				if not names2.has(str(d["name"]) + str(d["pos"])):
					subset = false
			var again: Array = CG.plan(f, 3, BF.corridor_base_name(f))
			if again.size() != p3.size():
				det = false
			var fixed: Array = CG._taken(f, BF.corridor_base_name(f))
			for d in p3:
				var tex: Texture2D = CG._tex(d["name"])
				var r := Rect2(d["pos"], tex.get_size())
				if r.position.x < CD.WALL_X.x - 1.0 or r.end.x > CD.WALL_X.y + 1.0 or r.position.y < 0.0 or r.end.y > 192.0:
					inside = false
				if d["kind"] not in ["tuft", "roots", "moss"] and CG._hits(fixed, r):
					fixed_hit = "%s@%s floor %d" % [d["name"], d["pos"], f]
	check(subset, "what grew in run 1 is still there in run 2 (only ever adds)")
	check(counts_up, "there is more each run")
	check(det, "a floor's growth is the same every time")
	check(inside, "everything sits inside the corridor art and between the stairwell casings")
	check(fixed_hit == "", "nothing but weeds and moss grows over a sign, lamp or the exit sign %s" % fixed_hit)
	WorldState.master_seed = 4242
	var q := _quiet_floors()
	var bot: int = q.min()
	var top: int = q.max()
	var pb: Array = CG.plan(bot, 3, BF.corridor_base_name(bot))
	var pt: Array = CG.plan(top, 1, BF.corridor_base_name(top))
	var kinds := {}
	for d in pb:
		kinds[d["kind"]] = true
	check(pb.size() >= 60, "the bottom floor by night is properly overgrown (%d things)" % pb.size())
	check(not kinds.has("shrub") and kinds.has("hang") and kinds.has("creeper") and kinds.has("fern") and kinds.has("tuft"),
		"…with ivy, hanging vines and ferns, not just weeds — and no shrubs (owner round 26) %s" % str(kinds.keys()))
	check(pt.size() <= 12, "the top floor's first morning is nearly clear (%d things)" % pt.size())


func _test_corridor_nodes() -> void:
	print("[corridor growth nodes]")
	WorldState.master_seed = 4242
	var q := _quiet_floors()
	var f: int = q.min()
	var root := Node2D.new()
	add_child(root)
	var decals := Node2D.new()
	decals.name = "CorridorDecals"
	root.add_child(decals)
	CG.add_to(root, f, 3, BF.corridor_base_name(f), Vector2(115, 243))
	var holder = root.get_node_or_null("CorridorGrowth")
	check(holder != null and holder.get_index() == decals.get_index() + 1, "growth is laid straight over the decals")
	var planned: Array = CG.plan(f, 3, BF.corridor_base_name(f))
	check(holder != null and holder.get_child_count() == planned.size(), "one sprite per planned item (%d)" % planned.size())
	var meta: Dictionary = CG.meta()
	var wrong: Array = []
	var pinned_top := 0
	for s in holder.get_children():
		var kind: String = String(meta.get(String(s.get_meta("growth", "")), {}).get("kind", ""))
		var should: bool = not Sway.growth_spec(meta.get(String(s.get_meta("growth", "")), {})).is_empty()
		if bool(s.get_meta("sway", false)) != should:
			wrong.append(String(s.get_meta("growth", "")))
		if should and s.material is ShaderMaterial and float(s.material.get_shader_parameter("pin_top")) > 0.5:
			pinned_top += 1
			if kind != "hang":
				wrong.append("top-pinned " + kind)
	check(wrong.is_empty(), "moving kinds sway, static ones don't %s" % str(wrong))
	check(pinned_top > 0, "hanging vines swing from the top (%d)" % pinned_top)
	# swaying sprites still stand where planned
	var off := false
	var by_key := {}
	for d in planned:
		by_key[str(d["name"]) + str(d["pos"])] = true
	for s in holder.get_children():
		var px: float = s.position.x + (float(Sway.PAD) if s.get_meta("sway", false) else 0.0)
		if not by_key.has(str(s.get_meta("growth", "")) + str(Vector2(px, s.position.y))):
			off = true
	check(not off, "…and each still stands exactly where the planner put it")
	root.free()


func _all_arts() -> Array:
	var out: Array = []
	for t in ["bedroom", "bathroom", "study", "kitchen", "living_room", "dining_room"]:
		for v in ["", "_b", "_c", "_d", "_e"]:
			out.append(t + v)
	return out


func _test_rooms() -> void:
	print("[room growth]")
	var arts := _all_arts()
	var bad_map: Array = []
	for a in arts:
		var m: Dictionary = RG.map_for(a)
		for k in ["up_floor", "up_wall", "down_ceil"]:
			if not (m.get(k) is Array) or (m[k] as Array).size() != 320:
				bad_map.append(a + ":" + k)
	check(bad_map.is_empty(), "all 30 module variants carry a growth map %s" % str(bad_map.slice(0, 4)))
	# furniture really shows up as blocked columns: not every column of every room is wide open
	var some_blocked := 0
	for a in arts:
		var uf: Array = RG.map_for(a).get("up_floor", [])
		for x in uf:
			if int(x) < 20:
				some_blocked += 1
				break
	check(some_blocked >= 25, "furniture blocks part of the floor in nearly every room (%d of 30)" % some_blocked)
	WorldState.master_seed = 4242
	var q := _quiet_floors()
	var f: int = q.min()
	var subset := true
	var det := true
	var margin := true
	var fit := true
	var counts_up := true
	for a in ["living_room", "bedroom_c", "kitchen_e", "study_b", "dining_room_d", "bathroom"]:
		for slot in range(3):
			var apt := "%d0%d" % [f, 2]
			var p1: Array = RG.plan(a, f, apt, slot, 1, false)
			var p2: Array = RG.plan(a, f, apt, slot, 2, false)
			var p3: Array = RG.plan(a, f, apt, slot, 3, false)
			if p1.size() > p2.size() or p2.size() > p3.size():
				counts_up = false
			var keys2 := {}
			for d in p2:
				keys2[str(d["name"]) + str(d["pos"])] = true
			for d in p1:
				if d["kind"] != "potted" and not keys2.has(str(d["name"]) + str(d["pos"])):
					subset = false
			if RG.plan(a, f, apt, slot, 3, false).size() != p3.size():
				det = false
			var m: Dictionary = RG.map_for(a)
			for d in p3:
				var tex: Texture2D = RG._tex(d["name"])
				var sz := tex.get_size()
				if d["pos"].x < RG.MARGIN - 1 or d["pos"].x + sz.x > 320 - RG.MARGIN + 1:
					margin = false
				var sky: Array = m.get(RG.FIT.get(d["kind"], "up_floor"), [])
				if d["kind"] == "potted":
					sky = m["up_floor"]
				if sky.size() == 320:
					# ivy / vines / moss / fungus need the full height bare; a standing plant its footing
					var need: int = int(sz.y * 0.75) - 1 if d["kind"] in ["creeper", "hang"] else (int(sz.y) - 1 if d["kind"] in ["moss", "fungus"] else RG.FOOTING)
					if RG.clear_over(sky, int(d["pos"].x), int(sz.x)) < need:
						fit = false
	check(subset, "what grew in a flat in run 1 is still there in run 2 (only ever adds)")
	check(counts_up and det, "there is more each run, and a module is the same every time")
	check(margin, "nothing grows in the outer columns the perspective walls cover")
	check(fit, "ivy and vines sit only on bare wall, and every standing plant has clear floor under it")
	var pb: Array = RG.plan("living_room", f, "%d02" % f, 1, 3, false)
	var pt: Array = RG.plan("living_room", 29, "2902", 1, 1, false)
	check(pb.size() >= 8, "a low flat by night is properly overgrown (%d things)" % pb.size())
	var wild := 0
	for d in pt:
		if d["kind"] != "potted":
			wild += 1
	check(wild <= 4, "a top flat's first morning has hardly any wild growth (%d)" % wild)
	# a balcony's doors keep the left of the module clear
	var left_clear := true
	for a in arts:
		for d in RG.plan(a, f, "%d02" % f, 0, 3, true):
			if d["pos"].x < RG.BALCONY_X - 1:
				left_clear = false
	check(left_clear, "a balcony slot's doors keep growth off the left of the module")
	# a burnt flat grows nothing
	var burnt := RG.plan("living_room", f, "%d02" % f, 1, 3, false, WorldState.FIRE_BLAZE)
	var wild_burnt := 0
	for d in burnt:
		if d["kind"] != "potted":
			wild_burnt += 1
	check(wild_burnt == 0, "a flat that has burnt grows nothing wild")
	# houseplants: alive at the top / early, dead lower down and later — and only ever in the OPEN (owner round 34: "an out of
	# place plant on a stool just randomly in front of other art items"), so only rooms with open wall can hold one
	var dead_top := 0
	var dead_low := 0
	var n_top := 0
	var n_low := 0
	var blocked: Array = []
	for art in ["bedroom_e", "dining_room_c", "kitchen_c", "bathroom_c", "living_room_b", "study_c"]:
		for seed_ in range(1, 40):
			WorldState.master_seed = seed_ * 977
			for slot in range(3):
				for f_run in [[28, 1], [3, 3]]:
					for d in RG.plan(art, f_run[0], "%d%02d" % [f_run[0], seed_], slot, f_run[1], false):
						if d["kind"] != "potted":
							continue
						var sz: Vector2 = RG._tex(d["name"]).get_size()
						var sky: Array = RG.map_for(art)["up_floor"]
						if RG.clear_over(sky, int(d["pos"].x), int(sz.x)) < int(sz.y):
							blocked.append("%s %s at x %d" % [art, d["name"], int(d["pos"].x)])
						if f_run[0] == 28:
							n_top += 1
							dead_top += 1 if String(d["name"]).contains("dead") else 0
						else:
							n_low += 1
							dead_low += 1 if String(d["name"]).contains("dead") else 0
	WorldState.master_seed = 4242
	check(blocked.is_empty(), "a houseplant's WHOLE height stands in clear space — never in front of furniture %s" % str(blocked.slice(0, 3)))
	check(n_top > 0 and n_low > 0, "flats keep houseplants (%d up top, %d low)" % [n_top, n_low])
	check(float(dead_low) / maxf(1.0, n_low) > float(dead_top) / maxf(1.0, n_top), "…and they die lower down and later (%d/%d vs %d/%d)" % [dead_low, n_low, dead_top, n_top])


func _test_balconies() -> void:
	print("[balcony plants]")
	WorldState.master_seed = 4242
	var q := _quiet_floors()
	var f: int = q.min()
	var top: int = q.max()
	var subset := true
	var inside := true
	var det := true
	var none_top := 0
	var some_top := 0
	var full_low := 0
	var seen := {}
	for seed_ in range(1, 41):
		WorldState.master_seed = seed_ * 613
		var apt := "%d0%d" % [top, 1 + seed_ % 5]
		var t1: Array = RG.balcony_plan(top, apt, seed_ % 3, 1)
		var t3: Array = RG.balcony_plan(top, apt, seed_ % 3, 3)
		if t1.is_empty():
			none_top += 1
		else:
			some_top += 1
		if t1.size() > t3.size():
			subset = false                                   # a slot filled in run 1 is still filled in run 3
		if RG.balcony_plan(top, apt, seed_ % 3, 1).size() != t1.size():
			det = false
		var lo: Array = RG.balcony_plan(f, "%d02" % f, seed_ % 3, 3)
		if lo.size() >= 3:
			full_low += 1
		for d in lo + t1:
			seen[str(d["name"])] = true
			var tex: Texture2D = RG._tex(d["name"])
			var r := Rect2(d["pos"], tex.get_size())
			if r.position.x < 8.0 or r.end.x > 96.0 or r.position.y < 14.0 or r.end.y > 100.0:
				inside = false
				print("    outside: %s at %s size %s" % [d["name"], d["pos"], tex.get_size()])
	WorldState.master_seed = 4242
	check(subset and det, "a balcony only ever gains plants through the day, and is the same every time")
	check(inside, "every balcony plant sits inside the loggia (x 8..96, y 14..100)")
	check(none_top > 0 and some_top > 0, "up top some balconies are bare and some are planted, so they read as distinct (%d bare / %d planted)" % [none_top, some_top])
	check(full_low >= 20, "low down by night most balconies are properly green (%d of 40)" % full_low)
	check(seen.size() >= 6, "the plants vary — shrubs, pots and vines (%d different sprites)" % seen.size())
	var no_big := true
	for n in seen:
		if String(n).begins_with("shrub_") and not String(n).begins_with("shrub_small"):
			no_big = false
	check(no_big, "only the SMALL shrubs are ever used")
