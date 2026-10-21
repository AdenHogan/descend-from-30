class_name FurniturePlanner
extends RefCounted

## FURNITURE AS ASSETS — the planner (owner round 47: "converting all art furniture and objects into their own assets… that a seed can natively place in procedural items so even two
## versions of a bedroom module A will have variance… just because an item is currently in a bedroom doesn't mean it can't also be in another room — some rule and logic needs to be
## in place, we do not ever need a bed in a kitchen. So intelligent design needs to apply").
##
## Every piece of furniture / object is its OWN sprite (tools/art/furnlib.py + furn_<room>.py → assets/furniture/, data/furniture.json) with a record of what it is: the PLANE it stands
## on (wall / front / decor / rug / floor / top / ceiling), the ROOMS and STYLES it belongs in, its TAGS, where its scavenge nodes / lights / slots are. This file puts them in a room
## from a seed — a pure function (same seed → same room, on every machine, on every re-entry; nothing here is random in the unseeded sense).
##
## THE LOGIC (every rule is data, `rules` + each piece's record, and `validate()` re-checks any plan against all of it — tests/furniture_test.gd runs that over thousands of seeds):
##   * a piece is only ever drawn from the room's own pool: `rooms` {room type: weight} AND `styles` {style: weight} must both list it, and a piece carrying a tag in `rules.tag_rooms`
##     may not be in a room that table does not allow (a "sleeping" piece is a bedroom thing, so a kitchen can never get a bed — even if someone mis-registers one);
##   * the wall line is exclusive (two wardrobes never overlap, a bed is never in front of a dresser), nothing tall stands in front of the room's window, nothing is closer than the edge
##     columns, everything on the floor lies behind the walking lane (feet ≤ 122), and nothing standing or lying on the floor is in a step-up spot's stand zone (the player is drawn over
##     everything baked, so a body there would be walked over — owner rounds 36i / 36k / 45b);
##   * things on top (a lamp, a glass) stand on a surface that has a slot for them; hung things (pictures) hang clear of every piece and of the window; clutter lies near what it belongs to;
##   * a room always has enough to search: ≥ `min_front` scavenge nodes reachable from the walking lane (the old per-module rule), and a plan that can't be made falls back to a hand-set one.
##
## Coordinates: module pixels (the module is 320 × 144; the lane / feet line 129, the wall seam 100). An item's (x, y) is where its reference point R lands — the front-left corner of a body at its
## feet row, the top-left of a hung picture, the top centre of a ceiling light; data/furniture.json gives each sprite's R inside it (`rx`, `ry`) and its drawn extent around R (l, r, t, b).

const DATA_PATH := "res://data/furniture.json"
const SPRITE_DIR := "res://assets/furniture/"

const MODULE_W := 320
const EDGE_L := 4                  # nothing inside the side-wall sample columns (x 3 / 316) and a margin
const EDGE_R := 315
const TOP_MIN_Y := 5               # below the crown moulding (a ceiling light is the exception)
const LANE_CLEAR_ROW := 122        # the lowest row anything standing / lying on the floor may reach (pixlib.LANE_CLEAR_ROW)
const STAND_TOP_ROW := 102         # the step-up spot's stand zone rows (pixlib.BP_ROWS)
const STAND_HALF := 14             # the player's half width up there (13) + a pixel
const BP_CLUSTER := 40             # nodes this close share a spot (room.gd BACK_SPOT_CLUSTER)
const FRONT_NODE_MIN_Y := 66       # a node higher than this is out of reach from the walking lane (pixlib.FRONT_NODE_MIN_Y)
const WANT_TRIES := 4              # how many spots a recipe's `want` tag is tried at before the room carries on without it
const NODE_MIN_Y := 46             # no node higher than this at all: from the step-up plane (player origin y 82) a node more than ~44 px away in a straight line cannot be searched, and the window sits above
const PLANE_ORIGIN_Y := 82         # the player's origin (module-local y) while stepped up at a set-back piece — room.gd back_spot_groups
const WINDOW_INSET := 72           # room.MODULE_WINDOW_INSET
const WINDOW_HALF_W := 22
const WINDOW_Y0 := 10
const WINDOW_Y1 := 66
const MAX_TRIES := 48
const SPOTS_PER_PIECE := 14        # x candidates tried for one piece before it is given up on
const DEFAULT_LIMIT := {"wall": 1, "front": 1, "floor": 2, "top": 2, "decor": 2, "rug": 1, "ceiling": 1}

static var _data: Dictionary = {}
static var _loaded := false


# ------------------------------------------------------------------------------------------------------------------------------------ data
static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
	return _data


static func piece(id: String) -> Dictionary:
	return data().get("items", {}).get(id, {})


static func recipe(room_type: String, style: String) -> Dictionary:
	return data().get("recipes", {}).get(room_type + "/" + style, {})


## The styles a room type has recipes for: [{style, weight, shell}] (stable order).
static func styles_of(room_type: String) -> Array:
	var out: Array = []
	var recs: Dictionary = data().get("recipes", {})
	var keys: Array = recs.keys()
	keys.sort()
	for k in keys:
		if String(k).begins_with(room_type + "/"):
			out.append({"style": String(k).substr(room_type.length() + 1), "weight": float(recs[k].get("weight", 1.0)), "shell": String(recs[k].get("shell", ""))})
	return out


## Is this room type laid by the planner at all (has recipes + a shell)?
static func handles(room_type: String) -> bool:
	return not styles_of(room_type).is_empty()


## Which style of `room_type` a module is — seeded, weighted, and a pure function of `seed_` (not of the run: the furniture is a physical feature of the flat).
static func pick_style(room_type: String, seed_: int) -> String:
	var opts := styles_of(room_type)
	if opts.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:style" % seed_)
	var total := 0.0
	for o in opts:
		total += float(o["weight"])
	var r := rng.randf() * total
	for o in opts:
		r -= float(o["weight"])
		if r <= 0.0:
			return String(o["style"])
	return String(opts[opts.size() - 1]["style"])


## The module-local rect the BALCONY doors take on a balcony slot (the same x 4..96 the old baked art kept its StripArt furniture in): no piece may touch it.
static func balcony_box() -> Rect2:
	return Rect2(4.0, 0.0, 93.0, 144.0)


## The module-local rect of the window a module shows on `side` ("left" / "right"); an empty Rect2 for anything else.
static func window_box(side: String) -> Rect2:
	var cx: float = float(WINDOW_INSET) if side == "left" else (float(MODULE_W - WINDOW_INSET) if side == "right" else -1.0)
	if cx < 0.0:
		return Rect2()
	return Rect2(cx - WINDOW_HALF_W, WINDOW_Y0, WINDOW_HALF_W * 2 + 1, WINDOW_Y1 - WINDOW_Y0 + 1)


# ------------------------------------------------------------------------------------------------------------------------------------ eligibility (THE LOGIC)
## May this piece be in this kind of room, in this style? Both lists must name it, and its tags must be allowed in the room by the rules table.
static func eligible(id: String, room_type: String, style: String) -> bool:
	var rec := piece(id)
	if rec.is_empty():
		return false
	if float(rec["rooms"].get(room_type, 0.0)) <= 0.0:
		return false
	var st = rec.get("styles", null)
	if st != null and float(st.get(style, 0.0)) <= 0.0:
		return false
	if not _any_variant_for(rec, style):
		return false
	var tag_rooms: Dictionary = data().get("rules", {}).get("tag_rooms", {})
	for t in rec.get("tags", []):
		if tag_rooms.has(t) and not (room_type in tag_rooms[t]):
			return false
	return true


## Does this variant suit the style? A variant that names no styles (`for`) suits all; one may also name styles it is NOT used in (`not` — a colourway that would vanish into that style's wall:
## tools/art/furn_palette.py).
static func variant_ok(rec: Dictionary, vid: String, style: String) -> bool:
	var params: Dictionary = rec["variants"][vid].get("params", {})
	var f = params.get("for", null)
	if f != null and not (style in f):
		return false
	return not (style in params.get("not", []))


## Does at least one variant of the piece suit this style?
static func _any_variant_for(rec: Dictionary, style: String) -> bool:
	for v in rec["variants"]:
		if variant_ok(rec, v, style):
			return true
	return false


static func weight_of(id: String, room_type: String, style: String) -> float:
	var rec := piece(id)
	var w: float = float(rec["rooms"].get(room_type, 0.0))
	var st = rec.get("styles", null)
	if st != null:
		w *= float(st.get(style, 0.0))
	return w


static func _pool(room_type: String, style: String, planes: Array, tag: String = "", kind: String = "", companion: bool = false) -> Array:
	var out: Array = []
	var items: Dictionary = data().get("items", {})
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		var rec: Dictionary = items[id]
		if not (rec["plane"] in planes):
			continue
		if bool(rec.get("companion_only", false)) and not companion:
			continue                                                    # a desk chair is only ever put beside a desk
		if tag != "" and not _has_any(rec["tags"], tag):
			continue
		if kind != "" and not (kind in rec.get("on", [])):
			continue
		if not eligible(id, room_type, style):
			continue
		out.append([id, weight_of(id, room_type, style)])
	return out


static func _wpick(rng: RandomNumberGenerator, pool: Array) -> String:
	var total := 0.0
	for e in pool:
		total += float(e[1])
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			return String(e[0])
	return String(pool[pool.size() - 1][0])


static func _limit_of(rec: Dictionary) -> int:
	var l = rec.get("limit", null)
	return int(l) if l != null else int(DEFAULT_LIMIT.get(rec["plane"], 1))


# ------------------------------------------------------------------------------------------------------------------------------------ one placed item
static func _sprite_for(rec: Dictionary, vid: String, x_centre: float) -> Dictionary:
	var sprites: Array = rec["variants"][vid]["sprites"]
	if sprites.size() == 1:
		return sprites[0]
	var best: Dictionary = sprites[0]
	var bd := 1.0e9
	for s in sprites:
		var d := absf(float(s["bx"]) - x_centre)
		if d < bd:
			bd = d
			best = s
	return best


## Build the item for `id`/`vid` with its reference point at (x, y). {} if the variant is unknown.
static func _make(id: String, vid: String, x: int, y: int, host: int = -1) -> Dictionary:
	var rec := piece(id)
	if rec.is_empty() or not rec["variants"].has(vid):
		return {}
	var info := _sprite_for(rec, vid, float(x) + float(rec["w"]) * 0.5)
	var rect := Rect2(x + int(info["l"]), y + int(info["t"]), int(info["r"]) - int(info["l"]) + 1, int(info["b"]) - int(info["t"]) + 1)
	return {"id": id, "variant": vid, "plane": rec["plane"], "x": x, "y": y, "file": info["file"], "rx": int(info["rx"]), "ry": int(info["ry"]),
		"open_file": info.get("open_file", ""), "rect": rect, "face": Vector2(x, x + int(rec["w"]) - 1), "w": int(rec["w"]), "host": host, "tags": rec["tags"],
		"params": rec["variants"][vid].get("params", {})}


## A variant of the piece, uniformly — but a variant that names its STYLES (`params.for`: a kitchen unit's sage doors are the classic kitchen's, its yellow doors the retro one's) is only
## offered to those styles; a variant that names none is for every style.
static func _vid(rng: RandomNumberGenerator, rec: Dictionary, style: String = "") -> String:
	var vids: Array = rec["variants"].keys()
	vids.sort()
	if style != "":
		var ok: Array = []
		for v in vids:
			if variant_ok(rec, v, style):
				ok.append(v)
		if not ok.is_empty():
			vids = ok
	return String(vids[rng.randi() % vids.size()])


static func _feet(rng: RandomNumberGenerator, rec: Dictionary) -> int:
	var f: Array = rec.get("feet", [0, 0])
	return rng.randi_range(int(f[0]), int(f[1]))


# ------------------------------------------------------------------------------------------------------------------------------------ the rules of one placement
static func _is_body(plane: String) -> bool:
	return plane == "wall" or plane == "front"


## The columns of every step-up spot's stand zone: (lo, hi) pairs from the 'bp' (wall-plane) scavenge nodes of `items`, the cluster midpoints too (pixlib._bp_centres).
static func _bands(items: Array) -> Array:
	var xs: Array = []
	for it in items:
		for a in _item_anchors(it):
			if bool(a["bp"]):
				xs.append(int(a["x"]))
	xs.sort()
	var centres: Array = []
	for i in range(xs.size()):
		centres.append(float(xs[i]))
		for j in range(i + 1, xs.size()):
			var chain := true
			for k in range(i, j):
				if xs[k + 1] - xs[k] > BP_CLUSTER:
					chain = false
					break
			if chain:
				centres.append((float(xs[i]) + float(xs[j])) * 0.5)
	var bands: Array = []
	for c in centres:
		bands.append(Vector2(int(c) - STAND_HALF, int(c) + STAND_HALF))
	return bands


## Does an item that stands / lies on the floor (front / floor planes) reach into a step-up spot's stand zone?
static func _in_stand_zone(rect: Rect2, bands: Array) -> bool:
	if rect.end.y <= STAND_TOP_ROW:
		return false
	for b in bands:
		if rect.position.x <= float(b.y) and rect.end.x - 1.0 >= float(b.x):
			return true
	return false


static func _blocked(rect: Rect2, ctx: Dictionary) -> bool:
	for b in ctx.get("blocked", []):
		if rect.intersects((b as Rect2).grow(1.0)):
			return true
	return false


static func _item_anchors(it: Dictionary) -> Array:
	var rec := piece(String(it["id"]))
	var out: Array = []
	if rec.is_empty():
		return out
	var host_plane := String(it.get("host_plane", it["plane"]))
	for a in rec["variants"][it["variant"]].get("anchors", []):
		out.append({"name": String(a["name"]), "x": int(it["x"]) + int(a["dx"]), "y": int(it["y"]) + int(a["dy"]), "bp": host_plane == "wall"})
	return out


## Can `it` be added to the plan state `st` without breaking a rule? `gap` = the minimum space kept between two bodies on the wall line.
static func _fits(st: Dictionary, it: Dictionary, gap: int = 1) -> bool:
	if it.is_empty():
		return false
	var rect: Rect2 = it["rect"]
	var plane := String(it["plane"])
	var items: Array = st["items"]
	var ctx: Dictionary = st["ctx"]
	# the module's own edges
	if plane != "ceiling" and (rect.position.x < EDGE_L or rect.end.x - 1.0 > EDGE_R or rect.position.y < TOP_MIN_Y):
		return false
	if plane == "ceiling" and (rect.position.x < EDGE_L or rect.end.x - 1.0 > EDGE_R):
		return false
	if plane != "rug" and plane != "ceiling" and _blocked(rect, ctx):
		return false
	# a node nobody can reach (above the window line / further than arm's length from the step-up plane) is not allowed
	for a in _item_anchors(it):
		if int(a["y"]) < NODE_MIN_Y:
			return false
	# the same piece no more than its limit (a room has one wardrobe, a few shoes)
	var rec := piece(String(it["id"]))
	var same := 0
	for o in items:
		if String(o["id"]) == String(it["id"]):
			same += 1
	if same >= _limit_of(rec):
		return false
	var face: Vector2 = it["face"]
	var bands := _bands(items)
	match plane:
		"wall", "front":
			for o in items:
				if _is_body(String(o["plane"])):
					var of: Vector2 = o["face"]
					if face.x <= of.y + float(gap) and face.y >= of.x - float(gap):
						return false
			# its own step-up spot may not swallow something already standing on the floor
			if plane == "wall":
				var mine := _bands([it])
				for o in items:
					var op := String(o["plane"])
					if (op == "front" or op == "floor") and _in_stand_zone(o["rect"], mine):
						return false
			elif _in_stand_zone(rect, bands):
				return false
		"floor":
			if rect.end.y - 1.0 > LANE_CLEAR_ROW:
				return false
			if _in_stand_zone(rect, bands):
				return false
			for o in items:
				var op := String(o["plane"])
				if op == "floor" or op == "front":
					if rect.grow(1.0).intersects((o["rect"] as Rect2)) and not _depth_ok(it, o):
						return false
				elif op == "wall":
					if not _depth_ok(it, o) and rect.intersects((o["rect"] as Rect2).grow(0.0)):
						return false
		"decor":
			for o in items:
				var op := String(o["plane"])
				if op == "rug" or op == "floor" or op == "ceiling":
					continue
				if rect.grow(2.0).intersects(o["rect"]):
					return false
		"rug":
			for o in items:
				if String(o["plane"]) == "rug" and rect.intersects(o["rect"]):
					return false
		"top":
			for o in items:
				if String(o["plane"]) == "top" and rect.grow(0.0).intersects(o["rect"]):
					return false
		"ceiling":
			for o in items:
				var op := String(o["plane"])
				if op == "ceiling" and rect.grow(6.0).intersects(o["rect"]):
					return false
				if (op == "decor" or op == "wall" or op == "top") and rect.grow(2.0).intersects(o["rect"]):
					return false                                # a pendant's flex never hangs through a picture or a wardrobe
	return true


## A floor item may overlap a body's drawn rect only along the body's lower edge (clothes in front of a wardrobe, a shoe by a bed leg) — never lie under / inside it.
static func _depth_ok(it: Dictionary, body: Dictionary) -> bool:
	if not _is_body(String(body["plane"])) and String(body["plane"]) != "floor":
		return false
	var r: Rect2 = it["rect"]
	var b: Rect2 = body["rect"]
	if String(body["plane"]) == "floor":
		return not r.grow(1.0).intersects(b)
	var overlap_y := minf(r.end.y, b.end.y) - maxf(r.position.y, b.position.y)
	var lap := float(piece(String(it["id"])).get("lap", 6))             # a coffee table may stand over the front of the sofa (its `lap`); a shoe may not
	return overlap_y <= lap and int(it["y"]) > int(body["y"])


# ------------------------------------------------------------------------------------------------------------------------------------ the plan
## Plan a room: {ok, room, style, shell, seed, attempt, fallback, items, anchors, lights, anims}. `ctx`: {window: "left"/"right"/"" (the side its window is on)}; extra
## {blocked: [Rect2]} may be passed by the caller. Deterministic in (room type, style, seed, ctx.window). A recipe that cannot place its pieces in MAX_TRIES attempts
## falls back to its hand-set layout; an unknown room / style returns {} (the caller keeps the baked module).
static func plan(room_type: String, style: String, seed_: int, ctx_in: Dictionary = {}) -> Dictionary:
	var rcp := recipe(room_type, style)
	if rcp.is_empty():
		return {}
	var ctx := ctx_in.duplicate()
	var blocked: Array = []
	for b in ctx_in.get("blocked", []):
		blocked.append(b)
	var wb := window_box(String(ctx_in.get("window", "")))
	if wb.size.x > 0.0:
		blocked.append(wb)
	ctx["blocked"] = blocked
	for attempt in range(MAX_TRIES):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%d:%s" % [seed_, attempt, String(ctx_in.get("window", ""))])
		var st := {"items": [], "rng": rng, "ctx": ctx, "room": room_type, "style": style, "rcp": rcp}
		if _attempt(st, rcp):
			return _result(st, room_type, style, rcp, seed_, attempt, false)
	var fb := {"items": [], "rng": RandomNumberGenerator.new(), "ctx": ctx, "room": room_type, "style": style, "rcp": rcp}
	for e in rcp.get("fallback", []):
		var vid_ := String(e["variant"])
		var it := _make(String(e["id"]), vid_, int(e["x"]), int(e["y"]))
		if not it.is_empty():
			fb["items"].append(it)
	return _result(fb, room_type, style, rcp, seed_, MAX_TRIES, true)


static func _result(st: Dictionary, room_type: String, style: String, rcp: Dictionary, seed_: int, attempt: int, fallback: bool) -> Dictionary:
	var items: Array = st["items"]
	# draw order: rugs, hung things, then the bodies (far from the middle first — a left-leaning piece's side face is covered by its neighbour), things on top, the ceiling
	var layer := {"rug": 0, "decor": 1, "wall": 2, "front": 2, "floor": 2, "top": 3, "ceiling": 4}
	var order: Array = []
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var cx: float = float(it["x"]) + float(it["w"]) * 0.5
		order.append([int(layer.get(String(it["plane"]), 2)), int(it["y"]) if _is_body(String(it["plane"])) or it["plane"] == "floor" else 0, -absf(cx - 160.0), i])
	order.sort_custom(func(a, b):
		for k in range(4):
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	var out_items: Array = []
	var anchors: Array = []
	var lights: Array = []
	var anims: Array = []
	var used_names := {}
	for o in order:
		var it: Dictionary = items[int(o[3])]
		var n: int = out_items.size()
		var d := {"id": it["id"], "variant": it["variant"], "plane": it["plane"], "x": it["x"], "y": it["y"], "file": it["file"], "rx": it["rx"], "ry": it["ry"],
			"open_file": it["open_file"], "z": n, "w": it["w"], "host_plane": String(it.get("host_plane", it["plane"]))}
		var rec := piece(String(it["id"]))
		var v: Dictionary = rec["variants"][it["variant"]]
		for a in _item_anchors(it):
			var nm := "anchor_%s_%s" % [room_type, String(a["name"])]
			if String(a["name"]).begins_with("bed_") or String(a["name"]).begins_with("floor_"):
				nm = "anchor_" + String(a["name"])
			var base := nm
			var k := 2
			while used_names.has(nm):
				nm = "%s_%d" % [base, k]
				k += 1
			used_names[nm] = true
			anchors.append({"name": nm, "x": a["x"], "y": a["y"], "bp": a["bp"], "item": n})
			if rec.get("opens", null) != null and String(rec["opens"].get("anchor", "")) == String(a["name"]) and String(it["open_file"]) != "":
				d["opens"] = nm
				d["kind"] = String(rec["opens"].get("kind", "drawer"))
				d["frames"] = int(rec["opens"].get("frames", 3))
		for l in v.get("lights", []):
			lights.append({"kind": String(l["kind"]), "x": int(it["x"]) + int(l["dx"]), "y": int(it["y"]) + int(l["dy"])})
		for an in v.get("anims", []):
			var ad: Dictionary = an.duplicate()
			ad["x"] = int(it["x"]) + int(an["dx"])
			ad["y"] = int(it["y"]) + int(an["dy"])
			ad["item"] = n
			anims.append(ad)
		out_items.append(d)
	return {"ok": true, "room": room_type, "style": style, "shell": String(rcp.get("shell", "")), "seed": seed_, "attempt": attempt, "fallback": fallback,
		"items": out_items, "anchors": anchors, "lights": lights, "anims": anims}


# ------------------------------------------------------------------------------------------------------------------------------------ one attempt
static func _attempt(st: Dictionary, rcp: Dictionary) -> bool:
	var rng: RandomNumberGenerator = st["rng"]
	var room: String = st["room"]
	var style: String = st["style"]
	var cr: Dictionary = rcp.get("centre", {})
	st["flank_tag"] = String(rcp.get("flank", {}).get("tag", ""))
	var centre := -1
	if not cr.is_empty():
		centre = _place_centre(st, cr)
		if centre < 0:
			return false
		var fr: Dictionary = rcp.get("flank", {})
		if not fr.is_empty() and rng.randf() < float(fr.get("chance", 1.0)):
			_place_flank(st, centre, fr)
		_place_needs(st, centre)                                          # a sofa wants its coffee table (never at the cost of the sofa: `optional`)
	if not rcp.get("run", {}).is_empty():
		_fill_run(st, rcp["run"])
		for tag in rcp["run"].get("must", []):
			if not _has_tag(st, tag):
				return false
	_fill_wall(st, rcp.get("wall", {}))
	for tag in rcp.get("wall", {}).get("must", []):
		if not _has_tag(st, tag):
			return false
	_fill_tops(st, float(rcp.get("tops", 0.7)))
	_fill_decor(st, rcp.get("decor", [0, 0]))
	_fill_clutter(st, rcp.get("clutter", [0, 0]))
	if rng.randf() < float(rcp.get("rug", 0.0)):
		_place_rug(st, centre)
	if rng.randf() < float(rcp.get("ceiling", 1.0)):
		_place_ceiling(st)
	if _count_front_nodes(st) < int(rcp.get("min_front", 2)):
		return false
	return validate_state(st).is_empty()


## `tag` may name alternatives ("wardrobe|dressing" — a wardrobe OR a dressing table).
static func _has_any(tags: Array, tag: String) -> bool:
	for t in tag.split("|"):
		if String(t) in tags:
			return true
	return false


static func _has_tag(st: Dictionary, tag: String) -> bool:
	for it in st["items"]:
		if _has_any(it["tags"], tag):
			return true
	return false


static func _count_front_nodes(st: Dictionary) -> int:
	var n := 0
	for it in st["items"]:
		for a in _item_anchors(it):
			if not bool(a["bp"]) and int(a["y"]) >= FRONT_NODE_MIN_Y:
				n += 1
	return n


static func _add(st: Dictionary, it: Dictionary) -> int:
	st["items"].append(it)
	return st["items"].size() - 1


## The centrepiece (a bed): its tag picks the piece, the recipe's x range where it may start.
static func _place_centre(st: Dictionary, cr: Dictionary) -> int:
	var rng: RandomNumberGenerator = st["rng"]
	var pool := _pool(st["room"], st["style"], ["front", "wall"], String(cr["tag"]))
	var id := _wpick(rng, pool)
	if id == "":
		return -1
	var rec := piece(id)
	var xr: Array = cr["x"]
	for t in range(12):
		var vid := _vid(rng, rec, String(st["style"]))
		var it := _make(id, vid, rng.randi_range(int(xr[0]), int(xr[1])), _feet(rng, rec))
		if _fits(st, it):
			return _add(st, it)
	if bool(cr.get("anywhere", false)):                                      # then anywhere the room has space (a kitchen table goes wherever the run left room)
		for t in range(24):
			var it2 := _make(id, _vid(rng, rec, String(st["style"])), rng.randi_range(EDGE_L, EDGE_R - int(rec["w"])), _feet(rng, rec))
			if _fits(st, it2):
				return _add(st, it2)
	return -1


## A bedside table at the HEAD end of the centrepiece (a bed's head side is its variant's `head`), flush against it.
static func _place_flank(st: Dictionary, ci: int, fr: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var c: Dictionary = st["items"][ci]
	var pool := _pool(st["room"], st["style"], ["wall", "front"], String(fr["tag"]))
	var id := _wpick(rng, pool)
	if id == "":
		return
	var rec := piece(id)
	var head := String(c["params"].get("head", ""))
	if head != "left" and head != "right":
		head = "left" if rng.randf() < 0.5 else "right"
	var crect: Rect2 = c["rect"]
	var vid := _vid(rng, rec, String(st["style"]))
	var w := int(rec["w"])
	for step in range(0, 40):
		var x := int(crect.position.x) - w - 1 - step if head == "left" else int(crect.end.x) + 1 + step
		var it := _make(id, vid, x, _feet(rng, rec))
		if _fits(st, it, 0):
			_add(st, it)
			return


## Fill the wall line with the wall-plane pieces of this room's pool (a wardrobe, a dresser…): `count` of them, and every `must` tag at least once.
static func _fill_wall(st: Dictionary, wr: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var cnt: Array = wr.get("count", [0, 0])
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]))
	var must: Array = wr.get("must", [])
	var want: Array = wr.get("want", [])                              # tags TRIED a few times once the musts stand (a wet room's washing machine) — never a reason to fail the room
	var want_tries := {}
	var placed := 0
	for guard in range(n + 8):
		var unmet := ""
		for t in must:
			if not _has_tag(st, String(t)):
				unmet = String(t)
				break
		if unmet == "":
			for t in want:
				if not _has_tag(st, String(t)) and int(want_tries.get(String(t), 0)) < WANT_TRIES:
					want_tries[String(t)] = int(want_tries.get(String(t), 0)) + 1
					unmet = String(t)
					break
		if unmet == "" and placed >= n:
			break
		var pool := _pool(st["room"], st["style"], wr.get("planes", ["wall"]), unmet)      # a bathroom's fixtures (a toilet, a basin) are FRONT pieces: `planes: ["wall", "front"]`
		if String(st.get("flank_tag", "")) != "":                   # a bedside table stands at the bed, never alone in a corner
			pool = pool.filter(func(e): return not (String(st["flank_tag"]) in piece(String(e[0]))["tags"]))
		var id := _wpick(rng, pool)
		if id == "":
			continue
		var rec := piece(id)
		var vid := _vid(rng, rec, String(st["style"]))
		var w := int(rec["w"])
		var xs: Array = [EDGE_L + rng.randi_range(0, 4), EDGE_R - w - rng.randi_range(0, 4)]
		for k in range(SPOTS_PER_PIECE - 2):
			xs.append(rng.randi_range(EDGE_L, EDGE_R - w))
		for k in range(xs.size() - 1, 0, -1):                       # shuffled: a wardrobe is not always in the left corner
			var j := rng.randi() % (k + 1)
			var tmp = xs[k]
			xs[k] = xs[j]
			xs[j] = tmp
		var gap := 1 + rng.randi_range(0, 3)
		for x in xs:
			var it := _make(id, vid, int(x), _feet(rng, rec))
			if _fits(st, it, gap):
				var idx := _add(st, it)
				_place_needs(st, idx)
				placed += 1
				break


## A RUN of units along the wall, edge to edge (a kitchen's line of fridge, base units, cooker and sink): pieces tagged `unit` laid one after another from a seeded start x, all at ONE feet row
## (so their worktops line up), no gap between them; every `must` tag (cooking, wet…) is placed first. The recipe's `run`: {count:[a,b], x:[start range], must:[tags]}.
static func _fill_run(st: Dictionary, rr: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var cnt: Array = rr.get("count", [3, 5])
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]))
	var must: Array = rr.get("must", []).duplicate()
	for k in range(must.size() - 1, 0, -1):                                   # the musts in a random order — not always fridge, cooker, sink from the left
		var j := rng.randi() % (k + 1)
		var tmp = must[k]
		must[k] = must[j]
		must[j] = tmp
	var xr: Array = rr.get("x", [EDGE_L, 120])
	var x := rng.randi_range(int(xr[0]), int(xr[1]))
	var rtl: bool = int(rr.get("sides", 1)) > 1 and rng.randf() < 0.5      # a run may start from the right-hand wall and grow leftward: x is then the distance from the right edge
	if rtl:
		x = MODULE_W - x
	var row := -1
	var placed := 0
	var last_id := ""
	for guard in range(n * 6 + 16):
		var unmet := ""
		for t in must:
			if not _has_tag(st, String(t)):
				unmet = String(t)
				break
		if placed >= n and unmet == "":
			break
		var done := false
		# the piece the room still needs (a fridge, a cooker, a sink) — if it does not fit here (the window is above this stretch of wall), a plain unit fills the gap and the need waits
		for attempt in range(2):
			var want := unmet if (attempt == 0 and unmet != "") else "unit"
			var pool := _pool(st["room"], st["style"], ["wall"], want)
			pool = pool.filter(func(e): return "unit" in piece(String(e[0]))["tags"])
			if attempt == 1:
				pool = pool.filter(func(e): return not _has_any_must(piece(String(e[0]))["tags"], must))
			var id := _wpick(rng, pool)
			if id == "":
				continue
			var rec := piece(id)
			var vid := _vid(rng, rec, String(st["style"]))
			if row < 0:
				row = _feet(rng, rec)
			var it := _make(id, vid, x - int(rec["w"]) if rtl else x, row)
			if _fits(st, it, 0):
				_add(st, it)
				x += -int(rec["w"]) if rtl else int(rec["w"])
				placed += 1
				last_id = id
				done = true
				break
		if not done:
			break


static func _has_any_must(tags: Array, must: Array) -> bool:
	for m in must:
		if String(m) in tags:
			return true
	return false


static func _all_tags(st: Dictionary, tags: Array) -> bool:
	for t in tags:
		if not _has_tag(st, String(t)):
			return false
	return true


## A piece that needs company (a desk wants its chair): place the companion beside it or take the piece back out.
static func _place_needs(st: Dictionary, idx: int) -> void:
	var host: Dictionary = st["items"][idx]
	var rec := piece(String(host["id"]))
	var nd = rec.get("needs", null)
	if nd == null:
		return
	var rng: RandomNumberGenerator = st["rng"]
	if rng.randf() >= float(nd.get("chance", 1.0)):
		return
	var pool := _pool(st["room"], st["style"], ["floor", "front"], String(nd["tag"]), "", true)
	var id := _wpick(rng, pool)
	if id == "":
		return
	var crec := piece(id)
	var dxr: Array = nd.get("dx", [0, 20])
	for t in range(10):
		var x := int(host["x"]) + rng.randi_range(int(dxr[0]), int(dxr[1]))
		var it := _make(id, _vid(rng, crec, String(st["style"])), x, _feet(rng, crec))
		if _fits(st, it):
			_add(st, it)
			return
	if bool(nd.get("optional", false)):
		return                                                    # a sofa with no room for a coffee table is still a sofa
	st["items"].remove_at(idx)                                # no room for the chair → no desk (never a desk with nowhere to sit)


## Things that stand ON a surface: each slot of each placed piece may take one or two small things / a lamp of this room's pool.
static func _fill_tops(st: Dictionary, chance: float) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var hosts: Array = st["items"].duplicate()
	for hi in range(hosts.size()):
		var host: Dictionary = hosts[hi]
		var hrec := piece(String(host["id"]))
		var slots: Array = hrec["variants"][host["variant"]].get("slots", [])
		for sl in slots:
			if rng.randf() >= chance:
				continue
			var kinds: Array = sl.get("kinds", [])
			var x0 := int(host["x"]) + int(sl["dx0"])
			var x1 := int(host["x"]) + int(sl["dx1"])
			var cap := 1 if "lamp" in kinds and not ("small" in kinds) else 2
			var placed := 0
			for t in range(cap * 3):
				if placed >= cap or x0 > x1:
					break
				var pool: Array = []
				for kd in kinds:
					for e in _pool(st["room"], st["style"], ["top"], "", String(kd)):
						pool.append(e)
				var id := _wpick(rng, pool)
				if id == "":
					break
				var rec := piece(id)
				var w := int(rec["w"])
				if x0 + w - 1 > x1:
					continue
				var x := rng.randi_range(x0, x1 - w + 1)
				var it := _make(id, _vid(rng, rec, String(st["style"])), x, int(host["y"]) + int(sl["dy"]), hi)
				it["host_plane"] = hrec["plane"]
				if _fits(st, it):
					_add(st, it)
					placed += 1
					x0 = x + w + 1


## Pictures and notices: hung on the wall clear of every piece and of the window.
static func _fill_decor(st: Dictionary, cnt: Array) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]))
	for k in range(n):
		var id := _wpick(rng, _pool(st["room"], st["style"], ["decor"]))
		if id == "":
			return
		var rec := piece(id)
		var wy: Array = rec.get("wall_y", [24, 44]) if rec.get("wall_y", null) != null else [24, 44]
		var vid := _vid(rng, rec, String(st["style"]))
		var w := int(rec["w"])
		var hosts: Array = []                                      # a hung unit prefers the run it belongs over (wall cupboards above the worktop)
		for tg in rec.get("above", []):
			for o in st["items"]:
				if _is_body(String(o["plane"])) and String(tg) in o["tags"]:
					hosts.append(o)
		for t in range(SPOTS_PER_PIECE * 2):
			var x := rng.randi_range(EDGE_L + 2, EDGE_R - w - 1)
			if not hosts.is_empty() and t < SPOTS_PER_PIECE:
				var h: Dictionary = hosts[rng.randi() % hosts.size()]
				x = clampi(int(h["x"]) + rng.randi_range(-w / 3, int(h["w"]) - w * 2 / 3), EDGE_L + 2, EDGE_R - w - 1)
			var it := _make(id, vid, x, rng.randi_range(int(wy[0]), int(wy[1])))
			if _fits(st, it):
				_add(st, it)
				break


## Things lying about: near what they belong to (clothes by the bed or the wardrobe), never in a stand zone, never past the lane.
static func _fill_clutter(st: Dictionary, cnt: Array) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var n := rng.randi_range(int(cnt[0]), int(cnt[1]))
	for k in range(n):
		var id := _wpick(rng, _pool(st["room"], st["style"], ["floor"]))
		if id == "":
			return
		var rec := piece(id)
		var vid := _vid(rng, rec, String(st["style"]))
		var w := int(rec["w"])
		var near: Array = rec.get("near", [])
		var xs: Array = []
		for o in st["items"]:
			if _is_body(String(o["plane"])):
				for t in near:
					if t in o["tags"]:
						var r: Rect2 = o["rect"]
						for gap in [2, 5, 10, 18, 28]:                  # beside the thing it belongs with, on either side, near then further
							xs.append(int(r.position.x) - w - gap)
							xs.append(int(r.end.x) + gap)
						xs.append(rng.randi_range(int(r.position.x), maxi(int(r.position.x), int(r.end.x) - w)))
		if xs.is_empty():
			for t in range(10):
				xs.append(rng.randi_range(EDGE_L + 2, EDGE_R - w - 2))
		for m in range(xs.size() - 1, 0, -1):
			var j := rng.randi() % (m + 1)
			var tmp = xs[m]
			xs[m] = xs[j]
			xs[j] = tmp
		for x in xs:
			var it := _make(id, vid, int(x), _feet(rng, rec))
			if _fits(st, it):
				_add(st, it)
				break


static func _place_rug(st: Dictionary, centre: int) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var id := _wpick(rng, _pool(st["room"], st["style"], ["rug"]))
	if id == "":
		return
	var rec := piece(id)
	var w := int(rec["w"])
	var under: Array = rec.get("under", [])
	for t in range(10):
		var cx := rng.randi_range(70, 250)
		if not under.is_empty() and centre >= 0:                      # a living-room rug lies under the sofa group, centred on it
			var cf: Vector2 = st["items"][centre]["face"]
			cx = int((cf.x + cf.y) * 0.5) + rng.randi_range(-12, 12)
		var it := _make(id, _vid(rng, rec, String(st["style"])), cx - w / 2, _feet(rng, rec))
		if _fits(st, it) and _rug_ok(st, it):
			_add(st, it)
			return


## A rug lies on open floor, clear of the bed / sofa — never half under it, peeking out from one side like a dropped towel.
static func _rug_ok(st: Dictionary, rug: Dictionary) -> bool:
	var rf: Vector2 = rug["face"]
	var under: Array = piece(String(rug["id"])).get("under", [])
	for o in st["items"]:
		if String(o["plane"]) == "front":
			var skip := false
			for tg in under:
				if String(tg) in o["tags"]:
					skip = true                                           # the sofa / an armchair may stand on this rug, even half on it
			if skip:
				continue
			var of: Vector2 = o["face"]
			if rf.x <= of.y + 4.0 and rf.y >= of.x - 4.0:
				return false
	return true


static func _place_ceiling(st: Dictionary) -> void:
	var rng: RandomNumberGenerator = st["rng"]
	var id := _wpick(rng, _pool(st["room"], st["style"], ["ceiling"]))
	if id == "":
		return
	var rec := piece(id)
	for t in range(8):
		var it := _make(id, _vid(rng, rec, String(st["style"])), rng.randi_range(110, 200), 0)
		if _fits(st, it):
			_add(st, it)
			return


# ------------------------------------------------------------------------------------------------------------------------------------ validation
## Every rule, re-checked on a finished plan state (used by the planner to accept an attempt, and by tests on `plan()` results through `validate()`).
static func validate_state(st: Dictionary) -> Array:
	var bad: Array = []
	var items: Array = st["items"]
	var room: String = st["room"]
	var style: String = st["style"]
	var ctx: Dictionary = st["ctx"]
	var bands := _bands(items)
	var counts := {}
	for i in range(items.size()):
		var it: Dictionary = items[i]
		var id := String(it["id"])
		var rec := piece(id)
		var plane := String(it["plane"])
		if not eligible(id, room, style):
			bad.append("%s is not allowed in a %s (%s)" % [id, room, style])
		elif not variant_ok(rec, String(it["variant"]), style):
			bad.append("%s / %s is not used in a %s (a `for` list or a colourway that blends into the wall)" % [id, String(it["variant"]), style])
		counts[id] = int(counts.get(id, 0)) + 1
		var rect: Rect2 = it["rect"]
		if plane != "ceiling" and (rect.position.x < EDGE_L or rect.end.x - 1.0 > EDGE_R):
			bad.append("%s leaves the module (x %d..%d)" % [id, int(rect.position.x), int(rect.end.x) - 1])
		if plane != "rug" and plane != "ceiling" and _blocked(rect, ctx):
			bad.append("%s stands in front of the window / a blocked box %s" % [id, str(rect)])
		for a in _item_anchors(it):
			if int(a["y"]) < NODE_MIN_Y:
				bad.append("%s has a node out of reach (y %d)" % [id, int(a["y"])])
		if plane == "floor" and rect.end.y - 1.0 > LANE_CLEAR_ROW:
			bad.append("%s lies past the walking lane (row %d)" % [id, int(rect.end.y) - 1])
		if (plane == "front" or plane == "floor") and _in_stand_zone(rect, bands):
			bad.append("%s is in a step-up spot's stand zone" % id)
		if _is_body(plane):
			for j in range(i + 1, items.size()):
				var o: Dictionary = items[j]
				if _is_body(String(o["plane"])):
					var a: Vector2 = it["face"]
					var b: Vector2 = o["face"]
					if a.x <= b.y and a.y >= b.x:
						bad.append("%s overlaps %s on the wall line" % [id, String(o["id"])])
	for id in counts:
		if int(counts[id]) > _limit_of(piece(id)):
			bad.append("%d × %s (limit %d)" % [int(counts[id]), id, _limit_of(piece(id))])
	return bad


## Re-check a plan returned by `plan()` — [] when it breaks nothing. (Rebuilds the state from the plan's items.)
static func validate(pl: Dictionary, ctx_in: Dictionary = {}) -> Array:
	var ctx := ctx_in.duplicate()
	var blocked: Array = []
	var wb := window_box(String(ctx_in.get("window", "")))
	if wb.size.x > 0.0:
		blocked.append(wb)
	for b in ctx_in.get("blocked", []):
		blocked.append(b)
	ctx["blocked"] = blocked
	var items: Array = []
	for d in pl.get("items", []):
		var it := _make(String(d["id"]), String(d["variant"]), int(d["x"]), int(d["y"]))
		if it.is_empty():
			return ["unknown piece %s / %s" % [String(d["id"]), String(d["variant"])]]
		it["host_plane"] = String(d.get("host_plane", it["plane"]))
		items.append(it)
	var st := {"items": items, "room": String(pl["room"]), "style": String(pl["style"]), "ctx": ctx}
	return validate_state(st)
