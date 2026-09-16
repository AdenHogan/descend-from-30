extends SceneTree

# Dev tool (NOT part of the game): dumps trimmed idle/pose frames of the enemy rigs and
# the player at their true in-game scale, for an art comparison sheet. Runs headless —
# Image compositing is CPU-side, so no display is needed.
#   godot --headless --script res://tools/gen_sprite_lineup.gd
# Writes trimmed PNGs + a manifest.json under docs/art_reference/frames/; then
#   python3 tools/compose_sprite_lineup.py
# lays them out into the labelled reference sheets in docs/art_reference/.

const OUT := "res://docs/art_reference/frames/"

# name, scene, animation, frame index (-1 = middle frame)
const ENEMIES := [
	["Standard", "res://scenes/enemy_zombie_standard.tscn", "", 0],
	["Big",      "res://scenes/enemy_zombie_big.tscn",      "", 0],
	["Crawler",  "res://scenes/enemy_zombie_crawler.tscn",  "", 0],
	["Long Arm", "res://scenes/enemy_zombie_longarm.tscn",  "", 0],
	["Spitter",  "res://scenes/enemy_zombie_spitter.tscn",  "", 0],
]

# player poses: label, [candidate anim names, first that exists wins], frame (-1 = middle)
const PLAYER_POSES := [
	["Gun idle",   ["gun_idle"], 0],
	["Sword idle", ["katana_idle", "katana_attack_continuous"], 0],
	["Crouch",     ["crouch_idle"], 0],
	["Push",       ["punch_jab"], -1],
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var manifest := {"enemies": [], "player": []}
	# WorldState.new_game so rigs build cleanly.
	if Engine.has_singleton("WorldState"):
		pass
	await process_frame
	for e in ENEMIES:
		var entry = await _dump(e[0], e[1], e[2], e[3], "enemy_")
		if entry:
			manifest["enemies"].append(entry)
	# Player: one instance, pull several poses off its runtime-built SpriteFrames.
	var p = load("res://scenes/player.tscn").instantiate()
	get_root().add_child(p)
	await process_frame
	await process_frame
	var pspr: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	var sf: SpriteFrames = pspr.sprite_frames
	print("player anims: ", sf.get_animation_names())
	for pose in PLAYER_POSES:
		var anim := ""
		for cand in pose[1]:
			if sf.has_animation(cand):
				anim = cand
				break
		if anim == "":
			print("  MISSING pose ", pose[0], " (", pose[1], ")")
			continue
		var fcount := sf.get_frame_count(anim)
		var fi: int = pose[2] if pose[2] >= 0 else int(fcount / 2)
		fi = clampi(fi, 0, fcount - 1)
		var tex := sf.get_frame_texture(anim, fi)
		var file := _save_trimmed(tex, "player_" + anim, pspr.scale.x)
		if file != "":
			manifest["player"].append({"label": pose[0], "file": file, "scale": pspr.scale.x})
	p.queue_free()

	var f := FileAccess.open(OUT + "manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("DONE -> ", OUT)
	quit()


func _dump(label: String, scene_path: String, anim: String, frame: int, prefix: String):
	var n = load(scene_path).instantiate()
	get_root().add_child(n)
	await process_frame
	var spr: AnimatedSprite2D = n.get_node_or_null("AnimatedSprite2D")
	if spr == null or spr.sprite_frames == null:
		print("  no sprite for ", label); n.queue_free(); return null
	var sf: SpriteFrames = spr.sprite_frames
	var a := anim if (anim != "" and sf.has_animation(anim)) else sf.get_animation_names()[0]
	var fcount := sf.get_frame_count(a)
	var fi: int = frame if frame >= 0 else int(fcount / 2)
	fi = clampi(fi, 0, fcount - 1)
	var tex := sf.get_frame_texture(a, fi)
	var sc: float = spr.scale.x
	var file := _save_trimmed(tex, prefix + label.to_lower().replace(" ", "_"), sc)
	n.queue_free()
	if file == "":
		return null
	return {"label": label, "file": file, "scale": sc}


func _save_trimmed(tex: Texture2D, name: String, _scale: float) -> String:
	if tex == null:
		return ""
	var img := tex.get_image()
	if img == null:
		return ""
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var rect := img.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = Rect2i(0, 0, img.get_width(), img.get_height())
	var trimmed := img.get_region(rect)
	var path := OUT + name + ".png"
	trimmed.save_png(path)
	return path.get_file()
