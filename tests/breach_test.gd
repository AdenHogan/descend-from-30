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
	await _test_risers()
	await _test_rooms()
	await _test_foreground()
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
	# the story is SHORT (round 21c): the door's room + the next (split) or the door's room alone
	var split := ""
	var whole := ""
	for f in range(2, 29):
		for i in range(1, 6):
			var a := str(f) + "0" + str(i)
			if WorldState.breach_story_split(a) and split == "":
				split = a
			elif not WorldState.breach_story_split(a) and whole == "":
				whole = a
	check(split != "" and whole != "", "both kinds of story turn up (%s / %s)" % [split, whole])
	var r := func(apt, side): return [RoomScript.breach_nest_role(apt, side, 0), RoomScript.breach_nest_role(apt, side, 1), RoomScript.breach_nest_role(apt, side, 2)]
	check(r.call(split, "left") == ["door_l", "kill_l", ""], "door left, fled a room: door, kill, untouched (%s)" % str(r.call(split, "left")))
	check(r.call(split, "right") == ["", "kill_r", "door_r"], "door right, fled a room: untouched, kill, door (%s)" % str(r.call(split, "right")))
	check(r.call(whole, "left") == ["doorkill_l", "", ""], "door left, caught in the door's room (%s)" % str(r.call(whole, "left")))
	check(r.call(whole, "right") == ["", "", "doorkill_r"], "door right, caught in the door's room (%s)" % str(r.call(whole, "right")))
	# every module variant has all ten roles, each with its flies + the dead it drew (a RISE role draws
	# no body — a real zombie lies there — but records where)
	var meta := RoomScript.nest_meta()
	var missing := []
	var n := 0
	var no_body := []
	var corpses := 0
	var fought := 0
	for t in RoomScript.MODULE_VARIANTS:
		for scene_path in RoomScript.MODULE_VARIANTS[t]:
			var inst = load(scene_path).instantiate()
			var art = inst.get_node_or_null("Art")
			var base: String = art.texture.resource_path.get_basename() if art != null and art.texture != null else ""
			inst.free()
			for role in ["door_l", "kill_l", "doorkill_l", "corpse_l", "rise_l", "door_r", "kill_r", "doorkill_r", "corpse_r", "rise_r"]:
				var p: String = base + "_nest_" + role + ".png"
				n += 1
				var key := p.get_file().get_basename()
				if not ResourceLoader.exists(p) or not meta.has(key):
					missing.append(p.get_file())
				elif role.begins_with("rise"):
					var rs = meta[key].get("riser", [])
					if not (rs is Array and rs.size() == 3) or not meta[key].get("bodies", []).is_empty():
						no_body.append(key + " (riser spot)")
				elif not role.begins_with("door_") and meta[key].get("bodies", []).is_empty():
					no_body.append(key)
				if role.begins_with("corpse") and meta.has(key):
					corpses += 1
					if not meta[key].get("zombies", []).is_empty():
						fought += 1
			for old in ["_nest.png", "_nest_entry_l.png", "_nest_through_l.png", "_nest_lair_l.png"]:
				if base != "" and ResourceLoader.exists(base + old):
					missing.append("stale " + base + old)
	check(n == 300 and missing.is_empty(), "300 story overlays with their meta (%d, missing %s)" % [n, str(missing.slice(0, 4))])
	check(no_body.is_empty(), "every kill / doorkill / corpse draws someone, every rise marks its spot (%s)" % str(no_body.slice(0, 4)))
	# round 22: often, the resident took one of THEM with them
	check(fought >= corpses / 4 and fought < corpses, "the dead zombie beside them: now and then (%d of %d)" % [fought, corpses])
	# the dead's pockets: often empty, never anything outside the list
	var empty := 0
	var bad := []
	for i in range(200):
		var loot: Dictionary = WorldState.dead_body_loot("1203", "dead_0_%d" % i)
		if loot.is_empty():
			empty += 1
		elif not WorldState.DEAD_POCKETS.has(str(loot["item"])):
			bad.append(loot)
	check(empty > 60 and empty < 140 and bad.is_empty(), "the dead's pockets: often empty (%d/200), only pocket things (%s)" % [empty, str(bad)])
	check(WorldState.dead_body_loot("1203", "dead_0_3") == WorldState.dead_body_loot("1203", "dead_0_3"), "...and the same every visit")


func _dead_nodes() -> Array:
	var out := []
	for m in get_tree().get_nodes_in_group("room_module"):
		for c in m.get_children():
			if c.has_meta("dead_body"):
				out.append(c)
	return out


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
		# the story: the door's room (+ the next when they fled it), never all three rooms
		var nests := get_tree().get_nodes_in_group("breach_nest")
		var eside := WorldState.get_entrance_side(apt)
		var want_n := 2 if WorldState.breach_story_split(apt) else 1
		check(nests.size() == want_n, "%s room: the story covers %d room(s) (%d)" % [kind, want_n, nests.size()])
		var story_ok := not nests.is_empty()
		for nn in nests:
			var slot := int(round((nn.get_parent().position.x - RoomScript.LEFT_WALL_X) / RoomScript.MODULE_WIDTH))
			var role: String = RoomScript.breach_nest_role(apt, eside, slot)
			if role == "" or str(nn.get_meta("role", "")) != role or not nn.texture.resource_path.ends_with("_nest_" + role + ".png"):
				story_ok = false
		check(story_ok, "...each overlay the role its room plays (door %s)" % eside)
		var dead := _dead_nodes()
		var dead_ok := not dead.is_empty()
		for d in dead:
			if not d.has_method("try_interact") or not str(d.name).begins_with("dead_"):
				dead_ok = false
		check(dead_ok, "...and the dead in it can be searched (%d)" % dead.size())
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
	check(get_tree().get_nodes_in_group("breach_nest").is_empty() == WorldState.apartment_corpse(quiet).is_empty(), "an ordinary flat: no story unless one of the dead is there")
	r2.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# an ordinary flat with one of the dead: that room alone, a body to search
	var with_dead := ""
	for f in range(4, 27):
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			if not WorldState.apartment_corpse(apt).is_empty() and not WorldState.apartment_riser(apt):
				with_dead = apt
				break
		if with_dead != "":
			break
	check(with_dead != "", "some ordinary flats have one of the dead (run %d)" % WorldState.current_run)
	if with_dead != "":
		var info: Dictionary = WorldState.apartment_corpse(with_dead)
		WorldState.current_apartment_id = with_dead
		WorldState.current_floor = WorldState._apartment_floor(with_dead)
		var r3 = load("res://scenes/room.tscn").instantiate()
		add_child(r3)
		for i in range(3):
			await get_tree().process_frame
		var ns := get_tree().get_nodes_in_group("breach_nest")
		check(ns.size() == 1 and str(ns[0].get_meta("role", "")) == "corpse_" + str(info["side"]), "%s: one room with its dead (%s)" % [with_dead, str(info)])
		check(_dead_nodes().size() == 1, "...one body to search (%d)" % _dead_nodes().size())
		r3.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	# how often: a handful of flats a run, more later in the day
	var counts := []
	var keep_run := WorldState.current_run
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var c := 0
		for f in range(2, 29):
			for i in range(1, 6):
				if not WorldState.apartment_corpse(str(f) + "0" + str(i)).is_empty():
					c += 1
		counts.append(c)
	WorldState.current_run = keep_run
	check(counts[0] >= 3 and counts[2] > counts[0] and counts[2] < 60, "the dead in ordinary flats: peppered, more each run (%s of 135)" % str(counts))


func _test_foreground() -> void:
	# the foreground-silhouette TEST look (round 21c) was DROPPED in round 33 (owner: "a little overwhelming and not clear about
	# what we're looking at, so we can drop that visual element from the foreground completely") — nothing may bring it back.
	check(not ResourceLoader.exists("res://scripts/foreground_dead.gd"), "the foreground-silhouette script is gone")
	check(not DirAccess.dir_exists_absolute("res://assets/foreground"), "...and its art")
	check(not ("foreground_dead_mode" in WorldState), "...and its dev switch")
	var apt := _find("big")
	var room := _room(apt)
	for i in range(4):
		await get_tree().process_frame
	check(room.get_node_or_null("ForegroundDead") == null and room.find_children("ForegroundDead", "", true, false).is_empty(),
		"a breached flat has no foreground silhouettes")
	room.queue_free()
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
	# scaled about its feet, which (round 33, enemy_feet.gd) sit on the player's row: 1 px over the collision feet
	var want: float = load("res://scripts/enemy_feet.gd").collision_bottom(la) - 1.0
	check(absf(feet - want) < 0.6, "...scaled about its feet: they're on the player's row (%.1f, want %.1f)" % [feet, want])
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


# RISERS (owner round 22 — "watch some of them get up… like our neighbour in the tutorial"): a flat's
# dead may be a zombie lying there. It lies still (no collision, no AI), twitches and gets up when the
# player comes near, and memory keeps it honest: a dormant one isn't remembered, a risen one is
# remembered standing, a killed one stays dead.
func _riser_flat() -> String:
	for f in range(4, 27):
		for i in range(1, 6):
			var apt := str(f) + "0" + str(i)
			if WorldState.apartment_riser(apt):
				return apt
	return ""


func _open_flat(apt: String) -> Node:
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _test_risers() -> void:
	WorldState.current_run = 2
	var counts := []
	for run in [1, 2, 3]:
		WorldState.current_run = run
		var c := 0
		var d := 0
		for f in range(2, 29):
			for i in range(1, 6):
				var a := str(f) + "0" + str(i)
				if WorldState.apartment_riser(a):
					c += 1
				if not WorldState.apartment_corpse(a).is_empty():
					d += 1
		counts.append([c, d])
	WorldState.current_run = 2
	var some: int = int(counts[0][0]) + int(counts[1][0]) + int(counts[2][0])
	var fewer: bool = counts[0][0] <= counts[0][1] and counts[1][0] <= counts[1][1] and counts[2][0] <= counts[2][1]
	check(some >= 3 and fewer and WorldState.RISER_CHANCE[3] > WorldState.RISER_CHANCE[1],
		"risers: some of the dead, likelier as the arc goes on ([risers, dead] %s)" % str(counts))
	var apt := _riser_flat()
	check(apt != "", "a flat with a riser turns up")
	if apt == "":
		return
	var key := WorldState.riser_key(apt)
	WorldState.killed_zombies.erase(key)
	WorldState.zombie_positions.erase(key)
	var room := _open_flat(apt)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	player.global_position.x = 2000.0          # far off to start
	for i in range(3):
		await get_tree().process_frame
	var ns := get_tree().get_nodes_in_group("breach_nest")
	var side: String = str(WorldState.apartment_corpse(apt)["side"])
	check(ns.size() == 1 and str(ns[0].get_meta("role", "")) == "rise_" + side, "%s: the story drawn without its body (rise_%s)" % [apt, side])
	check(_dead_nodes().is_empty(), "...no drawn body to search")
	var rs := get_tree().get_nodes_in_group("riser")
	check(rs.size() == 1, "...and one of them lying there (%d)" % rs.size())
	if rs.size() != 1:
		room.queue_free()
		return
	var z = rs[0]
	check(z.spawn_key == key and z.riser_phase == "lying" and z.state == "dormant", "it lies dormant (%s / %s)" % [z.riser_phase, z.state])
	check(not z.get_collision_layer_value(1) and not z.get_collision_mask_value(1), "...no body collision while it lies there")
	check(absf(absf(z.animated_sprite.rotation) - PI * 0.5) < 0.01, "...on its back (rotation %.2f)" % z.animated_sprite.rotation)
	var feet_y: float = z.global_position.y + z.RISER_FEET
	check(z.z_index == 0, "...on the floor layer, under the living")
	# the lying body rests on the floor: its drawn extent (a rotated frame) sits above its feet line
	check(absf(z.animated_sprite.global_position.y - (feet_y - z.RISER_HALF * z.RISER_FLAT)) < 30.0, "...its body rests on the floor (sprite %.0f, feet %.0f)" % [z.animated_sprite.global_position.y, feet_y])
	for i in range(30):
		await get_tree().physics_frame
	check(z.riser_phase == "lying", "the player far away: it stays down")
	# a swing prefers anything standing over it
	check(player.has_method("_lying_penalty") and player._lying_penalty(z) > 0.0, "a lying riser is the last thing a swing picks")
	# leave while it lies: not remembered
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not WorldState.zombie_positions.has(key), "left lying: not remembered (so it lies there again)")
	room = _open_flat(apt)
	player = get_tree().get_first_node_in_group("player")
	for i in range(3):
		await get_tree().process_frame
	rs = get_tree().get_nodes_in_group("riser")
	check(rs.size() == 1 and rs[0].riser_phase == "lying", "...and it's lying there again on return")
	if rs.size() != 1:
		room.queue_free()
		return
	z = rs[0]
	# the player comes close: it twitches, rises stiff, and comes on
	player.global_position = Vector2(z.global_position.x + 60.0, player.global_position.y)
	var saw_twitch := false
	var saw_rise := false
	var t := 0.0
	while t < 4.0 and z.riser_phase != "":
		await get_tree().physics_frame
		player.global_position.x = z.global_position.x + 60.0
		t += get_physics_process_delta_time()
		saw_twitch = saw_twitch or z.riser_phase == "twitch"
		saw_rise = saw_rise or z.riser_phase == "rise"
	check(saw_twitch and saw_rise and z.riser_phase == "", "it twitches, rises and is up (%.1fs)" % t)
	check(z.get_collision_layer_value(1) and z.z_index == 1 and z.state in ["chase", "attack", "idle"] and not z.is_in_group("riser"), "...an ordinary zombie now (%s)" % z.state)
	check(absf(z.animated_sprite.rotation) < 0.001 and z.animated_sprite.scale == z._riser_scale0, "...standing upright, full size")
	check(z.alert_timer > 0.0, "...coming for you")
	# leave: remembered STANDING; back: not lying down again
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(WorldState.zombie_positions.has(key), "left after it rose: remembered")
	room = _open_flat(apt)
	for i in range(3):
		await get_tree().process_frame
	rs = get_tree().get_nodes_in_group("riser")
	var standing = null
	for zz in get_tree().get_nodes_in_group("zombie"):
		if zz.spawn_key == key:
			standing = zz
	check(rs.is_empty() and standing != null and standing.riser_phase == "", "...and it's back on its feet on return, not lying down")
	# kill it: it stays dead
	if standing != null:
		standing.receive_damage(99, "bludgeon")
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(WorldState.killed_zombies.has(key), "killed: remembered dead")
	room = _open_flat(apt)
	for i in range(3):
		await get_tree().process_frame
	var again := false
	for zz in get_tree().get_nodes_in_group("zombie"):
		if zz.spawn_key == key and not zz.is_dead:
			again = true
	check(not again, "...and it doesn't get up again")
	room.queue_free()
	await get_tree().process_frame
	# hit where it lies: it's up at once and takes the blow
	WorldState.killed_zombies.erase(key)
	WorldState.zombie_positions.erase(key)
	room = _open_flat(apt)
	player = get_tree().get_first_node_in_group("player")
	player.global_position.x = 2000.0
	for i in range(3):
		await get_tree().process_frame
	rs = get_tree().get_nodes_in_group("riser")
	if rs.size() == 1:
		z = rs[0]
		var hp0: int = z.current_hp
		z.receive_damage(1, "blade")
		check(z.riser_phase == "" and absf(z.animated_sprite.rotation) < 0.001 and (z.current_hp < hp0 or z.is_dead), "hit where it lies: it's up at once, and the blow lands")
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	WorldState.killed_zombies.erase(key)
	WorldState.zombie_positions.erase(key)
