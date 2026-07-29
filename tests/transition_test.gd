extends Node

# Headless test for the scene-fade autoload (transition.gd). Exercises the
# fade animation + guarantees the overlay can never eat clicks. Does NOT call
# to_scene() (that would change the harness's own scene).
# Run:  godot --headless res://tests/transition_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== scene transition test ===")
	var tr = get_node_or_null("/root/Transition")
	check(tr != null, "Transition is an autoload singleton")
	if tr == null:
		get_tree().quit(1)
		return
	check(tr.rect != null, "has a full-screen fade rect")
	check(tr.rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade rect never eats clicks")
	check(tr.layer >= 100, "renders above HUD / overlays")
	check(tr.process_mode == Node.PROCESS_MODE_ALWAYS, "runs while paused")
	check(tr.rect.color.a == 0.0, "starts fully transparent")

	tr.rect.visible = true
	await tr._fade(1.0, 0.05)
	check(absf(tr.rect.color.a - 1.0) < 0.02, "fades to opaque black")
	await tr._fade(0.0, 0.05)
	check(tr.rect.color.a < 0.02, "fades back to transparent")

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)
