extends Node

# Writes docs/PERKS.md — the perk list (rarity `w`, desirability `d`, Valour price) generated from
# the live data (Progression.perk_table_markdown), so the doc can never drift from the game.
#   godot --headless res://tools/perk_table.tscn
# progression_test fails if the committed doc is stale — rerun this after changing any perk.

const OUT := "res://docs/PERKS.md"


func _ready() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("perk_table: can't write %s" % OUT)
		get_tree().quit(1)
		return
	f.store_string(Progression.perk_table_markdown())
	f.close()
	print("perk_table: wrote %s" % OUT)
	get_tree().quit(0)
