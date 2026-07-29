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

	# The stair pan hands over to a real floor with no fade — a black blink would
	# undo the whole point of panning — so it cross-fades under a still frame of
	# the outgoing one instead.
	check(tr.has_method("cross_fade_scene"), "offers a cross-fade for the stair handover")
	check(tr.CROSS_FADE > 0.0, "cross-fade has a real duration (%.2fs)" % tr.CROSS_FADE)
	# Headless has no framebuffer to read; it must degrade to a plain swap rather
	# than hang waiting on a frame that never draws.
	check(await tr._snapshot() == null, "headless: no snapshot, no hang")
	check(not tr.busy, "a skipped snapshot releases the guard")

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)
