extends Node

const ModuleGeo := preload("res://scripts/module_geo.gd")

## Runs the furniture planner over many seeds and writes the plans as JSON — for review (tools/art/furn_preview.py composes them into contact sheets) and for measuring
## how often a recipe needs its fallback (owner round 47).
##   godot --headless res://tools/furniture_dump.tscn -- --room=bedroom --style=adult --n=24 --out=/tmp/plans.json [--window=left|right|none] [--seed0=1000] [--why=1 (print why attempts failed)]
## Prints, per style, how many plans broke a rule (must be 0), how many used the fallback, and the mean attempts.


func _arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return default


func _ready() -> void:
	var room := _arg("room", "bedroom")
	var only := _arg("style", "")
	var n := int(_arg("n", "24"))
	var seed0 := int(_arg("seed0", "1000"))
	var win := _arg("window", "mixed")
	var out := _arg("out", "")
	if _arg("fallbacks", "") != "":                      # every recipe's hand-set fallback layout, checked with the window on either side (tests/furniture_test.gd does the same)
		var nbad := 0
		for key in FurniturePlanner.data().get("recipes", {}).keys():
			var parts: PackedStringArray = String(key).split("/")
			if only != "" and parts[1] != only:
				continue
			var rcp := FurniturePlanner.recipe(parts[0], parts[1])
			for side in ["left", "right", ""]:
				if side == "" and not (parts[0] in ["study", "dining_room"]):
					continue
				var vctx: Dictionary = {"window": side}
				if side == "":
					vctx["blocked"] = [FurniturePlanner.balcony_box()]                          # a balcony slot: no window, the doors take the left of the module
				var items: Array = []
				for e in FurniturePlanner.fallback_layout(rcp, side):
					var rec := FurniturePlanner.piece(String(e["id"]))
					items.append({"id": e["id"], "variant": e["variant"], "x": e["x"], "y": e["y"], "plane": rec["plane"], "host_plane": rec["plane"], "w": rec["w"]})
				vctx["fallback"] = true
				var v := FurniturePlanner.validate({"room": parts[0], "style": parts[1], "items": items, "fallback": true}, vctx)
				if not v.is_empty():
					nbad += 1
					print("FALLBACK %s window %s: %s" % [key, side if side != "" else "none (balcony slot)", str(v)])
		print("fallbacks: %d layouts broke a rule" % nbad)
		get_tree().quit(1 if nbad > 0 else 0)
		return
	if _arg("make_fallbacks", "") != "":                # for every recipe: a seeded plan stripped to its main pieces, per window side (and with no window) — printed as furn_rooms.py text (design x)
		for key in FurniturePlanner.data().get("recipes", {}).keys():
			var parts: PackedStringArray = String(key).split("/")
			if only != "" and parts[1] != only:
				continue
			for side in ["left", "right", ""]:
				var ctx: Dictionary = {"window": side}
				if side == "" and parts[0] in ["study", "dining_room"]:
					ctx["blocked"] = [FurniturePlanner.balcony_box()]
				var found := false
				for sd in range(1, 1500):
					var pl := FurniturePlanner.plan(parts[0], parts[1], sd, ctx)
					if pl.is_empty() or bool(pl["fallback"]):
						continue
					var items: Array = []
					var main: Array = []
					for it in pl["items"]:
						if String(it["plane"]) in ["wall", "front", "floor", "ceiling"] and not bool(it.get("clutter", false)):
							items.append({"id": it["id"], "variant": it["variant"], "x": it["x"], "y": it["y"], "plane": it["plane"], "host_plane": it["host_plane"], "w": it["w"]})
							main.append(it)
					var vctx := ctx.duplicate()
					vctx["fallback"] = true
					if items.size() < int(_arg("minitems", "2")) or not FurniturePlanner.validate({"room": parts[0], "style": parts[1], "items": items, "fallback": true}, vctx).is_empty():
						continue
					var txt := []
					for it in main:
						txt.append("dict(id='%s', variant='%s', x=%d, y=%d)" % [it["id"], it["variant"], int(it["x"]) + ModuleGeo.DESIGN_PAD, int(it["y"])])
					print("FB %s %s (seed %d): [%s]" % [key, side if side != "" else "default", sd, ", ".join(txt)])
					found = true
					break
				if not found:
					print("FB %s %s: NONE FOUND" % [key, side if side != "" else "default"])
		get_tree().quit(0)
		return
	var result: Array = []
	var bad_total := 0
	FurniturePlanner.collect_fail = _arg("why", "") != ""
	for st in FurniturePlanner.styles_of(room):
		var style := String(st["style"])
		if only != "" and only != style:
			continue
		var bad := 0
		var fb := 0
		var tries := 0
		for k in range(n):
			var side := win if win != "mixed" else ("left" if k % 2 == 0 else "right")
			if side == "none":
				side = ""
			var pctx: Dictionary = {"window": side}
			if side == "" and _arg("balcony", "") != "":              # a balcony slot: no window, the doors take the left of the module (--window=none --balcony=1)
				pctx["blocked"] = [FurniturePlanner.balcony_box()]
			var pl := FurniturePlanner.plan(room, style, seed0 + k, pctx)
			if pl.is_empty():
				bad += 1
				print("EMPTY plan %s/%s seed %d" % [room, style, seed0 + k])
				continue
			var v := FurniturePlanner.validate(pl, pctx)
			if not v.is_empty():
				bad += 1
				print("VIOLATION %s/%s seed %d (%s): %s" % [room, style, seed0 + k, side, str(v)])
			if bool(pl["fallback"]):
				fb += 1
			tries += int(pl["attempt"])
			pl["window"] = side
			result.append(pl)
		bad_total += bad
		print("%s/%s: %d plans, %d broke a rule, %d fallback, %.1f attempts on average" % [room, style, n, bad, fb, float(tries) / float(maxi(1, n))])
	if FurniturePlanner.collect_fail:
		var keys: Array = FurniturePlanner.fail_log.keys()
		keys.sort_custom(func(a, b): return int(FurniturePlanner.fail_log[a]) > int(FurniturePlanner.fail_log[b]))
		for k in keys:
			print("  failed attempt: %5d x %s" % [int(FurniturePlanner.fail_log[k]), String(k)])
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(result))
		f.close()
	get_tree().quit(1 if bad_total > 0 else 0)
