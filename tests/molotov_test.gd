extends Node

# MOLOTOV COCKTAIL + CRAFTING (owner round 30: "a Molotov cocktail that is thrown like the can, only when it hits enemies or
# areas it breaks and creates flame… crafted with a bottle (not broken) and one torn clothing… found premade in scavenge… their
# fire aoe will work the same as fire now, only it will be a splash spread… crafting/merging happens from the item wheel in the
# backpack — players drag items to items in the wheel… three clothes into rope").
#  * item 039: data, flags, icon, spawn pool entries;
#  * Crafting: plan/craft rules (never the Broken Bottle, one unit per input, either way round, rope = 3 clothes, nothing lost
#    when the result won't fit);
#  * the thrown molotov bursts into a MolotovFire where it lands; the splash plays by the floor fire's rules (enemies catch,
#    the player burns unless sprinting, never blocks, dies out, the extinguisher douses it);
#  * the player throws one; the backpack ring crafts by drag and still equips on a plain click.
# Run:  godot --headless res://tests/molotov_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== molotov + crafting test ===")
	await get_tree().process_frame
	_test_item()
	_test_crafting()
	await _test_thrown_burst()
	await _test_fire_rules()
	await _test_player_throws()
	await _test_ring_drag()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh() -> void:
	WorldState.new_game()
	WorldState.inventory.clear()
	HUD.selected_slot = -1


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _ids() -> Array:
	var out: Array = []
	for inst in WorldState.inventory:
		out.append(inst.item_id)
	return out


# ---------------------------------------------------------------- the item

func _test_item() -> void:
	print("[item 039]")
	var d: Dictionary = ItemData.get_item("039")
	check(str(d.get("name", "")) == "Molotov Cocktail", "item 039 is the Molotov Cocktail")
	check(bool(d.get("is_molotov", false)) and bool(d.get("is_throwable", false)), "it is throwable + flagged is_molotov")
	check(not bool(d.get("is_bottle", false)) and not bool(d.get("is_junk", false)), "…and is not itself a bottle or junk (it must not be craftable twice or salvaged as rubbish)")
	check(ItemData.get_texture("039") != null, "it has an icon")
	var pools: Dictionary = ItemData.room_spawn_pools
	var weights := 0
	for room in ["bedroom", "kitchen", "bathroom", "study", "living_room", "dining_room"]:
		var w: int = int(pools.get("Molotov Cocktail", {}).get(room, -1))
		check(w >= 0, "spawn pool names the %s" % room)
		weights += maxi(0, w)
	check(weights > 0, "…and at least one room can actually roll it (premade molotovs turn up in scavenging)")
	check(int(d.get("rarity", 0)) == 1, "it is a RARE find (rarity 1)")
	# it stacks like a can
	_fresh()
	for _i in range(3):
		check(WorldState.add_to_inventory("039"), "a molotov fits")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 3, "three molotovs share one slot (throwables stack to 3)")
	check(not WorldState.add_to_inventory("039") or WorldState.inventory.size() == 2, "a fourth takes a new slot rather than overflowing the stack")


# ---------------------------------------------------------------- crafting rules

func _test_crafting() -> void:
	print("[crafting rules]")
	_fresh()
	WorldState.add_to_inventory("024")      # 0 empty bottle
	WorldState.add_to_inventory("009")      # 1 torn clothes
	WorldState.add_to_inventory("002")      # 2 hammer (unrelated)
	var pl: Dictionary = Crafting.plan(0, 1)
	check(bool(pl.get("ok", false)) and str(pl.get("result", "")) == "039", "a bottle + torn clothes plan to a Molotov")
	check(Crafting.plan(1, 0).get("recipe", "") == "molotov", "…either way round")
	check(Crafting.plan(0, 2).is_empty() and Crafting.plan(1, 2).is_empty(), "an unrelated pair has no recipe at all")
	check(Crafting.plan(0, 0).is_empty() and Crafting.plan(0, 9).is_empty() and Crafting.plan(-1, 1).is_empty(), "a slot onto itself / out of range / empty is nothing")
	var r: Dictionary = Crafting.craft(0, 2)
	check(not bool(r["ok"]) and WorldState.inventory.size() == 3, "crafting an unrelated pair refuses and changes nothing")
	r = Crafting.craft(1, 0)
	check(bool(r["ok"]) and str(r["name"]) == "Molotov Cocktail", "crafting (dragging the cloth onto the bottle) works")
	check(_ids().has("039") and not _ids().has("024") and not _ids().has("009") and _ids().has("002"), "…the bottle and the cloth are spent, the molotov is made, the hammer is untouched")
	# the broken bottle never counts
	_fresh()
	WorldState.add_to_inventory("023")
	WorldState.add_to_inventory("009")
	check(Crafting.plan(0, 1).is_empty(), "a BROKEN bottle can't make a molotov")
	check(not bool(Crafting.craft(0, 1)["ok"]) and _ids() == ["023", "009"], "…and trying it spends nothing")
	# one unit per input: a stack of bottles loses ONE bottle
	_fresh()
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("009")
	check(WorldState.inventory.size() == 2 and WorldState.inventory[0].count == 2, "(setup) two bottles in one slot + a cloth")
	check(bool(Crafting.craft(0, 1)["ok"]), "crafting from a stack works")
	check(WorldState.inventory[0].item_id == "024" and WorldState.inventory[0].count == 1, "…the stack lost ONE bottle, not both")
	check(_ids().has("039") and not _ids().has("009"), "…the cloth is spent and the molotov is in the pack")
	# a second molotov stacks onto the first
	WorldState.add_to_inventory("009")
	check(bool(Crafting.craft(0, WorldState.inventory.size() - 1)["ok"]), "a second craft…")
	var mol := 0
	for inst in WorldState.inventory:
		if inst.item_id == "039":
			mol += inst.count
	check(mol == 2 and WorldState.inventory.size() == 1, "…and the two molotovs stack in ONE slot (%d, %d slots)" % [mol, WorldState.inventory.size()])
	# the held item follows the craft (HUD.selected_slot is an index)
	_fresh()
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("009")
	HUD.selected_slot = 2                   # the cloth in hand
	check(bool(Crafting.craft(1, 2)["ok"]), "(setup) craft with the hammer ahead of it")
	check(HUD.selected_slot == -1, "if the held item is spent nothing stays 'in hand' on a stale index (%d)" % HUD.selected_slot)
	_fresh()
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("009")
	HUD.selected_slot = 0                   # the hammer in hand
	Crafting.craft(1, 2)
	check(HUD.selected_slot == 0 and WorldState.inventory[0].item_id == "002", "…and the hammer is still in hand when it isn't spent")
	# the rope: three clothes
	_fresh()
	WorldState.add_to_inventory("008")
	WorldState.add_to_inventory("008")
	var two: Dictionary = Crafting.plan(0, 1)
	check(not bool(two.get("ok", true)) and str(two.get("why", "")).contains("3"), "two clothes aren't enough — it says so ('%s')" % str(two.get("why", "")))
	check(not bool(Crafting.craft(0, 1)["ok"]) and _ids() == ["008", "008"], "…and spends nothing")
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("008")      # slot 3
	check(bool(Crafting.plan(0, 1).get("ok", false)), "three clothes (the third elsewhere in the pack) plan to a Rope")
	check(bool(Crafting.craft(0, 1)["ok"]), "…and craft")
	check(_ids() == ["002", "018"] or (_ids().has("018") and not _ids().has("008") and _ids().has("002")), "three clothes → one Rope; the hammer untouched (%s)" % str(_ids()))
	# nothing lost when the result won't fit: a bag over capacity (an overloaded pack) can't take it
	_fresh()
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("009")
	for id in ["002", "005", "006"]:
		var inst := ItemInstance.new()
		inst.setup(id)
		WorldState.inventory.append(inst)
	var cap: int = WorldState.get_inventory_slots()
	while WorldState.inventory.size() < cap + 1:
		var inst2 := ItemInstance.new()
		inst2.setup("030")
		WorldState.inventory.append(inst2)
	var before_ids: Array = _ids()
	var before_counts: Array = []
	for inst in WorldState.inventory:
		before_counts.append(inst.count)
	var full: Dictionary = Crafting.craft(0, 1)
	var after_counts: Array = []
	for inst in WorldState.inventory:
		after_counts.append(inst.count)
	check(not bool(full["ok"]) and String(full["why"]).contains("room"), "with no room for the result the craft is refused ('%s')" % String(full["why"]))
	check(_ids() == before_ids and after_counts == before_counts, "…and the pack is EXACTLY as it was (nothing silently destroyed)")


# ---------------------------------------------------------------- the burst

func _floor_at(y: float) -> StaticBody2D:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, y + 30.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6000, 60)
	cs.shape = rect
	floor_body.add_child(cs)
	add_child(floor_body)
	return floor_body


func _players_with(stream: AudioStream) -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is AudioStreamPlayer2D and c.stream == stream and not c.is_queued_for_deletion():
				out.append(c)
	return out


func _fires() -> Array:
	var out: Array = []
	for f in get_tree().get_nodes_in_group("molotov_fire"):
		if is_instance_valid(f) and not f.is_queued_for_deletion():
			out.append(f)
	return out


func _test_thrown_burst() -> void:
	print("[the thrown molotov bursts into flame]")
	_fresh()
	var fl := _floor_at(420.0)
	var m = load("res://scenes/thrown_molotov.tscn").instantiate()
	add_child(m)
	check(m.molotov and m.fragile, "the thrown molotov is flagged molotov + fragile (it never bounces or rolls)")
	check(_fires().is_empty(), "no fire yet while it is in the air")
	m.launch(1.0, Vector2(0, 300))
	m.global_position = Vector2(500, 300)
	check(m.whoosh_player != null and m.whoosh_player.playing and m.whoosh_player.stream in m.WHOOSH_STREAMS, "a whoosh plays as it leaves the hand")
	for i in range(90):
		await get_tree().physics_frame
		if m.shattered:
			break
	check(m.shattered, "it smashed where it landed")
	check(m.smash_player != null and m.smash_player.playing and m.smash_player.stream in m.SMASH_STREAMS, "…with the glass smash")
	check(not m.whoosh_player.playing, "…and the flight whoosh stops")
	await get_tree().physics_frame
	check(_players_with(MolotovFire.IGNITE_SOUND).size() == 1 and _players_with(MolotovFire.IGNITE_SOUND)[0].playing, "…and the ignition FWOOMP kicks off")
	var has_loop := false
	for fnode in _fires():
		for c in fnode.get_children():
			if c is AudioStreamPlayer2D and c.playing and c.stream is AudioStreamWAV and c.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD:
				has_loop = true
	check(has_loop, "…and a looping crackle plays for as long as it burns")
	var fs: Array = _fires()
	check(fs.size() == 1, "…and left exactly ONE splash fire (%d)" % fs.size())
	if fs.size() == 1:
		var f = fs[0]
		check(absf(f.global_position.x - m.global_position.x) < 30.0, "…where it landed (x %.0f vs %.0f)" % [f.global_position.x, m.global_position.x])
		check(absf(f.global_position.y - 420.0) < 6.0, "…ON the floor line (y %.1f)" % f.global_position.y)
		check(f.is_inside_tree() and f.get_parent() == m.get_parent(), "…in the scene it was thrown in, not some other one")
		var e0: float = f.extent()
		await _frames(12)
		check(f.extent() > e0, "the splash SPREADS out from the impact (%.0f → %.0f px)" % [e0, f.extent()])
		await _frames(40)
		check(is_equal_approx(f.extent(), f.RADIUS), "…to its full width (%.0f)" % f.extent())
	for f in _fires():
		f.queue_free()
	fl.queue_free()
	m.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the fire's rules

const STUB_SRC := """extends Node2D
var is_running := false
var hits := 0
func receive_hit(amount: int = 1) -> void:
	hits += amount
"""


func _stub_player(at: Vector2) -> Node2D:
	var s := GDScript.new()
	s.source_code = STUB_SRC
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.add_to_group("player")
	n.global_position = at
	add_child(n)
	return n


func _test_fire_rules() -> void:
	print("[the splash plays by the floor fire's rules]")
	_fresh()
	var f: MolotovFire = MolotovFire.spawn(self, Vector2(300, 419))
	await _frames(45)
	check(f != null and f.is_burning(), "a fresh splash is burning")
	check(f.in_fire(300.0 + f.RADIUS * 0.8, 419.0) and not f.in_fire(300.0 + f.RADIUS + 30.0, 419.0), "it covers ±RADIUS along the floor and no further")
	check(not f.in_fire(300.0, 419.0 - 120.0), "…and not something high above it (a balcony)")
	var no_collision := true
	for c in f.get_children():
		if c is CollisionObject2D or c is CollisionShape2D:
			no_collision = false
	check(no_collision, "it never blocks anything (no collision at all)")
	# enemies catch
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(340, 370)
	add_child(z)
	var far = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	far.global_position = Vector2(300.0 + f.RADIUS + 120.0, 370)
	add_child(far)
	await _frames(3)
	check(f.ignite_enemies() >= 1 and z.on_fire, "a zombie standing in it CATCHES")
	check(_players_with(MolotovFire.CATCH_SOUND).size() == 1, "…with a whoomph as it catches")
	f.ignite_enemies()
	check(_players_with(MolotovFire.CATCH_SOUND).size() == 1, "…once, not every tick while it keeps burning")
	check(not far.on_fire, "…one well outside it does not")
	await _frames(40)
	check(z.on_fire or not is_instance_valid(z) or z.state == "dead", "it keeps burning (or has burned down) while it stands there")
	# the player burns when walking, not when sprinting (the zombies go first: they'd bite the stub and muddy the count)
	z.queue_free()
	far.queue_free()
	await get_tree().process_frame
	var pl := _stub_player(Vector2(300, 386))
	await _frames(int(MolotovFire.BURN_INTERVAL * 60.0) + 12)
	check(pl.hits >= 1, "the player standing in it takes damage (%d hit(s) in ~1.3 s)" % pl.hits)
	var h0: int = pl.hits
	pl.is_running = true
	await _frames(int(MolotovFire.BURN_INTERVAL * 60.0) * 2)
	check(pl.hits == h0, "…but sprinting THROUGH it takes none")
	pl.is_running = false
	pl.global_position = Vector2(300.0 + f.RADIUS + 80.0, 386)
	var h1: int = pl.hits
	await _frames(int(MolotovFire.BURN_INTERVAL * 60.0) * 2)
	check(pl.hits == h1, "…and standing outside it takes none (%d → %d, fire extent %.0f at %.0f px away, t %.1f)" % [h1, pl.hits, f.extent(), absf(pl.global_position.x - f.global_position.x), f._t])
	pl.queue_free()
	# the extinguisher douses it
	f.douse()
	check(_players_with(MolotovFire.DOUSE_SOUND).size() == 1, "dousing hisses")
	await _frames(int(MolotovFire.DOUSE_TIME * 60.0) + 8)
	check(_players_with(MolotovFire.DOUSE_SOUND).size() == 1, "…and the hiss carries on after the fire is gone")
	check(not is_instance_valid(f) or f.is_queued_for_deletion(), "dousing puts it out (gone within %.1fs)" % MolotovFire.DOUSE_TIME)
	# it dies on its own
	var g: MolotovFire = MolotovFire.spawn(self, Vector2(900, 419))
	g._t = MolotovFire.LIFETIME - 0.2
	await _frames(20)
	check(not is_instance_valid(g) or g.is_queued_for_deletion(), "a splash left alone burns out by itself")
	var h: MolotovFire = MolotovFire.spawn(self, Vector2(900, 419))
	h._t = MolotovFire.LIFETIME - 1.0
	check(h.extent() < MolotovFire.RADIUS * 0.8, "…shrinking as it dies (%.0f of %.0f px)" % [h.extent(), MolotovFire.RADIUS])
	h.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the player throws one

func _test_player_throws() -> void:
	print("[the player throws a molotov]")
	_fresh()
	WorldState.is_scavenge_mode = false     # combat stance — it is a weapon, so it throws from either
	WorldState.add_to_inventory("039")
	WorldState.add_to_inventory("039")
	var fl := _floor_at(420.0)
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2(0, 386)
	player.use_item(0)
	var thrown: Node = null
	for c in get_children():
		if c is RigidBody2D and c.get("molotov") == true:
			thrown = c
	check(thrown != null, "using a molotov throws a MOLOTOV (not a can or a bottle)")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 1, "one spent from the stack, one kept")
	if thrown != null:
		for i in range(150):
			await get_tree().physics_frame
			if thrown.shattered:
				break
		check(thrown.shattered and not _fires().is_empty(), "it burst into flame where it came down")
	WorldState.is_scavenge_mode = true
	player.attack_cooldown_timer = 0.0
	player.is_attacking = false
	var n_before: int = _fires().size()
	player.use_item(0)
	var again := false
	for c in get_children():
		if c is RigidBody2D and c.get("molotov") == true and c != thrown and not c.shattered:
			again = true
	check(again, "…and it throws from the scavenge stance too")
	check(WorldState.inventory.is_empty(), "the last one leaves the pack")
	for f in _fires():
		f.queue_free()
	for c in get_children():
		if c is RigidBody2D:
			c.queue_free()
	player.queue_free()
	fl.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- the ring: drag to craft

var bf: Node = null
var p: Node = null


func _click_drag(from: Vector2, to: Vector2, release_at: Vector2 = Vector2(-1, -1)) -> void:
	# Push in WINDOW space (headless windows aren't the content size — see pack_test._click)
	var tf: Transform2D = get_viewport().get_final_transform()
	var up_at: Vector2 = to if release_at.x < 0 else release_at
	var mv := InputEventMouseMotion.new()
	mv.position = tf * from
	get_viewport().push_input(mv)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = tf * from
	get_viewport().push_input(ev)
	await get_tree().process_frame
	if from != to:
		var mv2 := InputEventMouseMotion.new()
		mv2.position = tf * to
		mv2.relative = to - from
		get_viewport().push_input(mv2)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = tf * up_at
	get_viewport().push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _slot_pos(k: int) -> Vector2:
	var pw = HUD.pack_wheel
	return pw.RingGeo.slot_position(pw.centre, k, pw.slots.size(), pw.RING_R)


func _open_pack() -> void:
	HUD.pack_wheel.toggle()
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	await get_tree().process_frame


func _test_ring_drag() -> void:
	print("[drag onto an item in the backpack ring]")
	WorldState.new_game()
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await _frames(40)
	p = get_tree().get_first_node_in_group("player")
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	WorldState.inventory.clear()
	for id in ["002", "024", "009", "006"]:
		WorldState.add_to_inventory(id)
	HUD.refresh_inventory()
	WorldState.god_mode = false
	HUD.selected_slot = -1
	await _frames(2)
	await _open_pack()
	var pw = HUD.pack_wheel
	check(pw.is_open and pw.slots.size() >= 4, "the ring is open with the bag on it")
	# a plain click (press + release, no movement) still equips
	await _click_drag(_slot_pos(0), _slot_pos(0))
	check(HUD.selected_slot == 0, "a click that never moves still equips (slot %d)" % HUD.selected_slot)
	check(pw.drag_k < 0, "…and no drag is left over")
	await _click_drag(_slot_pos(0), _slot_pos(0))
	check(HUD.selected_slot == -1, "…and again puts it away")
	# a drag between two things that don't go together does nothing
	var ids0: Array = _ids()
	await _click_drag(_slot_pos(0), _slot_pos(3))
	check(_ids() == ids0, "dragging the hammer onto the bandages changes nothing")
	check(HUD.selected_slot == -1, "…and doesn't equip it either (a drag is not a click)")
	check(pw.is_open, "…the pack stays open")
	# a drag released off the ring does nothing and does not close the pack
	await _click_drag(_slot_pos(1), _slot_pos(1) + Vector2(0, 0), Vector2(1100, 60))
	check(_ids() == ids0 and pw.drag_k < 0, "dropping it off the ring cancels the drag, nothing spent")
	# a mid-drag highlight: the dragged bottle + the cloth is a valid target
	var tf: Transform2D = get_viewport().get_final_transform()
	var mv := InputEventMouseMotion.new()
	mv.position = tf * _slot_pos(1)
	get_viewport().push_input(mv)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = tf * _slot_pos(1)
	get_viewport().push_input(ev)
	await get_tree().process_frame
	var mv2 := InputEventMouseMotion.new()
	mv2.position = tf * _slot_pos(2)
	mv2.relative = _slot_pos(2) - _slot_pos(1)
	get_viewport().push_input(mv2)
	await get_tree().process_frame
	check(pw.drag_k == 1, "pressing the bottle and moving it starts a drag (wedge %d)" % pw.drag_k)
	check(bool(Crafting.plan(int(pw.slots[1]), int(pw.slots[2])).get("ok", false)), "…and the cloth under it is a valid target")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = tf * _slot_pos(2)
	get_viewport().push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame
	check(_ids().has("039") and not _ids().has("024") and not _ids().has("009"), "dropping the bottle on the cloth CRAFTS the molotov (%s)" % str(_ids()))
	check(_ids().has("002") and _ids().has("006"), "…the rest of the bag is untouched")
	check(pw.drag_k < 0 and pw._press_k < 0, "…and the drag state is clear")
	check(pw.is_open, "…the pack is still open after crafting")
	# the ring can't strand: closing mid-drag leaves nothing behind
	await _click_drag(_slot_pos(0), _slot_pos(0))
	p.end_pack(true)
	await _frames(4)
	check(not pw.is_open and pw.drag_k < 0 and pw._press_k < 0, "a closed ring carries no drag state")
	p.is_hit = false
	WorldState.god_mode = true
	bf.queue_free()
	await get_tree().process_frame
