extends Node

# Headless test for the stair-pan groundwork: building_floors can be built as a
# PASSIVE backdrop for a specific floor (no player/enemies/merchant, correct
# door IDs) — what StairPan instances beside the live floor. Also checks the
# StairPan safety guard (disabled by default → never pans).
# Run:  godot --headless res://tests/building_floors_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== building_floors passive / StairPan test ===")
	await _test_passive_backdrop()
	await _test_backdrop_offset_applies()
	_test_stairpan_guard()
	_test_pan_targets()
	await _test_floor_camera()
	await _test_scenery_zombie_plane()
	await _test_pried_arrival_milling()
	await _test_stair_pull_rouses_only_near()
	await _test_barricade_visuals()
	await _test_stair_enemy_spawns()
	await _test_stair_enemy_backdrop()
	await _test_stair_enemy_return_grounded()
	await _test_follower_same_node()
	await _test_follower_resident()
	await _test_follower_unique_keys()
	_test_followed_away_saved()
	await _test_stair_gates()
	await _test_fire_spawns()
	await _test_elevator_arrival_stairs()
	await _test_enemies_stand_on_the_line_frame_zero()
	await _test_corridor_art()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _enabled_stair_triggers(bf: Node) -> Array:
	var out: Array = []
	for n in ["stair_left_down_trigger", "stair_left_up_trigger", "stair_right_down_trigger", "stair_right_up_trigger"]:
		var t = bf.get_node_or_null(n)
		if t != null and t.process_mode != Node.PROCESS_MODE_DISABLED:
			out.append(n)
	return out


func _test_elevator_arrival_stairs() -> void:
	# Arriving by elevator must configure the stairwells like a canonical descent —
	# exactly ONE up + ONE down trigger live (zig-zag). The bug: empty stair state left
	# ALL FOUR enabled, so the player tripped the wrong one and the floor count drifted.
	print("[elevator arrival stairs]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	for f in [19, 20]:               # odd + even (canonical side alternates)
		WorldState.current_floor = f
		WorldState.spawn_source = "elevator"
		WorldState.stair_spawn_side = WorldState.canonical_stair_arrival_side(f)
		WorldState.stair_direction = "down"
		var bf = load("res://scenes/building_floors.tscn").instantiate()
		bf.setup_floor = f
		add_child(bf)
		for i in range(4): await get_tree().process_frame
		var en := _enabled_stair_triggers(bf)
		check(en.size() == 2, "floor %d elevator arrival: exactly 2 stair triggers live (%d)" % [f, en.size()])
		var ups := 0
		var downs := 0
		for n in en:
			if str(n).contains("_up_"): ups += 1
			else: downs += 1
		check(ups == 1 and downs == 1, "floor %d: one up + one down live (up=%d down=%d)" % [f, ups, downs])
		bf.free()
		await get_tree().process_frame


func _floor_with_zombies(fallback: int) -> int:
	# new_game() picks a RANDOM master seed and get_floor_zombie_count can legally
	# return 0, so "spawn a floor and expect enemies" is a coin flip — that was the
	# intermittent failure, not a timing problem. Pick a floor this seed actually
	# populates instead of assuming one does.
	for f in range(1, 30):
		if WorldState.get_floor_zombie_count(f) > 0:
			return f
	return fallback


func _test_passive_backdrop() -> void:
	print("[passive backdrop]")
	WorldState.new_game()
	var backdrop_floor := _floor_with_zombies(27)
	WorldState.current_floor = (backdrop_floor + 2) % 29 + 1   # live floor is elsewhere
	WorldState.seed_floor_door_states(backdrop_floor)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = backdrop_floor
	bf.passive = true
	add_child(bf)
	for i in range(6):
		await get_tree().process_frame

	check(bf.get_node_or_null("Player") == null, "passive backdrop drops its Player node")
	# A backdrop DOES show the floor's enemies (seeded identically to the live
	# floor) so they scroll into view during the pan instead of materialising on
	# arrival — but they must be pure scenery: no AI, no collision.
	var scenery := get_tree().get_nodes_in_group("pan_scenery")
	check(scenery.size() > 0, "backdrop shows the next floor's enemies (%d)" % scenery.size())
	var thinking := 0
	for z in scenery:
		if z.is_physics_processing():
			thinking += 1
	check(thinking == 0, "backdrop enemies have no AI running (%d thinking)" % thinking)
	# Doors carry the backdrop floor's apartment IDs.
	var d1 = bf.get_node_or_null("apartment01")
	var want_id := str(backdrop_floor) + "01"
	check(d1 != null and d1.apartment_id == want_id,
		"doors use the backdrop floor's IDs (%s)" % (d1.apartment_id if d1 else "nil"))
	check(bf.get_node_or_null("Merchant") == null, "no merchant on a passive backdrop")
	# The pan offset comes from the floor's tilemap height (not one screen) —
	# that's what removes the grey gap between floors.
	var sp2 = get_node_or_null("/root/StairPan")
	if sp2 != null:
		var spacing = sp2._floor_spacing(bf)
		check(spacing > 0.0, "floor spacing measured from the tilemap (%.0f)" % spacing)
		check(spacing < 1000.0, "floor spacing is a plausible one-floor height (%.0f)" % spacing)
		print("  INFO  measured floor spacing = %.1f world px" % spacing)
	bf.queue_free()
	await get_tree().process_frame


func _test_backdrop_offset_applies() -> void:
	# THE regression that broke every earlier "seamless offset" attempt:
	# building_floors' root used to be a plain Node. CanvasItem transforms only
	# propagate through CanvasItem parents, so a Node2D holder's offset was
	# SILENTLY IGNORED — the backdrop drew exactly on top of the live floor and
	# the camera panned off into grey. Assert the offset lands in WORLD space,
	# not just that the arithmetic is right.
	print("[backdrop offset actually applies]")
	WorldState.new_game()
	WorldState.current_floor = 25
	var holder := Node2D.new()
	add_child(holder)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 26
	bf.passive = true
	holder.add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	var base_tm = bf.get_node_or_null("TileMapLayer")
	var base_y: float = base_tm.global_position.y
	holder.position = Vector2(0, -192.0)
	await get_tree().process_frame
	var moved_y: float = base_tm.global_position.y
	check(bf is Node2D, "building_floors root is a Node2D (transforms propagate)")
	check(is_equal_approx(moved_y, base_y - 192.0),
		"holder offset reaches the tilemap in world space (%.0f → %.0f)" % [base_y, moved_y])
	# A stacked neighbour must not collide with / trigger on the live floor.
	var counts := _physics_counts(bf)
	check(counts["solid"] == 0, "passive backdrop has no active collision (%d)" % counts["solid"])
	check(counts["monitoring"] == 0, "passive backdrop has no live Area2D triggers (%d)" % counts["monitoring"])
	holder.queue_free()
	await get_tree().process_frame


func _test_floor_camera() -> void:
	# The camera is locked to the FLOOR, not floating with the player: walking to
	# a stairwell pushes the view against the end wall and it stops there.
	print("[scene-locked floor camera]")
	var sp = get_node_or_null("/root/StairPan")
	WorldState.new_game()
	WorldState.current_floor = 25
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 25
	bf.passive = true
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	var tm = bf.get_node_or_null("TileMapLayer")
	# Junk row is gone: the floor is its solid content only.
	check(sp.strip_junk_rows(tm) == 0, "junk rows already stripped on build")
	var b: Rect2 = sp.floor_band(tm)
	check(is_equal_approx(b.size.y, 192.0), "floor band is the full 12-tile corridor (%.0f)" % b.size.y)
	check(is_equal_approx(b.position.y, 243.0), "floor top is the raised ceiling (%.0f)" % b.position.y)

	# The hallway's tilemap is TALLER than a floor (blue filler above + below).
	# It must still frame to the same band, or floor 30 zooms differently from 29.
	var hall = load("res://scenes/hallway.tscn").instantiate()
	var htm: TileMapLayer = hall.get_node_or_null("TileMapLayer")
	var hb: Rect2 = sp.floor_band(htm)
	check(is_equal_approx(hb.size.y, b.size.y) and is_equal_approx(hb.position.y, b.position.y),
		"hallway frames the SAME band as a floor (%.0f..%.0f)" % [hb.position.y, hb.position.y + hb.size.y])
	hall.free()

	var cam := Camera2D.new()
	add_child(cam)
	sp.apply_floor_camera(cam, b)
	# The floor's bottom edge must land exactly on the top of the HUD bar, or the
	# inventory eats into the floor (the bar is 120px, not BAR_H's 80).
	var floor_bottom_screen: float = (b.position.y + b.size.y - float(cam.limit_top)) * cam.zoom.y
	check(absf(floor_bottom_screen - (648.0 - sp.HUD_BAR_H)) <= 1.0,
		"floor sits tight above the HUD bar (%.0f vs %.0f)" % [floor_bottom_screen, 648.0 - sp.HUD_BAR_H])
	check(cam.limit_left == int(b.position.x), "camera stops at the left wall (%d)" % cam.limit_left)
	check(cam.limit_right == int(b.position.x + b.size.x), "camera stops at the right wall (%d)" % cam.limit_right)
	check(cam.limit_top == int(b.position.y), "camera never rises above the ceiling (%d)" % cam.limit_top)
	# Vertical limits span exactly one view height → the camera cannot drift up
	# or down at all, so no grey above the ceiling or below the floor.
	var view_h: float = 648.0 / cam.zoom.y
	check(absf(float(cam.limit_bottom - cam.limit_top) - view_h) <= 1.0,
		"vertical limits pin the view to one floor (range %d vs view %.0f)"
			% [cam.limit_bottom - cam.limit_top, view_h])
	check(cam.zoom.y > 2.5, "zoomed so the floor fills the play area (%.2f)" % cam.zoom.y)
	cam.queue_free()
	bf.queue_free()
	await get_tree().process_frame


func _test_scenery_zombie_plane() -> void:
	# A backdrop zombie must stand on the SAME plane a live one settles to,
	# otherwise it visibly warps up the instant the floor commits. This measures
	# the real settled Y, so if collision shapes ever change the constant in
	# building_floors.gd fails here instead of silently drifting.
	print("[scenery zombie stands on the live plane]")
	WorldState.new_game()
	var live_floor := _floor_with_zombies(25)
	WorldState.current_floor = live_floor
	var live = load("res://scenes/building_floors.tscn").instantiate()
	live.setup_floor = live_floor
	add_child(live)
	# Drop the floor's Player so the seeded zombies (crawlers now hit for double) can't
	# kill it mid-measure — a death would fire the time-skip and free this test scene.
	var _pl = live.get_node_or_null("Player")
	if _pl != null:
		_pl.queue_free()
	# Measure an explicitly-spawned STANDARD zombie: the seeded mix now includes crawlers
	# (which rest on their own 374 line), so grabbing "a live zombie" could read the wrong
	# rig. A known standard proves ZOMBIE_SETTLED_Y is where the standard rig actually rests.
	for i in range(4):
		await get_tree().process_frame
	var std = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	live.add_child(std)
	std.global_position = Vector2(640, 388.0)
	for i in range(80):                 # fully settles by ~frame 60 (measured)
		await get_tree().process_frame
	var settled: float = std.global_position.y
	check(settled > 0.0, "a live standard zombie settled to measure (%.1f)" % settled)
	if settled > 0.0:
		check(absf(settled - live.ZOMBIE_SETTLED_Y) <= 2.0,
			"ZOMBIE_SETTLED_Y matches where a live zombie rests (%.1f vs %.1f)"
				% [live.ZOMBIE_SETTLED_Y, settled])
	live.queue_free()
	await get_tree().process_frame


func _physics_counts(node: Node) -> Dictionary:
	var out := {"solid": 0, "monitoring": 0}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject2D:
			if n.collision_layer != 0 or n.collision_mask != 0:
				out["solid"] += 1
			if n is Area2D and (n.monitoring or n.monitorable):
				out["monitoring"] += 1
		for c in n.get_children():
			stack.append(c)
	return out


func _test_stairpan_guard() -> void:
	print("[StairPan guard]")
	var sp = get_node_or_null("/root/StairPan")
	check(sp != null, "StairPan is an autoload singleton")
	if sp == null:
		return
	# Enabled: pans between EVERY floor, lobby (0) and hallway (30) included — but never
	# off the ends of the building. (The per-staircase + real-scene checks live in
	# transition_seam_test, which runs them from actual floor scenes.)
	check(sp.ENABLED, "StairPan is enabled")
	check(not sp.can_pan(-1), "no pan below the lobby")
	check(not sp.can_pan(31), "no pan above the top floor")
	check(sp.scene_for_floor(30).ends_with("hallway.tscn") and sp.scene_for_floor(0).ends_with("lobby.tscn")
		and sp.scene_for_floor(15).ends_with("building_floors.tscn"), "each floor builds its real scene")


func _test_pan_targets() -> void:
	print("[seamless pan targets]")
	var sp = get_node_or_null("/root/StairPan")
	if sp == null:
		return
	# The whole seamlessness rests on one invariant: at the end of the pan the
	# camera-relative-to-player equals the live camera offset, so when the
	# destination scene loads (player at spawn, camera at spawn+offset) the first
	# frame is identical to the last pan frame — no jump, no hard cut.
	var cam_offset := Vector2(6, -19)
	var spawn := Vector2(188, 391)     # SPAWN_LEFT_BOTTOM
	var down_t = sp.pan_targets(spawn, cam_offset, 176.0)
	check(down_t["cam_target"] - down_t["player_target"] == cam_offset,
		"down: end framing matches destination (seamless commit)")
	check(down_t["player_target"] == spawn + Vector2(0, 176.0),
		"down: player ends one floor below on the backdrop")
	var up_t = sp.pan_targets(Vector2(148, 391), cam_offset, -176.0)
	check(up_t["cam_target"] - up_t["player_target"] == cam_offset,
		"up: end framing matches destination (seamless commit)")
	# Player + camera move by the SAME delta → player holds a fixed screen spot.
	var start_player := spawn
	var start_cam := spawn + cam_offset
	var player_delta = down_t["player_target"] - start_player
	var cam_delta = down_t["cam_target"] - start_cam
	check(player_delta == cam_delta, "player and camera slide by an identical delta")
	# Floors are contiguous: the offset is exactly one floor height (no gap).
	check(down_t["delta"] == Vector2(0, 176.0), "floor offset is exactly one floor height")


func _test_pried_arrival_milling() -> void:
	# Phase 3: arriving via a crowbar pry, the destination floor's dead have
	# gathered at the stairwell you tore open — clustered by the arrival stairs
	# and roused — rather than spread evenly along the corridor.
	print("[pried-arrival milling]")
	WorldState.new_game()
	var f := _floor_with_zombies(27)
	WorldState.current_floor = f
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"   # land on the LEFT stairwell
	WorldState.pending_pry_arrival_floor = f
	WorldState.seed_floor_door_states(f)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	# _ready runs synchronously on add_child: the horde exists, positioned +
	# roused, before any physics has had a chance to move it.
	var zs: Array = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not z.is_in_group("pan_scenery"):
			zs.append(z)
	check(zs.size() > 0, "pried arrival spawned the floor's horde (%d)" % zs.size())
	var all_in_band := true
	var all_roused := true
	for z in zs:
		# A stair-horde on the FAR stairwell is a separate hazard (docked + sliced there),
		# not the arrival's milling dead — exclude it so the seed's horde placement can't
		# skew the milling asserts.
		if z.is_in_group("stair_enemy"):
			continue
		if z.global_position.x < 230.0 or z.global_position.x > 500.0:
			all_in_band = false
		if z.alert_timer <= 0.0:
			all_roused = false
	check(all_in_band, "horde clustered by the LEFT arrival stairwell")
	check(all_roused, "arrival horde is roused (alerted)")
	check(WorldState.pending_pry_arrival_floor == -1, "arrival flag consumed after milling")
	bf.queue_free()
	await get_tree().process_frame


func _test_stair_pull_rouses_only_near() -> void:
	# Phase 4: a cross-floor pull rouses ONLY the dead seeded near the arrival
	# stairwell — never the ones dozing deeper in the corridor. Invariant checked
	# regardless of how the seed happened to distribute them.
	print("[cross-floor pull: only near-stair roused]")
	WorldState.new_game()
	var f := _floor_with_zombies(27)
	WorldState.current_floor = f
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.pending_stair_pulls[str(f) + ":" + str(WorldState.current_run)] = true
	WorldState.seed_floor_door_states(f)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	var near_x: float = 265.0 + WorldState.STAIR_PULL_NEAR   # left arrival threshold
	var roused_far := 0
	var roused_total := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if z.is_in_group("pan_scenery"):
			continue
		if z.alert_timer > 0.0:
			roused_total += 1
			if z.global_position.x > near_x:
				roused_far += 1
	check(roused_far == 0, "no far-corridor zombie was roused by the pull (%d)" % roused_far)
	check(not WorldState.has_stair_pull(f), "pull flag consumed after arrival")
	print("  INFO  roused %d near-stair zombie(s) on floor %d" % [roused_total, f])
	bf.queue_free()
	await get_tree().process_frame


func _test_barricade_visuals() -> void:
	# A crate stack spawns in front of every blocked stairwell (up AND down), so a
	# barricade is visible on the floor, not just felt on a pry attempt.
	print("[barricade visuals]")
	WorldState.new_game()
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_BARRICADE   # every stairwell blocked
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(15)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	# _ready runs synchronously: a prop lives at BOTH active stairwells, each
	# VISIBLE because both are barricaded (F2 mode → both sides shown).
	var props: Array = get_tree().get_nodes_in_group("barricade_prop")
	check(props.size() == 2, "a prop lives at each active stairwell (%d)" % props.size())
	var visible_ends := 0
	for p in props:
		if p.visible and (p.global_position.x < 300.0 or p.global_position.x > 1000.0):
			visible_ends += 1
	check(visible_ends == 2, "both stairwells show visible crates in barricade mode (%d)" % visible_ends)
	# The two props are this floor's DOWN-stair (choke = floor, the descent block)
	# and its UP-stair back to the floor above (choke = floor+1) — so a barricade
	# you balconied past above is still visible here on the stair leading back up.
	var chokes := {}
	for p in props:
		chokes[p.choke_floor] = true
	check(chokes.has(15) and chokes.has(16),
		"props cover the descent stair (15) AND the up-stair back (16)")
	bf.queue_free()
	await get_tree().process_frame
	# With no barricade (cleared), the props exist but self-hide (visual matches
	# the block, so it can never show crates where you can walk through).
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	WorldState.clear_stair_block(15)
	WorldState.clear_stair_block(16)
	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf2)
	var any_visible := false
	for p in get_tree().get_nodes_in_group("barricade_prop"):
		if p.visible:
			any_visible = true
	check(not any_visible, "no VISIBLE barricade crates on an unblocked floor")
	bf2.queue_free()
	await get_tree().process_frame


func _test_stair_enemy_spawns() -> void:
	# A seeded stairwell spawns a SINGLE standard zombie partway down the stairs,
	# sliced into the shaft (both active stairwells in dev horde mode), in the
	# "stair_enemy" group. It emerges onto the corridor when the player nears.
	print("[stair horde spawns]")
	WorldState.new_game()
	WorldState.dev_force_stair_enemies = true   # force one stair enemy per active stairwell
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(15)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	var horde := get_tree().get_nodes_in_group("stair_enemy")
	# One enemy per active stairwell — two active (one up + one down) in dev mode.
	check(horde.size() == 2, "one stairwell enemy per active stairwell (%d)" % horde.size())
	# Each starts IN the shaft: stair mode, tucked to a stairwell centre (an end), sunk
	# down on the steps (below the corridor line), passable + unharmable until it emerges.
	var all_in_shaft := true
	for z in horde:
		if not z.stair_mode:
			all_in_shaft = false
		if z.get_collision_layer_value(1):
			all_in_shaft = false            # body collision must be OFF on the steps (can't shove/wall the player)
		if z.global_position.x > 260.0 and z.global_position.x < 1090.0:
			all_in_shaft = false            # not tucked into a stairwell
		if absf(z.global_position.y - 391.0) < 8.0:
			all_in_shaft = false            # should be OFF the plane, on the steps (up OR down), not standing on the corridor
	check(all_in_shaft, "the stairwell enemy waits IN the shaft (stair mode, no body collision, off the plane)")
	# It is ALWAYS killable — no softlock. A hit pulls it OUT of stair mode into normal
	# handling instead of being unharmable, so it can always be dealt with.
	var z0 = horde[0]
	z0.receive_damage(1, "blade")
	check(not z0.stair_mode, "a hit pulls a stairwell enemy off the steps (killable, never a softlock)")
	# (Stairwell enemies are decoupled from hazards now — a barricade may coexist here.)
	bf.queue_free()
	await get_tree().process_frame
	WorldState.dev_force_stair_enemies = false


func _test_follower_same_node() -> void:
	# Cross-floor follow with the EXACT SAME NODE: a chasing enemy is parked on the tree
	# root, survives the origin floor being freed, and is re-homed emerging from the
	# arrival stairwell — same instance id, same hp. No duplicate is left behind.
	print("[cross-floor follower — exact same node]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.dev_force_stair_enemies = true
	WorldState.current_floor = 14; WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"; WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(14)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().process_frame
	var e = null
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		e = z; break
	check(e != null, "a stair enemy exists to become the follower")
	if e == null:
		bf.queue_free(); await get_tree().process_frame; WorldState.dev_force_stair_enemies = false; return
	var eid: int = e.get_instance_id()
	e.current_hp = 2
	# Simulate stairwell._capture_follower toward floor 13.
	WorldState.followed_away[e.spawn_key] = true
	WorldState.zombie_positions.erase(e.spawn_key)
	WorldState.follower_streak = 1
	e.begin_follow()
	WorldState.follower_node = e
	check(e.get_parent() == get_tree().root, "the captured node is parked on the tree root")
	# The origin floor is torn down (as a real transition frees it).
	bf.queue_free()
	await get_tree().process_frame
	check(is_instance_valid(e), "the SAME node survives the origin floor being freed")
	# Arrive on floor 13.
	WorldState.current_floor = 13; WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"; WorldState.stair_spawn_side = "left"
	WorldState.dev_force_stair_enemies = false
	WorldState.seed_floor_door_states(13)
	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf2)
	await get_tree().process_frame
	var arrived = null
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if z.get_instance_id() == eid:
			arrived = z; break
	check(arrived != null, "THE SAME node (same instance id) arrives on the next floor")
	check(WorldState.follower_node == null, "follower_node is consumed on arrival")
	if arrived != null:
		check(arrived.get_parent() == bf2, "the same node is re-homed into the new floor scene")
		check(arrived.current_hp == 2, "it keeps its EXACT hp (2)")
		check(arrived.is_follower and arrived.alert_timer > 0.0, "arrives as the follower, locked on")
		for i in range(600):
			if not arrived.stair_mode: break
			arrived._stair_tick(1.0 / 60.0)
		check(absf(arrived.global_position.y - 370.0) < 0.5, "ends GROUNDED on the floor line (%.1f)" % arrived.global_position.y)
	bf2.queue_free()
	await get_tree().process_frame
	WorldState.followed_away.clear()


func _test_follower_resident() -> void:
	# A follower left on a floor (non-stair exit) persists: remembered under its resident
	# key and restored GROUNDED as an ordinary floor zombie on return.
	print("[follower resident persistence]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.follower_node = null
	WorldState.current_floor = 12; WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"; WorldState.stair_spawn_side = "left"
	WorldState.seed_floor_door_states(12)
	# Forge a remembered resident follower on floor 12 (as _exit_tree would after an
	# apartment trip).
	WorldState.zombie_positions["followerR:12"] = {"x": 620.0, "y": 370.0, "facing": false, "hp": 3, "alert": 0.0}
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().process_frame
	var r = null
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if z.spawn_key == "followerR:12":
			r = z; break
	check(r != null, "a resident follower is restored on return")
	if r != null:
		check(r.current_hp == 3, "it keeps its remembered hp (3)")
		check(not r.stair_mode, "it's an ordinary floor zombie (not re-caged in the shaft)")
		check(absf(r.global_position.y - 370.0) < 0.5, "restored GROUNDED on the floor line (%.1f)" % r.global_position.y)
	# A DEAD resident does not come back.
	bf.queue_free(); await get_tree().process_frame
	WorldState.killed_zombies["followerR:12"] = {"floor": 12}
	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf2)
	await get_tree().process_frame
	var still := false
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if z.spawn_key == "followerR:12":
			still = true
	check(not still, "a killed resident follower stays dead")
	bf2.queue_free(); await get_tree().process_frame
	WorldState.zombie_positions.erase("followerR:12")
	WorldState.killed_zombies.erase("followerR:12")


func _test_stair_enemy_backdrop() -> void:
	# Regression (pan-pop): a floor reached by the seamless stair PAN builds as a PASSIVE
	# backdrop first, so its stair enemies must be present as FROZEN scenery that scrolls
	# into view — not pop in at the commit. And go_live must WAKE those same nodes, never
	# spawn a second set. The backdrop must seed on exactly the 2 active chokes (like a
	# live floor), not all 4 (its triggers weren't enabled before this fix).
	print("[stair enemy pan backdrop]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.dev_force_stair_enemies = true   # force one stair enemy per active stairwell
	WorldState.current_floor = 14
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(14)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	bf.setup_floor = 14
	bf.passive = true
	add_child(bf)
	for i in range(4):
		await get_tree().process_frame
	# The backdrop shows the stair enemies as pure scenery: in the shaft, frozen (no AI),
	# tagged pan_scenery, and — crucially — one per ACTIVE choke, so 2 not 4.
	var back := get_tree().get_nodes_in_group("stair_enemy")
	check(back.size() == 2, "backdrop seeds stair enemies on the 2 active chokes, not 4 (%d)" % back.size())
	var all_frozen_scenery := true
	for z in back:
		if not z.is_in_group("pan_scenery"):
			all_frozen_scenery = false
		if z.is_physics_processing():
			all_frozen_scenery = false      # AI must be off while it's still a floor away
		if not z.stair_mode:
			all_frozen_scenery = false      # still waiting in the shaft
	check(all_frozen_scenery, "backdrop stair enemies are frozen scenery (pan_scenery, no AI, in the shaft)")
	var ids := {}
	for z in back:
		ids[z.get_instance_id()] = true
	# Wake the backdrop into a live floor (as StairPan does after reparenting the player).
	bf.go_live()
	await get_tree().process_frame
	var live := get_tree().get_nodes_in_group("stair_enemy")
	check(live.size() == 2, "go_live wakes the SAME stair enemies, no double-spawn (%d)" % live.size())
	var same_nodes := true
	var awake := 0
	for z in live:
		if not ids.has(z.get_instance_id()):
			same_nodes = false              # a fresh node → go_live re-spawned instead of waking
		if z.is_in_group("pan_scenery"):
			same_nodes = false              # scenery tag must be dropped on wake
		if z.is_physics_processing():
			awake += 1
	check(same_nodes, "the woken stair enemies are the SAME backdrop nodes (no re-spawn)")
	check(awake == live.size(), "woken stair enemies have their AI back on (%d/%d)" % [awake, live.size()])
	bf.queue_free()
	await get_tree().process_frame
	WorldState.dev_force_stair_enemies = false


func _test_stair_enemy_return_grounded() -> void:
	# Regression: a stair enemy remembered at an off-plane (mid-shaft/mid-air) y must come
	# back GROUNDED on the floor line as an ordinary zombie — not floating, solid, lodging
	# the player. This was the "enemy mid-air, dragged the player across the map" bug.
	print("[stair enemy returns grounded]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.dev_force_stair_enemies = true   # force one stair enemy per active stairwell
	WorldState.current_floor = 15; WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"; WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(15)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().process_frame
	var key := ""
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		key = z.spawn_key; break
	check(key != "", "a stair enemy exists to remember")
	# Forge a mid-air memory (as if recorded while emerging) and rebuild the floor.
	WorldState.zombie_positions[key] = {"x": 700.0, "y": 360.0, "facing": false, "hp": 3, "alert": 0.0}
	bf.queue_free()
	await get_tree().process_frame
	var bf2 = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf2)
	await get_tree().process_frame
	var found = null
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if z.spawn_key == key:
			found = z; break
	check(found != null, "the remembered stair enemy respawns")
	if found != null:
		check(absf(found.global_position.y - 370.0) < 0.5, "it returns GROUNDED on the stand line 370, not mid-air (%.1f)" % found.global_position.y)
		check(absf(found.base_walk_y - 370.0) < 0.5, "its home line is the floor, not the stale shaft y (%.1f)" % found.base_walk_y)
		check(not found.stair_mode, "it returns as an ordinary floor zombie, not re-caged in the shaft")
		check(found.get_collision_layer_value(1), "its body collision is back on")
	bf2.queue_free()
	await get_tree().process_frame
	WorldState.dev_force_stair_enemies = false


func _test_fire_spawns() -> void:
	# Hazard 3: a fire floor spawns one spreading fire field, alight at the stairwell.
	print("[fire spawns]")
	WorldState.new_game()
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_FIRE
	WorldState.current_run = 1   # LIGHT stage: an active fire (not a charred ruin)
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(15)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	var fields := get_tree().get_nodes_in_group("fire_field")
	check(fields.size() == 1, "exactly one fire field per fire floor (%d)" % fields.size())
	check(fields.size() == 1 and fields[0].any_burning(), "the fire is alight")
	# Run 1 = a small, PATCHY LIGHT fire (a few separate patches, not a solid span).
	check(fields.size() == 1 and fields[0].stage == WorldState.FIRE_LIGHT, "run-1 fire is the LIGHT stage")
	if fields.size() == 1:
		var bc: int = fields[0].burning_count()
		# "Small/patchy" vs a floor-wide BLAZE (~16-26 cells). The exact ignite-patch size
		# varies a little by seed, so bound it generously to distinguish LIGHT from BLAZE
		# without false-failing on a slightly larger patch (was 2..5 — flaked at 6).
		check(bc >= 1 and bc <= 12, "run-1 LIGHT fire is small/patchy (%d cells)" % bc)
	# One hazard at a time: no visible crates, no horde cluster.
	var vis_crates := 0
	for p in get_tree().get_nodes_in_group("barricade_prop"):
		if p.visible:
			vis_crates += 1
	check(vis_crates == 0, "no barricade crates on a fire floor")
	# Floor 15 is a MAINTENANCE floor (15 % 3 == 0): the maintenance-room door takes the
	# extinguisher's wall spot between the elevator and the right stairwell, so no canister
	# is mounted here — a maintenance door is placed instead.
	check(not WorldState.elevator_kit_placed.get("15:1", false), "no extinguisher on a maintenance floor")
	check(bf.get_node_or_null("MaintenanceDoor") != null, "a maintenance-room door is placed on a maintenance floor")
	# A maintenance floor NEVER offers a wall extinguisher; a normal floor's presence is
	# seeded (deterministic) and not guaranteed — some floors have none.
	check(not WorldState.floor_has_extinguisher(15), "maintenance floor never has a wall extinguisher")
	check(WorldState.floor_has_extinguisher(14) == WorldState.floor_has_extinguisher(14), "floor extinguisher presence is deterministic")
	# Floor 15 is a merchant floor; the fire keeps the merchant sheltering.
	check(bf._merchant_pending_fire, "the merchant shelters while the floor's on fire")
	check(bf.get_node_or_null("Merchant") == null, "no merchant comes out during the fire")
	# Put the whole floor's fire out — the merchant then emerges to trade.
	fields[0].char_all()
	bf._process(0.1)
	check(not bf._merchant_pending_fire, "with the fire out, the merchant is no longer sheltering")
	check(bf.get_node_or_null("Merchant") != null, "the merchant emerges once the fire is dealt with")
	bf.queue_free()
	await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE


# Every standing enemy spawns with its FEET on the corridor floor line (419) on the very first
# frame — no physics step needed. They used to spawn at the seed's 388 and wait to be lifted, so
# any paused or first frame showed them sunk 18px (the owner saw it in the lobby). Covers the
# corridor mix (run 3 = every type + bosses), the lobby, and the Floor 30 hallway.
func _test_enemies_stand_on_the_line_frame_zero() -> void:
	print("[enemies stand on the floor line (feet 419) from frame 0 — no physics needed]")
	var bad: Array = []
	var seen := 0
	var cases := []
	for s in [11, 22, 33, 44, 55, 66]:
		cases.append(["res://scenes/building_floors.tscn", 8, 3, s])
		cases.append(["res://scenes/building_floors.tscn", 18, 2, s])
		cases.append(["res://scenes/lobby.tscn", 0, 1, s])
	for c in cases:
		WorldState.new_game()
		WorldState.tutorial_completed = true
		WorldState.is_first_run = false
		WorldState.master_seed = int(c[3]) * 7919
		WorldState.current_run = int(c[2])
		WorldState.current_floor = int(c[1])
		var inst = load(c[0]).instantiate()
		get_tree().paused = true                       # no physics step can lift anything
		add_child(inst)
		for z in inst.find_children("*", "CharacterBody2D", true, false):
			if not z.is_in_group("zombie") or z.get("stair_mode"):
				continue                               # stair enemies lurk in the shaft by design
			var cs = z.get_node_or_null("CollisionShape2D")
			if cs == null or cs.shape == null:
				continue
			seen += 1
			var feet := int(round(cs.global_position.y + cs.shape.get_rect().end.y))
			if feet != 419:
				bad.append("%s f%d r%d %s feet %d" % [String(c[0]).get_file(), c[1], c[2], z.scene_file_path.get_file(), feet])
		inst.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
	check(seen > 20, "measured a real crowd (%d enemies)" % seen)
	check(bad.is_empty(), "every one's feet on 419 %s" % ("" if bad.is_empty() else str(bad)))


func _test_follower_unique_keys() -> void:
	# Residents used to share ONE key per floor: a second follower landing where the first was
	# killed inherited that kill record and vanished on your return. Keys are per-enemy now.
	print("[follower residents: one key per enemy]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.follower_node = null
	WorldState.current_floor = 12; WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"; WorldState.stair_spawn_side = "left"
	WorldState.seed_floor_door_states(12)
	WorldState.zombie_positions["followerR:12:13:300:370"] = {"x": 500.0, "y": 370.0, "facing": false, "hp": 3, "alert": 0.0}
	WorldState.zombie_positions["followerR:12:13:700:370"] = {"x": 800.0, "y": 370.0, "facing": false, "hp": 2, "alert": 0.0}
	WorldState.killed_zombies["followerR:12:13:300:370"] = {"floor": 12}     # the first one died here
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().process_frame
	var found: Array = []
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if bf.is_ancestor_of(z) and str(z.spawn_key).begins_with("followerR:12"):
			found.append(z.spawn_key)
	check(found == ["followerR:12:13:700:370"], "the living follower is restored, the dead one isn't (%s)" % str(found))
	for z in get_tree().get_nodes_in_group("stair_enemy"):
		if bf.is_ancestor_of(z) and z.spawn_key == "followerR:12:13:700:370":
			check(z.follow_origin == "13:700:370", "a restored resident keeps its origin slot (%s)" % z.follow_origin)
	# The key a live follower gets on arrival carries its origin, so it can't collide.
	var k: String = bf._follower_res_key(12, "13:700:370")
	check(k == "followerR:12:13:700:370", "resident key is per enemy (%s)" % k)
	bf.queue_free(); await get_tree().process_frame
	WorldState.zombie_positions.clear()
	WorldState.killed_zombies.clear()


func _test_followed_away_saved() -> void:
	# followed_away wasn't saved: after a load the floor a follower LEFT re-seeded it while it
	# also lived on as a resident where it followed you — a duplicate.
	print("[followed_away survives save/load]")
	WorldState.new_game()
	WorldState.followed_away["13:300:370"] = true
	WorldState.save_game("res://scenes/building_floors.tscn", false)
	WorldState.followed_away.clear()
	WorldState.load_game()
	check(WorldState.followed_away.has("13:300:370"), "an enemy that followed you away stays gone after a load")
	WorldState.followed_away.clear()


func _test_stair_gates() -> void:
	# A dead / scripted player could press W on the stairs and change floor (a death then lost
	# its game-over). And a pan torn down mid-way left `panning` stuck for the session.
	print("[stairs: only a player in control; pans never stick]")
	WorldState.new_game(); WorldState.tutorial_completed = true; WorldState.is_first_run = false
	WorldState.current_floor = 12; WorldState.spawn_source = ""
	WorldState.seed_floor_door_states(12)
	# Observable without leaving the floor: every stairwell barricaded + a crowbar in hand, so a
	# player IN CONTROL starts a pry (is_prying) — and one who isn't must not.
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_BARRICADE
	WorldState.add_to_inventory("035")
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().process_frame
	var p = bf.get_node("Player")
	var trig = null
	for n in bf.find_children("*", "Area2D", true, false):
		if n.has_method("_use_stairs") and n.process_mode != Node.PROCESS_MODE_DISABLED and n.direction == "down":
			trig = n
			break
	check(trig != null, "found a live down-stair trigger")
	if trig != null:
		check(WorldState.is_stair_blocked(trig._choke_floor()) and WorldState.has_crowbar(), "setup: barricaded + crowbar")
		for state in ["is_dead", "is_cutscene", "escaping", "is_lashing"]:
			p.set(state, true)
			trig._use_stairs()
			check(not trig.is_prying and WorldState.current_floor == 12,
				"a player with %s can't use the stairs" % state)
			trig._cancel_pry("")
			p.set(state, false)
		trig._use_stairs()
		check(trig.is_prying, "control: a player in control does start the pry")
		trig._cancel_pry("")
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE
	bf.queue_free(); await get_tree().process_frame
	for pan in [StairPan, BalconyPan]:
		var owner_node := Node.new()
		add_child(owner_node)
		pan.panning = true
		pan._pan_owner = owner_node
		owner_node.free()
		if pan == StairPan:
			pan.can_pan(11, "", "")
		else:
			pan.can_pan()
		check(not pan.panning, "%s: a pan whose scene died no longer blocks later pans" % pan.name)
		pan.panning = false


func _test_corridor_art() -> void:
	# The corridor's painted overlay (tools/art/corridor.py): one per section (high 21-29 / mid
	# 11-20 / low 1-10), a ruined version per run, sitting right ABOVE the TileMapLayer so doors,
	# stairs and the elevator still draw over it — in the live build AND the passive pan backdrop.
	print("[corridor art]")
	WorldState.new_game()
	WorldState.tutorial_completed = true
	WorldState.is_first_run = false
	var BF = load("res://scripts/building_floors.gd")
	for case in [[25, 1, "corridor_high.png"], [15, 2, "corridor_mid_r2.png"], [3, 3, "corridor_low_r3.png"]]:
		var f: int = case[0]
		WorldState.current_run = case[1]
		for passive in [false, true]:
			WorldState.current_floor = f
			var bf = load("res://scenes/building_floors.tscn").instantiate()
			bf.setup_floor = f
			bf.passive = passive
			add_child(bf)
			for i in range(2): await get_tree().process_frame
			var art = bf.get_node_or_null("CorridorArt")
			var tm = bf.get_node_or_null("TileMapLayer")
			var label := "floor %d run %d%s" % [f, case[1], " (backdrop)" if passive else ""]
			check(art is Sprite2D and art.texture != null and art.texture.resource_path.get_file() == case[2],
				"%s: corridor art %s" % [label, art.texture.resource_path.get_file() if art is Sprite2D and art.texture else "missing"])
			if art is Sprite2D and tm != null:
				check(art.get_index() == tm.get_index() + 1, "%s: drawn right above the tilemap" % label)
				var door = bf.get_node_or_null("apartment01")
				var elev = bf.get_node_or_null("Elevator")
				check(door != null and door.get_index() > art.get_index() and elev.get_index() > art.get_index(),
					"%s: doors + the elevator draw over it" % label)
				check(art.position == BF.CORRIDOR_ART_POS and art.texture.get_size() == Vector2(1120, 192),
					"%s: covers the band exactly (115,243 1120x192)" % label)
			bf.free()
			await get_tree().process_frame
	# the endpoint floors: the hallway (30) and the lobby (0), live + backdrop
	for case in [["res://scenes/hallway.tscn", 30, "corridor_hallway"], ["res://scenes/lobby.tscn", 0, "corridor_lobby"]]:
		for run in [1, 3]:
			WorldState.current_run = run
			for passive in [false, true]:
				WorldState.current_floor = case[1]
				var sc = load(case[0]).instantiate()
				sc.passive = passive
				add_child(sc)
				for i in range(2): await get_tree().process_frame
				var art = sc.get_node_or_null("CorridorArt")
				var tm = sc.get_node_or_null("TileMapLayer")
				var want: String = case[2] + (".png" if run == 1 else "_r3.png")
				var label := "%s run %d%s" % [case[2], run, " (backdrop)" if passive else ""]
				check(art is Sprite2D and art.texture != null and art.texture.resource_path.get_file() == want,
					"%s: %s" % [label, art.texture.resource_path.get_file() if art is Sprite2D and art.texture else "missing"])
				check(art is Sprite2D and tm != null and art.get_index() == tm.get_index() + 1, "%s: right above the tilemap" % label)
				sc.free()
				await get_tree().process_frame
	WorldState.current_run = 1
