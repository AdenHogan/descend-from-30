class_name RoomDepth
extends RefCounted
## DEPTH AND LIGHT FOR A FLAT'S ROOMS (owner round 49s: "take a pass at our art... shapes, depth, and most importantly, lighting. I'm not asking for 2.5D space, but I do want deeper
## lived in looking space"; round 49q: "dynamic real lighting is so important because so much of our colour palette looks so lifeless... we need lighting, shadows").
##
## A room's art is authored FLAT (even light) so the engine's lights can work on it - and until now nothing in the engine said where the light comes FROM: every wall was the same
## brightness from corner to corner, nothing cast a shadow, and furniture read as stickers on wallpaper. This lays, per room module:
##
##   1. SHADE (every room, baked or planned) - the dark a real room keeps where light does not reach: under the ceiling, in the corners at the flat's end walls and beside each
##      partition, along the floor's near edge, and a falling-off away from the room's daylight (its window or its balcony door), so the wall is brightest by the glass.
##   2. SEAM (planned rooms only: drawn UNDER the furniture) - the wall darkening down to the skirting and the strip of floor against it.
##   3. CAST SHADOWS (planned rooms only: each piece is its own sprite) - every piece against the wall, every picture on it and everything standing on a surface throws its own
##      silhouette on the wall behind it, AWAY from the room's light: the window by day, a lit lamp in the room by night. That gap of shadow is what stands a wardrobe off the wall.
##
## All of it is BLACK with alpha, UNSHADED (never dimmed twice by the night's ambient, never brightened by a lamp), in hard bands (no blur, no dither: it is pixel art). Nothing here
## has collision, groups or input, nothing is saved, and every number is a pure function of the room - so a pan backdrop and the live room agree.
##
## Not gloom: the morning stays a bright day (WorldState's staged ramp is untouched) - the shade only says where the daylight comes from.

const ModuleGeo := preload("res://scripts/module_geo.gd")

const H := 144                       # a module's height (ModuleGeo: 240 x 144)
const SEAM_ROW := 100                # the wall meets the floor (tools/art/pixlib.SEAM_Y)
const BAND := 0.028                  # alpha is cut into steps this size: visible bands, not an airbrush

# --- 1. the shade (alpha of black; they combine as light does: 1 - product of (1 - a)) -------------------------------------------------
const CEIL_REACH := 34.0             # rows under the ceiling the dark hangs down
const CEIL_AO := 0.38
const WALL_LIFT := 0.07              # a faint darkening of the whole wall toward the ceiling (walls are lit from window height down)
const CORNER_REACH := 30.0           # px in from one of the flat's END walls
const CORNER_AO := 0.34
const PARTITION_REACH := 16.0        # px either side of a wall between two rooms
const PARTITION_AO := 0.15
const FRONT_REACH := 15.0            # rows up from the picture's bottom edge (the floor nearest the camera)
const FRONT_AO := 0.22
const FALLOFF_START := 46.0          # px from the daylight before the wall starts to dim
const FALLOFF_BY_RUN := [0.18, 0.30, 0.30]     # morning / afternoon / night: how much darker the far side of the room is than the side by the glass

# --- 2. the seam (planned rooms) -----------------------------------------------------------------------------------------------------
const SEAM_UP := 14.0                # rows of wall above the skirting that darken toward it
const SEAM_UP_AO := 0.13
const SEAM_DOWN := 10.0              # rows of floor against the wall
const SEAM_DOWN_AO := 0.24

# --- 3. cast shadows (planned rooms) ---------------------------------------------------------------------------------------------------
# per plane: [[dx, dy, alpha], ...] - dx is how far the shadow is thrown sideways when the light is fully to one side (scaled by where the piece stands), dy how far down
const CAST := {
	"wall": [[4.0, 1.0, 0.26], [7.0, 2.0, 0.12]],          # furniture standing against the back wall: a core and a longer, fainter penumbra
	"decor": [[2.0, 2.0, 0.26], [3.0, 3.0, 0.10]],         # a picture, a clock, a shelf: hangs proud of the wall
	"top": [[2.0, 1.0, 0.20]],                             # a lamp, a vase, a radio on a surface: its shadow on the wall behind
	"ceiling": [],
}
const CAST_SPAN := 64.0              # px from the light at which a shadow is thrown its full length
# A piece that STANDS OUT in the room (the `front` and `floor` planes: a sofa, a bed, a table, a chair, a plant) and one against the wall throws a shadow on the FLOOR
# (owner round 49t: "so that the furniture does have its weight from shadow, lighting, that depth"): its own silhouette laid down on the boards from its foot, toward the
# camera and away from the room's light — plane -> [length as a share of the piece's height, darkness].
const FLOOR_CAST := {"front": [0.30, 0.20], "floor": [0.30, 0.18], "wall": [0.18, 0.14]}
const FLOOR_MAX_LEN := 15.0          # rows: a shadow never runs further down the floor than this (it stops short of the room's near edge)
const FLOOR_MIN_LEN := 3.0
const FLOOR_THROW := 0.9             # px sideways per row of length, at the light's full angle (away from the light)
const FLOOR_LEN_BY_RUN := [1.0, 1.35, 0.9]     # the afternoon's low sun throws them further
const CAST_LEN_BY_RUN := [1.0, 1.5, 1.0]       # the afternoon's low sun throws them further
const CAST_ALPHA_BY_RUN := [1.0, 1.1, 0.9]

static var _cache: Dictionary = {}


static func _smooth(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _band(a: float) -> float:
	return clampf(round(a / BAND) * BAND, 0.0, 0.9)


## How much light a module ROW keeps (1 = all of it): the dark under the ceiling, the wall's faint lift toward it, the floor's near edge.
static func keep_row(y: int) -> float:
	var keep := 1.0 - CEIL_AO * pow(1.0 - clampf(float(y) / CEIL_REACH, 0.0, 1.0), 1.6)
	if y < SEAM_ROW:
		keep *= 1.0 - WALL_LIFT * (1.0 - float(y) / float(SEAM_ROW))
	keep *= 1.0 - FRONT_AO * _smooth(1.0 - float(H - 1 - y) / FRONT_REACH)
	return keep


## How much light a module COLUMN keeps: the corners (an end wall of the flat, or a partition) and the falling-off away from the room's daylight.
static func keep_col(x: int, w: int, end_l: bool, end_r: bool, light_x: float, run: int) -> float:
	var dl := float(x)
	var dr := float(w - 1 - x)
	var keep := 1.0 - (CORNER_AO if end_l else PARTITION_AO) * pow(1.0 - clampf(dl / (CORNER_REACH if end_l else PARTITION_REACH), 0.0, 1.0), 1.5)
	keep *= 1.0 - (CORNER_AO if end_r else PARTITION_AO) * pow(1.0 - clampf(dr / (CORNER_REACH if end_r else PARTITION_REACH), 0.0, 1.0), 1.5)
	var far: float = maxf(light_x, float(w) - light_x) - FALLOFF_START
	if far > 1.0:
		var t: float = (absf(float(x) - light_x) - FALLOFF_START) / far
		keep *= 1.0 - float(FALLOFF_BY_RUN[clampi(run - 1, 0, 2)]) * _smooth(t)
	return keep


## How dark the shade is at a module pixel (0 = untouched). `end_l` / `end_r`: this edge is one of the flat's end walls (else a partition); `light_x`: the room's daylight (module x).
## The darks multiply as light does, so it is one number down the rows times one along the columns.
static func shade_at(x: int, y: int, w: int, end_l: bool, end_r: bool, light_x: float, run: int) -> float:
	return _band(1.0 - keep_row(y) * keep_col(x, w, end_l, end_r, light_x, run))


## The seam's dark at a module pixel (planned rooms; drawn under the furniture).
static func seam_at(y: int) -> float:
	var a := 0.0
	if y < SEAM_ROW:
		a = SEAM_UP_AO * _smooth(1.0 - float(SEAM_ROW - y) / SEAM_UP)
	else:
		a = SEAM_DOWN_AO * (1.0 - _smooth(float(y - SEAM_ROW) / SEAM_DOWN))
	return _band(a)


static func shade_texture(w: int, end_l: bool, end_r: bool, light_x: float, run: int) -> Texture2D:
	var key := "shade:%d:%s:%s:%d:%d" % [w, str(end_l), str(end_r), int(round(light_x)), run]
	if _cache.has(key):
		return _cache[key]
	# (one pass over a byte array from the two profiles: ~8 ms, where 34,560 set_pixel calls took ~40 - a hitch on walking into a flat)
	var cols := PackedFloat32Array()
	cols.resize(w)
	for x in range(w):
		cols[x] = keep_col(x, w, end_l, end_r, light_x, run)
	var data := PackedByteArray()
	data.resize(w * H * 4)                     # zero-filled: black, alpha set below
	var i := 3
	for y in range(H):
		var ky: float = keep_row(y)
		for x in range(w):
			data[i] = int(round(_band(1.0 - ky * cols[x]) * 255.0))
			i += 4
	var tex := ImageTexture.create_from_image(Image.create_from_data(w, H, false, Image.FORMAT_RGBA8, data))
	_cache[key] = tex
	return tex


static func seam_texture(w: int) -> Texture2D:
	var key := "seam:%d" % w
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, H, false, Image.FORMAT_RGBA8)
	for y in range(H):
		var a := seam_at(y)
		for x in range(w):
			img.set_pixel(x, y, Color(0, 0, 0, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static var _unshaded: CanvasItemMaterial = null


static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Where a room's light comes from by night: the nearest lit fixture to the room's middle, else its daylight (the moon through the glass). `lamps` is an apartment_lights node (or null).
static func light_x_for(module: Node2D, lamps: Node, day_x: float, run: int, w: int) -> float:
	if run < 2 or lamps == null or not lamps.has_method("lamps"):
		return day_x
	var best := day_x
	var best_d := INF
	for e in lamps.lamps():
		var lt = e.get("light")
		if lt == null or not is_instance_valid(lt):
			continue
		var lx: float = (lt as Node2D).position.x            # the lamps node sits at the module's origin, so this is module-local
		var d: float = absf(lx - float(w) * 0.5)
		if d < best_d:
			best_d = d
			best = lx
	return best


## Lay the room's depth into `module`. `opts`: {width, end_l, end_r, day_x (the window / balcony door, module x), run, planned (bool), lamps (apartment_lights or null)}.
## Returns {shade, seam, shadows: [...], light_x} - the nodes made, for tests and tools. Calling it twice on a module does nothing the second time.
static func add_to(module: Node2D, opts: Dictionary) -> Dictionary:
	var made := {"shade": null, "seam": null, "shadows": [], "light_x": 0.0}
	if module == null or module.has_node("DepthShade"):
		return made
	var w: int = int(opts.get("width", ModuleGeo.WIDTH))
	var run: int = clampi(int(opts.get("run", 1)), 1, 3)
	var day_x: float = float(opts.get("day_x", float(w) * 0.5))
	var planned: bool = bool(opts.get("planned", false))
	var art := module.get_node_or_null("Art")
	var under_at: int = (art.get_index() + 1) if art != null else 0
	# what the furniture stands in front of: the seam first, then every cast shadow, then (already there) the furniture itself
	if planned:
		var seam := Sprite2D.new()
		seam.name = "DepthSeam"
		seam.texture = seam_texture(w)
		seam.centered = false
		seam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		seam.material = unshaded()
		module.add_child(seam)
		module.move_child(seam, under_at)
		under_at += 1
		made["seam"] = seam
		var lx: float = light_x_for(module, opts.get("lamps"), day_x, run, w)
		made["light_x"] = lx
		made["shadows"] = _cast_shadows(module, under_at, lx, run)
	# the shade goes over the furniture and under everything that is not the room itself (the window's glass, the scavenge nodes)
	var shade := Sprite2D.new()
	shade.name = "DepthShade"
	shade.texture = shade_texture(w, bool(opts.get("end_l", false)), bool(opts.get("end_r", false)), day_x, run)
	shade.centered = false
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shade.material = unshaded()
	module.add_child(shade)
	module.move_child(shade, _over_index(module))
	made["shade"] = shade
	return made


## The child index just above the room's own picture: after the Art, the strip art and every furniture sprite / opened drawer - and before the window, the front art and the nodes.
static func _over_index(module: Node2D) -> int:
	var at := 0
	var i := 0
	for c in module.get_children():
		if c.name == "Art" or c.name == "StripArt" or c.has_meta("furniture") or c.has_meta("cast_shadow") or String(c.name).begins_with("Open_") or c.name == "DepthSeam":
			at = i + 1
		i += 1
	return at


static func _cast_shadows(module: Node2D, at: int, light_x: float, run: int) -> Array:
	var out: Array = []
	var r := clampi(run - 1, 0, 2)
	var pieces: Array = []
	for c in module.get_children():
		if c is Sprite2D and c.has_meta("furniture"):
			pieces.append(c)
	for c in pieces:
		var s := c as Sprite2D
		var spec: Array = CAST.get(String(s.get_meta("plane", "")), [])
		if spec.is_empty() or s.texture == null:
			continue
		var cx: float = s.position.x + float(s.texture.get_width()) * 0.5
		var k: float = clampf((cx - light_x) / CAST_SPAN, -1.0, 1.0)
		for o in spec:
			var dx: float = round(float(o[0]) * k * float(CAST_LEN_BY_RUN[r]))
			var dy: float = float(o[1])
			var sh := Sprite2D.new()
			sh.name = "Cast_%s_%d" % [String(s.name), out.size()]
			sh.texture = s.texture
			sh.centered = false
			sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sh.position = s.position + Vector2(dx, dy)
			sh.modulate = Color(0, 0, 0, clampf(float(o[2]) * float(CAST_ALPHA_BY_RUN[r]), 0.0, 0.6))
			sh.material = unshaded()
			sh.set_meta("cast_shadow", String(s.get_meta("furniture")))
			module.add_child(sh)
			module.move_child(sh, at)
			at += 1
			out.append(sh)
	out.append_array(_floor_shadows(module, pieces, light_x, run))
	return out


## The shadow each standing piece lays on the FLOOR: its own texture, black, flipped about its foot and squashed down the boards, leaning away from the light (a shear —
## the tip of a tall piece's shadow lands furthest from it). Drawn over the rugs (a sofa's shadow falls on its rug) and under every other piece. Marked `floor_shadow`.
static func _floor_shadows(module: Node2D, pieces: Array, light_x: float, run: int) -> Array:
	var out: Array = []
	var r := clampi(run - 1, 0, 2)
	# after the rugs (which the planner lays first), before everything that stands
	var at := -1
	for c in module.get_children():
		if c is Sprite2D and c.has_meta("furniture") and String(c.get_meta("plane", "")) != "rug":
			at = c.get_index()
			break
	if at < 0:
		return out
	for c in pieces:
		var s := c as Sprite2D
		var spec: Array = FLOOR_CAST.get(String(s.get_meta("plane", "")), [])
		if spec.is_empty() or s.texture == null:
			continue
		var w: float = float(s.texture.get_width())
		var h: float = float(s.texture.get_height())
		var length: float = clampf(h * float(spec[0]) * float(FLOOR_LEN_BY_RUN[r]), FLOOR_MIN_LEN, FLOOR_MAX_LEN)
		var k: float = clampf((s.position.x + w * 0.5 - light_x) / CAST_SPAN, -1.0, 1.0)
		var throw: float = round(length * FLOOR_THROW * k)
		var sh := Sprite2D.new()
		sh.name = "Floor_%s" % String(s.name)
		sh.texture = s.texture
		sh.centered = false
		sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# texel (u, v) -> (x + u + (h - v) * throw / h,  foot + (h - v) * length / h): the foot row stays on the foot line, the top lands `length` rows down and `throw` px across
		sh.transform = Transform2D(Vector2(1.0, 0.0), Vector2(-throw / h, -length / h), s.position + Vector2(throw, h + length))
		sh.modulate = Color(0, 0, 0, clampf(float(spec[1]) * float(CAST_ALPHA_BY_RUN[r]), 0.0, 0.5))
		sh.material = unshaded()
		sh.set_meta("floor_shadow", String(s.get_meta("furniture")))
		sh.set_meta("throw", throw)
		sh.set_meta("length", length)
		module.add_child(sh)
		module.move_child(sh, at)
		at += 1
		out.append(sh)
	return out


# === CORRIDORS ========================================================================================================================
# The same idea for a floor's corridor (the 1120 x 192 painted art, building_floors.add_corridor_art): the dark under the ceiling, the strip of floor against the wall, the floor's
# near edge - and a long hall's own light: daylight comes in at the stairwell windows at its ENDS, so the middle of the corridor is the dim part (where the wall lamps then do
# their work in the afternoon and at night). Two one-pixel-wide profiles stretched over the art (their darks multiply), children of the art itself so the doors, the dressing and
# every actor - drawn after it - are not shaded twice.
const HALL_W := 1120
const HALL_H := 192
const HALL_SEAM := 160               # the skirting: the wall meets the floor (art row)
const HALL_CEIL_REACH := 44.0
const HALL_CEIL_AO := 0.36
const HALL_WALL_LIFT := 0.06
const HALL_SEAM_DOWN := 9.0
const HALL_SEAM_AO := 0.20
const HALL_FRONT_REACH := 13.0
const HALL_FRONT_AO := 0.22
const HALL_WINDOW_X := [56.0, 1064.0]            # the stairwell windows, in art columns (world 171 / 1179)
const HALL_FALL_START := 110.0
const HALL_FALL_SPAN := 380.0
const HALL_FALLOFF_BY_RUN := [0.14, 0.22, 0.10]


static func hall_row_dark(y: int) -> float:
	var keep := 1.0
	keep *= 1.0 - HALL_CEIL_AO * pow(1.0 - clampf(float(y) / HALL_CEIL_REACH, 0.0, 1.0), 1.6)
	if y < HALL_SEAM:
		keep *= 1.0 - HALL_WALL_LIFT * (1.0 - float(y) / float(HALL_SEAM))
	else:
		keep *= 1.0 - HALL_SEAM_AO * (1.0 - _smooth(float(y - HALL_SEAM) / HALL_SEAM_DOWN))
	keep *= 1.0 - HALL_FRONT_AO * _smooth(1.0 - float(HALL_H - 1 - y) / HALL_FRONT_REACH)
	return _band(1.0 - keep)


## `sides`: which ends have a stairwell window ("left", "right"); a floor with none is evenly lit along its length.
static func hall_col_dark(x: int, sides: Array, run: int) -> float:
	var near := INF
	if sides.has("left"):
		near = minf(near, absf(float(x) - float(HALL_WINDOW_X[0])))
	if sides.has("right"):
		near = minf(near, absf(float(x) - float(HALL_WINDOW_X[1])))
	if near == INF:
		return 0.0
	return _band(float(HALL_FALLOFF_BY_RUN[clampi(run - 1, 0, 2)]) * _smooth((near - HALL_FALL_START) / HALL_FALL_SPAN))


static func _hall_profiles(sides: Array, run: int) -> Array:
	var key := "hall:%s:%s:%d" % [str(sides.has("left")), str(sides.has("right")), run]
	if _cache.has(key):
		return _cache[key]
	var col := Image.create(1, HALL_H, false, Image.FORMAT_RGBA8)
	for y in range(HALL_H):
		col.set_pixel(0, y, Color(0, 0, 0, hall_row_dark(y)))
	var row := Image.create(HALL_W, 1, false, Image.FORMAT_RGBA8)
	for x in range(HALL_W):
		row.set_pixel(x, 0, Color(0, 0, 0, hall_col_dark(x, sides, run)))
	var pair := [ImageTexture.create_from_image(col), ImageTexture.create_from_image(row)]
	_cache[key] = pair
	return pair


## Shade a corridor's painted art (`root` holds the `CorridorArt` sprite). Idempotent. Returns the two sprites made ([] when there is no art).
static func add_to_corridor(root: Node, sides: Array, run: int) -> Array:
	if root == null:
		return []
	var art := root.get_node_or_null("CorridorArt") as Sprite2D
	if art == null or art.has_node("DepthRows"):
		return []
	var pair: Array = _hall_profiles(sides, clampi(run, 1, 3))
	var rows := Sprite2D.new()
	rows.name = "DepthRows"
	rows.texture = pair[0]
	rows.centered = false
	rows.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rows.scale = Vector2(float(HALL_W), 1.0)
	rows.material = unshaded()
	art.add_child(rows)
	var cols := Sprite2D.new()
	cols.name = "DepthCols"
	cols.texture = pair[1]
	cols.centered = false
	cols.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cols.scale = Vector2(1.0, float(HALL_H))
	cols.material = unshaded()
	art.add_child(cols)
	return [rows, cols]


# --- what stands in a corridor throws a shadow up the wall behind it -------------------------------------------------------------------
const HALL_LAMP_X := [265.0, 392.0, 518.0, 647.0, 770.0]       # the wall lamps in art columns (FloorLighting.SCONCE_X - 115)
const HALL_CAST := [[3.0, 0.0, 0.24], [5.0, 1.0, 0.11]]


## Where the light on a corridor prop at art column `cx` comes from: the nearer stairwell window by day, the nearest wall lamp from dusk on.
static func hall_light_x(cx: float, run: int) -> float:
	var pool: Array = HALL_WINDOW_X if run <= 1 else HALL_LAMP_X
	var best: float = float(pool[0])
	for lx in pool:
		if absf(cx - float(lx)) < absf(cx - best):
			best = float(lx)
	return best


## Shadows for one standing prop `s` (a child of the corridor's decal layer `holder`), drawn just under it. Returns the sprites made.
static func add_corridor_cast(holder: Node, s: Sprite2D, run: int) -> Array:
	var out: Array = []
	if holder == null or s == null or s.texture == null:
		return out
	var r := clampi(run - 1, 0, 2)
	var cx: float = s.position.x + float(s.texture.get_width()) * 0.5
	var k: float = clampf((cx - hall_light_x(cx, run)) / CAST_SPAN, -1.0, 1.0)
	var at: int = s.get_index()
	for o in HALL_CAST:
		var dx: float = round(float(o[0]) * k * float(CAST_LEN_BY_RUN[r]))
		if absf(dx) < 1.0:
			dx = 1.0 if k >= 0.0 else -1.0                # (straight under a lamp: still a sliver, so the prop never sits flat on the paper)
		var sh := Sprite2D.new()
		sh.name = "Cast_%d_%d" % [at, out.size()]
		sh.texture = s.texture
		sh.centered = false
		sh.flip_h = s.flip_h
		sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sh.position = s.position + Vector2(dx, float(o[1]))
		sh.modulate = Color(0, 0, 0, clampf(float(o[2]) * float(CAST_ALPHA_BY_RUN[r]), 0.0, 0.6))
		sh.material = unshaded()
		sh.set_meta("cast_shadow", String(s.get_meta("decal", "")))
		holder.add_child(sh)
		holder.move_child(sh, at)
		at += 1
		out.append(sh)
	return out
