extends Sprite2D

# The GUN CABINET's state, drawn over living room E's art (owner round 20). The module art shows it
# LOCKED (its glass door shut, a handgun on the shelf inside, the brass lock); this sprite lays the
# other looks over it, cut to just the pixels that change (tools/art/living_room_variants.py writes
# them): open (its key) / smashed (a crowbar), each full or empty, and LOOTED (someone else got there
# first in runs 2/3: glass smashed, the long guns gone, a drawer dumped on the floor) — and
# the afternoon / night versions, so it wears the same damage as the rest of the room.

const DIR := "res://assets/rooms/"

var apartment_id: String = ""


func _ready() -> void:
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("gun_cabinet_art")


func refresh() -> void:
	var state := WorldState.gun_cabinet_state(apartment_id)
	var path := texture_for(state, WorldState.current_run)
	texture = load(path) if path != "" else null
	visible = texture != null


# The overlay file for a state + run ("" = none: locked is the module art itself).
static func texture_for(state: String, run: int) -> String:
	if state in ["none", "locked", ""]:
		return ""
	for r in range(run, 0, -1):
		var p := DIR + "living_room_e_cabinet_" + state + ("" if r < 2 else "_r%d" % r) + ".png"
		if ResourceLoader.exists(p):
			return p
	return ""
