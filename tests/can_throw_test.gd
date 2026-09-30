extends Node

# Headless test for can throwing / distraction (item 17).
# Run:  godot --headless res://tests/can_throw_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== can throw / distraction test ===")
	_test_distraction_targets()
	_test_boss_ignores()
	_test_arrival()
	_test_loud_noise_breaks()
	_test_can_lands()
	_test_no_block_layer()
	_test_landed_can_freezes()
	_test_despawn_flashes()
	_test_hit_damages_not_kills()
	_test_cans_stack()
	await _test_physics_collision()
	_test_bottle_item()
	await _test_bottle_shatters_on_floor()
	await _test_bottle_shatters_on_enemy()
	await _test_player_throws_bottle()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_distraction_targets() -> void:
	print("[distraction]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(100, 388)
	add_child(z)
	check(z.z_index == 1, "zombie renders on the actor layer (z 1, in front of doors)")
	z.alert_to_noise(6.0)  # pretend it was chasing
	WorldState.emit_distraction(Vector2(300, 388), 700.0)
	check(z.is_distracted and z.state == "distracted", "in-range zombie is distracted")
	check(z.alert_timer == 0.0, "distraction overrides prior aggro")
	check(z.distraction_target == Vector2(300, 388), "target is the can")
	z.queue_free()

	var far = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	far.global_position = Vector2(2000, 388)
	add_child(far)
	WorldState.emit_distraction(Vector2(300, 388), 700.0)
	check(not far.is_distracted, "out-of-earshot zombie is unaffected")
	far.queue_free()


func _test_boss_ignores() -> void:
	print("[boss immunity]")
	WorldState.new_game()
	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	big.global_position = Vector2(200, 388)
	add_child(big)
	WorldState.emit_distraction(Vector2(250, 388), 700.0)
	check(not big.has_method("be_distracted") or not big.get("is_distracted"),
		"big zombie ignores the can")
	big.queue_free()


func _test_arrival() -> void:
	print("[arrival — loiters, no proximity reaggro]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(300, 388)
	add_child(z)
	z.be_distracted(Vector2(305, 388), 6.0)  # already basically on top of it
	z._physics_process(0.1)
	check(z.is_distracted and z.state == "distracted",
		"at the can it loiters — still distracted, no arrival reaggro")
	check(z.velocity.x == 0.0, "it holds at the can rather than chasing off")
	# Timer runs out (the can despawns) -> normal aggro resumes.
	z.distraction_timer = 0.05
	z._physics_process(0.1)
	check(not z.is_distracted, "once the can goes quiet, distraction ends")
	check(z.state in ["idle", "chase"], "normal aggro resumes after the can")
	z.queue_free()


func _test_loud_noise_breaks() -> void:
	print("[loud noise overrides the can, quiet doesn't]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(400, 388)
	add_child(z)
	z.be_distracted(Vector2(360, 388), 6.0)
	check(z.is_distracted, "distracted by the can")
	# A quiet gait right next to it must NOT break the fixation.
	WorldState.emit_noise(Vector2(410, 388), WorldState.NOISE_RADIUS["walk"], 0.5)
	check(z.is_distracted, "quiet walking nearby doesn't break the distraction")
	# A loud one (running / door work / gunfire) does.
	WorldState.emit_noise(Vector2(410, 388), WorldState.NOISE_RADIUS["run"], 0.5)
	check(not z.is_distracted and z.state == "chase",
		"a loud noise (running) snaps it back onto the player")
	z.queue_free()


func _test_can_lands() -> void:
	print("[can landing]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(360, 388)
	add_child(z)
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.launch(1.0, Vector2(300, 388))
	check(can.linear_velocity.x > 0 and can.linear_velocity.y < 0, "launch gives forward+up velocity")
	check(can.collision_mask & 1 != 0, "can collides with the world (layer 1) so it can't pass walls")
	check(can.contact_monitor, "contact monitoring on for bounce thuds")
	can._land()
	check(z.is_distracted, "landing distracts a nearby zombie")
	can.queue_free()
	z.queue_free()


func _test_no_block_layer() -> void:
	print("[never a blockage]")
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	check(can.collision_layer == 128, "can sits on its own layer, not the world/actor layer 1")
	check((z.collision_mask & 128) == 0, "enemies don't mask the can's layer, so it can't block them")
	check((can.collision_mask & 1) != 0, "can still bounces off walls/floor and hits bodies (mask 1)")
	can.queue_free()
	z.queue_free()


func _test_landed_can_freezes() -> void:
	print("[a settled can pins itself]")
	# At rest after landing it freezes into a static prop so a zombie walking
	# over it can't shove it around until despawn.
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.has_landed = true
	can.linear_velocity = Vector2(3, 0)     # basically stopped
	can._physics_process(0.1)
	check(can.freeze, "a can at rest freezes (enemies can't push it)")
	var rolling = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(rolling)
	rolling.has_landed = true
	rolling.linear_velocity = Vector2(120, 0)   # still rolling
	rolling._physics_process(0.1)
	check(not rolling.freeze, "a still-rolling can is NOT frozen yet")
	can.queue_free()
	rolling.queue_free()


func _test_despawn_flashes() -> void:
	print("[blinks out as it despawns]")
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.has_landed = true
	# Walk the despawn timer down through the flash window; it should toggle
	# both on and off (a blink), not just sit visible.
	var seen_on := false
	var seen_off := false
	var t: float = can.FLASH_WINDOW
	while t > 0.01:
		can.despawn_timer = t
		can._physics_process(0.0)
		if can.visible:
			seen_on = true
		else:
			seen_off = true
		t -= 0.03
	check(seen_on and seen_off, "the can blinks on and off as it runs out")
	can.queue_free()


func _test_hit_damages_not_kills() -> void:
	print("[in-flight hit]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(400, 388)
	add_child(z)
	z.current_hp = 3            # fix it (spawn HP has 1..8 variance)
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.launch(1.0, Vector2(300, 388))    # airborne, not landed
	can._on_body_entered(z)
	check(z.current_hp == 3 - can.HIT_DAMAGE, "an in-flight hit damages the zombie")
	check(not z.is_dead, "a can hit never kills")
	can._on_body_entered(z)
	check(z.current_hp == 3 - can.HIT_DAMAGE, "the same zombie is only damaged once")

	# A 1-HP enemy: the hit is clamped to leave it alive — softened, not finished.
	var weak = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	weak.global_position = Vector2(500, 388)
	add_child(weak)
	weak.current_hp = 1
	var can2 = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can2)
	can2.launch(1.0, Vector2(450, 388))
	can2._on_body_entered(weak)
	check(weak.current_hp == 1 and not weak.is_dead, "a 1-HP enemy is never finished off by a can")

	can.has_landed = true
	var z2 = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z2.global_position = Vector2(400, 388)
	add_child(z2)
	z2.current_hp = 3
	can._on_body_entered(z2)
	check(z2.current_hp == 3, "a landed can bumps past enemies but does no damage")
	can.queue_free()
	can2.queue_free()
	z.queue_free()
	weak.queue_free()
	z2.queue_free()


func _test_cans_stack() -> void:
	print("[cans stack to three]")
	WorldState.new_game()
	WorldState.inventory.clear()
	check(WorldState.MAX_THROWABLE_PER_SLOT == 3, "cap is three per slot")
	check(absf(WorldState.CAN_SCAVENGE_BOOST - 1.18) < 0.001, "scavenge boost is 18%")
	check(WorldState.add_to_inventory("005"), "1st can taken")
	check(WorldState.add_to_inventory("005"), "2nd can taken")
	check(WorldState.add_to_inventory("005"), "3rd can taken")
	var slots := 0
	var total := 0
	for inst in WorldState.inventory:
		if inst.item_id == "005":
			slots += 1
			total += inst.count
	check(slots == 1 and total == 3, "three cans share ONE slot (x3), not three slots")
	WorldState.add_to_inventory("005")
	var t2 := 0
	for inst in WorldState.inventory:
		if inst.item_id == "005":
			t2 += inst.count
	check(t2 == 4, "a 4th can opens a new slot rather than vanishing")


func _test_physics_collision() -> void:
	print("[physics collision]")
	# Build a real floor collider (layer 1, like the world) and drop a can on
	# it. If the RigidBody physics is wired right the can lands and STOPS above
	# the floor instead of passing through it (the bug being fixed).
	var floor_body = StaticBody2D.new()
	floor_body.position = Vector2(0, 420)
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(4000, 60)
	cs.shape = rect
	floor_body.add_child(cs)
	add_child(floor_body)

	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.launch(1.0, Vector2(0, 300))
	# Let gravity + collision resolve over ~1.2s of physics.
	for i in range(72):
		await get_tree().physics_frame
	check(can.has_landed, "can made contact with the floor (didn't float)")
	check(can.global_position.y <= 400.0, "can rests ABOVE the floor, not through it (y=%.0f)" % can.global_position.y)
	can.queue_free()
	floor_body.queue_free()


func _test_bottle_item() -> void:
	print("[bottle item]")
	WorldState.new_game()
	var bottle: Dictionary = ItemData.get_item("024")
	check(bottle.get("is_throwable", false) and bottle.get("is_bottle", false), "the Empty Bottle (024) is a throwable, fragile item")
	check(ItemData.get_item("023").get("name", "") == "Broken Bottle" and not ItemData.get_item("023").get("is_throwable", false), "023 is the Broken Bottle — junk, NOT throwable")
	check(ItemData.get_item_id_by_name("Broken Bottle") == "023", "spawn pools find the renamed item by name")
	check(not ItemData.get_item("005").get("is_bottle", false), "a can is not a bottle")
	WorldState.inventory.clear()
	check(WorldState.add_to_inventory("024") and WorldState.add_to_inventory("024"), "two bottles taken")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 2, "bottles stack like cans (one slot, x2)")
	var bot = load("res://scenes/thrown_bottle.tscn").instantiate()
	add_child(bot)
	check(bot.fragile and bot.collision_layer == 128 and (bot.collision_mask & 1) != 0, "the thrown bottle is fragile, on the can's layer, and hits the world")
	bot.queue_free()


func _test_bottle_shatters_on_floor() -> void:
	print("[bottle smashes on the floor]")
	WorldState.new_game()
	var floor_body = StaticBody2D.new()
	floor_body.position = Vector2(0, 420)
	var cs = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(4000, 60)
	cs.shape = rect
	floor_body.add_child(cs)
	add_child(floor_body)
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(900, 388)
	add_child(z)
	var bot = load("res://scenes/thrown_bottle.tscn").instantiate()
	add_child(bot)
	bot.launch(1.0, Vector2(0, 300))
	check(not bot.shattered, "in the air it is whole")
	for i in range(72):
		await get_tree().physics_frame
		if bot.shattered:
			break
	check(bot.shattered, "it smashed when it hit the floor (no bounce, no roll)")
	check(not bot.visible, "the bottle itself is gone")
	check(bot.smash_player != null and bot.smash_player.playing and bot.smash_player.stream in bot.SMASH_STREAMS, "the smash sound is playing")
	check(bot.has_landed and z.is_distracted, "the smash counts as the landing: it distracts a nearby zombie")
	await get_tree().physics_frame
	var disabled := false
	for c in bot.get_children():
		if c is CollisionShape2D:
			disabled = c.disabled
	check(disabled and bot.freeze, "its body can never block or be shoved afterwards (collision off, frozen)")
	var shards: Node = null
	for c in get_children():
		if c.get_script() == bot.SHARDS:
			shards = c
	check(shards != null and shards.shards.size() == bot.SHARDS.COUNT, "a spray of %d glass shards was thrown" % bot.SHARDS.COUNT)
	for i in range(120):
		await get_tree().physics_frame
		await get_tree().process_frame
	check(shards != null and shards.all_rested, "the shards fall and come to rest")
	var on_floor := true
	for s in shards.shards:
		if s["p"].y > shards.floor_y + 0.01:
			on_floor = false
	check(on_floor and shards.floor_y > 0.0 and shards.floor_y < 240.0, "every shard lies on the floor (found %.0f px below the impact), none sank through" % shards.floor_y)
	check(shards.get_child_count() == 0, "the shards are pure visuals — no collision nodes")
	shards.queue_free()
	if is_instance_valid(bot):
		bot.queue_free()
	z.queue_free()
	floor_body.queue_free()


func _test_bottle_shatters_on_enemy() -> void:
	print("[bottle smashes on an enemy]")
	WorldState.new_game()
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	z.global_position = Vector2(0, 300)
	add_child(z)
	var hp_before: int = z.current_hp
	var bot = load("res://scenes/thrown_bottle.tscn").instantiate()
	add_child(bot)
	bot.global_position = Vector2(0, 300)
	bot._on_body_entered(z)
	check(bot.shattered, "hitting an enemy in flight smashes it")
	check(z.current_hp >= hp_before - 1 and z.current_hp >= 1, "it only knocks an enemy, never kills (hp %d → %d)" % [hp_before, z.current_hp])
	var can = load("res://scenes/thrown_can.tscn").instantiate()
	add_child(can)
	can.global_position = Vector2(0, 300)
	can._on_body_entered(z)
	check(not can.shattered and can.smash_player == null, "a can never shatters")
	for c in get_children():
		if c.get_script() == bot.SHARDS:
			c.queue_free()
	bot.queue_free()
	can.queue_free()
	z.queue_free()


func _test_player_throws_bottle() -> void:
	print("[the player throws a bottle]")
	WorldState.new_game()
	WorldState.inventory.clear()
	WorldState.is_scavenge_mode = true
	WorldState.add_to_inventory("024")
	WorldState.add_to_inventory("024")
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	player.global_position = Vector2(0, 386)
	player.use_item(0)
	var thrown: Node = null
	for c in get_tree().current_scene.get_children():
		if c is RigidBody2D and c.get("fragile") == true:
			thrown = c
	check(thrown != null, "using a bottle throws a BOTTLE (fragile), not a can")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 1, "one bottle spent from the stack, one kept")
	if thrown != null:
		thrown.queue_free()
	WorldState.inventory.clear()
	WorldState.add_to_inventory("005")
	player.attack_cooldown_timer = 0.0
	player.is_attacking = false
	player.use_item(0)
	var can: Node = null
	for c in get_tree().current_scene.get_children():
		if c is RigidBody2D and c.get("fragile") == false:
			can = c
	check(can != null, "using a can still throws a can")
	if can != null:
		can.queue_free()
	player.queue_free()
