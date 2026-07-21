extends Node

# Headless test for the rebind/settings system.
# Run:  godot --headless res://tests/settings_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== settings / rebind test ===")
	_test_attack_action()
	_test_rebind_key()
	_test_rebind_mouse()
	_test_reset()
	_test_labels()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_attack_action() -> void:
	print("[attack action]")
	check(InputMap.has_action("attack"), "attack action was created")
	var evs = InputMap.action_get_events("attack")
	check(evs.size() > 0 and evs[0] is InputEventMouseButton, "attack defaults to a mouse button")


func _test_rebind_key() -> void:
	print("[rebind key]")
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_Q
	SettingsManager.rebind("push", ev)
	var got = InputMap.action_get_events("push")
	check(got.size() == 1 and got[0] is InputEventKey, "push now bound to one key")
	check(SettingsManager.binding_label("push") == "Q", "label reads Q")


func _test_rebind_mouse() -> void:
	print("[rebind mouse]")
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_XBUTTON2
	SettingsManager.rebind("attack", ev)
	check(SettingsManager.binding_label("attack") == "Mouse 5 (side)", "attack bound to mouse side button")
	# Persistence round-trip.
	SettingsManager._save()
	var ev2 = InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_erase_events("attack")
	InputMap.action_add_event("attack", ev2)
	SettingsManager._load()
	check(SettingsManager.binding_label("attack") == "Mouse 5 (side)", "saved mouse bind restored on load")


func _test_reset() -> void:
	print("[reset]")
	SettingsManager.reset_defaults()
	check(SettingsManager.binding_label("push") != "Q", "reset restores default push bind")
	check(InputMap.has_action("attack"), "attack survives reset")


func _test_labels() -> void:
	print("[labels]")
	check(SettingsManager.REMAPPABLE.size() >= 15, "a full set of actions is remappable")
	var keyev = InputEventKey.new()
	keyev.physical_keycode = KEY_R
	check(SettingsManager.event_label(keyev) == "R", "key label works")
