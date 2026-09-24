extends SceneTree
# DEV: drawn feet per ANIMATION FRAME vs collision bottom (node-local y), for every actor rig.
func _init() -> void:
	for path in ["res://scenes/player.tscn", "res://scenes/enemy_zombie_standard.tscn", "res://scenes/enemy_zombie_big.tscn",
			"res://scenes/enemy_zombie_crawler.tscn", "res://scenes/enemy_zombie_longarm.tscn", "res://scenes/enemy_zombie_spitter.tscn"]:
		var n: Node = load(path).instantiate()
		var spr: AnimatedSprite2D = n.get_node_or_null("AnimatedSprite2D")
		var col: CollisionShape2D = n.get_node_or_null("CollisionShape2D")
		var r: Rect2 = col.shape.get_rect()
		print("%s col_bottom=%.1f" % [path.get_file(), col.position.y + r.end.y])
		for anim in spr.sprite_frames.get_animation_names():
			var feet := []
			for f in range(spr.sprite_frames.get_frame_count(anim)):
				var img := spr.sprite_frames.get_frame_texture(anim, f).get_image()
				if img.is_compressed():
					img.decompress()
				var bot := -1
				for yy in range(img.get_height() - 1, -1, -1):
					for xx in range(img.get_width()):
						if img.get_pixel(xx, yy).a > 0.5:
							bot = yy + 1
							break
					if bot >= 0:
						break
				var base := -img.get_height() / 2.0 if spr.centered else 0.0
				feet.append(int(spr.position.y + (spr.offset.y + base + bot) * spr.scale.y))
			print("   %-12s feet by frame %s" % [anim, str(feet)])
		n.free()
	quit()
