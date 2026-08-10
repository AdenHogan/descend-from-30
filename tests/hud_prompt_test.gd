extends Node

# The world-anchored loot prompt (HUD.show_world_prompt) is a SCREEN-space label
# that tracks an item's projected position but stays crisp and IN BOUNDS — the
# world-space label it replaced blew up huge/blurry and spilled past the walls.
# Headless can't see crispness, but it CAN prove the two things that matter:
#   (1) the projected label is clamped fully on-screen and above the HUD bar,
#   (2) one owner leaving range can't wipe another owner's prompt.
# Run:  godot --headless res://tests/hud_prompt_test.tscn

var fails := 0

func chk(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  ") + m)
	if not c:
		fails += 1


func _ready() -> void:
	print("=== HUD world prompt ===")
	var cam := Camera2D.new()
	cam.zoom = Vector2(3.3, 3.3)
	cam.position = Vector2(600, 300)
	add_child(cam)
	cam.make_current()
	var owner_a := Node.new()
	var owner_b := Node.new()
	add_child(owner_a)
	add_child(owner_b)
	await get_tree().process_frame

	# An item far off to the right must still land fully on-screen.
	HUD.show_world_prompt(owner_a, "First Aid Kit   [Click] Take", Vector2(5000, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_label.visible, "prompt is shown")
	var pos: Vector2 = HUD.world_prompt_label.position
	var w: float = HUD.world_prompt_label.size.x
	chk(pos.x >= 0.0 and pos.x + w <= HUD.SCREEN_W + 0.5, "clamped inside the right edge (x=%.0f w=%.0f)" % [pos.x, w])
	chk(pos.y >= 0.0 and pos.y <= HUD.SCREEN_H - HUD.BAR_H, "kept above the HUD bar (y=%.0f)" % pos.y)

	# An item far to the LEFT clamps to the left edge, never negative.
	HUD.show_world_prompt(owner_a, "Bandages   [Click] Take", Vector2(-5000, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_label.position.x >= 0.0, "clamped inside the left edge (x=%.0f)" % HUD.world_prompt_label.position.x)

	# Ownership: a different node leaving range must NOT hide the active prompt.
	HUD.hide_world_prompt(owner_b)
	chk(HUD.world_prompt_label.visible, "a non-owner cannot hide the prompt")
	HUD.hide_world_prompt(owner_a)
	chk(not HUD.world_prompt_label.visible, "the owner hides its own prompt")

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
