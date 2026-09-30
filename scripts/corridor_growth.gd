extends RefCounted

## The corridor's OVERGROWTH (owner round 26 — the building changing): ivy climbing the walls, vines
## hanging from the ceiling, weeds and wildflowers through the floor, ferns, shrubs that have taken a
## corner, roots lifting the boards, moss and fungus in the damp. How MUCH is scripts/overgrowth.gd
## (depth × run); this file says WHERE and WHAT, and lays it over the corridor art.
##
## Same trick as the corridor's horror decals: a fixed number of CANDIDATES are generated in one fixed
## order per floor (seeded from master_seed + floor — never the run), each with a rising threshold, and
## the floor shows the prefix its level reaches. So what grew in run 1 is still there in runs 2 and 3,
## with more added, and a floor is identical every time you re-enter it. Small things (weeds, moss) come
## first; the big ones (shrubs, thick ivy, curtains of vine) only where it is well gone.
##
## Coordinates are the corridor art's LOCAL space (0..1120 × 0..192), like corridor_decals.gd. Growth
## sits over the decals and under the doors and every actor; moving kinds sway (scripts/sway.gd).

const CD := preload("res://scripts/corridor_decals.gd")
const Sway := preload("res://scripts/sway.gd")
const Overgrowth := preload("res://scripts/overgrowth.gd")

const DIR := "res://assets/growth/"
const META_PATH := "res://assets/growth/growth.json"
const SLOTS := 130
const CENTRES := 4                               # patches the growth spreads out from (overgrown AREAS, not confetti)
const CEILING_Y := 12.0                          # vines root just under the crown moulding
const SCONCE_LOCAL := [265.0, 392.0, 518.0, 647.0, 770.0]     # FloorLighting.SCONCE_X − the art's x (115)

# What each kind looks like as a schedule (shrubs are not here: not for the corridors — owner round 26): [first threshold it can appear at, weight, sprites by size (small → big)]
const KINDS := {
	"tuft": [0.0, 5.0, ["tuft_1", "tuft_2", "tuft_4", "tuft_3", "tuft_6", "tuft_5"]],
	"moss": [0.0, 2.5, ["moss_3", "moss_4", "moss_1", "moss_2"]],
	"flower": [0.04, 2.0, ["flower_1", "flower_2", "flower_3", "flower_4"]],
	"hang": [0.06, 3.5, ["hang_1", "hang_2", "hang_3", "hang_4", "hang_5", "hang_6", "hang_7"]],
	"creeper": [0.2, 3.0, ["creeper_4", "creeper_1", "creeper_2", "creeper_6", "creeper_3", "creeper_5"]],
	"fungus": [0.22, 1.2, ["fungus_1", "fungus_2", "fungus_3", "fungus_4"]],
	"fern": [0.25, 2.2, ["fern_1", "fern_2", "fern_3", "fern_4"]],
	"roots": [0.35, 1.6, ["roots_1", "roots_2", "roots_3"]],
}

static var _meta: Dictionary = {}


static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if data is Dictionary and data.get("sprites") is Dictionary:
			_meta = data["sprites"]
	return _meta


static func _tex(name: String) -> Texture2D:
	var p := DIR + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


static func _taken(floor_num: int, base_name: String) -> Array:
	var taken: Array = CD._taken_for(base_name)
	taken.append(Rect2(858, 38, 16, 14))                                    # the exit sign
	taken.append_array(load("res://scripts/floor_signs.gd").taken_local())  # stair / floor / lift signs
	for d in CD.DOORS:
		taken.append(Rect2(d + 32, 85, 7, 8))                                # light switches
	for sx in SCONCE_LOCAL:
		taken.append(Rect2(sx - 12.0, 40.0, 24.0, 30.0))                     # a lamp — never grown over
	return taken


static func _hits(taken: Array, r: Rect2) -> bool:
	for t in taken:
		if (t as Rect2).intersects(r):
			return true
	return false


## (Shrubs were tried and dropped — owner round 26: not for the corridors or the flats. The small ones live on balconies.)
static func _weight(kind: String, u: float) -> float:
	var w: float = float(KINDS[kind][1])
	if kind == "tuft" or kind == "moss":
		return w * maxf(0.3, 1.0 - 0.75 * u)              # the small stuff is what starts it; the big kinds take over
	if kind in ["hang", "creeper", "fern"]:
		return w * (1.0 + 1.6 * u)
	return w


static func _pick_kind(rng: RandomNumberGenerator, u: float) -> String:
	var total := 0.0
	for k in KINDS:
		if u >= float(KINDS[k][0]):
			total += _weight(String(k), u)
	var roll := rng.randf() * total
	for k in KINDS:
		if u < float(KINDS[k][0]):
			continue
		roll -= _weight(String(k), u)
		if roll <= 0.0:
			return String(k)
	return "tuft"


## The sprite of `kind` for a candidate at threshold u: bigger ones as it gets more overgrown.
static func _pick_sprite(rng: RandomNumberGenerator, kind: String, u: float) -> String:
	var list: Array = KINDS[kind][2]
	var top: int = clampi(int(ceil(float(list.size()) * (0.35 + 0.75 * u))), 1, list.size())
	return String(list[rng.randi() % top])


## Everything this floor grows at this run: [{name, pos (local), kind, thr}], stable.
static func plan(floor_num: int, run: int, base_name: String) -> Array:
	var level: float = Overgrowth.level(floor_num, run)
	var out: Array = []
	if level <= 0.0:
		return out
	var fixed: Array = _taken(floor_num, base_name)
	var placed_rects: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "corridor_growth" + str(floor_num))
	# the patches it spreads from: half at the two stairwell ends (the draughts, the broken glass), the
	# rest anywhere along the wall
	var centres: Array = []
	for k in range(CENTRES):
		var cx: float = rng.randf_range(CD.WALL_X.x, CD.WALL_X.y)
		if k < 2 and rng.randf() < 0.6:
			cx = CD.WALL_X.x + 40.0 if k == 0 else CD.WALL_X.y - 40.0
		centres.append(cx)
	for i in range(SLOTS):
		var thr: float = (float(i) + rng.randf()) / float(SLOTS)
		var kind: String = _pick_kind(rng, thr)
		var name: String = _pick_sprite(rng, kind, thr)
		var tex := _tex(name)
		# most of it clusters round a patch, which spreads wider as the candidate's threshold rises
		var near: float = float(centres[rng.randi() % centres.size()]) + rng.randfn(0.0, 55.0 + 230.0 * thr) if rng.randf() < 0.72 else -1.0
		var placed = _place(rng, fixed, placed_rects, kind, tex, near)   # ALWAYS drawn, so the stream never depends on the level
		if tex == null or placed == null:
			continue
		if thr < level:
			out.append({"name": name, "pos": placed, "kind": kind, "thr": thr})
	return out


## Where a sprite goes, by kind. Null if nothing fits. Consumes a fixed amount of the stream per try.
static func _place(rng: RandomNumberGenerator, fixed: Array, placed: Array, kind: String, tex: Texture2D, near: float = -1.0):
	if tex == null:
		return null
	var size := tex.get_size()
	for attempt in range(30):
		var x: float = roundf(rng.randf_range(CD.WALL_X.x, CD.WALL_X.y - size.x))
		if near >= 0.0 and attempt < 20:
			x = clampf(roundf(near - size.x * 0.5 + rng.randf_range(-24.0, 24.0)), CD.WALL_X.x, CD.WALL_X.y - size.x)
		var y: float
		var standing := false
		match kind:
			"hang":
				y = CEILING_Y
			"creeper":
				y = float(CD.SKIRT_TOP) + 2.0 - size.y
			"moss":
				y = float(CD.SKIRT_TOP) + 5.0 - size.y                    # low on the wall, over the skirting
			"fungus":
				if String(tex.resource_path).contains("fungus_1") or String(tex.resource_path).contains("fungus_2"):
					y = float(rng.randi_range(112, 146))                   # bracket fungus up the damp wall
				else:
					y = float(CD.FLOOR_Y) + float(rng.randi_range(3, 8)) - size.y
					standing = true
			"roots":
				y = float(CD.FLOOR_Y) + float(rng.randi_range(6, 16)) - size.y
			_:                                                             # tuft / flower / fern / shrub: on the floor
				y = float(CD.FLOOR_Y) + float(rng.randi_range(3, 9)) - size.y
				standing = kind != "tuft"
		var r := Rect2(Vector2(x, y), size)
		var floor_kind: bool = kind in ["tuft", "roots"] or (kind == "fungus" and standing)
		if not floor_kind:
			if kind in ["creeper", "moss", "hang", "fungus"]:
				if _on_door_face(r):
					continue                                   # ivy may frame a door, never cover its face
			elif kind in ["shrub", "fern", "flower"]:
				# a bush may stand in front of a door's edge (it has taken the corridor) but not its middle
				var cxm: float = r.position.x + r.size.x * 0.5
				var dead_on := false
				for d in CD.DOORS:
					if absf(cxm - float(d)) < 16.0:
						dead_on = true
				if dead_on or (r.end.x >= 874.0 and r.position.x <= 956.0):
					continue
			elif CD._blocked(r, false, true):
				continue
		# never over what's reserved (signs, lamps, the exit sign, the lift's plate)…
		if kind not in ["tuft", "roots", "moss"] and _hits(fixed, r):
			continue
		# …and the big kinds only partly overlap each other (ivy and vines may layer into a mass)
		if kind in ["fern", "shrub"] and _overlap_frac(placed, r, ["fern", "shrub"]) > 0.3:
			continue
		placed.append({"r": r, "kind": kind})
		return Vector2(x, y)
	return null


static func _on_door_face(r: Rect2) -> bool:
	if r.end.y < float(CD.DOOR_TOP):
		return false
	for d in CD.DOORS:
		if r.end.x >= float(d) - 24.0 and r.position.x <= float(d) + 24.0:
			return true
	# the lift and the maintenance door
	if r.end.x >= 874.0 and r.position.x <= 956.0 and r.end.y >= 64.0:
		return true
	if r.end.x >= 798.0 and r.position.x <= 830.0 and r.end.y >= 68.0:
		return true
	return false


static func _overlap_frac(placed: Array, r: Rect2, kinds: Array) -> float:
	var worst := 0.0
	for p in placed:
		if String(p["kind"]) in kinds:
			var i: Rect2 = (p["r"] as Rect2).intersection(r)
			if i.has_area():
				worst = maxf(worst, i.get_area() / maxf(1.0, r.get_area()))
	return worst


## Adds "CorridorGrowth" over the decals (under the doors and every actor).
static func add_to(root: Node, floor_num: int, run: int, base_name: String, art_pos: Vector2) -> void:
	if root.get_node_or_null("CorridorGrowth") != null:
		return
	var holder := Node2D.new()
	holder.name = "CorridorGrowth"
	holder.position = art_pos
	var items: Array = plan(floor_num, run, base_name)
	# back to front: what stands further up the wall first, floor things by their base
	items.sort_custom(func(a, b): return float(a["pos"].y) + _tex(a["name"]).get_size().y < float(b["pos"].y) + _tex(b["name"]).get_size().y)
	var m := meta()
	for d in items:
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("growth", d["name"])
		s.set_meta("growth_kind", d["kind"])
		var spec: Dictionary = Sway.GROWTH.get(String(m.get(d["name"], {}).get("kind", "")), {})
		if not spec.is_empty():
			Sway.apply_spec(s, spec, hash(str(WorldState.master_seed) + "gsway" + str(floor_num) + str(d["pos"])), run)
		holder.add_child(s)
	root.add_child(holder)
	var decals = root.get_node_or_null("CorridorDecals")
	if decals != null:
		root.move_child(holder, decals.get_index() + 1)
