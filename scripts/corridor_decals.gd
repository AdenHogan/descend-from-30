extends RefCounted
## Per-FLOOR decals over the baked corridor art, so no two floors look alike:
##   DRESSING — residents' things against the walls (plants, shoes, parcels, a chair, a scooter,
##              a kid's drawing...), fewer and more abandoned the deeper you go; later runs knock
##              some over and some are gone (people grabbed them and fled).
##   HORROR   — blood smeared along the walls, handprints, spatter, bullet holes, claw gouges,
##              scrawled messages, pools / drag trails / footprints on the floor, marks on doors.
##              More the DEEPER you go and the LATER in the day (run) it is.
## Everything is seeded per floor from master_seed and generated in one fixed order, then filtered
## by the floor + run: what a floor showed on run 1 is still there on runs 2 and 3, with more
## added. Positions avoid doors, the elevator, the extinguisher, the stair openings, the exit
## sign and everything the baked image already holds (assets/corridor/corridor_layout.json,
## written by tools/art/corridor.py). Sprites come from tools/art/corridor_decals.py.
## Coordinates are in the art's LOCAL space (0..1120 x 0..192, placed at CORRIDOR_ART_POS).

const DIR := "res://assets/corridor/decals/"
const LAYOUT_PATH := "res://assets/corridor/corridor_layout.json"
const DOORS := [201, 329, 455, 581, 714]      # local door centres (APARTMENT_X - 115); apt 5 .. 1
const FLOOR_Y := 160                           # the wall meets the floor
const SKIRT_TOP := 154
const DOOR_TOP := 74                           # door sprites cover y >= ~79 at DOORS ±28
const WALL_X := Vector2(116, 1004)             # between the two stair openings' casings
const HORROR_MAX := 1.5
const HORROR_SLOTS := 22
const DOOR_FACE_STATES := [0, 1, 2]           # WorldState.DoorState OPEN / SHUT_* show a plain face

# kind -> [min horror, weight, zone, sprites]. Zones: "hand" (hand height on the wall), "wall",
# "top" (the high wall, above the pictures), "slide" (down to the skirting), "floor", "door".
const HORROR := {
	"bullets": [0.0, 3.0, "wall", ["bullets_1", "bullets_2", "bullets_3"]],
	"hand": [0.0, 3.0, "hand", ["hand_1", "hand_2", "hand_3"]],
	"smear": [0.1, 3.0, "hand", ["smear_1", "smear_2", "smear_3"]],
	"casings": [0.1, 1.0, "floor", ["casings_1"]],
	"spatter": [0.15, 2.0, "wall", ["spatter_1", "spatter_2"]],
	"pool": [0.2, 2.0, "floor", ["pool_1", "pool_2", "pool_3"]],
	"door_hand": [0.2, 1.0, "door", ["door_hand"]],
	"door_bullets": [0.3, 1.0, "door", ["door_bullets"]],
	"prints": [0.3, 1.0, "floor", ["prints_1"]],
	"claws": [0.35, 1.0, "wall", ["claws_1", "claws_2"]],
	"slide": [0.4, 1.5, "slide", ["slide_1", "slide_2"]],
	"drag": [0.5, 1.0, "floor", ["drag_1", "drag_2"]],
	"scrawl": [0.55, 1.2, "top", ["scrawl_1", "scrawl_2", "scrawl_3", "scrawl_4", "scrawl_5", "scrawl_6"]],
	"door_x": [0.6, 1.0, "door", ["door_x"]],
}
const MAX_PER_KIND := {"scrawl": 2, "slide": 2, "drag": 2, "door_x": 2}
# resident things, by how far gone the floor is (corridor wear 0..4)
const DRESSING_KEPT := ["plant_tall", "plant_small", "umbrella", "shoes", "boots", "shoe_rack", "parcels",
	"chair", "scooter", "shopping_bag", "kid_drawing"]
const DRESSING_TIRED := ["plant_tall", "plant_dead", "parcels", "chair", "shoes", "suitcase",
	"shopping_bag", "notice_quarantine", "poster_missing"]
const DRESSING_GONE := ["plant_dead", "chair_down", "suitcase", "parcels", "poster_missing",
	"notice_quarantine", "shopping_bag"]
const WALL_DRESSING := ["kid_drawing", "notice_quarantine", "poster_missing"]

static var _layout: Dictionary = {}
static var _loaded := false


static func horror_level(floor_num: int, run: int) -> float:
	# 0.06 at the top on the first morning .. 1.5 at the bottom on the third night.
	var wear: int = clampi((29 - floor_num) / 6, 0, 4)
	return clampf(0.06 + 0.2 * wear + 0.32 * (run - 1), 0.0, HORROR_MAX)


static func _taken_for(base_name: String) -> Array:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(LAYOUT_PATH):
			var data = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
			if data is Dictionary and data.get("taken") is Dictionary:
				_layout = data["taken"]
	var out: Array = []
	for r in _layout.get(base_name, []):
		if r is Array and r.size() == 4:
			out.append(Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
	return out


## Everything this floor shows at this run: [{name, pos (local), layer "wall"/"door"}], stable.
static func plan(floor_num: int, run: int, base_name: String) -> Array:
	var taken: Array = _taken_for(base_name)
	taken.append(Rect2(858, 38, 16, 14))                      # the exit sign
	for d in DOORS:
		taken.append(Rect2(d + 32, 85, 7, 8))                 # light switches
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "corridor_decals" + str(floor_num))
	var wear: int = clampi((29 - floor_num) / 6, 0, 4)
	var out: Array = []
	# --- dressing: fixed per floor; later runs take some away / knock some over ---
	var pool: Array = DRESSING_KEPT if wear <= 1 else (DRESSING_TIRED if wear == 2 else DRESSING_GONE)
	var n_dress: int = 2 + rng.randi() % 3
	for i in range(n_dress):
		var name: String = pool[rng.randi() % pool.size()]
		var keep: float = rng.randf()
		var wall: bool = name in WALL_DRESSING
		var tex := _tex(name)
		if tex == null:
			continue
		var pos = _find(rng, taken, tex.get_size(), "poster" if wall else "stand")
		if pos == null:
			continue
		taken.append(Rect2(pos, tex.get_size()).grow(2))
		if (run >= 3 and keep < 0.55) or (run == 2 and keep < 0.3):
			continue                                          # gone: somebody took it, or it was cleared
		var shown := name
		if name == "plant_tall" and run >= 2 and keep < 0.75:
			shown = "plant_fallen"
		elif name == "chair" and run >= 3 and keep < 0.8:
			shown = "chair_down"
		var t2 := _tex(shown)
		var p2: Vector2 = pos
		if t2 != null and shown != name:                      # knocked over: same floor spot
			p2 = Vector2(pos.x, pos.y + tex.get_size().y - t2.get_size().y)
		out.append({"name": shown, "pos": p2, "layer": "wall"})
	# --- horror: HORROR_SLOTS candidates with rising thresholds; the floor + run shows a prefix ---
	var h := horror_level(floor_num, run)
	var per_kind := {}
	var doors_ok := _plain_doors(floor_num)
	for i in range(HORROR_SLOTS):
		var thr: float = HORROR_MAX * (float(i) + rng.randf()) / float(HORROR_SLOTS)
		var kind := _pick_kind(rng, thr, per_kind)
		if kind == "":
			continue
		var spec: Array = HORROR[kind]
		var sprites: Array = spec[3]
		var name: String = sprites[rng.randi() % sprites.size()]
		var tex := _tex(name)
		if tex == null:
			continue
		var zone: String = spec[2]
		var pos = null
		var layer := "wall"
		var door_plain := true
		if zone == "door":
			# the same draws every run (door states change between runs; the stream mustn't)
			layer = "door"
			var d: int = DOORS[rng.randi() % DOORS.size()]
			var sz := tex.get_size()
			pos = Vector2(d - sz.x / 2.0 + rng.randi_range(-8, 8), rng.randi_range(88, int(150 - sz.y)))
			door_plain = d in doors_ok
		else:
			pos = _find(rng, taken, tex.get_size(), zone)
		if pos == null:
			continue
		per_kind[kind] = int(per_kind.get(kind, 0)) + 1
		if layer == "wall":
			taken.append(Rect2(pos, tex.get_size()).grow(3))
		if thr < h and door_plain:
			out.append({"name": name, "pos": pos, "layer": layer})
	return out


static func _pick_kind(rng: RandomNumberGenerator, thr: float, per_kind: Dictionary) -> String:
	var total := 0.0
	var ok: Array = []
	for k in HORROR:
		var spec: Array = HORROR[k]
		if float(spec[0]) <= thr and int(per_kind.get(k, 0)) < int(MAX_PER_KIND.get(k, 99)):
			ok.append(k)
			total += float(spec[1])
	var r := rng.randf() * total
	for k in ok:
		r -= float(HORROR[k][1])
		if r <= 0.0:
			return k
	return ok.back() if not ok.is_empty() else ""


static func _plain_doors(floor_num: int) -> Array:
	# Doors that show a plain face (not barricaded / breached) — the only ones to mark.
	var out: Array = []
	for i in range(DOORS.size()):
		var apt: int = 5 - i                                  # DOORS runs apt 5 .. apt 1
		var st: int = WorldState.get_door_state(str(floor_num) + "0" + str(apt))
		if st in DOOR_FACE_STATES:
			out.append(DOORS[i])
	return out


static func _find(rng: RandomNumberGenerator, taken: Array, size: Vector2, zone: String):
	var y_lo := 30.0
	var y_hi := 130.0
	match zone:
		"hand":
			y_lo = 84.0; y_hi = 128.0
		"top":
			y_lo = 18.0; y_hi = 30.0
		"slide":
			y_lo = SKIRT_TOP - size.y; y_hi = y_lo
		"floor":
			y_lo = FLOOR_Y + 3.0; y_hi = 190.0 - size.y
		"stand":                                               # standing on the floor at the wall
			y_lo = FLOOR_Y + 4.0 - size.y; y_hi = y_lo
		"poster":
			y_lo = 40.0; y_hi = 124.0 - size.y
	var floor_zone := zone == "floor"
	for attempt in range(40):
		var x: float = float(rng.randi_range(8 if floor_zone else int(WALL_X.x), int((1112.0 if floor_zone else WALL_X.y) - size.x)))
		var y: float = float(rng.randi_range(int(y_lo), int(maxf(y_lo, y_hi))))
		var r := Rect2(Vector2(x, y), size)
		if _blocked(r, floor_zone):
			continue
		var hit := false
		for t in taken:
			if (t as Rect2).intersects(r):
				hit = true
				break
		if not hit:
			return Vector2(x, y)
	return null


static func _blocked(r: Rect2, floor_zone: bool) -> bool:
	if floor_zone:
		return false                                          # the floor runs under everything
	var y1 := r.end.y
	if y1 >= DOOR_TOP:
		for d in DOORS:
			if r.end.x >= d - 31 and r.position.x <= d + 31:
				return true
	if y1 >= 64 and r.end.x >= 874 and r.position.x <= 956:  # the elevator
		return true
	if y1 >= 68 and r.end.x >= 798 and r.position.x <= 830:  # the extinguisher / maintenance door
		return true
	return false


static func _tex(name: String) -> Texture2D:
	var p := DIR + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


## Adds "CorridorDecals" (wall + floor, right above the corridor art — under the doors) and
## "CorridorDoorDecals" (on the door faces — right after the Elevator, over the doors).
static func add_to(root: Node, floor_num: int, run: int, base_name: String, art_pos: Vector2) -> void:
	if root.get_node_or_null("CorridorDecals") != null:
		return
	var wall := Node2D.new()
	wall.name = "CorridorDecals"
	wall.position = art_pos
	var door := Node2D.new()
	door.name = "CorridorDoorDecals"
	door.position = art_pos
	for d in plan(floor_num, run, base_name):
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("decal", d["name"])
		(door if d["layer"] == "door" else wall).add_child(s)
	root.add_child(wall)
	var art = root.get_node_or_null("CorridorArt")
	if art != null:
		root.move_child(wall, art.get_index() + 1)
	root.add_child(door)
	var elev = root.get_node_or_null("Elevator")
	if elev != null:
		root.move_child(door, elev.get_index() + 1)
