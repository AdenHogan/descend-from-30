extends Node

# Headless smoke test for gun combat: ammo stacking (max 8/slot), ammo
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
	_test_player_gun_setup()
	_test_zombie_alert()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_ammo_stacking() -> void:
	print("[ammo stacking]")
	WorldState.new_game()
	check(WorldState.add_to_inventory("016"), "single bullet enters inventory")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 1,
		"one stack of 1")
	for i in range(7):
		WorldState.add_to_inventory("016")
	check(WorldState.inventory.size() == 1 and WorldState.inventory[0].count == 8,
		"8 bullets fill one slot")
	WorldState.add_to_inventory("016")
	check(WorldState.inventory.size() == 2 and WorldState.inventory[1].count == 1,
		"9th bullet overflows to a second slot")
	check(WorldState.get_ammo_total() == 9, "ammo total counts across stacks")

	check(WorldState.add_to_inventory("016", 12), "bundle add spreads across stacks")
	check(WorldState.get_ammo_total() == 21, "bundle lands in full")
	check(WorldState.inventory.size() == 3, "bundle used minimal slots (8+8+5)")
	check(WorldState.inventory[0].count == 8 and WorldState.inventory[1].count == 8
		and WorldState.inventory[2].count == 5, "stack fills are 8/8/5")

	# Fill remaining 2 slots with non-ammo, then over-cap ammo must refuse.
	WorldState.add_to_inventory("001")
	WorldState.add_to_inventory("002")
	check(not WorldState.add_to_inventory("016", 4), "bundle over capacity refused whole")
	check(WorldState.add_to_inventory("016", 3), "bundle exactly at capacity accepted")
	check(WorldState.get_ammo_total() == 24, "capacity math holds (3 stacks x 8)")


func _test_ammo_consumption() -> void:
	print("[ammo consumption]")
	WorldState.new_game()
	WorldState.add_to_inventory("004")        # gun
	WorldState.add_to_inventory("016", 10)    # 8 + 2
	HUD.selected_slot = 0
	check(WorldState.consume_ammo(1), "single shot consumes")
	check(WorldState.get_ammo_total() == 9, "one bullet gone")
	check(WorldState.consume_ammo(9), "draining every stack works")
	check(WorldState.get_ammo_total() == 0, "all ammo spent")
	check(WorldState.inventory.size() == 1, "empty stacks freed their slots")
	check(HUD.selected_slot == 0, "gun stays selected after stacks free")
	check(not WorldState.consume_ammo(1), "dry fire refused")


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