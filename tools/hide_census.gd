extends Node

## How many hiding places do planned rooms have? (owner round 49t: "we need to ensure stealth hiding spots are clear and present whenever they contextually should be there")
## Plans `--n` rooms of every style of every room type and counts, per room type: the share of rooms with a piece to hide in / behind, and how often the corner beside a
## doorway is bare enough to stand in (Stealth.WALL_HIDE).
##   godot --headless res://tools/hide_census.tscn -- --n=40


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default


func _ready() -> void:
	var n := int(_arg("n", "40"))
	print("hide census: %d rooms a style, a doorway corner must be bare for %d px" % [n, int(Stealth.WALL_HIDE["clear_to"])])
	for room in ["bedroom", "living_room", "study", "dining_room", "kitchen", "bathroom"]:
		var rooms := 0
		var with_piece := 0
		var pieces: Dictionary = {}
		var corners := 0
		var bare := 0
		for style in FurniturePlanner.styles_of(room):
			for i in n:
				var side: String = "left" if i % 2 == 0 else "right"
				var pl: Dictionary = FurniturePlanner.plan(room, String(style["style"]), 5000 + i * 7919, {"window": side})
				if pl.is_empty():
					continue
				rooms += 1
				var has := false
				for it in pl["items"]:
					if Stealth.HIDE_PIECES.has(String(it["id"])):
						has = true
						pieces[String(it["id"])] = int(pieces.get(String(it["id"]), 0)) + 1
				if has:
					with_piece += 1
				var standing: Array = StealthSpot.standing_spans(pl)
				for s in ["l", "r"]:
					corners += 1
					if StealthSpot.wall_is_bare(s, standing, []):
						bare += 1
		print("  %-12s rooms %4d   with a hide piece %3d%%   bare doorway corners %3d%%   pieces %s" % [room, rooms, int(round(100.0 * with_piece / maxf(1.0, rooms))), int(round(100.0 * bare / maxf(1.0, corners))), str(pieces)])
	get_tree().quit(0)
