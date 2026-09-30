extends Node

# ITEM ICONS + the hover TOOLTIP (owner: "high quality images so players can recognise the item
# instantly, then click or hover over if they want more information").
#  * every item has a real icon: 56x56, cut out (transparent around it), many colours — not one of
#    the old white word-cards or red placeholder boxes;
#  * hovering an inventory slot shows the item's name, condition and description above the slot.
# Run:  godot --headless res://tests/item_icon_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== item icon + tooltip test ===")
	_test_icons()
	await _test_tooltip()
	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_icons() -> void:
	print("[every item has a real icon]")
	var bad: Array = []
	for id in ItemData.items:
		var tex: Texture2D = ItemData.get_texture(id)
		if tex == null:
			bad.append(id + " (none)")
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		if img.get_width() != 56 or img.get_height() != 56:
			bad.append("%s (%dx%d)" % [id, img.get_width(), img.get_height()])
			continue
		var colours := {}
		var clear := 0
		for y in range(0, 56, 2):
			for x in range(0, 56, 2):
				var c := img.get_pixel(x, y)
				if c.a < 0.05:
					clear += 1
				else:
					colours[c.to_html(false)] = true
		# a card was a solid white slab (no transparency, 2-3 colours); a placeholder a flat red box
		if clear < 200 or colours.size() < 10:
			bad.append("%s (placeholder? %d clear, %d colours)" % [id, clear, colours.size()])
	check(ItemData.items.size() >= 38 and bad.is_empty(), "%d items, every icon drawn art %s" % [ItemData.items.size(), str(bad)])
	check(ItemData.get_texture("036") != null, "the Fire Extinguisher (036) has an icon now")


func _test_tooltip() -> void:
	print("[hover a slot for the details]")
	WorldState.new_game()
	WorldState.inventory.clear()
	WorldState.add_to_inventory("002", 1)      # hammer
	WorldState.add_to_inventory("004", 1)      # gun
	WorldState.add_to_inventory("016", 5)      # bullets
	WorldState.add_to_inventory("006", 1)      # bandages
	WorldState.add_to_inventory("025", 1)      # old magazine (junk)
	HUD.refresh_inventory()
	var hammer = WorldState.get_instance_at(0)
	var c: Dictionary = HUD.item_tip_content(hammer)
	check(c["title"] == "Hammer" and "Durability" in "\n".join(c["stats"]) and c["desc"] != "",
		"a hammer: its name, durability and description (%s)" % str(c["stats"]))
	hammer.current_durability = 0
	hammer.is_depleted = true
	c = HUD.item_tip_content(hammer)
	check(c["broken"] and "BROKEN" in "\n".join(c["stats"]), "a broken hammer says so, and how to fix it")
	c = HUD.item_tip_content(WorldState.get_instance_at(1))
	check("Magazine" in "\n".join(c["stats"]), "the gun shows its magazine (%s)" % str(c["stats"]))
	c = HUD.item_tip_content(WorldState.get_instance_at(2))
	check("5 rounds" in "\n".join(c["stats"]), "bullets show the count (%s)" % str(c["stats"]))
	c = HUD.item_tip_content(WorldState.get_instance_at(3))
	check("Heals" in "\n".join(c["stats"]) and c["hint"] == "Double-click to use", "bandages: how much they heal + how to use them")
	c = HUD.item_tip_content(WorldState.get_instance_at(4))
	check("Junk" in c["hint"], "junk says it's junk")
	# the real hover: move the mouse over slot 1 and wait out the delay
	var slot: Control = HUD.slots[1]
	await get_tree().process_frame                   # the bar lays itself out a frame after a refresh
	HUD.tip_mouse_override = slot.get_global_rect().get_center()
	await get_tree().process_frame
	check(not HUD.item_tip.visible, "not straight away — a short delay, so sweeping across the bar doesn't flash tips")
	for i in range(30):
		await get_tree().process_frame
	check(HUD.item_tip.visible and HUD._tip_title.text == "Gun", "hovering slot 1 shows the gun's tooltip (\"%s\")" % HUD._tip_title.text)
	var r: Rect2 = HUD.item_tip.get_global_rect()
	check(HUD.item_tip.visible and r.end.y <= slot.get_global_rect().position.y and r.position.x >= 0.0 and r.end.x <= 1152.0,
		"…above the slot and on screen (%s)" % str(r))
	HUD.tip_mouse_override = Vector2(400, 200)
	for i in range(3):
		await get_tree().process_frame
	check(not HUD.item_tip.visible, "moving off the slot hides it")
	HUD.tip_mouse_override = null
	WorldState.inventory.clear()
	HUD.refresh_inventory()
