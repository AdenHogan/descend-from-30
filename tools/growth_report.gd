extends Node

# DEV TOOL — how overgrown is each floor, and what grew? Prints, per floor and run, the overgrowth level
# and the corridor's items by kind, so the curve can be tuned without walking the building.
#   godot --headless res://tools/growth_report.tscn

const CG := preload("res://scripts/corridor_growth.gd")
const OG := preload("res://scripts/overgrowth.gd")
const BF := preload("res://scripts/building_floors.gd")


func _ready() -> void:
	await get_tree().process_frame
	WorldState.dev_seed = 12345
	WorldState.new_game()
	print("floor run  level word        total  (tuft moss flower hang creeper fungus fern roots)")
	for f in [29, 25, 20, 15, 10, 6, 3, 1]:
		for r in [1, 2, 3]:
			var lv: float = OG.level(f, r)
			var kinds := {}
			var items: Array = CG.plan(f, r, BF.corridor_base_name(f))
			for d in items:
				kinds[d["kind"]] = int(kinds.get(d["kind"], 0)) + 1
			var row := ""
			for k in ["tuft", "moss", "flower", "hang", "creeper", "fungus", "fern", "roots"]:
				row += " %3d" % int(kinds.get(k, 0))
			print("%4d %3d  %.2f  %-10s %4d  %s" % [f, r, lv, OG.word(lv), items.size(), row])
	get_tree().quit(0)
