extends Node

# Headless test for THE DEAD THINK A LITTLE (docs/NPC_AI.md "Enemy intelligence"): a noise tells a zombie WHERE (it
# investigates the source and searches), it keeps hunting the place it last saw you then gives up, the dead near a
# lunge turn toward it, and it bites the NEARER meal — a survivor or you. Run:
#   godot --headless res://tests/enemy_mind_test.tscn

var failures: int = 0
const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const BIG := "res://scenes/enemy_zombie_big.tscn"
const SPITTER := "res://scenes/enemy_zombie_spitter.tscn"
const CRAWLER := "res://scenes/enemy_zombie_crawler.tscn"
const ENEMY_CROWD := preload("res://scripts/enemy_crowd.gd")
var _n: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== enemy mind test ===")
	await _test_noise_is_where()
	await _test_legacy_alert_still_knows()
	await _test_lose_the_player()
	await _test_spotted_spreads()
	await _test_prey_is_the_nearer_meal()
	await _test_other_types()
	await _test_scripted_and_noise_scope()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _corridor() -> Node:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.dev_survivors = 0
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			z.free()
	for s in get_tree().get_nodes_in_group("survivor"):
		if bf.is_ancestor_of(s):
			s.free()
	return bf


func _finish(bf: Node) -> void:
	WorldState.god_mode = false
	bf.free()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _zombie(bf: Node, x: float, scene: String = STANDARD, frozen: bool = false) -> Node:
	var z = load(scene).instantiate()
	z.global_position = Vector2(x, 370.0 if scene == STANDARD else 374.0)
	bf.add_child(z)
	z.max_hp = 8
	z.current_hp = 8
	if frozen:
		z.set_physics_process(false)
	return z


func _hider(bf: Node, x: float) -> Survivor:
	var key := "mind:%d" % _n
	_n += 1
	var rec := {"key": key, "role": "hider", "floor": 12, "apt": "", "look": 3, "weapon": "", "ammo": 0, "gift": "", "gift_n": 0,
		"hp": 3, "max_hp": 3, "dead": false, "x": -1.0, "post": x, "post_kind": "", "spot": 0.5, "met": 0, "aided": false,
		"calm": false, "gave": false, "quest": ""}
	WorldState.survivors[key] = rec
	return Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, x)


# --- noise = where ------------------------------------------------------------------------------

func _test_noise_is_where() -> void:
	print("[A NOISE tells it WHERE: it walks to the source, searches, gives up — it does not learn where YOU are]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(300.0, 386.0)
	var z = _zombie(bf, 800.0)
	await _frames(5)
	WorldState.emit_noise(Vector2(500.0, 386.0), 2000.0, 1.0)
	check(z.alert_timer > 0.0 and z._alert_positional, "it is alerted, and the alert is POSITIONAL")
	check(z.mind == "investigate" and is_equal_approx(z.mind_x, 500.0), "it will INVESTIGATE x=500 (the noise), not x=300 (the player): %s %.0f" % [z.mind, z.mind_x])
	check(z.ai_tell != null and z.ai_tell.kind == "search", "…and marks '?' over its head")
	await _frames(30)
	check(z.global_position.x < 800.0 and z.state != "chase", "it walks toward the noise, not 'chasing' (x %.0f, %s)" % [z.global_position.x, z.state])
	check(z.velocity.x < 0.0, "…leftward")
	var arrived := await _until(func(): return z.mind == "search", 900)
	check(arrived, "it arrives and SEARCHES (%s at x %.0f)" % [z.mind, z.global_position.x])
	check(absf(z.global_position.x - 500.0) <= 24.0, "…at the noise's spot (x %.0f)" % z.global_position.x)
	var flips := 0
	var last: bool = z.animated_sprite.flip_h
	for i in 260:
		await get_tree().physics_frame
		if z.animated_sprite.flip_h != last:
			flips += 1
			last = z.animated_sprite.flip_h
		if z.mind == "":
			break
	check(flips >= 2, "while searching it turns its head (%d looks)" % flips)
	check(z.mind == "" and z.state == "idle", "…then gives up and stands (%s / %s)" % [z.mind, z.state])
	check(z.state != "chase" and absf(z.global_position.x - 500.0) < 40.0, "it never went for the player")
	await _finish(bf)


func _test_legacy_alert_still_knows() -> void:
	print("[A source-less alert (the dead mustered at a pried stairwell) still knows where you are]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(300.0, 386.0)
	var z = _zombie(bf, 800.0)
	await _frames(5)
	z.alert_to_noise(12.0)
	check(not z._alert_positional, "a source-less alert is not positional")
	await _frames(20)
	check(z.state == "chase" and z.prey == p, "it chases the player from 500 px (%s)" % z.state)
	check(z.ai_tell != null and z.ai_tell.kind == "alert", "…marking '!'")
	await _finish(bf)


func _test_lose_the_player() -> void:
	print("[LOSING you: it goes to where it last saw you, searches there, gives up]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(330.0, 386.0)
	var z = _zombie(bf, 400.0)
	await _until(func(): return z.state in ["chase", "attack"], 60)
	check(z.state in ["chase", "attack"] and z.prey == p, "inside its sight (<100 px) it goes for the player (%s)" % z.state)
	check(z.ai_tell != null and z.ai_tell.kind == "alert", "'!' as it commits")
	await _frames(20)
	var seen_at: float = z._seen_x
	check(absf(seen_at - 330.0) < 1.0, "it remembers where it last saw them (%.0f)" % seen_at)
	p.global_position = Vector2(900.0, 386.0)                 # gone: 500 px away
	await _until(func(): return z.mind != "", 120)
	check(z.mind == "investigate" and absf(z.mind_x - seen_at) < 1.0, "it heads for the LAST-SEEN spot, not for you (%s %.0f)" % [z.mind, z.mind_x])
	check(z.global_position.x > 330.0 or z.velocity.x <= 0.0, "(it does not follow them to x=900)")
	var searched := await _until(func(): return z.mind == "search", 900)
	check(searched, "it gets there and searches")
	var gave_up := await _until(func(): return z.mind == "", 400)
	check(gave_up and z.state == "idle", "…then gives up (%s)" % z.state)
	check(z.global_position.x < 450.0, "and it never came after them (x %.0f)" % z.global_position.x)
	await _finish(bf)


func _test_spotted_spreads() -> void:
	print("[SPOTTED: the dead standing near a lunge turn toward it]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(430.0, 386.0)
	var near = _zombie(bf, 500.0)                              # 70 px: inside its sight
	var friend = _zombie(bf, 600.0)                            # 170 px from the player: outside its own sight, inside 170 of `near`
	var far_friend = _zombie(bf, 900.0)
	await _frames(30)
	check(near.state in ["chase", "attack"], "the near one commits (%s)" % near.state)
	check(friend.mind == "investigate" or friend.state == "chase", "…and the one beside it turns toward the commotion (%s)" % friend.mind)
	check(absf(friend.mind_x - 430.0) < 60.0 or friend.state == "chase", "…toward where the player was (%.0f)" % friend.mind_x)
	check(far_friend.mind == "" and far_friend.state == "idle", "one far off does not (%s)" % far_friend.mind)
	check(near._spread_cd > 0.0, "(it won't raise the alarm again for a few seconds)")
	await _finish(bf)


# --- prey --------------------------------------------------------------------------------------

func _test_prey_is_the_nearer_meal() -> void:
	print("[PREY: it bites the nearer meal — a survivor, or you]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(1100.0, 386.0)
	var s := _hider(bf, 250.0)                                 # near the corridor's end: a hider runs, then is cornered there
	var z = _zombie(bf, 340.0)                                 # 90 px from the survivor, far from the player
	await _frames(10)
	check(z.prey == s, "alone with a survivor, the survivor is its prey")
	check(not ENEMY_CROWD.engaged(z), "…and it is not part of the PLAYER's crowd")
	var bitten := await _until(func(): return s.current_hp < 3 or s.is_dead, 900)
	check(bitten, "it bites the survivor once it catches it (hp %d)" % s.current_hp)
	await _until(func(): return s.is_dead, 900)
	check(s.is_dead and not s.is_in_group("survivor_prey"), "…and a dead survivor is no longer prey")
	await _frames(5)
	check(z.prey == null or z.prey == p or z.mind != "" or z.state == "idle", "the dead one is free of it (prey %s)" % str(z.prey))
	z.free()
	s.free()
	# the player nearer
	var s2 := _hider(bf, 170.0)                                # (cornered at the wall: it cannot run out of the dead one's sight)
	p.global_position = Vector2(215.0, 386.0)
	var z2 = _zombie(bf, 260.0)                                # 45 px from the player, 90 from the survivor
	await _frames(10)
	check(z2.prey == p, "the player nearer (45 px vs 90 px): it goes for the PLAYER")
	check(ENEMY_CROWD.engaged(z2), "…and counts in the player's crowd")
	p.global_position = Vector2(1100.0, 386.0)                 # walk the player away
	var turned := await _until(func(): return z2.prey == s2, 240)
	check(turned, "…walk the player away and it turns on the survivor")
	await _finish(bf)


func _test_other_types() -> void:
	print("[TYPES: the big one bites a survivor for 2; a spitter ignores survivors; a crawler bites for double]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(1100.0, 386.0)
	var s := _hider(bf, 170.0)
	s.current_hp = 9
	s.max_hp = 9
	var big = _zombie(bf, 250.0, BIG)                          # 80 px off
	await _frames(10)
	check(big.prey == s, "a BIG zombie goes for the nearer survivor too")
	var hit := await _until(func(): return s.current_hp < 9, 900)
	check(hit and 9 - s.current_hp == 2, "…and its swing does 2 (hp 9 → %d)" % s.current_hp)
	big.free()
	s.free()
	var s2 := _hider(bf, 170.0)
	s2.current_hp = 9
	s2.max_hp = 9
	var sp = _zombie(bf, 250.0, SPITTER)
	await _frames(240)
	check(sp.prey != s2 and s2.current_hp == 9, "a SPITTER never targets a survivor (prey %s, hp %d)" % [str(sp.prey), s2.current_hp])
	sp.free()
	var cr = _zombie(bf, 250.0, CRAWLER)
	var hit2 := await _until(func(): return s2.current_hp < 9, 900)
	check(hit2 and 9 - s2.current_hp == 2, "a CRAWLER's bite is double (hp 9 → %d)" % s2.current_hp)
	cr.free()
	await _finish(bf)


func _test_scripted_and_noise_scope() -> void:
	print("[SCOPE: the tutorial's scripted dead don't think; a survivor's noise doesn't carry to other floors]")
	var bf = await _corridor()
	var p = bf.get_node("Player")
	p.global_position = Vector2(300.0, 386.0)
	var z = _zombie(bf, 800.0, STANDARD, true)
	z.tutorial_scripted = true
	WorldState.emit_noise(Vector2(500.0, 386.0), 2000.0, 1.0)
	check(z.mind == "", "a scripted zombie has no mind of its own")
	z.free()
	var riser = _zombie(bf, 800.0, STANDARD, true)
	riser.riser_phase = "lying"
	WorldState.emit_noise(Vector2(500.0, 386.0), 2000.0, 1.0)
	check(riser.mind == "", "…nor one lying there as a riser")
	riser.free()
	WorldState.pending_stair_pulls.clear()
	WorldState.current_floor = 12
	WorldState.emit_noise(Vector2(200.0, 386.0), 2000.0, 1.0, false)
	check(WorldState.pending_stair_pulls.is_empty(), "a survivor's shot by a stairwell does not pull the floors above/below")
	WorldState.emit_noise(Vector2(200.0, 386.0), 2000.0, 1.0)
	check(not WorldState.pending_stair_pulls.is_empty(), "…the PLAYER's does (unchanged)")
	WorldState.pending_stair_pulls.clear()
	await _finish(bf)
