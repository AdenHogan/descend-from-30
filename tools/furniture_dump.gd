extends Node

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
			var pl := FurniturePlanner.plan(room, style, seed0 + k, {"window": side})
			if pl.is_empty():
				bad += 1
				print("EMPTY plan %s/%s seed %d" % [room, style, seed0 + k])
				continue
			var v := FurniturePlanner.validate(pl, {"window": side})
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
