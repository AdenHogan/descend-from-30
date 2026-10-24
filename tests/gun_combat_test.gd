extends Node

# Headless smoke test for gun combat: ammo stacking (one slot holds WorldState.MAX_AMMO_PER_SLOT), ammo
# consumption, runtime gun animations, outcome bands, and noise alerts.
# Run:  godot --headless res://tests/gun_combat_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== gun combat test ===")
	_test_ammo_stacking()
	_test_ammo_consumption()
	_test_magazine()
	_test_inventory_moves()
	_test_player_gun_setup()
	_test_zombie_alert()
	_test_melee_plane_reach()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_ammo_stacking() -> void:
	print("[ammo stacking]")
	# Owner round 48i: "Screw it, let bullets stack. That's a better UI proposal" - one slot holds MAX_AMMO_PER_SLOT rounds (it was 8).
	WorldState.new_game()
	var mx: int = WorldState.MAX_AMMO_PER_SLOT
	check(mx >= 30, "a slot of bullets holds a real supply (%d), not a clip" % mx)
	check(WorldState.add_to_inventory("016"), "single bullet enters inventory")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 1,
		"one stack of 1")
	for i in range(mx - 1):
		WorldState.add_to_inventory("016")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == mx,
		"%d bullets fill one slot" % mx)
	WorldState.add_to_inventory("016")
	check(WorldState.inventory.size() == 2 and WorldState.inventory[1].count == 1,
		"bullet %d overflows to a second slot" % (mx + 1))
	check(WorldState.get_ammo_total() == mx + 1, "ammo total counts across stacks")

	check(WorldState.add_to_inventory("016", 12), "bundle add tops up the open stack")
	check(WorldState.get_ammo_total() == mx + 13, "bundle lands in full")
	check(WorldState.inventory.size() == 2, "bundle used no new slot (%d + 13)" % mx)
	check(WorldState.inventory[0].count == mx and WorldState.inventory[1].count == 13, "stack fills are %d / 13" % mx)

	# Fill the remaining 3 slots with non-ammo, then over-cap ammo must refuse.
	WorldState.add_to_inventory("001")
	WorldState.add_to_inventory("002")
	WorldState.add_to_inventory("003")
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "(setup) the bag is full")
	check(not WorldState.add_to_inventory("016", mx - 13 + 1), "bundle one over capacity refused whole")
	check(WorldState.get_ammo_total() == mx + 13, "...and nothing was added")
	check(WorldState.add_to_inventory("016", mx - 13), "bundle exactly at capacity accepted")
	check(WorldState.get_ammo_total() == 2 * mx, "capacity math holds (2 stacks x %d)" % mx)
	# a dropped stack of bullets joins the held one when the two fit one slot (the pack ring's Drop and a pickup return a whole stack)
	WorldState.new_game()
	WorldState.add_to_inventory("016", 10)
	var dropped = ItemInstance.new()
	dropped.setup("016")
	dropped.count = 12
	check(WorldState.add_instance_to_inventory(dropped) and WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 22,
		"a dropped stack of 12 rejoins the 10 in the pack: one stack of 22")


func _test_ammo_consumption() -> void:
	print("[ammo consumption]")
	WorldState.new_game()
	WorldState.add_to_inventory("004")        # gun
	WorldState.add_to_inventory("016", 10)
	HUD.selected_slot = 0
	check(WorldState.consume_ammo(1), "single shot consumes")
	check(WorldState.get_ammo_total() == 9, "one bullet gone")
	check(WorldState.consume_ammo(9), "draining every stack works")
	check(WorldState.get_ammo_total() == 0, "all ammo spent")
	check(WorldState.inventory.size() == 1, "empty stacks freed their slots")
	check(HUD.selected_slot == 0, "gun stays selected after stacks free")
	check(not WorldState.consume_ammo(1), "dry fire refused")


func _test_magazine() -> void:
	print("[magazine]")
	WorldState.new_game()
	WorldState.add_to_inventory("004")
	WorldState.add_to_inventory("016", 24)
	var gun = WorldState.get_instance_at(0)
	check(gun.mag_count == 0 and gun.get_mag_cap() == 18, "fresh gun empty, cap 18")
	var loaded = WorldState.reload_gun(gun)
	check(loaded == 18 and gun.mag_count == 18, "reload fills the mag to 18")
	check(WorldState.get_ammo_total() == 6, "leftover bullets stay in inventory")
	check(WorldState.reload_gun(gun) == 0, "full mag refuses more")
	gun.is_damaged = true
	check(gun.get_mag_cap() == 10, "damaged gun caps at 10")
	gun.is_damaged = false


func _test_inventory_moves() -> void:
	print("[inventory moves]")
	WorldState.new_game()
	WorldState.add_to_inventory("001")  # knife -> slot 0
	WorldState.add_to_inventory("002")  # hammer -> slot 1
	WorldState.add_to_inventory("003")  # sword -> slot 2
	HUD.selected_slot = 0
	WorldState.swap_inventory_slots(0, 2)
	check(WorldState.get_item_id_at(0) == "003" and WorldState.get_item_id_at(2) == "001",
		"swap exchanges two slots")
	check(HUD.selected_slot == 2, "selection follows the swapped item")
	WorldState.move_inventory_slot_to_end(0)
	check(WorldState.get_item_id_at(2) == "003", "move-to-end reorders")
	check(WorldState.get_item_id_at(0) == "002", "remaining items shift down")
	HUD.selected_slot = -1


func _test_player_gun_setup() -> void:
	print("[gun animations]")
	WorldState.new_game()
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	var frames = player.get_node("AnimatedSprite2D").sprite_frames
	for anim in ["gun_idle", "gun_walk", "gun_run", "gun_shoot"]:
		check(frames.has_animation(anim), "animation registered: " + anim)
	check(frames.get_frame_count("gun_shoot") == 10, "gun_shoot has 10 frames")
	check(frames.get_frame_count("gun_walk") == 8, "gun_walk has 8 frames")
	check(not frames.get_animation_loop("gun_shoot"), "gun_shoot does not loop")

	var outcome = player._calculate_gun_outcome(50.0)
	check(outcome in ["headshot", "body", "miss"], "close-range outcome is a valid band")
	outcome = player._calculate_gun_outcome(500.0)
	check(outcome in ["headshot", "body", "miss"], "long-range outcome is a valid band")
	outcome = player._calculate_gun_outcome(50.0, true)
	check(outcome in ["headshot", "body", "miss"], "damaged-gun outcome is a valid band")
	player.queue_free()


func _test_zombie_alert() -> void:
	print("[noise alert]")
	WorldState.new_game()
	var zombie = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(zombie)
	check(zombie.alert_timer == 0.0, "zombie starts unalerted")
	zombie.alert_to_noise()
	check(zombie.alert_timer > 0.0, "gunfire noise alerts standard zombie")
	zombie.queue_free()

	var big = load("res://scenes/enemy_zombie_big.tscn").instantiate()
	add_child(big)
	big.alert_to_noise(3.0)
	big.alert_to_noise(1.0)
	check(big.alert_timer == 3.0, "shorter noise never truncates an active alert")
	big.queue_free()


func _test_melee_plane_reach() -> void:
	# Melee must be HEIGHT-INDEPENDENT: the player (~388) and zombies (~370-374) rest at
	# different ORIGINS though their feet share 419, so a swing must connect across that
	# ~18px gap — but must NOT reach an enemy genuinely off this plane (balcony / stair).
	print("[melee plane-independent reach]")
	WorldState.new_game()
	WorldState.god_mode = true            # skip the stamina gate
	WorldState.add_to_inventory("002")    # Hammer (a melee weapon)
	HUD.selected_slot = 0
	var inst = WorldState.inventory[0]
	var player = load("res://scenes/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(600, 388)
	await get_tree().process_frame
	# On-plane target ahead (to the right), at the real rig-origin gap (dy 18).
	var z = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z)
	z.global_position = Vector2(640, 370)
	await get_tree().process_frame
	var before = z.current_hp
	player._do_melee_attack(inst, 0)
	check(z.current_hp < before, "swing connects across the 18px rig-origin gap (%d -> %d)" % [before, z.current_hp])
	z.queue_free()
	await get_tree().process_frame
	# Off-plane target (far below, e.g. a corridor zombie while you're on a balcony): no hit.
	# Clear the per-swing guard so this is a real swing, not an early-return.
	player.is_attacking = false
	player.attack_cooldown_timer = 0.0
	var z2 = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	add_child(z2)
	z2.global_position = Vector2(640, 388 + 200)
	await get_tree().process_frame
	var before2 = z2.current_hp
	player._do_melee_attack(inst, 0)
	check(z2.current_hp == before2, "a genuinely off-plane enemy is NOT hit (tolerance excludes it)")
	WorldState.god_mode = false
	player.queue_free()
	z2.queue_free()