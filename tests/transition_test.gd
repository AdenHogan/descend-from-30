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
	var trans = get_node_or_null("/root/Transition")
	check(trans != null, "Transition is an autoload singleton")
	if trans == null:
		get_tree().quit(1)
		return
	check(trans.rect != null, "has a full-screen fade rect")
	check(trans.rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "fade rect never eats clicks")
	check(trans.layer >= 100, "renders above HUD / overlays")
	check(trans.process_mode == Node.PROCESS_MODE_ALWAYS, "runs while paused")
	check(trans.rect.color.a == 0.0, "starts fully transparent")

	trans.rect.visible = true
	await trans._fade(1.0, 0.05)
	check(absf(trans.rect.color.a - 1.0) < 0.02, "fades to opaque black")
	await trans._fade(0.0, 0.05)
	check(trans.rect.color.a < 0.02, "fades back to transparent")

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)
