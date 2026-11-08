extends Node

# Headless test for STEALTH SPACES, phase 1 — hiding (docs/STEALTH_SPACES.md): the plane table, the dead's sight, the entry rule, the finding rule, leaving,
# the grey screen (and that the camera never moves for it), the prompt, and the hiding places in a real flat. Run:
#   godot --headless res://tests/stealth_test.tscn

var failures: int = 0
const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const BIG := "res://scenes/enemy_zombie_big.tscn"
const SPOT_X := 330.0
# A character-trait-aware pair (docs/CHARACTERS.md: the Neighbour is 15 % quieter, so a walking step carries 102 px, not 120): a zombie GAP px behind, whose sight is pinned
# to SIGHT_PINNED, is outside its own sight, inside every character's walking step (>= 102) and outside every character's crouched step (<= 52).
const SIGHT_PINNED := 60.0
const GAP := 95.0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== stealth test ===")
	AllyCombat.performative = false
	_test_rules_table()
	await _test_sight()
	await _test_entry_refused_when_seen()
	await _test_finding()
	await _test_noise_link()
	await _test_leaving()
	await _test_interact_is_theirs()
	await _test_screen()
	await _test_prompt()
	await _test_hide_context()
	await _test_real_flat()
	await _test_shower_curtain()
	await _test_tub_is_not_a_plane()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- helpers -----------------------------------------------------------------------------------------------------------------------------

func _corridor() -> Node:
	WorldState.new_game()
	WorldState.is_scavenge_mode = false             # the combat pace: a normal step carries 120 px, a crouched one 45
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.dev_survivors = 0
	var quiet := 12
	for step in [0, 2, -2, 4, -4, 6, -6]:
		var f: int = 12 + step
		if f >= 2 and f <= 28 and WorldState.fire_intensity(f) < 0:
			quiet = f
			break
	WorldState.current_floor = quiet
	WorldState.seed_floor_door_states(quiet)
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


func _seconds(s: float) -> void:
	await get_tree().create_timer(s).timeout


## `_process` frames (a node that polls in `_process` has not run at all in the physics steps that catch up after a scene loads).
func _pframes(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A real input event, so "just pressed" is seen by both _process and _physics_process (as back_plane_test does).
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _zombie(bf: Node, x: float, scene: String = STANDARD) -> Node:
	var z = load(scene).instantiate()
	z.global_position = Vector2(x, 370.0 if scene == STANDARD else 374.0)
	bf.add_child(z)
	z.max_hp = 8
	z.current_hp = 8
	return z


func _spot(bf: Node, x: float = SPOT_X) -> StealthSpot:
	var s := StealthSpot.new()
	s.piece_id = "wardrobe_wood"
	s.noun = "wardrobe"
	s.verb = "Hide"
	s.how = "inside"
	s.noise = 40.0
	s.half_w = 23.0
	s.prompt_lift = 70.0
	bf.add_child(s)
	s.global_position = Vector2(x, 419.0)
	return s


## The player, standing at `x` and crouched, with the spot beside them; presses [W] the way a player does.
func _hide_at(bf: Node, spot: StealthSpot, x: float) -> Node:
	var p = bf.get_node("Player")
	p.global_position = Vector2(x, 386.0)
	p.is_crouching = true
	await _pframes(4)
	await _tap("move_up")
	return p


func _camera_zoom(p: Node) -> Vector2:
	var cam = p.get_node_or_null("Camera2D")
	return cam.zoom if cam != null else Vector2.ZERO


func _camera_offset(p: Node) -> Vector2:
	var cam = p.get_node_or_null("Camera2D")
	return cam.offset if cam != null else Vector2.INF


# --- the plane table + the numbers -------------------------------------------------------------------------------------------------------

func _test_rules_table() -> void:
	print("[the plane context table and the numbers]")
	var ok := true
	for k in ["lane", "back", "balcony", "cover", "hidden"]:
		ok = ok and Stealth.PLANES.has(k)
		for field in ["sees", "reach", "noise", "screen", "prompt"]:
			if not Stealth.PLANES.get(k, {}).has(field):
				ok = false
				print("    plane '%s' has no '%s'" % [k, field])
	check(ok, "every plane answers sees / reach / noise / screen / prompt")
	check(Stealth.PLANES["hidden"]["sees"] == "blocked" and Stealth.PLANES["lane"]["sees"] == "radius", "a hidden player is out of sight; the lane is seen by radius")
	check(Stealth.focus_for_gap(0.0) == 1.0 and Stealth.focus_for_gap(Stealth.ENEMY_FULL) == 1.0, "a dead thing within %d px is lit in full" % int(Stealth.ENEMY_FULL))
	check(Stealth.focus_for_gap(Stealth.ENEMY_GONE) == 0.0 and Stealth.focus_for_gap(1000.0) == 0.0, "…and is gone into the grey by %d px" % int(Stealth.ENEMY_GONE))
	var a := Stealth.focus_for_gap(130.0)
	var b := Stealth.focus_for_gap(200.0)
	check(a > b and a < 1.0 and b > 0.0, "…and fades smoothly between (130 px %.2f > 200 px %.2f)" % [a, b])
	check(Stealth.HIDE_PIECES.has("wardrobe_wood") and not Stealth.HIDE_PIECES.has("sofa"), "wardrobes hide you; a sofa does not (that is cover, phase 2)")
	var data: Dictionary = FurniturePlanner.data().get("items", {})
	var all_real := true
	for id in Stealth.HIDE_PIECES:
		if not data.has(id):
			all_real = false
			print("    hide piece '%s' is not in the furniture library" % id)
	check(all_real, "every hide piece is a real piece in the furniture library")


# --- sight ---------------------------------------------------------------------------------------------------------------------------------

func _test_sight() -> void:
	print("[A hidden player is outside the dead's sight — whatever their alert]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var p = bf.get_node("Player")
	# control: the same zombie at the same place DOES go for a player who is not hidden
	p.global_position = Vector2(SPOT_X, 386.0)
	var z0 = _zombie(bf, SPOT_X + 60.0)
	var chased := await _until(func(): return z0.state in ["chase", "attack"] and z0.prey == p, 90)
	check(chased, "(control) a zombie 60 px away goes for an unhidden player (%s)" % z0.state)
	z0.free()
	await _frames(2)
	p = await _hide_at(bf, spot, SPOT_X)
	check(p.conceal == Stealth.HIDDEN and p.hide_spot == spot, "[W] crouched at the wardrobe hides the player (%s)" % p.conceal)
	await _seconds(0.4)
	check(p.conceal == Stealth.HIDDEN, "…and the press that hid them does not also bring them out (the pack had that bug)")
	var z = _zombie(bf, SPOT_X + 60.0)
	await _frames(90)
	check(z.state not in ["chase", "attack"] and z.prey != p, "a zombie 60 px from the wardrobe does not see them (%s)" % z.state)
	z.global_position.x = SPOT_X + 20.0                     # inside its reach
	await _frames(90)
	check(z.state != "attack" and z.state != "chase", "…and standing right beside them it does not strike (%s)" % z.state)
	check(p.conceal == Stealth.HIDDEN, "…and merely standing there (it is not searching) does not find them either")
	z.free()
	await _frames(2)
	var zo = _zombie(bf, SPOT_X + 150.0)                    # a follower: locked on with no source (the 2000 'it knows' case), but further off than a search can reach
	await _frames(4)
	zo.alert_to_noise(12.0)
	await _frames(60)
	check(zo.state not in ["chase", "attack"], "an omniscient alert does not see them either (%s)" % zo.state)
	check(zo.alert_timer == 0.0 and not zo._alert_positional, "…the lock-on ENDS (it cannot find what it cannot see; left running it would charge the moment they came out): alert %.1f" % zo.alert_timer)
	check(zo.mind in ["investigate", "search"], "…and it looks about where it stands (%s)" % zo.mind)
	z = zo
	var big = _zombie(bf, SPOT_X - 50.0, BIG)
	big.detection_range = 160.0
	await _frames(90)
	check(big.state not in ["chase", "attack"], "a big zombie 50 px away, sight pinned at 160, does not see them either (%s)" % big.state)
	# come out: the dead see them again
	p.leave_hide()
	var seen_again := await _until(func(): return z.state in ["chase", "attack"] or big.state in ["chase", "attack"], 120)
	check(seen_again, "…and the moment they come out they are seen again")
	await _finish(bf)


func _test_entry_refused_when_seen() -> void:
	print("[You cannot hide from something that is looking at you]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var p = bf.get_node("Player")
	p.global_position = Vector2(SPOT_X, 386.0)
	p.is_crouching = true
	var z = _zombie(bf, SPOT_X + 80.0)
	var chasing := await _until(func(): return z.state in ["chase", "attack"], 90)
	check(chasing, "(setup) the zombie is on them (%s)" % z.state)
	var took: bool = p.enter_hide(spot)
	check(not took and p.conceal == Stealth.NONE and p.hide_spot == null, "hiding is refused while it is chasing them")
	check(Stealth.seen_by(p).size() == 1, "…because it is one of the dead that are looking for them")
	# it loses them (they get far away), then they can hide
	p.global_position = Vector2(SPOT_X, 386.0)
	z.free()
	await _frames(2)
	var z2 = _zombie(bf, SPOT_X + 400.0)
	await _frames(20)
	check(Stealth.seen_by(p).is_empty(), "a zombie that is not on them does not stop them hiding")
	check(p.enter_hide(spot), "…so they can")
	p.leave_hide()
	await _finish(bf)


# --- finding -------------------------------------------------------------------------------------------------------------------------------

func _test_finding() -> void:
	print("[A hiding place is a risk, not a wall: a search that ends beside it finds you; walking past does not]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	check(p.conceal == Stealth.HIDDEN, "(setup) hidden")
	# walking PAST: it investigates a noise beyond the hiding place, crossing right through it without ever stopping there
	var z = _zombie(bf, SPOT_X + 120.0)
	await _frames(4)
	EnemyMind.hear(z, SPOT_X - 120.0)
	var passed := await _until(func(): return z.global_position.x < SPOT_X - 70.0, 60 * 14)
	check(passed, "a zombie walks right through the place the player hides and out the other side (x %.0f, %s)" % [z.global_position.x, z.mind])
	check(p.conceal == Stealth.HIDDEN and float(z.get_meta("stealth_find_t", 0.0)) == 0.0, "…and walking past finds nothing (find %.2f)" % float(z.get_meta("stealth_find_t", 0.0)))
	await _until(func(): return z.mind == "search", 60 * 8)
	check(z.mind == "search" and absf(z.global_position.x - SPOT_X) > Stealth.FIND_RANGE, "it stops to search %d px away (x %.0f)" % [int(absf(z.global_position.x - SPOT_X)), z.global_position.x])
	await _seconds(Stealth.FIND_TIME + 0.5)
	check(p.conceal == Stealth.HIDDEN, "a search that far away does not find them either")
	z.free()
	await _frames(2)
	# a SEARCH that ends beside the wardrobe: it heard a noise 30 px from it
	var z2 = _zombie(bf, SPOT_X + 150.0)
	await _frames(4)
	EnemyMind.hear(z2, SPOT_X + 30.0)
	var found := await _until(func(): return p.conceal == Stealth.NONE, 60 * 12)
	check(found, "a zombie that searches 30 px from the wardrobe finds them (%s, find %.2f)" % [p.conceal, float(z2.get_meta("stealth_find_t", 0.0))])
	check(p.hide_spot == null, "…they are thrown out of the hiding place")
	var on_them := await _until(func(): return z2.state in ["chase", "attack"] and z2.prey == p, 120)
	check(on_them, "…and it is on them (%s)" % z2.state)
	await _finish(bf)


# --- noise: hiding, passing, coming out ------------------------------------------------------------------------------------------------------

## Hold a movement action for `secs` of real time (the player polls the held axis, as in play).
func _hold(action: String, secs: float) -> void:
	Input.action_press(action)
	await _seconds(secs)
	Input.action_release(action)
	await _frames(2)


## Hide at the spot, put one zombie `gap` px to the LEFT of the player (as if it had just walked past), and bring the player out the way a player does.
func _just_passed(bf: Node, spot: StealthSpot, gap: float, crouched_after: bool) -> Array:
	var p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	var z = _zombie(bf, SPOT_X - gap)
	z.DETECTION_RANGE = SIGHT_PINNED                         # its sight pinned short of the gap, so the test is about what it HEARS
	await _frames(30)
	return [p, z]


func _test_noise_link() -> void:
	print("[Stealth and noise are one system: hiding is silent, the way out is a footstep, and a footstep turns them round]")
	# (1) hiding is silent: a zombie 60 px away, standing still, is never alerted by a hidden player
	var bf = await _corridor()
	var spot := _spot(bf)
	var pz = await _just_passed(bf, spot, 60.0, true)
	var p = pz[0]
	var z = pz[1]
	await _seconds(2.0)
	check(p.conceal == Stealth.HIDDEN and z.alert_timer == 0.0 and z.mind == "", "a hidden player makes no noise: a zombie 60 px away is not alerted (alert %.1f, mind '%s')" % [z.alert_timer, z.mind])
	await _finish(bf)

	# (2) out and QUIET: crouched, a zombie 90 px behind does not hear a crouched step (45 px) …
	bf = await _corridor()
	spot = _spot(bf)
	pz = await _just_passed(bf, spot, GAP, true)
	p = pz[0]
	z = pz[1]
	await _seconds(0.5)
	p.leave_hide(false, true)
	check(p.is_crouching, "(setup) they come out of the wardrobe still crouched")
	await _hold("move_right", 0.6)
	check(z.mind == "" and z.alert_timer == 0.0 and z.state not in ["chase", "attack"], "crouched, creeping away from a zombie that has just passed, 95 px off (past its sight, inside a walk's reach): it does not hear a crouched step (mind '%s', alert %.1f, %s)" % [z.mind, z.alert_timer, z.state])
	await _finish(bf)

	# (3) out and LOUD: standing, a normal step (120 px) carries to the same zombie, and it turns round
	bf = await _corridor()
	spot = _spot(bf)
	pz = await _just_passed(bf, spot, GAP, false)
	p = pz[0]
	z = pz[1]
	await _seconds(0.5)
	p.leave_hide(false, true)
	p.is_crouching = false                                  # …and they stand and walk off, the way a player who forgets does
	z.animated_sprite.flip_h = true                         # (it was walking away from them: facing left)
	await _hold("move_right", 0.2)
	check(z.alert_timer > 0.0 and z._alert_positional, "standing and walking, the same zombie 95 px behind hears it (alert %.1f, positional %s)" % [z.alert_timer, str(z._alert_positional)])
	check(z.mind == "investigate" and z.mind_x > z.global_position.x, "…and turns round for it (%s toward x %.0f from %.0f)" % [z.mind, z.mind_x, z.global_position.x])
	var comes := await _until(func(): return z.state in ["chase", "attack"], 60 * 8)
	check(comes, "…and is on them again (%s)" % z.state)
	await _finish(bf)

	# (4) coming out is not silent, and how loud depends on WHAT you were hiding in: a wardrobe's door (40 px) is not a bath's water (55 px)
	bf = await _corridor()
	spot = _spot(bf)
	pz = await _just_passed(bf, spot, 20.0, true)
	p = pz[0]
	z = pz[1]
	z.mind = ""
	z.alert_timer = 0.0
	await _seconds(0.4)
	p.leave_hide(false, true)
	check(z.alert_timer > 0.0, "coming out of a wardrobe beside a zombie 20 px away is heard (alert %.1f)" % z.alert_timer)
	await _finish(bf)
	for pair in [["wardrobe_wood", false], ["bath", true]]:
		bf = await _corridor()
		spot = _spot(bf)
		var def: Dictionary = Stealth.HIDE_PIECES[pair[0]]
		spot.piece_id = pair[0]
		spot.noise = float(def["noise"])
		pz = await _just_passed(bf, spot, 40.0, true)
		p = pz[0]
		z = pz[1]
		z.mind = ""
		z.alert_timer = 0.0
		await _seconds(0.4)
		p.leave_hide(false, true)
		check((z.alert_timer > 0.0) == pair[1], "…%s, a zombie 40 px off: the way out %s heard (%d px of noise; alert %.1f)" % [pair[0], "is" if pair[1] else "is not", int(spot.noise), z.alert_timer])
		await _finish(bf)
	check(Stealth.HIDE_PIECES["bath"]["noise"] > Stealth.HIDE_PIECES["wardrobe_wood"]["noise"], "(the rule: water slopping off a bath is louder than a wardrobe's door)")

	# (5) a locked-on follower loses a hidden player and does NOT charge when they come out
	bf = await _corridor()
	spot = _spot(bf)
	p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	z = _zombie(bf, SPOT_X + 220.0)
	await _frames(4)
	z.alert_to_noise(12.0)                                   # it walked in after them, locked on
	await _seconds(0.5)
	check(z.alert_timer == 0.0 and z.state not in ["chase", "attack"], "a follower locked on to a hidden player loses them (alert %.1f, %s)" % [z.alert_timer, z.state])
	p.leave_hide(false, true)
	await _seconds(1.0)
	check(z.state not in ["chase", "attack"] or absf(z.global_position.x - p.global_position.x) < 110.0,
		"…and when they come out it does not charge across the room on the old lock-on (%s, %d px)" % [z.state, int(absf(z.global_position.x - p.global_position.x))])
	await _finish(bf)


# --- leaving -------------------------------------------------------------------------------------------------------------------------------

func _test_leaving() -> void:
	print("[Leaving: every input, a hit, damage, and the camera and screen come back]")
	var bf = await _corridor()
	WorldState.god_mode = false
	var spot := _spot(bf)
	var p = bf.get_node("Player")
	var base_zoom := _camera_zoom(p)
	check(base_zoom != Vector2.ZERO, "(setup) the player has a camera (zoom %s)" % str(base_zoom))
	for action in ["move_left", "move_right", "move_down", "move_up", "crouch_toggle", "interact", "attack", "push"]:
		p = await _hide_at(bf, spot, SPOT_X)
		await _seconds(0.4)
		if p.conceal != Stealth.HIDDEN:
			check(false, "(setup) hidden before pressing %s" % action)
			continue
		await _tap(action)
		await _frames(3)
		check(p.conceal == Stealth.NONE and p.hide_spot == null, "'%s' brings them out" % action)
		await _seconds(0.8)
		p.is_crouching = true
	# a hit
	p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	p.receive_hit(1)
	check(p.conceal == Stealth.NONE and p.hide_spot == null, "a hit throws them out of the wardrobe")
	await _seconds(0.8)
	# damage that does not come through a hit (a fall)
	p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	p.take_damage(1)
	check(p.conceal == Stealth.NONE, "damage of any kind throws them out")
	await _seconds(0.8)
	# the screen and camera are back
	var cleared := await _until(func(): return not is_instance_valid(p.get_node_or_null("StealthFx")), 240)
	check(cleared, "the grey layer frees itself once it has cleared")
	check(_camera_zoom(p).distance_to(base_zoom) < 0.001, "…and the camera is at its own zoom (%s vs %s)" % [str(_camera_zoom(p)), str(base_zoom)])
	# a freed player takes the screen with it
	WorldState.god_mode = true
	p.health_state = 0
	p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	var fx = p.get_node_or_null("StealthFx")
	check(fx != null and p.conceal == Stealth.HIDDEN, "(setup) hiding again")
	p.free()
	await get_tree().process_frame
	check(not is_instance_valid(fx), "freeing the player frees the grey layer (a scene change cannot leave it on)")
	await _finish(bf)


## Nothing else answers [interact] while the player is hidden: the press that brings them out must not also open the door beside the wardrobe.
func _test_interact_is_theirs() -> void:
	print("[A hidden player's [interact] brings them out — it opens nothing else]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var stub := InteractStub.new()
	bf.add_child(stub)
	stub.global_position = Vector2(SPOT_X + 10.0, 419.0)
	stub.add_to_group(InteractArbiter.GROUP)
	var p = bf.get_node("Player")
	p.global_position = Vector2(SPOT_X, 386.0)
	await _frames(2)
	check(InteractArbiter.answers(stub, true), "(control) an answerer beside the player answers when they are not hidden")
	p = await _hide_at(bf, spot, SPOT_X)
	await _seconds(0.4)
	check(p.conceal == Stealth.HIDDEN and not InteractArbiter.answers(stub, true) and not InteractArbiter.take(stub, true),
		"…and answers nothing while they are hidden")
	p.leave_hide(false, true)
	await _frames(2)
	check(InteractArbiter.answers(stub, true), "…and answers again once they are out")
	await _finish(bf)


class InteractStub extends Node2D:
	func interact_ready() -> bool:
		return true

	func interact_x() -> float:
		return global_position.x

	func interact_rank() -> int:
		return InteractArbiter.RANK_DOOR


# --- the screen ----------------------------------------------------------------------------------------------------------------------------

func _test_screen() -> void:
	print("[The grey screen: nothing but the player; a dead thing is a shadow as it nears; no static, no zoom]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var p = bf.get_node("Player")
	var base_zoom := _camera_zoom(p)
	var base_offset := _camera_offset(p)
	p = await _hide_at(bf, spot, SPOT_X)
	var fx: StealthFx = p.get_node_or_null("StealthFx")
	check(fx != null, "hiding puts the grey layer on the player")
	if fx == null:
		await _finish(bf)
		return
	check(fx.layer == 0 and fx.layer < HUD.layer, "…between the world and the HUD, so the HUD stays readable (layer %d, HUD %d)" % [fx.layer, HUD.layer])
	await _until(func(): return fx.intensity >= 0.999, 240)
	var st: Dictionary = fx.state()
	check(st["intensity"] >= 0.999, "it greys the world out fully (%.2f)" % st["intensity"])
	check(fx._mat != null and absf(float(fx._mat.get_shader_parameter("intensity")) - st["intensity"]) < 0.01, "…and hands that to the shader")
	# the look (owner: "really grey so that you can't see anything except for basically just the player… the static is bad… a really weird zoom")
	var code: String = StealthFx.SHADER_CODE
	check(code.contains("fog_near") and not code.contains("hash(") and not code.contains("tear") and not code.contains("static") and not code.contains("TIME"), "the picture is one flat grey: no static, no snow, nothing moving in the shader")
	check(StealthFx.FOG_NEAR.r > 0.45 and StealthFx.FOG_FAR.r > 0.3 and absf(StealthFx.FOG_NEAR.r - StealthFx.FOG_NEAR.b) < 0.06, "…a pale grey with no colour in it, never black (%s / %s)" % [str(StealthFx.FOG_NEAR), str(StealthFx.FOG_FAR)])
	check(StealthFx.GHOST <= 0.12, "…the room is only the barest ghost in it (%.2f)" % StealthFx.GHOST)
	check(_camera_zoom(p).distance_to(base_zoom) < 0.0001 and _camera_offset(p).distance_to(base_offset) < 0.0001, "the camera does not move at all (zoom %s, look %s)" % [str(_camera_zoom(p)), str(_camera_offset(p))])
	# the player: the layer redraws their own sprite frame, on the same screen place
	var vp := get_viewport()
	var ps: AnimatedSprite2D = p.animated_sprite
	var pc: AnimatedSprite2D = fx.player_copy()
	check(st["player_copy"] and pc != null and pc.visible, "the only thing in colour is the player: their sprite is copied over the grey")
	check(pc != null and pc.sprite_frames == ps.sprite_frames and pc.animation == ps.animation and pc.frame == ps.frame and pc.flip_h == ps.flip_h, "…the same animation, frame and way round (%s %d)" % [pc.animation if pc != null else "-", pc.frame if pc != null else -1])
	var want_at: Vector2 = (vp.get_canvas_transform() * ps.get_global_transform()).origin
	check(pc != null and pc.position.distance_to(want_at) < 1.0, "…on the player's own place on the screen (%s vs %s)" % [str(pc.position if pc != null else Vector2.INF), str(want_at)])
	check(pc != null and pc.modulate.a > 0.99, "…at full strength")
	check(st["dead"].is_empty(), "with nothing near there is no shadow")
	# a dead thing walks by: close = a black silhouette, far = gone into the grey
	var z = _zombie(bf, SPOT_X + 60.0)
	z.set_physics_process(false)                     # (it stands where it is — it is the screen being tested)
	await _seconds(0.8)
	st = fx.state()
	var near_w: float = float(st["dead"][0]["w"]) if st["dead"].size() > 0 else -1.0
	check(st["dead"].size() == 1 and near_w > 0.95, "a dead thing 60 px away is a full silhouette (w %.2f)" % near_w)
	var shadow: AnimatedSprite2D = null
	for id in fx._dead:
		shadow = fx._dead[id]["node"]
	check(shadow != null and shadow.modulate.r < 0.1 and shadow.modulate.g < 0.1 and shadow.modulate.b < 0.1 and shadow.modulate.a > 0.95, "…black, not a copy of its colours (%s)" % str(shadow.modulate if shadow != null else "-"))
	check(shadow != null and shadow.sprite_frames == z.animated_sprite.sprite_frames and shadow.position.distance_to((vp.get_canvas_transform() * z.animated_sprite.get_global_transform()).origin) < 1.0, "…in the shape the dead thing is drawn, where it is drawn")
	z.global_position.x = SPOT_X + 250.0
	await _seconds(1.2)
	st = fx.state()
	var mid: float = float(st["dead"][0]["w"]) if st["dead"].size() > 0 else -1.0
	check(mid > 0.05 and mid < 0.8, "…a fainter one at 250 px (w %.2f)" % mid)
	z.global_position.x = SPOT_X + 520.0
	await _seconds(1.4)
	st = fx.state()
	check(st["dead"].is_empty() and fx._dead.is_empty(), "…and once it has moved on it is gone into the grey (%d shadows, %d copies)" % [st["dead"].size(), fx._dead.size()])
	z.global_position.x = SPOT_X - 90.0
	await _seconds(0.9)
	check(fx.state()["dead"].size() == 1, "…and one that passes on the other side is a shadow too")
	z.free()
	await _seconds(1.2)
	check(fx._dead.is_empty(), "a dead thing that stops existing takes its shadow with it")
	# the screen coordinates are the world's: the grey is centred on the player
	var centre = fx._mat.get_shader_parameter("centre")
	var want: Vector2 = (vp.get_canvas_transform() * p.global_position) / vp.get_visible_rect().size
	check(centre != null and Vector2(centre).distance_to(want) < 0.02, "the lighter grey is centred on the player (%s vs %s)" % [str(centre), str(want)])
	# coming out clears the layer and leaves the camera exactly as it was
	p.leave_hide()
	await _until(func(): return not is_instance_valid(p.get_node_or_null("StealthFx")), 240)
	check(_camera_zoom(p).distance_to(base_zoom) < 0.001 and _camera_offset(p).distance_to(base_offset) < 0.001, "the camera is exactly as it was after the layer clears")
	await _finish(bf)


# --- the prompt ----------------------------------------------------------------------------------------------------------------------------

func _test_prompt() -> void:
	print("[A prompt where the player can hide]")
	var bf = await _corridor()
	var spot := _spot(bf)
	var p = bf.get_node("Player")
	WorldState.is_scavenge_mode = false
	p.global_position = Vector2(SPOT_X + 200.0, 386.0)
	p.is_crouching = false
	await _pframes(4)
	check(spot.prompt_text() == "", "far from the wardrobe there is no prompt")
	p.global_position = Vector2(SPOT_X + 10.0, 386.0)
	await _pframes(4)
	var t := spot.prompt_text()
	check(t.contains("Wardrobe") and t.to_lower().contains("crouch to hide"), "standing at it: the place teaches the verb ('%s')" % t)
	check(not t.contains("{"), "…with the key written as the player's own (no raw token)")
	p.is_crouching = true
	await _pframes(4)
	t = spot.prompt_text()
	check(t.contains("Wardrobe") and t.contains("Hide") and not t.to_lower().contains("crouch"), "crouched at it: 'Wardrobe  [W] Hide' ('%s')" % t)
	p.global_position = Vector2(SPOT_X + 23.0 + StealthSpot.REACH - 1.0, 386.0)
	await _pframes(4)
	check(spot.prompt_text() != "", "…it is offered right to the edge of its reach")
	p.global_position = Vector2(SPOT_X + 23.0 + StealthSpot.REACH + 6.0, 386.0)
	await _pframes(4)
	check(spot.prompt_text() == "", "…and not beyond it")
	p.global_position = Vector2(SPOT_X, 386.0)
	await _pframes(4)
	await _tap("move_up")
	await _seconds(0.5)
	check(p.conceal == Stealth.HIDDEN and spot.prompt_text().contains("Come out"), "inside, the prompt says how to come out ('%s')" % spot.prompt_text())
	# a scavenge-stance player at a wardrobe whose search is still live: [W] is the search's, so no hide prompt
	p.leave_hide()
	await _seconds(0.5)
	WorldState.is_scavenge_mode = true
	var bps := BackPlaneSpot_Stub.new()
	bps.global_position = Vector2(SPOT_X, 419.0)
	bf.add_child(bps)
	bps.add_to_group("back_plane_spot")
	await _pframes(4)
	check(spot.search_owns_the_key(p) and spot.prompt_text() == "", "a wardrobe you can still search, in scavenge stance: the search owns [W], no hide prompt")
	WorldState.is_scavenge_mode = false
	await _pframes(4)
	check(not spot.search_owns_the_key(p) and spot.prompt_text() != "", "…and in combat stance it hides")
	await _finish(bf)


## Stands in for back_plane_spot.gd: a spot with a live node, the player always near.
class BackPlaneSpot_Stub extends Node2D:
	func has_live_node() -> bool:
		return true

	func player_near(_p: Node2D) -> bool:
		return true


# --- a real flat ---------------------------------------------------------------------------------------------------------------------------

func _test_hide_context() -> void:
	print("[Hiding must make sense: only pieces a person would hide in, in the rooms they stand in]")
	var problems: Array = Stealth.hide_rule_problems()
	check(problems.is_empty(), "every hiding place in the table makes sense against the furniture library (%s)" % str(problems))
	var lib: Dictionary = FurniturePlanner.data().get("items", {})
	# the check CAN fail: a toilet, a sink, a sofa, a trunk, a wardrobe in a bathroom, a bath in a bedroom, a shower behind glass
	for bad in [
		["toilet", {"how": "in", "noun": "toilet", "verb": "Get in", "noise": 40.0}],
		["basin", {"how": "inside", "noun": "basin", "verb": "Hide", "noise": 40.0}],
		["sofa", {"how": "inside", "noun": "sofa", "verb": "Hide", "noise": 40.0}],
		["trunk", {"how": "inside", "noun": "trunk", "verb": "Hide", "noise": 40.0}],
		["linen_cupboard", {"how": "inside", "noun": "cupboard", "verb": "Hide", "noise": 40.0}],
		["wardrobe_wood", {"how": "in", "noun": "wardrobe", "verb": "Get in", "noise": 40.0}],
		["bath", {"how": "inside", "noun": "bath", "verb": "Hide", "noise": 55.0}],
		["bath", {"how": "nonsense", "noun": "bath", "verb": "Hide", "noise": 55.0}],
		["not_a_piece", {"how": "inside", "noun": "x", "verb": "Hide", "noise": 40.0}],
	]:
		var one: Array = Stealth.hide_rule_problems({bad[0]: bad[1]}, lib)
		check(not one.is_empty(), "a bad hiding place is refused: %s as '%s' (%s)" % [bad[0], bad[1]["how"], str(one.slice(0, 1))])
	# what is in the table is what a person would use
	check(Stealth.HIDE_PIECES.has("bath") and Stealth.HIDE_PIECES.has("wardrobe_wood"), "a bath and a wardrobe are places to hide")
	for never in ["toilet", "basin", "sofa", "linen_cupboard", "larder_tall", "shower_walkin", "trunk", "fridge_tall"]:
		check(not Stealth.HIDE_PIECES.has(never), "…and a %s is not" % never)


func _test_real_flat() -> void:
	print("[The hiding places a real flat gets]")
	var wardrobes := 0
	var baths := 0
	var flats := 0
	var bad := 0
	var did_bath := false
	var any_other := 0
	for f in [25, 20, 14, 9, 22, 17, 11, 27, 19, 6, 24, 18, 13, 8, 5]:
		for col in range(1, 6):
			if wardrobes >= 2 and baths >= 2 and flats >= 6 and did_bath:
				break
			var apt := "%d0%d" % [f, col]
			WorldState.dev_seed = 20261020
			WorldState.new_game()
			WorldState.dev_seed = 0
			WorldState.is_first_run = false
			WorldState.is_scavenge_mode = false
			WorldState.current_apartment_id = apt
			WorldState.current_floor = f
			WorldState.spawn_source = ""
			var room = load("res://scenes/room.tscn").instantiate()
			add_child(room)
			for i in range(4):
				await get_tree().physics_frame
			flats += 1
			var spots: Array = []
			for s in get_tree().get_nodes_in_group("stealth_spot"):
				if room.is_ancestor_of(s):
					spots.append(s)
			var bath_spot = null
			for s in spots:
				var def: Dictionary = Stealth.HIDE_PIECES.get(s.piece_id, {})
				var lo: float = room.LEFT_WALL_X
				var hi: float = room.LEFT_WALL_X + room.MODULE_WIDTH * room._span
				if def.is_empty() or not (s.global_position.x > lo and s.global_position.x < hi) or s.half_w < 15.0 or s.how != String(def["how"]):
					bad += 1
					print("    bad spot %s at x %.0f (flat %s)" % [s.name, s.global_position.x, apt])
				match s.piece_id:
					"bath":
						baths += 1
						bath_spot = s
						if s.piece_sprite == null or s.cover_from_row < 0 or s.feet_y == INF:
							bad += 1
							print("    the bath has no rim to draw over the player (flat %s)" % apt)
					"wardrobe_wood", "wardrobe_mirror", "wardrobe_small":
						wardrobes += 1
					_:
						any_other += 1
			# the player steps into a real bath: rises into the tub, the rim is over them, and they climb back out
			if bath_spot != null and not did_bath:
				did_bath = true
				var pl = room.get_node("Player")
				for z in get_tree().get_nodes_in_group("zombie"):          # (a flat's own dead would be chasing them: this is about the tub)
					if room.is_ancestor_of(z):
						z.free()
				pl.global_position.x = bath_spot.global_position.x
				pl.is_crouching = true
				await _pframes(4)
				var y0: float = pl.global_position.y
				check(bath_spot.offered_to(pl) and bath_spot.prompt_text().begins_with(bath_spot.label()), "at the %s: '%s'" % [bath_spot.label().to_lower(), bath_spot.prompt_text()])
				check(pl.enter_hide(bath_spot), "…the player can get in")
				await _seconds(0.5)
				check(pl.conceal == Stealth.HIDDEN and pl.global_position.y < y0 - 3.0, "…and they rise into the tub (y %.1f -> %.1f)" % [y0, pl.global_position.y])
				check(bath_spot.has_cover() and bath_spot._cover.z_index == 1 and bath_spot._cover.region_enabled, "…the bath's own rim is drawn over them (z %d)" % (bath_spot._cover.z_index if bath_spot.has_cover() else -1))
				if bath_spot.has_cover():
					var feet: float = pl.global_position.y + Stealth.PLAYER_FEET_DROP - 1.0       # the drawn feet (the sprite's bottom row is origin + 32)
					var head: float = pl.global_position.y - 10.0                                     # a crouched figure's top row
					var lip: float = bath_spot._cover.global_position.y
					if bath_spot.behind_curtain:
						check(lip < head - 4.0, "…a shower curtain hangs from above their head to the tub: the whole of them is behind it (curtain top %.0f, head %.0f)" % [lip, head])
					else:
						check(feet - lip >= 6.0 and lip - head >= 8.0, "…the lip hides their shins and not their head: %.0f px of them behind it, %.0f px above it" % [feet - lip, lip - head])
				var bath_def: Dictionary = Stealth.HIDE_PIECES["bath"]
				check(StealthSpot.lip_rows(bath_def, "bath_gold_b3") == 17 and StealthSpot.lip_rows(bath_def, "bath_tiled_b5") == 22 and StealthSpot.lip_rows(bath_def, "bath_new_b1") == 20, "…each drawn bath has its own lip row (gold 17, tiled 22, an unknown one the default 20)")
				check(StealthSpot.variant_key("bath_curtain_b4") == "bath_curtain" and bath_def["curtain"].has("bath_curtain") and not bath_def["curtain"].has("bath_tiled"), "…only the bath with its curtain DRAWN is hidden behind it (the pulled-back one hides by its lip)")
				check(absf(pl.lane_position().y - y0) < 0.6, "…a save made in the tub loads on the floor (lane y %.1f vs %.1f)" % [pl.lane_position().y, y0])
				pl.leave_hide(false, true)
				await _seconds(0.5)
				check(not bath_spot.has_cover() and absf(pl.global_position.y - y0) < 0.6, "…they climb back out, and the rim goes (y %.1f)" % pl.global_position.y)
			room.free()
			await get_tree().process_frame
	check(flats >= 6, "(setup) %d flats built" % flats)
	check(wardrobes >= 1, "a wardrobe in a real bedroom is a place to hide (%d)" % wardrobes)
	check(baths >= 1 and did_bath, "…and so is a bath in a real bathroom (%d)" % baths)
	check(any_other == 0, "…and nothing else is (%d other hiding places)" % any_other)
	check(bad == 0, "…each inside its flat, on the right kind of piece, with a real width (%d bad)" % bad)
	# the spots are only on live flats: a passive room (the balcony pan's backdrop) lays none
	var passive_room = load("res://scenes/room.tscn").instantiate()
	passive_room.passive = true
	add_child(passive_room)
	for i in range(4):
		await get_tree().physics_frame
	var n := 0
	for s in get_tree().get_nodes_in_group("stealth_spot"):
		if passive_room.is_ancestor_of(s):
			n += 1
	check(n == 0, "a pan backdrop (passive room) offers no hiding places (%d)" % n)
	passive_room.free()
	await get_tree().process_frame
	# and no bare patch of wall is a place to hide: a flat has no spot that is not a piece
	WorldState.dev_seed = 20261020
	WorldState.new_game()
	WorldState.dev_seed = 0
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_apartment_id = "2001"
	WorldState.current_floor = 20
	WorldState.spawn_source = ""
	var room2 = load("res://scenes/room.tscn").instantiate()
	add_child(room2)
	await _pframes(8)
	var by_wall := 0
	for sp in get_tree().get_nodes_in_group("stealth_spot"):
		if room2.is_ancestor_of(sp) and not Stealth.HIDE_PIECES.has(sp.piece_id):
			by_wall += 1
	check(by_wall == 0, "arriving at a flat's front door offers no 'hide against the wall' (%d spots that are not a piece)" % by_wall)
	room2.free()
	await get_tree().process_frame


## A shower-bath with its curtain drawn: the player hides BEHIND it (owner: "the showers too… hide behind those, slicing behind the curtains like with stairwells").
func _test_shower_curtain() -> void:
	print("[Behind the shower curtain]")
	var found = null
	var room = null
	for f in [14, 25, 20, 9, 22, 17, 11, 27, 19, 6, 24, 18, 13, 8, 5, 26, 21, 16, 12, 10, 7]:
		for col in range(1, 6):
			WorldState.dev_seed = 20261020
			WorldState.new_game()
			WorldState.dev_seed = 0
			WorldState.is_first_run = false
			WorldState.is_scavenge_mode = false
			WorldState.current_apartment_id = "%d0%d" % [f, col]
			WorldState.current_floor = f
			WorldState.spawn_source = ""
			room = load("res://scenes/room.tscn").instantiate()
			add_child(room)
			for i in range(4):
				await get_tree().physics_frame
			for sp in get_tree().get_nodes_in_group("stealth_spot"):
				if room.is_ancestor_of(sp) and sp.behind_curtain:
					found = sp
			if found != null:
				break
			room.free()
			await get_tree().process_frame
		if found != null:
			break
	check(found != null, "a flat with a shower-bath and its curtain drawn exists (and is a place to hide)")
	if found == null:
		return
	check(found.noun == "shower" and found.cover_from_row == 0 and found.cover_alpha < 1.0 and found.cover_alpha > 0.5, "the whole curtain is the cover, a shade less than opaque (%.2f), and the place is called a shower" % found.cover_alpha)
	var pl = room.get_node("Player")
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			z.free()
	WorldState.is_scavenge_mode = false
	pl.global_position.x = found.global_position.x
	pl.is_crouching = true
	await _pframes(4)
	check(found.prompt_text() == "Shower   [%s] Hide behind the curtain" % HUD.action_key_name("move_up", "W"), "at the curtain: 'Shower   [W] Hide behind the curtain' ('%s')" % found.prompt_text())
	pl.is_crouching = false
	await _pframes(4)
	check(found.prompt_text().contains("Crouch to hide behind the curtain"), "standing, the place teaches the verb ('%s')" % found.prompt_text())
	pl.is_crouching = true
	await _pframes(2)
	check(pl.enter_hide(found), "…the player can step in")
	await _pframes(2)
	var early: float = found._cover.modulate.a if found.has_cover() else -1.0
	await _seconds(0.5)
	var settled: float = found._cover.modulate.a if found.has_cover() else -1.0
	check(early >= 0.0 and early < settled - 0.15, "the curtain comes over them as they step in, not in a pop (alpha %.2f -> %.2f)" % [early, settled])
	check(absf(settled - found.piece_sprite.modulate.a * found.cover_alpha) < 0.02, "…and settles a shade clear of opaque, so a dark figure shows through the plastic (%.2f)" % settled)
	check(found._cover.z_index == 1 and found._cover.region_rect.position.y == 0.0, "…the curtain is over the player (z %d, from its first row)" % found._cover.z_index)
	var head: float = pl.global_position.y - 10.0
	check(found._cover.global_position.y < head - 4.0, "…from above their head down to the tub (curtain top %.0f, head %.0f)" % [found._cover.global_position.y, head])
	var cover = found._cover
	pl.leave_hide(false, true)
	await _pframes(2)
	check(not found.has_cover() and is_instance_valid(cover) and cover.modulate.a < settled, "stepping out, the curtain lets go (it fades, and the spot no longer holds it)")
	await _seconds(0.5)
	check(not is_instance_valid(cover) or cover.is_queued_for_deletion(), "…and is gone")
	room.free()
	await get_tree().process_frame


## A real flat with a bath (not the curtain one), its dead cleared. Returns [room, spot] or [null, null].
func _bath_flat() -> Array:
	for f in [17, 14, 25, 20, 9, 22, 11, 27, 19, 6, 24, 18, 13, 8, 5, 26, 21, 16, 12, 10, 7]:
		for col in range(1, 6):
			WorldState.dev_seed = 20261020
			WorldState.new_game()
			WorldState.dev_seed = 0
			WorldState.is_first_run = false
			WorldState.is_scavenge_mode = false
			WorldState.current_apartment_id = "%d0%d" % [f, col]
			WorldState.current_floor = f
			WorldState.spawn_source = ""
			var room = load("res://scenes/room.tscn").instantiate()
			add_child(room)
			for i in range(4):
				await get_tree().physics_frame
			for sp in get_tree().get_nodes_in_group("stealth_spot"):
				if room.is_ancestor_of(sp) and sp.piece_id == "bath" and not sp.behind_curtain:
					for z in get_tree().get_nodes_in_group("zombie"):
						if room.is_ancestor_of(z):
							z.free()
					return [room, sp]
			room.free()
			await get_tree().process_frame
	return [null, null]


## Owner, on a playtest: "When you press W to get in the tub, that becomes a new Y plane and I could move left right all the way across the apartment."
## The lane is the player's walking line; a hide raises them off it and a leave must ALWAYS put them back — however fast the presses.
func _test_tub_is_not_a_plane() -> void:
	print("[The tub is not a new floor]")
	var found: Array = await _bath_flat()
	var room = found[0]
	var bath = found[1]
	check(room != null, "(setup) a flat with a bath")
	if room == null:
		return
	var pl = room.get_node("Player")
	WorldState.god_mode = true
	pl.global_position.x = bath.global_position.x
	pl.is_crouching = true
	await _pframes(4)
	var y0: float = pl.global_position.y
	# 1. the regression: out and back in before the first climb has finished must not store a half-climb as the floor
	check(pl.enter_hide(bath), "the player gets in")
	await _seconds(0.12)
	var mid: float = pl.global_position.y
	check(mid < y0 and mid > y0 - 60.0 and absf(mid - y0) > 0.5, "…and is part-way up the side (y %.1f of %.1f)" % [mid, y0])
	pl.leave_hide(false, true)
	await _seconds(0.1)
	check(pl.enter_hide(bath), "…out and straight back in")
	check(absf(pl.lane_position().y - y0) < 0.6, "…the floor they stand on is still the floor (lane y %.1f, floor %.1f)" % [pl.lane_position().y, y0])
	await _seconds(0.9)
	check(pl.conceal == Stealth.HIDDEN and absf(pl._hide_return_y - y0) < 0.6, "…hidden, with the walking line remembered once (%.1f vs %.1f)" % [pl._hide_return_y, y0])
	pl.leave_hide(false, true)
	await _seconds(0.9)
	check(pl.conceal == Stealth.NONE and absf(pl.global_position.y - y0) < 0.6 and pl._hide_return_y == 0.0, "…and out for good they are back on the floor (y %.1f vs %.1f, remembered %.1f)" % [pl.global_position.y, y0, pl._hide_return_y])
	# 2. a stress run: random W / A / D taps with random gaps, then walk the whole flat — the player must never be on any line but the floor
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var worst := 0.0
	var stuck_off := 0
	var bad_walk := 0
	var runs := 24
	for run_i in range(runs):
		pl.global_position = Vector2(bath.global_position.x + rng.randf_range(-10.0, 10.0), y0)
		pl.is_crouching = true
		await _pframes(2)
		var n: int = rng.randi_range(3, 9)
		for k in range(n):
			var pick: int = rng.randi_range(0, 3)
			var act: String = ["move_up", "move_up", "move_left", "move_right"][pick]
			await _tap(act)
			await _seconds(rng.randf_range(0.0, 0.5))
			# the invariant: when no hide is in progress the player is on the floor
			if pl.conceal == Stealth.NONE and pl._hide_return_y == 0.0:
				worst = maxf(worst, absf(pl.global_position.y - y0))
		if pl.conceal == Stealth.HIDDEN:
			pl.leave_hide(false, true)
		await _seconds(1.0)
		if pl.conceal != Stealth.NONE or pl._hide_return_y != 0.0 or absf(pl.global_position.y - y0) > 0.6:
			stuck_off += 1
			print("    run %d ended off the floor: conceal %d, remembered %.1f, y %.1f vs %.1f" % [run_i, pl.conceal, pl._hide_return_y, pl.global_position.y, y0])
		# and the old symptom: walk across the flat on the floor
		var x_before: float = pl.global_position.x
		await _hold("move_right", 0.6)
		if absf(pl.global_position.y - y0) > 0.6 or pl.global_position.x <= x_before:
			bad_walk += 1
	check(stuck_off == 0, "after %d runs of fast W / A / D presses the player was never left off the floor (%d were)" % [runs, stuck_off])
	check(worst < 0.6, "…and was on the floor at every check whenever no hide was under way (worst %.2f px off)" % worst)
	check(bad_walk == 0, "…and could always walk the flat on the floor (%d walks left the line or went nowhere)" % bad_walk)
	WorldState.god_mode = false
	room.free()
	await get_tree().process_frame
