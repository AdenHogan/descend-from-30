extends Node

# THE FLYER (docs/ENEMY_MOVEMENT.md; scripts/enemy_zombie_flyer.gd): a thing that hangs at head height and bobs.
#   • it is a zombie-group enemy AND a flyer, fragile, with its sprite lifted off the floor by its height while the collision box stays put;
#   • a swing reaches it only on the low half of its bob; a dead one can always be hit; a bite finds a crouching player only when it dives;
#   • the corridor spawner can pick it (WorldState.enemy_type_for) and maps it to its scene; the player's swing asks `can_be_meleed`.
# Run: godot --headless res://tests/flyer_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== flyer test ===")
	var host := Node2D.new()
	add_child(host)
	var f = load("res://scenes/enemy_zombie_flyer.tscn").instantiate()
	f.hp_floor = 2                                   # (the deep floors have 1 hp for everything: look at a floor where a standard has plenty)
	host.add_child(f)
	await get_tree().process_frame
	var std = load("res://scenes/enemy_zombie_standard.tscn").instantiate()
	std.hp_floor = 2
	host.add_child(std)
	await get_tree().process_frame
	check(f.is_in_group("flyer") and f.is_in_group("zombie") and not f.is_in_group("crawler"), "it is a flyer and a zombie-group enemy, not a crawler")
	check(f.max_hp < std.max_hp, "fragile: %d hp against a standard's %d" % [f.max_hp, std.max_hp])
	var cs: CollisionShape2D = f.get_node("CollisionShape2D")
	var shape_y: float = cs.position.y
	f._hover_t = PI / 2.0
	f._h = f.target_height()
	f._apply_height()
	check(absf(f.height() - (f.HOVER_BASE + f.HOVER_AMP)) < 0.01, "the top of the bob is %.0f px up" % f.height())
	check(not f.can_be_meleed(), "up high a swing goes under it")
	var spr: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
	check(absf(spr.position.y - (f._sprite_y0 - f.height())) < 0.01, "its sprite is lifted by its height")
	check(cs.position.y == shape_y, "the collision box stays on the floor (every feet measurement reads it)")
	f._hover_t = -PI / 2.0
	f._h = f.target_height()
	check(f.can_be_meleed(), "down low (%.0f px) a swing reaches it" % f.height())
	# the bite: a stub player
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar is_crouching = false\nvar hits = 0\nfunc receive_hit(n):\n\thits += n\n"
	check(src.reload() == OK, "the stub player compiles")
	var pl := Node2D.new()
	pl.set_script(src)
	host.add_child(pl)
	f.player = pl
	f._h = 56.0
	f._deliver_attack(0.0)
	check(pl.hits == 1, "a STANDING player is bitten however high it is")
	pl.is_crouching = true
	f._deliver_attack(0.0)
	check(pl.hits == 1, "a CROUCHING player is passed over while it is high")
	f._h = 24.0
	f._deliver_attack(0.0)
	check(pl.hits == 2, "...and bitten when it dives")
	f.is_dead = true
	check(f.can_be_meleed() and f.target_height() == 0.0, "a dead one is on the floor and can be hit")
	# the spawner
	var seen_fly := false
	var seen_crawl := false
	WorldState.current_run = 1
	for i in range(700):
		var t: String = WorldState.enemy_type_for(10, "10:%d:388" % (150 + i * 3))
		seen_fly = seen_fly or t == "zombie_flyer"
		seen_crawl = seen_crawl or t == "zombie_crawler"
	check(seen_fly and seen_crawl, "the corridor mix still lays blobs and now lays flyers (flyer %s, blob %s)" % [str(seen_fly), str(seen_crawl)])
	var bf_src := FileAccess.get_file_as_string("res://scripts/building_floors.gd")
	check(bf_src.contains('"zombie_flyer": preload("res://scenes/enemy_zombie_flyer.tscn")') and bf_src.contains('"zombie_flyer": 374.0'), "building_floors maps the flyer to its scene and its settled origin")
	var pl_src := FileAccess.get_file_as_string("res://scripts/player.gd")
	check(pl_src.contains("can_be_meleed"), "the player's swing asks an enemy whether it can be reached")
	host.queue_free()
	await get_tree().process_frame
	print("=== %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)
