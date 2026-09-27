extends Node2D
## FOREGROUND DEAD — a TEST look (owner round 21c: "sometimes we can have them in the foreground
## black shadows, like in games like hollow knight and silk song where visual storytelling puts
## items right on the camera… to show that this room has bodies everywhere even right up to the
## camera. This doesn't need to be all the time and we can test it first").
##
## Black silhouettes of the dead along the bottom edge of the view, between the camera and the
## play plane: drawn big (closer to us), cut off by the frame's bottom edge, sliding a little FASTER
## than the room as the camera moves (parallax), so they read as in front of everything. Never lit
## (light_mask 0), drawn over actors; a piece fades back when the player walks behind it so it never
## hides them. Sporadic by default (`wants`), forced on / off from the F1 dev menu
## (WorldState.foreground_dead_mode: 0 off, 1 sporadic, 2 everywhere).

const DIR := "res://assets/foreground/"        # tools/art/foreground_dead.py — black shapes at world px size
const KINDS := {"heap": 3, "slumped": 2, "hand": 2}
const SINK := 14.0              # px of each piece hidden below the frame's bottom edge
const PARALLAX := 0.35          # how much faster than the room it slides
const FADED := 0.35             # a piece's alpha while the player is behind it

var _pieces: Array = []         # [{node: Node2D, base_x: float, half_w: float}]
var _bottom := 435.0


## Should this place show them (sporadic mode)? kind: "corridor" / "breach" / "corpse". Seeded by
## the place + run, so a place is always the same during a run.
static func wants(kind: String, place: String) -> bool:
	match int(WorldState.foreground_dead_mode):
		0:
			return false
		2:
			return true
	var chance: float = {"corridor": 0.35, "breach": 0.5, "corpse": 0.35}.get(kind, 0.0)
	var h := posmod(hash(str(WorldState.master_seed) + "fgdead" + place + str(WorldState.current_run)), 1000)
	return float(h) / 1000.0 < chance


## Lay 2-4 pieces along [x0, x1] with their feet `bottom` (the bottom edge of the view).
func setup(place: String, bottom: float, x0: float, x1: float) -> void:
	name = "ForegroundDead"
	z_index = 40
	_bottom = bottom
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(WorldState.master_seed) + "fgpieces" + place)
	var n := rng.randi_range(2, 3)
	var span := (x1 - x0) / float(n)
	for i in range(n):
		var cx := x0 + span * (float(i) + rng.randf_range(0.2, 0.8))
		_pieces.append(_piece(rng, cx))


func _piece(rng: RandomNumberGenerator, cx: float) -> Dictionary:
	# mostly the piled dead; now and then one slumped against something, or a hand reaching up
	var r := rng.randf()
	var kind := "heap" if r < 0.55 else ("slumped" if r < 0.8 else "hand")
	var tex: Texture2D = load(DIR + "fg_%s_%d.png" % [kind, rng.randi_range(1, int(KINDS[kind]))])
	var p := Node2D.new()
	add_child(p)
	if tex == null:
		return {"node": p, "base_x": cx, "half_w": 0.0}
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.flip_h = rng.randf() < 0.5
	s.light_mask = 0                                   # never lit: a shape between us and the light
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sz := tex.get_size()
	s.position = Vector2(-sz.x * 0.5, SINK - sz.y)
	p.add_child(s)
	p.position = Vector2(cx, _bottom)
	return {"node": p, "base_x": cx, "half_w": sz.x * 0.5}


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var cam_x: float = cam.get_screen_center_position().x if cam != null else 0.0
	var player := get_tree().get_first_node_in_group("player")
	for pc in _pieces:
		var node: Node2D = pc["node"]
		if not is_instance_valid(node):
			continue
		node.position.x = float(pc["base_x"]) - (cam_x - float(pc["base_x"])) * PARALLAX
		var want := 1.0
		if player is Node2D and absf((player as Node2D).global_position.x - node.global_position.x) < float(pc["half_w"]) + 10.0:
			want = FADED
		node.modulate.a = move_toward(node.modulate.a, want, delta * 3.0)


func piece_count() -> int:
	return _pieces.size()
