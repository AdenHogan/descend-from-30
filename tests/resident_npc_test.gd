extends Node

# RESIDENTS (owner round 32): survivors holed up behind LOCKED doors who shout, square up, run, threaten,
# beg, attack or trade (scripts/resident_npc.gd, WorldState "RESIDENTS", data/npc_dialogue.json).
# Run: godot --headless res://tests/resident_npc_test.tscn

var failures := 0
const NPC := preload("res://scripts/resident_npc.gd")


func check(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		failures += 1


func _ready() -> void:
	print("=== resident npc test ===")
	WorldState.new_game()
	WorldState.dev_residents = 0
	_test_seeding()
	_test_dialogue_file()
	await _test_hostile()
	await _test_scared()
	await _test_trader()
	WorldState.dev_residents = 0
	WorldState.god_mode = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _apts() -> Array:
	var out := []
	for f in range(1, 31):
		for i in range(1, 6):
			out.append(str(f) + "0" + str(i))
	return out


func _test_seeding() -> void:
	print("[who lives where: only behind locked doors, fewer as the arc goes on]")
	var per_run := []
	var tempers := {}
	var ok_doors := true
	var ok_arms := true
	var ok_look := true
	for run in [1, 2, 3]:
		WorldState.current_run = run
		WorldState.residents.clear()
		WorldState.floor_states_seeded.clear()
		WorldState.door_states.clear()
		var n := 0
		for a in _apts():
			var r: Dictionary = WorldState.resident_for(a)
			if r.is_empty():
				continue
			n += 1
			tempers[r["temper"]] = true
			if not WorldState.is_locked_apartment(a) or WorldState._apartment_floor(a) >= 30:
				ok_doors = false
			if r["temper"] == "hostile" and str(r["weapon"]) == "":
				ok_arms = false
			if (int(r["look"]) == WorldState.RESIDENT_STICK_LOOK) != (str(r["weapon"]) in WorldState.RESIDENT_STICK_WEAPONS):
				ok_look = false
		per_run.append(n)
	check(per_run[0] >= 3 and per_run[2] >= 1, "residents turn up in every run (%s)" % str(per_run))
	# Fewer by night: the share of locked flats with someone in, over a few buildings (the count of
	# locked doors itself changes by run, so compare shares, not counts).
	var share := [0.0, 0.0, 0.0]
	for run in [1, 2, 3]:
		var hit := 0
		var locked := 0
		for sd in [11, 222, 3333, 44444, 555555, 6666666, 7, 88, 999, 1010]:
			WorldState.master_seed = sd
			WorldState.current_run = run
			WorldState.residents.clear()
			WorldState.floor_states_seeded.clear()
			WorldState.door_states.clear()
			WorldState.gun_cabinets.clear()
			for a in _apts():
				if WorldState.resident_eligible(a):
					locked += 1
					if not WorldState.resident_for(a).is_empty():
						hit += 1
		share[run - 1] = float(hit) / maxf(1.0, float(locked))
	check(share[0] > share[1] and share[1] > share[2], "...fewer as the arc goes on (share of locked flats %.2f / %.2f / %.2f)" % share)
	check(ok_doors, "only ever behind a LOCKED door, never on Floor 30")
	check(tempers.size() == 3, "all three tempers turn up (%s)" % str(tempers.keys()))
	check(ok_arms, "a hostile resident is always armed")
	check(ok_look, "the look with a stick in its art carries a bat / club — and only then")
	# Stable once settled, and KEPT when the lock gives (the player walks in after the door opens).
	WorldState.current_run = 1
	WorldState.residents.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.door_states.clear()
	var apt := ""
	for a in _apts():
		if not WorldState.resident_for(a).is_empty():
			apt = a
			break
	check(apt != "", "found a resident's flat (%s)" % apt)
	if apt == "":
		return
	var before: Dictionary = WorldState.resident_for(apt).duplicate()
	WorldState.residents.clear()                       # as if never listened at: decided at the door
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	check(WorldState.resident_for(apt).get("temper", "") == before.get("temper", "?"),
		"the lock gives: the same resident is still there (%s)" % str(WorldState.resident_for(apt).get("temper", "none")))
	var open_apt := ""
	for a in _apts():
		if WorldState.get_door_state(a) == WorldState.DoorState.OPEN and WorldState._apartment_floor(a) < 30 and a != apt:
			open_apt = a
			break
	check(open_apt != "" and WorldState.resident_for(open_apt).is_empty(), "an unlocked flat never has one (%s)" % open_apt)
	# Listening at their door: a voice, not a count.
	WorldState.residents.clear()
	WorldState.door_states.clear()
	WorldState.floor_states_seeded.clear()
	var rep: Dictionary = WorldState.get_listen_report_for_apartment(apt)
	var want: String = str(WorldState.resident_lines()["listen"][before["temper"]])
	check(rep.get("line", "") == want and int(rep.get("count", -1)) == 0, "listening at the door: '%s'" % rep.get("line", ""))
	# A save carries them.
	check(JSON.stringify(WorldState.residents) != "{}", "kept in the save block (residents)")


func _test_dialogue_file() -> void:
	print("[the dialogue file holds a line for every moment the residents use]")
	var lines := WorldState.resident_lines()
	var need := {
		"scared": ["enter", "enter_key", "enter_again", "leave_demand", "too_close", "cornered", "scavenge_beg", "item_taken", "lash_out", "calm", "hurt", "death"],
		"hostile": ["enter", "enter_key", "enter_again", "leave_demand", "too_close", "threaten", "scavenge_warn", "attack", "item_taken", "calm", "hurt", "death"],
		"trader": ["enter", "enter_key", "enter_again", "leave_demand", "too_close", "trade_offer", "trade_reminder", "trade_done", "trade_declined", "trade_refused", "turned_hostile", "no_trade", "calm", "hurt", "death"],
	}
	var missing := []
	for t in need:
		for m in need[t]:
			var pool = lines.get(t, {}).get(m, [])
			if not (pool is Array) or pool.is_empty():
				missing.append(t + "." + m)
	check(missing.is_empty(), "every moment has lines (missing: %s)" % str(missing))
	check(lines.get("listen", {}).size() == 3, "a listen line per temper")


# --- live flats ---------------------------------------------------------------------------------

func _resident_flat() -> String:
	WorldState.residents.clear()
	WorldState.floor_states_seeded.clear()
	WorldState.door_states.clear()
	for a in _apts():
		if WorldState.resident_eligible(a) and not WorldState.resident_for(a).is_empty():
			return a
	return ""


func _open_flat(apt: String) -> Node:
	WorldState.set_door_state(apt, WorldState.DoorState.OPEN)
	WorldState.current_apartment_id = apt
	WorldState.current_floor = WorldState._apartment_floor(apt)
	WorldState.spawn_source = ""
	WorldState.saved_player_x = 0.0
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	return room


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _close(room: Node) -> void:
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_hostile() -> void:
	print("[a HOSTILE resident: squares up, warns once, then attacks; it can be fought and killed]")
	WorldState.new_game()
	WorldState.current_run = 1
	WorldState.dev_residents = 3
	var apt := _resident_flat()
	check(apt != "", "a hostile resident's flat (%s)" % apt)
	if apt == "":
		return
	var room := _open_flat(apt)
	await _frames(3)
	var npc = room.get("resident")
	check(npc != null and is_instance_valid(npc) and npc.temper == "hostile", "they're home")
	if npc == null:
		await _close(room)
		return
	var zs := 0
	for z in get_tree().get_nodes_in_group("zombie"):
		if room.is_ancestor_of(z):
			zs += 1
	check(zs == 0, "no dead in with them (%d)" % zs)
	check(npc.is_in_group("resident_target") and not npc.is_in_group("zombie"), "a combat target, never a 'zombie'")
	check(npc.collision_layer == 0 and npc.collision_mask == 0, "no collision: it can never block the player")
	var p = get_tree().get_first_node_in_group("player")
	check(absf(npc.position.y - NPC.FEET_Y) < 0.5 and absf(npc.position.y - (p.position.y + 33.0)) < 1.5,
		"feet on the flat's walking line, level with the player's (%.0f vs %.0f)" % [npc.position.y, p.position.y + 33.0])
	p.global_position.x = npc.global_position.x + (-300.0 if npc.global_position.x > 600.0 else 300.0)
	await _frames(40)
	check(npc.last_moment == "enter", "it shouts as you come in ('%s')" % npc.last_line)
	var d0: float = absf(p.global_position.x - npc.global_position.x)
	await _frames(150)
	var d1: float = absf(p.global_position.x - npc.global_position.x)
	check(d1 < d0 - 60.0 and d1 < NPC.STANDOFF + 50.0, "it comes at you and squares up (%.0f → %.0f)" % [d0, d1])
	# Searching: one warning, then it goes for you.
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(npc.last_moment == "scavenge_warn" and not npc.violent, "first search: a warning ('%s')" % npc.last_line)
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(npc.violent and npc.last_moment == "attack", "search again: it attacks ('%s')" % npc.last_line)
	check(bool(WorldState.resident_for(apt).get("violent", false)), "...and stays angry (saved)")
	WorldState.god_mode = false
	var hp_before: int = p.health_state
	await _frames(200)
	check(p.health_state > hp_before, "it lands hits (health stage %d → %d)" % [hp_before, p.health_state])
	# Fight back with what's in your hand.
	p.health_state = 0
	WorldState.player_health = 0
	p.is_dying = false
	WorldState.god_mode = true
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")
	var inst = WorldState.get_instance_at(0)
	p.global_position.x = npc.global_position.x - 20.0
	p.get_node("AnimatedSprite2D").flip_h = false
	var hp0: int = npc.current_hp
	p.is_attacking = false
	p._do_melee_attack(inst, 0)
	check(npc.current_hp < hp0, "a swing lands on them (hp %d → %d)" % [hp0, npc.current_hp])
	check(p.push_target() == npc, "a shove picks them too")
	var drops_before := WorldState.world_drops.size()
	npc.receive_damage(99, "test")
	check(npc.is_dead and not npc.is_in_group("resident_target"), "they can die")
	check(npc.last_moment == "death", "...with a last word ('%s')" % npc.last_line)
	var expect_drops: int = (1 if npc.weapon != "" else 0) + npc.rec.get("goods", []).size()
	check(WorldState.world_drops.size() - drops_before == expect_drops,
		"...dropping their weapon + pockets (%d of %d)" % [WorldState.world_drops.size() - drops_before, expect_drops])
	await _close(room)
	room = _open_flat(apt)
	await _frames(3)
	npc = room.get("resident")
	check(npc != null and npc.is_dead and not npc.is_in_group("resident_target"), "come back: they still lie there")
	await _close(room)
	WorldState.god_mode = false


func _test_scared() -> void:
	print("[a SCARED resident: runs from you, cowers, begs]")
	WorldState.new_game()
	WorldState.current_run = 1
	WorldState.dev_residents = 2
	var apt := _resident_flat()
	if apt == "":
		check(false, "a scared resident's flat")
		return
	var room := _open_flat(apt)
	await _frames(3)
	var npc = room.get("resident")
	check(npc != null and npc.temper == "scared", "a scared one's home")
	if npc == null:
		await _close(room)
		return
	var p = get_tree().get_first_node_in_group("player")
	var bounds: Vector2 = npc._bounds()
	# Stand between them and the middle of the room; they bolt for the far wall.
	var away := 1.0 if npc.global_position.x > (bounds.x + bounds.y) * 0.5 else -1.0
	p.global_position.x = npc.global_position.x - away * 70.0
	var d0: float = absf(p.global_position.x - npc.global_position.x)
	await _frames(90)
	var d1: float = absf(p.global_position.x - npc.global_position.x)
	check(d1 > d0 + 30.0 or npc.state == "cower", "it runs from you (%.0f → %.0f, %s)" % [d0, d1, npc.state])
	# Corner it.
	var wall: float = bounds.y if away > 0.0 else bounds.x
	npc.global_position.x = wall
	p.global_position.x = wall - away * 30.0
	await _frames(20)
	check(npc.state == "cower" and npc.last_moment == "cornered", "backed into a corner it cowers ('%s')" % npc.last_line)
	# Through the real loot panel: opening a search, then taking what's in it.
	var lui = room.find_child("LootUI", true, false)
	lui.open("025", "test_anchor", apt)
	check(npc.last_moment == "scavenge_beg", "search: it begs ('%s')" % npc.last_line)
	WorldState.inventory.clear()
	lui.is_revealing = false
	lui.has_item = true
	lui._take()
	check(npc.last_moment == "item_taken", "take something: '%s'" % npc.last_line)
	# Cornered long enough, it snaps (lash) or makes a break for it past you (dash).
	WorldState.god_mode = true
	var broke := false
	for k in int(NPC.CORNER_TIME * 60.0) + 90:
		await get_tree().physics_frame
		if npc.violent or npc.state == "dash":
			broke = true
			break
	check(broke, "cornered too long: it snaps at you or bolts past you (%s, lash %s)" % [npc.state, str(npc.rec.get("lash"))])
	WorldState.god_mode = false
	await _close(room)


func _test_trader() -> void:
	print("[a TRADER: offers a swap when you search, takes it, or turns on you when robbed]")
	WorldState.new_game()
	WorldState.current_run = 1
	WorldState.dev_residents = 4
	var apt := _resident_flat()
	if apt == "":
		check(false, "a trader's flat")
		return
	var rec: Dictionary = WorldState.resident_for(apt)
	check(not rec.get("goods", []).is_empty(), "a trader has goods (%s)" % str(rec.get("goods", [])))
	var room := _open_flat(apt)
	await _frames(3)
	var npc = room.get("resident")
	if npc == null:
		check(false, "the trader's home")
		await _close(room)
		return
	var p = get_tree().get_first_node_in_group("player")
	p.global_position.x = npc.global_position.x - 100.0
	WorldState.inventory.clear()
	WorldState.add_to_inventory("025")              # junk: nothing they want
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(npc.offer.is_empty() and npc.last_moment == "no_trade", "nothing worth having: no deal ('%s')" % npc.last_line)
	WorldState.add_to_inventory("013")              # a cricket bat (never one of a resident's goods)
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(not npc.offer.is_empty() and npc.last_moment == "trade_offer", "search: an offer ('%s')" % npc.last_line)
	var give_id: String = str(npc.offer.get("give", {}).get("id", ""))
	check(npc.last_line.find(ItemData.get_item(give_id).get("name", "?")) >= 0 or npc.last_line.find("{") < 0,
		"...naming the goods, no raw placeholders left")
	check(npc._offer_row.visible, "[Trade] / [No] show in the bubble")
	await get_tree().process_frame
	var r: Rect2 = npc._bubble.get_global_rect()
	check(HUD.pointer_over_widget(r.get_center()), "a click on the bubble isn't a swing or a walk (HUD widget)")
	var ok: bool = npc.accept_trade()
	var have_give := false
	var have_bat := false
	for inst in WorldState.inventory:
		if inst.item_id == give_id:
			have_give = true
		if inst.item_id == "013":
			have_bat = true
	check(ok and have_give and not have_bat, "the swap: their %s for your bat" % give_id)
	check(bool(WorldState.resident_for(apt).get("traded", false)) and npc.last_moment == "trade_done", "...done, and remembered")
	await _close(room)
	# Robbed after an offer: this one turns.
	WorldState.new_game()
	WorldState.dev_residents = 4
	apt = _resident_flat()
	WorldState.resident_for(apt)["turn"] = true
	room = _open_flat(apt)
	await _frames(3)
	npc = room.get("resident")
	WorldState.inventory.clear()
	WorldState.add_to_inventory("013")
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(not npc.offer.is_empty(), "(an offer is on the table)")
	get_tree().call_group("resident_npc", "on_scavenge", "take", apt)
	check(npc.violent and npc.last_moment == "turned_hostile", "rob them after an offer: they turn on you ('%s')" % npc.last_line)
	await _close(room)
	# A trader who turned you down ("nothing I want — hands off") is robbed just the same.
	WorldState.new_game()
	WorldState.dev_residents = 4
	apt = _resident_flat()
	WorldState.resident_for(apt)["turn"] = false
	room = _open_flat(apt)
	await _frames(3)
	npc = room.get("resident")
	WorldState.inventory.clear()
	get_tree().call_group("resident_npc", "on_scavenge", "start", apt)
	check(npc.last_moment == "no_trade", "empty pack: no deal ('%s')" % npc.last_line)
	get_tree().call_group("resident_npc", "on_scavenge", "take", apt)
	check(not npc.violent and npc.last_moment == "trade_refused", "...take it anyway: they protest ('%s')" % npc.last_line)
	await _close(room)
