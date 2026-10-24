extends Node

# WHICH WEAPON IS BETTER, AT A GLANCE (owner round 48i). ItemCompare reads the numbers combat uses, sets a weapon beside the one in hand (like with like), and says it in a card
# (the loot panel), a line (the floor pill) and rows (the pack ring's middle).

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		failures += 1


func _weapon(id: String, level: int = 1, uses: int = -1):
	var inst := ItemInstance.new()
	inst.setup(id)
	inst.level = level
	if level >= WeaponUpgrades.REINFORCE_LEVEL:
		var auto: String = WeaponUpgrades.auto_perk(id, WeaponUpgrades.REINFORCE_LEVEL)
		if auto != "":
			var base_max: int = inst.get_max_durability()
			inst.perks.append(auto)
			WorldState._apply_durability_headroom(inst, base_max)      # the bench adds the new headroom to what is left (a real upgrade does the same)
	if uses >= 0:
		inst.current_durability = uses
	return inst


func _row(c: Dictionary, label: String) -> Dictionary:
	for r in c["rows"]:
		if r["label"] == label:
			return r
	return {}


func _ready() -> void:
	WorldState.new_game()
	print("[the weapon kinds agree with the player's own]")
	var P = AllyCombat.player_script()
	var pl = P.new()
	var weapons := 0
	for id in ItemData.items:
		var d: Dictionary = ItemData.get_item(id)
		if not d.get("is_weapon", false):
			check(ItemCompare.weapon_kind(d) == "", "%s is not a weapon: no kind" % str(d.get("name", id)))
			continue
		weapons += 1
		check(ItemCompare.weapon_kind(d) == pl._get_weapon_type(d), "%s: %s agrees with player.gd (%s)" % [str(d.get("name", id)), ItemCompare.weapon_kind(d), pl._get_weapon_type(d)])
	check(weapons >= 6, "the catalogue has weapons to compare (%d)" % weapons)
	pl.free()

	print("[a bat against a knife]")
	var knife = _weapon("001")
	var bat = _weapon("014")
	var c: Dictionary = ItemCompare.card(bat, knife)
	check(not c.is_empty() and c["vs"] == knife.get_display_name(), "the card says what it is set against (%s)" % str(c.get("vs", "")))
	var dmg: Dictionary = _row(c, "Damage")
	check(dmg["text"] == "3" and dmg["tone"] == 1 and "+2" in dmg["delta"], "damage: a bat hits for 3, two more than the knife (%s %s)" % [dmg["text"], dmg["delta"]])
	var reach: Dictionary = _row(c, "Reach")
	check(reach["tone"] == 1 and "▲" in reach["delta"], "reach: longer (%s)" % reach["delta"])
	var spd: Dictionary = _row(c, "Speed")
	check(spd["tone"] == -1 and "▼" in spd["delta"], "speed: slower - the card does not only flatter (%s)" % spd["delta"])
	var stam: Dictionary = _row(c, "Stamina")
	check(stam["tone"] == -1, "stamina: dearer is WORSE, so a bigger number is red (%s)" % stam["delta"])
	var dur: Dictionary = _row(c, "Durability")
	check(dur["text"] == "8 / 8" and dur["tone"] == 1, "durability: 8 / 8 against the knife's 7 (%s)" % dur["delta"])

	print("[the same weapon, worn]")
	var worn = _weapon("014", 1, 3)
	var c2: Dictionary = ItemCompare.card(worn, bat)
	var d2: Dictionary = _row(c2, "Durability")
	check(d2["text"] == "3 / 8" and d2["tone"] == -1 and "-5" in d2["delta"], "3 of 8 left against a fresh bat: worse by 5 (%s)" % d2["delta"])
	check(_row(c2, "Damage")["tone"] == 0 and _row(c2, "Damage")["delta"] == "", "…and nothing else differs, so nothing else is flagged")
	var broken = _weapon("014")
	broken.is_depleted = true
	broken.current_durability = 0
	check(_row(ItemCompare.card(broken, bat), "Durability")["text"] == "BROKEN", "a broken weapon says BROKEN")

	print("[workbench levels count]")
	var knife2 = _weapon("001", 2)
	var c3: Dictionary = ItemCompare.card(knife2, knife)
	check(_row(c3, "Damage")["tone"] == 1 and _row(c3, "Damage")["text"] == "2", "a Reinforced knife hits for 2: the first bench step shows on the card (%s)" % _row(c3, "Damage")["text"])
	check(_row(c3, "Durability")["text"] == "11 / 11", "…and lasts half as long again, 7 -> 11 (%s)" % _row(c3, "Durability")["text"])

	print("[only like against like]")
	var gun = _weapon("004")
	var c4: Dictionary = ItemCompare.card(gun, knife)
	check(c4["vs"] == "" and ItemCompare.pill_suffix(c4) == "", "a gun is not set against a knife (no comparison, no pill suffix)")
	check(not _row(c4, "Close hit").is_empty() and not _row(c4, "Magazine").is_empty(), "…but it still shows its own numbers")
	var gun2 = _weapon("004", 2)
	var c5: Dictionary = ItemCompare.card(gun2, gun)
	check(_row(c5, "Close hit")["tone"] == 1 and "+10%" in _row(c5, "Close hit")["delta"], "a Reinforced gun hits 10 points more often at close range (%s)" % _row(c5, "Close hit")["delta"])
	check(ItemCompare.card(_plain("035"), knife).is_empty(), "a crowbar is no weapon: no card")
	check(ItemCompare.card(bat, null)["vs"] == "", "nothing in hand: its own numbers, nothing to set against")
	check(ItemCompare.card(bat, bat)["vs"] == "", "the weapon in hand is not set against itself")

	print("[the three presentations]")
	var bb: String = ItemCompare.bbcode(c)
	check(bb.contains("compared with your") and bb.contains("Damage") and bb.contains("▲"), "the panel text names what it is compared with and carries the arrows")
	var pill: String = ItemCompare.pill_suffix(c)
	check(pill.contains("dmg ▲ +2") and pill.contains("spd ▼"), "the floor pill is one line of what differs (%s)" % pill)
	check(ItemCompare.pill_suffix(ItemCompare.card(bat, _weapon("014"))) == "", "an identical weapon says nothing")

	print("[wired in]")
	WorldState.inventory.clear()
	WorldState.add_to_inventory("001")
	HUD.selected_slot = 0
	var drop = load("res://scenes/world_drop.tscn").instantiate() if ResourceLoader.exists("res://scenes/world_drop.tscn") else null
	if drop != null:
		drop.item_id = "014"
		add_child(drop)
		var line: String = drop._prompt_text()
		check(line.contains("Baseball Bat") and line.contains("dmg ▲"), "a bat on the floor says how it compares with the knife in hand (%s)" % line)
		drop.queue_free()
	else:
		check(true, "(no world_drop scene to build; the pill text is covered by ItemCompare.pill_suffix above)")
	var loot = load("res://scripts/loot_ui.gd").new()
	add_child(loot)
	loot.current_item_id = "014"
	loot.current_key_target = ""
	loot._show_compare(ItemData.get_item("014"))
	check(loot.compare_label.visible and loot.compare_label.text.contains("Damage"), "the found-item panel carries the card")
	loot._show_compare(ItemData.get_item("006"))
	check(not loot.compare_label.visible, "…and only for a weapon")
	loot.queue_free()
	HUD.selected_slot = -1
	WorldState.inventory.clear()

	print("=== %s (%d failures) ===" % ["FAILED" if failures > 0 else "ALL PASSED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _plain(id: String):
	var inst := ItemInstance.new()
	inst.setup(id)
	return inst
