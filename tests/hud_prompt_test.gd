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
	var pa: Panel = HUD.world_prompt_panel(owner_a)
	chk(pa != null and pa.visible, "prompt is shown")
	var pos: Vector2 = pa.position
	var w: float = pa.size.x
	chk(pos.x >= 0.0 and pos.x + w <= HUD.SCREEN_W + 0.5, "clamped inside the right edge (x=%.0f w=%.0f)" % [pos.x, w])
	chk(pos.y >= 0.0 and pos.y + pa.size.y <= HUD.SCREEN_H + 0.5, "kept on screen (y=%.0f)" % pos.y)

	# An item far to the LEFT clamps to the left edge, never negative.
	HUD.show_world_prompt(owner_a, "Bandages   [Click] Take", Vector2(-5000, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).position.x >= 0.0, "clamped inside the left edge (x=%.0f)" % HUD.world_prompt_panel(owner_a).position.x)

	# Multiple owners show at once, each its own pill.
	HUD.show_world_prompt(owner_b, "2509 - [E] Enter", Vector2(600, 300))
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).visible and HUD.world_prompt_panel(owner_b).visible,
		"two owners show independent prompts at once")

	# Ownership: one node leaving range hides ONLY its own prompt.
	HUD.hide_world_prompt(owner_b)
	chk(HUD.world_prompt_panel(owner_a).visible, "one owner leaving does not hide another's prompt")
	chk(not HUD.world_prompt_panel(owner_b).visible, "the owner hides its own prompt")
	HUD.hide_world_prompt(owner_a)
	chk(not HUD.world_prompt_panel(owner_a).visible, "the other owner hides its own too")

	# Owner round 48i: "Overlap on items and text" - two pickups side by side (a Fire Extinguisher and Torn Clothes) drew their pills on top of each other, "Fir…" hidden
	# behind "Torn Clothes [Click] Take". Pills that would overlap stack instead, in a stable left-to-right order, all on screen; a lone pill stays where it was.
	var o3 := Node.new()
	var o4 := Node.new()
	add_child(o3)
	add_child(o4)
	HUD.show_world_prompt(owner_a, "Torn Clothes   [Click] Take", Vector2(600, 300))
	HUD._update_world_prompt()
	var lone: Vector2 = HUD.world_prompt_panel(owner_a).position
	HUD.show_world_prompt(owner_b, "Fire Extinguisher   [Click] Take", Vector2(590, 300))
	HUD.show_world_prompt(o3, "First Aid Kit   [Click] Take", Vector2(612, 301))
	HUD.show_world_prompt(o4, "2509 - [E] Enter", Vector2(600, 296))
	HUD._update_world_prompt()
	var pills: Array = [HUD.world_prompt_panel(owner_a), HUD.world_prompt_panel(owner_b), HUD.world_prompt_panel(o3), HUD.world_prompt_panel(o4)]
	var overlaps := 0
	var off_screen := 0
	for i in range(pills.size()):
		var ri := Rect2(pills[i].position, pills[i].size)
		if ri.position.x < 0.0 or ri.position.y < 0.0 or ri.end.x > HUD.SCREEN_W + 0.5 or ri.end.y > HUD.SCREEN_H + 0.5:
			off_screen += 1
		for j in range(i + 1, pills.size()):
			if ri.intersects(Rect2(pills[j].position, pills[j].size)):
				overlaps += 1
	chk(overlaps == 0, "four pickups / doors at nearly one spot: no two pills overlap (%d overlapping pairs)" % overlaps)
	chk(off_screen == 0, "...and every one stays on screen (%d off)" % off_screen)
	chk(HUD.world_prompt_panel(owner_b).position.x < HUD.world_prompt_panel(owner_a).position.x + 1.0 or HUD.world_prompt_panel(owner_b).position.y != HUD.world_prompt_panel(owner_a).position.y,
		"...and they are told apart (not stacked on the same rows)")
	HUD.hide_world_prompt(owner_b)
	HUD.hide_world_prompt(o3)
	HUD.hide_world_prompt(o4)
	HUD._update_world_prompt()
	chk(HUD.world_prompt_panel(owner_a).position.is_equal_approx(lone), "a pill on its own is where it always was (%s vs %s)" % [str(HUD.world_prompt_panel(owner_a).position), str(lone)])
	# near the top of the screen there is no room to stack upward: the stack goes below, still on screen
	HUD.show_world_prompt(owner_a, "Torn Clothes   [Click] Take", Vector2(600, 150))
	HUD.show_world_prompt(owner_b, "Fire Extinguisher   [Click] Take", Vector2(598, 150))
	HUD._update_world_prompt()
	var ta := Rect2(HUD.world_prompt_panel(owner_a).position, HUD.world_prompt_panel(owner_a).size)
	var tb := Rect2(HUD.world_prompt_panel(owner_b).position, HUD.world_prompt_panel(owner_b).size)
	chk(not ta.intersects(tb) and ta.position.y >= 0.0 and tb.position.y >= 0.0, "high on the screen: still separate and on screen (%s / %s)" % [str(ta), str(tb)])
	for o in [owner_a, owner_b, o3, o4]:
		HUD.hide_world_prompt(o)

	print("=== %s (%d failures) ===" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(1 if fails > 0 else 0)
