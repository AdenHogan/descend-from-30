class_name BuildingMap
extends Control

# THE JOURNAL'S MAP (owner round 48i: "the map shows us nothing really. It should show us what we've seen so far in the building. A mini version
# detailing where things are that we've seen, where fire might be. It needs detail, even if the map needs to be scrolled").
#
# One tall page, a ROW per floor (30 down to the lobby), each row the corridor in miniature drawn in pencil at the corridor's own scale:
# the two stairwells (the way DOWN marked, a barricade crossed through), the five flats' doors as their states are SEEN (shut, been inside,
# a breached hole, boarded up, burning, burnt out), the lift (a $ where the merchant keeps it), the staff door of a maintenance floor, the
# fire where it was last seen burning (and the char where it burnt out), the dead last seen standing there, any living person, the bodies
# of the characters who fell, and YOU. A floor the player has never set foot on is fog: hatched, its number and nothing else.
#
# All the DECIDING is `row_model(floor)` (pure: reads the world's memory, draws nothing) so a test can prove what the map says; `_draw` only
# turns that model into pencil strokes. Put it inside a ScrollContainer (character_panel does) — its height is the whole building.

const FONT := preload("res://assets/fonts/PixelOperator8.ttf")
const FIRE_FIELD := preload("res://scripts/fire_field.gd")     # no class_name: the cell grid (FIRE_MIN_X, CELL_W) the fire memory is indexed by

const ROW_H := 66.0
const HEAD_H := 58.0                      # the key at the top of the page
const GUTTER := 36.0                      # the floor numbers
const PAD_R := 10.0
const WORLD_X0 := 115.0                   # the corridor's walkable span in world px (docs/Y_PLANES.md)
const WORLD_X1 := 1235.0
const STAIR_LEFT := Vector2(131.0, 211.0)       # a stairwell's drawn box in world x
const STAIR_RIGHT := Vector2(1139.0, 1219.0)
const DOOR_W := 46.0                      # a flat door in world px
const MAINT_X := 929.0
const ELEVATOR_X := 1029.5
const EXIT_X := 654.0                     # the lobby's street door
const FLOORS := 31                        # 30 .. 1 and the lobby (0)

# What a door can show (row_model → doors[i].kind)
const D_SHUT := "shut"
const D_IN := "entered"
const D_BREACH := "breached"
const D_BOARDED := "boarded"
const D_BURNING := "burning"
const D_CHARRED := "charred"

var hand: Font = null
var ink: Color = Color(0.20, 0.15, 0.09)


func _ready() -> void:
	custom_minimum_size = Vector2(300, content_height())


static func content_height() -> float:
	return HEAD_H + float(FLOORS) * ROW_H + 8.0


## The y of a floor's row (floor 30 first, the lobby last).
static func row_top(floor_num: int) -> float:
	return HEAD_H + float(30 - clampi(floor_num, 0, 30)) * ROW_H


## Which floor a y in the map belongs to (the click / scroll maths), -1 outside the rows.
static func floor_at(y: float) -> int:
	if y < HEAD_H:
		return -1
	var k := int(floor((y - HEAD_H) / ROW_H))
	if k < 0 or k >= FLOORS:
		return -1
	return 30 - k


## World x → the bar's x for a bar spanning [bx, bx + bw].
static func map_x(world_x: float, bx: float, bw: float) -> float:
	return bx + (world_x - WORLD_X0) / (WORLD_X1 - WORLD_X0) * bw


# -------------------------------------------------------------------------------------------------------- what the map says
## Everything the map knows about one floor, as data. `visited` false → fog: nothing else is filled in.
static func row_model(floor_num: int) -> Dictionary:
	var key := str(floor_num)
	var m := {"floor": floor_num, "visited": WorldState.visited_floors.has(key), "current": floor_num == WorldState.current_floor,
		"doors": [], "stairs": [], "maintenance": false, "merchant": false, "lift": floor_num >= 1 and floor_num <= 29,
		"exit": floor_num == 0, "fire": [], "spent": [], "dead": [], "people": [], "corpses": [], "dead_seen": false, "you_x": -1.0, "you_door": -1}
	if not m["visited"]:
		return m
	# the two stairwells: which is the way DOWN is a pure function of the floor (stair_down_side)
	if floor_num == 30:
		m["stairs"].append({"side": "left", "down": true, "blocked": false})
	elif floor_num == 0:
		m["stairs"].append({"side": "right", "down": false, "blocked": false})
	else:
		var down_side: String = WorldState.stair_down_side(floor_num)
		for side in ["left", "right"]:
			var is_down: bool = side == down_side
			m["stairs"].append({"side": side, "down": is_down, "blocked": is_down and WorldState.is_stair_blocked(floor_num)})
	m["maintenance"] = WorldState.is_maintenance_floor(floor_num)
	m["merchant"] = floor_num in WorldState.MERCHANT_FLOORS
	# the flats' doors, as seen from the corridor (plus the ones the player has stood inside)
	if floor_num >= 1:
		for idx in range(1, 6):
			var id := str(floor_num * 100 + idx)
			var d := {"idx": idx, "id": id, "kind": D_SHUT, "x": float(WorldState.APARTMENT_X.get(idx, 0.0))}
			var fire_stage: int = WorldState.apartment_active_fire_stage(floor_num, idx)
			var state: int = WorldState.get_door_state(id)
			if fire_stage == WorldState.FIRE_CHARRED:
				d["kind"] = D_CHARRED
			elif fire_stage == WorldState.FIRE_BLAZE:
				d["kind"] = D_BURNING
			elif state == WorldState.DoorState.BREACHED:
				d["kind"] = D_BREACH
			elif state == WorldState.DoorState.BARRICADED_FORCEABLE or state == WorldState.DoorState.BARRICADED_LOCKED:
				d["kind"] = D_BOARDED
			elif WorldState.map_entered.has(id) or id in WorldState.run_apartments_looted:
				d["kind"] = D_IN
			m["doors"].append(d)
	# fire, where it was last seen: this run's snapshot of the cells (burning = 1, burnt out = 2)
	if WorldState.has_fire_cells(floor_num):
		var cells: Array = WorldState.get_fire_cells(floor_num)
		for i in cells.size():
			var wx: float = FIRE_FIELD.FIRE_MIN_X + (float(i) + 0.5) * FIRE_FIELD.CELL_W
			if int(cells[i]) == 1:
				m["fire"].append(wx)
			elif int(cells[i]) == 2:
				m["spent"].append(wx)
	# …and, from an earlier run, the thirds of the corridor that burned (soot stays)
	if m["spent"].is_empty() and m["fire"].is_empty():
		var zone: String = WorldState.fire_scar_zone(floor_num)
		if zone != "":
			var lo := WORLD_X0
			var hi := WORLD_X1
			var thirds: float = (WORLD_X1 - WORLD_X0) / 3.0
			if zone == "l":
				hi = WORLD_X0 + thirds
			elif zone == "m":
				lo = WORLD_X0 + thirds
				hi = WORLD_X0 + 2.0 * thirds
			elif zone == "r":
				lo = WORLD_X1 - thirds
			elif zone == "lm":
				hi = WORLD_X0 + 2.0 * thirds
			elif zone == "mr":
				lo = WORLD_X0 + thirds
			var x := lo + 21.0
			while x < hi:
				m["spent"].append(x)
				x += FIRE_FIELD.CELL_W
	var sight: Dictionary = WorldState.map_sights.get(key, {})
	for x in sight.get("dead", []):
		m["dead"].append(float(x))
	for x in sight.get("people", []):
		m["people"].append(float(x))
	m["dead_seen"] = WorldState.floors_enemy_seen.has(key) or not m["dead"].is_empty()
	for rk in WorldState.player_corpses:
		var rec: Dictionary = WorldState.player_corpses[rk]
		if int(rec.get("floor", -1)) == floor_num:
			m["corpses"].append({"x": float(rec.get("x", 0.0)), "apt": str(rec.get("apartment_id", ""))})
	if m["current"]:
		var apt: String = WorldState.current_apartment_id
		var tree := Engine.get_main_loop() as SceneTree
		var p = tree.get_first_node_in_group("player") if tree != null else null
		var in_flat: bool = p != null and is_instance_valid(p) and WorldState.world_scene_of(p).ends_with("room.tscn")
		if apt != "" and in_flat:
			m["you_door"] = int(apt) % 100
		elif p != null and is_instance_valid(p):
			m["you_x"] = clampf(float(p.global_position.x), WORLD_X0, WORLD_X1)
	return m


# -------------------------------------------------------------------------------------------------------- drawing
func _sketch(r: Rect2, col: Color, width: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var j := func() -> float: return rng.randf_range(-0.9, 0.9)
	var a := r.position
	var b := Vector2(r.end.x, r.position.y)
	var c := r.end
	var d := Vector2(r.position.x, r.end.y)
	draw_line(a + Vector2(-1.2, j.call()), b + Vector2(1.2, j.call()), col, width)
	draw_line(b + Vector2(j.call(), -1.2), c + Vector2(j.call(), 1.2), col, width)
	draw_line(c + Vector2(1.2, j.call()), d + Vector2(-1.2, j.call()), col, width)
	draw_line(d + Vector2(j.call(), 1.2), a + Vector2(j.call(), -1.2), col, width)


func _label(f: Font, pos: Vector2, text: String, size: int, col: Color) -> void:
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _flame(cx: float, base: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(cx - h * 0.32, base), Vector2(cx - h * 0.22, base - h * 0.55), Vector2(cx - h * 0.04, base - h * 0.38),
		Vector2(cx + h * 0.02, base - h), Vector2(cx + h * 0.2, base - h * 0.5), Vector2(cx + h * 0.34, base)])
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - h * 0.14, base), Vector2(cx, base - h * 0.5), Vector2(cx + h * 0.16, base)]), Color(0.98, 0.78, 0.25, 0.95))


func _door(m: Dictionary, bx: float, bw: float, top: float, h: float, d: Dictionary, you: bool) -> void:
	var cx: float = map_x(float(d["x"]), bx, bw)
	var w: float = DOOR_W / (WORLD_X1 - WORLD_X0) * bw
	var r := Rect2(cx - w * 0.5, top + h - 26.0, w, 26.0)
	var f: Font = hand if hand != null else FONT
	var kind: String = d["kind"]
	var line := Color(ink.r, ink.g, ink.b, 0.85)
	match kind:
		D_CHARRED:
			draw_rect(r, Color(0.13, 0.11, 0.10, 0.85))
			for k in 3:
				draw_line(Vector2(r.position.x + 1.0, r.position.y + 5.0 + 5.0 * k), Vector2(r.end.x - 1.0, r.position.y + 2.0 + 5.0 * k), Color(0.4, 0.38, 0.36, 0.7), 1.0)
		D_BURNING:
			draw_rect(r, Color(0.55, 0.30, 0.15, 0.35))
			_flame(cx - w * 0.22, r.position.y + 6.0, 11.0, Color(0.85, 0.28, 0.12, 0.95))
			_flame(cx + w * 0.22, r.position.y + 8.0, 8.0, Color(0.9, 0.38, 0.14, 0.95))
		D_BREACH:
			draw_rect(r, Color(0.08, 0.06, 0.05, 0.9))
			var zig := PackedVector2Array([Vector2(r.position.x - 2.0, r.position.y + 7.0), Vector2(r.position.x + w * 0.25, r.position.y + 2.0),
				Vector2(r.position.x + w * 0.5, r.position.y + 8.0), Vector2(r.position.x + w * 0.75, r.position.y + 1.0), Vector2(r.end.x + 2.0, r.position.y + 6.0)])
			draw_polyline(zig, Color(0.62, 0.15, 0.12), 1.6)
		D_BOARDED:
			draw_rect(r, Color(0.62, 0.45, 0.25, 0.30))
			draw_line(r.position + Vector2(0, 3), r.end - Vector2(0, 3), Color(0.40, 0.26, 0.12), 1.8)
			draw_line(Vector2(r.position.x, r.end.y - 3.0), Vector2(r.end.x, r.position.y + 3.0), Color(0.40, 0.26, 0.12), 1.8)
		D_IN:
			draw_rect(r, Color(0.95, 0.88, 0.68, 0.55))
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - w * 0.42, r.position.y + 4.0), line, 1.2)       # the leaf swung open
			draw_line(Vector2(r.end.x - w * 0.42, r.position.y + 4.0), Vector2(r.end.x - w * 0.42, r.end.y), line, 1.2)
		_:
			draw_rect(r, Color(ink.r, ink.g, ink.b, 0.10))
	_sketch(r, line if kind != D_CHARRED else Color(0.2, 0.2, 0.2, 0.9), 1.1, int(d["idx"]) * 31 + int(m["floor"]) * 7)
	if kind == D_SHUT or kind == D_IN:
		draw_circle(Vector2(r.end.x - 3.0, r.position.y + 11.0), 0.9, line)                                              # a handle
	_label(f, Vector2(r.position.x + 1.0, top + h - 28.0), "%02d" % int(d["idx"]), 10, Color(ink.r, ink.g, ink.b, 0.8))
	if you:
		_sketch(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(0.80, 0.22, 0.12), 1.8, 77 + int(d["idx"]))


func _stair(bx: float, bw: float, top: float, h: float, s: Dictionary, f: Font) -> void:
	var span: Vector2 = STAIR_LEFT if s["side"] == "left" else STAIR_RIGHT
	var x0: float = map_x(span.x, bx, bw)
	var x1: float = map_x(span.y, bx, bw)
	var r := Rect2(x0, top + 4.0, x1 - x0, h - 8.0)
	draw_rect(r, Color(ink.r, ink.g, ink.b, 0.14 if bool(s["down"]) else 0.07))
	for k in 4:                                                                              # the flight, in treads
		var y: float = r.position.y + 5.0 + 6.0 * k
		draw_line(Vector2(r.position.x + 2.0 + 2.0 * k, y), Vector2(r.end.x - 2.0, y), Color(ink.r, ink.g, ink.b, 0.5), 1.0)
	_sketch(r, Color(ink.r, ink.g, ink.b, 0.7), 1.1, 5 if s["side"] == "left" else 9)
	if bool(s["down"]):
		var ax: float = (x0 + x1) * 0.5
		var ay: float = r.end.y - 6.0
		draw_polyline(PackedVector2Array([Vector2(ax - 4.0, ay - 5.0), Vector2(ax, ay), Vector2(ax + 4.0, ay - 5.0)]), Color(0.78, 0.22, 0.12), 1.6)
	if bool(s["blocked"]):
		draw_line(r.position, r.end, Color(0.55, 0.12, 0.08), 2.0)
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color(0.55, 0.12, 0.08), 2.0)


func _draw() -> void:
	var f: Font = hand if hand != null else FONT
	var bx := GUTTER + 4.0
	var bw: float = maxf(120.0, size.x - bx - PAD_R)
	# ---- the key
	var ky := 4.0
	_label(f, Vector2(2.0, ky + 12.0), "WHAT YOU HAVE SEEN", 12, ink)
	var key_items := [["dead", "the dead, last seen"], ["person", "someone living"], ["body", "one of you fell"], ["fire", "fire / char"], ["you", "you are here"]]
	var kx := 2.0
	var kyy := ky + 30.0
	for it in key_items:
		var c := Vector2(kx + 5.0, kyy - 3.0)
		match it[0]:
			"dead":
				draw_circle(c, 3.0, Color(0.75, 0.16, 0.13))
			"person":
				draw_arc(c, 3.2, 0.0, TAU, 14, Color(0.18, 0.5, 0.32), 1.6)
			"body":
				draw_circle(c, 3.0, Color(0.30, 0.45, 0.85))
			"fire":
				_flame(c.x, c.y + 4.0, 9.0, Color(0.85, 0.28, 0.12, 0.95))
			"you":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3.5, 4), c + Vector2(3.5, 4), c + Vector2(0, -4)]), Color(0.80, 0.22, 0.12))
		_label(f, Vector2(kx + 13.0, kyy), it[1], 8, Color(ink.r, ink.g, ink.b, 0.85))
		kx += 14.0 + float(String(it[1]).length()) * 5.4
		if kx > size.x - 80.0:
			kx = 2.0
			kyy += 14.0
	var kyy2 := kyy + 14.0
	_label(f, Vector2(2.0, kyy2), "doors: shut · been in · breached · boarded · burning · burnt out   ▼ the way down", 8, Color(ink.r, ink.g, ink.b, 0.6))
	# ---- the rows
	for fl in range(30, -1, -1):
		var m: Dictionary = row_model(fl)
		var top: float = row_top(fl)
		var r := Rect2(bx, top + 3.0, bw, ROW_H - 6.0)
		var visited: bool = m["visited"]
		var nlabel := "L" if fl == 0 else str(fl)
		_label(f, Vector2(2.0, top + ROW_H * 0.5 + 5.0), nlabel, 15 if visited else 13, ink if visited else Color(ink.r, ink.g, ink.b, 0.45))
		if not visited:
			draw_rect(r, Color(0.25, 0.22, 0.18, 0.14))
			for hx in range(0, int(r.size.x), 9):
				draw_line(Vector2(r.position.x + hx, r.end.y), Vector2(r.position.x + hx + 5.0, r.position.y), Color(0.2, 0.17, 0.13, 0.10), 1.0)
			_sketch(r, Color(ink.r, ink.g, ink.b, 0.26), 1.1, fl * 53 + 7)
			continue
		draw_rect(r, Color(1.0, 0.97, 0.88, 0.22))
		# the floor line and the ceiling, so a row reads as a corridor
		draw_line(Vector2(r.position.x, r.end.y - 5.0), Vector2(r.end.x, r.end.y - 5.0), Color(ink.r, ink.g, ink.b, 0.35), 1.0)
		var bar_top: float = r.position.y
		var bar_h: float = r.size.y
		# fire: char first (under), then the flames
		for wx in m["spent"]:
			var sx: float = map_x(float(wx), bx, bw)
			draw_rect(Rect2(sx - 3.0, r.end.y - 9.0, 6.0, 8.0), Color(0.16, 0.14, 0.12, 0.40))
		for s in m["stairs"]:
			_stair(bx, bw, bar_top, bar_h, s, f)
		for d in m["doors"]:
			_door(m, bx, bw, bar_top, bar_h, d, int(m["you_door"]) == int(d["idx"]))
		if m["maintenance"]:
			var mx: float = map_x(MAINT_X, bx, bw)
			var mr := Rect2(mx - 7.0, r.end.y - 26.0, 14.0, 26.0)
			draw_rect(mr, Color(0.35, 0.40, 0.45, 0.28))
			_sketch(mr, Color(ink.r, ink.g, ink.b, 0.8), 1.1, fl * 11 + 3)
			_label(f, Vector2(mx - 3.5, r.end.y - 6.0), "M", 10, ink)
		if m["lift"]:
			var lx: float = map_x(ELEVATOR_X, bx, bw)
			var lr := Rect2(lx - 9.0, r.end.y - 26.0, 18.0, 26.0)
			draw_rect(lr, Color(0.45, 0.45, 0.48, 0.28))
			draw_line(Vector2(lx, lr.position.y + 1.0), Vector2(lx, lr.end.y - 1.0), Color(ink.r, ink.g, ink.b, 0.6), 1.0)
			_sketch(lr, Color(ink.r, ink.g, ink.b, 0.8), 1.1, fl * 13 + 5)
			if m["merchant"]:
				_label(f, Vector2(lx - 3.5, lr.position.y - 2.0), "$", 11, Color(0.18, 0.5, 0.2))
		if m["exit"]:
			var ex: float = map_x(EXIT_X, bx, bw)
			var er := Rect2(ex - 12.0, r.end.y - 26.0, 24.0, 26.0)
			draw_rect(er, Color(0.95, 0.9, 0.7, 0.5))
			_sketch(er, Color(ink.r, ink.g, ink.b, 0.85), 1.2, 41)
			_label(f, Vector2(ex - 9.0, er.position.y - 3.0), "OUT", 9, ink)
		for wx in m["fire"]:
			_flame(map_x(float(wx), bx, bw), r.end.y - 6.0, 15.0, Color(0.85, 0.28, 0.12, 0.95))
		for wx in m["dead"]:
			var dx: float = map_x(float(wx), bx, bw)
			draw_circle(Vector2(dx, r.position.y + 7.0), 3.4, Color(0.75, 0.16, 0.13))
		if m["dead"].is_empty() and m["dead_seen"]:
			draw_circle(Vector2(r.end.x - 8.0, r.position.y + 7.0), 2.8, Color(0.75, 0.16, 0.13, 0.55))     # seen, but not where
		for wx in m["people"]:
			draw_arc(Vector2(map_x(float(wx), bx, bw), r.position.y + 7.0), 3.2, 0.0, TAU, 14, Color(0.18, 0.5, 0.32), 1.6)
		for cp in m["corpses"]:
			var cx: float = map_x(float(cp["x"]) if String(cp["apt"]) == "" else map_x_for_apt(String(cp["apt"])), bx, bw)
			draw_circle(Vector2(cx, r.position.y + 7.0), 3.0, Color(0.30, 0.45, 0.85))
			draw_line(Vector2(cx - 2.0, r.position.y + 7.0), Vector2(cx + 2.0, r.position.y + 7.0), Color(1, 1, 1, 0.9), 1.0)
		if m["current"]:
			_sketch(Rect2(r.position - Vector2(2, 1), r.size + Vector2(4, 2)), Color(0.80, 0.22, 0.12), 2.0, 991)
			if float(m["you_x"]) >= 0.0:
				var ux: float = map_x(float(m["you_x"]), bx, bw)
				draw_colored_polygon(PackedVector2Array([Vector2(ux - 4.0, r.end.y - 1.0), Vector2(ux + 4.0, r.end.y - 1.0), Vector2(ux, r.end.y - 10.0)]), Color(0.80, 0.22, 0.12))


## A flat's door x in the corridor, so a body that fell in a flat is drawn at its door.
static func map_x_for_apt(apt_id: String) -> float:
	var idx: int = int(apt_id) % 100
	return float(WorldState.APARTMENT_X.get(idx, 675.0))
