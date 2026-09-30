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
	await _test_identity_and_stamina()
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


func _test_identity_and_stamina() -> void:
	print("[identity bottom-left + the single stamina bar]")
	WorldState.new_game()
	await get_tree().process_frame
	var pr: Rect2 = HUD.portrait.get_global_rect()
	check(pr.position.x < 40.0 and pr.end.y <= HUD.SCREEN_H and pr.position.y > HUD.SCREEN_H * 0.6,
		"the portrait sits in the bottom-left corner (%s)" % str(pr))
	check(pr.size.x >= 120.0 and pr.size.y >= 150.0, "…LARGE and uncropped, not a small circle (%.0f x %.0f)" % [pr.size.x, pr.size.y])
	check(HUD.portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED and HUD.portrait.get_parent() == HUD.get_node("Control"),
		"…the whole bust (no circular clip window, no ring round it)")
	check(not ("health_ring" in HUD) and not ("_portrait_clip" in HUD), "…and the health ring / clip window are gone")
	check(HUD.name_label.global_position.x > pr.end.x - 20.0 and HUD.name_label.global_position.y >= pr.position.y,
		"…with the name beside it")
	# no bloat text (owner round 26e): the portrait shows health, the wall sign shows the floor
	check(not ("condition_label" in HUD) and not ("floor_caption" in HUD) and not ("floor_total_label" in HUD) and not ("time_label" in HUD) and not ("run_pips" in HUD),
		"no condition word, no FLOOR / 30 / time-of-day text, no run pips")
	check(not HUD.floor_label.visible, "the floor numeral never shows")
	var wi: Rect2 = Rect2(HUD.wallet_icon.global_position, HUD.wallet_icon.size)
	check(wi.position.x > HUD.SCREEN_W * 0.8 and wi.position.y < 60.0, "the wallet + notes count sit top-right, where the floor text was (%s)" % str(wi))
	# the name row: NAME, then the MODE; the stamina bar is the row's UNDERLINE (and the gauge)
	var nr: Rect2 = Rect2(HUD.name_label.global_position, HUD.name_label.size)
	var mode_r: Rect2 = HUD.mode_label.get_global_rect()
	var sb: Rect2 = Rect2(HUD.stamina_bar.global_position, HUD.stamina_bar.size)
	check(mode_r.position.x >= nr.end.x - 6.0 and absf((mode_r.position.y + mode_r.size.y * 0.5) - (nr.position.y + nr.size.y * 0.5)) < 8.0,
		"the mode sits on the name's row, right after the name (%s → %s)" % [str(nr), str(mode_r)])
	check(HUD.mode_label.text in ["SCAVENGE", "COMBAT"], "…as plain words (%s), no brackets" % HUD.mode_label.text)
	check(sb.position.y >= nr.end.y - 2.0 and sb.position.y - nr.end.y < 12.0 and sb.size.y <= 6.0, "the stamina bar is a thin horizontal line right UNDER the name row")
	check(sb.position.x <= nr.position.x + 1.0 and sb.end.x >= mode_r.end.x - 4.0, "…spanning the name AND the mode, so it is their underline (%s)" % str(sb))
	var eb: Rect2 = Rect2(HUD.equip_box.global_position, HUD.equip_box.size)
	check(eb.position.x >= sb.end.x and eb.end.y <= HUD.SCREEN_H and eb.size.x > 56.0,
		"the in-hand BOX sits to the right of the name / mode / stamina block, bigger than a hotbar slot (%s)" % str(eb))
	check(not HUD.color_rect.visible, "the opaque bottom bar is GONE")
	check(not HUD.hotbar_visible and not HUD.hbox.visible and HUD.hotbar_rect().size == Vector2.ZERO,
		"and so is the hotbar (redundant with the wheels) — hidden by default")
	var pb: Rect2 = HUD.pack_button.get_global_rect()
	check(pb.position.x > HUD.SCREEN_W * 0.85 and pb.end.y <= HUD.SCREEN_H and pb.position.y > HUD.SCREEN_H * 0.7,
		"the backpack button is the bottom-right corner (%s)" % str(pb))
	check(HUD.inventory_drop_rect().has_point(pb.get_center()), "…and dropping a loot item on it takes it into the pack")
	# with no bar there is no "HUD band": only real widgets are HUD, the rest of the screen is the world
	check(not HUD.pointer_over_widget(Vector2(576, 620)) and not HUD.pointer_over_widget(Vector2(576, 330)) and not HUD.pointer_over_widget(Vector2(576, 40)),
		"the bottom (and top) of the screen is the WORLD, not HUD (a click there is a world click)")
	check(HUD.pointer_over_widget(pb.get_center()) and HUD.pointer_over_widget(mode_r.get_center()) and HUD.pointer_over_widget(pr.get_center()),
		"…while the pack, the mode toggle and the portrait still are")
	# the optional hotbar still works when turned on
	HUD.set_hotbar_visible(true)
	await get_tree().process_frame
	var r0: Rect2 = HUD.slots[0].get_global_rect()
	var r5: Rect2 = HUD.slots[5].get_global_rect()
	check(HUD.hbox.visible and HUD.pointer_over_widget(r0.get_center()) and absf(r0.position.x - (HUD.SCREEN_W - r5.end.x)) < 3.0 and r5.end.y <= 100.0,
		"(opt-in) the hotbar returns centred at the top, and is then a HUD widget")
	HUD.set_hotbar_visible(false)
	# hovering the mode explains the two modes
	check(not HUD.mode_tip.visible, "the mode tooltip is hidden until you hover")
	WorldState.is_scavenge_mode = true
	HUD.update_mode_indicator()
	var mc: Dictionary = HUD.mode_tip_content()
	check(mc["current"] == "scavenge" and "you are here" in mc["scavenge"]["head"] and not ("you are here" in mc["combat"]["head"]),
		"the tip marks the mode you are in (scavenge)")
	WorldState.is_scavenge_mode = false
	HUD.update_mode_indicator()
	mc = HUD.mode_tip_content()
	check(mc["current"] == "combat" and "you are here" in mc["combat"]["head"], "…and follows a switch to combat")
	check("sprint" in mc["scavenge"]["body"].to_lower() and "search" in mc["scavenge"]["body"].to_lower() and "swing" in mc["combat"]["body"].to_lower(),
		"it says what each mode is for (search / slow + quiet / no sprint; fight / sprint)")
	check(mc["hint"].contains(HUD.action_key_name("mode_toggle", "F")), "…and names the CURRENT switch key (%s)" % mc["hint"])
	HUD.mode_label.mouse_entered.emit()
	HUD._process(0.3)
	check(HUD.mode_tip.visible, "hovering the mode text shows the tooltip after a beat")
	var tr: Rect2 = HUD.mode_tip.get_global_rect()
	check(tr.end.y <= HUD.mode_label.get_global_rect().position.y + 1.0 and tr.position.x >= 0.0 and tr.end.x <= HUD.SCREEN_W and tr.position.y >= 0.0,
		"…above the text, on screen (%s)" % str(tr))
	HUD.mode_label.mouse_exited.emit()
	check(not HUD.mode_tip.visible, "…and it goes when the pointer leaves")
	# the stamina bar: one continuous bar off the same numbers
	var bar = HUD.stamina_bar
	check(bar.get_script().resource_path.ends_with("hud_stamina.gd"), "the stamina gauge is one continuous bar")
	check(bar.get_child_count() == 0, "…not a row of segments")
	HUD.update_stamina(100.0, 100.0)
	bar.shown = 1.0
	bar.tail = 1.0
	HUD.update_stamina(40.0, 100.0)
	check(is_equal_approx(bar.target, 0.4), "it reads the same stamina numbers (target %.2f)" % bar.target)
	bar._process(1.0 / 60.0)
	check(bar.shown > 0.4 and bar.tail > bar.shown, "spending: the fill hasn't snapped down — it eases (%.2f), and a tail trails behind (%.2f)" % [bar.shown, bar.tail])
	for i in range(60):
		bar._process(1.0 / 60.0)
	check(absf(bar.shown - 0.4) < 0.01, "…it drains smoothly to the true value (%.3f)" % bar.shown)
	check(absf(bar.tail - bar.shown) < 0.05, "…and the tail catches up after a beat (%.3f)" % bar.tail)
	HUD.update_stamina(90.0, 100.0)
	check(bar.is_recharging(), "recharging: the bar knows it is refilling")
	for i in range(90):
		bar._process(1.0 / 60.0)
	check(absf(bar.shown - 0.9) < 0.01 and not bar.is_recharging(), "…and it fills smoothly back up (%.3f)" % bar.shown)
	var Bar = preload("res://scripts/hud_stamina.gd")
	check(Bar.colour_for(0.8) == Bar.CALM and Bar.colour_for(0.5) == Bar.CALM, "plenty of stamina reads calm, not alarming")
	check(Bar.colour_for(0.2) != Bar.CALM and Bar.colour_for(0.02).r > Bar.colour_for(0.02).g, "…warming to red only as it runs low")
	HUD.update_stamina(3.0, 100.0)
	check(bar.is_spent(), "a spent player is flagged (the bar pulses)")
	# real time: a slowed game must not freeze it
	Engine.time_scale = 0.2
	var before: float = bar.shown
	for i in range(30):
		bar._process(1.0 / 60.0 * 0.2)
	Engine.time_scale = 1.0
	check(bar.shown < before, "it keeps flowing in the quick wheel's slow motion")
	HUD.update_stamina(WorldState.stamina, WorldState.get_max_stamina())


func _test_cluster() -> void:
	print("[corner cluster]")
	WorldState.new_game()
	await get_tree().process_frame
	HUD.update_portrait(0)
	HUD.update_floor_label()
	check(HUD.name_label != null and HUD.name_label.text == WorldState.character_display_name(WorldState.current_character()).to_upper(),
		"the character's name is shown (%s)" % HUD.name_label.text)
	var tex: Array = []
	for st in range(6):
		HUD.update_portrait(st)
		tex.append(HUD.portrait.texture)
	check(tex[0] != tex[5] and tex[0] != tex[3] and tex[3] != tex[5], "health reads from the portrait art alone — a different bust at every worse stage")
	HUD.update_portrait(0)
	check(HUD.portrait.mouse_filter == Control.MOUSE_FILTER_STOP, "the portrait is still the button")
	# nothing new may swallow a world click (click-to-move)
	var stoppers: Array = []
	for n in [HUD.name_label, HUD.floor_label, HUD.wallet_label, HUD.scrap_label, HUD.equip_box,
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
	check(HUD.scrap_icon.position.y > HUD.wallet_icon.position.y and is_equal_approx(HUD.scrap_icon.position.x, HUD.wallet_icon.position.x),
		"scrap sits on the row under the notes")
	WorldState.wallet_unlocked = false
	HUD.update_wallet()
	check(is_equal_approx(HUD.scrap_icon.position.y, HUD.wallet_icon.position.y), "…and takes the first row while the wallet is still locked")
	WorldState.wallet_unlocked = true
	HUD.update_wallet()
	# the in-hand line
	WorldState.inventory.clear()
	_give("002")
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	HUD._update_equipped_chip()
	var eq = HUD.equip_box
	check(not eq.has_item and eq.ammo_text == "" and eq.fraction < 0.0, "nothing selected = the bare box")
	HUD.select_slot(0)
	check(eq.has_item and eq.icon != null, "the selected item's ICON is in the box")
	check(eq.fraction > 0.99 and not eq.broken and eq.ammo_text == "", "a fresh hammer: full condition and NO numbers")
	var fresh: Color = eq.current_tint()
	WorldState.inventory[0].current_durability = int(WorldState.inventory[0].get_max_durability() / 2)
	HUD._update_equipped_chip()
	eq._drawn_frac = eq.fraction            # (the colour eases in real time — jump to the end for the check)
	var half: Color = eq.current_tint()
	check(absf(eq.fraction - 0.5) < 0.15, "half worn: fraction about half (%.2f)" % eq.fraction)
	check(eq.ammo_text == "", "…and still no numbers")
	check(fresh.g > fresh.r and half.r > half.b and half != fresh, "the body colour moved from green toward yellow/orange as it wore (%s → %s)" % [str(fresh), str(half)])
	WorldState.inventory[0].current_durability = 1
	HUD._update_equipped_chip()
	eq._drawn_frac = eq.fraction
	var low: Color = eq.current_tint()
	check(low.r > low.g * 2.0 and low.r < half.r, "nearly gone: a dark red (%s)" % str(low))
	WorldState.inventory[0].current_durability = 0
	WorldState.inventory[0].is_depleted = true
	HUD._update_equipped_chip()
	check(eq.broken and eq.fraction == 0.0 and eq.current_tint() == eq.BROKEN, "worn out = broken: the dull cracked look")
	# the colour is one continuous mapping: monotone toward red as condition falls, never jumping
	var prev: Color = eq.tint_for(1.0)
	var worst_jump := 0.0
	for i in range(99, -1, -1):
		var c: Color = eq.tint_for(float(i) / 100.0)
		worst_jump = maxf(worst_jump, absf(c.r - prev.r) + absf(c.g - prev.g) + absf(c.b - prev.b))
		prev = c
	check(worst_jump < 0.09, "the gradient is smooth (largest 1%% step %.3f)" % worst_jump)
	check(eq.tint_for(-1.0) == eq.NEUTRAL and eq.tint_for(0.5, false, false) == eq.GLASS, "no-wear = slate, nothing = dark glass")
	# the three shapes drive the shader's shape uniform
	for st in eq.STYLES:
		eq.set_style(st)
		check(int(eq._mat.get_shader_parameter("shape")) == eq.STYLES.find(st), "%s shape set on the shader" % st)
	eq.set_style("rounded")
	HUD.equip_box.clear_item()
	# a GUN carries its rounds — the only number the box ever shows
	WorldState.inventory.clear()
	_give("004")
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	HUD.select_slot(0)
	check(eq.ammo_text.contains("/"), "a gun shows its rounds (%s)" % eq.ammo_text)
	WorldState.inventory.clear()
	_give("002")
	HUD.refresh_inventory()
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
	check(w.centre.y <= HUD.SCREEN_H and w.centre.x >= 100.0, "the ring stays on screen")
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
