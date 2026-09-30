extends Area2D

# THE BACKPACK, lying on the floor (owner round 27). Under the packless rule a character starts a run
# with only pockets; this is what turns them into the full inventory. Laid out beside apartment 3001 on
# every run's Floor 30 (`hallway._spawn_backpack`) — and in the first run's tutorial, in 3003
# (`room._spawn_tutorial_backpack`). Walk up + [E] / click to take it: `WorldState.take_backpack()`
# opens the slots out, wakes the pack button + the quick wheel. Skipping it is allowed on purpose — the
# ultra-difficult "no backpack" run is a legitimate way to play. Built in code (no .tscn), mirroring
# player_corpse.gd. The node sits ON the floor line (local y 0 = feet), the sprite stands up from it.

signal taken

const PICKUP_RANGE := 46.0
const GLOW_RANGE := 110.0
const SCALE := 1.5                 # 16x20 art px -> 24x30 world px: a rucksack beside a ~56px person
const FL := preload("res://scripts/floor_lighting.gd")

var player: Node2D = null
var player_nearby: bool = false
## Something the tutorial wants the player to notice: the pack pulses gently brighter.
var highlight: bool = false
## Called once when the pack is taken (the tutorial's "this is your inventory" beat).
var on_taken: Callable = Callable()
var _t: float = 0.0
var _light: PointLight2D = null


func _ready() -> void:
	z_index = 0                                   # on the floor layer, under the living
	add_to_group("backpack_pickup")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	cs.shape = shape
	cs.position = Vector2(0, -20)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	player = get_tree().get_first_node_in_group("player")
	# A warm little glow so it can be found in the dark (a cousin of the loot orbs' light, softer).
	_light = PointLight2D.new()
	_light.texture = FL.light_texture()
	_light.color = Color(1.0, 0.82, 0.5)
	_light.energy = 0.0
	_light.texture_scale = 0.05
	_light.position = Vector2(0, -12)
	add_child(_light)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true
		HUD.show_world_prompt(self, "Backpack   [E] Pick up", global_position)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		HUD.hide_world_prompt(self)


func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over():
			take()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _light != null:
		var lvl := _glow_level()
		var pulse: float = (0.5 + 0.5 * sin(_t * 3.0)) if highlight else 0.0
		_light.energy = (lvl * 0.45 + pulse * 0.35) * (1.0 + 0.06 * sin(_t * 2.1))
		_light.texture_scale = 0.045 + 0.03 * maxf(lvl, pulse)
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact") and not TutorialManager.interact_guarded():
		take()


func _glow_level() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var dist := global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return 0.0
	return 1.0 - clampf((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)


func _is_mouse_over() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return false
	var mouse_world = cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom
	return global_position.distance_to(mouse_world + Vector2(0, 14)) <= PICKUP_RANGE


## Take it. Returns true when the pack was picked up.
func take() -> bool:
	if WorldState.has_backpack:
		queue_free()                              # already carrying one — a stray second pack just goes
		return false
	WorldState.take_backpack()
	HUD.hide_world_prompt(self)
	HUD.show_feedback("You pick up the backpack.")
	taken.emit()
	if on_taken.is_valid():
		on_taken.call()
	queue_free()
	return true


func _exit_tree() -> void:
	if player_nearby:
		HUD.hide_world_prompt(self)


func _draw() -> void:
	var tex: Texture2D = PackArt.texture()
	var w: float = PackArt.W * SCALE
	var h: float = PackArt.H * SCALE
	# Just the pack, standing on the floor line — no box, no outline (the world prompt says what it is).
	var lvl := _glow_level()
	var tint := Color(1, 1, 1).lerp(Color(1.12, 1.08, 1.0), maxf(lvl, 0.6 if highlight else 0.0))
	draw_texture_rect(tex, Rect2(Vector2(-w * 0.5, -h), Vector2(w, h)), false, tint)
