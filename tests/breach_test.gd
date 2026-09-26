extends Node

# BREACH ROOMS (owner round 21): a LEADER per room (big / crawler nest / long-arm / spitter) that
# carries the key; nest crawlers clinging to the walls + ceiling that drop on you; the room itself a
# story told across the flat (entry struggle → drag trail → the dead at the far end, round 21b); the
# long arm drawn smaller so its swing lands.
#   godot --headless res://tests/breach_test.tscn

const RoomScript := preload("res://scripts/room.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== breach room test ===")
	WorldState.dev_seed = 5151
	WorldState.new_game()
	WorldState.is_first_run = false
	_test_leaders()
	_test_listen()
	_test_nest_art()
	await _test_rooms()
	await _test_wall_crawlers()
	await _test_longarm()
	WorldState.dev_seed = 0
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _find(kind: String) -> String:
	# never on a gun cabinet's floor: breaching a flat there can make it the cabinet's key room
	for f in range(4, 27):
		if not WorldState.gun_cabinets_on_floor(f).is_empty():
			continue
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			if WorldState.cabinet_for_key_room(apt) == "" and WorldState.breach_leader(apt) == kind:
				return apt
	return ""


func _test_leaders() -> void:
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var seen := {}
		for f in range(2, 29):
			for i in range(1, 6):
				var apt := str(f) + "0" + str(i)
				if WorldState.cabinet_for_key_room(apt) == "":
					seen[WorldState.breach_leader(apt)] = true
		if run == 1:
			check(seen.has("big") and seen.has("crawlers") and seen.has("longarm"), "run 1: big / crawler nest / long-arm leaders (%s)" % str(seen.keys()))
			check(not seen.has("spitter"), "run 1: no spitter leaders (outside the gun cabinet's key room)")
		else:
			check(seen.size() == 4, "run %d: all four leaders turn up (%s)" % [run, str(seen.keys())])
	WorldState.current_run = 2
	var nest := _find("crawlers")
	check(nest != "", "found a crawler nest")
	if nest != "":
		check(WorldState.breach_leader(nest) == WorldState.breach_leader(nest), "a room's leader is stable")
		var all_crawl := true
		var walls := 0
		for i in range(WorldState.get_breached_room_enemies(nest, 150.0, 1030.0, 321.0).size()):
			if WorldState.breach_slot_type(nest, i) != "crawler":
				all_crawl = false
			if WorldState.breach_on_wall(nest, i):
				walls += 1
		check(all_crawl, "a nest is all crawlers")
		check(not WorldState.breach_on_wall(nest, 0), "its leader never starts up the wall")
	var big := _find("big")
	check(big != "" and WorldState.breach_slot_type(big, 0) == "big" and WorldState.breach_slot_type(big, 1) == "standard",
		"a big-zombie room: the big leads, standards follow")


func _test_listen() -> void:
	WorldState.current_run = 2
	for kind in ["big", "crawlers", "longarm", "spitter"]:
		var apt := _find(kind)
		if apt == "":
			check(false, "a %s room to listen at" % kind)
			continue
		WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
		var r: Dictionary = WorldState.get_listen_report_for_apartment(apt)
		check(r["has_big"] and r["line"] == WorldState.BREACH_LISTEN_LINES[kind], "listening at a %s room: \"%s\"" % [kind, r["line"]])
		WorldState.killed_zombies[WorldState.breach_leader_key(apt)] = {"x": 0, "y": 0, "floor": 0, "scene": "room", "apartment_id": apt, "type": "standard"}
		check(not WorldState.get_listen_report_for_apartment(apt)["has_big"], "...and once its leader's dead, no leader in there")
		WorldState.killed_zombies.erase(WorldState.breach_leader_key(apt))


func _room(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	WorldState.set_door_state(apt, WorldState.DoorState.BREACHED)
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _test_nest_art() -> void:
	# every module variant has all six story roles, each with its flies in nest_meta.json
	check(RoomScript.breach_nest_role("left", 0) == "entry_l" and RoomScript.breach_nest_role("left", 2) == "lair_l", "door left: entry at slot 0, lair at 2")
	check(RoomScript.breach_nest_role("right", 2) == "entry_r" and RoomScript.breach_nest_role("right", 0) == "lair_r", "door right: entry at slot 2, lair at 0")
	check(RoomScript.breach_nest_role("left", 1) == "through_l" and RoomScript.breach_nest_role("right", 1) == "through_r", "the middle room is dragged through")
	var meta := RoomScript.nest_meta()
	var missing := []
	var n := 0
	for t in RoomScript.MODULE_VARIANTS:
		for scene_path in RoomScript.MODULE_VARIANTS[t]:
			var inst = load(scene_path).instantiate()
			var art = inst.get_node_or_null("Art")
			var base: String = art.texture.resource_path.get_basename() if art != null and art.texture != null else ""
			inst.free()
			for role in ["entry_l", "through_l", "lair_l", "entry_r", "through_r", "lair_r"]:
				var p: String = base + "_nest_" + role + ".png"
				n += 1
				if not ResourceLoader.exists(p) or not meta.has(p.get_file().get_basename()):
					missing.append(p.get_file())
			if base != "" and ResourceLoader.exists(base + "_nest.png"):
				missing.append("stale " + base + "_nest.png")
	check(n == 180 and missing.is_empty(), "180 story overlays, each with its fly spots (%d, missing %s)" % [n, str(missing.slice(0, 4))])
	var lair_flies := 0
	for k in meta:
		if str(k).contains("_lair_") and not meta[k].get("flies", []).is_empty():
			lair_flies += 1
	check(lair_flies == 60, "flies gather over the dead in every lair (%d/60)" % lair_flies)


func _test_rooms() -> void:
	WorldState.current_run = 2
	for kind in ["big", "crawlers", "longarm", "spitter"]:
		var apt := _find(kind)
		if apt == "":
			continue
		var room := _room(apt)
		for i in range(4):
			await get_tree().process_frame
		var carriers := []
		var bigs := 0
		for z in get_tree().get_nodes_in_group("zombie"):
			if z.get("drops_key") == true:
				carriers.append(z)
			if z.get_script() == load("res://scripts/enemy_zombie_big.gd"):
				bigs += 1
		check(carriers.size() == 1, "%s room: exactly one enemy carries the key (%d)" % [kind, carriers.size()])
		if carriers.size() == 1:
			var c = carriers[0]
			check(c.key_target_apartment == WorldState.breach_key_target(apt), "%s room: it carries the room's key" % kind)
			match kind:
				"big":
					check(c.get_script() == load("res://scripts/enemy_zombie_big.gd"), "big room: the big leads")
				"crawlers":
					check(c.is_in_group("crawler") and c.is_in_group("breach_leader"), "nest: a crawler leads")
				"longarm":
					check(c.is_in_group("longarm") and c.is_in_group("breach_leader"), "a long-arm leads")
				"spitter":
					check(c.is_in_group("spitter") and c.spit_damage == 2, "a spitter leads, spitting for 2")
			if kind != "big":
				check(c.modulate != Color.WHITE, "%s leader: its darker look" % kind)
		if kind != "big":
			check(bigs == 0, "%s room: no big zombie" % kind)
		# the NEST tells one story across the flat: ENTRY by the front door, THROUGH, LAIR at the far end
		var nests := get_tree().get_nodes_in_group("breach_nest")
		check(nests.size() == 3, "%s room: a nest overlay on all three modules (%d)" % [kind, nests.size()])
		var side := "_l" if WorldState.get_entrance_side(apt) == "left" else "_r"
		var by_x := nests.duplicate()
		by_x.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
		var want := ["entry", "through", "lair"] if side == "_l" else ["lair", "through", "entry"]
		var story_ok := by_x.size() == 3
		for i in range(by_x.size()):
			var n = by_x[i]
			var role: String = want[i] + side
			if str(n.get_meta("role", "")) != role or n.texture == null \
					or not n.texture.resource_path.ends_with("_nest_" + role + ".png"):
				story_ok = false
		check(story_ok, "...the entry room is the front door's, the lair the far end (door %s)" % side)
		var anims := get_tree().get_nodes_in_group("breach_nest_anim")
		var kinds := {}
		for a in anims:
			kinds[str(a.get_meta("kind"))] = true
		check(kinds.has("flies") and not kinds.has("drip"), "...flies where the art puts them, no blood raining from the ceiling")
		room.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	# an ordinary flat has none of it
	var quiet := ""
	for f in range(4, 27):
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			if WorldState.get_door_state(apt) != WorldState.DoorState.BREACHED:
				quiet = apt
				break
		if quiet != "":
			break
	WorldState.current_apartment_id = quiet
	WorldState.current_floor = WorldState._apartment_floor(quiet)
	var r2 = load("res://scenes/room.tscn").instantiate()
	add_child(r2)
	for i in range(3):
		await get_tree().process_frame
	check(get_tree().get_nodes_in_group("breach_nest").is_empty(), "an ordinary flat: no nest")
	r2.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_wall_crawlers() -> void:
	WorldState.current_run = 2
	var apt := ""
	for f in range(4, 27):
		if not WorldState.gun_cabinets_on_floor(f).is_empty():
			continue
		for i in range(1, 6):
			var a := str(f) + "0" + str(i)
			if WorldState.cabinet_for_key_room(a) == "" and WorldState.breach_leader(a) == "crawlers":
				var n := 0
				for s in range(WorldState.get_breached_room_enemies(a, 150.0, 1030.0, 321.0).size()):
					if WorldState.breach_on_wall(a, s):
						n += 1
				if n >= 2:
					apt = a
					break
		if apt != "":
			break
	check(apt != "", "a crawler nest with two or more on the walls")
	if apt == "":
		return
	for k in WorldState.zombie_positions.keys():
		if String(k).begins_with(str(WorldState._apartment_floor(apt)) + ":"):
			WorldState.zombie_positions.erase(k)
	# leave while they're still up there: each is remembered on its FLOOR line, never in the air
	var room := _room(apt)
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position.x = 1200.0          # well away from them
	for i in range(3):
		await get_tree().process_frame
	var mem_floor: float = 308.0                    # room.ROOM_BIG_ORIGIN_Y (memory is room-local)
	var left_keys := []
	for z in get_tree().get_nodes_in_group("wall_crawler"):
		left_keys.append(z.spawn_key)
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var mem_ok := not left_keys.is_empty()
	for k in left_keys:
		if not WorldState.zombie_positions.has(k) or absf(float(WorldState.zombie_positions[k]["y"]) - mem_floor) > 1.5:
			mem_ok = false
	check(mem_ok, "crawlers left on the walls are remembered on the floor, not in the air (%d)" % left_keys.size())
	for k in left_keys:
		WorldState.zombie_positions.erase(k)
	# back in, fresh
	room = _room(apt)
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.global_position.x = 1200.0
	for i in range(3):
		await get_tree().process_frame
	var up: Array = get_tree().get_nodes_in_group("wall_crawler")
	check(up.size() >= 2, "crawlers are up on the walls / ceiling when you walk in (%d)" % up.size())
	var floor_y: float = room.global_position.y + 308.0     # room.ROOM_BIG_ORIGIN_Y, in the room's own space
	var off_plane := true
	for z in up:
		if z.global_position.y > floor_y - 25.0 or z.get_collision_layer_value(1):
			off_plane = false
	check(off_plane, "...up off the floor, no body collision (they can't block or be blocked)")
	# a hit brings one straight down onto its floor line
	var hit = up[0]
	hit.receive_damage(0, "blunt")
	check(absf(hit.global_position.y - floor_y) < 1.0 and not hit.is_in_group("wall_crawler"), "a hit drops it onto the floor line (%.1f)" % hit.global_position.y)
	# walking under one sets it off: it twitches, drops, lands on the line and is solid-capable again
	if up.size() >= 2 and player != null:
		var z2 = up[1]
		player.global_position.x = z2.global_position.x
		var landed := false
		for i in range(150):
			await get_tree().physics_frame
			if is_instance_valid(z2) and z2.wall_mode == "":
				landed = true
				break
		check(landed, "walking under one: it drops down on you")
		if landed:
			check(absf(z2.global_position.y - floor_y) < 1.5, "...and lands on its floor line (%.1f)" % z2.global_position.y)
			check(z2.get_collision_layer_value(1), "...a body again")
			check(z2.alert_timer > 0.0, "...and comes for you")
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# a kill up there never leaves it hanging
	floor_y = 308.0
	var cr = load("res://scenes/enemy_zombie_crawler.tscn").instantiate()
	cr.global_position = Vector2(500, 321)
	add_child(cr)
	cr.start_on_wall("ceiling", floor_y, "t")
	cr.receive_damage(99, "blunt")
	check(absf(cr.global_position.y - floor_y) < 1.0 and cr.is_dead, "killed up there: it dies on the floor line")
	cr.queue_free()


func _test_longarm() -> void:
	var la = load("res://scenes/enemy_zombie_longarm.tscn").instantiate()
	la.global_position = Vector2(400, 374)
	add_child(la)
	await get_tree().process_frame
	var spr: AnimatedSprite2D = la.get_node("AnimatedSprite2D")
	check(absf(spr.scale.x - la.SPRITE_SCALE) < 0.001 and la.SPRITE_SCALE < 3.0, "the long arm is drawn smaller (%.1f, was 3)" % spr.scale.x)
	var feet: float = spr.position.y + spr.scale.y * la.FEET_BELOW_CENTRE
	check(absf(feet - 3.0 * la.FEET_BELOW_CENTRE) < 0.01, "...scaled about its feet: they're where they were (%.1f)" % feet)
	# its swing (25 frame px above its feet at full reach) now lands at the player's head, not over it
	var swing: float = 25.0 * spr.scale.y
	var ptex: Texture2D = load("res://assets/2D-Pixel-Art-Character-Template/Idle/Player Idle 48x48.png")
	var pimg: Image = ptex.get_image()
	var top := 48
	for y in range(48):
		for x in range(48):
			if pimg.get_pixel(x, y).a > 0.5:
				top = mini(top, y)
	var player_h: float = (40 - top) * 2.0
	check(swing <= player_h, "its swing lands at head height (%.0f) — not over a %.0f-tall player" % [swing, player_h])
	la.queue_free()
