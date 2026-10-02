extends RefCounted

## OVERGROWTH INSIDE THE FLATS (owner round 26): ivy on the walls, vines from the ceiling, weeds and
## wildflowers through the floorboards, ferns and shrubs that have taken a corner — and, in a flat still
## kept up, a houseplant in its pot (or, later, a dead one). How much is scripts/overgrowth.gd; WHERE is
## the module's growth map (tools/art/growth_map.py → assets/rooms/growth_meta.json): three skylines of
## clear rows over its 320 columns, so a sprite only goes where its whole width is clear of furniture
## (the module art is one baked picture — a sprite laid over furniture would sit in FRONT of it).
##
## Like the corridor (corridor_growth.gd) a fixed run of CANDIDATES is generated per module in one fixed
## order, seeded from master_seed + apartment + slot — never the run — each with a rising threshold, and
## the flat shows the prefix its level reaches: what grew in run 1 is still there in run 2, more added.
## Breached flats and flats holding one of the dead show none (their story is the point); a flat that is
## burning or burnt shows none. Growth sways (scripts/sway.gd) and is added on the balcony-descent
## backdrop too, so the flat below is already green as you climb down to it.

const CG := preload("res://scripts/corridor_growth.gd")
const Overgrowth := preload("res://scripts/overgrowth.gd")
const Sway := preload("res://scripts/sway.gd")

const META_PATH := "res://assets/rooms/growth_meta.json"
const DIR := "res://assets/growth/"
const W := 320
const SLOTS := 40
const MARGIN := 14                      # the perspective walls between modules cover the outer columns
const FOOTING := 3                       # rows of clear floor a standing plant needs under it
const BALCONY_X := 100                  # a balcony slot's doors occupy the left of the module
const POTS := ["pot_fern_1", "pot_fern_2", "pot_flowers_3", "pot_flowers_4", "pot_flowers_5", "pot_tall_6", "pot_tall_7"]
const DEAD_POTS := ["pot_dead_8", "pot_dead_9"]

# room kinds: how they sit — the skyline they fit, and the row their foot / root is on
const FIT := {
	"tuft": "up_floor", "flower": "up_floor", "fern": "up_floor", "shrub": "up_floor", "roots": "up_floor",
	"creeper": "up_wall", "moss": "up_wall", "hang": "down_ceil", "fungus": "up_wall",
}

# BALCONIES (owner round 26: "shrubs… shrink them a bit and add them to some balconies so balcony areas look
# varied and distinct sometimes"): the loggia (module x 12..88, floor at local y 96, rail at 64, lintel at 20)
# gets, by seed, a small shrub or a houseplant either side, a vine hanging from the lintel and one trailing
# over the rail. Which are there is seeded per (flat, slot) and only ever ADDS — from "sometimes" up top on
# the first morning to a green loggia low down by night.
const BAL_SHRUBS := ["shrub_small_1", "shrub_small_2", "shrub_small_3", "shrub_small_4"]
const BAL_VINES := ["hang_1", "hang_2", "hang_4", "hang_3"]
const BAL_FLOOR_Y := 96.0
const BAL_LEFT := 16.0
const BAL_RIGHT := 84.0
const BAL_LINTEL_Y := 20.0
const BAL_RAIL_Y := 62.0
const BAL_BASE_SHOW := 0.22             # the chance a slot is filled even on a clear floor

static var _maps: Dictionary = {}
static var _base: Dictionary = {}


static func maps() -> Dictionary:
	if _maps.is_empty() and FileAccess.file_exists(META_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if data is Dictionary and data.get("modules") is Dictionary:
			_maps = data["modules"]
			_base = data.get("base", {})
	return _maps


static func base_row(which: String) -> int:
	maps()
	return int(_base.get(which, {"floor": 116, "wall": 97, "ceil": 12}.get(which, 0)))


## The growth map for an art name ("living_room_b"), or {} if it has none.
static func map_for(art: String) -> Dictionary:
	return maps().get(art, {})


static func _tex(name: String) -> Texture2D:
	var p := DIR + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


## Clear room for a sprite `w` wide at column x0 on skyline `sky`: the smallest value over its columns.
static func clear_over(sky: Array, x0: int, w: int) -> int:
	var lo := 1 << 20
	for x in range(maxi(x0, 0), mini(x0 + w, W)):
		lo = mini(lo, int(sky[x]))
	return lo if lo < (1 << 20) else 0


## What this module grows at this run: [{name, pos (module-local), kind, thr}], stable per module.
## `art` is the module's art name; `slot` 0..2; `balcony` = a balcony's doors are in x < BALCONY_X.
static func plan(art: String, floor_num: int, apartment_id: String, slot: int, run: int, balcony: bool, fire_stage: int = -1) -> Array:
	var out: Array = []
	var m: Dictionary = map_for(art)
	if m.is_empty():
		return out
	var level: float = Overgrowth.room_level(floor_num, apartment_id, run, fire_stage)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "room_growth" + apartment_id + "/" + str(slot))
	var lo_x: int = BALCONY_X if balcony else MARGIN
	var placed: Array = []                                     # [{r, kind}]
	for i in range(SLOTS):
		var thr: float = (float(i) + rng.randf()) / float(SLOTS)
		var kind: String = CG._pick_kind(rng, thr)
		var name: String = CG._pick_sprite(rng, kind, thr)
		var tex := _tex(name)
		var pos = _place(rng, m, placed, kind, tex, lo_x)   # ALWAYS drawn: the stream never depends on the level
		if tex != null and pos != null and thr < level:
			out.append({"name": name, "pos": pos, "kind": kind, "thr": thr})
	# a houseplant, if the flat is still kept — independent of the wild growth
	var hp = _houseplant(rng, m, placed, floor_num, run, lo_x)
	if hp != null:
		out.append(hp)
	return out


static func _place(rng: RandomNumberGenerator, m: Dictionary, placed: Array, kind: String, tex: Texture2D, lo_x: int):
	if tex == null or not FIT.has(kind):
		return null
	var size := tex.get_size()
	var sky: Array = m.get(FIT[kind], [])
	if sky.size() < W:
		return null
	var base_key: String = "ceil" if kind == "hang" else ("floor" if String(FIT[kind]) == "up_floor" else "wall")
	var base: float = float(base_row(base_key))
	# Ivy and vines only go over bare wall. Plants standing on the FLOOR only need their footing clear: the
	# floor line is in front of the furniture that stands against the back wall, so a fern beside a sofa
	# is a fern beside a sofa (the nodes draw over it, and it never hides one).
	var need: int = int(size.y) - int(size.y * 0.25) if kind in ["creeper", "hang"] else (int(size.y) if kind in ["moss", "fungus"] else FOOTING)
	for attempt in range(30):
		var x: int = rng.randi_range(lo_x, int(W - MARGIN - size.x))
		if clear_over(sky, x, int(size.x)) < need:
			continue
		var y: float = base if kind == "hang" else base - size.y
		if kind == "moss" or kind == "roots":
			y = base + 1.0 - size.y
		if kind == "fungus" and String(tex.resource_path).contains("fungus_1") or String(tex.resource_path).contains("fungus_2"):
			y = base - size.y - float(rng.randi_range(6, 26))
		var r := Rect2(Vector2(x, y), size)
		if kind in ["fern", "shrub", "creeper"] and CG._overlap_frac(placed, r, ["fern", "shrub", "creeper"]) > 0.3:
			continue
		placed.append({"r": r, "kind": kind})
		return Vector2(x, y)
	return null


## A tended houseplant: more likely in a kept-up flat and high in the building; dead ones grow likelier
## later in the day and lower down. Null if this flat has none. It only ever stands where its WHOLE height is clear of
## furniture (owner round 34 — "an out of place plant on a stool just randomly in front of other art items"): the old rule
## asked only for a clear footing, so a pot could stand in front of a dresser or a bed's end with its fronds over them.
static func _houseplant(rng: RandomNumberGenerator, m: Dictionary, placed: Array, floor_num: int, run: int, lo_x: int):
	var depth: float = WorldState.infection_depth(floor_num)
	var has: float = rng.randf()
	var style_roll: float = rng.randf()
	var pick: int = rng.randi()
	var x_roll: int = rng.randi()
	if has > 0.5 - 0.2 * depth:
		return null
	var dead: bool = style_roll < clampf(0.05 + 0.45 * depth + 0.22 * float(run - 1), 0.0, 0.9)
	var list: Array = DEAD_POTS if dead else POTS
	var name: String = String(list[pick % list.size()])
	var tex := _tex(name)
	if tex == null:
		return null
	var size := tex.get_size()
	var sky: Array = m.get("up_floor", [])
	if sky.size() < W:
		return null
	for k in range(24):
		var x: int = lo_x + int((x_roll + k * 37) % maxi(1, int(W - MARGIN - size.x) - lo_x))
		if clear_over(sky, x, int(size.x)) < int(size.y):      # the whole plant, not just its footing, in the open
			continue
		var r := Rect2(Vector2(x, float(base_row("floor")) - size.y), size)
		if CG._overlap_frac(placed, r, ["fern", "shrub"]) > 0.15:
			continue
		return {"name": name, "pos": r.position, "kind": "potted", "thr": 0.0}
	return null


## Lay the growth on a module instance (a Node2D at the module's origin): a "Growth" node straight above its art.
static func add_to(module: Node, art: String, floor_num: int, apartment_id: String, slot: int, run: int, balcony: bool, fire_stage: int = -1) -> void:
	if module.get_node_or_null("Growth") != null:
		return
	var items: Array = plan(art, floor_num, apartment_id, slot, run, balcony, fire_stage)
	if items.is_empty():
		return
	var holder := Node2D.new()
	holder.name = "Growth"
	items.sort_custom(func(a, b): return float(a["pos"].y) + _tex(a["name"]).get_size().y < float(b["pos"].y) + _tex(b["name"]).get_size().y)
	var meta: Dictionary = CG.meta()
	for d in items:
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("growth", d["name"])
		s.set_meta("growth_kind", d["kind"])
		var spec: Dictionary = Sway.growth_spec(meta.get(d["name"], {}))
		if not spec.is_empty():
			Sway.apply_spec(s, spec, hash(str(WorldState.master_seed) + "rsway" + apartment_id + str(slot) + str(d["pos"])), run)
		holder.add_child(s)
	module.add_child(holder)
	var art_node = module.get_node_or_null("Art")
	if art_node != null:
		module.move_child(holder, art_node.get_index() + 1)


## The balcony's plants: [{name, pos (module-local), kind, thr}]. Slots: 0 left of the doorway, 1 right,
## 2 a vine from the lintel, 3 a vine trailing over the rail. Stable per (flat, slot), only ever adds.
static func balcony_plan(floor_num: int, apartment_id: String, slot: int, run: int) -> Array:
	var out: Array = []
	var level: float = Overgrowth.level(floor_num, run)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "balcony_growth" + apartment_id + "/" + str(slot))
	var dead_roll: float = 0.0
	for i in range(4):
		var u: float = rng.randf()                       # the slot's threshold
		var pick: int = rng.randi()
		var jit: float = rng.randf_range(-4.0, 4.0)
		var pot: bool = rng.randf() < 0.4
		dead_roll = rng.randf()
		var show: bool = u < BAL_BASE_SHOW + (1.0 - BAL_BASE_SHOW) * level
		if not show:
			continue
		var name: String
		var pos: Vector2
		var kind: String
		if i < 2:
			if pot:
				var dead: bool = dead_roll < clampf(0.1 + 0.3 * float(run - 1) + 0.3 * WorldState.infection_depth(floor_num), 0.0, 0.85)
				var list: Array = DEAD_POTS if dead else POTS
				name = String(list[pick % list.size()])
				kind = "potted"
			else:
				name = String(BAL_SHRUBS[pick % BAL_SHRUBS.size()])
				kind = "shrub"
			var tex := _tex(name)
			if tex == null:
				continue
			var sz := tex.get_size()
			var edge: float = absf(jit)                          # 0..4 px in from the casing
			var px: float = BAL_LEFT + edge if i == 0 else BAL_RIGHT - sz.x - edge
			pos = Vector2(roundf(px), BAL_FLOOR_Y - sz.y)
		else:
			name = String(BAL_VINES[pick % BAL_VINES.size()])
			kind = "hang"
			var tex2 := _tex(name)
			if tex2 == null:
				continue
			var x: float = 24.0 + float(pick % 40) + jit if i == 2 else 22.0 + float(pick % 44) + jit
			# a lintel vine hangs from the top; the rail vine starts at the rail but never trails past the floor
			var y0: float = BAL_LINTEL_Y if i == 2 else minf(BAL_RAIL_Y, 98.0 - tex2.get_size().y)
			pos = Vector2(clampf(roundf(x), 12.0, 88.0 - tex2.get_size().x), y0)
		out.append({"name": name, "pos": pos, "kind": kind, "thr": u})
	return out


## Lay the balcony's plants over its art (a "BalconyGrowth" node straight after the module's Balcony node).
static func add_balcony_to(module: Node, floor_num: int, apartment_id: String, slot: int, run: int) -> void:
	if module.get_node_or_null("BalconyGrowth") != null:
		return
	var items: Array = balcony_plan(floor_num, apartment_id, slot, run)
	if items.is_empty():
		return
	var holder := Node2D.new()
	holder.name = "BalconyGrowth"
	var meta: Dictionary = CG.meta()
	for d in items:
		var s := Sprite2D.new()
		s.texture = _tex(d["name"])
		s.centered = false
		s.position = d["pos"]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.set_meta("growth", d["name"])
		s.set_meta("growth_kind", d["kind"])
		var spec: Dictionary = Sway.growth_spec(meta.get(d["name"], {})).duplicate()
		if not spec.is_empty():
			spec["amp"] = float(spec["amp"]) * 1.3                 # out in the open air: it catches more wind (still capped at 1 texel)
			Sway.apply_spec(s, spec, hash(str(WorldState.master_seed) + "bsway" + apartment_id + str(slot) + str(d["pos"])), run)
		holder.add_child(s)
	module.add_child(holder)
	var bal = module.get_node_or_null("Balcony")
	if bal != null:
		module.move_child(holder, bal.get_index() + 1)
