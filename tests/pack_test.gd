extends Node

# The BACKPACK sequence (owner round 26: "click the pack, the player bends down and opens their
# backpack, then a wheel for inventory opens with live gameplay underneath so you can still be
# attacked"; docs/BACKPACK.md), on the REAL player in a REAL corridor:
#  * kneel → open → stand, with the feet held where they were while the body leans;
#  * the world is never slowed and the player is rooted; the ring is a pure view of the player's phase;
#  * click equips / right-click uses / Delete drops / the middle, Esc, the key and a click in the world close;
#  * a hit slams it shut at once; every other exit (death, a cutscene, a panel) leaves nothing stuck;
#  * it refuses to start when it shouldn't, and never fights the quick wheel.
# Run:  godot --headless res://tests/pack_test.tscn

var failures: int = 0
var bf: Node = null
var p: Node = null


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== backpack sequence test ===")
	await get_tree().process_frame
	await _setup()
	await _test_sequence()
	await _test_ring_actions()
	await _test_exits()
	await _test_refusals()
	await _test_button_and_key()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _give(id: String) -> void:
	var inst := ItemInstance.new()
	inst.setup(id)
	WorldState.inventory.append(inst)


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _setup() -> void:
	WorldState.new_game()
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	await _frames(40)
	p = get_tree().get_first_node_in_group("player")
	_clear_the_dead()
	WorldState.inventory.clear()
	_give("002")      # 0 hammer
	_give("005")      # 1 canned food
	_give("006")      # 2 bandages (LAST — using it must not shift the others)
	HUD.refresh_inventory()
	WorldState.god_mode = false


func _clear_the_dead() -> void:
	# A random seed puts zombies in the corridor: any that reached the player would slam the pack
	# shut mid-check (correct behaviour, a flaky test). Clear them; the hit test hits by hand.
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()


func _reset() -> void:
	_clear_the_dead()
	if p.pack_phase != "":
		p.end_pack(true)
	p.is_hit = false
	p.is_dead = false
	p.is_dying = false
	p.is_cutscene = false
	p.health_state = 0
	WorldState.player_health = 0
	HUD.selected_slot = -1
	Engine.time_scale = 1.0
	await _frames(2)


func _feet_x() -> float:
	return (p.animated_sprite.global_transform * Vector2(0, p._pack_feet_dy / p.animated_sprite.scale.y)).x


func _test_sequence() -> void:
	print("[kneel → open → stand]")
	await _reset()
	var pw = HUD.pack_wheel
	check(pw != null and HUD.pack_button != null, "the HUD has the pack button and its ring")
	check(p.pack_blocked_reason() == "", "a free player may kneel to the pack")
	var x0: float = p.global_position.x
	var y0: float = p.global_position.y
	var feet0: float = (p.animated_sprite.global_transform * Vector2(0, maxf(p.feet_position().y - p.animated_sprite.global_position.y, 0.0) / p.animated_sprite.scale.y)).x
	check(pw.toggle(), "the pack key / button starts it")
	check(p.pack_phase == "kneel", "…kneeling first")
	check(is_instance_valid(p._pack_prop), "…with the pack laid at their feet")
	check(not pw.is_open, "the ring is NOT up while they're still going down")
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	await get_tree().process_frame
	check(p.pack_phase == "open", "after the kneel the pack is open")
	check(pw.is_open and pw.visible, "…and the ring appears")
	check(pw.slots.size() == mini(WorldState.inventory.size(), WorldState.get_inventory_slots()), "the ring holds the whole bag (%d slots)" % pw.slots.size())
	check(absf(p.animated_sprite.skew) > 0.1, "the body leans toward the pack (skew %.2f)" % p.animated_sprite.skew)
	check(absf(_feet_x() - feet0) < 0.6, "…with the FEET held where they were (moved %.2f px)" % absf(_feet_x() - feet0))
	check(absf(p.global_position.x - x0) < 0.01 and absf(p.global_position.y - y0) < 0.01, "the player is rooted (no drift)")
	check(Engine.time_scale == 1.0, "the world is NOT slowed — it stays live")
	check(p.animated_sprite.animation == &"crouch_idle", "they're in the crouch pose")
	check(pw.toggle(), "the key again puts it away")
	check(p.pack_phase == "stand", "…standing back up")
	await _frames(int(ceil(p.PACK_STAND_TIME * 60.0)) + 6)
	await get_tree().process_frame
	check(p.pack_phase == "", "the stand-up finishes")
	check(absf(p.animated_sprite.skew) < 0.001 and absf(p.animated_sprite.position.x - p._pack_base_x) < 0.01, "…upright again, sprite back where it was")
	check(not is_instance_valid(p._pack_prop), "…the pack prop is gone")
	check(not pw.is_open and not pw.visible, "…and so is the ring")


func _open_pack() -> void:
	HUD.pack_wheel.toggle()
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	await get_tree().process_frame


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	# Prime the viewport's cached mouse position (headless has no cursor), then push the press.
	# Headless windows aren't the content size, so a pushed event is scaled by the inverse of the
	# viewport's final transform; push it in WINDOW space so the ring sees `pos` in HUD space.
	var wpos: Vector2 = get_viewport().get_final_transform() * pos
	var mv := InputEventMouseMotion.new()
	mv.position = wpos
	get_viewport().push_input(mv)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = wpos
	get_viewport().push_input(ev)
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = wpos
	get_viewport().push_input(up)
	await get_tree().process_frame


func _slot_pos(k: int) -> Vector2:
	var pw = HUD.pack_wheel
	return pw.QuickWheel.slot_position(pw.centre, k, pw.slots.size(), pw.RING_R)


func _world_has_drop(item_id: String) -> bool:
	for k in WorldState.world_drops:
		if str(WorldState.world_drops[k].get("item_id", "")) == item_id:
			return true
	return false


func _test_ring_actions() -> void:
	print("[ring actions]")
	await _reset()
	await _open_pack()
	var pw = HUD.pack_wheel
	check(pw.is_open, "ring up")
	var n: int = pw.slots.size()
	# left-click equips / a second click puts it away
	await _click(Vector2(1, 1))     # a click out in the world closes it (checked properly below) — re-open
	await _reset()
	await _open_pack()
	await _click(_slot_pos(0))
	check(HUD.selected_slot == 0, "left-click on a wedge equips it (slot %d)" % HUD.selected_slot)
	check(pw.is_open, "…and the pack stays open")
	await _click(_slot_pos(0))
	check(HUD.selected_slot == -1, "left-click again puts it away")
	# a throwable can't be thrown from your knees
	var can = WorldState.get_instance_at(1)
	var cans_before: int = can.count
	await _click(_slot_pos(1), MOUSE_BUTTON_RIGHT)
	check(WorldState.get_instance_at(1) == can and can.count == cans_before, "a can is NOT thrown from down there (kept)")
	check(pw.is_open, "…and the pack stays open")
	# use: bandages heal
	p.health_state = 2
	WorldState.player_health = 2
	await _click(_slot_pos(2), MOUSE_BUTTON_RIGHT)
	check(int(p.health_state) < 2, "right-click USES it — a bandage from the bag (health %d)" % int(p.health_state))
	check(pw.is_open, "…still open")
	# delete drops it out of the bag — never destroyed silently
	var held_id: String = WorldState.get_instance_at(1).item_id
	pw.drop_at(1)
	check(WorldState.get_instance_at(1) == null or WorldState.get_instance_at(1).item_id != held_id, "Delete takes the item out of the bag…")
	check(_world_has_drop(held_id), "…and it is on the floor (a world drop of %s exists)" % held_id)
	# closing by the middle
	await _click(HUD.pack_wheel.centre)
	check(p.pack_phase == "stand" or p.pack_phase == "", "a click in the middle closes it")
	await _reset()
	# closing by a click in the world
	await _open_pack()
	await _click(Vector2(60, 300))
	check(p.pack_phase == "stand" or p.pack_phase == "", "a click out in the world closes it")
	await _reset()
	# a click in the strip is NOT the world's: it neither closes nor equips
	await _open_pack()
	await _click(Vector2(600, 600))
	check(p.pack_phase == "open", "a click in the hotbar strip doesn't close it")
	# Esc closes the pack, not the game
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	get_viewport().push_input(esc)
	await get_tree().process_frame
	check(p.pack_phase == "stand" or p.pack_phase == "", "Esc closes the pack (phase %s)" % p.pack_phase)
	check(not get_tree().paused, "…and does not open the pause menu on top")
	await _reset()


func _test_exits() -> void:
	print("[every exit leaves nothing stuck]")
	# a hit slams it shut at once
	await _reset()
	await _open_pack()
	var hp0: int = int(p.health_state)
	p.receive_hit(1)
	check(p.pack_phase == "", "a hit slams the pack shut AT ONCE (no stand-up to wait through)")
	check(int(p.health_state) > hp0, "…and still hurts (health %d → %d)" % [hp0, int(p.health_state)])
	check(absf(p.animated_sprite.skew) < 0.001, "…and knocks them upright")
	check(not is_instance_valid(p._pack_prop), "…the prop is gone")
	await get_tree().process_frame
	check(not HUD.pack_wheel.is_open, "…and so is the ring")
	# a hit while merely kneeling (ring not up yet)
	await _reset()
	HUD.pack_wheel.toggle()
	await _frames(6)
	p.receive_hit(1)
	check(p.pack_phase == "", "a hit mid-kneel cancels it too")
	# crouching before → still crouching after
	await _reset()
	p.is_crouching = true
	await _open_pack()
	HUD.pack_wheel.toggle()
	await _frames(int(ceil(p.PACK_STAND_TIME * 60.0)) + 6)
	check(p.is_crouching, "a player who was crouching is still crouching afterwards")
	p.is_crouching = false
	# death
	await _reset()
	await _open_pack()
	p.is_dead = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(p.pack_phase == "" and not HUD.pack_wheel.is_open, "death takes them out of the pack and drops the ring")
	p.is_dead = false
	# a cutscene (a door approach, a stair step)
	await _reset()
	await _open_pack()
	p.is_cutscene = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(p.pack_phase == "" and not HUD.pack_wheel.is_open, "a cutscene takes them out of the pack")
	p.is_cutscene = false
	# a movement key stands them up
	await _reset()
	await _open_pack()
	Input.action_press("move_right")
	await _frames(3)
	Input.action_release("move_right")
	check(p.pack_phase == "stand" or p.pack_phase == "", "pressing a movement key gets them up")
	await _reset()
	# the pause menu / a paused tree hides the ring but the state survives
	await _open_pack()
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	check(Engine.time_scale == 1.0, "a pause never leaves time scaled")
	await _reset()


func _test_refusals() -> void:
	print("[refusals]")
	await _reset()
	var pw = HUD.pack_wheel
	p.is_attacking = true
	check(not pw.toggle(), "mid-swing: refused")
	p.is_attacking = false
	p.is_listening = true
	check(not pw.toggle(), "listening: refused")
	p.is_listening = false
	p.is_lashing = true
	check(not pw.toggle(), "lashing a rope: refused")
	p.is_lashing = false
	p.on_balcony_plane = true
	check(not pw.toggle(), "out on a balcony: refused")
	p.on_balcony_plane = false
	WorldState.loot_open = true
	check(not pw.toggle(), "a loot panel open: refused")
	WorldState.loot_open = false
	HUD.dialogue_panel.visible = true
	check(not pw.toggle(), "a dialogue up: refused")
	HUD.dialogue_panel.visible = false
	HUD.quick_wheel.open()
	check(HUD.quick_wheel.is_open and not pw.toggle(), "the quick wheel open: refused (never two rings)")
	HUD.quick_wheel.close(false)
	check(Engine.time_scale == 1.0, "…the quick wheel gave the time back")
	await _reset()
	# and the quick wheel refuses while kneeling
	await _open_pack()
	check(HUD.quick_wheel.blocked_reason() == "at the pack", "the quick wheel won't open while kneeling (%s)" % HUD.quick_wheel.blocked_reason())
	await _reset()
	check(p.pack_blocked_reason() == "", "everything is free again after a reset")
	# an empty bag still opens (an empty ring, closable)
	var keep: Array = WorldState.inventory.duplicate()
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	await _open_pack()
	check(p.pack_phase == "open" and HUD.pack_wheel.is_open, "an EMPTY bag still opens (never a dead end)")
	await _click(HUD.pack_wheel.centre)
	check(p.pack_phase == "stand" or p.pack_phase == "", "…and closes")
	WorldState.inventory = keep
	HUD.refresh_inventory()
	await _reset()


func _test_button_and_key() -> void:
	print("[the button and the key]")
	await _reset()
	var btn = HUD.pack_button
	check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "the pack button takes clicks")
	check(HUD.get_node("Control").mouse_filter == Control.MOUSE_FILTER_IGNORE, "…while the HUD root still ignores the mouse (click-to-move)")
	var r: Rect2 = btn.get_global_rect()
	check(r.position.y >= HUD.STRIP_TOP and r.end.x <= HUD.SCREEN_W and r.position.x > HUD.hbox.position.x + 64.0 * 6, "it sits in the strip, right of the hotbar")
	btn.pressed.emit()
	check(p.pack_phase == "kneel", "clicking the pack starts the kneel")
	await _frames(4)
	check(btn.is_pack_open, "…the button shows it as open")
	var ev := InputEventAction.new()
	ev.action = "open_pack"
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame
	check(p.pack_phase == "stand", "the pack KEY (B) toggles it too (phase %s)" % p.pack_phase)
	check(InputMap.has_action("open_pack") and not InputMap.action_get_events("open_pack").is_empty(), "the action is bound")
	var listed := false
	for row in SettingsManager.REMAPPABLE:
		if row[0] == "open_pack":
			listed = true
	check(listed, "…and rebindable in Settings")
	check(HUD.action_key_name("open_pack", "?") == "B", "the hint names the CURRENT key (%s)" % HUD.action_key_name("open_pack", "?"))
	await _reset()
