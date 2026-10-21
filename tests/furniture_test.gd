extends Node

# FURNITURE AS ASSETS (owner round 47) — the planner that lays a room's furniture from a seed (scripts/furniture_planner.gd), the library it draws from (data/furniture.json,
# assets/furniture/), the assembler that builds a plan into a room (scripts/room_furniture.gd) and the room code that chooses between a planned and a baked module.
#   "we do not ever need to have a bed in a kitchen" — the LOGIC is proven over thousands of seeded rooms, and each rule is proven to FAIL on a plan that breaks it.
# Run:  godot --headless res://tests/furniture_test.tscn

const RoomScript := preload("res://scripts/room.gd")
const BEDROOM_STYLES := ["adult", "teen", "sick", "refuge", "kid"]
const KITCHEN_STYLES := ["classic", "retro", "country", "student", "hoarder"]
const LIVING_STYLES := ["cosy", "mid", "squat", "parlour", "lodge"]
const DINING_STYLES := ["family", "diner", "formal", "barricade", "party"]
const STUDY_STYLES := ["den", "office", "library", "radio", "studio"]
const BATH_STYLES := ["tub", "avocado", "gilded", "wetroom", "pink"]
const PLANNED := {"bedroom": BEDROOM_STYLES, "kitchen": KITCHEN_STYLES, "living_room": LIVING_STYLES, "dining_room": DINING_STYLES, "study": STUDY_STYLES, "bathroom": BATH_STYLES}   # the room types the planner lays, and their styles
const UNPLANNED := []                                                                      # every room type is planned now
const SEEDS_PER_STYLE := 100

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== furniture test ===")
	await get_tree().process_frame
	WorldState.new_game()
	WorldState.is_first_run = false
	_test_library()
	_test_logic_table()
	_test_plans_obey_the_rules()
	_test_rules_can_fail()
	_test_variety_and_determinism()
	_test_needs()
	_test_reach()
	_test_room_choice()
	await _test_real_rooms("bedroom")
	await _test_real_rooms("kitchen")
	await _test_real_rooms("living_room")
	_test_living()
	await _test_real_rooms("dining_room")
	await _test_real_rooms("study")
	await _test_real_rooms("bathroom")
	_test_palette()
	_test_paired_pictures()
	_test_balcony()
	await _test_balcony_flats()
	_test_bathroom()
	await _test_story_flats_stay_baked()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------------------------------------------------------------------------ the library
func _test_library() -> void:
	print("[the library]")
	var d: Dictionary = FurniturePlanner.data()
	check(d.has("items") and d["items"].size() >= 60, "data/furniture.json lists the pieces (%d)" % d.get("items", {}).size())
	check(not d["items"].has("beanbag"), "the beanbag is gone (owner round 47b: hard to identify — a chair, a child's chair and a rocking horse took its place)")
	check(d["items"].has("chair_wood") and d["items"].has("chair_child") and d["items"]["rocking_horse"]["variants"].size() >= 12, "the chairs and the rocking horse (with its bloodied variant) are in the library")
	var boxed: Array = []
	var no_under: Array = []
	for bid in d["items"]:
		var brec: Dictionary = d["items"][bid]
		if not ("sleeping" in brec["tags"]):
			continue
		for bvid in brec["variants"]:
			if String(bvid).ends_with("_box"):
				boxed.append("%s/%s" % [bid, bvid])
			var has_under := false
			for a in brec["variants"][bvid]["anchors"]:
				if String(a["name"]) in ["underbed", "sleeping_bag", "quilt"] or String(bid) == "mattress_floor":
					has_under = true
			if not has_under and String(bid) != "mattress_floor":
				no_under.append("%s/%s" % [bid, bvid])
	check(boxed.is_empty(), "no bed has a box shoved under it any more %s" % str(boxed.slice(0, 3)))
	check(no_under.is_empty(), "every bed keeps a node to search without the box (the dark gap under it) %s" % str(no_under.slice(0, 3)))
	var missing: Array = []
	var no_buckets: Array = []
	var opens_missing: Array = []
	for id in d["items"]:
		var rec: Dictionary = d["items"][id]
		for vid in rec["variants"]:
			var sprites: Array = rec["variants"][vid]["sprites"]
			if sprites.is_empty():
				missing.append("%s/%s has no sprite" % [id, vid])
			for s in sprites:
				if not ResourceLoader.exists(FurniturePlanner.SPRITE_DIR + String(s["file"]) + ".png"):
					missing.append(String(s["file"]))
				if rec["bucketed"] and not s.has("bx"):
					no_buckets.append(String(s["file"]))
				if rec.get("opens", null) != null and not ResourceLoader.exists(FurniturePlanner.SPRITE_DIR + "open/" + String(s.get("open_file", "none")) + ".png"):
					opens_missing.append(String(s["file"]))
	check(missing.is_empty(), "every sprite a piece names exists %s" % str(missing.slice(0, 4)))
	check(no_buckets.is_empty(), "every leaning sprite knows its bucket x")
	check(opens_missing.is_empty(), "every opening piece has its open strip %s" % str(opens_missing.slice(0, 4)))
	for room in PLANNED:
		for style in PLANNED[room]:
			var r := FurniturePlanner.recipe(room, style)
			check(not r.is_empty(), "%s/%s has a recipe" % [room, style])
			check(ResourceLoader.exists(RoomScript.FURNITURE_SHELL_DIR + String(r.get("shell", "x")) + ".tscn"), "%s/%s: its shell scene exists" % [room, style])
			check(ResourceLoader.exists("res://assets/rooms/%s.png" % String(r.get("shell", "x"))), "%s/%s: its shell art exists" % [room, style])
			check(not r.get("fallback", []).is_empty(), "%s/%s: has a hand-set fallback layout" % [room, style])
	var only_planned := true
	for room in PLANNED:
		only_planned = only_planned and FurniturePlanner.handles(room)
	for room in UNPLANNED:
		only_planned = only_planned and not FurniturePlanner.handles(room)
	check(only_planned, "the planner lays exactly the room types in PLANNED (%s) and nothing else" % str(PLANNED.keys()))


# ------------------------------------------------------------------------------------------------------------------------------------ THE LOGIC
func _test_logic_table() -> void:
	print("[the logic table]")
	var rules: Dictionary = FurniturePlanner.data()["rules"]["tag_rooms"]
	check(rules.get("sleeping", []) == ["bedroom"], "a sleeping piece is a bedroom thing, only")
	check("kitchen" in rules.get("cooking", []) and not ("bedroom" in rules.get("cooking", [])), "cooking is for the kitchen")
	var bad: Array = []
	var beds := 0
	for id in FurniturePlanner.data()["items"]:
		var rec: Dictionary = FurniturePlanner.data()["items"][id]
		for t in rec["tags"]:
			if rules.has(t):
				for room in rec["rooms"]:
					if not (room in rules[t]):
						bad.append("%s (%s) in %s" % [id, t, room])
		if "sleeping" in rec["tags"]:
			beds += 1
			for room in ["kitchen", "bathroom", "study", "living_room", "dining_room"]:
				if FurniturePlanner.eligible(id, room, "adult") or FurniturePlanner.eligible(id, room, "kid"):
					bad.append("a bed (%s) is eligible for a %s" % [id, room])
	check(beds >= 5, "the library has beds (%d) — and none is eligible for a kitchen, bathroom, study, living room or dining room" % beds)
	check(bad.is_empty(), "no piece sits in a room its tags forbid %s" % str(bad.slice(0, 3)))
	# the runtime defence: even a piece MIS-registered for a kitchen is refused (the rules table is checked again at plan time)
	var items: Dictionary = FurniturePlanner.data()["items"]
	var saved: Dictionary = items["bed_wood"]["rooms"].duplicate()
	items["bed_wood"]["rooms"]["kitchen"] = 9.0
	check(not FurniturePlanner.eligible("bed_wood", "kitchen", "adult"), "a bed mis-registered for a kitchen is STILL refused at plan time")
	items["bed_wood"]["rooms"] = saved
	check(FurniturePlanner.eligible("bed_wood", "bedroom", "adult"), "…and is fine in the bedroom it belongs in")
	check(not FurniturePlanner.eligible("drip_stand", "bedroom", "kid") and FurniturePlanner.eligible("drip_stand", "bedroom", "sick"), "a drip stand is for the sick room, never the child's")
	check(not FurniturePlanner.eligible("rocking_horse", "bedroom", "sick") and FurniturePlanner.eligible("rocking_horse", "bedroom", "kid"), "a rocking horse is for the child's room, never the sick room")
	check(not FurniturePlanner.eligible("poster_gig", "bedroom", "kid") and FurniturePlanner.eligible("poster_gig", "bedroom", "teen"), "a gig poster is the teenager's")


# ------------------------------------------------------------------------------------------------------------------------------------ plans obey every rule
func _test_plans_obey_the_rules() -> void:
	print("[plans obey every rule — %d seeds per style, both window sides]" % SEEDS_PER_STYLE)
	var t0 := Time.get_ticks_msec()
	var total := 0
	for room in PLANNED:
		for style in PLANNED[room]:
			var broke: Array = []
			var fb := 0
			var few_front := 0
			var empty := 0
			var wrong := 0
			var seen_ids := {}
			var vanity_wrong := 0
			var vanity_seen := 0
			var n := 0
			for k in range(SEEDS_PER_STYLE):
				for side in ["left", "right"]:
					var pl := FurniturePlanner.plan(room, style, 7000 + k, {"window": side})
					n += 1
					if pl.is_empty():
						empty += 1
						continue
					if bool(pl["fallback"]):
						fb += 1
					var v := FurniturePlanner.validate(pl, {"window": side})
					if not v.is_empty():
						broke.append("seed %d %s: %s" % [7000 + k, side, str(v.slice(0, 2))])
					var front := 0
					for a in pl["anchors"]:
						if not bool(a["bp"]) and int(a["y"]) >= FurniturePlanner.FRONT_NODE_MIN_Y:
							front += 1
						if int(a["x"]) < 6 or int(a["x"]) > 314:
							broke.append("a node off the module (%d,%d)" % [int(a["x"]), int(a["y"])])
					if front < 2:
						few_front += 1
					if pl["anchors"].size() < 2:
						broke.append("fewer than 2 nodes")
					for it in pl["items"]:
						seen_ids[String(it["id"])] = true
						if room == "bedroom" and String(it["id"]) in ["jewel_box", "perfume_set", "hairbrush"]:           # a jewellery box / scent / brush stands on a dressing table or a chest of drawers, never a bookcase
							vanity_seen += 1
							var on_vanity := false
							for h in pl["items"]:
								if String(h["id"]) in ["dressing_table", "chest_drawers"] and int(it["x"]) >= int(h["x"]) and int(it["x"]) + int(it["w"]) <= int(h["x"]) + int(h["w"]) + 2:
									on_vanity = true
							if not on_vanity:
								vanity_wrong += 1
						if not FurniturePlanner.eligible(String(it["id"]), room, style):
							wrong += 1
					if String(pl["style"]) != style or String(pl["room"]) != room:
						wrong += 1
			if room == "bedroom":
				check(vanity_wrong == 0, "bedroom/%s: dressing-table things (%d placed) stand only on a dressing table or a chest of drawers (%d strays)" % [style, vanity_seen, vanity_wrong])
				if style == "adult":
					check(vanity_seen > 0, "bedroom/adult: the vanity check really sees jewellery boxes / scent / brushes (%d)" % vanity_seen)
			check(empty == 0, "%s/%s: every seed yields a plan" % [room, style])
			check(broke.is_empty(), "%s/%s: %d plans break no rule %s" % [room, style, n, str(broke.slice(0, 2))])
			check(wrong == 0, "%s/%s: every placed piece belongs in a %s %s (%d strays)" % [room, style, style, room, wrong])
			check(few_front == 0, "%s/%s: always at least 2 nodes reachable from the walking lane" % [room, style])
			check(float(fb) / float(n) < 0.05, "%s/%s: the hand-set fallback is the rare exception (%d of %d)" % [room, style, fb, n])
			check(seen_ids.size() >= 12, "%s/%s: draws on a real range of pieces (%d different)" % [room, style, seen_ids.size()])
			total += n
	print("  (%d plans in %.1f s)" % [total, (Time.get_ticks_msec() - t0) / 1000.0])
	# every fallback layout is itself valid (it must be safe for either window side)
	for room in PLANNED:
		for style in PLANNED[room]:
			for side in ["left", "right"]:
				var rcp := FurniturePlanner.recipe(room, style)
				var items: Array = []
				for e in rcp["fallback"]:
					var rec := FurniturePlanner.piece(String(e["id"]))
					items.append({"id": e["id"], "variant": e["variant"], "x": e["x"], "y": e["y"], "plane": rec["plane"], "host_plane": rec["plane"], "w": rec["w"]})
				var v := FurniturePlanner.validate({"room": room, "style": style, "items": items}, {"window": side})
				check(v.is_empty(), "%s/%s: the fallback layout is valid with the window on the %s %s" % [room, style, side, str(v)])


# ------------------------------------------------------------------------------------------------------------------------------------ every rule can FAIL
func _plan_of(style: String, entries: Array) -> Dictionary:
	var items: Array = []
	for e in entries:
		var rec := FurniturePlanner.piece(String(e[0]))
		items.append({"id": e[0], "variant": e[1], "x": e[2], "y": e[3], "plane": rec["plane"], "host_plane": String(e[4]) if e.size() > 4 else rec["plane"], "w": rec["w"]})
	return {"room": "bedroom", "style": style, "items": items}


func _violations(pl: Dictionary, side: String = "left") -> String:
	return str(FurniturePlanner.validate(pl, {"window": side}))


func _test_rules_can_fail() -> void:
	print("[each rule fails on a plan that breaks it]")
	var ok := _plan_of("adult", [["bed_wood", "l_sage", 110, 115], ["wardrobe_wood", "walnut", 268, 106]])
	check(FurniturePlanner.validate(ok, {"window": "left"}).is_empty(), "a sane layout passes (left window) %s" % str(FurniturePlanner.validate(ok, {"window": "left"})))
	var win := _plan_of("adult", [["wardrobe_wood", "walnut", 60, 106]])
	check("window" in _violations(win, "left"), "a wardrobe standing in front of the left window is refused")
	check(FurniturePlanner.validate(win, {"window": "right"}).is_empty(), "…and the same wardrobe is fine when the window is on the other side")
	var kitchen := {"room": "kitchen", "style": "adult", "items": ok["items"]}
	check("not allowed in a kitchen" in _violations(kitchen), "a bed in a kitchen is refused")
	var bath := {"room": "bathroom", "style": "adult", "items": _plan_of("adult", [["wardrobe_wood", "walnut", 200, 106]])["items"]}
	check("not allowed in a bathroom" in _violations(bath), "a wardrobe in a bathroom is refused")
	var wrong_style := _plan_of("kid", [["drip_stand", "clear", 200, 116]])
	check("not allowed" in _violations(wrong_style), "a drip stand in the child's room is refused")
	var overlap := _plan_of("adult", [["bed_wood", "l_sage", 110, 115], ["wardrobe_wood", "walnut", 200, 106]])
	check("overlaps" in _violations(overlap), "a wardrobe in the middle of the bed is refused (the wall line is exclusive)")
	var lane := _plan_of("adult", [["clothes_pile", "blue_red", 200, 130]])
	check("walking lane" in _violations(lane), "clothes dropped on the walking lane are refused")
	var stand := _plan_of("adult", [["nightstand_wood", "dark", 60, 106], ["bed_wood", "l_sage", 74, 115]])
	check("stand zone" in _violations(stand), "a bed pushed against a bedside table (over the spot the player steps up to) is refused")
	var dup := _plan_of("adult", [["wardrobe_wood", "walnut", 20, 106], ["wardrobe_wood", "oak", 200, 106]])
	check("limit" in _violations(dup, "right"), "a room with two wardrobes is refused (a piece's limit)")
	var off := _plan_of("adult", [["wardrobe_wood", "walnut", 300, 106]])
	check("leaves the module" in _violations(off), "a piece standing off the module's edge is refused")
	var floaty := _plan_of("adult", [["clothes_pile", "blue_red", 120, 118]])
	check(FurniturePlanner.validate(floaty, {"window": "left"}).is_empty(), "a pile of clothes on open floor is fine")


# ------------------------------------------------------------------------------------------------------------------------------------ variety + determinism
func _signature(pl: Dictionary) -> String:
	var parts: Array = []
	for it in pl["items"]:
		parts.append("%s:%s@%d,%d" % [it["id"], it["variant"], int(it["x"]), int(it["y"])])
	parts.sort()
	return "|".join(parts)


func _test_variety_and_determinism() -> void:
	print("[variety + determinism]")
	for room in PLANNED:
		for style in PLANNED[room]:
			var a := FurniturePlanner.plan(room, style, 31337, {"window": "left"})
			var b := FurniturePlanner.plan(room, style, 31337, {"window": "left"})
			check(_signature(a) == _signature(b) and a["anchors"].size() == b["anchors"].size(), "%s/%s: the same seed gives the same room, down to the pixel" % [room, style])
			var sigs := {}
			for k in range(40):
				var p := FurniturePlanner.plan(room, style, 500 + k, {"window": "left"})
				sigs[_signature(p)] = true
			check(sigs.size() >= 34, "%s/%s: 40 flats, %d different rooms — two of the same style are not the same room" % [room, style, sigs.size()])
	var w1 := FurniturePlanner.plan("bedroom", "adult", 4242, {"window": "left"})
	var w2 := FurniturePlanner.plan("bedroom", "adult", 4242, {"window": "right"})
	check(w1["items"].size() > 0 and w2["items"].size() > 0, "a different window side re-plans (the room works round its window)")
	var counts := {}
	for k in range(300):
		counts[FurniturePlanner.pick_style("bedroom", 900 + k)] = int(counts.get(FurniturePlanner.pick_style("bedroom", 900 + k), 0)) + 1
	var all_present := true
	for s in BEDROOM_STYLES:
		if not counts.has(s):
			all_present = false
	check(all_present and int(counts["adult"]) > int(counts["sick"]), "the room's style is seeded and weighted: all five turn up, the ordinary one most %s" % str(counts))
	check(FurniturePlanner.pick_style("bedroom", 1234) == FurniturePlanner.pick_style("bedroom", 1234), "a flat's style is stable")
	var kcounts := {}
	for k in range(300):
		kcounts[FurniturePlanner.pick_style("kitchen", 900 + k)] = int(kcounts.get(FurniturePlanner.pick_style("kitchen", 900 + k), 0)) + 1
	var kall := true
	for s in KITCHEN_STYLES:
		if not kcounts.has(s):
			kall = false
	check(kall and int(kcounts["classic"]) > int(kcounts["hoarder"]), "the kitchen's style is seeded and weighted too: all five turn up %s" % str(kcounts))


# ------------------------------------------------------------------------------------------------------------------------------------ needs: a desk wants its chair
func _test_needs() -> void:
	print("[needs]")
	var with_desk := 0
	var chairless := 0
	for k in range(200):
		var pl := FurniturePlanner.plan("bedroom", "teen", 11000 + k, {"window": "left" if k % 2 == 0 else "right"})
		var desk := false
		var seat := false
		for it in pl["items"]:
			if String(it["id"]) == "desk_crt":
				desk = true
			if "seat" in FurniturePlanner.piece(String(it["id"]))["tags"]:
				seat = true
		if desk:
			with_desk += 1
			if not seat:
				chairless += 1
	check(with_desk >= 100, "a teenager's room usually has its desk (%d of 200)" % with_desk)
	check(chairless == 0, "…and a desk is never without somewhere to sit (%d chairless)" % chairless)
	var rec := FurniturePlanner.piece("desk_crt")
	check(rec.get("needs", null) != null, "the desk's record carries the need")
	var lone_chairs := 0
	for style in BEDROOM_STYLES:
		for k in range(60):
			var pl := FurniturePlanner.plan("bedroom", style, 15000 + k, {"window": "left"})
			var has_desk := false
			var has_chair := false
			for it in pl["items"]:
				if String(it["id"]) == "desk_crt":
					has_desk = true
				if String(it["id"]) == "chair_office":
					has_chair = true
			if has_chair and not has_desk:
				lone_chairs += 1
	check(lone_chairs == 0 and bool(FurniturePlanner.piece("chair_office").get("companion_only", false)), "an office chair is only ever put beside a desk (%d lone chairs)" % lone_chairs)


# ------------------------------------------------------------------------------------------------------------------------------------ every node can be reached
func _test_reach() -> void:
	print("[every scavenge node can be reached]")
	# the grouping of set-back nodes into step-up spots (room.back_spot_groups)
	var wide: Array = []
	for i in range(6):
		wide.append(Vector2(300.0 + 35.0 * i, 300.0))               # a chain of nodes 35 px apart — one spot of the old chaining rule, 175 px wide
	var groups: Array = RoomScript.back_spot_groups(wide)
	var far := 0.0
	for g in groups:
		var cx := 0.0
		for i in g:
			cx += wide[i].x
		cx /= float(g.size())
		for i in g:
			far = maxf(far, Vector2(wide[i].x - cx, wide[i].y - 306.0).length())
	check(groups.size() > 1 and far <= RoomScript.BACK_SPOT_REACH, "a wide chain of nodes splits into spots the player can reach from the middle of each (%d spots, farthest %.1f px)" % [groups.size(), far])
	check(RoomScript.back_spot_groups([Vector2(300, 300), Vector2(320, 300)]).size() == 1, "two nodes of one piece still share one spot")
	check(RoomScript.back_spot_groups([Vector2(300, 300), Vector2(380, 300)]).size() == 2, "nodes further apart than a cluster never share one")
	check(RoomScript.back_spot_groups([Vector2(300, 300), Vector2(310, 300)])[0] == [0, 1], "the group is a list of indices into the sorted nodes")
	# every node of every planned room: not above the reach line, and reachable from its own spot
	var high := 0
	var unreachable := 0
	var spots := 0
	for room in PLANNED:
		for style in PLANNED[room]:
			for k in range(60):
				var pl := FurniturePlanner.plan(room, style, 21000 + k, {"window": "left" if k % 2 == 0 else "right"})
				var pts: Array = []
				for a in pl["anchors"]:
					if int(a["y"]) < FurniturePlanner.NODE_MIN_Y:
						high += 1
					if bool(a["bp"]):
						pts.append(Vector2(float(a["x"]), float(a["y"]) + 224.0))
				pts.sort_custom(func(p, q): return p.x < q.x)
				for g in RoomScript.back_spot_groups(pts):
					spots += 1
					var cx := 0.0
					for i in g:
						cx += pts[i].x
					cx /= float(g.size())
					for i in g:
						if Vector2(pts[i].x - cx, pts[i].y - 306.0).length() > 50.0:
							unreachable += 1
	check(high == 0, "no planned node sits above the reach line (y < %d)" % FurniturePlanner.NODE_MIN_Y)
	check(unreachable == 0 and spots > 100, "every set-back node of the planned rooms is within arm's length (50 px) of its spot's centre (%d spots, %d out of reach)" % [spots, unreachable])
	var high_node := _plan_of("adult", [["wardrobe_wood", "walnut", 120, 90]])
	check("out of reach" in _violations(high_node, "right"), "a piece whose node would hang above the reach line is refused")
	check(FurniturePlanner.validate(_plan_of("adult", [["wardrobe_wood", "walnut", 120, 106]]), {"window": "right"}).is_empty(), "…and the same wardrobe at its proper height passes")
	var tall := _plan_of("adult", [["wardrobe_wood", "walnut", 120, 106], ["suitcase", "tan", 123, 31, "wall"]])
	check(FurniturePlanner.validate(tall, {"window": "left"}).is_empty(), "a suitcase on a wardrobe is scenery and passes (it has no node to strand)")


# ------------------------------------------------------------------------------------------------------------------------------------ which rooms are planned
func _test_room_choice() -> void:
	print("[which rooms are planned, which stay baked]")
	WorldState.dev_seed = 20261020
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	var apt := "1503"
	var plain := RoomScript.furniture_plan_for(apt, 0, "bedroom", false, false)
	check(not plain.is_empty() and String(plain["shell"]).begins_with("bedroom_shell_"), "an ordinary flat's bedroom is planned")
	var plain_l := RoomScript.furniture_plan_for(apt, 0, "living_room", false, false)
	check(not plain_l.is_empty() and String(plain_l["shell"]).begins_with("living_shell_"), "an ordinary flat's living room is planned too")
	var plain_k := RoomScript.furniture_plan_for(apt, 0, "kitchen", false, false)
	check(not plain_k.is_empty() and String(plain_k["shell"]).begins_with("kitchen_shell_"), "an ordinary flat's kitchen is planned too")
	for room in UNPLANNED:
		check(RoomScript.furniture_plan_for(apt, 0, room, false, false).is_empty(), "a %s is still the baked module (no recipes yet)" % room)
	check(RoomScript.furniture_plan_for(apt, 0, "bedroom", true, false).is_empty(), "a BREACHED flat keeps its baked story")
	check(RoomScript.furniture_plan_for(apt, 0, "bedroom", false, true).is_empty(), "a BURNT flat keeps its baked husk")
	WorldState.is_first_run = true
	check(RoomScript.furniture_plan_for("3003", 2, "bedroom", false, false).is_empty(), "the tutorial's flats keep their scripted modules")
	WorldState.is_first_run = false
	check(not RoomScript.furniture_plan_for("3003", 2, "bedroom", false, false).is_empty(), "…the same flat is planned once the tutorial is over")
	# the furniture is a physical feature of the flat: the same room in every run (a flat whose room turns into a story room in a later run is the only exception)
	var same := 0
	var drift := 0
	for f in range(3, 28):
		for col in range(1, 6):
			var ap := "%d0%d" % [f, col]
			var sigs: Array = []
			for run in [1, 2, 3]:
				WorldState.current_run = run
				var p := RoomScript.furniture_plan_for(ap, 1, "bedroom", false, false)
				sigs.append(_signature(p) if not p.is_empty() else "")
			WorldState.current_run = 1
			if sigs[0] != "" and sigs[1] != "" and sigs[2] != "":
				if sigs[0] == sigs[1] and sigs[1] == sigs[2]:
					same += 1
				else:
					drift += 1
	check(same >= 80 and drift == 0, "the same bedroom in all three runs (%d flats checked, %d drifted)" % [same, drift])
	# a room that must be baked shows the old module of ITS OWN style (same wallpaper, same floor)
	var matched := 0
	var mism := 0
	for f in range(3, 28):
		var ap2 := "%d02" % f
		var plan := RoomScript.furniture_plan_for(ap2, 0, "bedroom", false, false)
		if plan.is_empty():
			continue
		var baked: String = RoomScript.baked_scene_for(ap2, 0, "bedroom")
		var want: String = RoomScript.MODULE_VARIANTS["bedroom"][int(FurniturePlanner.recipe("bedroom", String(plan["style"]))["legacy"])]
		if baked == want:
			matched += 1
		else:
			mism += 1
	check(matched >= 10 and mism == 0, "a baked bedroom is the old module of the planned style (%d flats, %d mismatches)" % [matched, mism])
	for rt in ["dining_room", "study", "bathroom"]:
		_check_baked_is_style_module(rt)
	var kmatched := 0
	var kmism := 0
	for f in range(3, 28):
		var kap := "%d02" % f
		var kplan := RoomScript.furniture_plan_for(kap, 0, "kitchen", false, false)
		if kplan.is_empty():
			continue
		var kbaked: String = RoomScript.baked_scene_for(kap, 0, "kitchen")
		if kbaked == RoomScript.MODULE_VARIANTS["kitchen"][int(FurniturePlanner.recipe("kitchen", String(kplan["style"]))["legacy"])]:
			kmatched += 1
		else:
			kmism += 1
	check(kmatched >= 10 and kmism == 0, "a baked kitchen is the old module of the planned style (%d flats, %d mismatches)" % [kmatched, kmism])
	var styles := {}
	var planned := 0
	var story := 0
	WorldState.current_run = 3                         # (the dead are likeliest in the last run: 22 % of the flats)
	for f in range(2, 29):
		for col in range(1, 6):
			var ap := "%d0%d" % [f, col]
			for slot in range(3):
				var p := RoomScript.furniture_plan_for(ap, slot, "bedroom", false, false)
				if p.is_empty():
					story += 1                    # the one room of a flat that holds one of the dead keeps its baked story
					continue
				planned += 1
				styles[String(p["style"])] = true
	WorldState.current_run = 1
	check(styles.size() == 5, "across a building every style of bedroom turns up (%s)" % str(styles.keys()))
	var lstyles := {}
	for f in range(2, 29):
		for col in range(1, 6):
			for slot in range(3):
				var lp := RoomScript.furniture_plan_for("%d0%d" % [f, col], slot, "living_room", false, false)
				if not lp.is_empty():
					lstyles[String(lp["style"])] = true
	check(lstyles.size() == 5, "…and every style of living room (%s)" % str(lstyles.keys()))
	var kstyles := {}
	for f in range(2, 29):
		for col in range(1, 6):
			for slot in range(3):
				var kp := RoomScript.furniture_plan_for("%d0%d" % [f, col], slot, "kitchen", false, false)
				if not kp.is_empty():
					kstyles[String(kp["style"])] = true
	check(kstyles.size() == 5, "…and every style of kitchen (%s)" % str(kstyles.keys()))
	check(story > 0 and story < planned / 4, "only the rooms that hold one of the dead stay baked (%d of %d)" % [story, story + planned])


# ------------------------------------------------------------------------------------------------------------------------------------ living rooms
func _test_living() -> void:
	print("[living rooms]")
	var sofaless := 0
	var table_alone := 0
	var tv_unhosted := 0
	var lodge_hearth := 0
	var lodge_n := 0
	var parlour_music := 0
	var parlour_n := 0
	var tables := 0
	var rooms := 0
	for style in LIVING_STYLES:
		for k in range(60):
			var pl := FurniturePlanner.plan("living_room", style, 21000 + k, {"window": "left" if k % 2 == 0 else "right"})
			rooms += 1
			var sofa := false
			var table := false
			var hearth := false
			var music := false
			for it in pl["items"]:
				var tags: Array = FurniturePlanner.piece(String(it["id"]))["tags"]
				if "sofa" in tags:
					sofa = true
				if String(it["id"]) == "coffee_table":
					table = true
				if "hearth" in tags:
					hearth = true
				if "music" in tags or "display" in tags:
					music = true
				if String(it["id"]) == "tv_crt" and not ("host_plane" in it and String(it["host_plane"]) == "wall"):
					tv_unhosted += 1
			if not sofa:
				sofaless += 1
			if table:
				tables += 1
				if not sofa:
					table_alone += 1
			if style == "lodge":
				lodge_n += 1
				if hearth:
					lodge_hearth += 1
			if style == "parlour":
				parlour_n += 1
				if music:
					parlour_music += 1
	check(sofaless == 0, "every living room has a sofa or a settee (%d of %d without)" % [sofaless, rooms])
	check(tables >= rooms / 2, "most living rooms have their coffee table in front of the sofa (%d of %d)" % [tables, rooms])
	check(table_alone == 0 and bool(FurniturePlanner.piece("coffee_table").get("companion_only", false)), "a coffee table is only ever put with a sofa (%d alone)" % table_alone)
	check(tv_unhosted == 0, "a CRT television only ever stands on something (%d on the floor)" % tv_unhosted)
	check(lodge_hearth >= lodge_n * 9 / 10, "the hunting lodge has its hearth (%d of %d)" % [lodge_hearth, lodge_n])
	check(parlour_music >= parlour_n * 9 / 10, "the parlour has its piano or its china cabinet (%d of %d)" % [parlour_music, parlour_n])
	check(int(FurniturePlanner.piece("coffee_table").get("lap", 6)) > 6 and FurniturePlanner.piece("rug_large").get("under", []).size() > 0, "the coffee table may overlap the sofa's front and the rug lies under the group (the record carries both)")
	# THE GUN CABINET'S living room is never planned: the cabinet is drawn into that baked module (and no other flat shows it)
	var cabinet_apts := 0
	var cabinet_planned := 0
	var cabinet_wrong := 0
	var cabinet_elsewhere := 0
	var cabinet_scene: String = WorldState.GUN_CABINET_SCENE
	for f in range(1, 25):
		for col in range(1, 6):
			var apt := "%d0%d" % [f, col]
			var layout: Array = WorldState.get_apartment_layout(apt)
			for slot in range(layout.size()):
				if layout[slot] != "living_room":
					continue
				var is_cab: bool = WorldState.gun_cabinet_slot(apt) == slot
				if is_cab:
					cabinet_apts += 1
					if not RoomScript.furniture_plan_for(apt, slot, "living_room", false, false).is_empty():
						cabinet_planned += 1
					if RoomScript.baked_scene_for(apt, slot, "living_room") != cabinet_scene:
						cabinet_wrong += 1
				elif RoomScript.baked_scene_for(apt, slot, "living_room") == cabinet_scene:
					cabinet_elsewhere += 1
	check(cabinet_apts >= 1 and cabinet_planned == 0 and cabinet_wrong == 0, "the gun cabinet's living room (%d flats) is never planned and stays the cabinet module" % cabinet_apts)
	check(cabinet_elsewhere == 0, "…and no other flat's story living room ever shows the cabinet (%d did)" % cabinet_elsewhere)
	# a baked living room (a story room) is the old module of its planned style — except the lodge, whose old module is the cabinet's
	var matched := 0
	var mism := 0
	for f in range(3, 25):
		var ap := "%d02" % f
		var plan := RoomScript.furniture_plan_for(ap, 0, "living_room", false, false)
		if plan.is_empty():
			continue
		var rcp: Dictionary = FurniturePlanner.recipe("living_room", String(plan["style"]))
		if int(rcp["legacy"]) < 0:
			continue
		if RoomScript.baked_scene_for(ap, 0, "living_room") == RoomScript.MODULE_VARIANTS["living_room"][int(rcp["legacy"])]:
			matched += 1
		else:
			mism += 1
	check(matched >= 6 and mism == 0, "a baked living room is the old module of the planned style (%d flats, %d mismatches)" % [matched, mism])


# ------------------------------------------------------------------------------------------------------------------------------------ colour harmony
## Owner round 47h: a colourway that would vanish into its room's wall (a rose armchair on rose wallpaper, an olive sofa under green paper, a green filing cabinet in the green den) is not used there
## (`not` in the variant's params, tools/art/furn_palette.py AVOID).
func _test_palette() -> void:
	print("[colour harmony]")
	var avoided := 0
	for id in FurniturePlanner.data()["items"]:
		var rec := FurniturePlanner.piece(String(id))
		for vid in rec["variants"]:
			avoided += (rec["variants"][vid].get("params", {}).get("not", []) as Array).size()
	check(avoided >= 8, "the data names the colourways a style does not use (%d style entries)" % avoided)
	var sofa := FurniturePlanner.piece("sofa")
	check(not FurniturePlanner.variant_ok(sofa, "olive", "cosy") and FurniturePlanner.variant_ok(sofa, "olive", "mid"), "the olive sofa is not used in the green cosy room, and still is in the mid one")
	var seen := 0
	var olive := 0
	var rose_on_rose := 0
	for k in range(120):
		for it in FurniturePlanner.plan("living_room", "cosy", 52000 + k, {"window": "left"})["items"]:
			if String(it["id"]) in ["sofa", "loveseat"]:
				seen += 1
				if String(it["variant"]) == "olive":
					olive += 1
		for it in FurniturePlanner.plan("living_room", "parlour", 53000 + k, {"window": "right"})["items"]:
			if String(it["id"]) == "armchair" and String(it["variant"]).contains("rose"):
				rose_on_rose += 1
	check(seen >= 60 and olive == 0, "120 cosy living rooms lay %d sofas / loveseats and none is the olive one (%d)" % [seen, olive])
	check(rose_on_rose == 0, "…and no rose armchair stands against the parlour's rose wallpaper (%d)" % rose_on_rose)
	var pl := FurniturePlanner.plan("living_room", "cosy", 52001, {"window": "left"})
	var forced := pl.duplicate(true)
	for it in forced["items"]:
		if String(it["id"]) == "sofa" or String(it["id"]) == "loveseat":
			var made := FurniturePlanner._make(String(it["id"]), "olive", int(it["x"]), int(it["y"]))
			if not made.is_empty():
				it["variant"] = "olive"
	var broke := false
	for msg in FurniturePlanner.validate(forced, {"window": "left"}):
		if String(msg).contains("olive"):
			broke = true
	check(broke, "validate() refuses an avoided colourway when one is forced in (the rule can fail)")


## Owner round 47h: "the picture of the ship and the picture of the flowers aren't the same size… one flower is not in the pot". The two pinned sheets of the studio's sketches are the same size,
## pinned at the same height, and every stem of the tulips ends inside the vase's mouth.
func _test_paired_pictures() -> void:
	print("[pictures hung as a pair]")
	var img: Image = load("res://assets/furniture/sketches_wall_sheets.png").get_image()
	var paper := Color8(0xf4, 0xf0, 0xe4)
	var runs: Array = []                                   # [x0, x1, y0, y1] of each run of paper-coloured columns
	var in_run := false
	var x0 := 0
	for x in range(img.get_width() + 1):
		var has := false
		if x < img.get_width():
			for y in range(0, 20):
				if img.get_pixel(x, y).is_equal_approx(paper):
					has = true
					break
		if has and not in_run:
			in_run = true
			x0 = x
		elif not has and in_run:
			in_run = false
			var y0 := 99
			var y1 := -1
			for xx in range(x0, x):
				for y in range(0, 20):
					if img.get_pixel(xx, y).is_equal_approx(paper):
						y0 = mini(y0, y)
						y1 = maxi(y1, y)
			runs.append([x0, x - 1, y0, y1])
	check(runs.size() == 2, "the sketches are two sheets (%s)" % str(runs))
	if runs.size() == 2:
		var a: Array = runs[0]
		var b: Array = runs[1]
		check(int(a[1]) - int(a[0]) == int(b[1]) - int(b[0]), "…the same width (%d and %d)" % [int(a[1]) - int(a[0]) + 1, int(b[1]) - int(b[0]) + 1])
		check(int(a[3]) - int(a[2]) == int(b[3]) - int(b[2]) and int(a[2]) == int(b[2]), "…the same height, hung at the same height (rows %d-%d and %d-%d)" % [int(a[2]), int(a[3]), int(b[2]), int(b[3])])
		# the tulips' green stems: every one of them stands over the vase (a blue run of pixels at the mouth), not beside it
		var stems_outside := 0
		var stems := 0
		var mouth_row := -1
		for y in range(int(b[2]), int(b[3]) + 1):
			var blue := 0
			for x in range(int(b[0]), int(b[1]) + 1):
				var c := img.get_pixel(x, y)
				if c.b > c.r + 0.25 and c.b > 0.5 and c.a > 0.5:
					blue += 1
			if blue >= 7 and mouth_row < 0:
				mouth_row = y
		check(mouth_row > 0, "the tulips' vase is found (its mouth is on sheet row %d)" % (mouth_row - int(b[2])))
		if mouth_row > 0:
			var mx0 := 999
			var mx1 := -1
			for x in range(int(b[0]), int(b[1]) + 1):
				var c := img.get_pixel(x, mouth_row)
				if c.b > c.r + 0.25 and c.b > 0.5 and c.a > 0.5:
					mx0 = mini(mx0, x)
					mx1 = maxi(mx1, x)
			for x in range(int(b[0]), int(b[1]) + 1):
				var c2 := img.get_pixel(x, mouth_row - 1)                  # the row just above the mouth: stems only
				if c2.g > c2.r + 0.15 and c2.g > c2.b and c2.a > 0.5:
					stems += 1
					if x < mx0 or x > mx1:
						stems_outside += 1
			check(stems >= 3 and stems_outside == 0, "…and every tulip stem enters the vase's mouth (%d stems, %d beside it)" % [stems, stems_outside])


# ------------------------------------------------------------------------------------------------------------------------------------ balconies and bathrooms
## A story room (breached / burnt / holding the dead) of a planned type shows the OLD module of the style its flat's room would have had.
func _check_baked_is_style_module(rt: String) -> void:
	var matched := 0
	var mism := 0
	for f in range(3, 28):
		for col in range(1, 6):
			var ap := "%d0%d" % [f, col]
			var slot: int = WorldState.get_apartment_layout(ap).find(rt)
			if slot < 0:
				continue
			var plan := RoomScript.furniture_plan_for(ap, slot, rt, false, false)
			if plan.is_empty():
				continue
			var rcp: Dictionary = FurniturePlanner.recipe(rt, String(plan["style"]))
			if int(rcp["legacy"]) < 0:
				continue
			if RoomScript.baked_scene_for(ap, slot, rt) == RoomScript.MODULE_VARIANTS[rt][int(rcp["legacy"])]:
				matched += 1
			else:
				mism += 1
	check(matched >= 20 and mism == 0, "a baked %s is the old module of the planned style (%d flats, %d mismatches)" % [rt, matched, mism])


## A study / dining room on a BALCONY slot keeps x 4..96 clear (the doors go in the back wall there): nothing stands, lies or hangs in it, whatever the style.
func _test_balcony() -> void:
	print("[balcony slots]")
	var box := FurniturePlanner.balcony_box()
	var bad := 0
	var rooms := 0
	var fallbacks := 0
	for room in ["dining_room", "study"]:
		for style in PLANNED[room]:
			for k in range(40):
				var ctx := {"window": "", "blocked": [box]}
				var pl := FurniturePlanner.plan(room, style, 33000 + k, ctx)
				rooms += 1
				if bool(pl.get("fallback", false)):
					fallbacks += 1
				if not FurniturePlanner.validate(pl, ctx).is_empty():
					bad += 1
				for it in pl["items"]:
					if String(it["plane"]) in ["rug", "ceiling"]:
						continue
					var rect: Rect2 = Rect2(float(it["x"]), float(it["y"]), 1.0, 1.0)
					var rec := FurniturePlanner.piece(String(it["id"]))
					var info := FurniturePlanner._make(String(it["id"]), String(it["variant"]), int(it["x"]), int(it["y"]))
					if not info.is_empty() and (info["rect"] as Rect2).intersects(box):
						bad += 1
	check(bad == 0, "%d balcony-slot plans (dining + study, every style): nothing in the doorway's box (%d problems)" % [rooms, bad])
	check(fallbacks <= rooms / 20, "…and the seeded layouts almost never need the fallback there (%d of %d)" % [fallbacks, rooms])
	for room in ["dining_room", "study"]:
		for style in PLANNED[room]:
			var fb: Array = FurniturePlanner.recipe(room, style)["fallback"]
			var items: Array = []
			for e in fb:
				items.append({"id": e["id"], "variant": e["variant"], "x": e["x"], "y": e["y"]})
			var plan := {"room": room, "style": style, "items": items}
			check(FurniturePlanner.validate(plan, {"window": "", "blocked": [box]}).is_empty(), "%s/%s: the fallback layout is valid on a balcony slot too" % [room, style])


func _test_balcony_flats() -> void:
	print("[balcony flats]")
	var checked := 0
	var clear_ok := true
	var shown_ok := true
	for f in [25, 22, 19, 16, 13, 10, 7, 4]:
		for col in range(1, 6):
			if checked >= 4:
				break
			var apt := "%d0%d" % [f, col]
			WorldState.dev_seed = 20261020
			WorldState.new_game()
			WorldState.dev_seed = 0
			WorldState.is_first_run = false
			WorldState.current_run = 1
			var bs := WorldState.balcony_slot_in_apartment(apt)
			if bs < 0:
				continue
			var layout: Array = WorldState.get_apartment_layout(apt)
			if WorldState.get_door_state(apt) == WorldState.DoorState.BREACHED or WorldState.is_apartment_charred(f, col):
				continue
			var plan := RoomScript.furniture_plan_for(apt, bs, String(layout[bs]), false, false)
			if plan.is_empty():
				continue
			var room = await _build_flat(apt)
			checked += 1
			for m in get_tree().get_nodes_in_group("room_module"):
				if not String(m.scene_file_path).begins_with("res://scenes/Room_Shells/"):
					continue
				var bal = m.get_node_or_null("Balcony")
				if bal == null:
					continue
				var idx: int = int(round((m.position.x - RoomScript.LEFT_WALL_X) / RoomScript.MODULE_WIDTH))
				if idx == bs:
					shown_ok = shown_ok and bal.visible
					for c in m.get_children():
						if c is Sprite2D and c.has_meta("furniture") and c.visible and c.name != "Art":
							var r := Rect2(c.position, c.texture.get_size() if c.texture != null else Vector2.ZERO)
							if r.intersects(FurniturePlanner.balcony_box()) and String(c.get_meta("plane", "")) not in ["rug", "ceiling"]:
								clear_ok = false
			room.free()
			await get_tree().process_frame
	check(checked >= 2, "built %d real balcony flats with a planned study / dining room" % checked)
	check(shown_ok, "the balcony doors are shown on a balcony slot's shell")
	check(clear_ok, "…and no furniture sprite stands in their box")


func _test_bathroom() -> void:
	print("[bathrooms]")
	var no_toilet := 0
	var no_basin := 0
	var no_bath := 0
	var no_washer := 0
	var rooms := 0
	for style in BATH_STYLES:
		for k in range(50):
			var pl := FurniturePlanner.plan("bathroom", style, 41000 + k, {"window": "left" if k % 2 == 0 else "right"})
			rooms += 1
			var toilet := false
			var basin := false
			var bath := false
			var washer := false
			for it in pl["items"]:
				var tags: Array = FurniturePlanner.piece(String(it["id"]))["tags"]
				if "laundry" in tags and "wet" in tags:
					washer = true
				if "toilet" in tags:
					toilet = true
				if "basin" in tags:
					basin = true
				if "bath" in tags:
					bath = true
			if not toilet:
				no_toilet += 1
			if not basin and style != "wetroom":                        # the squalid wetroom may have lost its basin (it has its washing machine instead)
				no_basin += 1
			if style == "wetroom" and not washer:
				no_washer += 1
			if not bath:
				no_bath += 1
	check(no_toilet <= rooms / 25, "a bathroom has its toilet (%d of %d without)" % [no_toilet, rooms])
	check(no_basin <= rooms / 25, "…and its basin (%d without)" % no_basin)
	check(no_bath == 0, "…and always the bath it is built round (%d without)" % no_bath)
	check(no_washer == 0, "…and the wetroom always has its washing machine (%d without)" % no_washer)
	var rules: Dictionary = FurniturePlanner.data().get("rules", {}).get("tag_rooms", {})
	check(rules.get("toilet", []) == ["bathroom"], "a toilet is a bathroom thing, only")


# ------------------------------------------------------------------------------------------------------------------------------------ real rooms
func _build_flat(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = int(apt.left(apt.length() - 2))
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	for i in range(4):
		await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.queue_free()
	return room


func _test_real_rooms(rtype: String) -> void:
	print("[real %s rooms]" % rtype)
	var found := 0
	var opened_seen := false
	var anchors_ok := true
	var sprites_ok := true
	var lights_ok := true
	var no_bed_elsewhere := true
	var checked := 0
	for f in [25, 20, 14, 9, 6, 22, 17, 11, 4, 27, 19]:
		for col in range(1, 6):
			if found >= 6 and opened_seen:
				break
			var apt := "%d0%d" % [f, col]
			WorldState.dev_seed = 20261020            # a fixed building, so the same flats are checked every time
			WorldState.new_game()
			WorldState.dev_seed = 0
			WorldState.is_first_run = false
			WorldState.current_run = 2
			var layout: Array = WorldState.get_apartment_layout(apt)
			if not (rtype in layout):
				continue
			if WorldState.get_door_state(apt) == WorldState.DoorState.BREACHED or WorldState.is_apartment_charred(f, col):
				continue
			var slot: int = layout.find(rtype)
			var dead: Dictionary = WorldState.apartment_corpse(apt)
			if not dead.is_empty() and int(dead["slot"]) == slot:
				continue
			if rtype == "living_room" and WorldState.gun_cabinet_slot(apt) == slot:
				continue                                        # the gun cabinet's living room is baked (checked in _test_living)
			var room = await _build_flat(apt)
			checked += 1
			var plan := RoomScript.furniture_plan_for(apt, slot, rtype, false, false)
			for m in get_tree().get_nodes_in_group("room_module"):
				var is_shell: bool = String(m.scene_file_path).begins_with("res://scenes/Room_Shells/")
				var label = m.get_node_or_null("ColorRect/Label")
				var rt: String = String(label.text).to_lower().replace(" ", "_") if label != null else ""
				var n_sprites := 0
				var n_anchors := 0
				var n_bp := 0
				for c in m.get_children():
					if c is Sprite2D and c.has_meta("furniture"):
						n_sprites += 1
						if not (rt in PLANNED):
							no_bed_elsewhere = false
					elif c is Marker2D:
						n_anchors += 1
						if c.has_meta("back_plane"):
							n_bp += 1
				if rt == rtype and is_shell:
					found += 1
					sprites_ok = sprites_ok and n_sprites == plan["items"].size()
					anchors_ok = anchors_ok and n_anchors == plan["anchors"].size()
					var lights = m.get_node_or_null("Lights")
					lights_ok = lights_ok and ((lights != null and lights.get_child_count() == plan["lights"].size()) or (lights == null and plan["lights"].is_empty()))
					check(String(m.scene_file_path).ends_with(String(plan["shell"]) + ".tscn"), "%s: the %s is the %s shell" % [apt, rtype, plan["shell"]])
					for c in m.get_children():
						if c is Sprite2D and String(c.name).begins_with("Open_"):
							opened_seen = true
							var anchor := m.get_node_or_null(String(c.name).substr(5))
							check(anchor != null, "%s: %s has the node it opens for" % [apt, c.name])
							check(not c.visible, "%s: %s is shut until it is searched" % [apt, c.name])
							c.play()
							check(c.visible, "%s: %s opens when played" % [apt, c.name])
				elif rt == rtype and not is_shell:
					check(false, "%s: a plain flat's %s must be the planned shell, got %s" % [apt, rtype, m.scene_file_path])
			room.free()
			await get_tree().process_frame
	check(found >= 4, "built %d real planned %s rooms (%d flats)" % [found, rtype, checked])
	check(sprites_ok, "each room has a sprite for every item of its plan")
	check(anchors_ok, "each room has a scavenge node for every anchor of its plan")
	check(lights_ok, "each room has a light for every fixture of its plan")
	check(no_bed_elsewhere, "furniture sprites are only ever laid in rooms the planner handles (no planned piece in any other room)")
	check(opened_seen, "at least one planned %s has a piece that opens when searched" % rtype)


func _test_story_flats_stay_baked() -> void:
	print("[story flats stay baked]")
	# a BREACHED flat's bedroom is still its legacy module, with the nest overlays that tell its story
	for f in [12, 18, 7]:
		for col in range(1, 6):
			var apt := "%d0%d" % [f, col]
			WorldState.new_game()
			WorldState.is_first_run = false
			var layout: Array = WorldState.get_apartment_layout(apt)
			if not ("bedroom" in layout):
				continue
			WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
			var room = await _build_flat(apt)
			var all_baked := true
			for m in get_tree().get_nodes_in_group("room_module"):
				if String(m.scene_file_path).begins_with("res://scenes/Room_Shells/"):
					all_baked = false
			check(all_baked, "%s (breached): no module is a planned shell" % apt)
			room.free()
			await get_tree().process_frame
			return
