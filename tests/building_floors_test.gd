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
	await _test_stair_horde_spawns()
	await _test_fire_spawns()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


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
	# Wait for the zombie's move_and_slide depenetration to actually SETTLE rather
	# than assuming a fixed frame count — a fixed wait made this test flaky under
	# load, failing intermittently with a mid-flight Y.
	var settled := -1.0
	var prev := -999.0
	for i in range(180):
		await get_tree().process_frame
		var cur := -1.0
		for z in get_tree().get_nodes_in_group("zombie"):
			if not z.is_in_group("pan_scenery"):
				cur = z.global_position.y
				break
		if cur > 0.0 and is_equal_approx(cur, prev):
			settled = cur
			break
		prev = cur
	check(settled > 0.0, "a live zombie exists to measure (%.1f)" % settled)
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
	# Enabled: pans between real floors (not into the lobby / past the top).
	check(sp.ENABLED, "StairPan is enabled")
	check(not sp.can_pan(0), "no pan into the lobby (floor 0)")
	check(not sp.can_pan(30), "no pan up to the hallway (floor 30)")


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


func _test_stair_horde_spawns() -> void:
	# Hazard 2: a horde stairwell spawns a cluster of live zombies at the steps
	# (both active stairwells in dev horde mode), in the "stair_horde" group.
	print("[stair horde spawns]")
	WorldState.new_game()
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_HORDE   # every stairwell a horde
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	WorldState.stair_spawn_side = "left"
	WorldState.pending_pry_arrival_floor = -1
	WorldState.seed_floor_door_states(15)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	var horde := get_tree().get_nodes_in_group("stair_horde")
	# Two active stairwells x 4-7 each.
	check(horde.size() >= 8 and horde.size() <= 14, "a horde cluster spawns at each stairwell (%d)" % horde.size())
	var all_at_ends := true
	for z in horde:
		if z.global_position.x > 550.0 and z.global_position.x < 850.0:
			all_at_ends = false   # mid-corridor, not by a stairwell
	check(all_at_ends, "horde zombies cluster by the stairwells, not mid-corridor")
	# No VISIBLE barricade crates while in horde mode (one hazard at a time; the
	# self-hiding props may exist but must not show).
	var vis_crates := 0
	for p in get_tree().get_nodes_in_group("barricade_prop"):
		if p.visible:
			vis_crates += 1
	check(vis_crates == 0, "no visible barricade crates in horde mode (%d)" % vis_crates)
	# A red echo cue radiates from each horde stairwell, and each is a warn target.
	check(get_tree().get_nodes_in_group("horde_echo").size() == 2,
		"a horde echo cue spawns at each stairwell (%d)" % get_tree().get_nodes_in_group("horde_echo").size())
	check(bf._horde_warn_targets.size() == 2, "both horde stairwells are approach-warn targets")
	bf.queue_free()
	await get_tree().process_frame
	WorldState.dev_hazard_mode = WorldState.DEV_HAZARD_NONE


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
		check(bc >= 2 and bc <= 5, "run-1 LIGHT fire is small/patchy (%d cells)" % bc)
	# One hazard at a time: no visible crates, no horde cluster.
	var vis_crates := 0
	for p in get_tree().get_nodes_in_group("barricade_prop"):
		if p.visible:
			vis_crates += 1
	check(vis_crates == 0, "no barricade crates on a fire floor")
	check(get_tree().get_nodes_in_group("stair_horde").is_empty(), "no horde on a fire floor")
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
