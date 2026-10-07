extends Node

# The BACKPACK sequence (owner round 26: "click the pack, the player bends down and opens their
# backpack, then a wheel for inventory opens with live gameplay underneath so you can still be
# attacked"; docs/BACKPACK.md), on the REAL player in a REAL corridor:
#  * kneel → open → stand: a crouch with the bag opening beside them on the floor, NO lean (owner round 33);
#  * the world is never slowed and the player is rooted; the ring is a pure view of the player's phase;
#  * click equips / right-click opens a menu (equip / use / drop) / drag OFF the ring drops / Delete drops /
#    the middle, Esc, the key and a click in the world close; the help line sits clear of the ring;
#  * a hit slams it shut at once; every other exit (death, a cutscene, a panel) leaves nothing stuck;
#  * it refuses to start when it shouldn't.
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
	await _test_full_ring_and_prompts()
	await _test_pack_beside_loot()
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
	check(pw.slots.size() == WorldState.get_inventory_slots() + (1 if WorldState.get_inventory_slots() < 6 else 0),
		"the ring holds every slot of the bag, empty ones and the locked one too (%d slots)" % pw.slots.size())
	check(absf(p.animated_sprite.skew) < 0.001 and absf(p.animated_sprite.position.x - p._pack_base_x) < 0.01,
		"no lean — just the crouch (skew %.2f)" % p.animated_sprite.skew)
	var prop = p._pack_prop
	var dx: float = prop.global_position.x - p.global_position.x if is_instance_valid(prop) else 0.0
	check(is_instance_valid(prop) and absf(dx) > 12.0 and signf(dx) == (-1.0 if p.animated_sprite.flip_h else 1.0)
		and absf(prop.global_position.y - p.feet_position().y) < 2.0, "the bag lies BESIDE them on the floor (dx %.0f)" % dx)
	check(is_instance_valid(prop) and prop.open_amount > 0.99, "…and it's open")
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
	return pw.RingGeo.slot_position(pw.centre, k, pw.slots.size(), pw.RING_R)


func _row_pos(row: int) -> Vector2:
	var pw = HUD.pack_wheel
	return pw.menu_pos + Vector2(pw.MENU_W * 0.5, 4.0 + pw.MENU_ROW_H * (row + 0.5))


func _row_of(action: String) -> int:
	var pw = HUD.pack_wheel
	for i in range(pw.menu_rows.size()):
		if String(pw.menu_rows[i][1]) == action:
			return i
	return -1


## Press on `from`, move past the drag threshold to `to`, let go there.
func _drag(from: Vector2, to: Vector2) -> void:
	var ft: Transform2D = get_viewport().get_final_transform()
	for step in [[from, true], [from.lerp(to, 0.3), false], [to, false]]:
		var mv := InputEventMouseMotion.new()
		mv.position = ft * step[0]
		get_viewport().push_input(mv)
		if step[1]:
			var dn := InputEventMouseButton.new()
			dn.button_index = MOUSE_BUTTON_LEFT
			dn.pressed = true
			dn.position = ft * from
			get_viewport().push_input(dn)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = ft * to
	get_viewport().push_input(up)
	await get_tree().process_frame


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
	# right-click: a MENU, not an action (owner round 33 — it used to do the same as a left click)
	var sel_before: int = HUD.selected_slot
	await _click(_slot_pos(0), MOUSE_BUTTON_RIGHT)
	check(pw.menu_k == 0 and _row_of("equip") >= 0 and _row_of("drop") >= 0, "right-click opens the item's options (%s)" % str(pw.menu_rows))
	check(HUD.selected_slot == sel_before, "…and doesn't equip it by itself")
	await _click(_row_pos(_row_of("equip")))
	check(HUD.selected_slot == 0 and pw.menu_k == -1, "'Equip' equips it and the menu closes")
	await _click(_slot_pos(0), MOUSE_BUTTON_RIGHT)
	check(String(pw.menu_rows[0][0]) == "Put away", "in hand, the first option is 'Put away'")
	await _click(Vector2(pw.centre.x + 5.0, pw.centre.y + 5.0))
	check(pw.menu_k == -1 and p.pack_phase == "open", "a click elsewhere just closes the menu (the pack stays open)")
	HUD.select_slot(0)
	# a throwable can't be thrown from your knees
	var can = WorldState.get_instance_at(1)
	var cans_before: int = can.count
	await _click(_slot_pos(1), MOUSE_BUTTON_RIGHT)
	await _click(_row_pos(_row_of("use")))
	check(WorldState.get_instance_at(1) == can and can.count == cans_before, "a can is NOT thrown from down there (kept)")
	check(pw.is_open, "…and the pack stays open")
	# use: bandages heal
	p.health_state = 2
	WorldState.player_health = 2
	await _click(_slot_pos(2), MOUSE_BUTTON_RIGHT)
	check(_row_of("use") >= 0, "bandages offer 'Use'")
	await _click(_row_pos(_row_of("use")))
	check(int(p.health_state) < 2, "'Use' — a bandage from the bag (health %d)" % int(p.health_state))
	check(pw.is_open, "…still open")
	# the menu's Drop
	var drop_id: String = WorldState.get_instance_at(1).item_id if WorldState.get_instance_at(1) != null else ""
	await _click(_slot_pos(1), MOUSE_BUTTON_RIGHT)
	await _click(_row_pos(_row_of("drop")))
	check(drop_id != "" and _world_has_drop(drop_id), "'Drop' puts it on the floor (%s)" % drop_id)
	# DRAG an item off the ring and let go: dropped at your feet
	_give("010")
	HUD.refresh_inventory()
	await get_tree().process_frame
	var last: int = WorldState.inventory.size() - 1
	var drag_id: String = WorldState.get_instance_at(last).item_id
	var drops_before: int = WorldState.world_drops.size()
	var off: Vector2 = pw.centre + (_slot_pos(last) - pw.centre).normalized() * (pw.RING_R + pw.DISC_SEL + 40.0)
	await _drag(_slot_pos(last), off)
	check(WorldState.inventory.size() == last and WorldState.world_drops.size() == drops_before + 1,
		"dragged off the ring and let go: %s is dropped on the floor" % drag_id)
	check(p.pack_phase == "open", "…and the pack stays open")
	# dragged onto a HUD widget (the pack button) it is NOT dropped
	_give("010")
	HUD.refresh_inventory()
	await get_tree().process_frame
	last = WorldState.inventory.size() - 1
	await _drag(_slot_pos(last), HUD.pack_button.get_global_rect().get_center())
	check(WorldState.inventory.size() == last + 1, "let go over the pack button: kept")
	# the help line sits clear of the ring (it used to run behind the top item)
	var font: Font = pw.get_theme_default_font()
	var hw: float = font.get_string_size(pw.HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
	var hr := Rect2(pw.centre.x - hw * 0.5, pw.hint_top(), hw, 20.0)
	var clear := true
	for k in range(pw.slots.size()):
		var sp: Vector2 = _slot_pos(k)
		var rad: float = pw.DISC_SEL * 0.5
		if hr.intersects(Rect2(sp - Vector2(rad, rad), Vector2(rad, rad) * 2.0)):
			clear = false
	check(clear and hr.position.y >= 0.0, "the help line is clear of every item on the ring (top %.0f)" % hr.position.y)
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
	# a click on a HUD widget is NOT the world's: it neither closes nor equips
	await _open_pack()
	HUD.set_hotbar_visible(true)
	await get_tree().process_frame
	await _click(HUD.slots[3].get_global_rect().get_center())
	check(p.pack_phase == "open", "a click on a (shown) hotbar slot doesn't close it")
	HUD.set_hotbar_visible(false)
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


## Owner round 36f: "if my inventory is full and I scavenge an item, I should be able to open the backpack while still in that scavenge
## UI… the search panel can move left and the item wheel show on the right… drag from the node to the wheel" — and "dragging items from the
## item wheel doesn't work when that item is on top of a scavenge node" (the room's click-to-search swallowed the press).
func _test_pack_beside_loot() -> void:
	print("[the pack beside a found item]")
	await _reset()
	var pw = HUD.pack_wheel
	WorldState.is_scavenge_mode = true
	WorldState.current_apartment_id = "test"
	WorldState.inventory.clear()
	for id in ["002", "012", "007", "004", "035"]:
		if WorldState.inventory.size() < WorldState.get_inventory_slots():
			_give(id)
	HUD.refresh_inventory()
	check(WorldState.inventory.size() == WorldState.get_inventory_slots(), "(the bag is full: %d)" % WorldState.inventory.size())
	WorldState.set_anchor_item("test", "a1", "011")
	var loot = load("res://scenes/loot_ui.tscn").instantiate()
	add_child(loot)
	await get_tree().process_frame
	loot.open("011", "a1", "test")
	check(not pw.toggle(), "mid-search the bag stays shut")
	loot._process(loot.REVEAL_TIME + 0.1)
	loot._take()
	check(loot.visible and loot.name_label.text == "Inventory full", "a full bag refuses the found item")
	check(p.pack_blocked_reason() == "" and not WorldState.inventory.is_empty(), "…and the pack MAY open beside it")
	check(pw.toggle() and p.pack_phase == "kneel", "the pack opens while the panel is up")
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 20)
	check(pw.is_open and loot.visible, "ring up, panel still up")
	var pr: Rect2 = loot.panel.get_global_rect()
	check(pw.centre.x - pw.RING_R - pw.DISC_SEL * 0.5 > pr.end.x, "the panel slid LEFT of the ring (panel ends %.0f, ring starts %.0f)" % [pr.end.x, pw.centre.x - pw.RING_R - pw.DISC_SEL * 0.5])
	check(pw.centre.x > HUD.SCREEN_W * 0.55 and pw.centre.x < HUD.SCREEN_W * 0.72, "the ring sits right of the panel but near the middle, not at the edge (%.0f of %.0f)" % [pw.centre.x, HUD.SCREEN_W])
	var pair_l: float = pr.position.x
	var pair_r: float = pw.centre.x + pw.RING_R + pw.DISC_SEL * 0.5
	check(absf((pair_l + pair_r) * 0.5 - HUD.SCREEN_W * 0.5) < 40.0, "…the panel + ring pair is centred on the screen (%.0f..%.0f)" % [pair_l, pair_r])
	# a ring slot is HUD ground (the room's click-to-search must not take a press that lands on it)
	check(HUD.pointer_over_widget(_slot_pos(0)) and HUD.pointer_over_widget(pw.centre), "a press on the ring belongs to the ring, not the room under it")
	# ring → panel: onto the found item with the bag full puts that one down and takes the new one
	var first: String = WorldState.inventory[0].item_id
	await _drag(_slot_pos(0), pr.get_center())
	await _frames(2)
	var has_new := false
	for inst in WorldState.inventory:
		if inst.item_id == "011":
			has_new = true
	check(has_new and not loot.visible and not WorldState.loot_open, "dragging a bag item onto the found item swaps them (took the ice pack, panel closed)")
	check(_world_has_drop(first), "…and the swapped-out item (%s) lies at the feet, not lost" % first)
	check(pw.is_open and p.pack_phase == "open", "…the pack stays open")
	# panel → ring: the other way
	while WorldState.inventory.size() < WorldState.get_inventory_slots():
		_give("007")
	HUD.refresh_inventory()
	WorldState.set_anchor_item("test", "a2", "011")
	loot.open("011", "a2", "test")
	loot._process(loot.REVEAL_TIME + 0.1)
	await get_tree().process_frame
	pr = loot.panel.get_global_rect()
	await get_tree().create_timer(0.45).timeout        # (a second press inside DOUBLE_CLICK_TIME is a double-click = take)
	var gone: String = WorldState.inventory[1].item_id
	var count_gone: int = 0
	for inst in WorldState.inventory:
		if inst.item_id == gone:
			count_gone += 1
	await _drag(pr.get_center(), _slot_pos(1))
	await _frames(2)
	var count_after: int = 0
	for inst in WorldState.inventory:
		if inst.item_id == gone:
			count_after += 1
	check(not loot.visible and count_after == count_gone - 1, "dragging the found item onto a ring slot swaps it in (%d → %d of %s)" % [count_gone, count_after, gone])
	loot.queue_free()
	WorldState.loot_open = false
	WorldState.is_scavenge_mode = false
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
	check(pw.toggle() and p.pack_phase == "kneel", "out on a balcony: the bag opens (owner round 36d — from anywhere)")
	p.on_balcony_plane = false
	await _reset()
	WorldState.loot_open = true
	check(not pw.toggle(), "a loot panel open: refused")
	WorldState.loot_open = false
	HUD.dialogue_panel.visible = true
	check(not pw.toggle(), "a dialogue up: refused")
	HUD.dialogue_panel.visible = false
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
	check(r.end.x <= HUD.SCREEN_W and r.end.y <= HUD.SCREEN_H and r.position.x > HUD.SCREEN_W * 0.85 and r.position.y > HUD.SCREEN_H * 0.7, "it is the bottom-right corner")
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


## Owner round 33: "when you don't have any items in your bag, opening the bag doesn't show a wheel. We still need a wheel even if
## empty. When you drop items, the wheel should not lessen in number of slots… there is always a locked slot unless the upgrade is
## collected" — and "When opening the bag, in game text like that door behind being locked, it should disappear".
func _test_full_ring_and_prompts() -> void:
	print("[the ring: every slot, empty or locked; world pills step aside]")
	await _reset()
	var pw = HUD.pack_wheel
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	var owner_ := Node2D.new()
	add_child(owner_)
	HUD.show_world_prompt(owner_, "2805 - Locked  Needs key  [R] Listen", p.global_position + Vector2(0, -60))
	await get_tree().process_frame
	var pill: Panel = HUD.world_prompt_panel(owner_)
	check(pill != null and pill.visible and pill.modulate.a > 0.9, "a door pill is up before the pack opens")
	await _open_pack()
	var cap: int = WorldState.get_inventory_slots()
	check(pw.is_open and pw.slots.size() == cap + 1, "an EMPTY bag still opens a full ring: %d slots + the locked one (%d)" % [cap, pw.slots.size()])
	check(pw.is_locked(pw.slots.size() - 1) and not pw.is_locked(0), "...the last wedge is the LOCKED slot")
	check(pw._slot_inst(pw.slots.size() - 1) == null, "...and it holds nothing, so no action can touch it")
	check(pill.visible and pill.modulate.a < 0.01, "the world pill steps aside while the ring is open")
	p.end_pack(false)
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	await get_tree().process_frame
	check(pill.modulate.a > 0.9, "...and comes back when the pack closes")
	# items in, one dropped: the ring keeps its size
	_give("002"); _give("005"); _give("006")
	HUD.refresh_inventory()
	await _open_pack()
	var n0: int = pw.slots.size()
	pw.drop_at(0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(WorldState.inventory.size() == 2 and pw.slots.size() == n0 and n0 == cap + 1, "dropping an item doesn't shrink the ring (%d → %d)" % [n0, pw.slots.size()])
	p.end_pack(false)
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	# with the slot upgrade, no locked wedge
	WorldState.active_upgrades.append("U_slot")
	await _open_pack()
	check(pw.slots.size() == WorldState.get_inventory_slots() and WorldState.get_inventory_slots() == 6 and not pw.is_locked(pw.slots.size() - 1),
		"with the upgrade the sixth slot is a real one (%d slots)" % pw.slots.size())
	p.end_pack(false)
	await _frames(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 6)
	WorldState.active_upgrades.erase("U_slot")
	HUD.hide_world_prompt(owner_)
	owner_.queue_free()
