extends Node

# DEV TOOL — a contact sheet of the people at the opening's windows (scripts/opening_exterior.gd `_Survivors`): every behaviour at four moments
# on a lit pane, 8x. Needs a rendering driver:
#
#   xvfb-run -a -s "-screen 0 1152x648x24" godot --rendering-driver opengl3 res://tools/people_sheet.tscn -- --out=/tmp/people.png [--run=2]

const KINDS := ["wave", "pace", "peer", "sway", "pound", "shout", "huddle", "phone", "slump"]
const TIMES := [0.4, 1.1, 1.9, 2.8]

func _ready() -> void:
	var out := "/tmp/people.png"
	var run := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--run="):
			run = int(a.substr(6))
	await get_tree().process_frame
	var Ext = load("res://scripts/opening_exterior.gd")
	var holder := Node2D.new()
	holder.scale = Vector2(8, 8)
	holder.position = Vector2(12, 12)
	add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12)
	bg.size = Vector2(1152, 648)
	add_child(bg)
	move_child(bg, 0)
	var cell := Vector2(12, 11)
	for ki in KINDS.size():
		for ti in TIMES.size():
			var o := Vector2(float(ki) * cell.x, float(ti) * cell.y)
			var pane := ColorRect.new()                                  # a warm lit pane: 9 x 8 of glass
			pane.color = Color(1.0, 0.82, 0.5)
			pane.position = o
			pane.size = Vector2(9, 8)
			holder.add_child(pane)
			var sv = Ext._Survivors.new()
			sv.run = run
			sv.people = [{"x": o.x, "y": o.y, "w": 9, "h": 8, "floor": 12, "bay": ki, "kind": KINDS[ki], "shirt": "4f7ab0", "phase": 0.7 + 0.31 * float(ki)}]
			sv.clock = TIMES[ti] + 0.2 * float(ki)
			holder.add_child(sv)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
