extends Node

# DEV TOOL — a contact sheet of the furniture pieces that carry a LIVE detail (module_anim kinds lava / smoke / pendulum): each piece's real sprite with its real anim nodes
# (the records in data/furniture.json), one row a piece, one column a moment, drawn 6x. Needs a rendering driver:
#
#   xvfb-run -a -s "-screen 0 1152x648x24" godot --rendering-driver opengl3 res://tools/anim_sheet.tscn -- --out=/tmp/anim_sheet.png [--times=0,0.5,1,1.5,2.5,4,6.5] [--zoom=6] [--pieces=lamp_lava:purple,ashtray_pack:glass]

var pieces: Array = [["lamp_lava", "purple"], ["lamp_lava", "blue"], ["ashtray_pack", "glass"], ["clock_regulator", "a"], ["clock_cuckoo", "a"]]
var zoom := 6.0

func _ready() -> void:
	var out := "/tmp/anim_sheet.png"
	var times: Array = [0.0, 0.5, 1.0, 1.5, 2.5, 4.0, 6.5]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--pieces="):
			pieces = []
			for pv in a.substr(9).split(","):
				pieces.append(Array(pv.split(":")))
		elif a.begins_with("--times="):
			times = []
			for t in a.substr(8).split(","):
				times.append(float(t))
	await get_tree().process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/furniture.json"))
	var items: Dictionary = data["items"]
	var bg := ColorRect.new()
	bg.color = Color(0.38, 0.33, 0.3)
	bg.size = Vector2(1152, 648)
	add_child(bg)
	var y := 4.0
	for pv in pieces:
		var v: Dictionary = items[pv[0]]["variants"][pv[1]]
		var spr: Dictionary = v["sprites"][mini(3, v["sprites"].size() - 1)]
		var tex: Texture2D = load("res://assets/furniture/%s.png" % spr["file"])
		var rowh := float(tex.get_height()) * zoom + 6.0
		var x := 4.0
		for t in times:
			var holder := Node2D.new()
			holder.scale = Vector2(zoom, zoom)
			holder.position = Vector2(x, y)
			add_child(holder)
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			holder.add_child(s)
			for an in v["anims"]:
				var n := Node2D.new()
				n.position = Vector2(int(spr["rx"]) + int(an["dx"]), int(spr["ry"]) + int(an["dy"]))
				n.set_script(load("res://scripts/module_anim.gd"))
				for k in ["kind", "fall", "color", "w", "h"]:
					if an.has(k):
						n.set_meta(k, an[k])
				holder.add_child(n)
				n.set_process(false)
				n._snow = t
				n.queue_redraw()
			x += float(tex.get_width()) * zoom + 14.0
		y += rowh
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
