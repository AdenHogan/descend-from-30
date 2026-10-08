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

const Sway := preload("res://scripts/sway.gd")
const DIR := "res://assets/corridor/decals/"
const LAYOUT_PATH := "res://assets/corridor/corridor_layout.json"
const DOORS := [201, 329, 455, 581, 714]      # local door centres (APARTMENT_X - 115); apt 5 .. 1
const LANE_Y := 419.0                          # the walking line (every actor's feet, world Y) — bodies are searched from it
const FLOOR_Y := 160                           # the wall meets the floor
const SKIRT_TOP := 154
const DOOR_TOP := 74                           # door sprites cover y >= ~79 at DOORS ±28
const WALL_X := Vector2(116, 1004)             # between the two stair openings' casings
const HORROR_MAX := 1.5
const HORROR_SLOTS := 22
const DOOR_FACE_STATES := [0, 1, 2]           # WorldState.DoorState OPEN / SHUT_* show a plain face

# kind -> [min horror, weight, zone, sprites]. Zones: "hand" (hand height on the wall), "wall",
# "top" (the high wall, up under the ceiling), "slide" (down to the skirting), "floor", "door".
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
# (owner round 24: "things like shoe racks, or trash, or plants, or other outside things. the occasional
# bicycle" — the corridor carries what residents leave outside their doors, not picture frames)
# Round 24b ("they are very flat and on the wall… it needs to have geometry and weight to it. AND logic"):
# the standing things are drawn with volume (tools/art/corridor_props.py) and each has a RULE for where it
# goes — "door": beside a flat's door (shoes, a rack, an umbrella stand, parcels, a pram, the bins put out,
# a bike leant on the wall); "open": a stretch of wall between the doors or by the lift (a planter, a small
# plant up on its stand, a hall chair to wait on) — and its depth on the floor (assets/corridor/decals/
# dressing.json, written by the art tool).
# Round 24e: shoes stand on a boot TRAY, the small things sit on a HALL TABLE / shoe cabinet by the door,
# and every prop has VARIANTS (sprites <base>__2, __3 — dressing_variants picks one per placement).
const DRESSING_KEPT := ["plant_tall", "plant_stand", "umbrella_stand", "shoe_tray", "shoe_tray", "shoe_rack",
	"hall_table", "hall_table", "parcels", "chair", "scooter", "shopping_bag", "kid_drawing", "bicycle", "kids_bike",
	"pram", "bin_bags", "recycling_box", "newspapers",
	"notice_meeting", "notice_bins", "notice_smoking", "notice_quiet", "notice_water", "notice_lift"]
const DRESSING_TIRED := ["plant_tall", "plant_dead", "parcels", "chair", "shoe_tray", "suitcase", "bin_bags", "hall_table",
	"bin_bags", "recycling_box", "bicycle", "shoe_rack", "newspapers", "plant_stand",
	"shopping_bag", "notice_quarantine", "poster_missing", "notice_lift", "notice_water", "notice_evac"]
const DRESSING_GONE := ["plant_dead", "chair_down", "suitcase", "parcels", "poster_missing", "bin_bags",
	"bin_bags", "bicycle_wrecked", "pram", "newspapers", "plant_stand_fallen",
	"notice_quarantine", "shopping_bag", "notice_evac", "notice_curfew", "notice_dont_open"]
# building notices (owner round 23 — "a variety of notices for the building"), readable, per floor
const WALL_DRESSING := ["kid_drawing", "notice_quarantine", "poster_missing", "notice_lift", "notice_water",
	"notice_meeting", "notice_bins", "notice_smoking", "notice_quiet", "notice_evac", "notice_curfew",
	"notice_dont_open"]
# THE DEAD (owner round 21c): someone lying where they fell — in a pool, or at the end of the trail
# they crawled. A separate seeded pass (its own RNG, so the dressing/horror draws above never move),
# up to two per floor, each appearing once the floor's horror level passes its seeded threshold and
# staying for the later runs. Sprite bottom row - DEAD_FOOT = the body's floor line.
const DEAD := ["dead_1", "dead_2", "dead_3", "dead_4", "dead_5", "dead_6"]   # 5-6: took one of them with them (round 22)
const DEAD_FOOT := 6
const DEAD_LINE := Vector2(168, 184)             # the floor lines a body may lie on (feet line 176)
const DEAD_THRESHOLDS := [0.3, 0.85]             # + up to 0.5 each, per floor
const DEAD_CHANCE := 0.55                        # not every floor, even when it's bad enough

const META_PATH := "res://assets/corridor/decals/dressing.json"
# what a prop becomes when it's been knocked over / gone through, later in the day
const KNOCKED := {"plant_tall": "plant_fallen", "chair": "chair_down", "bicycle": "bicycle_wrecked",
	"plant_stand": "plant_stand_fallen"}
const DOOR_FRAME := 27.0                          # a door's face + frame, either side of its centre
# the "open" spots: the wall between each pair of doors (under its sconce) and beside the lift
const OPEN_SPOTS := [265.0, 392.0, 518.0, 647.0, 852.0]

static var _layout: Dictionary = {}
static var _loaded := false
static var _meta: Dictionary = {}


static func horror_level(floor_num: int, run: int) -> float:
	# 0.06 at the top on the first morning .. 1.5 at the bottom on the third night.
	@warning_ignore("integer_division")
	var wear: int = clampi((29 - floor_num) / 6, 0, 4)
	return clampf(0.06 + 0.2 * wear + 0.32 * (run - 1), 0.0, HORROR_MAX)


## What corridor_props.py recorded for a standing prop: {rule, depth, contact} (empty if none).
static func dressing_meta(name: String) -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if data is Dictionary and data.get("props") is Dictionary:
			_meta = data["props"]
	return _meta.get(name, {})


## A prop's base name (its variants are <base>__2, <base>__3 ...).
static func base_of(sprite: String) -> String:
	return sprite.split("__")[0]


## Every sprite drawn for base prop `base` (the base itself first), from dressing.json.
static func dressing_variants(base: String) -> Array:
	dressing_meta(base)                                        # loads the table
	var out: Array = []
	for k in _meta:
		if base_of(str(k)) == base:
			out.append(str(k))
	out.sort()
	return out if not out.is_empty() else [base]


## The sprite's top so its front floor contact lands `depth` in front of the skirting (its back on it).
static func standing_y(name: String) -> float:
	var m := dressing_meta(name)
	var tex := _tex(name)
	var contact := float(m.get("contact", (tex.get_size().y - 1.0) if tex != null else 0.0))
	return float(FLOOR_Y) + float(m.get("depth", 4)) - contact


## Somewhere with a REASON to be: beside a door (just outside its frame), or on an open stretch of wall
## between the doors / by the lift. Null if nothing fits.
static func _place_standing(rng: RandomNumberGenerator, taken: Array, name: String, size: Vector2):
	var rule := str(dressing_meta(name).get("rule", "door"))
	var y := standing_y(name)
	for attempt in range(24):
		var x: float
		if rule == "open":
			x = float(OPEN_SPOTS[rng.randi() % OPEN_SPOTS.size()]) - size.x / 2.0 + float(rng.randi_range(-3, 3))
		else:
			var d: float = float(DOORS[rng.randi() % DOORS.size()])
			var gap := float(rng.randi_range(1, 6))
			x = d + DOOR_FRAME + gap if rng.randf() < 0.5 else d - DOOR_FRAME - gap - size.x
		x = roundf(x)
		var r := Rect2(Vector2(x, y), size)
		if x < WALL_X.x or r.end.x > WALL_X.y or _blocked(r, false, true):
			continue
		var hit := false
		for t in taken:
			if (t as Rect2).intersects(r):
				hit = true
				break
		if not hit:
			return Vector2(x, y)
	return null


## Where a sprite of width `w` stands inside the span reserved for it (the span may be wider — room kept
## for its knocked-over version): centred on an open spot, or hugging the door it stands by.
static func _fit_in_span(span_x: float, span_w: float, w: float, name: String) -> float:
	if span_w <= w:
		return span_x
	if str(dressing_meta(name).get("rule", "door")) == "open":
		return roundf(span_x + (span_w - w) / 2.0)
	var cx := span_x + span_w / 2.0
	var nearest: float = float(DOORS[0])
	for d in DOORS:
		if absf(float(d) - cx) < absf(nearest - cx):
			nearest = float(d)
	return span_x + span_w - w if cx < nearest else span_x


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
static func plan(floor_num: int, run: int, base_name: String, extra_taken: Array = [], horror_boost: float = 0.0) -> Array:
	var taken: Array = _taken_for(base_name)
	taken.append_array(extra_taken)                           # the caller's own keep-clear rects (the tutorial's wall text, the lift...)
	taken.append(Rect2(858, 38, 16, 14))                      # the exit sign
	taken.append_array(load("res://scripts/floor_signs.gd").taken_local())   # stair / floor / lift signs, door plates
	for d in DOORS:
		taken.append(Rect2(d + 32, 85, 7, 8))                 # light switches
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "corridor_decals" + str(floor_num))
	@warning_ignore("integer_division")
	var wear: int = clampi((29 - floor_num) / 6, 0, 4)
	var out: Array = []
	# --- dressing: fixed per floor; later runs take some away / knock some over ---
	var pool: Array = DRESSING_KEPT if wear <= 1 else (DRESSING_TIRED if wear == 2 else DRESSING_GONE)
	var n_dress: int = 4 + rng.randi() % 3
	for i in range(n_dress):
		var base: String = pool[rng.randi() % pool.size()]
		var keep: float = rng.randf()
		var wall: bool = base in WALL_DRESSING
		var vroll: int = rng.randi()
		var variants := [base] if wall else dressing_variants(base)
		var name: String = variants[vroll % variants.size()]
		var tex := _tex(name)
		if tex == null:
			continue
		var pos = null
		var span := tex.get_size()
		if wall:
			pos = _find(rng, taken, span, "poster")
		else:
			if KNOCKED.has(base):                             # room for it if it's knocked over later
				var kv := dressing_variants(str(KNOCKED[base]))
				var k2 := _tex(str(kv[vroll % kv.size()]))
				if k2 != null:
					span.x = maxf(span.x, k2.get_size().x)
			pos = _place_standing(rng, taken, name, span)
		if pos == null:
			continue
		taken.append(Rect2(pos, span).grow(2))
		if (run >= 3 and keep < 0.55) or (run == 2 and keep < 0.3):
			continue                                          # gone: somebody took it, or it was cleared
		var shown := name
		var knocked := (base == "plant_tall" and run >= 2 and keep < 0.75) \
			or (base == "plant_stand" and run >= 2 and keep < 0.7) \
			or (base in ["chair", "bicycle"] and run >= 3 and keep < 0.8)
		if knocked:
			var kv2 := dressing_variants(str(KNOCKED[base]))
			shown = str(kv2[vroll % kv2.size()])
		var p2: Vector2 = pos
		if not wall:                                          # stood on the floor at its own depth
			p2.y = standing_y(shown)
			p2.x = _fit_in_span(pos.x, span.x, _tex(shown).get_size().x, name)
		out.append({"name": shown, "pos": p2, "layer": "wall"})
	# --- horror: HORROR_SLOTS candidates with rising thresholds; the floor + run shows a prefix ---
	var h := horror_level(floor_num, run) + horror_boost
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


## The dead lying on this floor at this run: [{name, pos (local), flip}], stable per floor.
static func dead_plan(floor_num: int, run: int, avoid: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "corridor_dead" + str(floor_num))
	var h := horror_level(floor_num, run)
	var out: Array = []
	var taken: Array = avoid.duplicate()
	for i in range(DEAD_THRESHOLDS.size()):
		var thr: float = float(DEAD_THRESHOLDS[i]) + rng.randf() * 0.5
		var gate: bool = rng.randf() < DEAD_CHANCE
		var name: String = DEAD[rng.randi() % DEAD.size()]
		var flip: bool = rng.randf() < 0.5
		var tex := _tex(name)
		var pos = null
		for attempt in range(30):
			if tex == null:
				break
			var sz := tex.get_size()
			var x := float(rng.randi_range(int(WALL_X.x), int(WALL_X.y - sz.x)))
			var line := float(rng.randi_range(int(DEAD_LINE.x), int(DEAD_LINE.y)))
			var r := Rect2(Vector2(x, line + DEAD_FOOT - sz.y), sz)
			var hit := false
			for t in taken:
				if (t as Rect2).intersects(r.grow(4)):
					hit = true
					break
			if not hit and pos == null:
				pos = r.position
		if pos == null:
			continue
		taken.append(Rect2(pos, tex.get_size()))
		if gate and thr < h:
			out.append({"name": name, "pos": pos, "flip": flip, "idx": i})
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
		"poster":                                              # pinned up in the band just over the rail —
			y_lo = 58.0; y_hi = 94.0 - size.y                  # never up by the ceiling (owner round 24)
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


static func _blocked(r: Rect2, floor_zone: bool, standing: bool = false) -> bool:
	if floor_zone:
		return false                                          # the floor runs under everything
	var y1 := r.end.y
	if y1 >= DOOR_TOP:
		# a door face is ±23; things standing on the floor may come up to its frame (a bike leant
		# between two doors), anything on the wall keeps clear of the plate / switch beside it too
		var m := 27.0 if standing else 31.0
		for d in DOORS:
			if r.end.x >= d - m and r.position.x <= d + m:
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
static func add_to(root: Node, floor_num: int, run: int, base_name: String, art_pos: Vector2, extra_taken: Array = [], horror_boost: float = 0.0) -> void:
	if root.get_node_or_null("CorridorDecals") != null:
		return
	var wall := Node2D.new()
	wall.name = "CorridorDecals"
	wall.position = art_pos
	var door := Node2D.new()
	door.name = "CorridorDoorDecals"
	door.position = art_pos
	var floor_rects: Array = []
	# A SCRIPTED body (owner round 37: Alex finds a neighbour dead on floor 29): reserved before the dressing is planned, so nothing is
	# dropped on top of it, then laid first among the dead below.
	var story: Dictionary = CharacterStory.alex_body(floor_num)
	var story_tex: Texture2D = _tex(String(story["name"])) if not story.is_empty() else null
	var story_rect := Rect2()
	if story_tex != null:
		var sz0: Vector2 = story_tex.get_size()
		story["pos"] = Vector2(float(story["pos"].x), (DEAD_LINE.x + DEAD_LINE.y) * 0.5 + DEAD_FOOT - sz0.y)
		story_rect = Rect2(story["pos"], sz0)
		extra_taken = extra_taken + [story_rect.grow(24)]
	for d in plan(floor_num, run, base_name, extra_taken, horror_boost):
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("decal", d["name"])
		# Standing plants lean in the draught (scripts/sway.gd) — seeded per floor + place so no two move in step.
		Sway.apply(s, base_of(d["name"]), hash(str(WorldState.master_seed) + "sway" + str(floor_num) + str(d["pos"])), run)
		(door if d["layer"] == "door" else wall).add_child(s)
		if float(d["pos"].y) >= FLOOR_Y and s.texture != null:
			floor_rects.append(Rect2(d["pos"], s.texture.get_size()))
	var deads: Array = dead_plan(floor_num, run, floor_rects + ([story_rect.grow(24)] if story_tex != null else []))
	if story_tex != null:
		deads.push_front(story)
	for d in deads:
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.flip_h = bool(d["flip"])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("decal", d["name"])
		s.add_to_group("corridor_dead")
		wall.add_child(s)
		# ...and they can be searched: an invisible interact zone on the walking lane over the body
		var bz = load("res://scripts/corridor_body.gd").new()
		bz.floor_num = floor_num
		bz.body_name = "cdead_%d" % int(d["idx"])
		bz.half_width = maxf(28.0, s.texture.get_size().x * 0.5)
		bz.name = "Body_" + bz.body_name
		bz.position = Vector2(d["pos"].x + s.texture.get_size().x * 0.5, LANE_Y - art_pos.y)
		wall.add_child(bz)
		if d is Dictionary and d.get("idx", 0) == story.get("idx", -1) and story_tex != null:
			var trig = load("res://scripts/story_trigger.gd").new()    # walk up to it and the beat plays
			trig.story = "alex_body"
			trig.name = "StoryAlexBody"
			trig.position = bz.position
			wall.add_child(trig)
		var f := Node2D.new()                                     # flies over them
		var sz: Vector2 = s.texture.get_size()
		f.position = d["pos"] + Vector2(sz.x - 24.0 if not s.flip_h else 24.0, sz.y - 14.0)
		f.set_meta("kind", "flies")
		f.set_meta("color", "1a1414")
		f.set_meta("w", 12)
		f.set_meta("h", 7)
		f.set_script(load("res://scripts/module_anim.gd"))
		wall.add_child(f)
	root.add_child(wall)
	var art = root.get_node_or_null("CorridorArt")
	if art != null:
		root.move_child(wall, art.get_index() + 1)
	root.add_child(door)
	var elev = root.get_node_or_null("Elevator")
	if elev != null:
		root.move_child(door, elev.get_index() + 1)
