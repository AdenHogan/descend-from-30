extends Node

# WALK CADENCE (owner 2026-11-21, the motion review; scripts/enemy_zombie_standard.gd `_sync_walk_cadence`): a Walk plays at the rate its drawn stride matches the speed
# the body is going, so feet do not slide; any other animation plays at its own rate; a kind's designed speed sits inside the clamp; the blob humps (its speed follows its wave).
# Run: godot --headless res://tests/enemy_cadence_test.tscn

var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	print("=== enemy cadence test ===")
	var host := Node2D.new()
	add_child(host)
	for kind in ["standard", "big", "longarm", "spitter", "crawler", "flyer"]:
		var z = load("res://scenes/enemy_zombie_%s.tscn" % kind).instantiate()
		z.hp_floor = 5
		host.add_child(z)
		await get_tree().process_frame
		var spr: AnimatedSprite2D = z.get_node("AnimatedSprite2D")
		var spd: float = float(z.BASE_SPEED) if kind == "flyer" else float(z.SPEED)      # (the flyer's SPEED surges every frame: its designed speed is BASE_SPEED)
		var design: float = float(z.WALK_DESIGN_SPEED)
		var ratio: float = spd / design
		if kind == "crawler":
			check(not z.SYNC_CADENCE, "crawler: the blob keeps its own rate (the hump)")
			continue
		check(z.SYNC_CADENCE and ratio >= 0.5 and ratio <= 2.4, "%s: speed %.0f against the stride's designed speed %.0f is a %.2fx cadence (inside the 0.5-2.4 band)" % [kind, spd, design, ratio])
		spr.play("Walk")
		z.velocity.x = spd
		z._sync_walk_cadence()
		check(absf(spr.speed_scale - clampf(ratio, 0.3, 2.4)) < 0.01, "%s: a Walk at full speed plays at %.2fx" % [kind, spr.speed_scale])
		z.velocity.x = 0.0
		z._sync_walk_cadence()
		check(spr.speed_scale <= 0.31, "%s: stopped, the steps nearly stop too" % kind)
		spr.play("Attack")
		z._sync_walk_cadence()
		check(is_equal_approx(spr.speed_scale, 1.0), "%s: an Attack plays at its own rate" % kind)
	# the blob's hump
	var b = load("res://scenes/enemy_zombie_crawler.tscn").instantiate()
	b.hp_floor = 5
	host.add_child(b)
	await get_tree().process_frame
	var bs: AnimatedSprite2D = b.get_node("AnimatedSprite2D")
	var base: float = float(b.SPEED)
	bs.play("Walk")
	var lo := INF
	var hi := 0.0
	var sum := 0.0
	for f in range(12):
		bs.frame = f
		b._hump_base = 0.0
		b.SPEED = base
		b._hump()
		lo = minf(lo, b.SPEED)
		hi = maxf(hi, b.SPEED)
		sum += b.SPEED
	check(hi > base * 1.3 and lo < base * 0.5, "the blob surges (%.0f) and gathers (%.0f) around its crawl speed %.0f" % [hi, lo, base])
	check(absf(sum / 12.0 - base) < base * 0.15, "...and averages its old crawl speed (%.1f against %.1f)" % [sum / 12.0, base])
	host.queue_free()
	await get_tree().process_frame
	print("=== %s ===" % ("ALL PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)
