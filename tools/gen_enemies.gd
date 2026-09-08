extends SceneTree

# One-off asset tool: build SpriteFrames .tres for the three new enemy types by
# slicing their 128x128 sheets, and MEASURE each sprite's feet/head line within a
# frame (bottom/top opaque pixel) so collision + settled-Y are set by measurement,
# never by eye. Run: godot --headless --script res://tools/gen_enemies.gd

const ENEMIES := {
	"crawler": "res://assets/Enemies/CrawlerZombie/CrawlerZombie/CrawlerZombie - %s.png",
	"longarm": "res://assets/Enemies/LongArmZombie/LongArmZombie/LongArmZombie - %s.png",
	"spitter": "res://assets/Enemies/SpittingZombie/SpittingZombie/SpittingZombie - %s.png",
}
# name -> [speed, loop] ; matches enemy_zombie_standard.tscn
const ANIMS := {
	"Idle": [5.0, true], "Walk": [6.0, true], "Attack": [16.0, true],
	"Hit": [5.0, true], "Death": [10.0, false],
}
const FW := 128
const FH := 128

func _init() -> void:
	for ename in ENEMIES:
		var pattern: String = ENEMIES[ename]
		var sf := SpriteFrames.new()
		if sf.has_animation("default"):
			sf.remove_animation("default")
		for anim in ANIMS:
			sf.add_animation(anim)
			sf.set_animation_speed(anim, ANIMS[anim][0])
			sf.set_animation_loop(anim, ANIMS[anim][1])
			var tex: Texture2D = load(pattern % anim)
			var n: int = int(tex.get_width() / FW)
			for i in range(n):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * FW, 0, FW, FH)
				sf.add_frame(anim, at)
		var out := "res://assets/Enemies/%s_frames.tres" % ename
		var err := ResourceSaver.save(sf, out)
		# Measure feet/head from the Idle frame 0 (a clean standing pose).
		var img: Image = (load(pattern % "Idle") as Texture2D).get_image()
		var top := -1
		var bot := -1
		var lo := 999
		var hi := -1
		for y in range(FH):
			for x in range(FW):
				if img.get_pixel(x, y).a > 0.3:
					if top < 0:
						top = y
					bot = y
					lo = min(lo, x)
					hi = max(hi, x)
		# scale 3, sprite centred on origin: local_y = (frame_y - FH/2) * 3
		var feet_off := (bot - FH / 2.0) * 3.0
		var head_off := (top - FH / 2.0) * 3.0
		var settled := 419.0 - feet_off
		print("%s: save_err=%d frames_Idle_top=%d bot=%d x[%d..%d] feet_off=%.1f head_off=%.1f SETTLED_Y=%.1f" % [ename, err, top, bot, lo, hi, feet_off, head_off, settled])
	quit()
