extends Node

# Headless test for the rebind/settings system (four slots per action; docs/CONTROLS.md).
# Run:  godot --headless res://tests/settings_test.tscn

const Scheme := preload("res://scripts/input_scheme.gd")

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== settings / rebind test ===")
	SettingsManager.reset_defaults()
	_test_attack_action()
	_test_rebind_key()
	_test_rebind_mouse()
	_test_reset()
	_test_labels()
	_test_pause_settings_lifecycle()
	SettingsManager.reset_defaults()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_attack_action() -> void:
	print("[attack action]")
	check(InputMap.has_action("attack"), "attack action exists")
	var evs = InputMap.action_get_events("attack")
	var has_mouse := false
	var has_key := false
	var has_pad := false
	for e in evs:
		has_mouse = has_mouse or e is InputEventMouseButton
		has_key = has_key or e is InputEventKey
		has_pad = has_pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
	check(has_mouse and has_key and has_pad, "attack defaults to the mouse button, Space AND the pad (X / RT)")


func _test_rebind_key() -> void:
	print("[rebind key]")
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_Z
	SettingsManager.rebind("push", ev)
	var keys := 0
	for e in InputMap.action_get_events("push"):
		if e is InputEventKey:
			keys += 1
	check(keys == 1, "push now has exactly one keyboard binding")
	check(SettingsManager.binding_label("push") == "Z", "label reads Z (%s)" % SettingsManager.binding_label("push"))
	check(SettingsManager.slot_spec("push", 2) == "j:1", "…and its pad button (B) is untouched")


func _test_rebind_mouse() -> void:
	print("[rebind mouse]")
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_XBUTTON2
	SettingsManager.rebind("attack", ev)
	check(SettingsManager.binding_label("attack") == "Mouse 5", "attack bound to mouse side button (%s)" % SettingsManager.binding_label("attack"))
	# Persistence round-trip.
	SettingsManager._save()
	SettingsManager.reset_defaults_in_memory_for_test()
	check(SettingsManager.binding_label("attack") == "Left-click", "…memory reset to the default")
	SettingsManager._load()
	SettingsManager.apply()
	check(SettingsManager.binding_label("attack") == "Mouse 5", "saved mouse bind restored on load")
	check(SettingsManager.slot_spec("push", 0) == "k:Z", "…and the earlier key rebind too")


func _test_reset() -> void:
	print("[reset]")
	SettingsManager.reset_defaults()
	check(SettingsManager.binding_label("push") != "Z", "reset restores default push bind")
	check(InputMap.has_action("attack"), "attack survives reset")
	check(not FileAccess.file_exists(SettingsManager._save_path()), "reset removes the saved file")


func _test_labels() -> void:
	print("[labels]")
	check(SettingsManager.REMAPPABLE.size() >= 20, "a full set of actions is remappable (%d)" % SettingsManager.REMAPPABLE.size())
	var keyev = InputEventKey.new()
	keyev.physical_keycode = KEY_R
	check(SettingsManager.event_label(keyev) == "R", "key label works")


func _test_pause_settings_lifecycle() -> void:
	print("[pause/settings lifecycle]")
	var pm = get_node_or_null("/root/PauseMenu")
	check(pm != null and pm.settings_menu != null, "pause menu owns the settings menu")
	if pm == null:
		return
	# Open pause, then settings; Esc from settings must return to the pause
	# menu (settings hidden) WITHOUT resuming — not leave settings floating.
	pm.toggle(true)
	pm.settings_menu.open()
	check(pm.settings_menu.visible, "settings menu opens")
	pm.handle_cancel()
	check(not pm.settings_menu.visible, "Esc from settings closes it")
	check(pm.visible, "...and stays on the pause menu (not resumed)")
	# Esc again resumes and force-closes settings for good measure.
	pm.handle_cancel()
	check(not pm.visible, "Esc from pause menu resumes")
	pm.toggle(true)
	pm.settings_menu.open()
	pm.toggle(false)
	check(not pm.settings_menu.visible, "resume also hides a stray settings menu")
	get_tree().paused = false
