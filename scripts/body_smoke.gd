extends Node2D

# A soft smoke wisp rising off a BURNED corpse — a zombie that died while on fire keeps
# smouldering. Purely cosmetic, NO collision. The same soft particle smoke as the fire's aftermath
# (scripts/soft_smoke.gd) — it used to loop the purchased Cycled_smoke sprite, a hard dark blob.
# Added as a child of the corpse (freed with it) when it dies alight.

const SOFT_SMOKE := preload("res://scripts/soft_smoke.gd")


func _ready() -> void:
	var e = SOFT_SMOKE.new()
	e.configure("body", 18.0)
	add_child(e)
