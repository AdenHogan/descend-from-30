extends Area2D

# The recoverable body of a PREVIOUS character (STORE_DESIGN step 7). Placed by
# WorldState.spawn_player_corpse_into at the recorded death spot; the current character walks
# up and [E]/clicks to loot it — notes credited to the wallet, items restored to inventory
# (see WorldState.recover_player_corpse). Items that don't fit stay on the body for a return
# trip. Built in code (no .tscn): an Area2D with a runtime CollisionShape2D, mirroring the
# world_drop interact pattern (prompt on approach, E or click to take).

const PICKUP_RANGE := 44.0
const GLOW_RANGE := 90.0
const FL := preload("res://scripts/floor_lighting.gd")

var corpse_key: String = ""

var player: Node2D = null
var player_nearby: bool = false
var _t: float = 0.0
var _light: PointLight2D = null


func _ready() -> void:
	z_index = 0                                  # a body lies on the floor layer, under the living
	add_to_group("player_corpse")
	# Detection shape (built at runtime so this needs no .tscn).
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	player = get_tree().get_first_node_in_group("player")
	# A soft, mournful blue glow so the body reads as findable in the dark (distinct from the
	# gold loot orbs — this is someone you lost, not a pickup).
	_light = PointLight2D.new()
	_light.texture = FL.light_texture()
	_light.color = Color(0.6, 0.72, 1.0)
	_light.energy = 0.0
	_light.texture_scale = 0.06
	_light.z_index = 0
	add_child(_light)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true
		HUD.show_world_prompt(self, "Fallen survivor   [E] Recover", global_position)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		HUD.hide_world_prompt(self)


func _input(event: InputEvent) -> void:
	if not player_nearby:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_mouse_over_body():
			_recover()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _light != null:
		var lvl := _glow_level()
		_light.energy = lvl * 0.5 * (1.0 + 0.08 * sin(_t * 2.4))
		_light.texture_scale = 0.04 + 0.03 * lvl
	if not player_nearby:
		return
	if Input.is_action_just_pressed("interact"):
		_recover()


func _glow_level() -> float:
	if player == null:
		return 0.0
	var dist := global_position.distance_to(player.global_position)
	if dist > GLOW_RANGE:
		return 0.0
	return 1.0 - clampf((dist - PICKUP_RANGE) / (GLOW_RANGE - PICKUP_RANGE), 0.0, 1.0)


func _is_mouse_over_body() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	var cam = p.get_node_or_null("Camera2D")
	if cam == null:
		return false
	var mouse_world = cam.get_screen_center_position() + \
		(get_viewport().get_mouse_position() - get_viewport().get_visible_rect().size / 2) / cam.zoom
	return global_position.distance_to(mouse_world) <= PICKUP_RANGE


func _recover() -> void:
	var summary = WorldState.recover_player_corpse(corpse_key)
	# Collect the fallen character's MEMORY too (STORE_DESIGN corpse recovery + cross-run memory):
	# unlock their lore in the chronicle and leave this character's comment on finding them.
	if corpse_key.is_valid_int():
		var dead_run := int(corpse_key)
		WorldState.recover_run_memory(dead_run, WorldState.make_finder_thought(dead_run))
	var parts: Array = []
	if int(summary.get("notes", 0)) > 0:
		parts.append("%d notes" % int(summary["notes"]))
	if int(summary.get("items_taken", 0)) > 0:
		parts.append("%d item%s" % [int(summary["items_taken"]), "" if summary["items_taken"] == 1 else "s"])
	if parts.is_empty():
		HUD.show_feedback("Nothing to recover — inventory full.")
	else:
		HUD.show_feedback("Recovered " + " and ".join(parts) + ".")
	# The body only lingers if items couldn't fit (a return trip); otherwise it's spent.
	if int(summary.get("items_left", 0)) <= 0:
		HUD.hide_world_prompt(self)
		queue_free()


func _exit_tree() -> void:
	if player_nearby:
		HUD.hide_world_prompt(self)


func _draw() -> void:
	# A slumped placeholder body (art pass later): a dark torso + head, brightening a little
	# when the player is near so it reads as reachable. Faces feet-down on the floor line.
	var lvl := _glow_level()
	var body_col := Color(0.24, 0.22, 0.26).lerp(Color(0.42, 0.40, 0.48), lvl)
	# torso (lying)
	draw_rect(Rect2(-18.0, -6.0, 36.0, 12.0), body_col)
	# head
	draw_circle(Vector2(-22.0, 0.0), 7.0, body_col)
	# a faint rim when near, to sell "interactable"
	if lvl > 0.0:
		draw_rect(Rect2(-18.0, -6.0, 36.0, 12.0), Color(0.7, 0.8, 1.0, 0.25 * lvl), false, 2.0)
