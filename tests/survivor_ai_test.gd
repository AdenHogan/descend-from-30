extends Node

# Headless test for the SURVIVORS (docs/NPC_AI.md): who is where, how they think, how they fight. Every pattern the doc
# promises is asserted here by running the real thing. Since owner round 41 their fighting is THEATRE (AllyCombat.performative:
# the flash of a blow, none of its weight) — the first half of this file runs the OLD half-damage fight with that switch OFF
# (it is still the maths behind the switch, and the patterns — alert → engage → return — are the same either way); the second
# half pins the theatre itself and the RESCUE events, with it on.
#   godot --headless res://tests/survivor_ai_test.tscn

var failures: int = 0
var _n: int = 0
const STANDARD := "res://scenes/enemy_zombie_standard.tscn"
const ENEMY_HURT := preload("res://scripts/enemy_hurt.gd")


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== survivor AI test ===")
	AllyCombat.performative = false                  # the old, real fight: its maths and its patterns (below), then the theatre
	await _test_half_damage_math()
	await _test_survivor_really_hits_half()
	await _test_defender_pattern()
	await _test_defender_leash_and_watch()
	await _test_defender_helps_the_player()
	await _test_defender_retreat_and_cornered()
	await _test_gun_defender()
	await _test_hider()
	await _test_hider_talk()
	await _test_waiter()
	await _test_talk_claim()
	await _test_plan_rules()
	await _test_persistence()
	await _test_spawning()
	await _test_hider_in_a_flat()
	_test_safety_and_dialogue()
	AllyCombat.performative = true                   # …and the shipped behaviour
	await _test_theatre()
	await _test_rescue_rules()
	await _test_rescue_overrun()
	await _test_rescue_saved()
	await _test_rescue_in_a_flat()
	await _test_stand_by_a_defender()
	await _test_haven_effects()
	await _test_rescue_reward_and_heal()
	await _test_safe_room()
	_test_haven_roundtrip()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- harness -------------------------------------------------------------------------------------

func _corridor(floor_num: int = 12) -> Node:
	WorldState.new_game()
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true                       # the real player stands in these scenes; zombies must not end the test
	WorldState.dev_survivors = 0
	WorldState.survivor_rule = false                 # these tests place their OWN survivors — no random defender fighting beside them
	floor_num = _quiet_floor(floor_num)
	WorldState.current_floor = floor_num
	WorldState.seed_floor_door_states(floor_num)
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


## A floor with no fire on it this seed, of the same parity as `want` (so its stairwell side is the same). About one seed in
## eight burns floor 12 in run 1; a burning corridor scorches the dead and survivors a test is counting, which made the
## checks flaky by seed.
func _quiet_floor(want: int) -> int:
	for step in [0, 2, -2, 4, -4, 6, -6]:
		var f: int = want + step
		if f >= 2 and f <= 28 and WorldState.fire_intensity(f) < 0:
			return f
	return want


func _finish(bf: Node) -> void:
	WorldState.god_mode = false
	WorldState.dev_survivors = 0
	bf.free()
	await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _rec(role: String, weapon: String = "", ammo: int = 0, post: float = 600.0) -> Dictionary:
	var key := "test:%s:%d" % [role, _n]
	_n += 1
	var rec := {
		"key": key, "role": role, "floor": 12, "apt": "", "look": 3, "weapon": weapon, "ammo": ammo,
		"gift": "006", "gift_n": 0, "hp": SurvivorPlan.HP[role], "max_hp": SurvivorPlan.HP[role], "dead": false,
		"x": -1.0, "post": post, "post_kind": "stairs", "spot": 0.5, "met": 0, "aided": false, "calm": false,
		"gave": false, "quest": "",
	}
	WorldState.survivors[key] = rec
	return rec


func _survivor(bf: Node, role: String, weapon: String = "", ammo: int = 0, post: float = 600.0) -> Survivor:
	return Survivor.spawn(bf, _rec(role, weapon, ammo, post), Survivor.FEET_CORRIDOR, post)


func _zombie(bf: Node, x: float, hp: int = 4, frozen: bool = false, scene: String = STANDARD) -> Node:
	var z = load(scene).instantiate()
	z.global_position = Vector2(x, 370.0 if scene == STANDARD else 374.0)
	bf.add_child(z)
	z.max_hp = hp
	z.current_hp = hp
	if frozen:
		z.set_physics_process(false)
	return z


func _player(bf: Node) -> Node:
	return bf.get_node("Player")


## Runs frames until `cond` holds or `max_frames` pass. Returns whether it held.
func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


# --- the half-damage rule ------------------------------------------------------------------------

func _test_half_damage_math() -> void:
	print("[a survivor's damage is HALF the player's, derived from the player's own numbers]")
	var bf = await _corridor()
	var p = _player(bf)
	var mism := []
	for id in ItemData.items:
		var data: Dictionary = ItemData.get_item(id)
		var pk: String = p._get_weapon_type(data) if data.get("is_weapon", false) else ""
		var want: String = pk if pk != "" else "fists"
		if AllyCombat.kind_of(id) != want:
			mism.append(id)
	check(mism.is_empty(), "AllyCombat.kind_of agrees with player._get_weapon_type for every item (disagree: %s)" % str(mism))
	for k in ["knife", "sword", "bat"]:
		check(is_equal_approx(AllyCombat.player_damage(k), float(p.WEAPON_DAMAGE[k])),
			"%s: player damage %.1f is read off player.gd" % [k, AllyCombat.player_damage(k)])
	for k in ["knife", "sword", "bat", "gun"]:
		check(is_equal_approx(AllyCombat.ally_damage(k), AllyCombat.player_damage(k) * 0.5),
			"%s: survivor %.1f = half of the player's %.1f" % [k, AllyCombat.ally_damage(k), AllyCombat.player_damage(k)])
	check(AllyCombat.ally_damage("fists") == 0.0, "bare-handed does nothing (the player can't either)")
	# the carry: exactly half over any number of swings, nothing rounded away
	for k in ["knife", "bat", "gun"]:
		var carry := 0.0
		var total := 0
		var seq := []
		for i in 20:
			var s: Dictionary = AllyCombat.take_swing(carry, k)
			carry = float(s["carry"])
			total += int(s["amount"])
			seq.append(int(s["amount"]))
		check(total == int(floor(20.0 * AllyCombat.ally_damage(k) + 0.0001)), "%s: 20 swings deal %d (= 20 × %.1f) — %s…" % [k, total, AllyCombat.ally_damage(k), str(seq.slice(0, 4))])
	# the gun constant is the zombie's own body-shot damage
	var z = _zombie(bf, 300.0, 8, true)
	z.receive_hit_from_gun("body")
	check(8 - z.current_hp == AllyCombat.GUN_BODY_DAMAGE, "GUN_BODY_DAMAGE (%d) is what a body shot really does (%d)" % [AllyCombat.GUN_BODY_DAMAGE, 8 - z.current_hp])
	# the survivor's gun never headshots and odds are the player's body odds
	check(AllyCombat.gun_hits(100.0, 0.59) and not AllyCombat.gun_hits(100.0, 0.61), "close odds = the player's 60% body chance")
	check(AllyCombat.gun_hits(200.0, 0.51) and not AllyCombat.gun_hits(200.0, 0.53), "mid odds = the player's 52% body chance")
	await _finish(bf)


func _test_survivor_really_hits_half() -> void:
	print("[…and in the live fight it lands exactly half]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 600.0)        # baseball bat: the player's bat does 3
	var z = _zombie(bf, 640.0, 100, true)
	await _frames(2)
	var before: int = z.current_hp
	for i in 10:
		d._strike(z)
	var dealt: int = before - z.current_hp
	check(dealt == 15, "ten bat swings deal 15 (the player's ten would deal 30): %d" % dealt)
	var d2 := _survivor(bf, "defender", "001", 0, 560.0)        # knife: the player's does 1
	var z2 = _zombie(bf, 590.0, 100, true)
	await _frames(2)
	var b2: int = z2.current_hp
	for i in 10:
		d2._strike(z2)
	check(b2 - z2.current_hp == 5, "ten knife swings deal 5: %d" % (b2 - z2.current_hp))
	await _finish(bf)


# --- the defender: hold → alert → engage → return -------------------------------------------------

func _test_defender_pattern() -> void:
	print("[DEFENDER: holds its post, marks '!', calls it, fights, then goes back to its post]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 600.0)
	var p = _player(bf)
	p.global_position = Vector2(1100.0, 386.0)                # the player is far off: this is the survivor's own fight
	await _frames(20)
	check(d.behaviour == "hold", "with nothing about it HOLDS (%s)" % d.behaviour)
	check(d.collision_layer == 0 and d.collision_mask == 0, "an Area2D with no collision: it can never block the player")
	var z = _zombie(bf, 430.0, 4)                              # 170 px off: in sight and inside its leash
	var seen: Array = []
	var tell_alert := false
	var said_spot := false
	for i in 900:
		await get_tree().physics_frame
		if seen.is_empty() or seen[-1] != d.behaviour:
			seen.append(d.behaviour)
		if d.tell != null and d.tell.kind == "alert":
			tell_alert = true
		if d.last_moment == "spot":
			said_spot = true
		if z.is_dead and d.behaviour == "hold":
			break
	check(seen.has("alert") and seen.has("engage") and seen.find("alert") < seen.find("engage"),
		"the pattern is alert → engage (saw %s)" % str(seen))
	check(tell_alert, "it marked '!' when it spotted it")
	check(said_spot, "…and called it out ('spot')")
	check(z.is_dead, "it killed the dead one with half-damage swings")
	check(not d.is_dead, "it came through alive (hp %d/%d)" % [d.current_hp, d.max_hp])
	check(seen.has("return") or absf(d.global_position.x - 600.0) < 8.0, "it went back to its post (%s)" % str(seen))
	check(absf(d.global_position.x - 600.0) < 8.0 and d.behaviour == "hold", "and HOLDS there again (x %.0f, %s)" % [d.global_position.x, d.behaviour])
	await _finish(bf)


func _test_defender_leash_and_watch() -> void:
	print("[DEFENDER: it does not chase into the dark — beyond its leash it only watches]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 400.0)
	_player(bf).global_position = Vector2(1100.0, 386.0)
	var z = _zombie(bf, 730.0, 4, true)                        # 330 px off: in sight, but past the 250 px leash
	await _frames(90)
	check(d.behaviour == "alert", "sighted but out of leash → it watches (%s)" % d.behaviour)
	check(absf(d.global_position.x - 400.0) < 2.0, "…and keeps its post (x %.1f)" % d.global_position.x)
	check(z.current_hp == 4, "…and strikes nothing")
	var face_to_zombie: bool = not d.animated_sprite.flip_h
	check(face_to_zombie, "it faces the one it is watching")
	z.free()
	var far = _zombie(bf, 400.0 + Survivor.SENSE + 80.0, 4, true)
	await _frames(60)
	check(d.behaviour in ["hold", "return"], "beyond its sight it simply holds (%s)" % d.behaviour)
	far.free()
	await _finish(bf)


func _test_defender_helps_the_player() -> void:
	print("[DEFENDER: it stretches its leash to go to the player's aid]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 600.0)
	var p = _player(bf)
	p.global_position = Vector2(820.0, 386.0)
	var z = _zombie(bf, 900.0, 6)                              # 300 px from the post: past the leash, on the player
	var went := false
	var helped := false
	for i in 400:
		await get_tree().physics_frame
		if d.behaviour == "help":
			helped = true
		if d.global_position.x > 680.0:
			went = true
		if z.is_dead:
			break
	check(helped, "it chose 'help' for a dead one that was on the player")
	check(went, "…and left its post to reach them (x %.0f)" % d.global_position.x)
	check(z.get("prey") == p or z.is_dead, "(the dead one really was going for the player)")
	await _finish(bf)


func _test_defender_retreat_and_cornered() -> void:
	print("[DEFENDER: hurt, it falls back; pinned, it fights]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 600.0)
	_player(bf).global_position = Vector2(1100.0, 386.0)
	d.current_hp = 2                                           # under a third of 8
	var z = _zombie(bf, 420.0, 6)                              # coming from the left, 180 px off
	await _frames(70)
	check(d.behaviour == "retreat", "wounded, it RETREATS (%s)" % d.behaviour)
	check(d.global_position.x > 640.0, "…away from the dead one, not toward it (x %.0f)" % d.global_position.x)
	check(d.tell != null and d.tell.kind == "fear" or d.last_moment == "wounded", "…and shows it (fear mark / 'wounded' line)")
	z.free()
	# calm for a while → it gets back up and returns
	var back := await _until(func(): return d.behaviour == "hold" and absf(d.global_position.x - 600.0) < 8.0, int((Survivor.RECOVER_QUIET + 14.0) * 60.0))
	check(back, "when it has been quiet a while it recovers and returns to its post (%s, x %.0f)" % [d.behaviour, d.global_position.x])
	# cornered: a dead one right on it forces a fight whatever its nerve
	d.current_hp = 2
	var near = _zombie(bf, d.global_position.x - 36.0, 100, true)
	await _frames(40)
	check(d.behaviour in ["engage", "alert"] and near.current_hp < 100, "pinned (36 px) the wounded one fights back (%s, zombie hp %d)" % [d.behaviour, near.current_hp])
	await _finish(bf)


func _test_gun_defender() -> void:
	print("[DEFENDER with a gun: shoots from range, the floor hears it, and with no rounds it falls back]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "004", 3, 500.0)
	_player(bf).global_position = Vector2(1180.0, 386.0)
	var target = _zombie(bf, 700.0, 100, true)                 # 200 px off, a punch bag
	var listener = _zombie(bf, 1000.0, 100)                    # 500 px off: beyond its sight, inside the shot's carry
	await _until(func(): return d.ammo <= 0, 900)
	var hits: int = 100 - target.current_hp
	check(d.ammo == 0, "three rounds fired (ammo %d)" % d.ammo)
	check(hits >= 0 and hits <= 3, "…at most three hits of 1 damage (%d)" % hits)
	check(d.kind == "fists", "with none left it carries no weapon that works")
	check(listener.mind == "investigate" or listener.mind == "search" or listener.state == "chase",
		"the shot carried: the dead one 500 px off went to look (%s)" % listener.mind)
	check(absf(float(listener.mind_x) - d.global_position.x) < 80.0 or listener.mind != "investigate",
		"…at the shooter's spot, not at the player (mind_x %.0f)" % listener.mind_x)
	await _frames(40)
	check(d.behaviour == "retreat", "out of rounds with one still in sight, it RETREATS (%s)" % d.behaviour)
	await _finish(bf)


# --- the hider: hide → peek → trust ; freeze → panic → relieved -----------------------------------------

func _test_hider() -> void:
	print("[HIDER: hides; peeks; trusts the harmless faster; freezes; panics when found; is relieved]")
	var bf = await _corridor()
	var p = _player(bf)
	var h := _survivor(bf, "hider", "", 0, 500.0)
	p.global_position = Vector2(900.0, 386.0)
	WorldState.is_scavenge_mode = true
	await _frames(20)
	check(h.behaviour == "hide", "alone it HIDES (%s)" % h.behaviour)
	p.global_position = Vector2(620.0, 386.0)                  # 120 px: inside the peek range
	await _frames(15)
	check(h.behaviour == "peek" and h.last_moment == "peek", "you come near and it PEEKS and whispers (%s, '%s')" % [h.behaviour, h.last_line])
	p.global_position = Vector2(560.0, 386.0)                  # 60 px: trust distance
	await _frames(int(Survivor.TRUST_TIME_SCAV * 60.0) - 20)
	check(h.behaviour == "peek", "not yet…")
	await _frames(40)
	check(h.behaviour == "trust", "weapon down, it TRUSTS you in ~%.1f s (%s)" % [Survivor.TRUST_TIME_SCAV, h.behaviour])
	# the same approach with the weapon DRAWN takes longer
	var h2 := _survivor(bf, "hider", "", 0, 300.0)
	p.global_position = Vector2(360.0, 386.0)
	WorldState.is_scavenge_mode = false
	await _frames(int(Survivor.TRUST_TIME_SCAV * 60.0) + 40)
	check(h2.behaviour == "peek", "weapon drawn: after the same time it still has not trusted you (%s)" % h2.behaviour)
	await _frames(int(Survivor.TRUST_TIME_COMBAT * 60.0))
	check(h2.behaviour == "trust", "…and does eventually (%s)" % h2.behaviour)
	WorldState.is_scavenge_mode = true
	h2.free()
	# freeze: one of the dead near but not on it
	var z = _zombie(bf, 700.0, 4, true)                        # 200 px from the hider at 500
	var hx: float = h.global_position.x
	await _frames(20)
	check(h.behaviour == "freeze", "one of the dead within earshot → it FREEZES (%s)" % h.behaviour)
	check(h.tell != null and h.tell.kind == "fear", "…marked '…'")
	check(absf(h.global_position.x - hx) < 1.0, "…and does not move a muscle")
	# found: the dead one is on top of it → panic, run for the far wall, scream (the dead hear it)
	var far_listener = _zombie(bf, 780.0, 4)                 # 280 px off: inside a scream's 380 px carry, outside its freeze range
	z.global_position.x = h.global_position.x + 50.0
	await _frames(30)
	check(h.behaviour == "panic", "found (50 px) it PANICS (%s)" % h.behaviour)
	check(h.global_position.x < hx - 20.0, "…running AWAY from it (x %.0f from %.0f)" % [h.global_position.x, hx])
	check(h.last_moment == "panic", "…screaming ('%s')" % h.last_line)
	check(far_listener.mind == "investigate" or far_listener.state == "chase", "…and the scream carried: another dead one went to look (%s)" % far_listener.mind)
	# relieved
	z.free()
	far_listener.free()
	await _frames(30)
	check(h.behaviour == "relieved", "the dead one gone, it is RELIEVED (%s)" % h.behaviour)
	await _frames(170)
	check(h.behaviour == "trust", "…and then trusts (%s)" % h.behaviour)
	await _finish(bf)


func _test_talk_claim() -> void:
	print("[THE TALK CLAIM: while a survivor offers [Talk], the same press is not also the door's / lift's]")
	var bf = await _corridor()
	var p = _player(bf)
	# a defender posted a few px from an apartment door, and the player between them
	var d := _survivor(bf, "defender", "001", 0, 640.0)
	p.global_position = Vector2(620.0, 386.0)
	WorldState.is_scavenge_mode = true
	await _frames(20)
	check(d.can_talk() and d._talk_near, "(setup) the defender is offering Talk (%s)" % d.behaviour)
	check(WorldState.interact_claimed_by_talk() and TutorialManager.interact_guarded(),
		"the interact press is CLAIMED: doors, the lift and the lobby door (all ask interact_guarded) stand down")
	check(not TutorialManager.tutorial_guard_active(), "…without borrowing the tutorial's own guard (the survivor's own press still gets through)")
	# step away: the claim lapses within a moment and the door has its key back
	p.global_position = Vector2(1000.0, 386.0)
	await _frames(30)
	check(not d._talk_near, "(setup) out of range, the offer is withdrawn")
	check(not WorldState.interact_claimed_by_talk() and not TutorialManager.interact_guarded(), "…and the claim has lapsed (the door is the door again)")
	# the player AT a door (nearer to it than to the survivor) gets the DOOR: the survivor stands down, claims nothing, and the press is the door's
	var dn := Area2D.new()
	dn.set_script(preload("res://tests/stub_door.gd"))
	bf.add_child(dn)
	dn.global_position = Vector2(300.0, 386.0)
	dn.add_to_group("door_interact")
	p.global_position = Vector2(620.0, 386.0)
	await _frames(20)
	check(d._talk_near, "(setup) with no door about, the defender 20 px away offers Talk")
	dn.player_nearby = true
	dn.global_position = Vector2(628.0, 386.0)          # the door's own centre 8 px away, the defender 20
	await _frames(40)
	check(d._door_answers_instead(), "a door at the player (8 px) nearer than the defender (20 px) answers the press")
	check(not d._talk_near and not WorldState.interact_claimed_by_talk(), "…so the survivor withdraws Talk and claims nothing (the door's press is not swallowed)")
	dn.global_position = Vector2(560.0, 386.0)          # the door 60 px off, the defender 20 px
	await _frames(40)
	check(not d._door_answers_instead() and d._talk_near and WorldState.interact_claimed_by_talk(), "a door FARTHER than the defender does not (the survivor still takes the press)")
	dn.player_nearby = false
	dn.global_position = Vector2(628.0, 386.0)
	await _frames(40)
	check(not d._door_answers_instead() and d._talk_near, "a nearer door the player is not AT (out of its reach) does not stand the survivor down")
	dn.queue_free()
	p.global_position = Vector2(1000.0, 386.0)
	await _frames(30)
	# a survivor who cannot talk (mid-fight / hiding) claims nothing
	var h := _survivor(bf, "hider", "", 0, 1000.0)
	await _frames(20)
	check(not h.can_talk() and not WorldState.interact_claimed_by_talk(), "a hider that has not yet trusted you claims nothing (%s)" % h.behaviour)
	await _finish(bf)


func _test_hider_talk() -> void:
	print("[HIDER: [E] talk gives its gift ONCE; a full pack keeps it for later; being aided counts]")
	var bf = await _corridor()
	var p = _player(bf)
	var h := _survivor(bf, "hider", "", 0, 500.0)
	h.rec["gift"] = "006"
	p.global_position = Vector2(540.0, 386.0)
	WorldState.is_scavenge_mode = true
	await _frames(int(Survivor.TRUST_TIME_SCAV * 60.0) + 40)
	check(h.can_talk(), "a trusting hider can be talked to")
	WorldState._ensure_chronicle()
	var aided_before := int(WorldState.run_chronicle[0].get("npcs_aided", 0))
	# full pack first: nothing is lost, the gift waits
	WorldState.inventory.clear()
	while WorldState.add_to_inventory("023"):
		pass                                                   # fill every slot with junk
	var n_before := _count_items("006")
	h.talk()
	check(not bool(h.rec.get("gave", false)) and _count_items("006") == n_before, "a full pack: the gift is not given and nothing is destroyed")
	WorldState.inventory.clear()
	h.talk()
	check(bool(h.rec.get("gave", false)) and _count_items("006") == 1, "with room it gives the gift (bandages)")
	var aided_after := int(WorldState.run_chronicle[0].get("npcs_aided", 0))
	check(aided_after == aided_before + 1, "…and it counts as an NPC aided (%d → %d)" % [aided_before, aided_after])
	h.talk()
	check(_count_items("006") == 1 and h.last_moment == "thanks", "talking again gives nothing more — just thanks")
	await _finish(bf)


func _count_items(id: String) -> int:
	var n := 0
	for it in WorldState.inventory:
		if it != null and it.item_id == id:
			n += 1
	return n


# --- the waiter: wait + bang in threes → startle → calm ; flee -----------------------------------------

func _test_waiter() -> void:
	print("[WAITER: knocks on the lift in THREES, which the dead hear; calms if you stand easy; flees the dead]")
	var bf = await _corridor()
	var p = _player(bf)
	p.global_position = Vector2(300.0, 386.0)
	var w := _survivor(bf, "waiter", "", 0, SurvivorPlan.WAITER_X)
	var listener = _zombie(bf, 1190.0, 4, true)                 # 206 px away: inside the 300 px knock, outside its 200 px flee range (frozen: it HEARS, it does not come)
	WorldState.is_scavenge_mode = true
	await _frames(10)
	check(w.behaviour == "wait", "it WAITS (%s)" % w.behaviour)
	w._bang_t = 0.05
	await _frames(150)
	check(w.knocks == 3, "one set = exactly three knocks (%d)" % w.knocks)
	check(listener.mind in ["investigate", "search"] or listener.state == "chase", "the dead heard it (%s)" % listener.mind)
	check(w.behaviour == "wait", "…then it waits again (%s)" % w.behaviour)
	w._bang_t = 0.05
	await _frames(150)
	check(w.knocks == 6, "the next set is three more (%d)" % w.knocks)
	listener.free()
	# the player comes near: startle, then calm if they stand easy
	p.global_position = Vector2(w.global_position.x - 60.0, 386.0)
	await _frames(20)
	check(w.behaviour == "startle" and w.tell != null and w.tell.kind == "alert", "you come near → it STARTLES, marked '!' (%s)" % w.behaviour)
	await _frames(int(Survivor.CALM_TIME * 60.0) + 40)
	check(w.behaviour == "calm" and bool(w.rec.get("calm", false)), "weapon down, standing easy → it CALMS (%s)" % w.behaviour)
	var k: int = w.knocks
	w._bang_t = 0.05
	await _frames(150)
	check(w.knocks == k, "a calmed waiter never knocks again")
	check(w.can_talk(), "…and can be talked to")
	check(w.talk() != "", "…(it answers)")
	# flee: the dead near it, whatever else
	var z = _zombie(bf, w.global_position.x - 140.0, 4, true)
	var x0: float = w.global_position.x
	await _frames(40)
	check(w.behaviour == "flee" and w.global_position.x > x0, "a dead one 140 px off → it FLEES the other way (%s; waiter x %.0f→%.0f, zombie x %.0f, gap %.0f, present %s)" % [w.behaviour, x0, w.global_position.x, z.global_position.x, AiMind.gap(w, z), str(AiMind.present(z))])
	z.free()
	await _finish(bf)


# --- placement, persistence, spawning ------------------------------------------------------------

func _test_plan_rules() -> void:
	print("[PLACEMENT: seeded, contextual, and stable]")
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.master_seed = 424242
	WorldState.dev_survivors = 0
	WorldState.current_run = 1
	var snap := {}
	for f in range(1, 29):
		snap[f] = JSON.stringify(SurvivorPlan.corridor_records(f))
	var again := {}
	WorldState.survivors.clear()
	for f in range(1, 29):
		again[f] = JSON.stringify(SurvivorPlan.corridor_records(f))
	check(snap == again, "the same seed rolls the same people (floors 1-28)")
	# the RULE: nobody anywhere unless the real New Game turned it on (so a test that builds a corridor has only its own enemies)
	var saved_dev := WorldState.dev_survivors
	WorldState.dev_survivors = 1
	var populated := 0
	for f in range(1, 29):
		populated += SurvivorPlan.corridor_records(f).size()
	check(populated > 0, "(setup) with the rule on and every roll forced, the floors are populated (%d)" % populated)
	WorldState.survivor_rule = false
	var populated_off := 0
	for f in range(1, 29):
		populated_off += SurvivorPlan.corridor_records(f).size() + Quests.corridor_records(f).size()
	check(populated_off == 0, "with the rule OFF no floor holds anyone (%d), whatever the rolls" % populated_off)
	var site_apt := str(Quests.site("ethel").get("apt", ""))
	check(site_apt != "" and not Quests.is_quest_flat(site_apt) and Quests.quest_for_flat(site_apt) == "", "…and a quest's flat is an ordinary flat")
	check(SurvivorPlan.hider_for(site_apt).is_empty(), "…and no flat hides anyone")
	WorldState.survivor_rule = true
	check(Quests.is_quest_flat(site_apt), "(setup) with it back on, the quest flat is the quest's")
	WorldState.dev_survivors = saved_dev
	check(SurvivorPlan.corridor_records(29).is_empty() and SurvivorPlan.corridor_records(30).is_empty() and SurvivorPlan.corridor_records(0).is_empty(),
		"nobody on 29 (the scripted neighbour), 30 (the tutorial) or the lobby")
	var def_by_run := {1: 0, 2: 0, 3: 0}
	var wait_on_merchant := 0
	var bad_weapon := 0
	var bad_gun := 0
	var bad_hp := 0
	var posts_ok := true
	var floors_checked := 0
	for run in [1, 2, 3]:
		WorldState.current_run = run
		for seed in range(300):
			WorldState.master_seed = 9000 + seed
			WorldState.survivors.clear()
			for f in range(1, 29):
				if run == 1 and seed >= 20:
					break
				floors_checked += 1
				for r in SurvivorPlan.corridor_records(f):
					if str(r.get("quest", "")) != "" or str(r.get("rescue", "")) != "":
						continue                # a quest giver is specified by data/quests.json (quest_test), a rescue by the rescue tests — not by the random role tables
					if r["role"] == "defender":
						def_by_run[run] += 1
						if not SurvivorPlan.DEFENDER_WEAPONS[run].has(r["weapon"]):
							bad_weapon += 1
						if r["weapon"] == "004" and (int(r["ammo"]) < SurvivorPlan.AMMO_MIN or int(r["ammo"]) > SurvivorPlan.AMMO_MAX):
							bad_gun += 1
						if r["weapon"] != "004" and int(r["ammo"]) != 0:
							bad_gun += 1
						if float(r["post"]) < 150.0 or float(r["post"]) > 1190.0:
							posts_ok = false
					if r["role"] == "waiter" and (f in WorldState.MERCHANT_FLOORS):
						wait_on_merchant += 1
					if int(r["hp"]) != int(SurvivorPlan.HP[r["role"]]):
						bad_hp += 1
	check(wait_on_merchant == 0, "a waiter is never on a merchant floor (the merchant has the car)")
	check(bad_weapon == 0, "every defender carries something from its run's list")
	check(bad_gun == 0, "a gun carries 4-7 rounds, nothing else carries any")
	check(bad_hp == 0 and posts_ok, "health by role, posts inside the corridor")
	check(def_by_run[3] < def_by_run[1] * 300.0 / 20.0, "survivors dwindle: far fewer defenders per floor by run 3 (run1 %d/20 seeds, run3 %d/300)" % [def_by_run[1], def_by_run[3]])
	var rate1: float = float(def_by_run[1]) / (20.0 * 28.0)
	check(rate1 > 0.18 and rate1 < 0.42, "run 1: about 30%% of floors hold a defender (%.2f)" % rate1)
	# a hider only in a flat you can walk into
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.current_run = 1
	WorldState.dev_survivors = 1
	var ok_open := 0
	var ok_bad := 0
	for f in range(2, 20):
		WorldState.seed_floor_door_states(f)
		for col in range(1, 6):
			var apt := "%d%02d" % [f, col]
			var h := SurvivorPlan.hider_for(apt)
			var ds: int = WorldState.get_door_state(apt)
			if h.is_empty():
				continue
			if ds == WorldState.DoorState.OPEN or ds == WorldState.DoorState.SHUT_FORCEABLE:
				ok_open += 1
			else:
				ok_bad += 1
	check(ok_open > 0 and ok_bad == 0, "hiders only in flats with an open / weak-lock door (%d found, %d wrong)" % [ok_open, ok_bad])
	WorldState.dev_survivors = 0


func _test_persistence() -> void:
	print("[PERSISTENCE: a record survives a save round-trip; the dead stay dead; a new run is a new roll]")
	var bf = await _corridor()
	var d := _survivor(bf, "defender", "014", 0, 600.0)
	d.receive_damage(3, "bite")
	check(WorldState.survivors[d.key]["hp"] == 5, "damage is written back to the record")
	d.receive_damage(99, "bite")
	check(d.is_dead and WorldState.survivors[d.key]["dead"] == true, "death is recorded")
	check(not d.is_in_group("survivor_prey"), "a dead survivor is nobody's prey")
	var json := JSON.stringify(WorldState.survivors)
	var back = JSON.parse_string(json)
	check(back is Dictionary and back.has(d.key) and back[d.key]["dead"] == true, "the dead flag survives a JSON round trip (string keys)")
	var d2 := Survivor.spawn(bf, back[d.key], Survivor.FEET_CORRIDOR, 600.0)
	check(d2.is_dead and d2.behaviour == "dead" and not d2.is_in_group("survivor_prey"), "…and it comes back lying dead")
	await _frames(5)
	check(d2.get_node_or_null("Weapon") == null or not d2.get_node("Weapon").visible, "the dead hold nothing")
	# drops: the weapon and the gift lie where it fell
	var drops := 0
	for n in bf.get_children():
		if n.is_in_group("world_drop"):
			drops += 1
	check(drops >= 1 or WorldState.world_drops.size() >= 1, "its weapon dropped where it fell")
	WorldState.new_game()
	WorldState.master_seed = 77
	WorldState.current_run = 1
	var k1 := SurvivorPlan.corridor_key(12, "defender")
	WorldState.current_run = 2
	check(SurvivorPlan.corridor_key(12, "defender") != k1, "a new run is a new key (a new roll)")
	await _finish(bf)


func _test_spawning() -> void:
	print("[SPAWNING: corridor floors place them live, as frozen scenery in a pan backdrop, and wake them]")
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.dev_survivors = 1
	WorldState.current_run = 1
	WorldState.current_floor = 12
	WorldState.seed_floor_door_states(12)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	var mine: Array = []
	for s in get_tree().get_nodes_in_group("survivor"):
		if bf.is_ancestor_of(s):
			mine.append(s)
	var roles := mine.map(func(s): return s.role)
	check(roles.has("defender") and roles.has("waiter"), "a live floor places its defender and waiter (%s)" % str(roles))
	var all_live := true
	var feet_ok := true
	for s in mine:
		if s.scenery:
			all_live = false
		if absf(s.position.y - Survivor.FEET_CORRIDOR) > 0.5:
			feet_ok = false
	check(all_live and feet_ok, "…live, standing on the corridor floor line (419)")
	for s in mine:
		if s.role == "waiter":
			check(absf(s.position.x - SurvivorPlan.WAITER_X) < 0.5, "the waiter stands by the lift (x %.0f)" % s.position.x)
	bf.free()
	await get_tree().process_frame
	# a pan backdrop of the same floor
	var back = load("res://scenes/building_floors.tscn").instantiate()
	back.passive = true
	back.setup_floor = 12
	add_child(back)
	await get_tree().physics_frame
	var scen: Array = []
	for s in get_tree().get_nodes_in_group("survivor"):
		if back.is_ancestor_of(s):
			scen.append(s)
	var frozen := scen.size() > 0
	for s in scen:
		if not s.scenery or not s.is_in_group("pan_scenery") or s.is_physics_processing():
			frozen = false
	check(frozen, "a pan BACKDROP carries them as frozen scenery (%d)" % scen.size())
	back._wake_scenery_zombies()
	var awake := scen.size() > 0
	for s in scen:
		if s.scenery or s.is_in_group("pan_scenery") or not s.is_physics_processing():
			awake = false
	check(awake, "…and the commit wakes them")
	back.free()
	await get_tree().process_frame
	WorldState.dev_survivors = 0


func _test_hider_in_a_flat() -> void:
	print("[A HIDER in a flat: at the back, on the flat's walking line]")
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_run = 1
	WorldState.dev_survivors = 1
	WorldState.god_mode = true
	var apt := ""
	for f in range(3, 20):
		WorldState.seed_floor_door_states(f)
		for col in range(1, 6):
			var a := "%d%02d" % [f, col]
			if SurvivorPlan.hider_flat_ok(a) and not SurvivorPlan.hider_for(a).is_empty() and str(SurvivorPlan.hider_for(a).get("rescue", "")) == "" and WorldState.get_door_state(a) == WorldState.DoorState.OPEN:
				apt = a
				break
		if apt != "":
			break
	check(apt != "", "an eligible flat exists (%s)" % apt)
	if apt == "":
		return
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	WorldState.saved_player_x = 0.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _frames(4)
	var h = room.get("hider")
	check(h != null and is_instance_valid(h) and h.role == "hider", "the hider is home")
	if h != null:
		check(absf(h.position.y - 353.0) < 0.5, "on the flat's walking line (353)")
		var side := WorldState.get_entrance_side(apt)
		var far_ok: bool = (h.position.x > 113.0 + 2 * 320.0 + 60.0) if side == "left" else (h.position.x < 113.0 + 320.0 + 60.0 + 180.0)
		check(far_ok, "as far from the front door as the flat goes (door %s, x %.0f)" % [side, h.position.x])
		for zz in get_tree().get_nodes_in_group("zombie"):
			if room.is_ancestor_of(zz):
				zz.free()                                          # (the flat's own dead are not what this checks)
		await _frames(30)
		# (the flat's own dead may have been close enough to frighten it before they were cleared away — then it is still coming down
		# from that: relieved, and soon trusting. What it must NOT be is frozen / panicking / fleeing with nobody left.)
		check(h.behaviour in ["hide", "peek", "relieved", "trust"], "hiding, or settling after a fright (%s)" % h.behaviour)
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# not in the tutorial's floor, nor a locked (resident) flat
	WorldState.dev_survivors = 1
	check(SurvivorPlan.hider_for("3002").is_empty() and SurvivorPlan.hider_for("3005").is_empty(), "never on Floor 30 (the tutorial flats)")
	WorldState.dev_survivors = 0
	WorldState.god_mode = false


func _test_safety_and_dialogue() -> void:
	print("[SAFETY + DIALOGUE]")
	var lines := Survivor.lines()
	var need := {
		"all": ["hurt", "death", "rescue_call", "rescue_saved", "rescue_overrun", "rescue_thanks", "haven_tend", "haven_fine", "haven_again"],
		"defender": ["greet", "greet_again", "spot", "engage", "help", "wounded", "recovered", "out_of_ammo", "clear", "thanks", "helped", "helped_last", "haven"],
		"hider": ["peek", "trust", "freeze", "panic", "relieved", "gift", "thanks", "cornered"],
		"waiter": ["mutter", "bang", "startle", "calm", "thanks", "flee"],
	}
	var missing := []
	for r in need:
		for m in need[r]:
			var pool = lines.get(r, {}).get(m, [])
			if not (pool is Array) or pool.is_empty() or str(pool[0]).strip_edges() == "":
				missing.append(r + "." + m)
	check(missing.is_empty(), "every moment the code speaks has a line (missing: %s)" % str(missing))
	# the tell
	var host := Node2D.new()
	add_child(host)
	var t := AiTell.attach(host, 70.0)
	check(not t.is_showing(), "a tell starts hidden")
	t.show_mark("alert")
	check(t.is_showing() and t.kind == "alert", "show_mark('alert') shows it")
	t.show_mark("nonsense")
	check(not t.is_showing(), "an unknown kind hides it")
	t.show_mark("search")
	t.clear()
	check(not t.is_showing(), "clear() hides it")
	host.free()


# --- THEATRE (owner round 41): the show takes nothing from anyone -------------------------------------------

## Physics at `mult`× real time with the per-step delta unchanged (the headless run is paced in real time otherwise).
func _fast(mult: int) -> void:
	Engine.physics_ticks_per_second = 60 * mult
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = float(mult)


func _test_theatre() -> void:
	print("[THEATRE: survivors fight for show — the flash of a blow, none of its weight, and no gun runs dry]")
	check(AllyCombat.performative, "(setup) the shipped default is the show")
	var bf = await _corridor()
	# a bat: ten swings flash the dead one white and take NOTHING off it, stun nothing, knock nothing down
	var d := _survivor(bf, "defender", "014", 0, 600.0)
	var z = _zombie(bf, 640.0, 100, true)
	await _frames(2)
	for i in 10:
		d._strike(z)
	check(z.current_hp == 100, "ten bat swings take nothing off the dead one (hp %d)" % z.current_hp)
	check(ENEMY_HURT.is_blinking(z), "…but it flashes white: the damage animation still plays")
	check(z.state != "hit" and z.state != "knockdown" and not z.is_hurt(), "…and it is not stunned, staggered or knocked down (%s)" % z.state)
	# a gun never runs dry and never hurts
	var g := _survivor(bf, "defender", "004", 3, 520.0)
	var target = _zombie(bf, 700.0, 100, true)
	await _frames(2)
	for i in 12:
		g._shoot(target)
	check(g.ammo == 3 and g.kind == "gun", "twelve shots later it still has its three rounds and its gun (ammo %d, %s)" % [g.ammo, g.kind])
	check(target.current_hp == 100, "…and none of them hurt (hp %d)" % target.current_hp)
	check(Survivor.SHOW_SHOT_NOISE < Survivor.SHOT_NOISE, "a pretend shot carries less far than a real one (it must not drag the floor to the post)")
	# the dead's bite: the flinch, not the wound
	var hp0: int = d.current_hp
	d.receive_damage(99, "bite")
	check(not d.is_dead and d.current_hp == hp0 and int(WorldState.survivors[d.key]["hp"]) == hp0, "a bite that would have killed them changes nothing (hp %d/%d)" % [d.current_hp, d.max_hp])
	check(d.is_hurt(), "…but they flinch (the hurt pose plays)")
	await _finish(bf)
	# a whole fight: a bat-holder, three of the dead on it — nobody is hurt, nobody dies, and they DID fight
	bf = await _corridor()
	_player(bf).global_position = Vector2(1180.0, 386.0)
	var d2 := _survivor(bf, "defender", "014", 0, 600.0)
	var dead_ones: Array = []
	for x in [430.0, 470.0, 520.0]:
		dead_ones.append(_zombie(bf, x, 4))
	_fast(8)
	var seen: Array = []
	for i in 1500:
		await get_tree().physics_frame
		if seen.is_empty() or seen[-1] != d2.behaviour:
			seen.append(d2.behaviour)
	_fast(1)
	var untouched := true
	for zz in dead_ones:
		if zz.is_dead or zz.current_hp != zz.max_hp:
			untouched = false
	check(seen.has("engage"), "the show is a fight: it engaged (%s)" % str(seen))
	check(untouched, "…and after twenty-five seconds of it not one of the dead is hurt or down")
	check(not d2.is_dead and d2.current_hp == d2.max_hp, "…nor is the survivor (hp %d/%d)" % [d2.current_hp, d2.max_hp])
	await _finish(bf)


# --- RESCUES --------------------------------------------------------------------------------------------------

func _rescue_rec(weapon: String, role: String = "defender", appears: int = 1) -> Dictionary:
	var rec := _rec(role, weapon, 0, 900.0)
	rec["rescue"] = "pending"
	rec["appears"] = appears
	rec["peril"] = SurvivorPlan.RESCUE_HOLD
	return rec


func _test_rescue_rules() -> void:
	print("[RESCUE: status by run, where it can be, and that it persists]")
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.master_seed = 515151
	var rec := {"key": "test:r", "rescue": "pending", "appears": 2}
	WorldState.current_run = 1
	check(SurvivorPlan.rescue_status(rec) == "future", "an event due in run 2 is not here in run 1")
	WorldState.current_run = 2
	check(SurvivorPlan.rescue_status(rec) == "open", "…it is ON in run 2")
	WorldState.current_run = 3
	check(SurvivorPlan.rescue_status(rec) == "lost", "…and in run 3 an unanswered one is lost (no step at the time skip to forget)")
	rec["rescue"] = "saved"
	check(SurvivorPlan.rescue_status(rec) == "saved", "a saved one stays saved")
	check(SurvivorPlan.rescue_status({"role": "defender"}) == "", "an ordinary survivor is not a rescue")
	var back = JSON.parse_string(JSON.stringify({"key": "test:r", "rescue": "pending", "appears": 2}))
	WorldState.current_run = 2
	check(SurvivorPlan.rescue_status(back) == "open", "the status survives a JSON round trip (appears comes back a float)")
	# where it can be
	WorldState.current_run = 1
	WorldState.dev_survivors = 2
	var opening := 0
	var elsewhere := 0
	for f in range(1, 31):
		if not SurvivorPlan.rescue_for_floor(f).is_empty():
			if f >= 27:
				opening += 1
			else:
				elsewhere += 1
	check(opening == 0, "never on the eased opening floors 27-30 (%d)" % opening)
	check(elsewhere > 10, "…but all over the rest of the building with the dev switch on (%d floors)" % elsewhere)
	WorldState.dev_survivors = 0
	WorldState.survivor_rule = false
	var any := 0
	for f in range(1, 31):
		any += 0 if SurvivorPlan.rescue_for_floor(f).is_empty() else 1
	check(any == 0, "with the survivor rule off nobody is shouting anywhere (%d)" % any)
	WorldState.survivor_rule = true
	# how common, and when: one identity per place, rolled once, whatever run it is first asked in
	var made := 0
	var appear := {1: 0, 2: 0, 3: 0}
	var floors_seen := 0
	for sd in range(1, 121):
		WorldState.master_seed = 7000 + sd
		WorldState.survivors.clear()
		WorldState.current_run = 1 + (sd % 3)
		for f in range(1, 27):
			if WorldState.fire_intensity(f) >= WorldState.FIRE_BLAZE:
				continue
			floors_seen += 1
			SurvivorPlan.rescue_for_floor(f)
			var r = WorldState.survivors.get(SurvivorPlan.rescue_key_corridor(f), {})
			if r is Dictionary and not r.is_empty() and not r.get("none", false):
				made += 1
				appear[int(r["appears"])] += 1
	var rate: float = float(made) / float(floors_seen)
	check(rate > 0.07 and rate < 0.17, "about one corridor floor in eight holds a rescue over the three runs (%.3f)" % rate)
	check(appear[1] > appear[3] and appear[2] > 0 and appear[3] > 0, "…spread over the runs, the first the most (%s)" % str(appear))
	# an event whose run has gone by unanswered is a body where they stood
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	var qf := _quiet_floor(12)
	var key := SurvivorPlan.rescue_key_corridor(qf)
	var seeded := SurvivorPlan._roll(key, "defender", qf, "", 1)
	seeded["rescue"] = "pending"
	seeded["appears"] = 1
	seeded["peril"] = SurvivorPlan.RESCUE_HOLD
	WorldState.survivors[key] = seeded
	WorldState.current_run = 1
	var live := SurvivorPlan.rescue_for_floor(qf)
	check(not live.is_empty() and not bool(live.get("dead", false)) and SurvivorPlan.rescue_status(live) == "open", "in its own run the event is open and they are alive")
	WorldState.current_run = 2
	var gone := SurvivorPlan.rescue_for_floor(qf)
	check(bool(gone.get("dead", false)) and str(gone.get("rescue", "")) == "lost", "…the run after, unanswered, they are a body where they stood")
	check(SurvivorPlan.corridor_records(qf).any(func(r): return str(r.get("key", "")) == key), "…which the floor lays (as the dead, not as a defender)")


func _test_rescue_overrun() -> void:
	print("[RESCUE: ignored, they are overrun live — only then — and the dead they were fending are untouched]")
	var bf = await _corridor()
	_player(bf).global_position = Vector2(1180.0, 386.0)
	var rec := _rescue_rec("014")
	var d := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, 900.0)
	var dead_ones := SurvivorPlan.spawn_rescue_dead(bf, rec, 900.0, 370.0, 265.0, 1105.0, -1.0, 12, false)
	await _frames(3)
	check(dead_ones.size() == 3 and get_tree().get_nodes_in_group("rescue_dead").size() == 3, "three of the dead are laid (%d)" % dead_ones.size())
	check(d.rescuing and d.behaviour == "shout", "they are shouting for help (%s)" % d.behaviour)
	var starts_left := true
	for z in dead_ones:
		if z.global_position.x >= 900.0 - 120.0:
			starts_left = false
	check(starts_left, "…and the dead start well away, on the side they come from")
	_fast(8)
	var called := false
	var fended := false
	var walked := true
	for i in 1100:
		await get_tree().physics_frame
		if d.last_moment == "rescue_call":
			called = true
		if d.behaviour == "fend":
			fended = true
		if i == 120:
			for z in dead_ones:
				if str(z.get("mind")) not in ["investigate", "search"] and str(z.get("state")) != "chase":
					walked = false
	check(called, "they called out ('rescue_call')")
	check(walked, "the dead were SENT at them (investigating their spot, not milling)")
	check(fended and not d.is_dead, "the dead reached them and they fended them off — alive so far (%s, peril %.1f)" % [d.behaviour, float(rec["peril"])])
	check(float(rec["peril"]) < SurvivorPlan.RESCUE_HOLD, "…and the clock to being overrun is running down (%.1f of %.0f)" % [float(rec["peril"]), SurvivorPlan.RESCUE_HOLD])
	var died := await _until(func(): return d.is_dead, 3200)
	_fast(1)
	check(died, "ignored, they are finally overrun")
	check(str(rec["rescue"]) == "lost" and bool(WorldState.survivors[d.key]["dead"]), "…recorded as lost, dead")
	var untouched := true
	for z in dead_ones:
		if is_instance_valid(z) and (z.is_dead or z.current_hp != z.max_hp):
			untouched = false
	check(untouched, "…and not one of the dead was hurt by anything they did")
	await _finish(bf)
	# leaving mid-event does not reset the clock
	bf = await _corridor()
	_player(bf).global_position = Vector2(1180.0, 386.0)
	var rec2 := _rescue_rec("014")
	rec2["peril"] = 9.5
	var d2 := Survivor.spawn(bf, rec2, Survivor.FEET_CORRIDOR, 900.0)
	await _frames(2)
	check(absf(d2._peril - 9.5) < 0.01, "a survivor spawned mid-event picks the clock up where it was (%.1f)" % d2._peril)
	await _finish(bf)


func _test_rescue_saved() -> void:
	print("[RESCUE: step in and they are saved — thanks, a gift, and still there next run]")
	var bf = await _corridor()
	_player(bf).global_position = Vector2(1180.0, 386.0)
	var rec := _rescue_rec("014")
	rec["gift"] = "006"
	rec["gift_n"] = 0
	var d := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, 900.0)
	var dead_ones := SurvivorPlan.spawn_rescue_dead(bf, rec, 900.0, 370.0, 265.0, 1105.0, -1.0, 12, false)
	await _frames(40)
	var aided0: int = int(WorldState.run_chronicle[0].get("npcs_aided", 0))
	check(d.rescuing and d.behaviour == "shout", "(setup) the event is on")
	for z in dead_ones:
		z.receive_damage(999, "blunt")
	await _frames(20)
	check(not d.rescuing and str(rec["rescue"]) == "saved", "all three down: they are SAVED")
	check(not d.is_dead and d.behaviour == "hold", "…alive, and settle into holding their post (%s)" % d.behaviour)
	check(d.last_moment == "rescue_saved", "…and they say so ('%s')" % d.last_moment)
	check(int(WorldState.run_chronicle[0].get("npcs_aided", 0)) == aided0 + 1, "…counted once as an NPC aided (Valour)")
	await _frames(30)
	check(int(WorldState.run_chronicle[0].get("npcs_aided", 0)) == aided0 + 1, "…and only once")
	_player(bf).global_position = Vector2(d.global_position.x - 30.0, 386.0)
	await _frames(5)
	var bandages_before := _count_items("006")
	var said := d.talk()
	check(_count_items("006") == bandages_before + 1, "talking to them hands over what they were keeping for you")
	var said2 := d.talk()
	check(said == "" or said2 != "", "…and next time they just thank you ('%s')" % said2)
	check(d.last_moment == "rescue_thanks", "…in their own words ('%s')" % d.last_moment)
	# the next run: still there, alive, no dead laid, no shouting
	WorldState.current_run = 2
	check(SurvivorPlan.rescue_status(rec) == "saved", "in the next run they are still saved")
	var again := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, 900.0)
	await _frames(3)
	check(not again.rescuing and not again.is_dead and again.behaviour == "hold", "…standing at their post, not shouting (%s)" % again.behaviour)
	WorldState.current_run = 1
	await _finish(bf)


func _test_rescue_in_a_flat() -> void:
	print("[RESCUE in a flat: the dead come from the front door's side, and no others]")
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.current_run = 1
	WorldState.god_mode = true
	var apt := ""
	for f in range(3, 20):
		WorldState.seed_floor_door_states(f)
		for col in range(1, 6):
			var a := "%d%02d" % [f, col]
			if SurvivorPlan.hider_flat_ok(a) and WorldState.get_door_state(a) == WorldState.DoorState.OPEN:
				apt = a
				break
		if apt != "":
			break
	check(apt != "", "(setup) a flat to hold it (%s)" % apt)
	if apt == "":
		return
	var f := WorldState._apartment_floor(apt)
	var key := SurvivorPlan.rescue_key_flat(apt)
	var seeded := SurvivorPlan._roll(key, "hider", f, apt, 1)
	seeded["rescue"] = "pending"
	seeded["appears"] = 1
	seeded["peril"] = SurvivorPlan.RESCUE_HOLD
	WorldState.survivors[key] = seeded
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = f
	WorldState.spawn_source = ""
	WorldState.saved_player_x = 0.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _frames(4)
	var h = room.get("hider")
	check(h != null and is_instance_valid(h) and h.rescuing, "the person in the flat is shouting for help")
	var mine: Array = []
	var others := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			if z.is_in_group("rescue_dead"):
				mine.append(z)
			else:
				others += 1
	check(mine.size() == 3 and others == 0, "three of the dead, and no ordinary ones (%d / %d others)" % [mine.size(), others])
	if h != null and mine.size() == 3:
		var side := WorldState.get_entrance_side(apt)
		var door_side_ok := true
		for z in mine:
			if (side == "left" and z.global_position.x >= h.global_position.x) or (side != "left" and z.global_position.x <= h.global_position.x):
				door_side_ok = false
		check(door_side_ok, "…all on the front door's side of them (door %s)" % side)
		for z in mine:
			z.receive_damage(999, "blunt")
		await _frames(25)
		check(not h.rescuing and str(seeded["rescue"]) == "saved" and h.behaviour == "trust", "kill them and the flat's hider is saved, and trusts you (%s)" % h.behaviour)
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	WorldState.god_mode = false


# =============================== STANDING BY THEM: HELPED SURVIVORS PERSIST (owner round 42) ==================================
#
# "If you help them they should persist… in run 3 that floor should be a safe haven with no enemies… an in-peril survivor can give an
# item, scrap or money, and in later runs be a safe room that heals the player too." The player is what makes anyone permanent.

## A floor that is calm in ALL THREE runs (no fire on it or its neighbours), has no quest giver or rescue of its own, and whose ordinary
## dead number at least one in run 2 (so "the haven floor is empty" has something to be empty against). Call after new_game, with
## `survivor_rule` on.
func _calm_floor(want: int) -> int:
	for step in [0, 2, -2, 4, -4, 6, -6, 8, -8]:
		var f: int = want + step
		if f < 4 or f > 24:
			continue
		var ok: bool = Quests.corridor_records(f).is_empty()
		SurvivorPlan.rescue_for_floor(f)
		var rr = WorldState.survivors.get(SurvivorPlan.rescue_key_corridor(f), {})
		ok = ok and rr is Dictionary and bool(rr.get("none", false))
		var keep := WorldState.current_run
		for r in [1, 2, 3]:
			WorldState.current_run = r
			ok = ok and WorldState.fire_intensity(f) < 0 and WorldState.fire_intensity(f - 1) < 0 and WorldState.fire_intensity(f + 1) < 0
		WorldState.current_run = 2
		ok = ok and WorldState._base_floor_zombie_count(f) > 0
		WorldState.current_run = keep
		if ok:
			return f
	return want


func _playthrough(seed_value: int) -> void:
	WorldState.new_game()
	WorldState.survivor_rule = true
	WorldState.is_first_run = false
	WorldState.tutorial_completed = true
	WorldState.god_mode = true
	WorldState.dev_survivors = 0
	WorldState.master_seed = seed_value
	WorldState.current_run = 1


## The real corridor for `f` as the state stands (survivor_rule as given), emptied of what it rolled when `clear`.
func _build(f: int, clear: bool) -> Node:
	WorldState.current_floor = f
	WorldState.seed_floor_door_states(f)
	var bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await get_tree().physics_frame
	if clear:
		for z in get_tree().get_nodes_in_group("zombie"):
			if bf.is_ancestor_of(z):
				z.free()
		for sv in get_tree().get_nodes_in_group("survivor"):
			if bf.is_ancestor_of(sv):
				sv.free()
	return bf


func _test_stand_by_a_defender() -> void:
	print("[STANDING BY A DEFENDER: two of the dead put down beside one mid-fight = HELPED, and remembered]")
	_playthrough(777001)
	var f := _calm_floor(14)
	WorldState.survivor_rule = false                 # the floor is built empty; the defender below is the test's own
	var bf = await _build(f, true)
	WorldState.survivor_rule = true
	var rec := _rec("defender", "002", 0, 600.0)
	rec["floor"] = f
	var d := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, 600.0)
	_player(bf).global_position = Vector2(1150.0, 386.0)
	var aided0: int = int(WorldState.run_chronicle[0].get("npcs_aided", 0))
	var a := _zombie(bf, 700.0, 4, true)
	var far := _zombie(bf, 1000.0, 4, true)           # 400 away: past their sense and past the aid range
	check(await _until(func(): return d.behaviour in ["engage", "help"], 120), "(setup) the defender is in the fight (%s)" % d.behaviour)
	far.receive_damage(999, "blunt")
	await _frames(3)
	check(d._aid_kills == 0, "a death far from them is not help")
	a.receive_damage(999, "blunt")
	await _frames(3)
	check(d._aid_kills == 1 and not bool(rec.get("helped", false)), "one put down beside them is not yet enough (%d)" % d._aid_kills)
	check(WorldState.havens.is_empty(), "…and nothing is remembered yet")
	var c := _zombie(bf, 700.0, 4, true)
	check(await _until(func(): return d.behaviour in ["engage", "help"], 120), "(the next one comes and they fight it)")
	c.receive_damage(999, "blunt")
	await _frames(3)
	check(bool(rec.get("helped", false)) and bool(rec.get("aided", false)), "the second makes it HELPED")
	var h := WorldState.haven_info("f%d" % f)
	check(not h.is_empty() and str(h.get("kind", "")) == "post" and int(h.get("run", 0)) == 1, "the floor is remembered as theirs (%s)" % str(h))
	check(int(h.get("snap", {}).get("look", 0)) == 3 and str(h.get("snap", {}).get("weapon", "")) == "002" and float(h.get("snap", {}).get("post", 0)) == 600.0, "…with who they are and where they stand")
	check(d.last_moment == "helped", "…and they say so ('%s')" % d.last_moment)
	check(int(WorldState.run_chronicle[0].get("npcs_aided", 0)) == aided0 + 1, "…counted once as an NPC aided")
	check(not WorldState.haven_floor(f), "the floor is not quiet in the run it was earned in (its dead are already seeded)")
	var z4 := _zombie(bf, 700.0, 4, true)
	await _frames(40)
	z4.receive_damage(999, "blunt")
	await _frames(3)
	check(int(WorldState.run_chronicle[0].get("npcs_aided", 0)) == aided0 + 1, "more help is not counted again")
	# the last run has no later run to be quiet for
	WorldState.havens.clear()
	WorldState.current_run = 3
	var rec3 := _rec("defender", "002", 0, 400.0)
	rec3["floor"] = f
	var d3 := Survivor.spawn(bf, rec3, Survivor.FEET_CORRIDOR, 400.0)
	var z5 := _zombie(bf, 480.0, 4, true)
	var z6 := _zombie(bf, 470.0, 4, true)
	check(await _until(func(): return d3.behaviour in ["engage", "help"], 120), "(run 3: another defender in a fight)")
	z5.receive_damage(999, "blunt")
	z6.receive_damage(999, "blunt")
	await _frames(3)
	check(bool(rec3.get("helped", false)) and WorldState.havens.is_empty(), "helped in the last run: thanked, but there is no later run to remember it in")
	check(d3.last_moment == "helped_last", "…and they say the plainer thing ('%s')" % d3.last_moment)
	# a rescue's person is not 'helped' by kills — they have their own way
	WorldState.current_run = 1
	var rr := _rescue_rec("014")
	rr["floor"] = f
	var rd := Survivor.spawn(bf, rr, Survivor.FEET_CORRIDOR, 900.0)
	var rz := _zombie(bf, 940.0, 4, true)
	await _frames(20)
	rz.receive_damage(999, "blunt")
	await _frames(3)
	check(not bool(rr.get("helped", false)) and rd._aid_kills == 0, "a person shouting for help is saved or lost, never 'helped' by a stray kill")
	await _finish(bf)


func _test_haven_effects() -> void:
	print("[A HAVEN: from the next run the same person holds the same post, and the floor — its dead, its stairs, its boss — is empty]")
	_playthrough(777002)
	var f := _calm_floor(14)
	var rec := {"key": "x", "role": "defender", "floor": f, "apt": "", "look": 4, "weapon": "014", "ammo": 0, "post": 480.0, "post_kind": "door", "spot": 0.3, "max_hp": 8}
	check(SurvivorPlan.register_haven(rec, "post") and WorldState.haven_floor(f) == false, "(setup) a defender helped in run 1 on floor %d" % f)
	WorldState.current_run = 2
	var before_count := WorldState.get_floor_zombie_count(f)
	check(WorldState.haven_floor(f) and before_count == 0, "run 2: the haven floor holds no corridor dead (%d)" % before_count)
	var held := WorldState.havens.duplicate(true)
	WorldState.havens.clear()
	var control := WorldState.get_floor_zombie_count(f)
	check(control > 0, "(control: the same floor, same run, with no haven, holds %d)" % control)
	WorldState.havens = held
	# only its own floor and staircases change — compare every other floor / choke value against the no-haven world
	var count_diff: Array = []
	var choke_diff: Array = []
	var boss_diff: Array = []
	for g in range(1, 30):
		var with_c := WorldState.get_floor_zombie_count(g)
		var with_s := WorldState.stair_enemy_count(g)
		var with_b := WorldState.floor_has_boss(g)
		WorldState.havens = {}
		if with_c != WorldState.get_floor_zombie_count(g):
			count_diff.append(g)
		if with_s != WorldState.stair_enemy_count(g):
			choke_diff.append(g)
		if with_b != WorldState.floor_has_boss(g):
			boss_diff.append(g)
		WorldState.havens = held
	check(count_diff.is_empty() or count_diff == [f], "no other floor's headcount moved (differs on: %s)" % str(count_diff))
	check(choke_diff.is_empty() or choke_diff.all(func(c): return c == f or c == f + 1), "no other staircase's population moved (differs on: %s)" % str(choke_diff))
	check(boss_diff.is_empty() or boss_diff == [f], "no other floor's boss moved (differs on: %s)" % str(boss_diff))
	# a staircase that does hold dead, on this floor's two sides, is emptied
	WorldState.havens = {}
	var c_hit := -1
	for c in range(3, 29):
		if WorldState.stair_enemy_count(c) > 0:
			c_hit = c
			break
	check(c_hit > 0, "(a staircase with dead on it exists: %d)" % c_hit)
	if c_hit > 0:
		WorldState.current_run = 1
		check(WorldState.note_haven("f%d" % c_hit, {"kind": "post", "floor": c_hit, "apt": "", "snap": {}}), "(a haven on floor %d, run 1)" % c_hit)
		WorldState.current_run = 2
		check(WorldState.haven_floor(c_hit) and WorldState.stair_enemy_count(c_hit) == 0, "the floor's own down staircase (choke %d) is empty" % c_hit)
		WorldState.havens = {}
		WorldState.current_run = 1
		check(WorldState.note_haven("f%d" % (c_hit - 1), {"kind": "post", "floor": c_hit - 1, "apt": "", "snap": {}}), "(a haven on floor %d instead)" % (c_hit - 1))
		WorldState.current_run = 2
		check(WorldState.haven_floor(c_hit - 1) and WorldState.stair_enemy_count(c_hit) == 0, "…and the staircase that climbs to it from below (choke %d, seen from floor %d) is empty" % [c_hit, c_hit - 1])
	# a boss floor loses its boss
	WorldState.havens = {}
	WorldState.current_run = 2
	var boss_floor := -1
	for g in range(4, 27):
		if WorldState.floor_has_boss(g):
			boss_floor = g
			break
	check(boss_floor > 0, "(a floor with a roaming boss exists: %d)" % boss_floor)
	if boss_floor > 0:
		WorldState.current_run = 1
		check(WorldState.note_haven("f%d" % boss_floor, {"kind": "post", "floor": boss_floor, "apt": "", "snap": {}}), "(a haven on floor %d, run 1)" % boss_floor)
		WorldState.current_run = 2
		check(WorldState.haven_floor(boss_floor) and not WorldState.floor_has_boss(boss_floor), "the haven floor's boss is gone")
	# the person: same look / weapon / post, a quiet floor built for real
	WorldState.havens = held
	WorldState.survivors.clear()
	WorldState.current_run = 2
	var bf = await _build(f, false)
	var zs := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if bf.is_ancestor_of(z):
			zs += 1
	check(zs == 0, "built for real: no dead on the haven floor (%d)" % zs)
	var me: Survivor = null
	for sv in get_tree().get_nodes_in_group("survivor"):
		if bf.is_ancestor_of(sv) and bool(sv.rec.get("haven", false)):
			me = sv
	check(me != null, "…and the person you stood by is at their post")
	if me != null:
		check(me.look == 4 and me.weapon == "014" and absf(me.post - 480.0) < 0.5 and me.role == "defender", "…the same look, weapon and post (%d / %s / %.0f)" % [me.look, me.weapon, me.post])
		check(me.rec["key"] == SurvivorPlan.haven_key(f) and WorldState.survivors.has(SurvivorPlan.haven_key(f)), "…one identity, kept under a run-less key")
		_player(bf).global_position = Vector2(me.global_position.x - 30.0, 386.0)
		await _frames(30)
		check(me.behaviour == "hold", "…holding, calm (%s)" % me.behaviour)
		var said := me.talk()
		check(said != "" and me.last_moment == "haven", "…and they greet the one who stood by them ('%s')" % me.last_moment)
		# helped-again can never double the Valour or re-register
		var n0: int = int(WorldState.run_chronicle[1].get("npcs_aided", 0)) if WorldState.run_chronicle.size() > 1 else 0
		var z1 := _zombie(bf, me.global_position.x + 90.0, 4, true)
		var z2 := _zombie(bf, me.global_position.x + 80.0, 4, true)
		await _until(func(): return me.behaviour in ["engage", "help"], 120)
		z1.receive_damage(999, "blunt")
		z2.receive_damage(999, "blunt")
		await _frames(3)
		var n1: int = int(WorldState.run_chronicle[1].get("npcs_aided", 0)) if WorldState.run_chronicle.size() > 1 else 0
		check(n1 == n0, "a haven's person, fought beside again, does not pay out twice")
	# an unhelped floor is untouched
	var g_plain := -1
	for g in range(4, 25):
		if g != f and not WorldState.haven_floor(g):
			g_plain = g
			break
	check(g_plain > 0 and not WorldState.haven_floor(g_plain) and SurvivorPlan.haven_for_floor(g_plain).is_empty(), "a floor nobody stood by has no haven")
	# a rescue still to come on a floor keeps the post out of the haven list (the person who will be shouting owns it)
	WorldState.havens.clear()
	WorldState.survivors[SurvivorPlan.rescue_key_corridor(f)] = {"key": "r", "role": "defender", "rescue": "pending", "appears": 3, "floor": f}
	check(not SurvivorPlan.can_haven_floor(f) and not SurvivorPlan.register_haven(rec, "post"), "a floor with a rescue still to happen cannot become a haven")
	WorldState.survivors.erase(SurvivorPlan.rescue_key_corridor(f))
	await _finish(bf)


func _saved_rescue(bf: Node, gift: String, n: int, x: float) -> Dictionary:
	var rec := _rescue_rec("014", "defender", 1)
	rec["floor"] = WorldState.current_floor
	rec["gift"] = gift
	rec["gift_n"] = n
	var d := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, x)
	var dead_ones := SurvivorPlan.spawn_rescue_dead(bf, rec, x, 370.0, 265.0, 1105.0, -1.0, 12, false)
	await _frames(30)
	for z in dead_ones:
		z.receive_damage(999, "blunt")
	await _frames(20)
	return {"rec": rec, "who": d}


func _test_rescue_reward_and_heal() -> void:
	print("[A RESCUE: an item, scrap or money now — and in a later run they patch you up, once a run]")
	_playthrough(777003)
	var f := _calm_floor(14)
	WorldState.survivor_rule = false
	var bf = await _build(f, true)
	WorldState.survivor_rule = true
	_player(bf).global_position = Vector2(1150.0, 386.0)
	# scrap
	var got = await _saved_rescue(bf, "037", 28, 900.0)
	var rec: Dictionary = got["rec"]
	var d: Survivor = got["who"]
	check(str(rec.get("rescue", "")) == "saved" and int(rec.get("saved_run", 0)) == 1, "(setup) saved in run 1")
	var h := WorldState.haven_info("f%d" % f)
	check(str(h.get("kind", "")) == "rescue" and int(h.get("run", 0)) == 1, "…and the floor is remembered as theirs (%s)" % str(h.get("kind", "")))
	var scrap0 := WorldState.scrap
	_player(bf).global_position = Vector2(d.global_position.x - 30.0, 386.0)
	await _frames(5)
	d.talk()
	check(WorldState.scrap == scrap0 + 28, "their thank-you can be scrap (+28: %d → %d)" % [scrap0, WorldState.scrap])
	check(bool(rec.get("gave", false)), "…given once")
	var heal_before := WorldState.player_health
	d.talk()
	check(d.last_moment == "rescue_thanks" and WorldState.player_health == heal_before, "in the same run they only thank you (no patching up yet)")
	# money
	WorldState.wallet_unlocked = true
	var got2 = await _saved_rescue(bf, "033", 40, 700.0)
	var d2: Survivor = got2["who"]
	var wallet0 := WorldState.wallet_balance
	_player(bf).global_position = Vector2(d2.global_position.x + 30.0, 386.0)
	await _frames(5)
	d2.talk()
	check(WorldState.wallet_balance == wallet0 + 40, "…or money (+40: %d → %d)" % [wallet0, WorldState.wallet_balance])
	# the table itself: scrap and money are rescue gifts only
	check(not SurvivorPlan.GIFTS.has("037") and not SurvivorPlan.GIFTS.has("033"), "an ordinary hider's table is unchanged (no scrap, no money)")
	var seen := {}
	for i in 400:
		seen[SurvivorPlan._weighted_gift(SurvivorPlan._rng("rg%d" % i), SurvivorPlan.RESCUE_GIFTS)] = true
	check(seen.has("037") and seen.has("033") and seen.has("006"), "a rescue's thank-you is drawn from items, scrap and money (%s)" % str(seen.keys()))
	# a later run: patched up
	WorldState.current_run = 2
	var p = _player(bf)
	var d3 := Survivor.spawn(bf, rec, Survivor.FEET_CORRIDOR, 900.0)
	await _frames(3)
	check(d3.behaviour == "hold" and not d3.rescuing, "run 2: they are still there, holding (%s)" % d3.behaviour)
	p.dev_set_health_state(3)
	check(WorldState.player_health == 3, "(the player is wounded)")
	d3.talk()
	check(WorldState.player_health == 0 and d3.last_moment == "haven_tend", "they patch the player up all the way ('%s', health %d)" % [d3.last_moment, WorldState.player_health])
	check(int(rec.get("tended_run", 0)) == 2, "…recorded for this run")
	p.dev_set_health_state(2)
	d3.talk()
	check(WorldState.player_health == 2 and d3.last_moment == "haven_again", "…but only once a run ('%s', health %d)" % [d3.last_moment, WorldState.player_health])
	WorldState.current_run = 3
	d3.talk()
	check(WorldState.player_health == 0 and d3.last_moment == "haven_tend", "run 3: they can do it again")
	d3.talk()
	check(d3.last_moment == "haven_fine", "…and, healthy now, the player just gets a word ('%s')" % d3.last_moment)
	p.dev_set_health_state(0)
	WorldState.current_run = 2
	rec["tended_run"] = 0
	d3.talk()
	check(d3.last_moment == "haven_fine", "a healthy player is not 'patched up' ('%s')" % d3.last_moment)
	check(not rec.has("helped") and d3._aid_kills == 0, "(a rescued person is never ALSO a 'helped' defender)")
	await _finish(bf)


func _test_safe_room() -> void:
	print("[A SAFE ROOM: a flat whose shouting hider you saved holds no dead in the next run — and they patch you up]")
	_playthrough(777004)
	var apt := ""
	for f in range(4, 20):
		WorldState.seed_floor_door_states(f)
		for col in range(1, 6):
			var a := "%d%02d" % [f, col]
			if SurvivorPlan.hider_flat_ok(a) and WorldState.get_door_state(a) == WorldState.DoorState.OPEN:
				WorldState.current_run = 2
				var n := WorldState.get_apartment_zombie_count(a)
				WorldState.current_run = 1
				if n > 0:
					apt = a
					break
		if apt != "":
			break
	check(apt != "", "(setup) a walk-in flat that holds dead in run 2 (%s)" % apt)
	if apt == "":
		return
	var f := WorldState._apartment_floor(apt)
	var key := SurvivorPlan.rescue_key_flat(apt)
	var seeded := SurvivorPlan._roll(key, "hider", f, apt, 1)
	seeded["rescue"] = "pending"
	seeded["appears"] = 1
	seeded["peril"] = SurvivorPlan.RESCUE_HOLD
	WorldState.survivors[key] = seeded
	# saved in run 1 (the same call the survivor makes)
	seeded["rescue"] = "saved"
	seeded["saved_run"] = 1
	check(SurvivorPlan.register_haven(seeded, "rescue") and WorldState.haven_info(apt).get("kind", "") == "rescue", "a flat rescue registers the FLAT (not the floor): %s" % str(WorldState.haven_info(apt).keys()))
	check(not WorldState.havens.has("f%d" % f), "…the corridor outside is not a haven")
	WorldState.current_run = 2
	check(WorldState.haven_flat(apt) and not WorldState.haven_flat("1" + apt), "from run 2 the flat is a safe room")
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = f
	WorldState.spawn_source = ""
	WorldState.saved_player_x = 0.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _frames(4)
	var inside := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			inside += 1
	check(inside == 0, "built for real: no dead inside (%d)" % inside)
	var h = room.get("hider")
	check(h != null and is_instance_valid(h) and not h.rescuing and h.behaviour == "trust", "…and the person you saved is there, trusting you (%s)" % (h.behaviour if h != null else "-"))
	if h != null:
		var p = room.get_node("Player")
		p.dev_set_health_state(4)
		h.rec["gave"] = true
		h.talk()
		check(WorldState.player_health == 0 and h.last_moment == "haven_tend", "…and patches the player up ('%s')" % h.last_moment)
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# control: the same flat with no haven holds its dead
	WorldState.havens.clear()
	room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await _frames(4)
	var control := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			control += 1
	check(control > 0, "(control: with no haven the same flat holds %d)" % control)
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	WorldState.god_mode = false


func _test_haven_roundtrip() -> void:
	print("[HAVENS are saved: a Continue keeps who you stood by]")
	_playthrough(777005)
	SurvivorPlan.register_haven({"key": "x", "role": "defender", "floor": 9, "apt": "", "look": 2, "weapon": "001", "ammo": 0, "post": 300.0, "post_kind": "door", "spot": 0.1, "max_hp": 8}, "post")
	var before := WorldState.havens.duplicate(true)
	check(before.has("f9"), "(setup) a haven on floor 9")
	WorldState.save_game("res://scenes/hallway.tscn")
	WorldState.havens.clear()
	WorldState.load_game()
	var as_json = JSON.parse_string(JSON.stringify(before))          # (JSON hands every number back as a float)
	check(WorldState.havens == as_json and WorldState.haven_info("f9").get("snap", {}).get("look", 0) == 2.0 and int(WorldState.haven_info("f9").get("run", 0)) == 1, "…it survives the real save and load (string keys)")
	WorldState.new_game()
	check(WorldState.havens.is_empty(), "a new game forgets them")

