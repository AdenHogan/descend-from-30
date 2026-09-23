extends Node

# Equip + attack must never hiccup (owner: "pressing Space does nothing until I unequip and
# re-equip"). Locks every trap that caused it:
#   1. a KEY attack is never blocked by the mouse resting over the HUD (only pointer clicks are),
#   2. Space with a weapon in SCAVENGE mode draws it (switches to combat) and swings,
#   3. a press during a swing's cooldown is buffered and fires, not dropped,
#   4. mouse SIDE buttons act like a key (not a pointer click),
#   5. toggling the equipped slot off is announced, never silent.
# Run: godot --headless res://tests/attack_input_test.tscn

var failures: int = 0
var p = null


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _attack_key() -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "attack"
	ev.pressed = true
	return ev


func _wait(sec: float) -> void:
	var until := Time.get_ticks_msec() / 1000.0 + sec
	while Time.get_ticks_msec() / 1000.0 < until:
		await get_tree().physics_frame


func _ready() -> void:
	print("=== attack input test ===")
	_test_hud_gate_rule()
	await _setup()
	await _test_key_attack_in_combat()
	await _test_buffered_press()
	await _test_scavenge_draws_weapon()
	await _test_scavenge_without_weapon()
	_test_side_button_is_not_pointer()
	_test_unequip_is_announced()
	p.queue_free()
	WorldState.god_mode = false
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_hud_gate_rule() -> void:
	print("[the HUD only blocks POINTER clicks]")
	var P = load("res://scripts/player.gd")
	check(not P.hud_blocks_attack(false, true), "a KEY attack is never blocked by the mouse over the HUD")
	check(P.hud_blocks_attack(true, true), "a pointer click on the HUD does not swing")
	check(not P.hud_blocks_attack(true, false), "a pointer click in the world can swing")


func _setup() -> void:
	WorldState.new_game()
	WorldState.god_mode = true                  # no stamina gating in this test
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002")          # Hammer
	p = load("res://scenes/player.tscn").instantiate()
	add_child(p)
	p.global_position = Vector2(600, 386)
	for i in range(3):
		await get_tree().physics_frame


func _test_key_attack_in_combat() -> void:
	print("[Space swings in combat with the weapon equipped]")
	WorldState.is_scavenge_mode = false
	HUD.selected_slot = 0
	p._input(_attack_key())
	check(p.is_attacking, "Space swings")
	await _wait(1.2)                              # let the cooldown clear


func _test_buffered_press() -> void:
	print("[a press during the cooldown is buffered, not dropped]")
	p._input(_attack_key())
	check(p.is_attacking, "first swing")
	# Press again just before the cooldown ends.
	while p.attack_cooldown_timer > 0.15:
		await get_tree().physics_frame
	var remaining: float = p.attack_cooldown_timer
	p._input(_attack_key())
	check(p._attack_buffered_until > 0.0, "the early press is held in the buffer")
	await _wait(remaining + 0.12)
	check(p.is_attacking and p.attack_cooldown_timer > 0.15, "the buffered press fired a second swing")
	check(p._attack_buffered_until < 0.0, "the buffer is cleared once used")
	await _wait(1.2)


func _test_scavenge_draws_weapon() -> void:
	print("[Space in SCAVENGE mode with a weapon draws it and swings]")
	WorldState.is_scavenge_mode = true
	HUD.selected_slot = 0
	p._input(_attack_key())
	check(p.is_switching_mode, "pressing attack starts the switch to combat")
	await _wait(p.MODE_SWITCH_TIME + 0.2)
	check(not WorldState.is_scavenge_mode, "now in combat")
	check(p.is_attacking, "and the swing landed without a second press")
	await _wait(1.2)


func _test_scavenge_without_weapon() -> void:
	print("[Space in scavenge mode with NO weapon changes nothing]")
	WorldState.is_scavenge_mode = true
	HUD.selected_slot = -1
	p._input(_attack_key())
	check(not p.is_switching_mode and WorldState.is_scavenge_mode, "no weapon → no stance switch")


func _test_side_button_is_not_pointer() -> void:
	print("[mouse side buttons behave like a key]")
	var side := InputEventMouseButton.new()
	side.button_index = MOUSE_BUTTON_XBUTTON1
	side.pressed = true
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	check(not p._is_pointer_click(side), "side button is not a pointer click")
	check(p._is_pointer_click(left), "left button is a pointer click")


func _test_unequip_is_announced() -> void:
	print("[toggling the equipped slot off is announced]")
	HUD.selected_slot = -1
	HUD.select_slot(0)
	check(HUD.selected_slot == 0 and HUD.feedback_label.text.begins_with("Equipped"), "equip is announced")
	HUD.select_slot(0)
	check(HUD.selected_slot == -1 and HUD.feedback_label.text.begins_with("Put away"), "put-away is announced")
