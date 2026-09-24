extends Node

# ECONOMY REPORT — measures what the building actually hands out, so upgrade / Valour costs are set
# against data, not guesses. Headless:
#   godot --headless res://tools/economy_report.tscn -- --seeds=6
# For each seed and run, it builds every apartment on floors 29..1 (the real room.tscn, so the
# real loot + scrap rolls) and totals the scrap sitting in their anchors, plus the maintenance
# rooms' expected spare parts. Prints per-run totals and the average; a character only searches
# part of the building, so read "all apartments" as the ceiling, not the typical haul.
# Runs in the test sandbox (res://tools/ → WorldState.data_dir()), never the player's saves.
# Known: it can linger after printing the RUN lines (rooms with pending awaits) — kill it then.

var _seeds := 6


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			_seeds = maxi(1, int(a.substr(8)))
	await get_tree().process_frame
	var per_run := {1: [], 2: [], 3: []}
	var per_apt := {1: [], 2: [], 3: []}
	for s in _seeds:
		WorldState.new_game()
		WorldState.is_first_run = false
		for run in [1, 2, 3]:
			WorldState.current_run = run
			var total := 0
			var apts := 0
			for f in range(29, 0, -1):
				for a in range(1, 6):
					var got := await _apartment_scrap(f, a)
					if got >= 0:
						total += got
						apts += 1
			var maint := 0
			for f in range(3, 28, 3):
				maint += 3          # 2 anchors × 16% × ~10 scrap — expected value (rounded)
			per_run[run].append(total + maint)
			per_apt[run].append(float(total) / maxf(1.0, float(apts)))
			print("seed %d run %d: apartments %d scrap (%.1f / apartment over %d) + maintenance ~%d" %
				[s + 1, run, total, float(total) / maxf(1.0, apts), apts, maint])
	for run in [1, 2, 3]:
		var t := 0.0
		for v in per_run[run]:
			t += v
		var pa := 0.0
		for v in per_apt[run]:
			pa += v
		print("RUN %d: whole building %.0f scrap on average; %.1f per apartment searched" %
			[run, t / per_run[run].size(), pa / per_apt[run].size()])
	get_tree().quit(0)


# Scrap in one apartment's anchors (-1 = no such apartment). Builds the real room, reads the
# anchors it seeded, frees it.
func _apartment_scrap(floor_num: int, apt: int) -> int:
	var id := "%d%02d" % [floor_num, apt]
	WorldState.current_floor = floor_num
	WorldState.current_apartment_id = id
	WorldState.spawn_source = ""
	var room = load("res://scenes/room.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var got := 0
	var prefix := id + ":"
	for key in WorldState.anchor_items.keys():
		if String(key).begins_with(prefix) and WorldState.anchor_items[key] == "037":
			got += int(WorldState.anchor_amounts.get(key, 0))
	room.queue_free()             # queue, not free: the room's own awaits must see it leave cleanly
	await get_tree().process_frame
	await get_tree().process_frame
	return got
