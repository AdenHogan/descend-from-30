class_name NodeReaction
extends RefCounted

## What a scavenge node DOES the moment the player presses interact on it (owner round 45c: "the movement animations should happen when
## the player presses their interact button to begin the scavenge of the node, not after… every node, if it makes logical sense, should have an
## animation… these details make the world more alive"). Two layers:
##   1. a SPECIFIC animation — a drawer pulls out, a door swings, the oven drops, a lid lifts, a glass tips over, a screen goes dark: a node
##      from scripts/open_furniture.gd named `Open_<anchor>` in the module (baked by tools/art/openables.py), played by Interactable.on_search_begin;
##   2. otherwise a GENERIC reaction for any node: a little dust / lint / paper rising and a sound that matches what the thing is made of
##      (this file: `material_for` reads the anchor's name). Nothing here is saved; the opened state is WorldState.opened_anchors.

const ROOM_SOUNDS := "res://assets/audio/room/"
const IMPACTS := "res://assets/audio/impacts/"
const DOORS := "res://assets/audio/doors/"
const DustPuff := preload("res://scripts/dust_puff.gd")

## material → [name keywords (first match wins in this order)]
const MATERIALS := [
	["paper", ["book", "paper", "file_box", "file", "map", "plan", "canvas", "record", "box", "pizza", "dollhouse", "present", "note"]],
	["cloth", ["clothes", "pillow", "quilt", "sofa", "armchair", "wingback", "beanbag", "sleeping_bag", "sleeping", "towel", "hamper", "laundry", "bag",
		"backpack", "mattress", "curtain", "pouffe", "rail", "bubbles", "rocking_horse", "toy"]],
	["metal", ["tin", "bucket", "trolley", "trash", "toolbox", "gas_mask", "microwave", "kettle", "fridge", "oven", "filing", "candelabra", "lantern",
		"handset", "radio", "printer", "crates", "pallet", "wheelchair", "med_"]],
	["ceramic", ["sink", "basin", "toilet", "throne", "tub", "taps", "washstand", "teapot", "tea", "dish", "china", "champagne", "drinks", "trinket",
		"vanity", "cup", "cake", "bath"]],
]
## material → [sound stems, volume dB]
const SOUNDS := {
	"paper": [["paper_0", "paper_1", "paper_2"], -14.0],
	"cloth": [["rustle_0", "rustle_1", "rustle_2"], -13.0],
	"metal": [["tin_0", "tin_1", "tin_2"], -14.0],
	"ceramic": [["clink_0", "clink_1", "clink_2"], -14.0],
	"wood": [["impactWood_medium_000", "impactWood_medium_001", "impactWood_medium_002"], -17.0],
}
## material → [dust colour, specks, spread, rise]
const PUFFS := {
	"paper": [Color(0.93, 0.92, 0.86), 5, 9.0, 7.0],
	"cloth": [Color(0.78, 0.74, 0.68), 8, 8.0, 10.0],
	"metal": [Color(0.7, 0.7, 0.72), 3, 5.0, 5.0],
	"ceramic": [Color(0.88, 0.9, 0.92), 3, 5.0, 5.0],
	"wood": [Color(0.62, 0.55, 0.46), 6, 7.0, 8.0],
}
## specific-animation kind → [stream path, dB]
const KIND_SOUNDS := {
	"drawer": ["res://assets/audio/room/scrape_%d.wav", 2, -11.0],
	"door_h": ["res://assets/audio/doors/creak1.ogg", 1, -12.0],
	"door_drop": ["res://assets/audio/doors/metalLatch.ogg", 1, -9.0],
	"lid": ["res://assets/audio/doors/creak1.ogg", 1, -12.0],
	"topple": ["res://assets/audio/room/fall_%d.wav", 3, -10.0],
	"screen_off": ["res://assets/audio/room/switch_0.wav", 1, -12.0],
}


## Things with a sound of their own (round 45d): the first entry whose `names` appear in the anchor's name (and none of its `not`) wins. `puff` =
## also the dust of its material; `also` = it plays alongside a SPECIFIC animation too (a microwave that opens AND beeps), not only in place of
## the generic sound.
const SPECIAL := [
	{"names": ["toilet", "throne"], "not": ["rolls"], "sounds": ["cistern_0"], "db": -13.0, "puff": false, "also": false},
	{"names": ["sink", "basin", "taps", "tub", "shower", "washstand", "bubbles"], "not": ["cupboard"], "sounds": ["tap_0", "tap_1"], "db": -14.0, "puff": false, "also": false},
	{"names": ["piano"], "sounds": ["piano_0", "piano_1", "piano_2"], "db": -12.0, "puff": false, "also": false},
	{"names": ["clock"], "sounds": ["clock_0"], "db": -14.0, "puff": false, "also": true},
	{"names": ["radio", "handset"], "sounds": ["static_0"], "db": -15.0, "puff": false, "also": true},
	{"names": ["microwave"], "sounds": ["beep_0"], "db": -14.0, "puff": false, "also": true},
	{"names": ["fridge"], "sounds": ["fridge_0"], "db": -12.0, "puff": false, "also": true},
	{"names": ["printer"], "sounds": ["printer_0"], "db": -14.0, "puff": true, "also": false},
	{"names": ["record_player", "records"], "sounds": ["needle_0"], "db": -14.0, "puff": false, "also": true},
	{"names": ["beanbag"], "sounds": ["pffft_0"], "db": -13.0, "puff": true, "also": false},
	{"names": ["sofa", "armchair", "wingback", "mattress"], "sounds": ["spring_0", "spring_1"], "db": -15.0, "puff": true, "also": false},
	{"names": ["rocking_horse", "toy_chest"], "sounds": ["squeak_0", "squeak_1"], "db": -14.0, "puff": true, "also": false},
	{"names": ["wheelchair", "trolley"], "sounds": ["roll_0", "roll_1"], "db": -14.0, "puff": false, "also": true},
]


## What a node is made of, from its name ("anchor_study_book_pile" → paper). Anything else is wood (furniture).
static func material_for(anchor_name: String) -> String:
	var n := anchor_name.to_lower().replace("anchor_", "")
	for entry in MATERIALS:
		for kw in entry[1]:
			if n.contains(String(kw)):
				return String(entry[0])
	return "wood"


static func _stream(stem: String) -> AudioStream:
	for base in [ROOM_SOUNDS, IMPACTS]:
		for ext in [".wav", ".ogg"]:
			var p: String = base + stem + ext
			if ResourceLoader.exists(p):
				return load(p) as AudioStream
	return null


static func _play_at(holder: Node, stream: AudioStream, at: Vector2, db: float, pitch: float = 1.0) -> void:
	if stream == null or holder == null or not holder.is_inside_tree():
		return
	var pl := AudioStreamPlayer2D.new()
	pl.stream = stream
	pl.volume_db = db
	pl.pitch_scale = pitch * randf_range(0.94, 1.06)
	pl.max_distance = 700.0
	pl.attenuation = 1.6
	holder.add_child(pl)
	pl.global_position = at
	pl.finished.connect(pl.queue_free)
	pl.play()


## The sound of a node's material, at `at`.
static func play_material_sound(holder: Node, material: String, at: Vector2) -> void:
	var spec: Array = SOUNDS.get(material, SOUNDS["wood"])
	var stems: Array = spec[0]
	_play_at(holder, _stream(String(stems[randi() % stems.size()])), at, float(spec[1]))


## The sound of a specific animation (a drawer scraping out…), at `at`.
static func play_kind_sound(holder: Node, kind: String, at: Vector2) -> void:
	if not KIND_SOUNDS.has(kind):
		return
	var spec: Array = KIND_SOUNDS[kind]
	var path: String = String(spec[0])
	if path.contains("%d"):
		path = path % (randi() % int(spec[1]))
	if ResourceLoader.exists(path):
		_play_at(holder, load(path) as AudioStream, at, float(spec[2]))


## Which nodes may startle a small creature, by their NAME (round 45d): piles / bags / boxes / bedding hide a rat, damp or food places a roach,
## cloth in a wardrobe a moth. `CRITTER_CHANCE` of them actually do, seeded per game + flat + node + run so a re-entry never re-rolls.
const CRITTER_NAMES := {
	"rat": ["clothes", "laundry", "bag", "boxes", "crates", "pallet", "trash", "sleeping", "mattress", "hamper", "backpack", "pile", "underbed"],
	"roach": ["sink", "cupboard", "oven", "pizza", "tins", "bucket", "larder", "units", "basin", "washer", "tub"],
	"moth": ["wardrobe", "clothes_rail", "quilt", "chest"],
}
const CRITTER_CHANCE := 0.14
const CRITTER_SQUEAK := "squeak_0"


## "rat" / "roach" / "moth" if this node startles one this game, else "". Pure: the same node answers the same every time.
static func critter_for(apartment_id: String, anchor_name: String) -> String:
	var n := anchor_name.to_lower().replace("anchor_", "")
	var kind := ""
	for k in ["moth", "rat", "roach"]:
		for kw in CRITTER_NAMES[k]:
			if kind == "" and n.contains(String(kw)):
				kind = k
	if kind == "":
		return ""
	var h: int = hash(str(WorldState.master_seed) + "critter" + apartment_id + anchor_name + str(WorldState.current_run))
	return kind if float(absi(h) % 1000) / 1000.0 < CRITTER_CHANCE else ""


## Let one out (if this node is due one): it runs away from the player's side of the node, over the floor of `holder`'s coordinates.
static func startle(node: Node2D, holder: Node) -> String:
	var kind := critter_for(String(node.get("apartment_id")), node.name)
	if kind == "" or holder == null:
		return ""
	var dir_x := 1.0 if (hash(node.name + str(WorldState.current_run)) % 2) == 0 else -1.0
	var player := node.get_tree().get_first_node_in_group("player") as Node2D
	if player != null:                                                    # away from the player
		dir_x = 1.0 if node.global_position.x >= player.global_position.x else -1.0
	if NodeCritter.spawn(holder, node.global_position + Vector2(0.0, -3.0), kind, dir_x, 120.0) == null:
		return ""
	if kind != "moth":
		_play_at(holder, _stream(CRITTER_SQUEAK), node.global_position, -16.0, 1.9)
	return kind


## The special-sound entry for a node's name ({} if it has none).
static func special_for(anchor_name: String) -> Dictionary:
	var n := anchor_name.to_lower().replace("anchor_", "")
	for entry in SPECIAL:
		var blocked := false
		for kw in entry.get("not", []):
			if n.contains(String(kw)):
				blocked = true
		if blocked:
			continue
		for kw in entry["names"]:
			if n.contains(String(kw)):
				return entry
	return {}


## Play a node's own sound. `with_specific` = a specific animation is playing too: only the entries marked `also` sound then. Returns whether one played.
static func play_special(holder: Node, anchor_name: String, at: Vector2, with_specific: bool) -> bool:
	var entry := special_for(anchor_name)
	if entry.is_empty() or (with_specific and not bool(entry["also"])):
		return false
	var stems: Array = entry["sounds"]
	_play_at(holder, _stream(String(stems[randi() % stems.size()])), at, float(entry["db"]))
	return true


static func puff(holder: Node, material: String, at: Vector2) -> void:
	if holder == null or not holder.is_inside_tree():
		return
	var spec: Array = PUFFS.get(material, PUFFS["wood"])
	var d := DustPuff.new()
	d.color = spec[0]
	d.count = int(spec[1])
	d.spread = float(spec[2])
	d.rise = float(spec[3])
	holder.add_child(d)
	d.global_position = at


## The generic reaction of a node that has no specific animation: dust / lint / paper and the sound of what it is made of.
## `dead` (a body's pockets): only a rustle, no dust.
static func play_generic(node: Node2D, dead: bool = false) -> String:
	var holder: Node = node.get_parent() if node.get_parent() != null else node
	var material := "cloth" if dead else material_for(node.name)
	var special: Dictionary = {} if dead else special_for(node.name)
	if not dead and (special.is_empty() or bool(special["puff"])):
		puff(holder, material, node.global_position + Vector2(0.0, -2.0))
	if special.is_empty() or not play_special(holder, node.name, node.global_position, false):
		play_material_sound(holder, material, node.global_position)
	return material
