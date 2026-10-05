extends Node

# THE CONTROL SCHEME (docs/CONTROLS.md): one table, four slots per action, keyboard + mouse, gamepad and touch.
#  * the table is sound: every action's defaults parse, no two actions share a button, the essentials can't be
#    left unbound, and EVERY action the game's scripts poll exists (a typo'd action name is a silent no-op);
#  * rebinding swaps (never doubles), refuses the impossible, saves only what changed, migrates the old file;
#  * the device in use is tracked, and prompts name ITS button ("[E]" / "[A]" / "[Cross]" / "[USE]");
#  * a pad press / stick really triggers the game's actions; Start pauses and B only ever closes; Esc always pauses;
#  * the on-screen touch controls press the same actions, hide + let go of everything when they should, and a tap
#    on one is never a click on the world;
#  * the wheel / LB / RB step through the bag; the pack ring is reachable from the right stick.
# Run:  godot --headless res://tests/controls_test.tscn

const Scheme := preload("res://scripts/input_scheme.gd")

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
	print("=== control scheme test ===")
	await get_tree().process_frame
	SettingsManager.reset_defaults()
	_test_table()
	_test_actions_exist_for_every_script()
	_test_rebind_rules()
	_test_save_and_migrate()
	_test_device_and_prompts()
	_test_pad_triggers_actions()
	await _test_pause_split()
	await _test_settings_menu()
	await _setup()
	await _test_touch_overlay()
	await _test_item_cycle()
	await _test_pad_pack_ring()
	await _test_click_still_moves()
	await _test_push_in_scavenge_says_why()
	_cleanup()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ------------------------------------------------------------------------------------------------ the table

func _test_table() -> void:
	print("[the table]")
	var ids: Array = Scheme.action_ids()
	check(ids.size() == Scheme.ACTIONS.size() and ids.size() >= 20, "%d actions" % ids.size())
	var bad: Array = []
	for a in Scheme.ACTIONS:
		for spec in a["kb"] + a["pad"]:
			if spec != "" and Scheme.spec_to_event(spec) == null:
				bad.append("%s %s" % [a["id"], spec])
		for s in a["kb"]:
			if s != "" and Scheme.family_of(s) != 0:
				bad.append("%s %s is not a keyboard/mouse binding" % [a["id"], s])
		for s in a["pad"]:
			if s != "" and Scheme.family_of(s) != 1:
				bad.append("%s %s is not a pad binding" % [a["id"], s])
	check(bad.is_empty(), "every default parses and sits in the right slot family %s" % str(bad))
	# no two actions share a button on the same kind of device
	var seen := {}
	var dup: Array = []
	for a in Scheme.ACTIONS:
		for spec in a["kb"] + a["pad"]:
			if spec == "":
				continue
			if seen.has(spec) and seen[spec] != a["id"]:
				dup.append("%s: %s / %s" % [spec, seen[spec], a["id"]])
			seen[spec] = a["id"]
	check(dup.is_empty(), "no button is bound to two actions %s" % str(dup))
	for id in Scheme.ESSENTIAL:
		var e: Dictionary = Scheme.entry(id)
		var kb := 0
		var pad := 0
		for s in e["kb"]:
			kb += 1 if s != "" else 0
		for s in e["pad"]:
			pad += 1 if s != "" else 0
		check(kb >= 1 and pad >= 1, "essential '%s' is playable on a keyboard AND a pad" % id)
	# round trip spec <-> event
	var rt_bad: Array = []
	for spec in ["k:E", "k:Shift", "k:Left", "m:1", "m:5", "j:0", "j:14", "a:4+", "a:0-", "k:Escape", "k:Space"]:
		if Scheme.event_to_spec(Scheme.spec_to_event(spec)) != spec:
			rt_bad.append(spec)
	check(rt_bad.is_empty(), "spec → event → spec round-trips %s" % str(rt_bad))
	check(Scheme.spec_to_event("zzz") == null and Scheme.spec_to_event("k:") == null and Scheme.spec_to_event("a:9") == null, "garbage specs are refused")
	# the InputMap really holds them
	check(InputMap.has_action("interact") and InputMap.action_get_events("interact").size() == 2, "interact = E + pad A in the InputMap")
	check(Scheme.pad_style_for("PS5 Controller") == "playstation" and Scheme.pad_style_for("Xbox 360 Controller") == "xbox"
		and Scheme.pad_style_for("Nintendo Switch Pro Controller") == "nintendo", "controller family is read from its name")
	check(Scheme.spec_label("j:0", "playstation") == "Cross" and Scheme.spec_label("j:0", "xbox") == "A"
		and Scheme.spec_label("a:5+", "xbox") == "RT" and Scheme.spec_label("m:1") == "Left-click", "labels per family")


## Every action name a script polls must exist — a typo'd or removed action is a SILENT no-op in Godot (an error in the log,
## no failure). Reads the real source.
func _test_actions_exist_for_every_script() -> void:
	print("[every polled action exists]")
	var re := RegEx.new()
	re.compile("(?:is_action(?:_just)?_(?:pressed|released)|get_action_strength|action_press|action_release|get_axis|get_vector)\\(\\s*\"([a-z_0-9]+)\"(?:\\s*,\\s*\"([a-z_0-9]+)\")?(?:\\s*,\\s*\"([a-z_0-9]+)\")?(?:\\s*,\\s*\"([a-z_0-9]+)\")?")
	var missing: Array = []
	var total := 0
	for dir in ["res://scripts", "res://tools"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string(dir + "/" + f)
			for m in re.search_all(src):
				for g in range(1, 5):
					var name: String = m.get_string(g)
					if name == "" or name == "ui_page_up" and false:
						continue
					total += 1
					if not InputMap.has_action(name):
						missing.append("%s: %s" % [f, name])
	check(total > 40, "scanned %d action references" % total)
	check(missing.is_empty(), "all of them exist in the InputMap %s" % str(missing))


# ------------------------------------------------------------------------------------------------ rebinding

func _test_rebind_rules() -> void:
	print("[rebinding]")
	SettingsManager.reset_defaults()
	# a button another action holds is SWAPPED
	var r: Dictionary = SettingsManager.rebind_slot("sprint", 0, "k:E")
	check(bool(r["ok"]) and r["swapped"] == ["interact"], "putting E on sprint swaps it out of interact")
	check(SettingsManager.slot_spec("sprint", 0) == "k:E" and SettingsManager.slot_spec("interact", 0) == "k:Shift",
		"…interact takes sprint's old key (%s)" % SettingsManager.slot_spec("interact", 0))
	check(InputMap.action_has_event("interact", Scheme.spec_to_event("k:Shift")), "…and the InputMap follows")
	# the other device family is untouched by a keyboard swap
	check(SettingsManager.slot_spec("interact", 2) == "j:0" and SettingsManager.slot_spec("sprint", 2) == "a:4+", "…pad bindings untouched")
	# wrong device refused
	r = SettingsManager.rebind_slot("sprint", 0, "j:3")
	check(not bool(r["ok"]) and r["reason"] == "wrong_device", "a pad button can't go in a keyboard slot")
	r = SettingsManager.rebind_slot("sprint", 2, "k:F")
	check(not bool(r["ok"]), "…nor a key in a pad slot")
	# the same button moved between slots of one action
	r = SettingsManager.rebind_slot("crouch_toggle", 1, "k:C")
	check(bool(r["ok"]) and SettingsManager.slot_spec("crouch_toggle", 0) == "" and SettingsManager.slot_spec("crouch_toggle", 1) == "k:C",
		"the same key moved to another slot of its own action leaves no duplicate")
	# essentials can't be emptied
	SettingsManager.reset_defaults()
	r = SettingsManager.clear_slot("attack", 0)
	check(bool(r["ok"]), "attack can lose one keyboard slot (it has Space)")
	r = SettingsManager.clear_slot("attack", 1)
	check(not bool(r["ok"]) and r["reason"] == "essential", "…but not its last one")
	r = SettingsManager.clear_slot("pause", 0)
	check(not bool(r["ok"]), "pause keeps a keyboard binding")
	r = SettingsManager.clear_slot("sprint", 0)
	check(bool(r["ok"]), "a non-essential action can be cleared")
	# swap into an empty slot
	SettingsManager.reset_defaults()
	r = SettingsManager.rebind_slot("listen", 1, "k:Q")
	check(bool(r["ok"]) and SettingsManager.slot_spec("item_use", 0) == "", "taking Q from item_use leaves it empty when listen's slot was empty")
	# legacy single-binding call
	SettingsManager.reset_defaults()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	SettingsManager.rebind("listen", ev)
	check(SettingsManager.slot_spec("listen", 0) == "k:G" and SettingsManager.slot_spec("listen", 2) == "j:13", "rebind(action, event) sets the keyboard side only")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_LEFT_SHOULDER
	SettingsManager.rebind("listen", jb)
	check(SettingsManager.slot_spec("listen", 2) == "j:9", "…a pad event sets the pad side")
	SettingsManager.reset_defaults()


func _test_save_and_migrate() -> void:
	print("[saving + the old file]")
	SettingsManager.reset_defaults()
	SettingsManager.rebind_slot("push", 1, "k:G")
	var cfg := ConfigFile.new()
	cfg.load(SettingsManager._save_path())
	check(cfg.has_section_key("binds2", "push") and not cfg.has_section_key("binds2", "attack"), "only a changed action is saved")
	SettingsManager.set_pad_style("playstation")
	SettingsManager.set_touch_mode("on")
	SettingsManager.reset_defaults_in_memory_for_test()
	SettingsManager.pad_style_setting = "auto"
	SettingsManager.touch_mode = "auto"
	SettingsManager._load()
	SettingsManager.apply()
	check(SettingsManager.slot_spec("push", 1) == "k:G" and SettingsManager.pad_style_setting == "playstation" and SettingsManager.touch_mode == "on",
		"bindings and options survive a reload")
	# a corrupt entry falls back to the default rather than breaking the action
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 2)
	bad.set_value("binds2", "push", PackedStringArray(["k:E", "zzz", "k:V", ""]))   # wrong family in a pad slot, nonsense
	bad.set_value("binds2", "nonsense_action", PackedStringArray(["k:E", "", "", ""]))
	bad.save(SettingsManager._save_path())
	SettingsManager.reset_defaults_in_memory_for_test()
	SettingsManager._load()
	check(SettingsManager.slot_spec("push", 1) == "k:V" or SettingsManager.slot_spec("push", 1) == "", "a nonsense slot doesn't load")
	check(SettingsManager.slot_spec("push", 2) == "j:1", "…it takes the default instead (%s)" % SettingsManager.slot_spec("push", 2))
	check(not SettingsManager.bindings.has("nonsense_action"), "an unknown action in the file is ignored")
	# v1 migration: a CHANGED binding is kept, an unchanged one takes the new default
	var old := ConfigFile.new()
	old.set_value("binds", "push", {"type": "key", "physical": KEY_Z, "key": 0})            # changed
	old.set_value("binds", "attack", {"type": "key", "physical": KEY_SPACE, "key": 0})        # the OLD default: never really changed
	old.set_value("binds", "listen", {"type": "mouse", "button": MOUSE_BUTTON_XBUTTON1})      # changed to a side button
	old.save(SettingsManager._save_path())
	SettingsManager.reset_defaults_in_memory_for_test()
	SettingsManager._load()
	SettingsManager.apply()
	check(SettingsManager.slot_spec("push", 0) == "k:Z" and SettingsManager.slot_spec("push", 1) == "", "v1 push=Z → first slot, second cleared")
	check(SettingsManager.slot_spec("attack", 0) == "m:1" and SettingsManager.slot_spec("attack", 1) == "k:Space", "v1 attack=Space was the old default → the new defaults")
	check(SettingsManager.slot_spec("listen", 0) == "m:8", "v1 mouse side button kept (%s)" % SettingsManager.slot_spec("listen", 0))
	var re := ConfigFile.new()
	re.load(SettingsManager._save_path())
	check(re.has_section("binds2") and not re.has_section("binds"), "…and the file is rewritten as v2")
	SettingsManager.reset_defaults()


# ------------------------------------------------------------------------------------------------ devices + prompts

func _test_device_and_prompts() -> void:
	print("[the device in use, and prompts that name its button]")
	SettingsManager.reset_defaults()
	SettingsManager.note_device("kbm")
	check(SettingsManager.action_text("interact") == "E" and SettingsManager.action_text("attack") == "Left-click"
		and SettingsManager.action_short("push") == "RMB", "keyboard: E / Left-click / RMB")
	check(SettingsManager.localize("[{interact}] Enter  [{listen}] Listen") == "[E] Enter  [R] Listen", "prompt text is localized: %s" % SettingsManager.localize("[{interact}] Enter"))
	var pad_ev := InputEventJoypadButton.new()
	pad_ev.button_index = JOY_BUTTON_A
	pad_ev.pressed = true
	SettingsManager._input(pad_ev)
	check(SettingsManager.last_device == "pad", "a pad button puts the game on the pad")
	check(SettingsManager.action_text("interact") == "A" and SettingsManager.action_text("attack") == "X", "pad: A / X (%s, %s)" % [SettingsManager.action_text("interact"), SettingsManager.action_text("attack")])
	check(SettingsManager.localize("[{interact}] Enter") == "[A] Enter", "…and the same line reads [A] Enter")
	SettingsManager.set_pad_style("playstation")
	check(SettingsManager.action_text("interact") == "Cross" and SettingsManager.localize("[{item_context}] Force") == "[D-pad Right] Force", "PlayStation labels")
	SettingsManager.set_pad_style("auto")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.1
	SettingsManager.note_device("kbm")
	SettingsManager._input(stick)
	check(SettingsManager.last_device == "kbm", "stick drift (below half) doesn't switch to the pad")
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = KEY_E
	key_ev.pressed = true
	SettingsManager.note_device("pad")
	SettingsManager._input(key_ev)
	check(SettingsManager.last_device == "kbm", "a key goes back to keyboard + mouse")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	SettingsManager._input(tap)
	check(SettingsManager.last_device == "touch", "a touch puts the game on touch")
	check(SettingsManager.action_text("interact") == "USE" and SettingsManager.localize("[{interact}] Enter") == "[USE] Enter", "touch: the on-screen button's name")
	check(SettingsManager.action_text("rest") != "" and SettingsManager.action_text("rest") != "(unbound)", "an action with no touch button falls back to its key")
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(1, 0)
	SettingsManager._input(mv)
	check(SettingsManager.last_device == "touch", "a 1px mouse jitter doesn't leave touch")
	mv.relative = Vector2(20, 5)
	SettingsManager._input(mv)
	check(SettingsManager.last_device == "kbm", "a real mouse move does")
	check(TutorialManager.key("attack") == "Left-click" and TutorialManager.key("push") == "Right-click", "tutorial lines name the current key (%s, %s)" % [TutorialManager.key("attack"), TutorialManager.key("push")])
	# any-press
	var k := InputEventKey.new()
	k.pressed = true
	var kr := InputEventKey.new()
	kr.pressed = true
	kr.echo = true
	var jb := InputEventJoypadButton.new()
	jb.pressed = true
	var jm := InputEventJoypadMotion.new()
	jm.axis_value = 1.0
	check(SettingsManager.is_any_press(k) and SettingsManager.is_any_press(jb) and not SettingsManager.is_any_press(kr) and not SettingsManager.is_any_press(jm),
		"'press any button': keys and pad buttons yes; key repeat and stick drift no")
	# wall text follows the device too
	var BT := preload("res://scripts/blood_text.gd")
	SettingsManager.note_device("kbm")
	check(BT.key_for("push") == "RMB" and BT.key_for("interact") == "E", "wall text names the keyboard key (%s)" % BT.key_for("push"))
	SettingsManager.note_device("pad")
	check(BT.key_for("push") == "B", "…and the pad button on a pad (%s)" % BT.key_for("push"))
	SettingsManager.note_device("kbm")


func _test_pad_triggers_actions() -> void:
	print("[a pad drives the game's actions]")
	var cases := {"interact": ["b", JOY_BUTTON_A], "push": ["b", JOY_BUTTON_B], "mode_toggle": ["b", JOY_BUTTON_Y], "attack": ["b", JOY_BUTTON_X],
		"open_pack": ["b", JOY_BUTTON_DPAD_UP], "item_use": ["b", JOY_BUTTON_DPAD_DOWN], "listen": ["b", JOY_BUTTON_DPAD_LEFT],
		"item_context": ["b", JOY_BUTTON_DPAD_RIGHT], "item_prev": ["b", JOY_BUTTON_LEFT_SHOULDER], "item_next": ["b", JOY_BUTTON_RIGHT_SHOULDER],
		"crouch_toggle": ["b", JOY_BUTTON_LEFT_STICK], "rest": ["b", JOY_BUTTON_RIGHT_STICK], "open_journal": ["b", JOY_BUTTON_BACK], "pause": ["b", JOY_BUTTON_START]}
	var wrong: Array = []
	for action in cases:
		var ev := InputEventJoypadButton.new()
		ev.button_index = cases[action][1]
		ev.pressed = true
		if not ev.is_action_pressed(action):
			wrong.append(action)
	check(wrong.is_empty(), "every pad button does what the layout says %s" % str(wrong))
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"sprint": [JOY_AXIS_TRIGGER_LEFT, 1.0], "attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0]}
	wrong = []
	for action in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		if not m.is_action_pressed(action):
			wrong.append(action)
	check(wrong.is_empty(), "the left stick walks, LT sprints, RT attacks %s" % str(wrong))
	var m2 := InputEventJoypadMotion.new()
	m2.axis = JOY_AXIS_LEFT_X
	m2.axis_value = -0.1
	check(not m2.is_action_pressed("move_left"), "a drifting stick (0.1) isn't walking")
	var ac := InputEventJoypadButton.new()
	ac.button_index = JOY_BUTTON_A
	ac.pressed = true
	check(ac.is_action_pressed("ui_accept") and not ac.is_action_pressed("pause"), "A also accepts in a menu")
	var bc := InputEventJoypadButton.new()
	bc.button_index = JOY_BUTTON_B
	bc.pressed = true
	check(bc.is_action_pressed("ui_cancel"), "B is Back in a menu")
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	check(rb.is_action_pressed("ui_page_down"), "RB turns the journal's pages")
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.physical_keycode = KEY_BACK
	back.pressed = true
	check(back.is_action_pressed("ui_cancel"), "the Android Back key is Back")


# ------------------------------------------------------------------------------------------------ pause / back / journal

func _press(action_ev: InputEvent) -> void:
	Game._input(action_ev)


func _pad_button(b: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev


func _test_pause_split() -> void:
	print("[Start pauses, B only closes, Esc always pauses, the journal key]")
	HUD.show_hud()
	get_tree().paused = false
	PauseMenu.toggle(false)
	var start := _pad_button(JOY_BUTTON_START)
	_press(start)
	check(PauseMenu.visible and get_tree().paused, "Start opens the pause menu")
	_press(start)
	check(not PauseMenu.visible and not get_tree().paused, "…and again closes it")
	_press(_pad_button(JOY_BUTTON_B))
	check(not PauseMenu.visible and not get_tree().paused, "B in play does NOT open the pause menu (it is push)")
	PauseMenu.toggle(true)
	_press(_pad_button(JOY_BUTTON_B))
	check(not PauseMenu.visible, "…but B backs out of the pause menu")
	# Esc always works, even with `pause` rebound away
	SettingsManager.rebind_slot("pause", 0, "k:F10")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_press(esc)
	check(PauseMenu.visible, "Esc still opens pause with 'pause' rebound to F10")
	_press(esc)
	check(not PauseMenu.visible, "…and closes it")
	var f10 := InputEventKey.new()
	f10.physical_keycode = KEY_F10
	f10.pressed = true
	_press(f10)
	check(PauseMenu.visible, "the rebound key pauses too")
	_press(f10)
	SettingsManager.reset_defaults()
	# the journal key
	var jk := InputEventKey.new()
	jk.physical_keycode = KEY_J
	jk.pressed = true
	var panel = HUD.character_panel
	check(panel != null, "the HUD has the journal")
	_press(jk)
	check(panel.visible and get_tree().paused, "J opens the journal")
	_press(jk)
	check(not panel.visible and not get_tree().paused, "…and J closes it")
	_press(_pad_button(JOY_BUTTON_BACK))
	check(panel.visible, "the pad's Back/View button opens it")
	panel._unhandled_input(_pad_button(JOY_BUTTON_RIGHT_SHOULDER))
	check(panel.tabs.current_tab == 1, "RB turns to the next bookmark (tab %d)" % panel.tabs.current_tab)
	panel._unhandled_input(_pad_button(JOY_BUTTON_LEFT_SHOULDER))
	check(panel.tabs.current_tab == 0, "LB back")
	_press(_pad_button(JOY_BUTTON_B))
	check(not panel.visible and not get_tree().paused, "B closes the journal")
	# typing in a text box is never a command
	var le := LineEdit.new()
	add_child(le)
	le.grab_focus()
	await get_tree().process_frame
	_press(jk)
	check(not panel.visible, "J typed into a text box doesn't open the journal")
	le.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	HUD.hide_hud()


# ------------------------------------------------------------------------------------------------ the settings screen

func _test_settings_menu() -> void:
	print("[the controls screen]")
	SettingsManager.reset_defaults()
	var sm: Node = preload("res://scripts/settings_menu.gd").new()
	add_child(sm)
	await get_tree().process_frame
	check(sm.bind_buttons.size() == Scheme.ACTIONS.size() * 4, "a button for every slot of every action (%d)" % sm.bind_buttons.size())
	check(sm.bind_buttons["interact:0"].text == "E" and sm.bind_buttons["interact:2"].text == "A" and sm.bind_buttons["attack:1"].text == "Space",
		"it shows the current bindings (%s / %s / %s)" % [sm.bind_buttons["interact:0"].text, sm.bind_buttons["interact:2"].text, sm.bind_buttons["attack:1"].text])
	# capture rules
	var k := InputEventKey.new()
	k.physical_keycode = KEY_H
	k.pressed = true
	check(sm.capture_spec(k, 0) == "k:H", "a key captures into a keyboard slot")
	check(sm.capture_spec(k, 2) == null, "…but not into a pad slot")
	var del := InputEventKey.new()
	del.physical_keycode = KEY_DELETE
	del.pressed = true
	check(sm.capture_spec(del, 2) == "", "Del clears (either kind of slot)")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	check(sm.capture_spec(esc, 0) == null, "Esc is not a binding")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_WHEEL_UP
	mb.pressed = true
	check(sm.capture_spec(mb, 1) == "m:4" and sm.capture_spec(mb, 3) == null, "the wheel binds in a keyboard slot only")
	var jb := _pad_button(JOY_BUTTON_X)
	check(sm.capture_spec(jb, 3) == "j:2" and sm.capture_spec(jb, 0) == null, "a pad button binds in a pad slot only")
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_TRIGGER_LEFT
	jm.axis_value = 0.9
	check(sm.capture_spec(jm, 2) == "a:4+", "a trigger binds")
	jm.axis_value = 0.2
	check(sm.capture_spec(jm, 2) == null, "…a light touch doesn't")
	# a full capture through the real flow: click the slot, press the key
	sm.open()
	sm._on_bind_pressed("rest", 0, sm.bind_buttons["rest:0"])
	check(sm.listening_action == "rest" and sm.bind_buttons["rest:0"].text.begins_with("press"), "clicking a slot starts listening")
	var kk := InputEventKey.new()
	kk.physical_keycode = KEY_Y
	kk.pressed = true
	sm._input(kk)
	check(SettingsManager.slot_spec("rest", 0) == "k:Y" and sm.bind_buttons["rest:0"].text == "Y" and sm.listening_action == "", "the key is bound and shown")
	# a conflict says what it swapped
	sm._on_bind_pressed("rest", 0, sm.bind_buttons["rest:0"])
	var k2 := InputEventKey.new()
	k2.physical_keycode = KEY_E
	k2.pressed = true
	sm._input(k2)
	check(sm.note_label.text.begins_with("Swapped with") and sm.note_label.text.contains("Interact"), "taking E from interact says so (%s)" % sm.note_label.text)
	check(sm.bind_buttons["interact:0"].text == "Y", "…and interact shows the key it was given (%s)" % sm.bind_buttons["interact:0"].text)
	# essentials
	sm._on_bind_pressed("interact", 2, sm.bind_buttons["interact:2"])
	sm._apply_capture("")
	check(SettingsManager.slot_spec("interact", 2) == "" or sm.note_label.text.contains("can't"), "clearing a non-last essential slot is allowed or explained")
	sm._on_bind_pressed("pause", 0, sm.bind_buttons["pause:0"])
	sm._apply_capture("")
	check(sm.note_label.text.contains("can't be left empty") and SettingsManager.slot_spec("pause", 0) == "k:Escape", "the last Esc/pause binding can't be cleared (%s)" % sm.note_label.text)
	# options
	sm.pad_style_pick.item_selected.emit(2)
	check(SettingsManager.pad_style_setting == "playstation", "the controller-buttons option applies")
	sm.touch_pick.item_selected.emit(1)
	check(SettingsManager.touch_mode == "on", "the touch option applies")
	sm._on_reset()
	check(SettingsManager.slot_spec("interact", 0) == "k:E" and SettingsManager.pad_style_setting == "auto" or SettingsManager.slot_spec("interact", 0) == "k:E",
		"Reset to Defaults restores the keys")
	SettingsManager.touch_mode = "auto"
	SettingsManager.pad_style_setting = "auto"
	sm.queue_free()
	await get_tree().process_frame
	# pad: opening the menu with a pad focuses a button so the stick can move
	SettingsManager.note_device("kbm")


# ------------------------------------------------------------------------------------------------ the live world

func _setup() -> void:
	WorldState.new_game()
	WorldState.current_floor = 15
	WorldState.spawn_source = "stair"
	WorldState.stair_direction = "down"
	HUD.show_hud()
	bf = load("res://scenes/building_floors.tscn").instantiate()
	add_child(bf)
	for i in range(40):
		await get_tree().physics_frame
	p = get_tree().get_first_node_in_group("player")
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()
	WorldState.inventory.clear()
	WorldState.god_mode = true            # nothing in a live-world check may end the run (a death changes scene)
	await get_tree().physics_frame


func _clear_the_dead() -> void:
	for z in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(z):
			z.queue_free()


func _cleanup() -> void:
	var ov = HUD.touch_overlay
	if ov != null:
		ov.release_all()
	SettingsManager.touch_mode = "auto"
	SettingsManager.reset_defaults()
	SettingsManager.note_device("kbm")
	HUD.hide_hud()
	get_tree().paused = false


## Input.parse_input_event is buffered until the frame flush: give it two frames.
func _flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _btn_pos(action: String) -> Vector2:
	for b in HUD.touch_overlay.BUTTONS:
		if b[0] == action:
			return b[2]
	return Vector2.ZERO


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = get_viewport().get_final_transform() * pos       # (a headless window isn't the content size)
	ev.pressed = pressed
	get_viewport().push_input(ev)


func _drag_to(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = get_viewport().get_final_transform() * pos
	get_viewport().push_input(ev)


## The big right-hand button follows the hand (owner round 36d): weapon → HIT / SHOOT / DRAW (attack), a usable item → its verb (item_use),
## empty hands → HIT in combat, nothing while scavenging; and tapping the in-hand box uses what is in hand.
func _test_primary_button(ov) -> void:
	var big = ov.get_node("Btn_attack")
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	WorldState.is_scavenge_mode = false
	ov.refresh()
	check(big.visible and big.label == "HIT", "bare-handed in combat: the big button is HIT (%s)" % big.label)
	WorldState.is_scavenge_mode = true
	ov.refresh()
	check(not big.visible, "bare-handed while scavenging: nothing to offer, so no button")
	# a first aid kit → HEAL, pressing item_use (not attack)
	var kit := ItemInstance.new()
	kit.setup("007")
	WorldState.inventory.append(kit)
	HUD.selected_slot = 0
	ov.refresh()
	check(big.visible and big.label == "HEAL" and ov._action_for(big) == "item_use", "a first aid kit in hand: the big button is HEAL on item_use (%s / %s)" % [big.label, ov._action_for(big)])
	var catcher := Node.new()
	catcher.set_script(load("res://tests/controls_catcher.gd"))
	add_child(catcher)
	catcher.action = "item_use"
	_touch(6, _btn_pos("attack"), true)
	await _flush()
	check(catcher.got, "…and a tap on it arrives as item_use, not attack")
	check(not Input.is_action_pressed("attack"), "…the attack action stays up")
	# the press is let go as the SAME action even if the hand changes mid-press
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	WorldState.is_scavenge_mode = false
	ov.refresh()
	_touch(6, _btn_pos("attack"), false)
	await _flush()
	check(not Input.is_action_pressed("item_use") and not Input.is_action_pressed("attack"), "…and lifting the finger lets go of what was pressed")
	catcher.queue_free()
	# a weapon → HIT in combat, DRAW while scavenging
	var club := ItemInstance.new()
	club.setup("012")
	WorldState.inventory.append(club)
	HUD.selected_slot = 0
	ov.refresh()
	check(big.label == "HIT" and ov._action_for(big) == "attack", "a club in hand in combat: HIT on attack")
	WorldState.is_scavenge_mode = true
	ov.refresh()
	check(big.visible and big.label == "DRAW" and ov._action_for(big) == "attack", "…and DRAW while scavenging (the attack key draws it)")
	WorldState.is_scavenge_mode = false
	# an extinguisher / a can name what they do
	var ext := ItemInstance.new()
	ext.setup("036")
	WorldState.inventory.clear()
	WorldState.inventory.append(ext)
	ov.refresh()
	check(big.label == "SPRAY" and ov._action_for(big) == "item_use", "an extinguisher: SPRAY")
	# a key is nothing you can use: combat falls back to HIT
	var key := ItemInstance.new()
	key.setup("022")
	WorldState.inventory.clear()
	WorldState.inventory.append(key)
	ov.refresh()
	check(big.label == "HIT" and ov._action_for(big) == "attack", "a key in hand isn't usable: back to HIT in combat")
	# strict beats: a beat waiting for item_use shows the BIG button (pulsing) when the hand has a usable item
	WorldState.inventory.clear()
	WorldState.inventory.append(kit)
	HUD.selected_slot = 0
	TutorialManager._awaiting = true
	TutorialManager._await_strict = true
	TutorialManager._await_action = "item_use"
	ov.refresh()
	check(big.visible and big.pulse, "a strict item_use beat pulses the big button")
	TutorialManager._awaiting = false
	TutorialManager._await_strict = false
	TutorialManager._await_action = ""
	# the IN-HAND BOX is the other way in: a tap uses what is in hand
	check(HUD.equip_box.mouse_filter == Control.MOUSE_FILTER_STOP and HUD.pointer_over_widget(HUD.equip_box.get_global_rect().get_center()),
		"the in-hand box takes taps, and a tap on it never also walks in the world")
	p.is_dead = false
	p.health_state = 3
	p.is_dying = false
	HUD.equip_box.tapped.emit()
	await get_tree().process_frame
	check(int(p.health_state) < 3, "tapping the in-hand box with a first aid kit heals (state %d)" % int(p.health_state))
	p.health_state = 0
	WorldState.inventory.clear()
	HUD.selected_slot = -1
	WorldState.is_scavenge_mode = false
	ov.refresh()


func _test_touch_overlay() -> void:
	print("[touch controls]")
	_clear_the_dead()
	# mid-corridor, clear of every stairwell and door (a held up / use press beside one would leave the floor — and the test)
	p.global_position.x = 640.0
	await get_tree().physics_frame
	var ov = HUD.touch_overlay
	check(ov != null and ov.widgets.size() == ov.BUTTONS.size() + 1, "the HUD owns the overlay: a stick and %d buttons" % ov.BUTTONS.size())
	SettingsManager.touch_mode = "auto"
	SettingsManager.note_device("kbm")
	ov.refresh()
	check(not ov.visible, "hidden while a keyboard + mouse is in use")
	check(not HUD.pointer_over_widget(ov.STICK_CENTRE), "…and it blocks no clicks")
	SettingsManager.note_device("touch")
	ov.refresh()
	check(ov.visible, "a touch brings it up")
	SettingsManager.note_device("kbm")
	SettingsManager.set_touch_mode("on")
	ov.refresh()
	check(ov.visible, "'Always on' keeps it up")
	SettingsManager.set_touch_mode("off")
	SettingsManager.note_device("touch")
	ov.refresh()
	check(not ov.visible, "'Off' keeps it away even on touch")
	SettingsManager.set_touch_mode("on")
	ov.refresh()
	check(HUD.pointer_over_widget(ov.STICK_CENTRE) and HUD.pointer_over_widget(_btn_pos("attack")), "the stick and the HIT button are HUD widgets")
	check(not HUD.pointer_over_widget(Vector2(576, 300)), "the middle of the screen is still the world's")
	# every button names a real action
	var bad: Array = []
	for b in ov.BUTTONS:
		if not InputMap.has_action(b[0]):
			bad.append(b[0])
	check(bad.is_empty(), "every button presses a real action %s" % str(bad))
	# the stick
	_touch(0, ov.STICK_CENTRE, true)
	_drag_to(0, ov.STICK_CENTRE + Vector2(80, 0))
	await _flush()
	check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"), "the stick pushed right walks right")
	check(Input.get_axis("move_left", "move_right") > 0.8, "…at nearly full strength (%.2f)" % Input.get_axis("move_left", "move_right"))
	_drag_to(0, ov.STICK_CENTRE + Vector2(30, 0))
	await _flush()
	var part: float = Input.get_axis("move_left", "move_right")
	check(part > 0.0 and part < 0.6, "a gentle push walks slower (%.2f)" % part)
	_drag_to(0, ov.STICK_CENTRE + Vector2(-80, -2))
	await _flush()
	check(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "…and left")
	_drag_to(0, ov.STICK_CENTRE + Vector2(0, -80))
	await _flush()
	check(Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_left"), "flicking it up is move_up")
	_touch(0, ov.STICK_CENTRE, false)
	await _flush()
	check(not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up"), "letting go stops everything")
	# buttons + multi-touch: hold the stick AND press HIT with the other thumb
	_touch(0, ov.STICK_CENTRE, true)
	_drag_to(0, ov.STICK_CENTRE + Vector2(80, 0))
	_touch(1, _btn_pos("attack"), true)
	await _flush()
	check(Input.is_action_pressed("attack") and Input.is_action_pressed("move_right"), "two thumbs: walking and hitting at once")
	_touch(1, _btn_pos("attack"), false)
	await _flush()
	check(not Input.is_action_pressed("attack") and Input.is_action_pressed("move_right"), "…letting go of HIT leaves the walk")
	# HOW HARD you push is how fast you go (owner round 36d): no RUN button — the rim is run
	check(ov.get_node_or_null("Btn_sprint") == null and ov.get_node_or_null("Btn_mode_toggle") == null and ov.get_node_or_null("Btn_item_use") == null,
		"no RUN, no second MODE switch, no tiny ITEM button on the overlay")
	check(Input.is_action_pressed("sprint") and ov.sprinting, "pushed out to the rim, the stick holds sprint")
	_drag_to(0, ov.STICK_CENTRE + Vector2(58, 0))
	await _flush()
	check(not Input.is_action_pressed("sprint") and not ov.sprinting and Input.get_axis("move_left", "move_right") > 0.6,
		"a firm but not full push is a fast WALK (%.2f), no sprint" % Input.get_axis("move_left", "move_right"))
	_drag_to(0, ov.STICK_CENTRE + Vector2(72, 0))
	await _flush()
	check(not Input.is_action_pressed("sprint"), "…it takes the rim to start the sprint (no accidental run at 88%)")
	_drag_to(0, ov.STICK_CENTRE + Vector2(80, 0))
	await _flush()
	check(Input.is_action_pressed("sprint"), "…and the rim does")
	_drag_to(0, ov.STICK_CENTRE + Vector2(68, 0))
	await _flush()
	check(Input.is_action_pressed("sprint"), "a thumb easing a little off the rim keeps running (hysteresis, no flicker)")
	_drag_to(0, ov.STICK_CENTRE + Vector2(30, 0))
	await _flush()
	check(not Input.is_action_pressed("sprint"), "easing right off ends it — walking costs no stamina")
	_drag_to(0, ov.STICK_CENTRE + Vector2(0, -80))
	await _flush()
	check(not Input.is_action_pressed("sprint"), "a vertical flick never sprints")
	_drag_to(0, ov.STICK_CENTRE + Vector2(80, 0))
	await _flush()
	check(Input.is_action_pressed("sprint"), "(running again, so the hide below has something to let go of)")
	# hiding lets go of everything
	SettingsManager.set_touch_mode("off")
	ov.refresh()
	await _flush()
	check(not Input.is_action_pressed("sprint") and not Input.is_action_pressed("move_right") and not ov.sprinting, "hiding the overlay releases every held action")
	# pausing too
	SettingsManager.set_touch_mode("on")
	ov.refresh()
	_touch(3, ov.STICK_CENTRE, true)
	_drag_to(3, ov.STICK_CENTRE + Vector2(80, 0))
	await _flush()
	check(Input.is_action_pressed("move_right"), "(walking again)")
	get_tree().paused = true
	ov.refresh()
	await _flush()
	check(not Input.is_action_pressed("move_right") and not ov.visible, "a pause lets go too and hides it")
	get_tree().paused = false
	ov.refresh()
	# a button reaches the game as a real event (an _input handler sees it, not only polling)
	var catcher := Node.new()
	catcher.set_script(load("res://tests/controls_catcher.gd"))
	add_child(catcher)
	catcher.action = "interact"
	TutorialManager.guard_interact()      # (the player stands in a real corridor: don't let this press also open a door)
	_touch(4, _btn_pos("interact"), true)
	await _flush()
	check(catcher.got, "a tap on USE arrives as an input EVENT for interact")
	_touch(4, _btn_pos("interact"), false)
	catcher.queue_free()
	await _flush()
	# --- owner round 36b: a quiet right hand, context buttons, and a teaching beat a phone can answer ---
	SettingsManager.set_touch_mode("on")
	ov.refresh()
	var always: Array = []
	for w in ov.widgets:
		if w.visible and w.kind == "button":
			always.append(w.action)
	check(always.size() <= 8, "at most 8 buttons on screen in plain play, stick aside (%d: %s)" % [always.size(), str(always)])
	check(not always.has("open_pack") and not always.has("item_context") and not always.has("listen") and not always.has("item_use")
			and not always.has("sprint") and not always.has("mode_toggle"),
		"the pack / force / listen buttons are NOT up until they'd do something; run + mode + item are not buttons at all %s" % str(always))
	for want in ["attack", "interact", "push"]:
		check(always.has(want), "the main hand has %s" % want)
	var hidden_force = ov.get_node("Btn_item_context")
	check(not hidden_force.visible and ov.widget_at(hidden_force.centre) == null and not HUD.pointer_over_widget(hidden_force.centre),
		"a hidden button can't be tapped and doesn't block world clicks")
	HUD.show_world_prompt(self, "2805 - Locked  [%s] Force lock  [%s] Listen" % [SettingsManager.action_text("item_context"), SettingsManager.action_text("listen")], Vector2(600, 300))
	ov.refresh()
	check(ov.get_node("Btn_item_context").visible and ov.get_node("Btn_listen").visible, "FORCE + LISTEN appear when a door prompt offers them")
	HUD.hide_world_prompt(self)
	ov.refresh()
	check(not ov.get_node("Btn_item_context").visible, "…and go again with the prompt")
	await _test_primary_button(ov)
	# a paused strict teaching beat: ONLY the push button, pulsing, and pressing it carries on
	var beat_done := [false]
	TutorialManager.prompt("test beat", "push", func(): beat_done[0] = true, "[PUSH] to shove", true)
	await get_tree().process_frame
	check(get_tree().paused and TutorialManager.strict_action() == "push", "the shove beat pauses the game and waits for push")
	ov.refresh()
	check(ov.visible, "the touch overlay STAYS UP through the pause (it vanished, which locked a phone player on the beat)")
	var vis: Array = []
	for w in ov.widgets:
		if w.visible:
			vis.append(w.name)
	check(vis.size() == 1 and str(vis[0]) == "Btn_push" and ov.get_node("Btn_push").pulse, "…showing only a pulsing PUSH button %s" % str(vis))
	_touch(5, _btn_pos("push"), true)
	await _flush()
	_touch(5, _btn_pos("push"), false)
	await _flush()
	check(beat_done[0] and not get_tree().paused, "tapping it answers the beat and the game resumes")
	ov.refresh()
	check(ov.get_node("Btn_attack").visible and not ov.get_node("Btn_push").pulse, "…and the full overlay is back")
	# a loose beat ("press any key") needs no button: a tap anywhere continues (the emulated click)
	var loose_done := [false]
	TutorialManager.prompt("loose", "interact", func(): loose_done[0] = true, "[continue]", false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click)
	await get_tree().process_frame
	check(loose_done[0] and not get_tree().paused, "a loose beat continues on any tap")
	ov.release_all()
	for i in range(60):                    # (let the shove the beat button threw finish — a pack won't open mid-shove)
		await get_tree().physics_frame

	# a tap in the world is not on any button
	check(ov.widget_at(Vector2(576, 300)) == null, "a tap in the world hits no button")
	ov.release_all()
	SettingsManager.set_touch_mode("auto")
	SettingsManager.note_device("kbm")
	ov.refresh()


func _test_item_cycle() -> void:
	print("[the wheel and LB / RB step through the bag]")
	_clear_the_dead()
	for id in ["002", "005", "006"]:
		var inst := ItemInstance.new()
		inst.setup(id)
		WorldState.inventory.append(inst)
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	HUD.cycle_item(1)
	check(HUD.selected_slot == 0, "next from empty hands = the first item")
	HUD.cycle_item(1)
	HUD.cycle_item(1)
	check(HUD.selected_slot == 2, "…through the bag")
	HUD.cycle_item(1)
	check(HUD.selected_slot == -1, "…past the last = hands empty again")
	HUD.cycle_item(-1)
	check(HUD.selected_slot == 2, "previous from empty hands = the last item")
	HUD.cycle_item(-1)
	check(HUD.selected_slot == 1, "…and back")
	# through the real input path: the wheel reaches the player's handler
	HUD.selected_slot = -1
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_DOWN
	w.pressed = true
	get_viewport().push_input(w)
	await get_tree().process_frame
	check(HUD.selected_slot == 0, "the mouse wheel cycles items (slot %d)" % HUD.selected_slot)
	var rb := _pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	get_viewport().push_input(rb)
	await get_tree().process_frame
	check(HUD.selected_slot == 1, "RB does too (slot %d)" % HUD.selected_slot)
	var lb := _pad_button(JOY_BUTTON_LEFT_SHOULDER)
	get_viewport().push_input(lb)
	await get_tree().process_frame
	check(HUD.selected_slot == 0, "LB goes back (slot %d)" % HUD.selected_slot)
	HUD.selected_slot = -1
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	HUD.cycle_item(1)
	check(HUD.selected_slot == -1, "an empty bag does nothing (no crash)")


func _test_pad_pack_ring() -> void:
	print("[the pack ring from a pad]")
	_clear_the_dead()
	WorldState.has_backpack = true
	for id in ["002", "005", "006"]:
		var inst := ItemInstance.new()
		inst.setup(id)
		WorldState.inventory.append(inst)
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	SettingsManager.note_device("pad")
	var pw = HUD.pack_wheel
	check(pw.toggle(), "the pad's D-pad up kneels to the pack")
	for i in range(int(ceil(p.PACK_KNEEL_TIME * 60.0)) + 8):
		await get_tree().physics_frame
	await get_tree().process_frame
	check(p.pack_phase == "open" and pw.is_open, "ring open")
	# point the right stick at slot 1 (its wedge's direction)
	var dir: Vector2 = (pw.RingGeo.slot_position(pw.centre, 1, pw.slots.size(), pw.RING_R) - pw.centre).normalized()
	pw.pad_override = dir
	await get_tree().process_frame
	await get_tree().process_frame
	check(pw.hover == 1, "the right stick points at a wedge (hover %d)" % pw.hover)
	pw.pad_override = Vector2.ZERO
	await get_tree().process_frame
	check(pw.hover == 1, "…and it STAYS chosen when the stick returns to the middle")
	check(pw.pad_selecting() and p._pad_is_choosing_in_pack(), "so A won't stand the player up")
	var a := _pad_button(JOY_BUTTON_A)
	TutorialManager.guard_interact()
	get_viewport().push_input(a)
	await get_tree().process_frame
	check(HUD.selected_slot == 1, "A equips it (slot %d)" % HUD.selected_slot)
	check(p.pack_phase == "open", "…and the pack is still open")
	# X opens the item's menu; the stick steps the rows; A runs one
	var x := _pad_button(JOY_BUTTON_X)
	get_viewport().push_input(x)
	await get_tree().process_frame
	check(pw.menu_k == 1 and pw.menu_rows.size() >= 2, "X opens the item's menu (%d rows)" % pw.menu_rows.size())
	pw.pad_override = Vector2(0, 1)
	await get_tree().process_frame
	check(pw.pad_row == 1, "the stick down moves to the next row (%d)" % pw.pad_row)
	pw.pad_override = Vector2.ZERO
	await get_tree().process_frame
	pw.pad_override = Vector2(0, 1)
	await get_tree().process_frame
	pw.pad_override = Vector2.ZERO
	var inv_before: int = WorldState.inventory.size()
	pw.pad_row = pw.menu_rows.size() - 1                # "Drop" is last
	TutorialManager.guard_interact()
	get_viewport().push_input(_pad_button(JOY_BUTTON_A))
	await get_tree().process_frame
	check(pw.menu_k < 0 and WorldState.inventory.size() == inv_before - 1, "A on 'Drop' drops it (%d → %d)" % [inv_before, WorldState.inventory.size()])
	# B closes the pack
	get_viewport().push_input(_pad_button(JOY_BUTTON_B))
	await get_tree().process_frame
	check(p.pack_phase == "stand" or p.pack_phase == "", "B puts the pack away")
	for i in range(60):
		await get_tree().physics_frame
	pw.pad_override = null
	WorldState.inventory.clear()
	HUD.refresh_inventory()
	HUD.selected_slot = -1
	SettingsManager.note_device("kbm")


func _test_click_still_moves() -> void:
	print("[left-click is attack AND click-to-move]")
	_clear_the_dead()
	check(InputMap.action_has_event("attack", Scheme.spec_to_event("m:1")), "attack is on the left mouse button by default")
	WorldState.is_scavenge_mode = false
	HUD.selected_slot = -1
	p.global_position.x = 600.0
	for i in range(20):
		await get_tree().physics_frame
	var x0: float = p.global_position.x
	var cam: Camera2D = p.get_node("Camera2D")
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var screen: Vector2 = (Vector2(x0 + 150.0, p.global_position.y) - cam.get_screen_center_position()) * cam.zoom + vs / 2.0
	p._clear_move_target()
	var mv := InputEventMouseMotion.new()
	mv.position = screen
	get_viewport().push_input(mv)
	var dn := InputEventMouseButton.new()
	dn.button_index = MOUSE_BUTTON_LEFT
	dn.pressed = true
	dn.position = screen
	get_viewport().push_input(dn)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	get_viewport().push_input(up)
	# (push_input is synchronous: look before physics can arrive and clear the target)
	# (headless has no real pointer, so WHERE it walks isn't checked here — click_move_test covers that it reaches the player)
	check(p.has_move_target and not p.is_attacking and not p.is_pushing,
		"a left-click on empty floor in combat (attack IS on the left button) still sets a walk target and doesn't swing")


func _test_push_in_scavenge_says_why() -> void:
	print("[push while scavenging says why instead of doing nothing]")
	_clear_the_dead()
	WorldState.is_scavenge_mode = true
	HUD.feedback_label.text = ""
	var ev := InputEventAction.new()
	ev.action = "push"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in range(4):
		await get_tree().physics_frame
	check(HUD.feedback_label.text.to_lower().contains("shove") and HUD.feedback_label.text.contains("["),
		"scavenge mode + push → \"%s\"" % HUD.feedback_label.text)
	var up := InputEventAction.new()
	up.action = "push"
	up.pressed = false
	Input.parse_input_event(up)
	await _flush()
	WorldState.is_scavenge_mode = false
