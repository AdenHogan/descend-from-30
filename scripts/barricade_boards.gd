extends Node2D
## BARRICADE BOARDS (owner round 22 — "make removing barricades look more exciting from a visual
## standpoint… the UX needs to look good too, not just the box showing the time counting down, and
## the spikey shape"). Replaces the placeholder crate sprite + the black ColorRect that shrank as you
## worked.
##
## The barricade is BOARDS nailed across the door (seeded per door: how many, their angles, the wood —
## pine, stained planks, a painted door panel, a table top), drawn in pixels. Removing it is the boards
## coming off ONE AT A TIME: the one you're on strains with every heave (it jolts, its nails creep out),
## splinters and plaster dust burst off it, and at its share of the work it RIPS free — flies out,
## spinning, bounces and lies on the corridor floor. A segmented bar over the door (one segment a
## board) says how far you are without a number. Saved progress shows as boards already gone.
## The door (scripts/door.gd) drives it: set_progress() every frame of work, heave() on each rip,
## tear_all() when the last board goes.

const DOOR_HALF_W := 22.0        # the door face (door art 46×84, centred on the door node)
const MAX_REACH := 23.0          # a board end's reach from the door's centre (its ragged end adds up to 2)
const DOOR_TOP := -41.0
const DOOR_BOTTOM := 43.0        # its foot: the corridor floor line (419) in the door's own space
const BAR_Y := -35.0             # the progress bar, across the door head (just under the prompt pill)
const GRAVITY := 720.0
const WOODS := [
	[Color8(170, 128, 82), Color8(122, 86, 52)],      # pine
	[Color8(118, 78, 48), Color8(80, 52, 32)],        # stained plank
	[Color8(150, 104, 66), Color8(104, 70, 42)],      # old floorboard
	[Color8(188, 184, 170), Color8(132, 128, 118)],   # a painted door panel
	[Color8(96, 108, 84), Color8(66, 74, 58)],        # green-painted shelf
	[Color8(136, 92, 60), Color8(94, 62, 40)],        # a table top
]

var boards: Array = []           # {c: Vector2, ang, len, w, col, dark, gone}
var order: Array = []            # the order they come off (indices into boards)
var frac := 0.0                  # removal progress 0..1
var working := false
var _strain := 0.0               # the current board's jolt (decays)
var _t := 0.0
var _air: Array = []             # torn boards: {p, v, rot, vr, len, w, col, dark, landed, bounces}
var _ground: Node2D = null       # boards lying on the corridor floor (z 0, under the living)
var _flight: Node2D = null       # boards in the air (in front of everything)
var _landed: Array = []
var _rng := RandomNumberGenerator.new()


func setup(seed_text: String) -> void:
	name = "BarricadeBoards"
	_rng.seed = hash(seed_text)
	boards.clear()
	var n := _rng.randi_range(4, 6)
	for i in range(n):
		var y := lerpf(DOOR_TOP + 12.0, DOOR_BOTTOM - 16.0, (float(i) + _rng.randf_range(0.2, 0.8)) / float(n))
		var ang := _rng.randf_range(-0.32, 0.32)
		if i == n / 2 and _rng.randf() < 0.6:
			ang = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.7, 0.95)   # a brace, corner to corner
		var wood: Array = WOODS[_rng.randi() % WOODS.size()]
		var ln := DOOR_HALF_W * 2.0 + _rng.randf_range(6.0, 14.0)
		if absf(ang) > 0.5:
			ln = 70.0
		var cx := _rng.randf_range(-3.0, 3.0)
		var bw := _rng.randf_range(6.0, 9.0)
		# the ends overhang the frame a little but never reach the door's number plate (door_plate.gd,
		# PLATE_GAP left of the face) — they clipped into it (owner round 23b)
		var reach := MAX_REACH - absf(cx) - absf(sin(ang)) * bw * 0.5
		ln = minf(ln, 2.0 * reach / maxf(0.2, absf(cos(ang))))
		boards.append({"c": Vector2(cx, y), "ang": ang, "len": ln,
			"w": bw, "col": wood[0], "dark": wood[1], "gone": false,
			"seed": _rng.randi()})
	order = range(n)
	for i in range(n - 1, 0, -1):                     # seeded shuffle: not always top to bottom
		var j := _rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	_ground = Node2D.new()
	_ground.name = "Fallen"
	_ground.z_as_relative = false
	_ground.z_index = 0
	_ground.draw.connect(_draw_ground)
	add_child(_ground)
	_flight = Node2D.new()
	_flight.name = "Flying"
	_flight.z_as_relative = false
	_flight.z_index = 3
	_flight.draw.connect(_draw_flight)
	add_child(_flight)


func board_count() -> int:
	return boards.size()


func boards_left() -> int:
	var k := 0
	for b in boards:
		if not b["gone"]:
			k += 1
	return k


## The share of the work each board takes: board order[i] comes off at (i + 1) / n.
func _threshold(i: int) -> float:
	return float(i + 1) / float(maxi(1, boards.size()))


## Progress 0..1. `live` = the player is at it right now (shows the bar, strains the board). Without
## `animate` (a saved fraction, a state change) the boards are simply there or not — no show.
func set_progress(f: float, live: bool, animate: bool = true) -> void:
	frac = clampf(f, 0.0, 1.0)
	working = live
	for i in range(order.size()):
		var b: Dictionary = boards[order[i]]
		var should_go := i < order.size() - 1 and frac >= _threshold(i) - 0.0001   # the last goes with tear_all()
		if should_go and not b["gone"]:
			b["gone"] = true
			if animate:
				_rip(b)
		elif not should_go and b["gone"] and not animate:
			b["gone"] = false
	queue_redraw()


## No barricade on this door (any more): no boards (the torn-off ones stay lying on the floor).
func clear_boards() -> void:
	working = false
	frac = 0.0
	for b in boards:
		b["gone"] = true
	queue_redraw()


## One heave (each rip sound): the board you're on jolts and sheds splinters + dust.
func heave() -> void:
	_strain = 1.0
	var b = _current()
	if b != null:
		_splinters(_board_end(b, 1.0 if _rng.randf() < 0.5 else -1.0), 6, false)


## The last board: gone, with the loudest crash.
func tear_all() -> void:
	frac = 1.0
	working = false
	for i in order:
		var b: Dictionary = boards[i]
		if not b["gone"]:
			b["gone"] = true
			_rip(b)
	queue_redraw()


func _current():
	for i in order:
		if not boards[i]["gone"]:
			return boards[i]
	return null


func _board_end(b: Dictionary, side: float) -> Vector2:
	return b["c"] + Vector2.from_angle(b["ang"]) * b["len"] * 0.5 * side


func _rip(b: Dictionary) -> void:
	# it comes away toward the corridor (whichever side the player is on) and up, spinning
	var dir := 1.0
	var pl := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if pl is Node2D:
		dir = 1.0 if (pl as Node2D).global_position.x >= global_position.x else -1.0
	dir = dir if _rng.randf() < 0.75 else -dir
	_air.append({"p": b["c"], "v": Vector2(dir * _rng.randf_range(50.0, 105.0), -_rng.randf_range(110.0, 170.0)),
		"rot": b["ang"], "vr": _rng.randf_range(4.0, 10.0) * dir, "len": b["len"] * _rng.randf_range(0.7, 1.0),
		"w": b["w"], "col": b["col"], "dark": b["dark"], "bounces": 0})
	_splinters(b["c"], 16, true)
	_splinters(_board_end(b, -1.0), 5, false)
	_splinters(_board_end(b, 1.0), 5, false)


func _splinters(at: Vector2, amount: int, dust: bool) -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.spread = 80.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 420.0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color8(176, 132, 84)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_as_relative = false
	p.z_index = 3
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
	if dust:                                          # plaster dust off the frame, slow and pale
		var d := CPUParticles2D.new()
		d.position = at
		d.one_shot = true
		d.emitting = true
		d.amount = 10
		d.lifetime = 1.1
		d.explosiveness = 0.9
		d.spread = 180.0
		d.initial_velocity_min = 8.0
		d.initial_velocity_max = 30.0
		d.gravity = Vector2(0, -12.0)
		d.scale_amount_min = 2.0
		d.scale_amount_max = 4.0
		d.color = Color(0.86, 0.82, 0.74, 0.55)
		var gd := Gradient.new()
		gd.set_color(0, Color(1, 1, 1, 0.8))
		gd.set_color(1, Color(1, 1, 1, 0))
		d.color_ramp = gd
		d.z_as_relative = false
		d.z_index = 3
		add_child(d)
		get_tree().create_timer(1.6).timeout.connect(d.queue_free)


func _process(delta: float) -> void:
	_t += delta
	_strain = maxf(0.0, _strain - delta * 3.5)
	for a in _air:
		if a.get("landed", false):
			continue
		a["v"].y += GRAVITY * delta
		a["p"] += a["v"] * delta
		a["rot"] += a["vr"] * delta
		if a["p"].y >= DOOR_BOTTOM - 2.0 and a["v"].y > 0.0:
			a["p"].y = DOOR_BOTTOM - 2.0
			a["bounces"] += 1
			if a["bounces"] >= 2 or absf(a["v"].y) < 60.0:
				a["landed"] = true
				a["rot"] = 0.0 if absf(fposmod(a["rot"], PI) - PI * 0.5) > PI * 0.25 else a["rot"]
				a["rot"] = snappedf(fposmod(a["rot"] + 0.15, PI), PI) + randf_range(-0.08, 0.08)
				_landed.append(a)
			else:
				a["v"] = Vector2(a["v"].x * 0.55, -a["v"].y * 0.35)
				a["vr"] *= 0.5
	_air = _air.filter(func(a): return not a.get("landed", false))
	queue_redraw()
	_flight.queue_redraw()
	_ground.queue_redraw()


# --- drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	var cur = _current() if working else null
	for b in boards:
		if b["gone"]:
			continue
		var jolt := 0.0
		var pull := 0.0
		if b == cur:
			var i := order.find(boards.find(b))
			var lo := _threshold(i - 1) if i > 0 else 0.0
			var local := clampf((frac - lo) / maxf(0.001, _threshold(i) - lo), 0.0, 1.0)
			jolt = sin(_t * 70.0) * 0.035 * _strain + sin(_t * 23.0) * 0.006 * local
			pull = local
		_draw_board(self, b["c"] + Vector2(0.0, -_strain * 0.8), b["ang"] + jolt, b["len"], b["w"], b["col"], b["dark"], b["seed"], pull, true)
	if working or (frac > 0.0 and frac < 1.0):
		_draw_bar()


func _draw_board(ci: CanvasItem, c: Vector2, ang: float, ln: float, w: float, col: Color, dark: Color,
		seed_: int, pull: float, nails: bool) -> void:
	var ax := Vector2.from_angle(ang)
	var ay := Vector2(-ax.y, ax.x)
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var h := ln * 0.5
	# a ragged end each side (cut / snapped), outline, face, grain
	var pts := PackedVector2Array([
		c - ax * (h - r.randf_range(0.0, 3.0)) - ay * w * 0.5,
		c + ax * (h - r.randf_range(0.0, 3.0)) - ay * w * 0.5,
		c + ax * (h + r.randf_range(-1.0, 2.0)) + ay * w * 0.5,
		c - ax * (h + r.randf_range(-1.0, 2.0)) + ay * w * 0.5])
	ci.draw_colored_polygon(pts, dark.darkened(0.45))
	var inner := PackedVector2Array()
	for k in range(4):
		inner.append(pts[k].lerp(c, 1.2 / maxf(w * 0.5, 1.0) * 0.5))
	ci.draw_colored_polygon(inner, col)
	ci.draw_line(c - ax * (h - 2.0) - ay * (w * 0.5 - 1.5), c + ax * (h - 2.0) - ay * (w * 0.5 - 1.5), col.lightened(0.18), 1.0)
	for g in range(2):                                            # the grain
		var off := r.randf_range(-w * 0.25, w * 0.25)
		var s0 := r.randf_range(-h + 3.0, 0.0)
		ci.draw_line(c + ax * s0 + ay * off, c + ax * (s0 + r.randf_range(8.0, h)) + ay * off, dark, 1.0)
	if r.randf() < 0.5:                                           # a knot
		ci.draw_circle(c + ax * r.randf_range(-h * 0.6, h * 0.6) + ay * r.randf_range(-1.0, 1.0), 1.2, dark)
	if not nails:
		return
	for sd in [-1.0, 1.0]:                                        # two nails an end, creeping out as you pull
		var side: float = sd
		for k in range(2):
			var np: Vector2 = c + ax * side * (h - 4.0) + ay * (float(k) - 0.5) * w * 0.45
			var out: Vector2 = np - ay * pull * 1.5 + ax * side * pull * 0.8
			ci.draw_rect(Rect2(out.round() - Vector2(1, 1), Vector2(2, 2)), Color8(70, 70, 76))
			ci.draw_rect(Rect2(out.round() - Vector2(0, 1), Vector2(1, 1)), Color8(170, 170, 178) if pull < 0.6 else Color8(206, 190, 150))


func _draw_bar() -> void:
	# one segment a board: gone = warm, the one you're on fills as you work (pulsing), the rest dark
	var n := boards.size()
	if n == 0:
		return
	var gap := 2.0
	var seg := 8.0
	var total := n * seg + (n - 1) * gap
	var x0 := -total * 0.5
	draw_rect(Rect2(x0 - 3.0, BAR_Y - 3.0, total + 6.0, 9.0), Color(0.05, 0.04, 0.035, 0.78))
	draw_rect(Rect2(x0 - 3.0, BAR_Y - 3.0, total + 6.0, 9.0), Color(0.62, 0.46, 0.3, 0.8), false, 1.0)
	for i in range(n):
		var x := x0 + i * (seg + gap)
		var lo := _threshold(i - 1) if i > 0 else 0.0
		var hi := _threshold(i)
		var k := clampf((frac - lo) / maxf(0.001, hi - lo), 0.0, 1.0)
		draw_rect(Rect2(x, BAR_Y, seg, 3.0), Color(0.22, 0.18, 0.15, 1.0))
		if k >= 1.0:
			draw_rect(Rect2(x, BAR_Y, seg, 3.0), Color(0.95, 0.66, 0.28, 1.0))
		elif k > 0.0:
			var glow := 0.75 + 0.25 * sin(_t * 12.0) if working else 0.7
			draw_rect(Rect2(x, BAR_Y, maxf(1.0, roundf(seg * k)), 3.0), Color(1.0, 0.82, 0.45, glow))


func _draw_flight() -> void:
	for a in _air:
		_draw_board(_flight, a["p"], a["rot"], a["len"], a["w"], a["col"], a["dark"], int(a["len"] * 13.0), 0.0, false)


func _draw_ground() -> void:
	for a in _landed:
		_draw_board(_ground, a["p"], a["rot"], a["len"], a["w"] * 0.7, a["col"].darkened(0.1), a["dark"], int(a["len"] * 13.0), 0.0, false)
