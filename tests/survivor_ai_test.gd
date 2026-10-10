extends Node

# Headless test for the SURVIVORS (docs/NPC_AI.md): who is where, how they think, how they fight — and that they
# fight at HALF the player's damage. Every pattern the doc promises is asserted here by running the real thing.
#   godot --headless res://tests/survivor_ai_test.tscn

var failures: int = 0
var _n: int = 0
const STANDARD := "res://scenes/enemy_zombie_standard.tscn"


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== survivor AI test ===")
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
	await _test_plan_rules()
	await _test_persistence()
	await _test_spawning()
	await _test_hider_in_a_flat()
	_test_safety_and_dialogue()
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
					if str(r.get("quest", "")) != "":
						continue                # a quest giver is specified by data/quests.json (quest_test), not by the random role tables
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
			if SurvivorPlan.hider_flat_ok(a) and not SurvivorPlan.hider_for(a).is_empty() and WorldState.get_door_state(a) == WorldState.DoorState.OPEN:
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
		"all": ["hurt", "death"],
		"defender": ["greet", "greet_again", "spot", "engage", "help", "wounded", "recovered", "out_of_ammo", "clear", "thanks"],
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
