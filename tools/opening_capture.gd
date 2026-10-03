extends Node

# DEV TOOL — renders the new-game / load opening (scripts/opening_exterior.gd) at chosen times for a given run + seed, so the three
# looks and this playthrough's burning floors can be reviewed without waiting through the climb. Needs a rendering driver:
#
#   xvfb-run -a -s "-screen 0 1152x648x24" godot --rendering-driver opengl3 res://tools/opening_capture.tscn -- \
#       --out=/tmp/open --run=3 --seed=5 --times=1.5,6,10,15 [--notitle=1]
#
# It picks a building with fire origins if --seed is not given (so the burnt floors show), sets WorldState.current_run, builds the
# exterior, ticks its clock to each time and saves a PNG per time (open_<run>_<time>.png).

var out_dir := "/tmp/opening"
var run := 1
var seed_ := 0
var times: Array = [1.5, 6.0, 11.0, 15.0]
var with_title := true


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--run="):
			run = int(a.substr(6))
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--times="):
			times = []
			for p in a.substr(8).split(","):
				times.append(float(p))
		elif a.begins_with("--notitle="):
			with_title = a.substr(10) != "1"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().process_frame
	WorldState.new_game()
	if seed_ == 0:
		for sd in range(1, 600):
			WorldState.master_seed = sd
			var n := 0
			for f in range(2, 30):
				if WorldState._fire_origin_seeded(f):
					n += 1
			if n >= 3:
				seed_ = sd
				break
	WorldState.master_seed = seed_
	WorldState.fire_dealt_with = {}
	WorldState.current_run = run
	print("seed ", seed_, " run ", run, " burning floors: ", JSON.stringify(preload("res://scripts/opening_exterior.gd").burn_plan()))
	var ext: Control = preload("res://scripts/opening_exterior.gd").new()
	ext.title_text = "DESCEND FROM 30" if with_title else ""
	ext.run = run
	add_child(ext)
	await get_tree().process_frame
	if not ext.load_ok:
		print("exterior failed to build")
		get_tree().quit(1)
		return
	var last := 0.0
	for tm in times:
		# tick in small steps so the animation state (flicker, drift, lightning) evolves like play
		var tt: float = float(tm)
		while ext.t < tt:
			ext.tick(0.05)
			await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "%s/open_%d_%05.1f.png" % [out_dir, run, tt]
		img.save_png(path)
		print("saved ", path)
	get_tree().quit(0)
