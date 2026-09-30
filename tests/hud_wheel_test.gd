extends Node

# The CORNER-CLUSTER HUD + the QUICK WHEEL (owner round 26: "combine 1 and 4, then build it in the game").
#  * the wheel's geometry round-trips (every slot position maps back to its own wedge);
#  * it opens only when it should, slows time while held and ALWAYS gives the time back;
#  * releasing equips what the pointer is on; the middle / an empty ring cancels;
#  * the cluster: identity top-left, place + time top-right, the hotbar centred and inside the strip.
# Run:  godot --headless res://tests/hud_wheel_test.tscn

const Wheel := preload("res://scripts/quick_wheel.gd")

var failures: int = 0
var stub: Node2D = null


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== hud cluster + quick wheel test ===")
	await get_tree().process_frame
	_test_geometry()
	await _test_cluster()
	await _test_wheel()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _give(id: String) -> void:
	var inst := ItemInstance.new()
	inst.setup(id)
	WorldState.inventory.append(inst)


func _stub_player() -> Node2D:
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nvar is_dead = false\nvar is_dying = false\nvar is_cutscene = false\nvar escaping = false\nvar is_lashing = false\nvar is_listening = false\n"
	gs.reload()
	var p := Node2D.new()
	p.set_script(gs)
	p.add_to_group("player")
	add_child(p)
	return p


func _test_geometry() -> void:
	print("[wheel geometry]")
	var c := Vector2(500, 300)
	check(Wheel.index_for(Vector2(0, -100), 4) == 0, "straight up = item 0")
	check(Wheel.index_for(Vector2(100, 0), 4) == 1, "right = item 1 (clockwise)")
	check(Wheel.index_for(Vector2(0, 100), 4) == 2, "down = item 2")
	check(Wheel.index_for(Vector2(-100, 0), 4) == 3, "left = item 3")
	check(Wheel.index_for(Vector2(10, -10), 4) == -1, "inside the dead zone = nothing (cancel)")
	check(Wheel.index_for(Vector2(0, -100), 0) == -1, "an empty ring picks nothing")
	check(Wheel.index_for(Vector2(0, -100), 1) == 0 and Wheel.index_for(Vector2(0, 100), 1) == 0, "a single item owns the whole ring")
	var ok := true
	for n in range(1, 7):
		for k in range(n):
			var pos: Vector2 = Wheel.slot_position(c, k, n)
			if Wheel.index_for(pos - c, n) != k:
				ok = false
				print("    round-trip broke at n=%d k=%d" % [n, k])
	check(ok, "every slot's position maps back to its own wedge, for 1..6 items")


func _test_cluster() -> void:
	print("[corner cluster]")
	WorldState.new_game()
	await get_tree().process_frame
	HUD.update_portrait(0)
	HUD.update_floor_label()
	check(HUD.name_label != null and HUD.name_label.text == WorldState.character_display_name(WorldState.current_character()).to_upper(),
		"the character's name is top-left (%s)" % HUD.name_label.text)
	check(HUD.condition_label.text == "Healthy", "…with their condition in words")
	var lit: Array = []
	for st in range(6):
		HUD.update_portrait(st)
		lit.append(HUD.health_ring.lit_segments())
	check(lit == [10, 8, 6, 4, 2, 1], "the health ring lights fewer pips at every worse stage (%s)" % str(lit))
	HUD.update_portrait(0)
	check(HUD.portrait.mouse_filter == Control.MOUSE_FILTER_STOP, "the portrait is still the button")
	check(HUD.portrait.get_parent() == HUD._portrait_clip and HUD._portrait_clip.clip_children == CanvasItem.CLIP_CHILDREN_ONLY,
		"…and it sits in a circular clip window")
	check(HUD.floor_label.text == str(WorldState.current_floor), "the floor numeral is top-right")
	check(HUD.time_label.text == WorldState.time_of_day().to_upper() and HUD.run_pips.run == WorldState.current_run,
		"…with the time of day and the run pips")
	# the hotbar floats centred in the strip
	var r0: Rect2 = HUD.slots[0].get_global_rect()
	var r5: Rect2 = HUD.slots[5].get_global_rect()
	check(absf((r0.position.x - 0.0) - (HUD.SCREEN_W - r5.end.x)) < 3.0, "the hotbar is centred (left gap %.0f, right gap %.0f)" % [r0.position.x, HUD.SCREEN_W - r5.end.x])
	check(r0.position.y >= HUD.STRIP_TOP and r0.end.y <= HUD.SCREEN_H, "…and sits inside the bottom strip")
	# nothing new may swallow a world click (click-to-move)
	var stoppers: Array = []
	for n in [HUD.name_label, HUD.condition_label, HUD.floor_label, HUD.floor_caption, HUD.floor_total_label, HUD.time_label,
			HUD.run_pips, HUD.health_ring, HUD.wallet_label, HUD.scrap_label, HUD.equipped_label, HUD.equipped_detail,
			HUD.wheel_hint, HUD.stamina_bar, HUD.quick_wheel, HUD.wallet_icon, HUD.scrap_icon]:
		if n.mouse_filter == Control.MOUSE_FILTER_STOP:
			stoppers.append(n.name)
	check(stoppers.is_empty(), "no cluster element swallows world clicks %s" % str(stoppers))
	# the currency icons follow their counters
	WorldState.wallet_unlocked = false
	WorldState.scrap_unlocked = false
	HUD.update_wallet()
	HUD.update_scrap()
	check(not HUD.wallet_icon.visible and not HUD.scrap_icon.visible, "a locked wallet / scrap shows no icon")
	WorldState.wallet_unlocked = true
	WorldState.scrap_unlocked = true
	WorldState.wallet_balance = 140
	WorldState.scrap = 35
	HUD.update_wallet()
	HUD.update_scrap()
	check(HUD.wallet_icon.visible and HUD.wallet_label.text == "140" and HUD.scrap_icon.visible and HUD.scrap_label.text == "35",
		"unlocked: icon + number")
	check(HUD.wallet_icon.texture != null and HUD.scrap_icon.texture != null, "…and both icons have art")
	# the in-hand line
	WorldState.inventory.clear()
	_give("002")
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	HUD._update_equipped_chip()
	check(HUD.equipped_label.text == "EMPTY-HANDED", "nothing selected reads empty-handed")
	HUD.select_slot(0)
	check(HUD.equipped_label.text == "HAMMER" and HUD.equipped_detail.text.contains("uses"), "the selected item's name + condition (%s / %s)" % [HUD.equipped_label.text, HUD.equipped_detail.text])
	HUD.select_slot(0)
	check(HUD.wheel_hint.text.contains("Tab"), "the wheel hint names the bound key (%s)" % HUD.wheel_hint.text)
	check(InputMap.has_action("item_wheel"), "item_wheel is a real input action")
	var listed := false
	for e in SettingsManager.REMAPPABLE:
		if e[0] == "item_wheel":
			listed = true
	check(listed, "…and it's rebindable in Settings")
	WorldState.wallet_unlocked = false
	WorldState.scrap_unlocked = false
	WorldState.wallet_balance = 0
	WorldState.scrap = 0


func _test_wheel() -> void:
	print("[quick wheel]")
	var w = HUD.quick_wheel
	Engine.time_scale = 3.0                      # a value that isn't 1.0, so 'restored' can't pass by luck
	WorldState.new_game()
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	check(w.blocked_reason() == "no player", "no player = it stays shut (%s)" % w.blocked_reason())
	stub = _stub_player()
	stub.global_position = Vector2(576, 380)
	check(w.blocked_reason() == "" , "with a player it may open (%s)" % w.blocked_reason())
	check(not w.open() and not w.is_open and Engine.time_scale == 3.0, "an empty bag opens nothing and slows nothing")
	for id in ["002", "035", "036", "006"]:
		_give(id)
	HUD.refresh_inventory()
	# --- each rule that must keep it shut
	get_tree().paused = true
	check(w.blocked_reason() == "paused", "paused: shut")
	get_tree().paused = false
	stub.set("is_dead", true)
	check(w.blocked_reason() == "is_dead", "a dead player: shut")
	stub.set("is_dead", false)
	stub.set("is_cutscene", true)
	check(w.blocked_reason() == "is_cutscene", "a cutscene: shut")
	stub.set("is_cutscene", false)
	HUD.dialogue_panel.visible = true
	check(w.blocked_reason() == "dialogue", "a dialogue prompt: shut")
	HUD.dialogue_panel.visible = false
	# --- open, point, release
	check(w.open() and w.is_open, "opens with items")
	check(w.entries == [0, 1, 2, 3] and Engine.time_scale == Wheel.SLOW_SCALE, "shows the four items and slows the game (x%.2f)" % Engine.time_scale)
	check(w.centre.y <= Wheel.STRIP_TOP and w.centre.x >= 100.0, "the ring stays clear of the hotbar strip")
	w.mouse_override = Wheel.slot_position(w.centre, 2, 4)
	await get_tree().process_frame
	check(w.hover == 2, "pointing at the third item hovers it")
	w.close(true)
	check(not w.is_open and Engine.time_scale == 3.0, "releasing gives the time back (x%.1f)" % Engine.time_scale)
	check(HUD.selected_slot == 2, "…and equips it (slot %d)" % HUD.selected_slot)
	# --- the middle cancels
	HUD.select_slot(2)                                  # toggle off
	HUD.select_slot(0)
	w.open()
	w.mouse_override = w.centre
	await get_tree().process_frame
	check(w.hover == -1, "the middle hovers nothing")
	w.close(true)
	check(HUD.selected_slot == 0, "releasing in the middle changes nothing (slot %d)" % HUD.selected_slot)
	# --- it starts on what's in hand
	w.open()
	check(w.hover == 0, "it opens on the item already in hand")
	w.close(false)
	# --- the real input action drives it
	w.mouse_override = null
	var press := InputEventAction.new()
	press.action = "item_wheel"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	check(w.is_open, "pressing the wheel action opens it")
	var rel := InputEventAction.new()
	rel.action = "item_wheel"
	rel.pressed = false
	Input.parse_input_event(rel)
	await get_tree().process_frame
	check(not w.is_open and Engine.time_scale == 3.0, "releasing the action closes it and restores time")
	# --- anything that takes the player out of play closes it AND returns the time
	for flag in ["is_dead", "is_cutscene"]:
		w.open()
		stub.set(flag, true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(not w.is_open and Engine.time_scale == 3.0, "%s mid-hold closes it and restores time" % flag)
		stub.set(flag, false)
	w.open()
	get_tree().paused = true
	await get_tree().process_frame
	get_tree().paused = false
	await get_tree().process_frame
	check(not w.is_open and Engine.time_scale == 3.0, "a pause mid-hold closes it and restores time")
	# --- the bag changing under it
	w.open()
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not w.is_open and Engine.time_scale == 3.0, "emptying the bag mid-hold closes it and restores time")
	Engine.time_scale = 1.0
	stub.queue_free()
